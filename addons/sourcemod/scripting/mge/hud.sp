
// ===== HUD DISPLAY CORE =====

// Displays comprehensive HUD information to active players including health, scores, and game-specific elements
// TODO: refactor repeated code with spectator.sp lines 6-131
void ShowPlayerHud(int client)
{
    if (!IsValidClient(client))
    {
        return;
    }

    // HP
    int arena_index = g_iPlayerArena[client];
    int client_slot = g_iPlayerSlot[client];
    int client_foe_slot = (client_slot == SLOT_ONE || client_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
    int client_foe = (g_iArenaQueue[g_iPlayerArena[client]][(g_iPlayerSlot[client] == SLOT_ONE || g_iPlayerSlot[client] == SLOT_THREE) ? SLOT_TWO : SLOT_ONE]); // Test
    int client_teammate;
    int client_foe2;
    char hp_report[128];

    if (g_bFourPersonArena[arena_index])
    {
        client_teammate = getTeammate(client_slot, arena_index);
        client_foe2 = getTeammate(client_foe_slot, arena_index);
    }

    if (g_bArenaKoth[arena_index])
    {
        /* if (g_iArenaStatus[arena_index] == AS_FIGHT || true) */
        {
            // Show the red team timer, if they have it capped make the timer red
            if (g_iPointState[arena_index] == TEAM_RED)
            {
                SetHudTextParams(0.40, 0.01, HUDFADEOUTTIME, 255, 0, 0, 255); // Red
            }
            else
            {
                SetHudTextParams(0.40, 0.01, HUDFADEOUTTIME, 255, 255, 255, 255);
            }

            // Set the Text for the timer
            ShowSyncHudText(client, hm_KothTimerRED, "%i:%02i", g_iKothTimer[arena_index][TEAM_RED] / 60, g_iKothTimer[arena_index][TEAM_RED] % 60);

            // Show the blue team timer, if they have it capped make the timer blue
            if (g_iPointState[arena_index] == TEAM_BLU)
            {
                SetHudTextParams(0.60, 0.01, HUDFADEOUTTIME, 0, 0, 255, 255); // Blue
            }
            else
            {
                SetHudTextParams(0.60, 0.01, HUDFADEOUTTIME, 255, 255, 255, 255);
            }
            // Set the Text for the timer
            ShowSyncHudText(client, hm_KothTimerBLU, "%i:%02i", g_iKothTimer[arena_index][TEAM_BLU] / 60, g_iKothTimer[arena_index][TEAM_BLU] % 60);

            // Show the capture point percent
            // Set it red if red team is capping
            if (g_iCappingTeam[arena_index] == TEAM_RED)
            {
                SetHudTextParams(0.50, 0.80, HUDFADEOUTTIME, 255, 0, 0, 255); // Red
            }
            // Set it blue if blu team is capping
            else if (g_iCappingTeam[arena_index] == TEAM_BLU)
            {
                SetHudTextParams(0.50, 0.80, HUDFADEOUTTIME, 0, 0, 255, 255); // Blue
            }
            // Set it white if no one is capping
            else
            {
                SetHudTextParams(0.50, 0.80, HUDFADEOUTTIME, 255, 255, 255, 255);
            }
            // Show the text
            ShowSyncHudText(client, hm_KothCap, "Point Capture: %.1f", g_fKothCappedPercent[arena_index]);
        }
    }


    if (g_bArenaShowHPToPlayers[arena_index])
    {
        float hp_ratio = ((float(g_iPlayerHP[client])) / (float(g_iPlayerMaxHP[client]) * g_fArenaHPRatio[arena_index]));
        if (hp_ratio > 0.66)
        {
            SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 0, 255, 0, 255); // Green
        }
        else if (hp_ratio >= 0.33)
        {
            SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 255, 255, 0, 255); // Yellow
        }
        else if (hp_ratio < 0.33)
        {
            SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 255, 0, 0, 255); // Red
        }
        else // SANITY
        {
            SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 255, 255, 255, 255); // White
        }
        ShowSyncHudText(client, hm_HP, "Health : %d", g_iPlayerHP[client]);
    }
    else
    {
        SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 255, 255, 255, 255); // White
        ShowSyncHudText(client, hm_HP, "", g_iPlayerHP[client]);
    }



    if (g_bArenaBBall[arena_index])
    {
        if (g_iArenaStatus[arena_index] == AS_FIGHT)
        {
            char hud_text[128];
            if (g_bPlayerHasIntel[client])
            {
                Format(hud_text, sizeof(hud_text), "%T", "YouHaveTheIntel", client);
                ShowSyncHudText(client, hm_HP, hud_text, g_iPlayerHP[client]);
            }
            else if (g_bFourPersonArena[arena_index] && g_bPlayerHasIntel[client_teammate])
            {
                Format(hud_text, sizeof(hud_text), "%T", "TeammateHasTheIntel", client);
                ShowSyncHudText(client, hm_HP, hud_text, g_iPlayerHP[client]);
            }
            else if (g_bPlayerHasIntel[client_foe] || (g_bFourPersonArena[arena_index] && g_bPlayerHasIntel[client_foe2]))
            {
                Format(hud_text, sizeof(hud_text), "%T", "EnemyHasTheIntel", client);
                ShowSyncHudText(client, hm_HP, hud_text, g_iPlayerHP[client]);
            }
            else
            {
                Format(hud_text, sizeof(hud_text), "%T", "GetTheIntel", client);
                ShowSyncHudText(client, hm_HP, hud_text, g_iPlayerHP[client]);
            }
        }
        else
        {
            ShowSyncHudText(client, hm_HP, "", g_iPlayerHP[client]);
        }
    }

    // We want ammomod players to be able to see what their health is, even when they have the text hud turned off.
    // We also want to show them BBALL notifications
    if (!g_bShowHud[client])
    {
        return;
    }

    // Score
    SetHudTextParams(0.01, 0.01, HUDFADEOUTTIME, 255, 255, 255, 255);
    char report[256];
    BuildArenaScoreReport(arena_index, client, false, report, sizeof(report));
    ShowSyncHudText(client, hm_Score, "%s", report);


    // Hp of teammate
    if (g_bFourPersonArena[arena_index])
    {

        if (client_teammate)
            Format(hp_report, sizeof(hp_report), "%N : %d", client_teammate, g_iPlayerHP[client_teammate]);
    }
    SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 255, 255, 255, 255);
    ShowSyncHudText(client, hm_TeammateHP, hp_report);
}

