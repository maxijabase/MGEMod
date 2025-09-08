// ===== ARENA SELECTION MENU SYSTEM =====

// Displays the main 2v2 arena selection menu with team join options and conversion to 1v1
void Show2v2SelectionMenu(int client, int arena_index)
{
    if (!IsValidClient(client))
        return;

    char title[128];
    char menu_item[128];

    Menu menu = new Menu(Menu_2v2Selection);

    // Check if player is already in this arena
    int current_slot = g_iPlayerSlot[client];
    bool already_in_arena = (g_iPlayerArena[client] == arena_index && current_slot >= SLOT_ONE && current_slot <= SLOT_FOUR);
    
    if (already_in_arena)
    {
        char current_team[16];
        Format(current_team, sizeof(current_team), (current_slot == SLOT_ONE || current_slot == SLOT_THREE) ? "RED" : "BLU");
        Format(title, sizeof(title), "2v2 Arena Management (Currently on %s team):", current_team);
    }
    else
    {
        Format(title, sizeof(title), "You selected a 2v2 arena. What would you like to do?");
    }
    menu.SetTitle(title);

    // Store arena index in menu data
    char arena_data[8];
    IntToString(arena_index, arena_data, sizeof(arena_data));

    // Count current team members
    int red_count = 0;
    int blu_count = 0;
    
    for (int i = SLOT_ONE; i <= SLOT_FOUR; i++)
    {
        if (g_iArenaQueue[arena_index][i])
        {
            if (i == SLOT_ONE || i == SLOT_THREE)
                red_count++;
            else
                blu_count++;
        }
    }

    // Option 1: Join normally and switch arena to 1v1 (only if logical)
    char disable_reason[64];
    bool can_convert_to_1v1 = CanConvertArenaTo1v1(arena_index, client, disable_reason, sizeof(disable_reason));
    
    if (can_convert_to_1v1)
    {
        Format(menu_item, sizeof(menu_item), "Join normally and switch arena to 1v1");
        menu.AddItem("1", menu_item);
    }
    else
    {
        Format(menu_item, sizeof(menu_item), "Switch to 1v1 (disabled - %s)", disable_reason);
        menu.AddItem("1", menu_item, ITEMDRAW_DISABLED);
    }

    // Option 2: Join RED team
    Format(menu_item, sizeof(menu_item), "Join RED [%d]", red_count);
    menu.AddItem("2", menu_item);

    // Option 3: Join BLU team
    Format(menu_item, sizeof(menu_item), "Join BLU [%d]", blu_count);
    menu.AddItem("3", menu_item);

    menu.ExitBackButton = true;
    menu.Display(client, 0);
}

