// ===== ENTITY MANAGEMENT =====

// Setup KOTH capture points for all KOTH arenas during round start
void SetupKothCapturePoints()
{
    for (int i = 0; i <= g_iArenaCount; i++)
    {
        if (g_bArenaKoth[i])
        {
            float point_loc[3];
            point_loc[0] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][0];
            point_loc[1] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][1];
            point_loc[2] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][2];

            if (IsValidEdict(g_iCapturePoint[i]) && g_iCapturePoint[i] > 0)
            {
                RemoveEdict(g_iCapturePoint[i]);
                g_iCapturePoint[i] = -1;
            }
            else if (g_iCapturePoint[i] != -1)
            {
                g_iCapturePoint[i] = -1;
            }

            if (g_iCapturePoint[i] == -1)
            {
                g_iCapturePoint[i] = CreateEntityByName("item_ammopack_small");
                TeleportEntity(g_iCapturePoint[i], point_loc, NULL_VECTOR, NULL_VECTOR);
                DispatchSpawn(g_iCapturePoint[i]);
                SetEntProp(g_iCapturePoint[i], Prop_Send, "m_iTeamNum", 1, 4);
                SetEntityModel(g_iCapturePoint[i], MODEL_POINT);
                DispatchKeyValue(g_iCapturePoint[i], "powerup_model", MODEL_BRIEFCASE);

                SDKHook(g_iCapturePoint[i], SDKHook_StartTouch, OnTouchPoint);
                SDKHook(g_iCapturePoint[i], SDKHook_EndTouch, OnEndTouchPoint);
            }

            AcceptEntityInput(g_iCapturePoint[i], "Disable");
        }
    }
}


// ===== GAME MECHANICS =====

// Process capture point mechanics across all active KOTH arenas
void ProcessKothCapturePoints()
{
    for (int arena_index = 1; arena_index <= g_iArenaCount; ++arena_index)
    {
        if (g_bArenaKoth[arena_index] && g_iArenaStatus[arena_index] == AS_FIGHT)
        {
            ProcessKothArenaCapture(arena_index);
        }
    }
}

