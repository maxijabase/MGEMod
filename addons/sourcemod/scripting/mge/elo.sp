
// ===== ELO CALCULATION CORE =====

// Calculates ELO ratings for 1v1 duels and updates player statistics in database
void CalcELO(int winner, int loser)
{
    if (IsFakeClient(winner) || IsFakeClient(loser) || g_bNoStats)
        return;
        
    // Skip ELO calculations if either player has unverified ELO
    if (!IsPlayerEligibleForElo(winner) || !IsPlayerEligibleForElo(loser))
        return;

    // Store previous ELO values before calculating new ones
    int winner_previous_elo = g_iPlayerRating[winner];
    int loser_previous_elo = g_iPlayerRating[loser];

    // ELO formula
    float El = 1 / (Pow(10.0, float((g_iPlayerRating[winner] - g_iPlayerRating[loser])) / 400) + 1);
    int k = (g_iPlayerRating[winner] >= 2400) ? 10 : 15;
    int winnerscore = RoundFloat(k * El);
    g_iPlayerRating[winner] += winnerscore;
    k = (g_iPlayerRating[loser] >= 2400) ? 10 : 15;
    int loserscore = RoundFloat(k * El);
    g_iPlayerRating[loser] -= loserscore;
    
    // Call ELO change forwards
    int arena_index = g_iPlayerArena[winner];
    CallForward_OnPlayerELOChange(winner, winner_previous_elo, g_iPlayerRating[winner], arena_index);
    CallForward_OnPlayerELOChange(loser, loser_previous_elo, g_iPlayerRating[loser], arena_index);
    int time = GetTime();
    char query[1024], sCleanArenaname[128], sCleanMapName[128];

    g_DB.Escape(g_sArenaName[g_iPlayerArena[winner]], sCleanArenaname, sizeof(sCleanArenaname));
    g_DB.Escape(g_sMapName, sCleanMapName, sizeof(sCleanMapName));

    if (IsValidClient(winner) && !g_bNoDisplayRating && g_bShowElo[winner])
        MC_PrintToChat(winner, "%t", "GainedPoints", winnerscore);

    if (IsValidClient(loser) && !g_bNoDisplayRating && g_bShowElo[loser])
        MC_PrintToChat(loser, "%t", "LostPoints", loserscore);

    // This is necessary for when a player leaves a 2v2 arena that is almost done.
    // I don't want to penalize the player that doesn't leave, so only the winners/leavers ELO will be effected.
    int winner_team_slot = (g_iPlayerSlot[winner] > 2) ? (g_iPlayerSlot[winner] - 2) : g_iPlayerSlot[winner];
    int loser_team_slot = (g_iPlayerSlot[loser] > 2) ? (g_iPlayerSlot[loser] - 2) : g_iPlayerSlot[loser];

    // DB entry for this specific duel.
    char winnerClass[64], loserClass[64];
    GetPlayerClassString(winner, arena_index, winnerClass, sizeof(winnerClass));
    GetPlayerClassString(loser, arena_index, loserClass, sizeof(loserClass));
    
    int startTime = g_iArenaDuelStartTime[arena_index];
    int endTime = time;
    
    GetInsertDuelQuery(query, sizeof(query), g_sPlayerSteamID[winner], g_sPlayerSteamID[loser], g_iArenaScore[arena_index][winner_team_slot], g_iArenaScore[arena_index][loser_team_slot], g_iArenaFraglimit[arena_index], endTime, startTime, g_sMapName, g_sArenaName[arena_index], winnerClass, loserClass, winner_previous_elo, g_iPlayerRating[winner], loser_previous_elo, g_iPlayerRating[loser]);
    g_DB.Query(SQL_OnGenericQueryFinished, query);

    // Winner's stats
    GetUpdateWinnerStatsQuery(query, sizeof(query), g_iPlayerRating[winner], time, g_sPlayerSteamID[winner]);
    g_DB.Query(SQL_OnGenericQueryFinished, query);

    // Loser's stats
    GetUpdateLoserStatsQuery(query, sizeof(query), g_iPlayerRating[loser], time, g_sPlayerSteamID[loser]);
    g_DB.Query(SQL_OnGenericQueryFinished, query);
}

