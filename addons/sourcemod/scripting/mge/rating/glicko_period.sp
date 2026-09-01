// ===== GLICKO-2 WALL-CLOCK PERIOD CLOSE =====
//
// Sealed rating/RD/volatility move once per configured window. Match-end writes the
// duel log plus HUD estimate columns. Close is elected via a per-driver advisory lock.

enum struct GlickoPeriodGame
{
    float oppRating;
    float oppRd;
    float score;
}

enum struct GlickoPeriodPlayer
{
    char steamid[32];
    int rating;
    float rd;
    float volatility;
    int lastplayed;
    int newRating;
    float newRd;
    float newVolatility;
    bool hadGames;
}

enum struct GlickoPeriodStart
{
    int rating;
    float rd;
    float volatility;
}

#define GLICKO_PERIOD_UPDATE_CHUNK 40
#define GLICKO_PERIOD_LEFTOVER_MAX 3

StringMap g_hGlickoPeriodGameMap;
StringMap g_hGlickoPeriodStartMap;
ArrayList g_hGlickoPeriodPlayers;
ArrayList g_hGlickoPeriodUpdateQueue;
int g_iGlickoPeriodCloseTarget;
int g_iGlickoPeriodLeftoverPasses;
int g_iGlickoPeriodUpdateIndex;
bool g_bGlickoPeriodRecomputeOnly;

int GlickoPeriod_GetId(int unixTime = 0)
{
    if (unixTime <= 0)
        unixTime = GetTime();

    int hours = g_iGlickoPeriodHours;
    if (hours < 1)
        hours = 1;
    if (hours > 168)
        hours = 168;

    int periodSec = hours * 3600;
    int offsetSec = g_iGlickoPeriodUtcOffset * 3600;
    int phaseSec = (g_iGlickoPeriodHour * 3600) + (g_iGlickoPeriodMinute * 60);
    int shifted = unixTime + offsetSec - phaseSec;
    if (periodSec <= 0)
        return 0;
    if (shifted < 0)
        return (shifted - periodSec + 1) / periodSec;
    return shifted / periodSec;
}

void GlickoPeriod_StartTimers()
{
    if (g_hGlickoPeriodTimer == null)
        g_hGlickoPeriodTimer = CreateTimer(30.0, Timer_GlickoPeriodTick, _, TIMER_REPEAT);

    CreateTimer(15.0, Timer_GlickoPeriodBootClose);
}

void GlickoPeriod_OnSchemaReady()
{
    if (g_bGlickoPeriodSchemaReady)
        return;

    g_bGlickoPeriodSchemaReady = true;
    GlickoPeriod_StartTimers();
}

Action Timer_GlickoPeriodTick(Handle timer)
{
    GlickoPeriod_TryClose();
    return Plugin_Continue;
}

Action Timer_GlickoPeriodBootClose(Handle timer)
{
    GlickoPeriod_TryClose();
    return Plugin_Stop;
}

void GlickoPeriod_TryClose()
{
    if (g_eRatingEngine != RATING_ENGINE_GLICKO2 || g_bNoStats || g_DB == null || !g_bGlickoPeriodSchemaReady)
        return;

    if (!g_bGlickoPeriodCloseEnabled)
        return;

    if (g_bGlickoPeriodCloseRunning)
        return;

    g_bGlickoPeriodCloseRunning = true;
    GlickoPeriod_TryLock();
}

void GlickoPeriod_TryLock()
{
    char query[256];
    switch (g_DatabaseType)
    {
        case DB_MYSQL:
            g_DB.Format(query, sizeof(query), "SELECT GET_LOCK('%s', 0)", GLICKO_PERIOD_LOCK_NAME);
        case DB_POSTGRESQL:
            g_DB.Format(query, sizeof(query), "SELECT pg_try_advisory_lock(hashtext('%s'))", GLICKO_PERIOD_LOCK_NAME);
        default:
            strcopy(query, sizeof(query), "BEGIN IMMEDIATE");
    }

    g_DB.Query(GlickoPeriod_OnLockResult, query);
}