// Updates HUD display for all players and spectators in a specific arena
void ShowHudToArena(int arena_index)
{
    if (arena_index <= 0 || arena_index > g_iArenaCount)
        return;

    // Update HUD for all players in the arena
    for (int i = SLOT_ONE; i <= (g_bFourPersonArena[arena_index] ? SLOT_FOUR : SLOT_TWO); i++)
    {
        if (g_iArenaQueue[arena_index][i])
        {
            ShowPlayerHud(g_iArenaQueue[arena_index][i]);
        }
    }
    
    // Update HUD for spectators watching this arena
    ShowSpecHudToArena(arena_index);
}

// Updates HUD display for all players and spectators across all arenas
void ShowHudToAll()
{
    for (int i = 1; i <= g_iArenaCount; i++)
    {
        ShowSpecHudToArena(i);
    }

    for (int i = 1; i <= MAXPLAYERS; i++)
    {
        if (g_iPlayerArena[i])
        {
            ShowPlayerHud(i);
        }
    }
}

// Clears HUD elements for a specific client when they disable HUD or leave arena
void HideHud(int client)
{
    if (!IsValidClient(client))
        return;

    ClearSyncHud(client, hm_Score);
    ClearSyncHud(client, hm_HP);
}


// ===== HUD DATA EXTRACTION FUNCTIONS =====

// Retrieves arena player assignments for HUD display
void GetArenaPlayers(int arena_index, int &red_f1, int &blu_f1, int &red_f2, int &blu_f2)
{
    red_f1 = g_iArenaQueue[arena_index][SLOT_ONE];
    blu_f1 = g_iArenaQueue[arena_index][SLOT_TWO];
    red_f2 = 0;
    blu_f2 = 0;
    
    if (g_bFourPersonArena[arena_index])
    {
        red_f2 = g_iArenaQueue[arena_index][SLOT_THREE];
        blu_f2 = g_iArenaQueue[arena_index][SLOT_FOUR];
    }
}

// Retrieves basic arena information for HUD display
void GetArenaBasicInfo(int arena_index, char[] arena_name, int name_size, int &fraglimit, bool &is_2v2, bool &is_bball)
{
    strcopy(arena_name, name_size, g_sArenaName[arena_index]);
    fraglimit = g_iArenaFraglimit[arena_index];
    is_2v2 = g_bFourPersonArena[arena_index];
    is_bball = g_bArenaBBall[arena_index];
}

// Formats a single player's score line with optional ELO display
void FormatPlayerScoreLine(int player, int score, bool show_elo, char[] output, int output_size)
{
    if (!player)
    {
        output[0] = '\0';
        return;
    }
    
    if (g_bNoStats || g_bNoDisplayRating || !show_elo)
        Format(output, output_size, "%N : %d", player, score);
    else
        Format(output, output_size, "%N (%d): %d", player, g_iPlayerRating[player], score);
}