// Handle capture logic, timing, and team calculations for a specific arena
void ProcessKothArenaCapture(int arena_index)
{
    g_fTotalTime[arena_index] += 7;
    
    if (g_iPointState[arena_index] == NEUTRAL || g_iPointState[arena_index] == TEAM_BLU)
    {
        // If RED Team is capping and BLU Team isn't and BLU Team has the point increase the cap time
        if (!(g_bPlayerTouchPoint[arena_index][SLOT_TWO] || g_bPlayerTouchPoint[arena_index][SLOT_FOUR]) && (g_iCappingTeam[arena_index] == TEAM_RED || g_iCappingTeam[arena_index] == NEUTRAL))
        {
            int cap = 0;

            if (g_bPlayerTouchPoint[arena_index][SLOT_ONE])
            {
                cap++;
                // If the player is a Scout add one to the cap speed
                if (g_tfctPlayerClass[g_iArenaQueue[arena_index][SLOT_ONE]] == TF2_GetClass("scout"))
                    cap++;

                int ent = GetPlayerWeaponSlot(g_iArenaQueue[arena_index][SLOT_ONE], 2);
                int iItemDefinitionIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");

                // If the player has the Pain Train equipped add one to the cap speed
                if (iItemDefinitionIndex == 154)
                    cap++;
            }
            if (g_bPlayerTouchPoint[arena_index][SLOT_THREE])
            {
                cap++;
                // If the player is a Scout add one to the cap speed
                if (g_tfctPlayerClass[g_iArenaQueue[arena_index][SLOT_THREE]] == TF2_GetClass("scout"))
                    cap++;

                int ent = GetPlayerWeaponSlot(g_iArenaQueue[arena_index][SLOT_THREE], 2);
                int iItemDefinitionIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");

                // If the player has the Pain Train equipped add one to the cap speed
                if (iItemDefinitionIndex == 154)
                    cap++;
            }
            // Add cap time if needed
            if (cap)
            {
                // True harmonic cap time, yes!
                for (; cap > 0; cap--)
                {
                    g_fCappedTime[arena_index] += 7.0 / float(cap);
                }
                g_iCappingTeam[arena_index] = TEAM_RED;
                return;
            }
        }
    }

    if (g_iPointState[arena_index] == NEUTRAL || g_iPointState[arena_index] == TEAM_RED)
    {
        // If BLU Team is capping and Team RED isn't and Team RED has the point increase the cap time
        if (!(g_bPlayerTouchPoint[arena_index][SLOT_ONE] || g_bPlayerTouchPoint[arena_index][SLOT_THREE]) && (g_iCappingTeam[arena_index] == TEAM_BLU || g_iCappingTeam[arena_index] == NEUTRAL))
        {
            int cap = 0;

            if (g_bPlayerTouchPoint[arena_index][SLOT_TWO])
            {
                cap++;
                // If the player is a Scout add one to the cap speed
                if (g_tfctPlayerClass[g_iArenaQueue[arena_index][SLOT_TWO]] == TF2_GetClass("scout"))
                    cap++;

                int ent = GetPlayerWeaponSlot(g_iArenaQueue[arena_index][SLOT_TWO], 2);
                int iItemDefinitionIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");

                // If the player has the Pain Train equipped add one to the cap speed
                if (iItemDefinitionIndex == 154)
                    cap++;
            }
            if (g_bPlayerTouchPoint[arena_index][SLOT_FOUR])
            {
                cap++;
                // If the player is a Scout add one to the cap speed
                if (g_tfctPlayerClass[g_iArenaQueue[arena_index][SLOT_FOUR]] == TF2_GetClass("scout"))
                    cap++;

                int ent = GetPlayerWeaponSlot(g_iArenaQueue[arena_index][SLOT_FOUR], 2);
                int iItemDefinitionIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");

                // If the player has the Pain Train equipped add one to the cap speed
                if (iItemDefinitionIndex == 154)
                    cap++;
            }
            // Add cap time if needed
            if (cap)
            {
                // True harmonic cap time, yes!
                for (; cap > 0; cap--)
                {
                    g_fCappedTime[arena_index] += 7.0 / float(cap);
                }
                g_iCappingTeam[arena_index] = TEAM_BLU;
                return;
            }
        }
    }

    // If BLU Team is blocking and RED Team isn't capping and BLU Team has the point increase the cap diminish rate
    if ((g_bPlayerTouchPoint[arena_index][SLOT_TWO] || g_bPlayerTouchPoint[arena_index][SLOT_FOUR]) &&
        (g_iPointState[arena_index] == NEUTRAL) && g_iCappingTeam[arena_index] == TEAM_RED &&
        !(g_bPlayerTouchPoint[arena_index][SLOT_ONE] || g_bPlayerTouchPoint[arena_index][SLOT_THREE]))
    {
        int cap = 0;

        if (g_bPlayerTouchPoint[arena_index][SLOT_TWO])
        {
            cap++;
            // If the player is a Scout add one to the cap speed
            if (g_tfctPlayerClass[g_iArenaQueue[arena_index][SLOT_TWO]] == TF2_GetClass("scout"))
                cap++;

            int ent = GetPlayerWeaponSlot(g_iArenaQueue[arena_index][SLOT_TWO], 2);
            int iItemDefinitionIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");

            // If the player has the Pain Train equipped add one to the cap speed
            if (iItemDefinitionIndex == 154)
                cap++;
        }
        if (g_bPlayerTouchPoint[arena_index][SLOT_FOUR])
        {
            cap++;
            // If the player is a Scout add one to the cap speed
            if (g_tfctPlayerClass[g_iArenaQueue[arena_index][SLOT_FOUR]] == TF2_GetClass("scout"))
                cap++;

            int ent = GetPlayerWeaponSlot(g_iArenaQueue[arena_index][SLOT_FOUR], 2);
            int iItemDefinitionIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");

            // If the player has the Pain Train equipped add one to the cap speed
            if (iItemDefinitionIndex == 154)
                cap++;
        }
        // Add cap time if needed
        if (cap)
        {
            // True harmonic cap time, yes!
            for (; cap > 0; cap--)
            {
                g_fCappedTime[arena_index] -= 7.0 / float(cap);
            }
            g_iCappingTeam[arena_index] = TEAM_BLU;
            return;
        }
    }

    // If RED Team is blocking and BLU Team isn't capping and RED Team has the point increase the cap diminish rate
    if ((g_bPlayerTouchPoint[arena_index][SLOT_ONE] || g_bPlayerTouchPoint[arena_index][SLOT_THREE]) &&
        (g_iPointState[arena_index] == NEUTRAL) && g_iCappingTeam[arena_index] == TEAM_BLU &&
        !(g_bPlayerTouchPoint[arena_index][SLOT_TWO] || g_bPlayerTouchPoint[arena_index][SLOT_FOUR]))
    {
        int cap = 0;

        if (g_bPlayerTouchPoint[arena_index][SLOT_ONE])
        {
            cap++;
            // If the player is a Scout add one to the cap speed
            if (g_tfctPlayerClass[g_iArenaQueue[arena_index][SLOT_ONE]] == TF2_GetClass("scout"))
                cap++;

            int ent = GetPlayerWeaponSlot(g_iArenaQueue[arena_index][SLOT_ONE], 2);
            int iItemDefinitionIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");

            // If the player has the Pain Train equipped add one to the cap speed
            if (iItemDefinitionIndex == 154)
                cap++;
        }
        if (g_bPlayerTouchPoint[arena_index][SLOT_THREE])
        {
            cap++;
            // If the player is a Scout add one to the cap speed
            if (g_tfctPlayerClass[g_iArenaQueue[arena_index][SLOT_THREE]] == TF2_GetClass("scout"))
                cap++;

            int ent = GetPlayerWeaponSlot(g_iArenaQueue[arena_index][SLOT_THREE], 2);
            int iItemDefinitionIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");

            // If the player has the Pain Train equipped add one to the cap speed
            if (iItemDefinitionIndex == 154)
                cap++;
        }
        // Add cap time if needed
        if (cap)
        {
            // True harmonic cap time, yes!
            for (; cap > 0; cap--)
            {
                g_fCappedTime[arena_index] -= 7.0 / float(cap);
            }
            g_iCappingTeam[arena_index] = TEAM_RED;
            return;
        }
    }

    // If both teams are touching the point, do nothing
    if ((g_bPlayerTouchPoint[arena_index][SLOT_TWO] || g_bPlayerTouchPoint[arena_index][SLOT_FOUR]) && (g_bPlayerTouchPoint[arena_index][SLOT_ONE] || g_bPlayerTouchPoint[arena_index][SLOT_THREE]))
        return;

    // If in overtime, revert cap at 6x speed, if not, revert cap slowly
    if (g_bOvertimePlayed[arena_index][TEAM_RED] || g_bOvertimePlayed[arena_index][TEAM_BLU])
        g_fCappedTime[arena_index] -= 6.0;
    else
        g_fCappedTime[arena_index]--;
}

