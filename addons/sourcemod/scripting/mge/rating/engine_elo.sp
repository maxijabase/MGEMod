
// ===== ELO RATING ENGINE =====
//
// Default rating engine. Identical math to the original CalcELO/CalcELO2, only renamed to
// fit the Rating_ReportResult dispatcher contract. Zero behavior change for servers that
// never touch mgemod_rating_engine.

// Calculates ELO ratings for 1v1 duels and updates player statistics in database
void Engine_Elo_OnMatchResult(int winner, int loser)
{
    if (IsFakeClient(winner) || IsFakeClient(loser) || g_bNoStats || g_bSuppressEloUpdates)
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
    Rating_RecordMatchOutcome(winner, 0, loser, 0);

    // Call ELO change forwards
    int arena_index = g_iPlayerArena[winner];
    CallForward_OnPlayerELOChange(winner, winner_previous_elo, g_iPlayerRating[winner], arena_index);
    CallForward_OnPlayerELOChange(loser, loser_previous_elo, g_iPlayerRating[loser], arena_index);
    int time = GetTime();
    char sCleanArenaname[128], sCleanMapName[128];

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

    char txnQueries[MATCH_TXN_MAX_QUERIES][MATCH_TXN_QUERY_LEN];

    GetInsertDuelQuery(txnQueries[0], MATCH_TXN_QUERY_LEN, g_sPlayerSteamID[winner], g_sPlayerSteamID[loser], g_iArenaScore[arena_index][winner_team_slot], g_iArenaScore[arena_index][loser_team_slot], g_iArenaFraglimit[arena_index], endTime, startTime, g_sMapName, g_sArenaName[arena_index], winnerClass, loserClass, winner_previous_elo, g_iPlayerRating[winner], loser_previous_elo, g_iPlayerRating[loser]);

    // Winner's stats
    GetUpdateWinnerStatsQuery(txnQueries[1], MATCH_TXN_QUERY_LEN, winnerscore, time, g_sPlayerSteamID[winner]);

    // Loser's stats
    GetUpdateLoserStatsQuery(txnQueries[2], MATCH_TXN_QUERY_LEN, -loserscore, time, g_sPlayerSteamID[loser]);

    ExecuteMatchResultQueries(txnQueries, 3);
}

// 2v2 does not move rating. Wins/losses and the 2v2 duel log still persist.
void Engine_Elo_OnMatchResult2v2(int winner, int winner2, int loser, int loser2)
{
    if (IsFakeClient(winner) || IsFakeClient(loser) || g_bNoStats || g_bSuppressEloUpdates || IsFakeClient(loser2) || IsFakeClient(winner2))
        return;

    if (!IsPlayerEligibleForElo(winner) || !IsPlayerEligibleForElo(winner2) ||
        !IsPlayerEligibleForElo(loser) || !IsPlayerEligibleForElo(loser2))
        return;

    int winner_previous_elo = g_iPlayerRating[winner];
    int winner2_previous_elo = g_iPlayerRating[winner2];
    int loser_previous_elo = g_iPlayerRating[loser];
    int loser2_previous_elo = g_iPlayerRating[loser2];

    Rating_RecordMatchOutcome(winner, winner2, loser, loser2);

    int arena_index = g_iPlayerArena[winner];
    int winner_team_slot = (g_iPlayerSlot[winner] > 2) ? (g_iPlayerSlot[winner] - 2) : g_iPlayerSlot[winner];
    int loser_team_slot = (g_iPlayerSlot[loser] > 2) ? (g_iPlayerSlot[loser] - 2) : g_iPlayerSlot[loser];
    int time = GetTime();

    g_iPlayerLastPlayed[winner] = time;
    g_iPlayerLastPlayed[winner2] = time;
    g_iPlayerLastPlayed[loser] = time;
    g_iPlayerLastPlayed[loser2] = time;

    char winnerClass[64], winner2Class[64], loserClass[64], loser2Class[64];
    GetPlayerClassString(winner, arena_index, winnerClass, sizeof(winnerClass));
    GetPlayerClassString(winner2, arena_index, winner2Class, sizeof(winner2Class));
    GetPlayerClassString(loser, arena_index, loserClass, sizeof(loserClass));
    GetPlayerClassString(loser2, arena_index, loser2Class, sizeof(loser2Class));

    int startTime = g_iArenaDuelStartTime[arena_index];

    char txnQueries[MATCH_TXN_MAX_QUERIES][MATCH_TXN_QUERY_LEN];

    GetInsert2v2DuelQuery(txnQueries[0], MATCH_TXN_QUERY_LEN, g_sPlayerSteamID[winner], g_sPlayerSteamID[winner2], g_sPlayerSteamID[loser], g_sPlayerSteamID[loser2], g_iArenaScore[arena_index][winner_team_slot], g_iArenaScore[arena_index][loser_team_slot], g_iArenaFraglimit[arena_index], time, startTime, g_sMapName, g_sArenaName[arena_index], winnerClass, winner2Class, loserClass, loser2Class, winner_previous_elo, winner_previous_elo, winner2_previous_elo, winner2_previous_elo, loser_previous_elo, loser_previous_elo, loser2_previous_elo, loser2_previous_elo);

    GetUpdateWinsOnlyQuery(txnQueries[1], MATCH_TXN_QUERY_LEN, time, g_sPlayerSteamID[winner]);
    GetUpdateWinsOnlyQuery(txnQueries[2], MATCH_TXN_QUERY_LEN, time, g_sPlayerSteamID[winner2]);
    GetUpdateLossesOnlyQuery(txnQueries[3], MATCH_TXN_QUERY_LEN, time, g_sPlayerSteamID[loser]);
    GetUpdateLossesOnlyQuery(txnQueries[4], MATCH_TXN_QUERY_LEN, time, g_sPlayerSteamID[loser2]);

    ExecuteMatchResultQueries(txnQueries, 5);
}