// Handles user selections from the 2v2 arena selection menu
int Menu_2v2Selection(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            int client = param1;
            char info[32];
            menu.GetItem(param2, info, sizeof(info));
            
            // Get arena index from pending context (preferred) or current arena
            int arena_index = g_iPendingArena[client] ? g_iPendingArena[client] : g_iPlayerArena[client];
            
            if (StringToInt(info) == 1)
            {
                // Fallback validation for stale menus - check if conversion is still valid
                char reason[64];
                if (!CanConvertArenaTo1v1(arena_index, client, reason, sizeof(reason))) {
                    PrintToChat(client, "Cannot convert to 1v1 - %s", reason);
                    return 0;
                }
                
                // Switch arena to 1v1 (same logic as !1v1 command)
                g_bFourPersonArena[arena_index] = false;
                g_iArenaCdTime[arena_index] = DEFAULT_COUNTDOWN_TIME;
                CreateTimer(1.5, Timer_StartDuel, arena_index);
                UpdateArenaName(arena_index);
                
                // Notify players about mode change (same as !1v1 command)
                if(g_iArenaQueue[arena_index][SLOT_ONE]) {
                    PrintToChat(g_iArenaQueue[arena_index][SLOT_ONE], "Changed current arena to 1v1 arena!");
                }
                
                if(g_iArenaQueue[arena_index][SLOT_TWO]) {
                    PrintToChat(g_iArenaQueue[arena_index][SLOT_TWO], "Changed current arena to 1v1 arena!");
                }
                
                // If player is not already in the arena, add them
                if (g_iPlayerArena[client] != arena_index || g_iPlayerSlot[client] < SLOT_ONE || g_iPlayerSlot[client] > SLOT_FOUR)
                {
                    AddInQueue(client, arena_index, true, 0, false);
                }
                else
                {
                    // Player is already in arena, just reset them for 1v1 mode
                    CreateTimer(0.1, Timer_ResetPlayer, GetClientUserId(client));
                }

                // Clear pending arena after action
                g_iPendingArena[client] = 0;
            }
            else if (StringToInt(info) == 2)
            {
                // Join RED team
                if (g_iPlayerArena[client] != arena_index)
                {
                    // Switching arenas: remove from current on confirm, then add with team pref
                    if (g_iPlayerArena[client])
                    {
                        RemoveFromQueue(client, true);
                    }
                    AddInQueue(client, arena_index, true, TEAM_RED, false);
                }
                else
                {
                    Handle2v2TeamSwitchFromMenu(client, arena_index, TEAM_RED);
                }

                // Clear pending arena after action
                g_iPendingArena[client] = 0;
            }
            else if (StringToInt(info) == 3)
            {
                // Join BLU team
                if (g_iPlayerArena[client] != arena_index)
                {
                    // Switching arenas: remove from current on confirm, then add with team pref
                    if (g_iPlayerArena[client])
                    {
                        RemoveFromQueue(client, true);
                    }
                    AddInQueue(client, arena_index, true, TEAM_BLU, false);
                }
                else
                {
                    Handle2v2TeamSwitchFromMenu(client, arena_index, TEAM_BLU);
                }

                // Clear pending arena after action
                g_iPendingArena[client] = 0;
            }
        }
        case MenuAction_Cancel:
        {
            // Player cancelled - only clear arena assignment if they weren't in an arena before
            int client = param1;
            int current_slot = g_iPlayerSlot[client];
            
            // Only clear arena assignment if player wasn't actually placed in a slot yet
            // (This handles the case where we temporarily set arena during menu display)
            if (g_iPlayerArena[client] && (current_slot < SLOT_ONE || current_slot > SLOT_FOUR))
            {
                g_iPlayerArena[client] = 0;
                g_iPlayerSlot[client] = 0;
            }

            // Always clear pending arena on cancel
            g_iPendingArena[client] = 0;

            if (param2 == MenuCancel_ExitBack)
            {
                ShowMainMenu(client);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }

    return 0;
}


// ===== READY SYSTEM MANAGEMENT =====