void GlickoPeriod_OnLockResult(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || results == null || !StrEqual("", error))
    {
        if (!StrEqual("", error))
            LogError("[GlickoPeriod] Lock failed: %s", error);
        g_bGlickoPeriodCloseRunning = false;
        return;
    }

    bool acquired = true;
    if (g_DatabaseType != DB_SQLITE)
    {
        if (!results.FetchRow())
        {
            g_bGlickoPeriodCloseRunning = false;
            return;
        }
        acquired = (results.FetchInt(0) == 1);
    }

    if (!acquired)
    {
        g_bGlickoPeriodCloseRunning = false;
        return;
    }

    g_bGlickoPeriodLockHeld = true;
    char query[192];
    strcopy(query, sizeof(query), "SELECT last_sealed_period_id FROM mgemod_period_state WHERE id = 1 LIMIT 1");
    g_DB.Query(GlickoPeriod_OnMeta, query);
}

void GlickoPeriod_OnMeta(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || results == null || !StrEqual("", error))
    {
        LogError("[GlickoPeriod] Failed to read period_state: %s", error);
        GlickoPeriod_Finish(false);
        return;
    }

    int lastSealed = 0;
    if (results.FetchRow())
        lastSealed = results.FetchInt(0);

    g_iGlickoLastSealedPeriodId = lastSealed;
    int current = GlickoPeriod_GetId();

    if (lastSealed == 0)
    {
        int seed = current - 1;
        if (seed < 1)
            seed = current;
        char query[192];
        g_DB.Format(query, sizeof(query), "UPDATE mgemod_period_state SET last_sealed_period_id = %d WHERE id = 1", seed);
        g_iGlickoLastSealedPeriodId = seed;
        g_DB.Query(GlickoPeriod_OnBootstrapped, query);
        return;
    }

    if (lastSealed >= current - 1)
    {
        g_iGlickoPeriodCloseTarget = lastSealed;
        GlickoPeriod_FetchLeftovers();
        return;
    }

    g_iGlickoPeriodCloseTarget = lastSealed + 1;
    g_bGlickoPeriodRecomputeOnly = false;
    g_iGlickoPeriodLeftoverPasses = 0;
    GlickoPeriod_FetchPeriodDuels();
}

void GlickoPeriod_OnBootstrapped(Database db, DBResultSet results, const char[] error, any data)
{
    if (!StrEqual("", error))
        LogError("[GlickoPeriod] Bootstrap last_sealed failed: %s", error);
    GlickoPeriod_Finish(true);
}

void GlickoPeriod_FetchPeriodDuels()
{
    char query[256];
    g_DB.Format(query, sizeof(query),
        "SELECT winner, loser, winner_sealed_rating, winner_sealed_rd, winner_sealed_volatility, loser_sealed_rating, loser_sealed_rd, loser_sealed_volatility FROM mgemod_duels WHERE period_id = %d",
        g_iGlickoPeriodCloseTarget);
    g_DB.Query(GlickoPeriod_OnPeriodDuels, query);
}

