void PrepareSQL() 
{
    char error[256];

    // Initial mysql connect
    if (g_DB == null && SQL_CheckConfig(g_sDBConfig))
    {
        g_DB = SQL_Connect(g_sDBConfig, /* persistent */ true, error, sizeof(error));
    }

    // Failed mysql connect for whatever reason (likely no config in databases.cfg)
    if (g_DB == null)
    {
        LogError("Cant use database config <%s> <Error: %s>, trying SQLite <storage-local>...", g_sDBConfig, error);
        g_DB = SQL_Connect("storage-local", true, error, sizeof(error));

        if (g_DB == null)
        {
            SetFailState("Could not connect to database: %s", error);
        }
        else
        {
            LogMessage("Success, using SQLite <storage-local>", g_sDBConfig, error);
        }
    }

    char ident[16];
    g_DB.Driver.GetIdentifier(ident, sizeof(ident));

    if (StrEqual(ident, "mysql", false))
    {
        g_bUseSQLite = false;
    }
    else if (StrEqual(ident, "sqlite", false))
    {
        g_bUseSQLite = true;
    }
    else
    {
        SetFailState("Invalid database.");
    }

    if (g_bUseSQLite)
    {
        g_DB.Query(SQL_OnGenericQueryFinished, "CREATE TABLE IF NOT EXISTS mgemod_stats (rating INTEGER, steamid TEXT, name TEXT, wins INTEGER, losses INTEGER, lastplayed INTEGER)");
        g_DB.Query(SQL_OnGenericQueryFinished, "CREATE TABLE IF NOT EXISTS mgemod_duels (winner TEXT, loser TEXT, winnerscore INTEGER, loserscore INTEGER, winlimit INTEGER, gametime INTEGER, mapname TEXT, arenaname TEXT) ");
        g_DB.Query(SQL_OnGenericQueryFinished, "CREATE TABLE IF NOT EXISTS mgemod_duels_2v2 (winner TEXT, winner2 TEXT, loser TEXT, loser2 TEXT, winnerscore INTEGER, loserscore INTEGER, winlimit INTEGER, gametime INTEGER, mapname TEXT, arenaname TEXT) ");
    }
    else
    {
        g_DB.Query(SQL_OnGenericQueryFinished, "CREATE TABLE IF NOT EXISTS mgemod_stats (rating INT(4) NOT NULL, steamid VARCHAR(32) NOT NULL, name VARCHAR(64) NOT NULL, wins INT(4) NOT NULL, losses INT(4) NOT NULL, lastplayed INT(11) NOT NULL) DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE = InnoDB ");
        g_DB.Query(SQL_OnGenericQueryFinished, "CREATE TABLE IF NOT EXISTS mgemod_duels (winner VARCHAR(32) NOT NULL, loser VARCHAR(32) NOT NULL, winnerscore INT(4) NOT NULL, loserscore INT(4) NOT NULL, winlimit INT(4) NOT NULL, gametime INT(11) NOT NULL, mapname VARCHAR(64) NOT NULL, arenaname VARCHAR(32) NOT NULL) DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE = InnoDB ");
        g_DB.Query(SQL_OnGenericQueryFinished, "CREATE TABLE IF NOT EXISTS mgemod_duels_2v2 (winner VARCHAR(32) NOT NULL, winner2 VARCHAR(32) NOT NULL, loser VARCHAR(32) NOT NULL, loser2 VARCHAR(32) NOT NULL, winnerscore INT(4) NOT NULL, loserscore INT(4) NOT NULL, winlimit INT(4) NOT NULL, gametime INT(11) NOT NULL, mapname VARCHAR(64) NOT NULL, arenaname VARCHAR(32) NOT NULL) DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE = InnoDB ");
    }

    RunDatabaseMigrations();
}

void SQLDbConnTest(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        LogError("Database connection test failed: connection lost");
        LogError("Database reconnect failed, next attempt in %i minutes.", g_iReconnectInterval);
        PrintHintTextToAll("%t", "DatabaseDown", g_iReconnectInterval);

        if (g_hDBReconnectTimer == null)
            g_hDBReconnectTimer = CreateTimer(float(60 * g_iReconnectInterval), Timer_ReconnectToDB, TIMER_FLAG_NO_MAPCHANGE);
    }
    else if (!StrEqual("", error))
    {
        LogError("Database connection test query failed: %s", error);
        LogError("Database reconnect failed, next attempt in %i minutes.", g_iReconnectInterval);
        PrintHintTextToAll("%t", "DatabaseDown", g_iReconnectInterval);

        if (g_hDBReconnectTimer == null)
            g_hDBReconnectTimer = CreateTimer(float(60 * g_iReconnectInterval), Timer_ReconnectToDB, TIMER_FLAG_NO_MAPCHANGE);
    } else {
        g_bNoStats = gcvar_stats.BoolValue ? false : true;

        if (!g_bNoStats && db != null)
        {
            // Database connection successful - handle both reconnection and hot-loading scenarios
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsValidClient(i))
                {
                    char steamid_dirty[31], steamid[64], query[256];
                    GetClientAuthId(i, AuthId_Steam2, steamid_dirty, sizeof(steamid_dirty));
                    db.Escape(steamid_dirty, steamid, sizeof(steamid));
                    strcopy(g_sPlayerSteamID[i], 32, steamid);
                    g_DB.Format(query, sizeof(query), "SELECT rating, wins, losses FROM mgemod_stats WHERE steamid='%s' LIMIT 1", steamid);
                    db.Query(SQL_OnPlayerReceived, query, i);
                    
                    // Handle hot-loading case: initialize client state that requires DB
                    if (!IsFakeClient(i))
                    {
                        // Ensure spectator team and proper client setup
                        ChangeClientTeam(i, TFTeam_Spectator);
                        g_bShowHud[i] = true;
                        g_bPlayerRestoringAmmo[i] = false;
                    }
                }
            }

            // Refresh all huds to show stats again.
            ShowHudToAll();

            PrintHintTextToAll("%t", "StatsRestored");
            LogError("Database connection restored.");
        } else {
            PrintHintTextToAll("%t", "StatsRestoredDown");
            LogError("Database connection restored but stats are disabled or DB handle is invalid.");
        }
    }
}

