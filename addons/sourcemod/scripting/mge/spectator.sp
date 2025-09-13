
// ===== SPECTATOR HUD MANAGEMENT =====

// Displays arena information and player stats to individual spectator clients
// TODO: refactor mounstrous repeated code mess
void ShowSpecHudToClient(int client)
{
    if (!IsValidClient(client) || !IsValidClient(g_iPlayerSpecTarget[client]) || !g_bShowHud[client])
        return;

    int arena_index = g_iPlayerArena[g_iPlayerSpecTarget[client]];
    int red_f1 = g_iArenaQueue[arena_index][SLOT_ONE];
    int blu_f1 = g_iArenaQueue[arena_index][SLOT_TWO];
    int red_f2;
    int blu_f2;

    if (g_bFourPersonArena[arena_index])
    {
        red_f2 = g_iArenaQueue[arena_index][SLOT_THREE];
        blu_f2 = g_iArenaQueue[arena_index][SLOT_FOUR];
    }

    char hp_report[128];

    // If its a 2v2 arena show the teamates hp's
    if (g_bFourPersonArena[arena_index])
    {
        if (red_f1)
            Format(hp_report, sizeof(hp_report), "%N : %d", red_f1, g_iPlayerHP[red_f1]);

        if (red_f2)
            Format(hp_report, sizeof(hp_report), "%s\n%N : %d", hp_report, red_f2, g_iPlayerHP[red_f2]);

        if (blu_f1)
            Format(hp_report, sizeof(hp_report), "%s\n\n%N : %d", hp_report, blu_f1, g_iPlayerHP[blu_f1]);

        if (blu_f2)
            Format(hp_report, sizeof(hp_report), "%s\n%N : %d", hp_report, blu_f2, g_iPlayerHP[blu_f2]);
    }
    else
    {
        if (red_f1)
            Format(hp_report, sizeof(hp_report), "%N : %d", red_f1, g_iPlayerHP[red_f1]);

        if (blu_f1)
            Format(hp_report, sizeof(hp_report), "%s\n%N : %d", hp_report, blu_f1, g_iPlayerHP[blu_f1]);
    }



    SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 255, 255, 255, 255);
    ShowSyncHudText(client, hm_HP, hp_report);

    // Score
    char report[256];
    SetHudTextParams(0.01, 0.01, HUDFADEOUTTIME, 255, 255, 255, 255);

    int fraglimit = g_iArenaFraglimit[arena_index];

    if (g_iArenaStatus[arena_index] != AS_IDLE)
    {
        if (fraglimit > 0)
            Format(report, sizeof(report), "%s - Frag Limit [%d]", g_sArenaName[arena_index], fraglimit);
        else
            Format(report, sizeof(report), "%s - No Frag Limit", g_sArenaName[arena_index]);
    }
    else
    {
        Format(report, sizeof(report), "%s", g_sArenaName[arena_index]);
    }

    if (g_bFourPersonArena[arena_index])
    {
        // Display RED team (SLOT_ONE and SLOT_THREE)
        if (red_f1 || red_f2)
        {
            if (red_f1 && red_f2)
            {
                // Both RED players present
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client] || !g_b2v2Elo)
                    Format(report, sizeof(report), "%s\n«%N» and «%N» : %d", report, red_f1, red_f2, g_iArenaScore[arena_index][SLOT_ONE]);
                else
                    Format(report, sizeof(report), "%s\n«%N» and «%N» (%d): %d", report, red_f1, red_f2, g_iPlayerRating[red_f1], g_iArenaScore[arena_index][SLOT_ONE]);
            }
            else if (red_f1)
            {
                // Only first RED player present
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n%N : %d", report, red_f1, g_iArenaScore[arena_index][SLOT_ONE]);
                else
                    Format(report, sizeof(report), "%s\n%N (%d): %d", report, red_f1, g_iPlayerRating[red_f1], g_iArenaScore[arena_index][SLOT_ONE]);
            }
            else if (red_f2)
            {
                // Only second RED player present
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n%N : %d", report, red_f2, g_iArenaScore[arena_index][SLOT_ONE]);
                else
                    Format(report, sizeof(report), "%s\n%N (%d): %d", report, red_f2, g_iPlayerRating[red_f2], g_iArenaScore[arena_index][SLOT_ONE]);
            }
        }
        
        // Display BLU team (SLOT_TWO and SLOT_FOUR)
        if (blu_f1 || blu_f2)
        {
            if (blu_f1 && blu_f2)
            {
                // Both BLU players present
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client] || !g_b2v2Elo)
                    Format(report, sizeof(report), "%s\n«%N» and «%N» : %d", report, blu_f1, blu_f2, g_iArenaScore[arena_index][SLOT_TWO]);
                else
                    Format(report, sizeof(report), "%s\n«%N» and «%N» (%d): %d", report, blu_f1, blu_f2, g_iPlayerRating[blu_f1], g_iArenaScore[arena_index][SLOT_TWO]);
            }
            else if (blu_f1)
            {
                // Only first BLU player present
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n%N : %d", report, blu_f1, g_iArenaScore[arena_index][SLOT_TWO]);
                else
                    Format(report, sizeof(report), "%s\n%N (%d): %d", report, blu_f1, g_iPlayerRating[blu_f1], g_iArenaScore[arena_index][SLOT_TWO]);
            }
            else if (blu_f2)
            {
                // Only second BLU player present
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n%N : %d", report, blu_f2, g_iArenaScore[arena_index][SLOT_TWO]);
                else
                    Format(report, sizeof(report), "%s\n%N (%d): %d", report, blu_f2, g_iPlayerRating[blu_f2], g_iArenaScore[arena_index][SLOT_TWO]);
            }
        }
    }

    else
    {
        if (red_f1)
        {
            if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                Format(report, sizeof(report), "%s\n%N : %d", report, red_f1, g_iArenaScore[arena_index][SLOT_ONE]);
            else
                Format(report, sizeof(report), "%s\n%N (%d): %d", report, red_f1, g_iPlayerRating[red_f1], g_iArenaScore[arena_index][SLOT_ONE]);
        }

        if (blu_f1)
        {
            if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                Format(report, sizeof(report), "%s\n%N : %d", report, blu_f1, g_iArenaScore[arena_index][SLOT_TWO]);
            else
                Format(report, sizeof(report), "%s\n%N (%d): %d", report, blu_f1, g_iPlayerRating[blu_f1], g_iArenaScore[arena_index][SLOT_TWO]);
        }
    }

    ShowSyncHudText(client, hm_Score, "%s", report);
}