// Initializes the 2v2 ready system when all 4 players have joined an arena
void Start2v2ReadySystem(int arena_index)
{
    // Reset all players' ready status
    for (int i = SLOT_ONE; i <= SLOT_FOUR; i++)
    {
        int client = g_iArenaQueue[arena_index][i];
        if (client)
        {
            g_bPlayer2v2Ready[client] = false;
        }
    }

    // Set arena status to waiting for ready
    g_iArenaStatus[arena_index] = AS_WAITING_READY;

    // Reset all players and show ready menu
    for (int i = SLOT_ONE; i <= SLOT_FOUR; i++)
    {
        int client = g_iArenaQueue[arena_index][i];
        if (client)
        {
            CreateTimer(0.1, Timer_ResetPlayer, GetClientUserId(client));
            CreateTimer(0.5, Timer_ShowReadyMenu, GetClientUserId(client));
        }
    }

    // Notify players about ready state
    PrintToChatArena(arena_index, "All 4 players joined! Please ready up to start the match.");
    Update2v2ReadyStatus(arena_index);
    
    // Start hud text refresh timer
    CreateTimer(5.0, Timer_Refresh2v2Hud, arena_index, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

// Displays the ready confirmation menu to players in 2v2 arenas
void Show2v2ReadyMenu(int client)
{
    if (!IsValidClient(client))
        return;

    int arena_index = g_iPlayerArena[client];
    if (!arena_index || !g_bFourPersonArena[arena_index] || g_iArenaStatus[arena_index] != AS_WAITING_READY)
        return;

    char title[128];
    Menu menu = new Menu(Menu_2v2Ready);

    Format(title, sizeof(title), "Ready for 2v2 match?");
    menu.SetTitle(title);

    menu.AddItem("1", "Yes, I'm ready!");
    menu.AddItem("0", "No, not ready");

    menu.ExitButton = true;
    menu.Display(client, 0);
}

// Processes player responses from the ready confirmation menu
int Menu_2v2Ready(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            int client = param1;
            char info[32];
            menu.GetItem(param2, info, sizeof(info));
            
            int arena_index = g_iPlayerArena[client];
            if (!arena_index || !g_bFourPersonArena[arena_index] || g_iArenaStatus[arena_index] != AS_WAITING_READY)
                return 0;

            bool ready = StringToInt(info) == 1;
            g_bPlayer2v2Ready[client] = ready;

            Update2v2ReadyStatus(arena_index);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }

    return 0;
}

// Updates and checks the ready status of all players in a 2v2 arena
void Update2v2ReadyStatus(int arena_index)
{
    int ready_count = 0;
    int total_players = 0;
    
    for (int i = SLOT_ONE; i <= SLOT_FOUR; i++)
    {
        int client = g_iArenaQueue[arena_index][i];
        if (client)
        {
            total_players++;
            if (g_bPlayer2v2Ready[client])
                ready_count++;
        }
    }

    // Show progress to all players in arena
    if (total_players == 4)
    {
        Show2v2ReadyHud(arena_index, ready_count);
        
        if (ready_count == 4)
        {
            // All players ready, start the match
            PrintToChatArena(arena_index, "All players ready! Starting match...");
            CreateTimer(1.5, Timer_StartDuel, arena_index);
        }
    }
}


// ===== HUD DISPLAY SYSTEM =====

// Shows personalized ready status HUD text to each player in the arena
void Show2v2ReadyHud(int arena_index, int ready_count)
{
    // Show personalized HUD text to each player
    for (int i = SLOT_ONE; i <= SLOT_FOUR; i++)
    {
        int client = g_iArenaQueue[arena_index][i];
        if (client)
        {
            char hudtext[256];
            char status_indicator[32];
            
            // Set personal ready status indicator
            if (g_bPlayer2v2Ready[client])
            {
                Format(status_indicator, sizeof(status_indicator), "✓ You are READY");
            }
            else
            {
                Format(status_indicator, sizeof(status_indicator), "✘ You are NOT READY");
            }
            
            // Format personalized hud text
            Format(hudtext, sizeof(hudtext), "%d/4 players ready\n%s\nType !ready or !r to toggle", 
                   ready_count, status_indicator);
            
            PrintHintText(client, "%s", hudtext);
            StopSound(client, SNDCHAN_STATIC, "UI/hint.wav");
        }
    }
}

// Clears ready status HUD text from all players in the arena
void Clear2v2ReadyHud(int arena_index)
{
    // Clear HUD text for all players in arena
    for (int i = SLOT_ONE; i <= SLOT_FOUR; i++)
    {
        int client = g_iArenaQueue[arena_index][i];
        if (client)
        {
            PrintHintText(client, "");
            StopSound(client, SNDCHAN_STATIC, "UI/hint.wav");
        }
    }
}


// ===== TEAM MANAGEMENT =====

// Handles team switching logic for players already in 2v2 arenas
void Handle2v2TeamSwitch(int client, int arena_index, int new_team)
{
    int current_slot = g_iPlayerSlot[client];
    
    // Only handle switching for players in active slots
    if (current_slot < SLOT_ONE || current_slot > SLOT_FOUR)
        return;
        
    // Determine current team based on slot
    int current_team = (current_slot == SLOT_ONE || current_slot == SLOT_THREE) ? TEAM_RED : TEAM_BLU;
    
    // If already on the target team, do nothing
    if (current_team == new_team)
        return;
        
    // Find available slot on new team
    int new_slot = 0;
    if (new_team == TEAM_RED)
    {
        if (!g_iArenaQueue[arena_index][SLOT_ONE])
            new_slot = SLOT_ONE;
        else if (!g_iArenaQueue[arena_index][SLOT_THREE])
            new_slot = SLOT_THREE;
    }
    else if (new_team == TEAM_BLU)
    {
        if (!g_iArenaQueue[arena_index][SLOT_TWO])
            new_slot = SLOT_TWO;
        else if (!g_iArenaQueue[arena_index][SLOT_FOUR])
            new_slot = SLOT_FOUR;
    }
    
    // If no slot available on target team, prevent switch
    if (new_slot == 0)
    {
        char team_name[16];
        Format(team_name, sizeof(team_name), (new_team == TEAM_RED) ? "RED" : "BLU");
        PrintToChat(client, "Cannot switch to %s team - no available slots!", team_name);
        return;
    }
    
    // Clear old slot and assign new slot
    g_iArenaQueue[arena_index][current_slot] = 0;
    g_iArenaQueue[arena_index][new_slot] = client;
    g_iPlayerSlot[client] = new_slot;
    
    // Reset ready status if in waiting phase
    if (g_iArenaStatus[arena_index] == AS_WAITING_READY)
    {
        g_bPlayer2v2Ready[client] = false;
    }
    
    // Reset player to spawn on new team
    CreateTimer(0.1, Timer_ResetPlayer, GetClientUserId(client));
    
    char name[MAX_NAME_LENGTH];
    char team_name[16];
    GetClientName(client, name, sizeof(name));
    Format(team_name, sizeof(team_name), (new_team == TEAM_RED) ? "RED" : "BLU");
    
    PrintToChatArena(arena_index, "%s switched to %s team", name, team_name);
    
    // Check if we have 2v2 team balance and can start/continue ready process
    Check2v2TeamBalance(arena_index);
    
    // Update HUD for all players in the arena to reflect team changes
    ShowHudToArena(arena_index);
}

// Processes team switching requests originating from menu selections
void Handle2v2TeamSwitchFromMenu(int client, int arena_index, int target_team)
{
    int current_slot = g_iPlayerSlot[client];
    
    // Check if player is already in the arena
    if (current_slot >= SLOT_ONE && current_slot <= SLOT_FOUR)
    {
        // Player is already in the arena, handle team switching
        int current_team = (current_slot == SLOT_ONE || current_slot == SLOT_THREE) ? TEAM_RED : TEAM_BLU;
        
        if (current_team == target_team)
        {
            // Player is already on the selected team, just show confirmation
            char team_name[16];
            Format(team_name, sizeof(team_name), (target_team == TEAM_RED) ? "RED" : "BLU");
            PrintToChat(client, "You are already on the %s team!", team_name);
            return;
        }
        
        // Use the existing team switch handler
        Handle2v2TeamSwitch(client, arena_index, target_team);
    }
    else
    {
        // Player is not in arena yet, add them with team preference
        AddInQueue(client, arena_index, true, target_team, false);
    }
}

// Validates team balance and triggers ready system when 2v2 balance is achieved
void Check2v2TeamBalance(int arena_index)
{
    int red_count = 0;
    int blu_count = 0;
    
    for (int i = SLOT_ONE; i <= SLOT_FOUR; i++)
    {
        if (g_iArenaQueue[arena_index][i])
        {
            if (i == SLOT_ONE || i == SLOT_THREE)
                red_count++;
            else
                blu_count++;
        }
    }
    
    if (red_count == 2 && blu_count == 2)
    {
        // Perfect 2v2 balance
        if (g_iArenaStatus[arena_index] == AS_IDLE)
        {
            Start2v2ReadySystem(arena_index);
        }
        else if (g_iArenaStatus[arena_index] == AS_WAITING_READY)
        {
            Update2v2ReadyStatus(arena_index);
        }
        else if (g_iArenaStatus[arena_index] == AS_AFTERFIGHT || g_iArenaStatus[arena_index] == AS_FIGHT)
        {
            // Match just ended and players were promoted, transition to ready system
            Clear2v2ReadyHud(arena_index);
            g_iArenaStatus[arena_index] = AS_IDLE;
            // Restore any waiting/spec players before readying again
            if (g_bFourPersonArena[arena_index])
            {
                Restore2v2WaitingSpectators(arena_index);
            }
            Start2v2ReadySystem(arena_index);
        }
    }
    else
    {
        // Not balanced, inform players
        if (g_iArenaStatus[arena_index] == AS_WAITING_READY)
        {
            Clear2v2ReadyHud(arena_index);
            g_iArenaStatus[arena_index] = AS_IDLE;
            if (g_bFourPersonArena[arena_index])
            {
                Restore2v2WaitingSpectators(arena_index);
            }
            PrintToChatArena(arena_index, "Team balance lost (RED: %d, BLU: %d). Need exactly 2 players per team.", red_count, blu_count);
        }
    }
}


// ===== PLAYER UTILITIES =====

// Gets a clients teammate if he's in a 4 player arena
// TODO: This can actually be replaced by g_iArenaQueue[SLOT_X] but I didn't realize that array existed, so YOLO
int getTeammate(int myClientSlot, int arena_index)
{
    int client_teammate_slot;

    if (myClientSlot == SLOT_ONE)
    {
        client_teammate_slot = SLOT_THREE;
    }
    else if (myClientSlot == SLOT_TWO)
    {
        client_teammate_slot = SLOT_FOUR;
    }
    else if (myClientSlot == SLOT_THREE)
    {
        client_teammate_slot = SLOT_ONE;
    }
    else
    {
        client_teammate_slot = SLOT_TWO;
    }

    int myClientTeammate = g_iArenaQueue[arena_index][client_teammate_slot];
    return myClientTeammate;
}

// Executes class swapping between two teammates in ultiduo arenas
void swapClasses(int client, int client_teammate)
{
    TFClassType client_class = g_tfctPlayerClass[client];
    TFClassType client_teammate_class = g_tfctPlayerClass[client_teammate];

    ForcePlayerSuicide(client);
    TF2_SetPlayerClass(client, client_teammate_class, false, true);
    ForcePlayerSuicide(client_teammate);
    TF2_SetPlayerClass(client_teammate, client_class, false, true);

    g_tfctPlayerClass[client] = client_teammate_class;
    g_tfctPlayerClass[client_teammate] = client_class;

}

// Restores any 2v2 participants who were moved to spectator while waiting for their teammate
// To finish the round. Ensures they are back on the correct team, clears waiting flag, and
// Schedules a reset to spawn them properly.
void Restore2v2WaitingSpectators(int arena_index)
{
    if (!g_bFourPersonArena[arena_index])
        return;

    for (int slot = SLOT_ONE; slot <= SLOT_FOUR; slot++)
    {
        int client = g_iArenaQueue[arena_index][slot];
        if (!IsValidClient(client))
            continue;

        bool isSpec = (GetClientTeam(client) == TEAM_SPEC);
        if (g_iPlayerWaiting[client] || isSpec)
        {
            int targetTeam = (slot == SLOT_ONE || slot == SLOT_THREE) ? TEAM_RED : TEAM_BLU;
            if (GetClientTeam(client) != targetTeam)
            {
                ChangeClientTeam(client, targetTeam);
            }
            g_iPlayerWaiting[client] = false;
            CreateTimer(0.1, Timer_ResetPlayer, GetClientUserId(client));
        }
    }
}


// ===== CLASS SWAP MENU SYSTEM =====

// Displays the class swap confirmation menu to the target teammate
void ShowSwapMenu(int client)
{
    if (!IsValidClient(client))
        return;

    char title[128];

    Menu menu = new Menu(SwapMenuHandler);

    Format(title, sizeof(title), "Would you like to swap classes with your teammate?", client);
    menu.SetTitle(title);
    menu.AddItem("yes", "Yes");
    menu.AddItem("no", "No");
    menu.ExitButton = false;
    menu.Display(client, 20);
}

// Processes responses from the class swap confirmation menu
int SwapMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    /* If an option was selected, tell the client about the item. */
    if (action == MenuAction_Select)
    {
        if (param2 == 0)
        {
            int client = param1;
            if (!client)
                return 0;

            int arena_index = g_iPlayerArena[client];
            int client_teammate = getTeammate(g_iPlayerSlot[client], arena_index);
            swapClasses(client, client_teammate);

        }
        else
            delete menu;
    }
    /* If the menu was cancelled, print a message to the server about it. */
    else if (action == MenuAction_Cancel)
    {
        PrintToServer("Client %d's menu was cancelled.  Reason: %d", param1, param2);
    }
    /* If the menu has ended, destroy it */
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}