void GlickoPeriod_OnPeriodDuels(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || results == null || !StrEqual("", error))
    {
        LogError("[GlickoPeriod] Failed to load period duels: %s", error);
        GlickoPeriod_Finish(false);
        return;
    }

    GlickoPeriod_ClearGameMap();
    g_hGlickoPeriodGameMap = new StringMap();
    g_hGlickoPeriodStartMap = new StringMap();

    while (results.FetchRow())
    {
        if (results.IsFieldNull(2) || results.IsFieldNull(5))
            continue;

        char winner[32], loser[32];
        results.FetchString(0, winner, sizeof(winner));
        results.FetchString(1, loser, sizeof(loser));
        float winnerRating = float(results.FetchInt(2));
        float winnerRd = results.FetchFloat(3);
        float winnerVol = results.FetchFloat(4);
        float loserRating = float(results.FetchInt(5));
        float loserRd = results.FetchFloat(6);
        float loserVol = results.FetchFloat(7);

        GlickoPeriod_RememberStart(winner, RoundFloat(winnerRating), winnerRd, winnerVol);
        GlickoPeriod_RememberStart(loser, RoundFloat(loserRating), loserRd, loserVol);
        GlickoPeriod_AddGame(winner, loserRating, loserRd, 1.0);
        GlickoPeriod_AddGame(loser, winnerRating, winnerRd, 0.0);
    }

    if (g_bGlickoPeriodRecomputeOnly)
    {
        GlickoPeriod_QueueGamePlayersOnly();
        return;
    }

    char query[256];
    strcopy(query, sizeof(query), "SELECT steamid, rating, rd, volatility, lastplayed FROM mgemod_stats WHERE rd IS NOT NULL");
    g_DB.Query(GlickoPeriod_OnStats, query);
}

void GlickoPeriod_RememberStart(const char[] steamid, int rating, float rd, float volatility)
{
    GlickoPeriodStart start;
    if (g_hGlickoPeriodStartMap.GetArray(steamid, start, sizeof(start)))
        return;

    start.rating = rating;
    start.rd = rd;
    start.volatility = volatility;
    g_hGlickoPeriodStartMap.SetArray(steamid, start, sizeof(start));
}

void GlickoPeriod_AddGame(const char[] steamid, float oppRating, float oppRd, float score)
{
    ArrayList games;
    if (!g_hGlickoPeriodGameMap.GetValue(steamid, games) || games == null)
    {
        games = new ArrayList(sizeof(GlickoPeriodGame));
        g_hGlickoPeriodGameMap.SetValue(steamid, games);
    }

    if (games.Length >= GLICKO2_MAX_PERIOD_GAMES)
        return;

    GlickoPeriodGame game;
    game.oppRating = oppRating;
    game.oppRd = oppRd;
    game.score = score;
    games.PushArray(game);
}

void GlickoPeriod_OnStats(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || results == null || !StrEqual("", error))
    {
        LogError("[GlickoPeriod] Failed to load stats for close: %s", error);
        GlickoPeriod_Finish(false);
        return;
    }

    delete g_hGlickoPeriodPlayers;
    g_hGlickoPeriodPlayers = new ArrayList(sizeof(GlickoPeriodPlayer));

    while (results.FetchRow())
    {
        GlickoPeriodPlayer player;
        results.FetchString(0, player.steamid, sizeof(player.steamid));
        player.rating = results.FetchInt(1);
        player.rd = results.FetchFloat(2);
        player.volatility = results.FetchFloat(3);
        player.lastplayed = results.FetchInt(4);
        player.newRating = player.rating;
        player.newRd = player.rd;
        player.newVolatility = player.volatility;
        player.hadGames = false;

        ArrayList games;
        if (g_hGlickoPeriodGameMap != null && g_hGlickoPeriodGameMap.GetValue(player.steamid, games) && games != null && games.Length > 0)
        {
            player.hadGames = true;
            GlickoPeriodStart start;
            if (g_hGlickoPeriodStartMap != null && g_hGlickoPeriodStartMap.GetArray(player.steamid, start, sizeof(start)))
            {
                player.rating = start.rating;
                player.rd = start.rd;
                player.volatility = start.volatility;
            }
            GlickoPeriod_FillFromGames(player, games);
        }
        else
        {
            Glicko2_InflateRdOnePeriod(player.rd, player.volatility, player.newRd);
        }

        g_hGlickoPeriodPlayers.PushArray(player);
    }

    GlickoPeriod_QueueUpdates();
}

