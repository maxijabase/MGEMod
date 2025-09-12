// ===== API FORWARD DECLARATIONS =====

// Initialize all API forwards for other plugins to hook into
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    // Forward declarations
    g_hOnPlayerArenaAdd = new GlobalForward("MGE_OnPlayerArenaAdd", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
    g_hOnPlayerArenaAdded = new GlobalForward("MGE_OnPlayerArenaAdded", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_hOnPlayerArenaRemove = new GlobalForward("MGE_OnPlayerArenaRemove", ET_Hook, Param_Cell, Param_Cell);
    g_hOnPlayerArenaRemoved = new GlobalForward("MGE_OnPlayerArenaRemoved", ET_Ignore, Param_Cell, Param_Cell);
    g_hOn1v1MatchStart = new GlobalForward("MGE_On1v1MatchStart", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_hOn1v1MatchEnd = new GlobalForward("MGE_On1v1MatchEnd", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_hOn2v2MatchStart = new GlobalForward("MGE_On2v2MatchStart", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_hOn2v2MatchEnd = new GlobalForward("MGE_On2v2MatchEnd", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_hOnArenaPlayerDeath = new GlobalForward("MGE_OnArenaPlayerDeath", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_hOnPlayerELOChange = new GlobalForward("MGE_OnPlayerELOChange", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_hOn2v2ReadyStart = new GlobalForward("MGE_On2v2ReadyStart", ET_Ignore, Param_Cell);
    g_hOn2v2PlayerReady = new GlobalForward("MGE_On2v2PlayerReady", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    
    // Register all natives
    RegisterNatives();
    
    RegPluginLibrary("mgemod");
    
    return APLRes_Success;
}

// ===== FORWARD CALL HELPERS =====

// Call the OnPlayerArenaAdd forward
Action CallForward_OnPlayerArenaAdd(int client, int arena_index, int slot)
{
    Action result = Plugin_Continue;
    Call_StartForward(g_hOnPlayerArenaAdd);
    Call_PushCell(client);
    Call_PushCell(arena_index);
    Call_PushCell(slot);
    Call_Finish(result);
    return result;
}

// Call the OnPlayerArenaAdded forward
void CallForward_OnPlayerArenaAdded(int client, int arena_index, int slot)
{
    Call_StartForward(g_hOnPlayerArenaAdded);
    Call_PushCell(client);
    Call_PushCell(arena_index);
    Call_PushCell(slot);
    Call_Finish();
}

// Call the OnPlayerArenaRemove forward
Action CallForward_OnPlayerArenaRemove(int client, int arena_index)
{
    Action result = Plugin_Continue;
    Call_StartForward(g_hOnPlayerArenaRemove);
    Call_PushCell(client);
    Call_PushCell(arena_index);
    Call_Finish(result);
    return result;
}

// Call the OnPlayerArenaRemoved forward
void CallForward_OnPlayerArenaRemoved(int client, int arena_index)
{
    Call_StartForward(g_hOnPlayerArenaRemoved);
    Call_PushCell(client);
    Call_PushCell(arena_index);
    Call_Finish();
}

// Call the On1v1MatchStart forward
void CallForward_On1v1MatchStart(int arena_index, int player1, int player2)
{
    Call_StartForward(g_hOn1v1MatchStart);
    Call_PushCell(arena_index);
    Call_PushCell(player1);
    Call_PushCell(player2);
    Call_Finish();
}

// Call the On1v1MatchEnd forward
void CallForward_On1v1MatchEnd(int arena_index, int winner, int loser, int winner_score, int loser_score)
{
    Call_StartForward(g_hOn1v1MatchEnd);
    Call_PushCell(arena_index);
    Call_PushCell(winner);
    Call_PushCell(loser);
    Call_PushCell(winner_score);
    Call_PushCell(loser_score);
    Call_Finish();
}

// Call the On2v2MatchStart forward
void CallForward_On2v2MatchStart(int arena_index, int team1_player1, int team1_player2, int team2_player1, int team2_player2)
{
    Call_StartForward(g_hOn2v2MatchStart);
    Call_PushCell(arena_index);
    Call_PushCell(team1_player1);
    Call_PushCell(team1_player2);
    Call_PushCell(team2_player1);
    Call_PushCell(team2_player2);
    Call_Finish();
}

// Call the On2v2MatchEnd forward
void CallForward_On2v2MatchEnd(int arena_index, int winning_team, int winning_score, int losing_score, int team1_player1, int team1_player2, int team2_player1, int team2_player2)
{
    Call_StartForward(g_hOn2v2MatchEnd);
    Call_PushCell(arena_index);
    Call_PushCell(winning_team);
    Call_PushCell(winning_score);
    Call_PushCell(losing_score);
    Call_PushCell(team1_player1);
    Call_PushCell(team1_player2);
    Call_PushCell(team2_player1);
    Call_PushCell(team2_player2);
    Call_Finish();
}

// Call the OnArenaPlayerDeath forward
void CallForward_OnArenaPlayerDeath(int victim, int attacker, int arena_index)
{
    Call_StartForward(g_hOnArenaPlayerDeath);
    Call_PushCell(victim);
    Call_PushCell(attacker);
    Call_PushCell(arena_index);
    Call_Finish();
}

// Call the OnPlayerELOChange forward
void CallForward_OnPlayerELOChange(int client, int old_elo, int new_elo, int arena_index)
{
    Call_StartForward(g_hOnPlayerELOChange);
    Call_PushCell(client);
    Call_PushCell(old_elo);
    Call_PushCell(new_elo);
    Call_PushCell(arena_index);
    Call_Finish();
}

// Call the On2v2ReadyStart forward
void CallForward_On2v2ReadyStart(int arena_index)
{
    Call_StartForward(g_hOn2v2ReadyStart);
    Call_PushCell(arena_index);
    Call_Finish();
}

// Call the On2v2PlayerReady forward
void CallForward_On2v2PlayerReady(int client, int arena_index, bool ready_status)
{
    Call_StartForward(g_hOn2v2PlayerReady);
    Call_PushCell(client);
    Call_PushCell(arena_index);
    Call_PushCell(ready_status);
    Call_Finish();
}
