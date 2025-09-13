
// ===== MENU SYSTEM =====

// Handles menu interactions for top players panel including pagination navigation
int Panel_TopPlayers(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char query[512];
            
            // Check if we have stored pagination info for this client
            bool hasPagination = g_iTopPlayersTotalPages[param1] > 1;
            
            if (hasPagination)
            {
                switch (param2)
                {
                    case 1: // Previous Page
                    {
                        g_iTopPlayersPage[param1]--;
                        GetSelectTopPlayersQuery(query, sizeof(query));
                        g_DB.Query(SQL_OnTopPlayersReceived, query, param1);
                    }
                    case 2: // Next Page
                    {
                        g_iTopPlayersPage[param1]++;
                        GetSelectTopPlayersQuery(query, sizeof(query));
                        g_DB.Query(SQL_OnTopPlayersReceived, query, param1);
                    }
                    case 3: // Close
                    {
                        // Panel closes automatically
                    }
                }
            }
            else
            {
                // No pagination, so item 1 is Close
                switch (param2)
                {
                    case 1: // Close
                    {
                        // Panel closes automatically
                    }
                }
            }
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                ShowMainMenu(param1);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }

    return 0;
}

// Creates and displays paginated top players panel with ELO rankings
void ShowTopPlayersPanel(int client, DBResultSet results, int totalRows)
{
    if (!IsValidClient(client))
        return;

    Panel panel = new Panel();
    char title[128];
    Format(title, sizeof(title), "%T\n", "EloRankingsTitle", client);
    panel.SetTitle(title);

    int playersPerPage = 10;
    int totalPages = (totalRows + playersPerPage - 1) / playersPerPage;
    int currentPage = g_iTopPlayersPage[client];
    
    if (currentPage >= totalPages)
        currentPage = 0;
    if (currentPage < 0)
        currentPage = totalPages - 1;
    
    g_iTopPlayersPage[client] = currentPage;
    g_iTopPlayersTotalPages[client] = totalPages;
    
    int startIndex = currentPage * playersPerPage;
    int endIndex = startIndex + playersPerPage;
    if (endIndex > totalRows)
        endIndex = totalRows;

    char line[256];
    Format(line, sizeof(line), "%T\n", "PageInfo", client, currentPage + 1, totalPages, totalRows);
    panel.DrawText(line);
    panel.DrawText(" ");

    int currentRow = 0;
    int rank = 1;
    
    while (results.FetchRow())
    {
        if (currentRow < startIndex)
        {
            currentRow++;
            rank++;
            continue;
        }
        
        if (currentRow >= endIndex)
            break;

        int rating = results.FetchInt(0);
        char name[MAX_NAME_LENGTH];
        results.FetchString(1, name, sizeof(name));
        int wins = results.FetchInt(2);
        int losses = results.FetchInt(3);

        if (g_bNoDisplayRating)
        {
            Format(line, sizeof(line), "#%d %s", rank, name);
        }
        else
        {
            Format(line, sizeof(line), "#%d %s (%d) [%d/%d]", rank, name, rating, wins, losses);
        }
        
        panel.DrawText(line);
        currentRow++;
        rank++;
    }

    panel.DrawText(" ");
    
    char prev_text[64], next_text[64], close_text[64];
    Format(prev_text, sizeof(prev_text), "%T", "PreviousPage", client);
    Format(next_text, sizeof(next_text), "%T", "NextPage", client);
    Format(close_text, sizeof(close_text), "%T", "Close", client);
    
    if (totalPages > 1)
    {
        if (currentPage > 0)
            panel.DrawItem(prev_text);
        else
            panel.DrawItem(prev_text, ITEMDRAW_DISABLED);
            
        if (currentPage < totalPages - 1)
            panel.DrawItem(next_text);
        else
            panel.DrawItem(next_text, ITEMDRAW_DISABLED);
    }
    
    panel.DrawItem(close_text);
    panel.Send(client, Panel_TopPlayers, MENU_TIME_FOREVER);
    delete panel;
}


// ===== DATABASE HANDLERS =====

// Processes database query results for top players rankings display
void SQL_OnTopPlayersReceived(Database db, DBResultSet results, const char[] error, any data)
{
    int client = data;

    if (db == null)
    {
        LogError("[TopPlayersPanel] Query failed: database connection lost");
        return;
    }
    
    if (results == null)
    {
        LogError("[TopPlayersPanel] Query failed: %s", error);
        return;
    }

    if (client < 1 || client > MaxClients || !IsClientConnected(client))
    {
        LogError("SQL_OnTopPlayersReceived failed: client %d <%s> is invalid.", client, g_sPlayerSteamID[client]);
        return;
    }

    int rowCount = SQL_GetRowCount(results);
    if (rowCount == 0)
    {
        MC_PrintToChat(client, "%t", "top5error");
        return;
    }

    ShowTopPlayersPanel(client, results, rowCount);
}


// ===== PLAYER COMMANDS =====

// Initiates top players query and displays ELO rankings to requesting client
Action Command_Top5(int client, int args)
{
    if (g_bNoStats || !IsValidClient(client))
    {
        MC_PrintToChat(client, "%t", "NoStatsTrue");
        return Plugin_Continue;
    }

    g_iTopPlayersPage[client] = 0;
    char query[512];
    GetSelectTopPlayersQuery(query, sizeof(query));
    g_DB.Query(SQL_OnTopPlayersReceived, query, client);
    return Plugin_Handled;
}

// Shows player's own rank or compares with another player's statistics
Action Command_Rank(int client, int args)
{
    if (g_bNoStats || !IsValidClient(client))
        return Plugin_Handled;

    if (args == 0)
    {
        if (g_bNoDisplayRating || !g_bShowElo[client])
            MC_PrintToChat(client, "%t", "MyRankNoRating", g_iPlayerWins[client], g_iPlayerLosses[client]);
        else
            MC_PrintToChat(client, "%t", "MyRank", g_iPlayerRating[client], g_iPlayerWins[client], g_iPlayerLosses[client]);
    } else {
        char argstr[64];
        GetCmdArgString(argstr, sizeof(argstr));
        int targ = FindTarget(0, argstr, false, false);

        if (targ == client)
        {
            if (g_bNoDisplayRating || !g_bShowElo[client])
                MC_PrintToChat(client, "%t", "MyRankNoRating", g_iPlayerWins[client], g_iPlayerLosses[client]);
            else
                MC_PrintToChat(client, "%t", "MyRank", g_iPlayerRating[client], g_iPlayerWins[client], g_iPlayerLosses[client]);
        } else if (targ != -1) {
            if (g_bNoDisplayRating || !g_bShowElo[client])
                MC_PrintToChat(client, "%t", "WinChanceMessage", targ, g_iPlayerWins[targ], g_iPlayerLosses[targ], RoundFloat((1 / (Pow(10.0, float((g_iPlayerRating[targ] - g_iPlayerRating[client])) / 400) + 1)) * 100));
            else
                MC_PrintToChat(client, "%t", "WinChanceRatingMessage", targ, g_iPlayerRating[targ], RoundFloat((1 / (Pow(10.0, float((g_iPlayerRating[targ] - g_iPlayerRating[client])) / 400) + 1)) * 100));
        }
    }

    return Plugin_Handled;
}