void GlickoPeriod_FillFromGames(GlickoPeriodPlayer player, ArrayList games)
{
    int count = games.Length;
    if (count > GLICKO2_MAX_PERIOD_GAMES)
        count = GLICKO2_MAX_PERIOD_GAMES;

    float oppRating[GLICKO2_MAX_PERIOD_GAMES];
    float oppRd[GLICKO2_MAX_PERIOD_GAMES];
    float score[GLICKO2_MAX_PERIOD_GAMES];

    for (int i = 0; i < count; i++)
    {
        GlickoPeriodGame game;
        games.GetArray(i, game);
        oppRating[i] = game.oppRating;
        oppRd[i] = game.oppRd;
        score[i] = game.score;
    }

    float newRating, newRd, newVol;
    Glicko2_ComputePeriodUpdate(float(player.rating), player.rd, player.volatility, count, oppRating, oppRd, score, newRating, newRd, newVol);
    player.newRating = RoundFloat(newRating);
    player.newRd = newRd;
    player.newVolatility = newVol;
}

void GlickoPeriod_QueueGamePlayersOnly()
{
    delete g_hGlickoPeriodPlayers;
    g_hGlickoPeriodPlayers = new ArrayList(sizeof(GlickoPeriodPlayer));

    if (g_hGlickoPeriodGameMap != null)
    {
        StringMapSnapshot snap = g_hGlickoPeriodGameMap.Snapshot();
        int len = snap.Length;
        for (int i = 0; i < len; i++)
        {
            char steamid[32];
            snap.GetKey(i, steamid, sizeof(steamid));

            ArrayList games;
            if (!g_hGlickoPeriodGameMap.GetValue(steamid, games) || games == null)
                continue;

            GlickoPeriodStart start;
            if (g_hGlickoPeriodStartMap == null || !g_hGlickoPeriodStartMap.GetArray(steamid, start, sizeof(start)))
                continue;

            GlickoPeriodPlayer player;
            strcopy(player.steamid, sizeof(player.steamid), steamid);
            player.rating = start.rating;
            player.rd = start.rd;
            player.volatility = start.volatility;
            player.newRating = start.rating;
            player.newRd = start.rd;
            player.newVolatility = start.volatility;
            player.hadGames = true;
            GlickoPeriod_FillFromGames(player, games);
            g_hGlickoPeriodPlayers.PushArray(player);
        }
        delete snap;
    }

    GlickoPeriod_QueueUpdates();
}

void GlickoPeriod_QueueUpdates()
{
    delete g_hGlickoPeriodUpdateQueue;
    g_hGlickoPeriodUpdateQueue = new ArrayList(ByteCountToCells(512));
    g_iGlickoPeriodUpdateIndex = 0;

    if (g_hGlickoPeriodPlayers != null)
    {
        for (int i = 0; i < g_hGlickoPeriodPlayers.Length; i++)
        {
            GlickoPeriodPlayer player;
            g_hGlickoPeriodPlayers.GetArray(i, player);

            char query[512];
            g_DB.Format(query, sizeof(query),
                "UPDATE mgemod_stats SET rating=%d, rd=%f, volatility=%f, rating_est=%d, rd_est=%f, period_dirty=0 WHERE steamid='%s'",
                player.newRating, player.newRd, player.newVolatility, player.newRating, player.newRd, player.steamid);
            g_hGlickoPeriodUpdateQueue.PushString(query);
        }
    }

    char markQuery[192];
    g_DB.Format(markQuery, sizeof(markQuery),
        "UPDATE mgemod_duels SET period_sealed=1 WHERE period_id=%d", g_iGlickoPeriodCloseTarget);
    g_hGlickoPeriodUpdateQueue.PushString(markQuery);

    GlickoPeriod_FlushUpdateChunk();
}