// Calculates ELO ratings for 2v2 duels using team-averaged ratings and updates player statistics
void CalcELO2(int winner, int winner2, int loser, int loser2)
{
    if (IsFakeClient(winner) || IsFakeClient(loser) || g_bNoStats || IsFakeClient(loser2) || IsFakeClient(winner2) || !g_b2v2Elo)
        return;
        
    // Skip ELO calculations if any player has unverified ELO
    if (!IsPlayerEligibleForElo(winner) || !IsPlayerEligibleForElo(winner2) || 
        !IsPlayerEligibleForElo(loser) || !IsPlayerEligibleForElo(loser2))
        return;

    // Store previous ELO values before calculating new ones
    int winner_previous_elo = g_iPlayerRating[winner];
    int winner2_previous_elo = g_iPlayerRating[winner2];
    int loser_previous_elo = g_iPlayerRating[loser];
    int loser2_previous_elo = g_iPlayerRating[loser2];

    float Losers_ELO = float((g_iPlayerRating[loser] + g_iPlayerRating[loser2]) / 2);
    float Winners_ELO = float((g_iPlayerRating[winner] + g_iPlayerRating[winner2]) / 2);

    // ELO formula
    float El = 1 / (Pow(10.0, (Winners_ELO - Losers_ELO) / 400) + 1);
    int k = (Winners_ELO >= 2400) ? 10 : 15;
    int winnerscore = RoundFloat(k * El);
    g_iPlayerRating[winner] += winnerscore;
    g_iPlayerRating[winner2] += winnerscore;
    k = (Losers_ELO >= 2400) ? 10 : 15;
    int loserscore = RoundFloat(k * El);
    g_iPlayerRating[loser] -= loserscore;
    g_iPlayerRating[loser2] -= loserscore;
    
    // Call ELO change forwards for all players
    int arena_index = g_iPlayerArena[winner];
    CallForward_OnPlayerELOChange(winner, winner_previous_elo, g_iPlayerRating[winner], arena_index);
    CallForward_OnPlayerELOChange(winner2, winner2_previous_elo, g_iPlayerRating[winner2], arena_index);
    CallForward_OnPlayerELOChange(loser, loser_previous_elo, g_iPlayerRating[loser], arena_index);
    CallForward_OnPlayerELOChange(loser2, loser2_previous_elo, g_iPlayerRating[loser2], arena_index);

    int winner_team_slot = (g_iPlayerSlot[winner] > 2) ? (g_iPlayerSlot[winner] - 2) : g_iPlayerSlot[winner];
    int loser_team_slot = (g_iPlayerSlot[loser] > 2) ? (g_iPlayerSlot[loser] - 2) : g_iPlayerSlot[loser];
    int time = GetTime();
    char query[1024], sCleanArenaname[128], sCleanMapName[128];

    g_DB.Escape(g_sArenaName[g_iPlayerArena[winner]], sCleanArenaname, sizeof(sCleanArenaname));
    g_DB.Escape(g_sMapName, sCleanMapName, sizeof(sCleanMapName));

    if (IsValidClient(winner) && !g_bNoDisplayRating && g_bShowElo[winner])
        MC_PrintToChat(winner, "%t", "GainedPoints", winnerscore);

    if (IsValidClient(winner2) && !g_bNoDisplayRating && g_bShowElo[winner2])
        MC_PrintToChat(winner2, "%t", "GainedPoints", winnerscore);

    if (IsValidClient(loser) && !g_bNoDisplayRating && g_bShowElo[loser])
        MC_PrintToChat(loser, "%t", "LostPoints", loserscore);

    if (IsValidClient(loser2) && !g_bNoDisplayRating && g_bShowElo[loser2])
        MC_PrintToChat(loser2, "%t", "LostPoints", loserscore);


    // DB entry for this specific duel.
    char winnerClass[64], winner2Class[64], loserClass[64], loser2Class[64];
    GetPlayerClassString(winner, arena_index, winnerClass, sizeof(winnerClass));
    GetPlayerClassString(winner2, arena_index, winner2Class, sizeof(winner2Class));
    GetPlayerClassString(loser, arena_index, loserClass, sizeof(loserClass));
    GetPlayerClassString(loser2, arena_index, loser2Class, sizeof(loser2Class));
    
    int startTime = g_iArenaDuelStartTime[arena_index];
    int endTime = time;
    
    GetInsert2v2DuelQuery(query, sizeof(query), g_sPlayerSteamID[winner], g_sPlayerSteamID[winner2], g_sPlayerSteamID[loser], g_sPlayerSteamID[loser2], g_iArenaScore[arena_index][winner_team_slot], g_iArenaScore[arena_index][loser_team_slot], g_iArenaFraglimit[arena_index], endTime, startTime, g_sMapName, g_sArenaName[arena_index], winnerClass, winner2Class, loserClass, loser2Class, winner_previous_elo, g_iPlayerRating[winner], winner2_previous_elo, g_iPlayerRating[winner2], loser_previous_elo, g_iPlayerRating[loser], loser2_previous_elo, g_iPlayerRating[loser2]);
    g_DB.Query(SQL_OnGenericQueryFinished, query);

    // Winner's stats
    GetUpdateWinnerStatsQuery(query, sizeof(query), g_iPlayerRating[winner], time, g_sPlayerSteamID[winner]);
    g_DB.Query(SQL_OnGenericQueryFinished, query);

    // Winner's teammate stats
    GetUpdateWinnerStatsQuery(query, sizeof(query), g_iPlayerRating[winner2], time, g_sPlayerSteamID[winner2]);
    g_DB.Query(SQL_OnGenericQueryFinished, query);

    // Loser's stats
    GetUpdateLoserStatsQuery(query, sizeof(query), g_iPlayerRating[loser], time, g_sPlayerSteamID[loser]);
    g_DB.Query(SQL_OnGenericQueryFinished, query);

    // Loser's teammate stats
    GetUpdateLoserStatsQuery(query, sizeof(query), g_iPlayerRating[loser2], time, g_sPlayerSteamID[loser2]);
    g_DB.Query(SQL_OnGenericQueryFinished, query);
}


// ===== PLAYER COMMANDS =====

// Toggles ELO rating display for individual players and saves preference to cookies
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