// ===== COMMANDS =====

// Handles the !ready command for toggling ready status in 2v2 arenas
Action Command_Ready(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    int arena_index = g_iPlayerArena[client];
    if (!arena_index)
    {
        PrintToChat(client, "You are not in an arena!");
        return Plugin_Handled;
    }

    if (!g_bFourPersonArena[arena_index])
    {
        PrintToChat(client, "Ready command is only available in 2v2 arenas!");
        return Plugin_Handled;
    }

    if (g_iArenaStatus[arena_index] != AS_WAITING_READY)
    {
        PrintToChat(client, "Arena is not waiting for ready confirmation!");
        return Plugin_Handled;
    }

    // Toggle ready status
    g_bPlayer2v2Ready[client] = !g_bPlayer2v2Ready[client];

    Update2v2ReadyStatus(arena_index);
    return Plugin_Handled;
}

// Handles the !force2v2 admin command for automatically setting up 2v2 matches
Action Command_Force2v2(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    // Count total players in server
    int total_players = 0;
    int valid_players[MAXPLAYERS + 1];
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && !IsFakeClient(i))
        {
            valid_players[total_players] = i;
            total_players++;
        }
    }

    if (total_players < 4)
    {
        PrintToChat(client, "Need at least 4 players for 2v2. Found %d players.", total_players);
        return Plugin_Handled;
    }

    // Find available 2v2 arena
    int target_arena = -1;
    for (int i = 1; i <= g_iArenaCount; i++)
    {
        if (g_bFourPersonArena[i] && g_iArenaStatus[i] == AS_IDLE)
        {
            // Check if arena has space
            int arena_players = 0;
            for (int j = SLOT_ONE; j <= SLOT_FOUR; j++)
            {
                if (g_iArenaQueue[i][j])
                    arena_players++;
            }
            
            if (arena_players == 0)
            {
                target_arena = i;
                break;
            }
        }
    }

    if (target_arena == -1)
    {
        PrintToChat(client, "No available 2v2 arenas found!");
        return Plugin_Handled;
    }

    // Remove all players from their current arenas first
    for (int i = 0; i < total_players; i++)
    {
        int player = valid_players[i];
        if (g_iPlayerArena[player])
        {
            RemoveFromQueue(player, true);
        }
    }

    // Add first 4 players to the 2v2 arena
    int red_team[2];
    int blu_team[2];
    red_team[0] = valid_players[0];
    red_team[1] = valid_players[1];
    blu_team[0] = valid_players[2];
    blu_team[1] = valid_players[3];

    // Add RED team players
    g_iPlayerArena[red_team[0]] = target_arena;
    g_iPlayerSlot[red_team[0]] = SLOT_ONE;
    g_iArenaQueue[target_arena][SLOT_ONE] = red_team[0];
    SetPlayerToAllowedClass(red_team[0], target_arena);

    g_iPlayerArena[red_team[1]] = target_arena;
    g_iPlayerSlot[red_team[1]] = SLOT_THREE;
    g_iArenaQueue[target_arena][SLOT_THREE] = red_team[1];
    SetPlayerToAllowedClass(red_team[1], target_arena);

    // Add BLU team players
    g_iPlayerArena[blu_team[0]] = target_arena;
    g_iPlayerSlot[blu_team[0]] = SLOT_TWO;
    g_iArenaQueue[target_arena][SLOT_TWO] = blu_team[0];
    SetPlayerToAllowedClass(blu_team[0], target_arena);

    g_iPlayerArena[blu_team[1]] = target_arena;
    g_iPlayerSlot[blu_team[1]] = SLOT_FOUR;
    g_iArenaQueue[target_arena][SLOT_FOUR] = blu_team[1];
    SetPlayerToAllowedClass(blu_team[1], target_arena);

    // Notify all players
    char red_names[128], blu_names[128];
    char name1[MAX_NAME_LENGTH], name2[MAX_NAME_LENGTH], name3[MAX_NAME_LENGTH], name4[MAX_NAME_LENGTH];
    
    GetClientName(red_team[0], name1, sizeof(name1));
    GetClientName(red_team[1], name2, sizeof(name2));
    GetClientName(blu_team[0], name3, sizeof(name3));
    GetClientName(blu_team[1], name4, sizeof(name4));
    
    Format(red_names, sizeof(red_names), "%s & %s", name1, name2);
    Format(blu_names, sizeof(blu_names), "%s & %s", name3, name4);

    PrintToChatAll("Admin force-added players to 2v2 arena: %s", g_sArenaName[target_arena]);
    PrintToChatAll("RED Team: %s", red_names);
    PrintToChatAll("BLU Team: %s", blu_names);

    // Start the 2v2 ready system
    Start2v2ReadySystem(target_arena);

    return Plugin_Handled;
}