void GlickoPeriod_FlushUpdateChunk()
{
    if (g_hGlickoPeriodUpdateQueue == null)
    {
        GlickoPeriod_AfterUpdates();
        return;
    }

    int remaining = g_hGlickoPeriodUpdateQueue.Length - g_iGlickoPeriodUpdateIndex;
    if (remaining <= 0)
    {
        GlickoPeriod_AfterUpdates();
        return;
    }

    Transaction txn = new Transaction();
    int chunk = remaining;
    if (chunk > GLICKO_PERIOD_UPDATE_CHUNK)
        chunk = GLICKO_PERIOD_UPDATE_CHUNK;

    for (int i = 0; i < chunk; i++)
    {
        char query[512];
        g_hGlickoPeriodUpdateQueue.GetString(g_iGlickoPeriodUpdateIndex + i, query, sizeof(query));
        txn.AddQuery(query);
    }

    g_iGlickoPeriodUpdateIndex += chunk;
    g_DB.Execute(txn, GlickoPeriod_OnUpdateChunkOk, GlickoPeriod_OnUpdateChunkFail);
}

void GlickoPeriod_OnUpdateChunkOk(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
    GlickoPeriod_FlushUpdateChunk();
}

void GlickoPeriod_OnUpdateChunkFail(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    LogError("[GlickoPeriod] Stats update chunk failed: %s", error);
    GlickoPeriod_Finish(false);
}

void GlickoPeriod_AfterUpdates()
{
    char query[192];
    g_DB.Format(query, sizeof(query),
        "SELECT COUNT(*) FROM mgemod_duels WHERE period_id=%d AND period_sealed=0",
        g_iGlickoPeriodCloseTarget);
    g_DB.Query(GlickoPeriod_OnLeftoverCount, query);
}

void GlickoPeriod_OnLeftoverCount(Database db, DBResultSet results, const char[] error, any data)
{
    int leftover = 0;
    if (results != null && StrEqual("", error) && results.FetchRow())
        leftover = results.FetchInt(0);

    if (leftover > 0 && g_iGlickoPeriodLeftoverPasses < GLICKO_PERIOD_LEFTOVER_MAX)
    {
        g_iGlickoPeriodLeftoverPasses++;
        g_bGlickoPeriodRecomputeOnly = true;
        GlickoPeriod_FetchPeriodDuels();
        return;
    }

    char query[192];
    g_DB.Format(query, sizeof(query),
        "UPDATE mgemod_period_state SET last_sealed_period_id=%d WHERE id=1",
        g_iGlickoPeriodCloseTarget);
    g_DB.Query(GlickoPeriod_OnSealed, query);
}

void GlickoPeriod_OnSealed(Database db, DBResultSet results, const char[] error, any data)
{
    if (!StrEqual("", error))
        LogError("[GlickoPeriod] Failed to write last_sealed: %s", error);

    g_iGlickoLastSealedPeriodId = g_iGlickoPeriodCloseTarget;
    g_iGlickoPeriodLeftoverPasses = 0;
    GlickoPeriod_NotifyConnectedClients();

    int current = GlickoPeriod_GetId();
    if (g_iGlickoLastSealedPeriodId < current - 1)
    {
        g_iGlickoPeriodCloseTarget = g_iGlickoLastSealedPeriodId + 1;
        g_bGlickoPeriodRecomputeOnly = false;
        g_iGlickoPeriodLeftoverPasses = 0;
        GlickoPeriod_FetchPeriodDuels();
        return;
    }

    GlickoPeriod_Finish(true);
}

void GlickoPeriod_FetchLeftovers()
{
    char query[256];
    g_DB.Format(query, sizeof(query),
        "SELECT COUNT(*) FROM mgemod_duels WHERE period_id > 0 AND period_id <= %d AND period_sealed=0",
        g_iGlickoLastSealedPeriodId);
    g_DB.Query(GlickoPeriod_OnStaleLeftoverCount, query);
}

