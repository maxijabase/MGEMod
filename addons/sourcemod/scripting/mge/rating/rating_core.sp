// ===== RATING ENGINE DISPATCHER =====
//
// Single entry point match flow code calls to report a finished duel. Callers never know
// which engine (Elo or Glicko-2) actually computed the new numbers - that decision is made
// here based on the mgemod_rating_engine convar, the same switch-on-enum pattern already
// used for g_DatabaseType in sql.sp.

// Reports a finished duel result to the active rating engine.
// winner2/loser2 of 0 means a 1v1-shaped result (used both by real 1v1 arenas and by the
// 2v2 early-leave path, which credits/debits individual players rather than full teams).
// Engines derive the arena index themselves from g_iPlayerArena[winner1], so it isn't taken here.
void Rating_ReportResult(int winner1, int winner2, int loser1, int loser2)
{
    if (g_bNoStats || g_bSuppressEloUpdates)
        return;

    bool is2v2 = (winner2 > 0 && loser2 > 0);

    switch (g_eRatingEngine)
    {
        case RATING_ENGINE_GLICKO2:
        {
            if (is2v2)
                Engine_Glicko2_OnMatchResult2v2(winner1, winner2, loser1, loser2);
            else
                Engine_Glicko2_OnMatchResult(winner1, loser1);
        }
        default:
        {
            if (is2v2)
                Engine_Elo_OnMatchResult2v2(winner1, winner2, loser1, loser2);
            else
                Engine_Elo_OnMatchResult(winner1, loser1);
        }
    }
}

// Returns the number to show/gate on for a player, regardless of active engine.
// Elo: the raw rating. Glicko-2: a conservative rating (rating - 2*RD), the standard
// Glicko display convention that keeps unproven players from looking artificially strong.
int Rating_GetDisplayValue(int client)
{
    if (g_eRatingEngine == RATING_ENGINE_GLICKO2 && g_bPlayerGlickoSeeded[client])
        return RoundToNearest(float(g_iPlayerRating[client]) - 2.0 * g_fPlayerRD[client]);

    return g_iPlayerRating[client];
}

// Whether this player's rating is still provisional (not enough games / too much inactivity
// to trust it). Always false under Elo, which has no notion of confidence.
bool Rating_IsProvisional(int client)
{
    if (g_eRatingEngine != RATING_ENGINE_GLICKO2)
        return false;

    if (!g_bPlayerGlickoSeeded[client])
        return true;

    return g_fPlayerRD[client] > g_fGlickoProvisionalRd;
}

// Builds the top players leaderboard query using the active engine's display value.
void Rating_GetLeaderboardQuery(char[] query, int maxlen)
{
    if (g_eRatingEngine == RATING_ENGINE_GLICKO2)
        g_DB.Format(query, maxlen, "SELECT (rating - 2 * COALESCE(rd, 0)) AS display_rating, name, wins, losses FROM mgemod_stats ORDER BY display_rating DESC");
    else
        g_DB.Format(query, maxlen, "SELECT rating, name, wins, losses FROM mgemod_stats ORDER BY rating DESC");
}

// Builds the rating-rank query (used by !rank) using the active engine's display value.
void Rating_GetRankQuery(char[] query, int maxlen, const char[] steamid)
{
    if (g_eRatingEngine == RATING_ENGINE_GLICKO2)
        g_DB.Format(query, maxlen, "SELECT COUNT(*) + 1 FROM mgemod_stats WHERE (rating - 2 * COALESCE(rd, 0)) > (SELECT (rating - 2 * COALESCE(rd, 0)) FROM mgemod_stats WHERE steamid='%s')", steamid);
    else
        g_DB.Format(query, maxlen, "SELECT COUNT(*) + 1 FROM mgemod_stats WHERE rating > (SELECT rating FROM mgemod_stats WHERE steamid='%s')", steamid);
}

// Estimated win chance of "client" against "target", used by the !rank panel.
// Elo: the classic logistic curve. Glicko-2: the same curve but discounted by both
// players' rating deviations via g(RD), so two provisional players show a chance closer to 50%.
float Rating_GetWinChance(int client, int target)
{
    if (g_eRatingEngine == RATING_ENGINE_GLICKO2)
    {
        float combinedRd = SquareRoot((g_fPlayerRD[client] * g_fPlayerRD[client]) + (g_fPlayerRD[target] * g_fPlayerRD[target]));
        float phi = combinedRd / GLICKO2_SCALE;
        float g = Glicko2_G(phi);
        return 1.0 / (Pow(10.0, -g * float(g_iPlayerRating[client] - g_iPlayerRating[target]) / 400.0) + 1.0);
    }

    return 1.0 / (Pow(10.0, float(g_iPlayerRating[target] - g_iPlayerRating[client]) / 400) + 1);
}


// ===== PLAYER COMMANDS =====

// Toggles rating display for individual players and saves preference to cookies.
// Engine-agnostic: works the same whether the active engine is Elo or Glicko-2.
Action Command_ToggleElo(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Continue;

    g_bShowElo[client] = !g_bShowElo[client];

    // Save the preference to client cookie
    g_hShowEloCookie.Set(client, g_bShowElo[client] ? "1" : "0");

    char status_text[32];
    Format(status_text, sizeof(status_text), "%T", g_bShowElo[client] ? "EnabledLabel" : "DisabledLabel", client);
    MC_PrintToChat(client, "%t", "EloToggle", status_text);
    
    // Refresh the appropriate HUD based on player's current state
    int arena_index = g_iPlayerArena[client];
    int player_slot = g_iPlayerSlot[client];
    
    if (arena_index > 0 && player_slot > 0)
    {
        // Player is actively in an arena - show player HUD
        UpdateHud(client);
    }
    else if (TF2_GetClientTeam(client) == TFTeam_Spectator && g_iPlayerSpecTarget[client] > 0)
    {
        // Player is spectating someone - show spectator HUD
        UpdateHud(client);
    }
    
    return Plugin_Handled;
}
