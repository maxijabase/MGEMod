Action OnTouchIntel(int entity, int other)
{
    int client = other;

    if (!IsValidClient(client))
        return Plugin_Continue;

    if (!g_bCanPlayerGetIntel[client])
        return Plugin_Continue;

    int arena_index = g_iPlayerArena[client];
    g_bPlayerHasIntel[client] = true;
    char msg[64];
    Format(msg, sizeof(msg), "You have the intel!");
    PrintCenterText(client, msg);

    if (entity == g_iBBallIntel[arena_index] && IsValidEdict(g_iBBallIntel[arena_index]) && g_iBBallIntel[arena_index] > 0)
    {
        // SDKUnhook(g_iBBallIntel[arena_index], SDKHook_StartTouch, OnTouchIntel);
        RemoveEdict(g_iBBallIntel[arena_index]);
        g_iBBallIntel[arena_index] = -1;
    }

    int particle;
    TFTeam team = TF2_GetClientTeam(client);

    // Create a fancy lightning effect to make it abundantly clear that the intel has just been picked up.
    AttachParticle(client, team == TFTeam_Red ? "teleported_red" : "teleported_blue", particle);

    // Attach a team-colored particle to give a visual cue that a player is holding the intel, since we can't attach models.
    particle = EntRefToEntIndex(g_iClientParticle[client]);
    if (particle == 0 || !IsValidEntity(particle))
    {
        AttachParticle(client, team == TFTeam_Red ? g_sBBallParticleRed : g_sBBallParticleBlue, particle);
        g_iClientParticle[client] = EntIndexToEntRef(particle);
    }

    ShowPlayerHud(client);
    EmitSoundToClient(client, "vo/intel_teamstolen.mp3");

    int foe = g_iArenaQueue[g_iPlayerArena[client]][(g_iPlayerSlot[client] == SLOT_ONE || g_iPlayerSlot[client] == SLOT_THREE) ? SLOT_TWO : SLOT_ONE];

    if (IsValidClient(foe))
    {
        EmitSoundToClient(foe, "vo/intel_enemystolen.mp3");
        ShowPlayerHud(foe);
    }

    if (g_bFourPersonArena[g_iPlayerArena[client]])
    {
        int foe2 = g_iArenaQueue[g_iPlayerArena[client]][(g_iPlayerSlot[client] == SLOT_ONE || g_iPlayerSlot[client] == SLOT_THREE) ? SLOT_FOUR : SLOT_THREE];
        if (IsValidClient(foe2))
        {
            EmitSoundToClient(foe2, "vo/intel_enemystolen.mp3");
            ShowPlayerHud(foe2);
        }
    }

    return Plugin_Continue;
}