void GlickoPeriod_OnStaleLeftoverCount(Database db, DBResultSet results, const char[] error, any data)
{
    int leftover = 0;
    if (results != null && StrEqual("", error) && results.FetchRow())
        leftover = results.FetchInt(0);

    if (leftover > 0)
    {
        g_iGlickoPeriodCloseTarget = g_iGlickoLastSealedPeriodId;
        g_iGlickoPeriodLeftoverPasses = 0;
        g_bGlickoPeriodRecomputeOnly = true;
        GlickoPeriod_FetchPeriodDuels();
        return;
    }

    GlickoPeriod_Finish(true);
}

void GlickoPeriod_NotifyConnectedClients()
{
    if (g_hGlickoPeriodPlayers == null)
        return;

    StringMap bySteam = new StringMap();
    for (int i = 0; i < g_hGlickoPeriodPlayers.Length; i++)
    {
        GlickoPeriodPlayer player;
        g_hGlickoPeriodPlayers.GetArray(i, player);
        bySteam.SetArray(player.steamid, player, sizeof(player));
    }

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsValidClient(client) || IsFakeClient(client) || g_sPlayerSteamID[client][0] == '\0')
            continue;

        GlickoPeriodPlayer player;
        if (!bySteam.GetArray(g_sPlayerSteamID[client], player, sizeof(player)))
            continue;

        int oldRating = g_iPlayerRating[client];
        float oldRd = g_fPlayerRD[client];

        g_iPlayerRating[client] = player.newRating;
        g_fPlayerRD[client] = player.newRd;
        g_fPlayerVolatility[client] = player.newVolatility;
        g_iPlayerRatingEst[client] = player.newRating;
        g_fPlayerRDEst[client] = player.newRd;
        g_bPlayerPeriodDirty[client] = false;

        int arena_index = g_iPlayerArena[client];
        if (oldRating != player.newRating || oldRd != player.newRd)
        {
            CallForward_OnPlayerELOChange(client, oldRating, player.newRating, arena_index);
            CallForward_OnPlayerRatingChange(client, oldRating, player.newRating, oldRd, player.newRd, arena_index);
        }
    }

    delete bySteam;
    UpdateHudForAll();
}

void GlickoPeriod_Finish(bool unlock)
{
    #pragma unused unlock
    GlickoPeriod_ClearGameMap();
    delete g_hGlickoPeriodPlayers;
    g_hGlickoPeriodPlayers = null;
    delete g_hGlickoPeriodUpdateQueue;
    g_hGlickoPeriodUpdateQueue = null;
    g_iGlickoPeriodLeftoverPasses = 0;

    if (g_bGlickoPeriodLockHeld && g_DB != null)
    {
        char query[256];
        switch (g_DatabaseType)
        {
            case DB_MYSQL:
                g_DB.Format(query, sizeof(query), "SELECT RELEASE_LOCK('%s')", GLICKO_PERIOD_LOCK_NAME);
            case DB_POSTGRESQL:
                g_DB.Format(query, sizeof(query), "SELECT pg_advisory_unlock(hashtext('%s'))", GLICKO_PERIOD_LOCK_NAME);
            default:
                strcopy(query, sizeof(query), "COMMIT");
        }
        g_DB.Query(SQL_OnGenericQueryFinished, query);
        g_bGlickoPeriodLockHeld = false;
    }

    g_bGlickoPeriodCloseRunning = false;
}

void GlickoPeriod_ClearGameMap()
{
    if (g_hGlickoPeriodGameMap != null)
    {
        StringMapSnapshot snap = g_hGlickoPeriodGameMap.Snapshot();
        int len = snap.Length;
        for (int i = 0; i < len; i++)
        {
            char key[32];
            snap.GetKey(i, key, sizeof(key));
            ArrayList games;
            if (g_hGlickoPeriodGameMap.GetValue(key, games))
                delete games;
        }
        delete snap;
        delete g_hGlickoPeriodGameMap;
        g_hGlickoPeriodGameMap = null;
    }

    delete g_hGlickoPeriodStartMap;
    g_hGlickoPeriodStartMap = null;
}

