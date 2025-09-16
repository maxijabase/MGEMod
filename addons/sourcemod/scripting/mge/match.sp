// ===== MATCH LIFECYCLE MANAGEMENT =====

// Determines if a match should be completed based on current conditions
bool ShouldProcessMatchCompletion(int arena_index, int killer_team_slot, int fraglimit)
{
    if (g_iArenaStatus[arena_index] < AS_FIGHT || g_iArenaStatus[arena_index] >= AS_REPORTED)
        return false;
        
    if (fraglimit <= 0)
        return false;
        
    return (g_iArenaScore[arena_index][killer_team_slot] >= fraglimit);
}

// Processes complete match end sequence including ELO, announcements, and queue rotation
void ProcessMatchCompletion(int arena_index, int winner1, int winner2, int loser1, int loser2, int winner_team_slot, int loser_team_slot, int fraglimit)
{
    // Set match as completed
    g_iArenaStatus[arena_index] = AS_REPORTED;
    
    // Format team names for announcement
    char winner_names[128];
    char loser_names[128];
    
    if (g_bFourPersonArena[arena_index])
    {
        FormatTeamPlayerNames(winner1, winner2, winner_names, sizeof(winner_names));
        FormatTeamPlayerNames(loser1, loser2, loser_names, sizeof(loser_names));
    }
    else
    {
        GetClientName(winner1, winner_names, sizeof(winner_names));
        GetClientName(loser1, loser_names, sizeof(loser_names));
    }
    
    // Announce match result
    MC_PrintToChatAll("%t", "XdefeatsY", winner_names, g_iArenaScore[arena_index][winner_team_slot], 
                      loser_names, g_iArenaScore[arena_index][loser_team_slot], fraglimit, g_sArenaName[arena_index]);
    
    // Call API forwards for match end
    if (!g_bFourPersonArena[arena_index])
    {
        CallForward_On1v1MatchEnd(arena_index, winner1, loser1, g_iArenaScore[arena_index][winner_team_slot], g_iArenaScore[arena_index][loser_team_slot]);
    }
    else
    {
        int winning_team = (winner_team_slot == SLOT_ONE) ? TEAM_RED : TEAM_BLU;
        CallForward_On2v2MatchEnd(arena_index, winning_team, g_iArenaScore[arena_index][winner_team_slot], g_iArenaScore[arena_index][loser_team_slot], 
                                g_iArenaQueue[arena_index][SLOT_ONE], g_iArenaQueue[arena_index][SLOT_THREE],
                                g_iArenaQueue[arena_index][SLOT_TWO], g_iArenaQueue[arena_index][SLOT_FOUR]);
    }
    
    // Handle ELO calculations
    if (!g_bNoStats)
    {
        if (!g_bFourPersonArena[arena_index])
            CalcELO(winner1, loser1);
        else
            CalcELO2(winner1, winner2, loser1, loser2);
    }
    
    // Handle post-match queue rotation and timers
    HandlePostMatchQueueRotation(arena_index, loser1, loser2);
}


// ===== QUEUE ROTATION MANAGEMENT =====

// Manages queue rotation and timer scheduling after match completion
void HandlePostMatchQueueRotation(int arena_index, int loser1, int loser2)
{
    if (!g_bFourPersonArena[arena_index])
    {
        // 1v1 queue rotation
        if (g_iArenaQueue[arena_index][SLOT_TWO + 1])
        {
            RemoveFromQueue(loser1, false, true);
            AddInQueue(loser1, arena_index, false, 0, false);
        } 
        else 
        {
            CreateTimer(3.0, Timer_StartDuel, arena_index);
        }
    }
    else
    {
        // 2v2 queue rotation
        if (g_iArenaQueue[arena_index][SLOT_FOUR + 1] && g_iArenaQueue[arena_index][SLOT_FOUR + 2])
        {
            RemoveFromQueue(loser2, false, true);
            RemoveFromQueue(loser1, false, true);
            AddInQueue(loser2, arena_index, false, 0, false);
            AddInQueue(loser1, arena_index, false, 0, false);
        }
        else if (g_iArenaQueue[arena_index][SLOT_FOUR + 1])
        {
            RemoveFromQueue(loser1, false, true);
            AddInQueue(loser1, arena_index, false, 0, false);
        }
        else 
        {
            // Return to ready state for 2v2 arenas
            CreateTimer(3.0, Timer_Restart2v2Ready, arena_index);
        }
    }
}


// ===== CLASS CHANGE MATCH COMPLETION =====

// Handles match completion triggered by class changes during fights (MGE/Endif specific)
void ProcessClassChangeMatchCompletion(int arena_index, int client, int killer, int killer_teammate, int client_teammate, int killer_team_slot, int client_team_slot, int fraglimit)
{
    if (g_iArenaStatus[arena_index] != AS_FIGHT || fraglimit <= 0 || g_iArenaScore[arena_index][killer_team_slot] < fraglimit)
        return;
    
    // Use the main match completion function
    ProcessMatchCompletion(arena_index, killer, killer_teammate, client, client_teammate, killer_team_slot, client_team_slot, fraglimit);
}


// ===== MATCH STATE VALIDATION =====

// Validates if match completion conditions are met
bool ValidateMatchCompletion(int arena_index, int team_slot, int fraglimit)
{
    if (g_iArenaStatus[arena_index] < AS_FIGHT || g_iArenaStatus[arena_index] >= AS_REPORTED)
        return false;
        
    if (fraglimit <= 0)
        return false;
        
    return (g_iArenaScore[arena_index][team_slot] >= fraglimit);
}
