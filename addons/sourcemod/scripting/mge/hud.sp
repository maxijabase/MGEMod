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
            if (g_bPlayerHasIntel[client])
            {
                ShowSyncHudText(client, hm_HP, "You have the intel!", g_iPlayerHP[client]);
            }
            else if (g_bFourPersonArena[arena_index] && g_bPlayerHasIntel[client_teammate])
            {
                ShowSyncHudText(client, hm_HP, "Your teammate has the intel!", g_iPlayerHP[client]);
            }
            else if (g_bPlayerHasIntel[client_foe] || (g_bFourPersonArena[arena_index] && g_bPlayerHasIntel[client_foe2]))
            {
                ShowSyncHudText(client, hm_HP, "Enemy has the intel!", g_iPlayerHP[client]);
            }
            else
            {
                ShowSyncHudText(client, hm_HP, "Get the intel!", g_iPlayerHP[client]);
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
    int fraglimit = g_iArenaFraglimit[arena_index];

    if (g_bArenaBBall[arena_index])
    {
        if (fraglimit > 0)
            Format(report, sizeof(report), "%s - Capture Limit [%d]", g_sArenaName[arena_index], fraglimit);
        else
            Format(report, sizeof(report), "%s - No Capture Limit", g_sArenaName[arena_index]);
    } else {
        if (fraglimit > 0)
            Format(report, sizeof(report), "%s - Frag Limit [%d]", g_sArenaName[arena_index], fraglimit);
        else
            Format(report, sizeof(report), "%s - No Frag Limit", g_sArenaName[arena_index]);
    }

    int red_f1 = g_iArenaQueue[arena_index][SLOT_ONE];
    int blu_f1 = g_iArenaQueue[arena_index][SLOT_TWO];
    int red_f2;
    int blu_f2;
    if (g_bFourPersonArena[arena_index])
    {
        red_f2 = g_iArenaQueue[arena_index][SLOT_THREE];
        blu_f2 = g_iArenaQueue[arena_index][SLOT_FOUR];
    }

    if (g_bFourPersonArena[arena_index])
    {
        if (red_f1)
        {
            if (red_f2)
            {
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n«%N» and «%N» : %d", report, red_f1, red_f2, g_iArenaScore[arena_index][SLOT_ONE]);
                else
                    Format(report, sizeof(report), "%s\n«%N» and «%N» (%d): %d", report, red_f1, red_f2, g_iPlayerRating[red_f1], g_iArenaScore[arena_index][SLOT_ONE]);
            }
            else
            {
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n%N : %d", report, red_f1, g_iArenaScore[arena_index][SLOT_ONE]);
                else
                    Format(report, sizeof(report), "%s\n%N (%d): %d", report, red_f1, g_iPlayerRating[red_f1], g_iArenaScore[arena_index][SLOT_ONE]);
            }


        }
        if (blu_f1)
        {
            if (blu_f2)
            {
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n«%N» and «%N» : %d", report, blu_f1, blu_f2, g_iArenaScore[arena_index][SLOT_TWO]);
                else
                    Format(report, sizeof(report), "%s\n«%N» and «%N» (%d): %d", report, blu_f1, blu_f2, g_iPlayerRating[blu_f1], g_iArenaScore[arena_index][SLOT_TWO]);
            }
            else
            {
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n%N : %d", report, blu_f1, g_iArenaScore[arena_index][SLOT_TWO]);
                else
                    Format(report, sizeof(report), "%s\n%N (%d): %d", report, blu_f1, g_iPlayerRating[blu_f1], g_iArenaScore[arena_index][SLOT_TWO]);
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


    // Hp of teammate
    if (g_bFourPersonArena[arena_index])
    {

        if (client_teammate)
            Format(hp_report, sizeof(hp_report), "%N : %d", client_teammate, g_iPlayerHP[client_teammate]);
    }
    SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 255, 255, 255, 255);
    ShowSyncHudText(client, hm_TeammateHP, hp_report);
}

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
        Format(report, sizeof(report), "Arena[%s]", g_sArenaName[arena_index]);
    }

    if (g_bFourPersonArena[arena_index])
    {
        if (red_f1)
        {
            if (red_f2)
            {
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n«%N» and «%N» : %d", report, red_f1, red_f2, g_iArenaScore[arena_index][SLOT_ONE]);
                else
                    Format(report, sizeof(report), "%s\n«%N» and «%N» (%d): %d", report, red_f1, red_f2, g_iPlayerRating[red_f1], g_iArenaScore[arena_index][SLOT_ONE]);
            }
            else
            {
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n%N : %d", report, red_f1, g_iArenaScore[arena_index][SLOT_ONE]);
                else
                    Format(report, sizeof(report), "%s\n%N (%d): %d", report, red_f1, g_iPlayerRating[red_f1], g_iArenaScore[arena_index][SLOT_ONE]);
            }


        }
        if (blu_f1)
        {
            if (blu_f2)
            {
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n«%N» and «%N» : %d", report, blu_f1, blu_f2, g_iArenaScore[arena_index][SLOT_TWO]);
                else
                    Format(report, sizeof(report), "%s\n«%N» and «%N» (%d): %d", report, blu_f1, blu_f2, g_iPlayerRating[blu_f1], g_iArenaScore[arena_index][SLOT_TWO]);
            }
            else
            {
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n%N : %d", report, blu_f1, g_iArenaScore[arena_index][SLOT_TWO]);
                else
                    Format(report, sizeof(report), "%s\n%N (%d): %d", report, blu_f1, g_iPlayerRating[blu_f1], g_iArenaScore[arena_index][SLOT_TWO]);
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

void HideHud(int client)
{
    if (!IsValidClient(client))
        return;

    ClearSyncHud(client, hm_Score);
    ClearSyncHud(client, hm_HP);
}