// Updates HUD display for all spectators watching a specific arena
void ShowSpecHudToArena(int arena_index)
{
    if (!arena_index)
    {
        return;
    }
    for (int i = 1; i <= MaxClients; i++)
    {
        if
        (
            IsValidClient(i)
            && GetClientTeam(i) == TEAM_SPEC
            && g_iPlayerSpecTarget[i] > 0
            && g_iPlayerArena[g_iPlayerSpecTarget[i]] == arena_index
        )
        {
            ShowSpecHudToClient(i);
        }
    }
}

// Displays countdown messages to spectators watching a specific arena
void ShowCountdownToSpec(int arena_index, char[] text)
{
    if (!arena_index)
    {
        return;
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        if
        (
            IsValidClient(i)
            && GetClientTeam(i) == TEAM_SPEC
            && g_iPlayerArena[g_iPlayerSpecTarget[i]] == arena_index
        )
        {
            PrintCenterText(i, text);
        }
    }
}


// ===== TIMER FUNCTIONS =====

// Fixes spectator team assignment issues by cycling through teams
Action Timer_SpecFix(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client))
        return Plugin_Continue;

    ChangeClientTeam(client, TEAM_RED);
    ChangeClientTeam(client, TEAM_SPEC);

    return Plugin_Continue;
}

// Updates spectator HUD for all arenas on a timer basis
Action Timer_SpecHudToAllArenas(Handle timer, int userid)
{
    for (int i = 1; i <= g_iArenaCount; i++)
    ShowSpecHudToArena(i);

    return Plugin_Continue;
}

// Changes dead player to spectator team after delay
Action Timer_ChangePlayerSpec(Handle timer, any player)
{
    if (IsValidClient(player) && !IsPlayerAlive(player))
    {
        ChangeClientTeam(player, TEAM_SPEC);
    }
    
    return Plugin_Continue;
}

// Updates spectator target and refreshes HUD when target changes
Action Timer_ChangeSpecTarget(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (!IsValidClient(client))
    {
        return Plugin_Stop;
    }

    int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

    if (IsValidClient(target) && g_iPlayerArena[target])
    {
        g_iPlayerSpecTarget[client] = target;
        ShowSpecHudToClient(client);
    }
    else
    {
        HideHud(client);
        g_iPlayerSpecTarget[client] = 0;
    }

    return Plugin_Stop;
}

// Shows periodic advertisements to spectators not in arenas
Action Timer_ShowAdv(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (IsValidClient(client) && g_iPlayerArena[client] == 0)
    {
        MC_PrintToChat(client, "%t", "Adv");
        CreateTimer(15.0, Timer_ShowAdv, userid);
    }

    return Plugin_Continue;
}


// ===== PLAYER COMMANDS =====

// Handles spectator command to detect and update spectator target
Action Command_Spec(int client, int args)
{  
    // Detecting spectator target
    if (!IsValidClient(client))
        return Plugin_Handled;

    CreateTimer(0.1, Timer_ChangeSpecTarget, GetClientUserId(client));
    return Plugin_Continue;
}