// When a hoop is touched by a player in BBall.
Action OnTouchHoop(int entity, int other)
{
    int client = other;

    if (!IsValidClient(client))
        return Plugin_Continue;

    int arena_index = g_iPlayerArena[client];
    int fraglimit = g_iArenaFraglimit[arena_index];
    int client_slot = g_iPlayerSlot[client];
    int foe_slot = (client_slot == SLOT_ONE || client_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
    int foe = g_iArenaQueue[arena_index][foe_slot];
    int client_teammate;
    int foe_teammate;
    int foe_team_slot = (foe_slot > 2) ? (foe_slot - 2) : foe_slot;
    int client_team_slot = (client_slot > 2) ? (client_slot - 2) : client_slot;

    if (g_bFourPersonArena[arena_index])
    {
        client_teammate = getTeammate(client_slot, arena_index);
        foe_teammate = getTeammate(foe_slot, arena_index);
    }



    if (!IsValidClient(foe) || !g_bArenaBBall[arena_index])
        return Plugin_Continue;

    if (entity == g_iBBallHoop[arena_index][foe_slot] && g_bPlayerHasIntel[client])
    {
        // Remove the particle effect attached to the player carrying the intel.
        RemoveClientParticle(client);

        char foe_name[MAX_NAME_LENGTH];
        GetClientName(foe, foe_name, sizeof(foe_name));
        char client_name[MAX_NAME_LENGTH];
        GetClientName(client, client_name, sizeof(client_name));

        MC_PrintToChat(client, "%t", "bballdunk", foe_name);

        g_bPlayerHasIntel[client] = false;
        g_iArenaScore[arena_index][client_team_slot] += 1;

        if (fraglimit > 0 && g_iArenaScore[arena_index][client_team_slot] >= fraglimit && g_iArenaStatus[arena_index] >= AS_FIGHT && g_iArenaStatus[arena_index] < AS_REPORTED)
        {
            g_iArenaStatus[arena_index] = AS_REPORTED;
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

            MC_PrintToChatAll("%t", "XdefeatsY", client_name, g_iArenaScore[arena_index][client_team_slot], foe_name, g_iArenaScore[arena_index][foe_team_slot], fraglimit, g_sArenaName[arena_index]);

            if (!g_bNoStats && !g_bFourPersonArena[arena_index])
                CalcELO(client, foe);

            else if (!g_bNoStats)
                CalcELO2(client, client_teammate, foe, foe_teammate);

            if (IsValidEdict(g_iBBallIntel[arena_index]) && g_iBBallIntel[arena_index] > -1)
            {
                // SDKUnhook(g_iBBallIntel[arena_index], SDKHook_StartTouch, OnTouchIntel);
                RemoveEdict(g_iBBallIntel[arena_index]);
                g_iBBallIntel[arena_index] = -1;
            }
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
                CreateTimer(3.0, Timer_StartDuel, arena_index);
            }
        } else {
            ResetPlayer(client);
            ResetPlayer(foe);

            if (g_bFourPersonArena[arena_index])
            {
                ResetPlayer(client_teammate);
                ResetPlayer(foe_teammate);
            }

            CreateTimer(0.15, Timer_ResetIntel, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
        }

        ShowPlayerHud(client);
        ShowPlayerHud(foe);

        if (g_bFourPersonArena[arena_index])
        {
            ShowPlayerHud(client_teammate);
            ShowPlayerHud(foe_teammate);
        }

        EmitSoundToClient(client, "vo/intel_teamcaptured.mp3");
        EmitSoundToClient(foe, "vo/intel_enemycaptured.mp3");

        if (g_bFourPersonArena[arena_index])
        {
            // This shouldn't be necessary but I'm getting invalid clients for some reason.
            if (IsValidClient(client_teammate))
                EmitSoundToClient(client_teammate, "vo/intel_teamcaptured.mp3");
            if (IsValidClient(foe_teammate))
                EmitSoundToClient(foe_teammate, "vo/intel_enemycaptured.mp3");
        }

        ShowSpecHudToArena(arena_index);
    }
    return Plugin_Continue;
}

void ResetIntel(int arena_index, any client = -1)
{
    if (g_bArenaBBall[arena_index])
    {
        if (IsValidEdict(g_iBBallIntel[arena_index]) && g_iBBallIntel[arena_index] > 0)
        {
            RemoveEdict(g_iBBallIntel[arena_index]);
            g_iBBallIntel[arena_index] = -1;
        }

        if (g_iBBallIntel[arena_index] == -1)
            g_iBBallIntel[arena_index] = CreateEntityByName("item_ammopack_small");
        else
            LogError("[%s] Intel [%i] already exists.", g_sArenaName[arena_index], g_iBBallIntel[arena_index]);


        float intel_loc[3];

        if (client != -1)
        {
            int client_slot = g_iPlayerSlot[client];
            g_bPlayerHasIntel[client] = false;

            if (client_slot == SLOT_ONE || client_slot == SLOT_THREE)
            {
                intel_loc[0] = g_fArenaSpawnOrigin[arena_index][g_iArenaSpawns[arena_index] - 3][0];
                intel_loc[1] = g_fArenaSpawnOrigin[arena_index][g_iArenaSpawns[arena_index] - 3][1];
                intel_loc[2] = g_fArenaSpawnOrigin[arena_index][g_iArenaSpawns[arena_index] - 3][2];
            } else if (client_slot == SLOT_TWO || client_slot == SLOT_FOUR) {
                intel_loc[0] = g_fArenaSpawnOrigin[arena_index][g_iArenaSpawns[arena_index] - 2][0];
                intel_loc[1] = g_fArenaSpawnOrigin[arena_index][g_iArenaSpawns[arena_index] - 2][1];
                intel_loc[2] = g_fArenaSpawnOrigin[arena_index][g_iArenaSpawns[arena_index] - 2][2];
            }
        } else {
            intel_loc[0] = g_fArenaSpawnOrigin[arena_index][g_iArenaSpawns[arena_index] - 4][0];
            intel_loc[1] = g_fArenaSpawnOrigin[arena_index][g_iArenaSpawns[arena_index] - 4][1];
            intel_loc[2] = g_fArenaSpawnOrigin[arena_index][g_iArenaSpawns[arena_index] - 4][2];
        }

        // Should fix the intel being an ammopack
        DispatchKeyValue(g_iBBallIntel[arena_index], "powerup_model", MODEL_BRIEFCASE);
        DispatchSpawn(g_iBBallIntel[arena_index]);
        TeleportEntity(g_iBBallIntel[arena_index], intel_loc, NULL_VECTOR, NULL_VECTOR);
        SetEntProp(g_iBBallIntel[arena_index], Prop_Send, "m_iTeamNum", 1, 4);
        SetEntPropFloat(g_iBBallIntel[arena_index], Prop_Send, "m_flModelScale", 1.15);

        SDKHook(g_iBBallIntel[arena_index], SDKHook_StartTouch, OnTouchIntel);
        AcceptEntityInput(g_iBBallIntel[arena_index], "Enable");
    }
}

Action Timer_ResetIntel(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    int arena_index = g_iPlayerArena[client];

    ResetIntel(arena_index, client);

    return Plugin_Continue;
}

Action Timer_AllowPlayerCap(Handle timer, int userid)
{
    g_bCanPlayerGetIntel[userid] = true;

    return Plugin_Continue;
}

// When a player drops the intel in BBall
Action Command_DropItem(int client, const char[] command, int argc)
{
    int arena_index = g_iPlayerArena[client];

    if (g_bArenaBBall[arena_index])
    {
        if (g_bPlayerHasIntel[client])
        {
            g_bPlayerHasIntel[client] = false;
            float pos[3];
            GetClientAbsOrigin(client, pos);
            float dist = DistanceAboveGroundAroundPlayer(client);
            if (dist > -1)
                pos[2] = pos[2] - dist + 5;
            else
                pos[2] = g_fArenaSpawnOrigin[arena_index][g_iArenaSpawns[arena_index] - 3][2];

            if (g_iBBallIntel[arena_index] == -1)
                g_iBBallIntel[arena_index] = CreateEntityByName("item_ammopack_small");
            else
                LogError("[%s] Player dropped the intel, but intel [%i] already exists.", g_sArenaName[arena_index], g_iBBallIntel[arena_index]);

            // This should fix the ammopack not being turned into a briefcase
            DispatchKeyValue(g_iBBallIntel[arena_index], "powerup_model", MODEL_BRIEFCASE);
            TeleportEntity(g_iBBallIntel[arena_index], pos, NULL_VECTOR, NULL_VECTOR);
            DispatchSpawn(g_iBBallIntel[arena_index]);
            SetEntProp(g_iBBallIntel[arena_index], Prop_Send, "m_iTeamNum", 1, 4);
            SetEntPropFloat(g_iBBallIntel[arena_index], Prop_Send, "m_flModelScale", 1.15);

            SDKHook(g_iBBallIntel[arena_index], SDKHook_StartTouch, OnTouchIntel);
            AcceptEntityInput(g_iBBallIntel[arena_index], "Enable");

            EmitSoundToClient(client, "vo/intel_teamdropped.mp3");

            RemoveClientParticle(client);

            g_bCanPlayerGetIntel[client] = false;
            CreateTimer(0.5, Timer_AllowPlayerCap, client);
        }
    }

    return Plugin_Continue;
}

Action BoostVectors(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    float vecClient[3];
    float vecBoost[3];

    GetEntPropVector(client, Prop_Data, "m_vecVelocity", vecClient);

    vecBoost[0] = vecClient[0] * g_fRocketForceX;
    vecBoost[1] = vecClient[1] * g_fRocketForceY;
    if (vecClient[2] > 0)
    {
        vecBoost[2] = vecClient[2] * g_fRocketForceZ;
    } else {
        vecBoost[2] = vecClient[2];
    }

    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecBoost);

    return Plugin_Continue;
}