void SQL_OnTestReceived(Database db, DBResultSet results, const char[] error, any data)
{
    int client = data;

    if (db == null)
    {
        LogError("[Test] Query failed: database connection lost");
        PrintToChat(client, "[Test] Database connection lost");
        return;
    }
    
    if (results == null)
    {
        LogError("[Test] Query failed: %s", error);
        PrintToChat(client, "[Test] Query failed: %s", error);
        return;
    }

    if (client < 1 || client > MaxClients || !IsClientConnected(client))
    {
        LogError("SQL_OnTestReceived failed: client %d <%s> is invalid.", client, g_sPlayerSteamID[client]);
        return;
    }

    if (results.FetchRow())
        PrintToChat(client, "\x01Database is \x04Up\x01.");
    else
        PrintToChat(client, "\x01Database is \x04Down\x01.");
}

void SQL_OnPlayerReceived(Database db, DBResultSet results, const char[] error, any data)
{
    int client = data;

    if (db == null)
    {
        LogError("SQL_OnPlayerReceived failed: database connection lost");
        return;
    }
    
    if (results == null)
    {
        LogError("SQL_OnPlayerReceived failed: %s", error);
        return;
    }

    if ( client < 1 || client > MaxClients || !IsClientConnected(client) )
    {
        LogError("SQL_OnPlayerReceived failed: client %d <%s> is invalid.", client, g_sPlayerSteamID[client]);
        return;
    }

    char query[512];
    char namesql_dirty[MAX_NAME_LENGTH], namesql[(MAX_NAME_LENGTH * 2) + 1];
    GetClientName(client, namesql_dirty, sizeof(namesql_dirty));
    db.Escape(namesql_dirty, namesql, sizeof(namesql));

    if (results.FetchRow())
    {
        g_iPlayerRating[client] = results.FetchInt(0);
        g_iPlayerWins[client] = results.FetchInt(1);
        g_iPlayerLosses[client] = results.FetchInt(2);

        g_DB.Format(query, sizeof(query), "UPDATE mgemod_stats SET name='%s' WHERE steamid='%s'", namesql, g_sPlayerSteamID[client]);
        db.Query(SQL_OnGenericQueryFinished, query);
    } else {
        if (g_bUseSQLite)
        {
            g_DB.Format(query, sizeof(query), "INSERT INTO mgemod_stats VALUES(1600, '%s', '%s', 0, 0, %i)", g_sPlayerSteamID[client], namesql, GetTime());
            db.Query(SQL_OnGenericQueryFinished, query);
        } else {
            g_DB.Format(query, sizeof(query), "INSERT INTO mgemod_stats (rating, steamid, name, wins, losses, lastplayed) VALUES (1600, '%s', '%s', 0, 0, %i)", g_sPlayerSteamID[client], namesql, GetTime());
            db.Query(SQL_OnGenericQueryFinished, query);
        }

        g_iPlayerRating[client] = 1600;
    }
}

void SQL_OnGenericQueryFinished(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        LogError("SQL_OnGenericQueryFinished: Database connection lost (db handle is null)");
        
        if (!g_bNoStats)
        {
            g_bNoStats = true;
            PrintHintTextToAll("%t", "DatabaseDown", g_iReconnectInterval);

            // Refresh all huds to get rid of stats display.
            ShowHudToAll();

            LogError("Lost connection to database, attempting reconnect in %i minutes.", g_iReconnectInterval);

            if (g_hDBReconnectTimer == null)
                g_hDBReconnectTimer = CreateTimer(float(60 * g_iReconnectInterval), Timer_ReconnectToDB, TIMER_FLAG_NO_MAPCHANGE);
        }
    }
    else if (!StrEqual("", error))
    {
        LogError("SQL_OnGenericQueryFinished: Query failed (connection OK): %s", error);
    }
}

Action Timer_ReconnectToDB(Handle timer)
{
    g_hDBReconnectTimer = null;

    char query[256];
    g_DB.Format(query, sizeof(query), "SELECT rating FROM mgemod_stats LIMIT 1");
    g_DB.Query(SQLDbConnTest, query);

    return Plugin_Continue;
}