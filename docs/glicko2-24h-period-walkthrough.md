# Glicko-2 24h rating periods — agent walkthrough

> Canonical design, test evidence, and debug notes for the wall-clock Glicko-2 period work shipped in MGEMod **3.1.0-beta36** and mge-classelo **0.7**. Written so a later agent can fix production issues without replaying the original chat.
>
> Companion plugin: [mge-classelo](https://github.com/mgetf/mge-classelo). Ecosystem consumers: `mge-platform`, `website-next`, `mge-servers-panel`.
>
> Source chat: [Glicko 24h periods](4744befb-f120-4d49-99f2-edb780a1610f) (2026-08-30 through 2026-09-01).

**Source of truth is the GitHub trees.** Local TF2 copies under `C:\Users\Maxi\Documents\tf2server\`, MCP scratch plugins (`glicko-onematch`, `glicko-hud-dump`, `glicko-add4`, probes), and LAN Steam-ID overrides are not product code.

---

## 1. What was broken

The first Glicko-2 port scored **each duel as its own rating period**.

That is legal Glicko-2, but it is the wrong grain for MGE:

- Glickman's RD inflation (`phi' = sqrt(phi² + σ²)`) is meant to run **once per empty window**, not once per five-minute duel.
- A strong player farming weaker opponents therefore saw **RD rise during a good session**. A lucky first win could sit on `!top` until RD finally dropped.
- Inactive players kept a frozen `rd` on disk. There is still no nightly job that walks the table. `!top` / platform / website read the stored RD, so a retired 2400 with RD 80 stayed ranked until they played again.

Lazy inactivity inflation (`Glicko2_ApplyInactivityDecay`) only ran at the **next duel**. No cron existed. That was correct for "no batch job", and wrong for leaderboard truth.

### Field example that started the ranking discussion

Steam64 `76561198879628943` (rch) could sit at the top of the skill pool and still miss the public leaderboard because sealed RD stayed ≥ `mgemod_glicko_ranked_rd` (100). A lower-rated player (flash, `76561198822971925`) with more volume against similar opponents dropped RD below the gate. This is Glicko volume/information, not a corrupt row.

### Adjacent incident (same week, not the period bug)

classelo appeared to "reset" on SA. It had not. `mge_classelo_dbconfig` was ignored until `OnConfigsExecuted`, so the plugin connected to the compiled default (`mgemod`) and wrote `mge_classelo_stats` **inside the mgemod database**. HUD could show a class rating from a different DB than the dedicated `mge_classelo` schema. Fix: hard-fail if `mge_classelo` is missing; never default to `mgemod`. Data was later moved with `mge-platform/scripts/migrate-classelo-db.ts` after the plugin was deployed worldwide. If a future "classelo reset" report appears, check **which database** the plugin connected to before assuming Glicko math is wrong.

---

## 2. Product contract (do not "fix" this)

| Surface | Number shown | Marker |
|---|---|---|
| Arena HUD, classelo HUD extra, in-game chat after a 1v1 | Estimate for the **open** period | `~` while `period_dirty` |
| `!top`, `!rank`, platform poller, website, servers-panel lookup | **Sealed** `rating` / `rd` / `volatility` | `?` if sealed RD is provisional |
| After period close | Estimate copied from seal | `~` drops |

Player-facing intent: live `~` exists so people still feel progress after 16 years of per-duel Elo. Serious ranking never reads the tilde.

Elo engine (`mgemod_rating_engine "elo"`) is unchanged: still live per duel. This document is **Glicko-2 only**.

2v2 does **not** write rating, RD, volatility, or estimate under **either** engine. Wins/losses still increment. `mgemod_duels_2v2` is still inserted. `mgemod_2v2_elo` only gates whether 2v2 HUD lines show rating digits. 2v2 team rating is an unsolved product problem. Do not sneak rating writes back in.

---

## 3. Decisions that must survive refactors

### 3.1 One shared wall-clock period, not sessions

A session-length or "first game + N hours" window is incompatible with frozen opponent ratings. Two players' sessions would not align, so "what is B's sealed rating right now?" would be undefined. The fleet uses one boundary for the region.

Default phase for mge.tf: **08:20 ART** (`mgemod_glicko_period_hour 8`, `minute 20`, `utc_offset -3`). Do **not** use `:00`. Boxes already restart on the hour to fight jitter. Close at `:00` races the reboot and can skip a seal on an empty hibernating box.

Period **length** is `mgemod_glicko_period_hours` (1–168, default 24). Separate from `mgemod_glicko_period_days`, which is only the **inactivity RD** knob (how many missed windows inflate RD when someone returns).

### 3.2 Close inside the plugin, no Railway worker

MGEMod must stay a self-contained SourceMod plugin. An external closer would break third-party servers. Close is a 30s repeating timer plus a boot pass, gated by **`mgemod_glicko_period_close`** (default `0`). On mge.tf only the `db+gameserver` host sets this to `1` (localhost MariaDB). Other regional game servers stay at `0`. Third-party single-server installs set it to `1`. The closer box must keep ticking: **`sv_hibernate_when_empty 0`**. The advisory lock is a second line of defense if more than one instance on that box has the cvar on.

Do not freeze arenas during close. Updates are chunked (`GLICKO_PERIOD_UPDATE_CHUNK` 40 rows). Typical close is sub-second to a few seconds on current SA volume, not minutes.

### 3.3 Advisory SQL lock, not `SQL_LockDatabase`

`SQL_LockDatabase` is connection-local. Server B cannot see it.

| Driver | Lock |
|---|---|
| MySQL/MariaDB | `SELECT GET_LOCK('mgemod_period_close', 0)` |
| PostgreSQL | `SELECT pg_try_advisory_lock(hashtext('mgemod_period_close'))` |
| SQLite | no cross-process lock (single writer). Skip or rely on one box. |

Timeout 0: try once, leave if busy. The loser retries on the next 30s tick. With `mgemod_glicko_period_close` only enabled on the DB host, the lock is belt-and-suspenders among slots on that box — not a fleet-wide race.

classelo uses a **different** lock name: `mge_classelo_period_close`. It must not queue behind overall MGE close.

Duels that finish while the lock is held still insert into `mgemod_duels` with that `period_id` and `period_sealed=0`. Close leftover passes (`GLICKO_PERIOD_LEFTOVER_MAX` 3) recompute **only those leftover rows** from the freeze snapshots of that period. **One `phiStar` per player per period.** Never inflate RD a second time for leftovers.

### 3.4 Estimate is a column, not a log replay

Match-end writes HUD columns on `mgemod_stats`:

- `rating_est`, `rd_est`, `period_dirty`

The HUD reads those. It does not parse `mge-logs`. After each 1v1 the estimate is the **same one-`phiStar` batch** the real close will use: all of today's duels against **frozen sealed** opponent rating/RD, not chained per-duel Glicko.

A HUD of `~2450` sealing at `2440` is expected (tiny gap). A HUD of `~1961` sealing at `1646` on the LAN box was **self-duel / leftover-hammer contamination** (four clients, one Steam ID), not production math. Clean dummy: `~1438` sealed **1438**.

### 3.5 Forwards fire on seal only

`MGE_OnPlayerELOChange` / `MGE_OnPlayerRatingChange` must not fire for HUD estimate writes. External plugins would treat a preview as a committed rating.

### 3.6 No post-seal void cascade in v1

Do not auto-rewrite sealed history if a duel is later voided. Append-only. Offline rebuild is a possible future admin tool. Confirmed wintrading is a human process, not a graph cascade that moves player B because match A was voided.

### 3.7 classelo is independent, same clock

classelo has its own table, own close, own estimate columns, own 7-day unused-class RD window (`mge_classelo_glicko_period_days` default 7 vs MGE 1). It does **not** share Steam IDs through an MGE native. Both plugins call `GetClientAuthId`. A temporary `sm_mge_setsteamid` existed only for LAN clones and was removed.

Each class seals from `mge_classelo_duels` rows for that `(steamid, class)`. A player who played 10 games in 24h:

- MGE close: one overall period of those 10.
- classelo close: scout/soldier/sniper/… each from **that class's** games only. Classes with 0 games that day do **not** get a daily RD bump. Unused-class RD inflates only after the 7-day inactivity window since `lastplayed`. A never-played class has no row.

### 3.8 Sparse classes (known, not a v1 bug)

Batching only helps when several games share **one** window.

- Eight engineer duels **the same night**: one period. This is the bug we fixed.
- Eight engineer duels on **eight different days**: eight one-game periods. RD can still rise. That matches Glicko when the class is genuinely rare.

Raising `mge_classelo_glicko_period_hours` (for example 168) is an optional later knob, not a missing close.

### 3.9 Tau stays 0.5 until we have sealed-period telemetry

`τ` (convar `mgemod_glicko_tau` / `mge_classelo_glicko_tau`) is Glickman's system constant for how fast volatility may move. It is not the period length. Do not retune from the old per-duel data. Watch σ clustering after 24h seals ship.

---

## 4. Schema (additive only)

Migration `009_glicko_period_schema` on MGEMod. classelo applies equivalent ALTERs in-plugin.

**No table or key column was renamed.** `mge-platform` still polls:

```sql
SELECT steamid, name, rating, rd, volatility, wins, losses, lastplayed FROM mgemod_stats;
SELECT steamid, class, rating, rd, volatility, wins, losses, lastplayed FROM mge_classelo_stats WHERE class BETWEEN 1 AND 9;
```

New columns are ignored by that SELECT. **No Prisma migration is required** for website or platform unless someone later wants `~` on the web.

### `mgemod_stats` added

`rating_est`, `rd_est`, `period_dirty`

### `mgemod_duels` added

`period_id`, `winner_sealed_*`, `loser_sealed_*`, `period_sealed`

Unique index `idx_mgemod_duels_match (winner, loser, starttime, endtime)` so leftover close cannot double-insert.

### New tables

- `mgemod_period_state (id=1, last_sealed_period_id)`
- classelo: `mge_classelo_duels`, `mge_classelo_period_state`

`rd IS NULL` still means Elo. `rd IS NOT NULL` still means Glicko-2. That invariant is older (migrations 007/008) and platform ranked filters depend on it.

`elo-corruption-audit.ts` compares `winner_new_elo` to `mgemod_stats.rating`. Under Glicko periods those duel elo columns stay near the **sealed** value during the day, so the audit can look "flat". That script is offline, not a production reader.

---

## 5. Code map

| Piece | File |
|---|---|
| Timer, lock, leftover, batch math | `addons/sourcemod/scripting/mge/rating/glicko_period.sp` |
| Include from entry | `mge.sp` (`#include "mge/rating/glicko_period.sp"`) |
| ConVars | `mgemod_glicko_period_hours/hour/minute/utc_offset` in `mge.sp` |
| Duel insert with snapshots | `mge/sql.sp` `GetInsertDuelQuery` |
| Schema | `mge/migrations.sp` `009_glicko_period_schema` |
| HUD `~` | `mge/hud.sp` from `g_iPlayerRatingEst` / `g_bPlayerPeriodDirty` |
| classelo mirror | `mge-classelo/scripting/mge_classelo.sp` (`ClassPeriod_*`) |
| classelo chat | `translations/mge_classelo.phrases.txt` via `MC_PrintToChat` + morecolors |

Elo path: `engine_elo.sp` still writes `rating` live. Do not route Elo through `glicko_period.sp`.

---

## 6. Testing that actually ran (2026-09-01, local srcds + MariaDB)

Harness: SourceMod MCP `user-sourcemod`, MariaDB Docker `sbpp-db` database `sm` (host port 3307, plus a 3306 socat proxy). GitHub sources compiled with `spcomp` 1.12. LAN clones needed a **temporary** `sm_mge_setsteamid` because four clients shared one Steam ID. That command and `g_sSteamIdOverride` were **removed** before ship.

### Proven

- Unique key on duel rows.
- 1v1 writes `period_dirty`, HUD `~`, estimate columns. After leftover/in-plugin close, dirty=0 and `~` gone.
- Leftover rows during close recomputed without a second `phiStar`.
- `GET_LOCK` skip then resume on the next tick.
- Forwards only on seal (count=2 for elo+rating on a leftover close in the live run).
- Forfeit 3-0 vs 0-0 leave.
- 4-player 2v2: `mgemod_duels_2v2` + W/L, **no** rating/RD/est/classelo writes.
- classelo 7-day unused-class RD vs MGE daily inactivity knob.
- SQL 8-game one-period math on MariaDB (not Elo).

### Do not treat as production math

`~1961` vs sealed `1646` on the LAN box. Same Steam ID fighting itself plus leftover hammer. Use the clean dummy (`~1438` → `1438`) when checking estimate ≈ seal.

### Not tested (non-blocking)

- Real 08:20 on an empty production closer box (hibernate off is required on that host).
- Two live srcds on the same DB host fighting the lock at once (lock SQL was unit-tested, not two processes).
- SQLite and Postgres close paths.
- Flipping `mgemod_rating_engine` back to Elo after a sealed Glicko history.

Pre-existing compile warning: `migrations.sp` `IsAlreadyAppliedMigrationError` should return a value. Unrelated. Do not "fix" it in a period-bug hotfix unless you are already in that file.

---

## 7. Debug playbook

**HUD has `~` but website does not.** Expected until the next seal. Website reads sealed `rating`.

**HUD `~` never drops.** Check `mgemod_glicko_period_close` is `1` on the DB host, `mgemod_period_state.last_sealed_period_id`, plugin timer, `sv_hibernate_when_empty`, and whether this box lost `GET_LOCK` to another srcds that then crashed mid-close (`period_sealed` leftover). Force a leftover close by advancing `last_sealed_period_id` only if you understand leftover recompute. Do not delete `mgemod_duels` rows from the open period.

**Two servers double-sealed.** Should be impossible with `GET_LOCK`. If you see it, they are not on the same MariaDB, lock name changed, or driver is SQLite.

**classelo HUD disagrees with MGE HUD.** Different DBs (`mge_classelo` vs leftover table in `mgemod`). Confirm `databases.cfg` + `mge_classelo_dbconfig` after `server.cfg`. classelo hard-fails on connect errors. Access denied (1045) is infra grants, not Glicko.

**RD still climbs on engineer.** Count games **per class per period**, not career volume. 0–1 engineer games per day is the documented sparse-class case.

**Huge estimate vs seal gap.** First check self-duels / duplicate Steam IDs / leftover hammer. Production 08:20 of **yesterday** should match the last HUD `~` of that day (same freeze + same games).

**Chat/log noise.** classelo logs have no `[mge_classelo]` prefix (SourceMod already tags the plugin). Chat is translations, compact: `{green}[MGE]{default} +15 Scout (now {green}1800{default})`. Glicko estimate uses `~` before the number. Class names are engine strings (`Scout`), not phrase keys. `tf2.inc` has `TF2_GetClass` (name → class) only. Reverse is a small static array in classelo.

---

## 8. What must not be reintroduced

- `sm_mge_setsteamid` / `g_sSteamIdOverride`
- `MGE_GetPlayerSteamID` native added only so classelo followed the override
- Scratch plugins on the test box as if they were the GitHub tree
- Per-duel Glicko as the sealed writer
- 2v2 rating writes
- External closer service
- Website reading `rating_est` without a new, explicit product decision

---

## 9. Related docs

- MGEMod `README.md` Rating Engines section (player-facing convars)
- mge-classelo `README.md` (7-day unused class, lock name, HUD `/~1850`)
- `mge-servers-panel/docs/mge-tf-regional-elo-architecture.md` (why platform polls sealed `rating`)
- Glickman: http://www.glicko.net/glicko/glicko2.pdf