// Handles the !swap command for initiating class swaps in ultiduo arenas
Action Command_Swap(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Continue;

    if (!g_bCanPlayerSwap[client])
    {
        PrintToChat(client, "You must wait 60 seconds between swap attempts!");
        return Plugin_Handled;
    }
    else
    {
        g_bCanPlayerSwap[client] = false;
        CreateTimer(60.0, Timer_ResetSwap, client);
    }

    int arena_index = g_iPlayerArena[client];

    if (!g_bArenaUltiduo[arena_index] || !g_bFourPersonArena[arena_index])
        return Plugin_Continue;

    int client_teammate = getTeammate(g_iPlayerSlot[client], arena_index);
    ShowSwapMenu(client_teammate);
    return Plugin_Handled;
}


// ===== TIMER CALLBACKS =====

// Periodically refreshes the ready status HUD display for active 2v2 arenas
Action Timer_Refresh2v2Hud(Handle timer, any arena_index)
{
    // Only refresh if arena is still in ready state
    if (g_iArenaStatus[arena_index] == AS_WAITING_READY)
    {
        int ready_count = 0;
        int total_players = 0;
        
        for (int i = SLOT_ONE; i <= SLOT_FOUR; i++)
        {
            int client = g_iArenaQueue[arena_index][i];
            if (client)
            {
                total_players++;
                if (g_bPlayer2v2Ready[client])
                    ready_count++;
            }
        }
        
        if (total_players == 4)
        {
            Show2v2ReadyHud(arena_index, ready_count);
        }
        else
        {
            // Not enough players, stop the timer
            return Plugin_Stop;
        }
    }
    else
    {
        // Arena is no longer in ready state, stop the timer
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

// Delayed callback to display the ready menu to newly joined players
Action Timer_ShowReadyMenu(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client)
    {
        Show2v2ReadyMenu(client);
    }
    return Plugin_Continue;
}

// Handles post-match cleanup and ready system restart for continuous 2v2 play
Action Timer_Restart2v2Ready(Handle timer, any arena_index)
{
    // Check if we still have 4 players in the arena
    int player_count = 0;
    for (int i = SLOT_ONE; i <= SLOT_FOUR; i++)
    {
        if (g_iArenaQueue[arena_index][i])
            player_count++;
    }

    if (player_count == 4)
    {
        // Reset scores and return to ready state
        g_iArenaScore[arena_index][SLOT_ONE] = 0;
        g_iArenaScore[arena_index][SLOT_TWO] = 0;
        // Ensure any players that were placed into spectator (waiting) are restored
        Restore2v2WaitingSpectators(arena_index);
        Start2v2ReadySystem(arena_index);
        PrintToChatArena(arena_index, "Match finished! Please ready up for the next round.");
    }
    else
    {
        // Not enough players, revert to normal behavior
        Clear2v2ReadyHud(arena_index);
        g_iArenaStatus[arena_index] = AS_IDLE;
        // Still restore any parked spectators in case teams refill
        Restore2v2WaitingSpectators(arena_index);
        ResetArena(arena_index);
    }

    return Plugin_Continue;
}

// Resets all players in a 2v2 arena and transitions to active fighting state
Action Timer_New2v2Round(Handle timer, any arena_index) {
    int red_f1 = g_iArenaQueue[arena_index][SLOT_ONE]; /* Red (slot one) player. */
    int blu_f1 = g_iArenaQueue[arena_index][SLOT_TWO]; /* Blu (slot two) player. */

    int red_f2 = g_iArenaQueue[arena_index][SLOT_THREE]; /* 2nd Red (slot three) player. */
    int blu_f2 = g_iArenaQueue[arena_index][SLOT_FOUR]; /* 2nd Blu (slot four) player. */

    if (red_f1) ResetPlayer(red_f1);
    if (blu_f1) ResetPlayer(blu_f1);
    if (red_f2) ResetPlayer(red_f2);
    if (blu_f2) ResetPlayer(blu_f2);

    g_iArenaStatus[arena_index] = AS_FIGHT;

    return Plugin_Continue;
}

// Resets the class swap cooldown timer for a specific player
Action Timer_ResetSwap(Handle timer, int client)
{
    g_bCanPlayerSwap[client] = true;

    return Plugin_Continue;
}