// Formats a team score line for 2v2 with optional ELO display  
void FormatTeamScoreLine(int player1, int player2, int score, bool show_elo, bool show_2v2_elo, char[] output, int output_size)
{
    if (!player1 && !player2)
    {
        output[0] = '\0';
        return;
    }
    
    if (player1 && player2)
    {
        if (g_bNoStats || g_bNoDisplayRating || !show_elo || !show_2v2_elo)
            Format(output, output_size, "«%N» and «%N» : %d", player1, player2, score);
        else
            Format(output, output_size, "«%N» and «%N» (%d): %d", player1, player2, g_iPlayerRating[player1], score);
    }
    else if (player1)
    {
        FormatPlayerScoreLine(player1, score, show_elo && show_2v2_elo, output, output_size);
    }
    else if (player2)
    {
        FormatPlayerScoreLine(player2, score, show_elo && show_2v2_elo, output, output_size);
    }
}

// Formats arena header with name and frag/capture limit information
void FormatArenaHeader(char[] arena_name, int fraglimit, bool is_bball, bool for_spectator, int arena_status, char[] output, int output_size)
{
    if (for_spectator && arena_status == AS_IDLE)
    {
        Format(output, output_size, "%s", arena_name);
        return;
    }
    
    if (fraglimit > 0)
    {
        if (is_bball)
            Format(output, output_size, "%s - Capture Limit [%d]", arena_name, fraglimit);
        else
            Format(output, output_size, "%s - Frag Limit [%d]", arena_name, fraglimit);
    }
    else
    {
        if (is_bball)
            Format(output, output_size, "%s - No Capture Limit", arena_name);
        else
            Format(output, output_size, "%s - No Frag Limit", arena_name);
    }
}

// Builds complete arena score report for both players and spectators
void BuildArenaScoreReport(int arena_index, int client, bool for_spectator, char[] output, int output_size)
{
    char arena_name[64];
    int fraglimit;
    bool is_2v2, is_bball;
    GetArenaBasicInfo(arena_index, arena_name, sizeof(arena_name), fraglimit, is_2v2, is_bball);
    
    int red_f1, blu_f1, red_f2, blu_f2;
    GetArenaPlayers(arena_index, red_f1, blu_f1, red_f2, blu_f2);
    
    char header[128];
    FormatArenaHeader(arena_name, fraglimit, is_bball, for_spectator, g_iArenaStatus[arena_index], header, sizeof(header));
    strcopy(output, output_size, header);
    
    bool show_elo = g_bShowElo[client];
    
    if (is_2v2)
    {
        char red_line[128], blu_line[128];
        
        if (red_f1 || red_f2)
        {
            FormatTeamScoreLine(red_f1, red_f2, g_iArenaScore[arena_index][SLOT_ONE], show_elo, g_b2v2Elo, red_line, sizeof(red_line));
            if (red_line[0] != '\0')
                Format(output, output_size, "%s\n%s", output, red_line);
        }
        
        if (blu_f1 || blu_f2)
        {
            FormatTeamScoreLine(blu_f1, blu_f2, g_iArenaScore[arena_index][SLOT_TWO], show_elo, g_b2v2Elo, blu_line, sizeof(blu_line));
            if (blu_line[0] != '\0')
                Format(output, output_size, "%s\n%s", output, blu_line);
        }
    }
    else
    {
        char red_line[128], blu_line[128];
        
        FormatPlayerScoreLine(red_f1, g_iArenaScore[arena_index][SLOT_ONE], show_elo, red_line, sizeof(red_line));
        if (red_line[0] != '\0')
            Format(output, output_size, "%s\n%s", output, red_line);
        
        FormatPlayerScoreLine(blu_f1, g_iArenaScore[arena_index][SLOT_TWO], show_elo, blu_line, sizeof(blu_line));
        if (blu_line[0] != '\0')
            Format(output, output_size, "%s\n%s", output, blu_line);
    }
}


// ===== PLAYER COMMANDS =====

// Toggles HUD display on/off for individual players and saves preference
Action Command_ToggleHud(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    g_bShowHud[client] = !g_bShowHud[client];

    if (g_bShowHud[client])
    {
        if (g_iPlayerArena[client])
            ShowPlayerHud(client);
        else
            ShowSpecHudToClient(client);
    }
    else
    {
        HideHud(client);
    }

    char status_text[32];
    Format(status_text, sizeof(status_text), "%T", g_bShowHud[client] ? "EnabledLabel" : "DisabledLabel", client);
    MC_PrintToChat(client, "%t", "HudToggle", status_text);
    return Plugin_Handled;
}
