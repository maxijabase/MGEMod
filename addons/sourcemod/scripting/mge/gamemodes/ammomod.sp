// ===== CLIENT MANAGEMENT =====

// Initialize and reset ammo tracking data for a client when they connect or change arenas
void ResetClientAmmoCounts(int client)
{
    // Crutch.
    g_iPlayerClip[client][SLOT_ONE] = -1;
    g_iPlayerClip[client][SLOT_TWO] = -1;

    // Check how much ammo each gun can hold in its clip and store it in a global variable so it can be set to that amount later.
    int primary = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
    if (IsValidEntity(primary) && GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex") != ITEM_DEFINDEX_BEGGARS_BAZOOKA)
        g_iPlayerClip[client][SLOT_ONE] = GetEntProp(primary, Prop_Data, "m_iClip1");

    int secondary = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
    if (IsValidEntity(secondary))
        g_iPlayerClip[client][SLOT_TWO] = GetEntProp(secondary, Prop_Data, "m_iClip1");
}


// ===== GAME MECHANICS =====

// Continuously manage health values in ammomod arenas to prevent one-shot kills
void ProcessAmmomodHealthManagement()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsValidClient(client) && IsPlayerAlive(client))
        {
            int arena_index = g_iPlayerArena[client];
            if (!g_bArenaBBall[arena_index] && !g_bArenaMGE[arena_index] && !g_bArenaKoth[arena_index])
            {
                /*  This is a hack that prevents people from getting one-shot by things
                like the direct hit in the Ammomod arenas. */
                int replacement_hp = (g_iPlayerMaxHP[client] + 512);
                SetEntProp(client, Prop_Send, "m_iHealth", replacement_hp, 1);
            }
        }
    }
}


// ===== TIMER CALLBACKS =====

// Restore saved ammunition counts to player weapons after a brief delay
Action Timer_GiveAmmo(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!client || !IsValidEntity(client))
        return Plugin_Continue;

    g_bPlayerRestoringAmmo[client] = false;

    int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
    if (IsValidEntity(weapon))
    {
        int itemDefinitionIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
        if (itemDefinitionIndex == ITEM_DEFINDEX_COW_MANGLER && HasEntProp(weapon, Prop_Send, "m_flEnergy"))
        {
            SetEntPropFloat(weapon, Prop_Send, "m_flEnergy", 100.0);
        }
        else if (itemDefinitionIndex == ITEM_DEFINDEX_BEGGARS_BAZOOKA)
        {
            int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
            if (ammoType >= 0)
                SetEntProp(client, Prop_Send, "m_iAmmo", BEGGARS_BAZOOKA_RESERVE_AMMO, 4, ammoType);
        }
        else if (g_iPlayerClip[client][SLOT_ONE] != -1)
        {
            SetEntProp(weapon, Prop_Send, "m_iClip1", g_iPlayerClip[client][SLOT_ONE]);
        }
    }

    if (g_iPlayerClip[client][SLOT_TWO] != -1)
    {
        weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);

        if (IsValidEntity(weapon))
            SetEntProp(weapon, Prop_Send, "m_iClip1", g_iPlayerClip[client][SLOT_TWO]);
    }

    return Plugin_Continue;
}