// Complete KOTH match including win conditions, ELO calculations, and queue management
void EndKoth(any arena_index, any winner_team)
{
    PlayEndgameSoundsToArena(arena_index, winner_team);
    g_iArenaScore[arena_index][winner_team] += 1;
    int fraglimit = g_iArenaFraglimit[arena_index];
    int client = g_iArenaQueue[arena_index][winner_team];
    int client_slot = winner_team;
    int foe_slot = (client_slot == SLOT_ONE || client_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
    int foe = g_iArenaQueue[arena_index][foe_slot];
    int client_teammate;
    int foe_teammate;

    // End the Timer if its still running
    // You shouldn't need to do this, but just incase
    if (g_bTimerRunning[arena_index])
    {
        delete g_tKothTimer[arena_index];
        g_bTimerRunning[arena_index] = false;
    }

    if (g_bFourPersonArena[arena_index])
    {
        client_teammate = GetPlayerTeammate(client_slot, arena_index);
        foe_teammate = GetPlayerTeammate(foe_slot, arena_index);
    }

    if (fraglimit > 0 && g_iArenaScore[arena_index][winner_team] >= fraglimit && g_iArenaStatus[arena_index] >= AS_FIGHT && g_iArenaStatus[arena_index] < AS_REPORTED)
    {
        g_iArenaStatus[arena_index] = AS_REPORTED;
        char foe_name[MAX_NAME_LENGTH];
        GetClientName(foe, foe_name, sizeof(foe_name));
        char client_name[MAX_NAME_LENGTH];
        GetClientName(client, client_name, sizeof(client_name));

        if (g_bFourPersonArena[arena_index])
        {
            char client_teammate_name[128];
            char foe_teammate_name[128];

            GetClientName(client_teammate, client_teammate_name, sizeof(client_teammate_name));
            GetClientName(foe_teammate, foe_teammate_name, sizeof(foe_teammate_name));

            Format(client_name, sizeof(client_name), "%s and %s", client_name, client_teammate_name);
            Format(foe_name, sizeof(foe_name), "%s and %s", foe_name, foe_teammate_name);
        }

        MC_PrintToChatAll("%t", "XdefeatsY", client_name, g_iArenaScore[arena_index][winner_team], foe_name, g_iArenaScore[arena_index][foe_slot], fraglimit, g_sArenaName[arena_index]);

        if (!g_bNoStats && !g_bFourPersonArena[arena_index])
            CalcELO(client, foe);

        else if (!g_bNoStats)
            CalcELO2(client, client_teammate, foe, foe_teammate);

        if (g_bFourPersonArena[arena_index] && g_iArenaQueue[arena_index][SLOT_FOUR + 1])
        {
            RemoveFromQueue(foe, false);
            RemoveFromQueue(foe_teammate, false);
            AddInQueue(foe, arena_index, false, 0, false);
            AddInQueue(foe_teammate, arena_index, false, 0, false);
        }
        else if (g_iArenaQueue[arena_index][SLOT_TWO + 1])
        {
            RemoveFromQueue(foe, false);
            AddInQueue(foe, arena_index, false, 0, false);
        } else {
            // For 2v2 arenas, return to ready state instead of restarting immediately
            if (g_bFourPersonArena[arena_index])
            {
                CreateTimer(3.0, Timer_Restart2v2Ready, arena_index);
            }
            else
            {
                CreateTimer(3.0, Timer_StartDuel, arena_index);
            }
        }
    } else {
        ResetArena(arena_index);

        ResetPlayer(client);
        ResetPlayer(foe);

        if (g_bFourPersonArena[arena_index])
        {
            ResetPlayer(client_teammate);
            ResetPlayer(foe_teammate);
        }

        g_bPlayerTouchPoint[arena_index][SLOT_ONE] = false;
        g_bPlayerTouchPoint[arena_index][SLOT_TWO] = false;
        g_bPlayerTouchPoint[arena_index][SLOT_THREE] = false;
        g_bPlayerTouchPoint[arena_index][SLOT_FOUR] = false;
        g_iKothTimer[arena_index][TEAM_RED] = g_iDefaultCapTime[arena_index];
        g_iKothTimer[arena_index][TEAM_BLU] = g_iDefaultCapTime[arena_index];
        g_fKothCappedPercent[arena_index] = 0.0;
        g_iCappingTeam[arena_index] = NEUTRAL;
        g_iPointState[arena_index] = NEUTRAL;
        g_fCappedTime[arena_index] = 0.0;
        g_bOvertimePlayed[arena_index][TEAM_RED] = false;
        g_bOvertimePlayed[arena_index][TEAM_BLU] = false;
        g_tKothTimer[arena_index] = CreateTimer(1.0, Timer_CountDownKoth, arena_index, TIMER_REPEAT);
        g_bTimerRunning[arena_index] = true;
    }

    UpdateHud(client);
    UpdateHud(foe);

    if (g_bFourPersonArena[arena_index])
    {
        UpdateHud(client_teammate);
        UpdateHud(foe_teammate);
    }
}


// ===== EVENT HANDLERS =====

// When the point is touched
Action OnTouchPoint(int entity, int other)
{
    int client = other;

    if (!IsValidClient(client))
        return Plugin_Continue;

    int arena_index = g_iPlayerArena[client];
    int client_slot = g_iPlayerSlot[client];

    g_bPlayerTouchPoint[arena_index][client_slot] = true;
    return Plugin_Continue;
}

// When the point is no longer touched
Action OnEndTouchPoint(int entity, int other)
{
    int client = other;

    if (!IsValidClient(client))
    {
        return Plugin_Continue;
    }
    int arena_index = g_iPlayerArena[client];
    int client_slot = g_iPlayerSlot[client];

    g_bPlayerTouchPoint[arena_index][client_slot] = false;
    return Plugin_Continue;
}


// ===== COMMANDS =====

// Allow players to switch current arena to KOTH gamemode
Action Command_Koth(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    int arena_index = g_iPlayerArena[client];

    if (!arena_index) {
        MC_PrintToChat(client, "%t", "NotInArena");
        return Plugin_Handled;
    }

    if (g_bArenaKoth[arena_index]) {
        MC_PrintToChat(client, "%t", "ArenaAlreadyKOTH");
        return Plugin_Handled;
    }

    if (!g_bArenaAllowKoth[arena_index]) {
        MC_PrintToChat(client, "%t", "CannotKOTHInArena");
        return Plugin_Handled;
    }

    if (g_iArenaStatus[arena_index] != AS_IDLE) {
        MC_PrintToChat(client, "%t", "CannotSwitchKOTHNow");
        return Plugin_Handled;
    }

    g_bArenaKoth[arena_index] = true;
    g_bArenaMGE[arena_index] = false;
    g_fArenaRespawnTime[arena_index] = 5.0;
    g_iArenaFraglimit[arena_index] = g_iArenaCaplimit[arena_index];
    CreateTimer(1.5, Timer_StartDuel, arena_index);
    UpdateArenaName(arena_index);

    if(g_iArenaQueue[arena_index][SLOT_ONE]) {
        MC_PrintToChat(g_iArenaQueue[arena_index][SLOT_ONE], "%t", "ChangedArenaToKOTH");
    }

    if(g_iArenaQueue[arena_index][SLOT_TWO]) {
        MC_PrintToChat(g_iArenaQueue[arena_index][SLOT_TWO], "%t", "ChangedArenaToKOTH");
    }

    return Plugin_Handled;
}


// ===== UTILITIES =====

// Check if opposing team members are currently touching the capture point
bool EnemyTeamTouching(any team, any arena_index)
{
    if (team == TEAM_RED)
    {
        if (g_bPlayerTouchPoint[arena_index][SLOT_TWO])
            return true;
        else if (g_bFourPersonArena[arena_index] && g_bPlayerTouchPoint[arena_index][SLOT_FOUR])
            return true;
        else
            return false;
    }
    else
    {
        if (g_bPlayerTouchPoint[arena_index][SLOT_ONE])
            return true;
        else if (g_bFourPersonArena[arena_index] && g_bPlayerTouchPoint[arena_index][SLOT_THREE])
            return true;
        else
            return false;
    }
}


// ===== TIMER CALLBACKS =====

// Manage countdown timers, capture progress, overtime logic, and audio cues
Action Timer_CountDownKoth(Handle timer, any arena_index)
{
    // If there was time spent on the point/time spent reverting the point add/remove perecent to the point for however long they were/n't standing on it
    if (g_fCappedTime[arena_index] != 0)
    {
        if (g_fKothCappedPercent[arena_index] == 0 && g_fCappedTime[arena_index] > 0)
        {
            int red_1 = g_iArenaQueue[arena_index][SLOT_ONE];
            int blu_1 = g_iArenaQueue[arena_index][SLOT_TWO];
            char SoundFileTemp[64];
            int num = GetRandomInt(1, 3);
            if (num == 1)
            {
                SoundFileTemp = "vo/announcer_control_point_warning.mp3";
            }
            else if (num == 2)
            {
                SoundFileTemp = "vo/announcer_control_point_warning2.mp3";
            }
            else
            {
                SoundFileTemp = "vo/announcer_control_point_warning3.mp3";
            }

            if (g_iCappingTeam[arena_index] == TEAM_BLU)
            {
                if (IsValidClient(red_1))
                    EmitSoundToClient(red_1, SoundFileTemp);
            }
            else
            {
                if (IsValidClient(blu_1))
                    EmitSoundToClient(blu_1, SoundFileTemp);
            }

            if (g_bFourPersonArena[arena_index])
            {
                int red_2 = g_iArenaQueue[arena_index][SLOT_THREE];
                int blu_2 = g_iArenaQueue[arena_index][SLOT_FOUR];
                if (g_iCappingTeam[arena_index] == TEAM_BLU)
                {
                    if (IsValidClient(red_2))
                        EmitSoundToClient(red_2, SoundFileTemp);
                }
                else
                {
                    if (IsValidClient(blu_2))
                        EmitSoundToClient(blu_2, SoundFileTemp);
                }
            }

        }
        if (g_fTotalTime[arena_index] != 0)
        {
            float cap = (g_fCappedTime[arena_index] * 8.4) / g_fTotalTime[arena_index];
            if (!g_bArenaUltiduo[arena_index])
                cap = cap * 1.5;
            g_fKothCappedPercent[arena_index] += cap;
        }

        g_fCappedTime[arena_index] = 0.0;
    }
    g_fTotalTime[arena_index] = 0.0;
    // If the cap is below 0 then reset it to 0
    if (g_fKothCappedPercent[arena_index] <= 0)
    {
        g_fKothCappedPercent[arena_index] = 0.0;

        if (g_iPointState[arena_index] == NEUTRAL)
            g_iCappingTeam[arena_index] = NEUTRAL;
    }

    if (g_fKothCappedPercent[arena_index] >= 100)
    {
        int red1, red2, blu1, blu2;
        if (g_bFourPersonArena[arena_index])
        {
            red1 = g_iArenaQueue[arena_index][SLOT_ONE];
            red2 = g_iArenaQueue[arena_index][SLOT_THREE];
            blu1 = g_iArenaQueue[arena_index][SLOT_TWO];
            blu2 = g_iArenaQueue[arena_index][SLOT_FOUR];
            if (g_iPointState[arena_index] == TEAM_RED)
            {
                if (IsValidClient(red1))
                    EmitSoundToClient(red1, "vo/announcer_we_lost_control.mp3");
                if (IsValidClient(red2))
                    EmitSoundToClient(red2, "vo/announcer_we_lost_control.mp3");
                if (IsValidClient(blu1))
                    EmitSoundToClient(blu1, "vo/announcer_we_captured_control.mp3");
                if (IsValidClient(blu2))
                    EmitSoundToClient(blu2, "vo/announcer_we_captured_control.mp3");

                g_iCappingTeam[arena_index] = TEAM_RED;
                g_iPointState[arena_index] = TEAM_BLU;
            }

            else if (g_iPointState[arena_index] == TEAM_BLU)
            {
                if (IsValidClient(red1))
                    EmitSoundToClient(red1, "vo/announcer_we_captured_control.mp3");
                if (IsValidClient(red2))
                    EmitSoundToClient(red2, "vo/announcer_we_captured_control.mp3");
                if (IsValidClient(blu1))
                    EmitSoundToClient(blu1, "vo/announcer_we_lost_control.mp3");
                if (IsValidClient(blu2))
                    EmitSoundToClient(blu2, "vo/announcer_we_lost_control.mp3");
                g_iCappingTeam[arena_index] = TEAM_BLU;
                g_iPointState[arena_index] = TEAM_RED;
            }


            else
            {
                if (g_iCappingTeam[arena_index] == TEAM_RED)
                {
                    EmitSoundToClient(red1, "vo/announcer_we_captured_control.mp3");
                    EmitSoundToClient(red2, "vo/announcer_we_captured_control.mp3");
                    g_iPointState[arena_index] = TEAM_RED;
                    g_iCappingTeam[arena_index] = TEAM_BLU;
                }
                else
                {
                    EmitSoundToClient(blu1, "vo/announcer_we_captured_control.mp3");
                    EmitSoundToClient(blu2, "vo/announcer_we_captured_control.mp3");
                    g_iPointState[arena_index] = TEAM_BLU;
                    g_iCappingTeam[arena_index] = TEAM_RED;
                }
            }
        }
        else
        {
            red1 = g_iArenaQueue[arena_index][SLOT_ONE];
            blu1 = g_iArenaQueue[arena_index][SLOT_TWO];
            if (g_iPointState[arena_index] == TEAM_RED)
            {
                EmitSoundToClient(red1, "vo/announcer_we_lost_control.mp3");
                EmitSoundToClient(blu1, "vo/announcer_we_captured_control.mp3");
                g_iCappingTeam[arena_index] = TEAM_RED;
                g_iPointState[arena_index] = TEAM_BLU;
            }

            else if (g_iPointState[arena_index] == TEAM_BLU)
            {
                EmitSoundToClient(red1, "vo/announcer_we_captured_control.mp3");
                EmitSoundToClient(blu1, "vo/announcer_we_lost_control.mp3");
                g_iCappingTeam[arena_index] = TEAM_BLU;
                g_iPointState[arena_index] = TEAM_RED;
            }


            else
            {
                if (g_iCappingTeam[arena_index] == TEAM_RED)
                {
                    EmitSoundToClient(red1, "vo/announcer_we_captured_control.mp3");
                    g_iPointState[arena_index] = TEAM_RED;
                    g_iCappingTeam[arena_index] = TEAM_BLU;
                }
                else
                {
                    EmitSoundToClient(blu1, "vo/announcer_we_captured_control.mp3");
                    g_iPointState[arena_index] = TEAM_BLU;
                    g_iCappingTeam[arena_index] = TEAM_RED;
                }
            }
        }

        g_fKothCappedPercent[arena_index] = 0.0;
    }
    else if (g_iKothTimer[arena_index][g_iPointState[arena_index]] > 0)
    {
        g_iKothTimer[arena_index][g_iPointState[arena_index]]--;
    }

    if (g_iArenaQueue[arena_index][SLOT_ONE])
        UpdateHud(g_iArenaQueue[arena_index][SLOT_ONE]);
    if (g_iArenaQueue[arena_index][SLOT_ONE])
        UpdateHud(g_iArenaQueue[arena_index][SLOT_TWO]);

    if (g_bFourPersonArena[arena_index])
    {
        UpdateHud(g_iArenaQueue[arena_index][SLOT_THREE]);
        UpdateHud(g_iArenaQueue[arena_index][SLOT_FOUR]);
    }

    if (g_iArenaStatus[arena_index] > AS_FIGHT)
    {
        g_bTimerRunning[arena_index] = false;
        return Plugin_Stop;
    }

    // Play the count down sounds
    if (g_iKothTimer[arena_index][g_iPointState[arena_index]] <= 5 && g_iKothTimer[arena_index][g_iPointState[arena_index]] > 0)
    {
        char SoundFile[64];
        switch (g_iKothTimer[arena_index][g_iPointState[arena_index]])
        {
            case 5:
            SoundFile = "vo/announcer_ends_5sec.mp3";
            case 4:
            SoundFile = "vo/announcer_ends_4sec.mp3";
            case 3:
            SoundFile = "vo/announcer_ends_3sec.mp3";
            case 2:
            SoundFile = "vo/announcer_ends_2sec.mp3";
            case 1:
            SoundFile = "vo/announcer_ends_1sec.mp3";
            default:
            SoundFile = "vo/announcer_ends_5sec.mp3";
        }

        if (g_bFourPersonArena[arena_index])
        {
            int red1 = g_iArenaQueue[arena_index][SLOT_ONE];
            int red2 = g_iArenaQueue[arena_index][SLOT_THREE];
            int blu1 = g_iArenaQueue[arena_index][SLOT_TWO];
            int blu2 = g_iArenaQueue[arena_index][SLOT_FOUR];
            EmitSoundToClient(blu1, SoundFile);
            EmitSoundToClient(blu2, SoundFile);
            EmitSoundToClient(red1, SoundFile);
            EmitSoundToClient(red2, SoundFile);
        }
        else
        {
            int red1 = g_iArenaQueue[arena_index][SLOT_ONE];
            int blu1 = g_iArenaQueue[arena_index][SLOT_TWO];
            EmitSoundToClient(blu1, SoundFile);
            EmitSoundToClient(red1, SoundFile);
        }
    }

    // If the point is capped, the timer for the capped team is out and the other team is not touching the point and has no cap time on the point, end the game.
    if (g_iPointState[arena_index] > NEUTRAL && g_iKothTimer[arena_index][g_iPointState[arena_index]] <= 0 && g_fKothCappedPercent[arena_index] <= 0 && !EnemyTeamTouching(g_iPointState[arena_index], arena_index))
    {
        g_bTimerRunning[arena_index] = false;
        // I know this is shit but fuck the police
        EndKoth(arena_index, g_iPointState[arena_index] - 1);
        return Plugin_Stop;
    }
    // If the time is at 0 and a team owns the point and OT hasn't been played already tell the arena it's OT
    if (g_iPointState[arena_index] > NEUTRAL && g_iKothTimer[arena_index][g_iPointState[arena_index]] == 0)
    {
        // Fixes the infinite OT sound bug, so "Overtime!" only gets played once
        if (!g_bOvertimePlayed[arena_index][g_iPointState[arena_index]])
        {

            char SoundFileTemp[64];
            int red1 = g_iArenaQueue[arena_index][SLOT_ONE];
            int blu1 = g_iArenaQueue[arena_index][SLOT_TWO];

            switch (GetRandomInt(1, 4))
            {
                case 1: SoundFileTemp = "vo/announcer_overtime.mp3";
                case 2: SoundFileTemp = "vo/announcer_overtime2.mp3";
                case 3: SoundFileTemp = "vo/announcer_overtime3.mp3";
                case 4: SoundFileTemp = "vo/announcer_overtime4.mp3";
            }

            EmitSoundToClient(blu1, SoundFileTemp);
            EmitSoundToClient(red1, SoundFileTemp);

            if (g_bFourPersonArena[arena_index])
            {
                int blu2 = g_iArenaQueue[arena_index][SLOT_FOUR];
                int red2 = g_iArenaQueue[arena_index][SLOT_THREE];
                EmitSoundToClient(red2, SoundFileTemp);
                EmitSoundToClient(blu2, SoundFileTemp);
            }
            // The overtime sound has been played for this team and doesn't need to be played again for the rest of the round
            g_bOvertimePlayed[arena_index][g_iPointState[arena_index]] = true;
        }
    }

    return Plugin_Continue;
}
