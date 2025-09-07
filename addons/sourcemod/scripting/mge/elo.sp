void CalcELO(int winner, int loser)
{
    if (IsFakeClient(winner) || IsFakeClient(loser) || g_bNoStats)
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

    int arena_index = g_iPlayerArena[winner];
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
    
    if (g_bUseSQLite)
    {
        g_DB.Format(query, sizeof(query), "INSERT INTO mgemod_duels VALUES (NULL, '%s', '%s', %i, %i, %i, %i, %i, '%s', '%s', '%s', '%s', %i, %i, %i, %i)",
            g_sPlayerSteamID[winner], g_sPlayerSteamID[loser], g_iArenaScore[arena_index][winner_team_slot], g_iArenaScore[arena_index][loser_team_slot], g_iArenaFraglimit[arena_index], endTime, startTime, g_sMapName, g_sArenaName[arena_index], winnerClass, loserClass, winner_previous_elo, g_iPlayerRating[winner], loser_previous_elo, g_iPlayerRating[loser]);
        g_DB.Query(SQL_OnGenericQueryFinished, query);
    } else {
        g_DB.Format(query, sizeof(query), "INSERT INTO mgemod_duels (winner, loser, winnerscore, loserscore, winlimit, endtime, starttime, mapname, arenaname, winnerclass, loserclass, winner_previous_elo, winner_new_elo, loser_previous_elo, loser_new_elo) VALUES ('%s', '%s', %i, %i, %i, %i, %i, '%s', '%s', '%s', '%s', %i, %i, %i, %i)",
            g_sPlayerSteamID[winner], g_sPlayerSteamID[loser], g_iArenaScore[arena_index][winner_team_slot], g_iArenaScore[arena_index][loser_team_slot], g_iArenaFraglimit[arena_index], endTime, startTime, g_sMapName, g_sArenaName[arena_index], winnerClass, loserClass, winner_previous_elo, g_iPlayerRating[winner], loser_previous_elo, g_iPlayerRating[loser]);
        g_DB.Query(SQL_OnGenericQueryFinished, query);
    }

    // Winner's stats
    g_DB.Format(query, sizeof(query), "UPDATE mgemod_stats SET rating=%i,wins=wins+1,lastplayed=%i WHERE steamid='%s'",
        g_iPlayerRating[winner], time, g_sPlayerSteamID[winner]);
    g_DB.Query(SQL_OnGenericQueryFinished, query);

    // Loser's stats
    g_DB.Format(query, sizeof(query), "UPDATE mgemod_stats SET rating=%i,losses=losses+1,lastplayed=%i WHERE steamid='%s'",
        g_iPlayerRating[loser], time, g_sPlayerSteamID[loser]);
    g_DB.Query(SQL_OnGenericQueryFinished, query);
}

void CalcELO2(int winner, int winner2, int loser, int loser2)
{
    if (IsFakeClient(winner) || IsFakeClient(loser) || g_bNoStats || IsFakeClient(loser2) || IsFakeClient(winner2))
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

    int winner_team_slot = (g_iPlayerSlot[winner] > 2) ? (g_iPlayerSlot[winner] - 2) : g_iPlayerSlot[winner];
    int loser_team_slot = (g_iPlayerSlot[loser] > 2) ? (g_iPlayerSlot[loser] - 2) : g_iPlayerSlot[loser];

    int arena_index = g_iPlayerArena[winner];
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
    
    if (g_bUseSQLite)
    {
        g_DB.Format(query, sizeof(query), "INSERT INTO mgemod_duels_2v2 VALUES (NULL, '%s', '%s', '%s', '%s', %i, %i, %i, %i, %i, '%s', '%s', '%s', '%s', '%s', '%s', %i, %i, %i, %i, %i, %i, %i, %i)",
            g_sPlayerSteamID[winner], g_sPlayerSteamID[winner2], g_sPlayerSteamID[loser], g_sPlayerSteamID[loser2], g_iArenaScore[arena_index][winner_team_slot], g_iArenaScore[arena_index][loser_team_slot], g_iArenaFraglimit[arena_index], endTime, startTime, g_sMapName, g_sArenaName[arena_index], winnerClass, winner2Class, loserClass, loser2Class, winner_previous_elo, g_iPlayerRating[winner], winner2_previous_elo, g_iPlayerRating[winner2], loser_previous_elo, g_iPlayerRating[loser], loser2_previous_elo, g_iPlayerRating[loser2]);
        g_DB.Query(SQL_OnGenericQueryFinished, query);
    } else {
        g_DB.Format(query, sizeof(query), "INSERT INTO mgemod_duels_2v2 (winner, winner2, loser, loser2, winnerscore, loserscore, winlimit, endtime, starttime, mapname, arenaname, winnerclass, winner2class, loserclass, loser2class, winner_previous_elo, winner_new_elo, winner2_previous_elo, winner2_new_elo, loser_previous_elo, loser_new_elo, loser2_previous_elo, loser2_new_elo) VALUES ('%s', '%s', '%s', '%s', %i, %i, %i, %i, %i, '%s', '%s', '%s', '%s', '%s', '%s', %i, %i, %i, %i, %i, %i, %i, %i)",
            g_sPlayerSteamID[winner], g_sPlayerSteamID[winner2], g_sPlayerSteamID[loser], g_sPlayerSteamID[loser2], g_iArenaScore[arena_index][winner_team_slot], g_iArenaScore[arena_index][loser_team_slot], g_iArenaFraglimit[arena_index], endTime, startTime, g_sMapName, g_sArenaName[arena_index], winnerClass, winner2Class, loserClass, loser2Class, winner_previous_elo, g_iPlayerRating[winner], winner2_previous_elo, g_iPlayerRating[winner2], loser_previous_elo, g_iPlayerRating[loser], loser2_previous_elo, g_iPlayerRating[loser2]);
        g_DB.Query(SQL_OnGenericQueryFinished, query);
    }

    // Winner's stats
    g_DB.Format(query, sizeof(query), "UPDATE mgemod_stats SET rating=%i,wins=wins+1,lastplayed=%i WHERE steamid='%s'",
        g_iPlayerRating[winner], time, g_sPlayerSteamID[winner]);
    g_DB.Query(SQL_OnGenericQueryFinished, query);

    // Winner's teammate stats
    g_DB.Format(query, sizeof(query), "UPDATE mgemod_stats SET rating=%i,wins=wins+1,lastplayed=%i WHERE steamid='%s'",
        g_iPlayerRating[winner2], time, g_sPlayerSteamID[winner2]);
    g_DB.Query(SQL_OnGenericQueryFinished, query);

    // Loser's stats
    g_DB.Format(query, sizeof(query), "UPDATE mgemod_stats SET rating=%i,losses=losses+1,lastplayed=%i WHERE steamid='%s'",
        g_iPlayerRating[loser], time, g_sPlayerSteamID[loser]);
    g_DB.Query(SQL_OnGenericQueryFinished, query);

    // Loser's teammate stats
    g_DB.Format(query, sizeof(query), "UPDATE mgemod_stats SET rating=%i,losses=losses+1,lastplayed=%i WHERE steamid='%s'",
        g_iPlayerRating[loser2], time, g_sPlayerSteamID[loser2]);
    g_DB.Query(SQL_OnGenericQueryFinished, query);
}