void GlickoPeriod_RefreshEstimate(int client)
{
    if (g_eRatingEngine != RATING_ENGINE_GLICKO2 || !g_bGlickoPeriodSchemaReady || g_DB == null)
        return;
    if (!IsValidClient(client) || IsFakeClient(client) || g_sPlayerSteamID[client][0] == '\0')
        return;

    int periodId = GlickoPeriod_GetId();
    char query[384];
    g_DB.Format(query, sizeof(query),
        "SELECT winner, loser, winner_sealed_rating, winner_sealed_rd, loser_sealed_rating, loser_sealed_rd FROM mgemod_duels WHERE period_id = %d AND (winner = '%s' OR loser = '%s')",
        periodId, g_sPlayerSteamID[client], g_sPlayerSteamID[client]);

    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteCell(g_iPlayerRating[client]);
    pack.WriteFloat(g_fPlayerRD[client]);
    pack.WriteFloat(g_fPlayerVolatility[client]);
    g_DB.Query(GlickoPeriod_OnEstimateDuels, query, pack);
}

void GlickoPeriod_OnEstimateDuels(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    pack.Reset();
    int userid = pack.ReadCell();
    int sealedRating = pack.ReadCell();
    float sealedRd = pack.ReadFloat();
    float sealedVol = pack.ReadFloat();
    delete pack;

    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client))
        return;

    if (results == null || !StrEqual("", error))
    {
        LogError("[GlickoPeriod] Estimate query failed: %s", error);
        return;
    }

    float oppRating[GLICKO2_MAX_PERIOD_GAMES];
    float oppRd[GLICKO2_MAX_PERIOD_GAMES];
    float score[GLICKO2_MAX_PERIOD_GAMES];
    int count = 0;

    while (results.FetchRow() && count < GLICKO2_MAX_PERIOD_GAMES)
    {
        if (results.IsFieldNull(2) || results.IsFieldNull(4))
            continue;

        char winner[32], loser[32];
        results.FetchString(0, winner, sizeof(winner));
        results.FetchString(1, loser, sizeof(loser));

        if (StrEqual(winner, g_sPlayerSteamID[client]))
        {
            oppRating[count] = float(results.FetchInt(4));
            oppRd[count] = results.FetchFloat(5);
            score[count] = 1.0;
        }
        else
        {
            oppRating[count] = float(results.FetchInt(2));
            oppRd[count] = results.FetchFloat(3);
            score[count] = 0.0;
        }
        count++;
    }

    float newRating = float(sealedRating);
    float newRd = sealedRd;
    float newVol = sealedVol;
    if (count > 0)
        Glicko2_ComputePeriodUpdate(float(sealedRating), sealedRd, sealedVol, count, oppRating, oppRd, score, newRating, newRd, newVol);

    int estRating = RoundFloat(newRating);
    int previousHud = g_bPlayerPeriodDirty[client] ? g_iPlayerRatingEst[client] : sealedRating;
    g_iPlayerRatingEst[client] = estRating;
    g_fPlayerRDEst[client] = newRd;
    g_bPlayerPeriodDirty[client] = (count > 0);

    char query[384];
    g_DB.Format(query, sizeof(query),
        "UPDATE mgemod_stats SET rating_est=%d, rd_est=%f, period_dirty=%d WHERE steamid='%s'",
        estRating, newRd, g_bPlayerPeriodDirty[client] ? 1 : 0, g_sPlayerSteamID[client]);
    g_DB.Query(SQL_OnGenericQueryFinished, query);

    if (IsValidClient(client) && !g_bNoDisplayRating && g_bShowElo[client])
    {
        int delta = estRating - previousHud;
        if (delta >= 0)
            MC_PrintToChat(client, "%t", "GainedRatingNow", delta, estRating);
        else
            MC_PrintToChat(client, "%t", "LostRatingNow", -delta, estRating);
    }

    UpdateHud(client);
}
