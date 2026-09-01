// ===== DATABASE INITIALIZATION =====

// Establishes database connection, detects database type, creates initial tables, and runs migrations
void PrepareSQL() 
{
    char error[256];
    bool usingFallback = false;

    // Check if database config is specified and exists
    if (strlen(g_sDBConfig) == 0 || !SQL_CheckConfig(g_sDBConfig))
    {
        if (strlen(g_sDBConfig) > 0)
        {
            LogMessage("Database config '%s' not found in databases.cfg, falling back to storage-local (SQLite)", g_sDBConfig);
        }
        
        g_DB = SQL_Connect("storage-local", true, error, sizeof(error));
        usingFallback = true;
        
        if (g_DB == null)
        {
            LogError("Could not connect to SQLite database: %s - stats will retry in the background", error);
            g_bNoStats = true;
            if (g_bLate)
                HandleHotReload();
            return;
        }
    }
    else
    {
        g_DB = SQL_Connect(g_sDBConfig, true, error, sizeof(error));
        
        if (g_DB == null)
        {
            // Failed to connect to specified config, try fallback to storage-local
            LogError("Could not connect to database config '%s': %s - falling back to storage-local", g_sDBConfig, error);
            
            g_DB = SQL_Connect("storage-local", true, error, sizeof(error));
            usingFallback = true;
            
            if (g_DB == null)
            {
                LogError("Could not connect to SQLite fallback database: %s - stats will retry in the background", error);
                g_bNoStats = true;
                if (g_bLate)
                    HandleHotReload();
                return;
            }
        }
    }

    char ident[16];
    g_DB.Driver.GetIdentifier(ident, sizeof(ident));

    if (StrEqual(ident, "mysql", false))
    {
        g_DatabaseType = DB_MYSQL;
    }
    else if (StrEqual(ident, "sqlite", false))
    {
        g_DatabaseType = DB_SQLITE;
    }
    else if (StrEqual(ident, "pgsql", false))
    {
        g_DatabaseType = DB_POSTGRESQL;
    }
    else
    {
        LogError("Unsupported database type: %s - stats will remain unavailable", ident);
        g_bNoStats = true;
        delete g_DB;
        g_DB = null;
        if (g_bLate)
            HandleHotReload();
        return;
    }

    if (g_DatabaseType == DB_MYSQL)
    {
        if (!g_DB.SetCharset("utf8mb4"))
        {
            LogError("Failed to set MySQL connection charset to utf8mb4 - player names may be stored incorrectly");
        }
        else
        {
            LogMessage("MySQL connection charset set to utf8mb4");
        }
    }

    if (usingFallback)
    {
        LogMessage("Successfully connected to fallback database 'storage-local' [%s]", ident);
    }
    else
    {
        LogMessage("Successfully connected to database config '%s' [%s]", g_sDBConfig, ident);
    }

    // Create tables using abstraction layer
    char query[1024];
    
    GetCreateTableQuery_Stats(query, sizeof(query));
    g_DB.Query(SQL_OnGenericQueryFinished, query);
    
    GetCreateTableQuery_Duels(query, sizeof(query));
    g_DB.Query(SQL_OnGenericQueryFinished, query);
    
    GetCreateTableQuery_Duels2v2(query, sizeof(query));
    g_DB.Query(SQL_OnGenericQueryFinished, query);
    
    if (g_DatabaseType == DB_POSTGRESQL)
    {
        g_DB.Query(SQL_OnGenericQueryFinished, "CREATE UNIQUE INDEX IF NOT EXISTS idx_stats_steamid ON mgemod_stats (steamid)");
        
        int currentTime = GetTime();
        char migrationQuery[256];
        g_DB.Format(migrationQuery, sizeof(migrationQuery), "INSERT INTO mgemod_migrations (migration_name, executed_at) VALUES ('001_add_class_columns', %d) ON CONFLICT (migration_name) DO NOTHING", currentTime);
        g_DB.Query(SQL_OnGenericQueryFinished, migrationQuery);
        
        g_DB.Format(migrationQuery, sizeof(migrationQuery), "INSERT INTO mgemod_migrations (migration_name, executed_at) VALUES ('002_duel_timing_columns', %d) ON CONFLICT (migration_name) DO NOTHING", currentTime);
        g_DB.Query(SQL_OnGenericQueryFinished, migrationQuery);
        
        g_DB.Format(migrationQuery, sizeof(migrationQuery), "INSERT INTO mgemod_migrations (migration_name, executed_at) VALUES ('003_add_primary_keys', %d) ON CONFLICT (migration_name) DO NOTHING", currentTime);
        g_DB.Query(SQL_OnGenericQueryFinished, migrationQuery);
        
        g_DB.Format(migrationQuery, sizeof(migrationQuery), "INSERT INTO mgemod_migrations (migration_name, executed_at) VALUES ('004_add_elo_tracking', %d) ON CONFLICT (migration_name) DO NOTHING", currentTime);
        g_DB.Query(SQL_OnGenericQueryFinished, migrationQuery);
        
        g_DB.Format(migrationQuery, sizeof(migrationQuery), "INSERT INTO mgemod_migrations (migration_name, executed_at) VALUES ('005_utf8mb4_charset', %d) ON CONFLICT (migration_name) DO NOTHING", currentTime);
        g_DB.Query(SQL_OnGenericQueryFinished, migrationQuery);
        
        g_DB.Format(migrationQuery, sizeof(migrationQuery), "INSERT INTO mgemod_migrations (migration_name, executed_at) VALUES ('006_drop_hitblip_column', %d) ON CONFLICT (migration_name) DO NOTHING", currentTime);
        g_DB.Query(SQL_OnGenericQueryFinished, migrationQuery);
    }

    RunDatabaseMigrations();

    // Handle hot reload after database is ready
    if (g_bLate)
    {
        HandleHotReload();
    }
}


// ===== CONNECTION MANAGEMENT =====

// Tests database connection and handles reconnection logic with player state restoration
void SQLDbConnTest(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        LogError("Database connection test failed: connection lost");
        LogError("Database reconnect failed, next attempt in %i minutes.", g_iReconnectInterval);
        PrintHintTextToAll("%t", "DatabaseDownStats", g_iReconnectInterval);

        if (g_hDBReconnectTimer == null)
            g_hDBReconnectTimer = CreateTimer(float(60 * g_iReconnectInterval), Timer_ReconnectToDB, TIMER_FLAG_NO_MAPCHANGE);
    }
    else if (!StrEqual("", error))
    {
        LogError("Database connection test query failed: %s", error);
        LogError("Database reconnect failed, next attempt in %i minutes.", g_iReconnectInterval);
        PrintHintTextToAll("%t", "DatabaseDownStats", g_iReconnectInterval);

        if (g_hDBReconnectTimer == null)
            g_hDBReconnectTimer = CreateTimer(float(60 * g_iReconnectInterval), Timer_ReconnectToDB, TIMER_FLAG_NO_MAPCHANGE);
    } else {
        g_bNoStats = gcvar_stats.BoolValue ? false : true;

        if (!g_bNoStats && db != null)
        {
            // Database connection successful - handle both reconnection and hot-loading scenarios
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsValidClient(i) && !IsFakeClient(i))
                {
                    ResetPlayerStatsIdentity(i);
                    TryLoadPlayerStats(i, true);
                }
            }

            // Refresh all huds to show stats again.
            UpdateHudForAll();

            PrintHintTextToAll("%t", "StatsRestored");
            LogError("Database connection restored.");
        } else {
            PrintHintTextToAll("%t", "StatsRestoredDown");
            LogError("Database connection restored but stats are disabled or DB handle is invalid.");
        }
    }
}


// ===== DATABASE QUERY HANDLERS =====

// Processes database test query results and reports connection status to client
void SQL_OnTestReceived(Database db, DBResultSet results, const char[] error, any data)
{
    int client = data;

    if (db == null)
    {
        LogError("[Test] Query failed: database connection lost");
        MC_PrintToChat(client, "%t", "DatabaseConnectionLost");
        return;
    }
    
    if (results == null)
    {
        LogError("[Test] Query failed: %s", error);
        MC_PrintToChat(client, "%t", "QueryFailed", error);
        return;
    }

    if (client < 1 || client > MaxClients || !IsClientConnected(client))
    {
        LogError("SQL_OnTestReceived failed: client %d <%s> is invalid.", client, g_sPlayerSteamID[client]);
        return;
    }

    if (results.FetchRow())
        MC_PrintToChat(client, "%t", "DatabaseUp");
    else
        MC_PrintToChat(client, "%t", "DatabaseDown");
}

void HandleDatabaseConnectionLoss(int failed_client = 0)
{
    if (!gcvar_stats.BoolValue)
        return;

    if (g_hDBReconnectTimer != null)
    {
        if (failed_client > 0)
        {
            CancelEloRetry(failed_client);
            g_iPlayerStatsLoadGeneration[failed_client]++;
            g_bEloSlowRetry[failed_client] = true;
            ScheduleEloRetry(failed_client, MGE_STATS_DB_FAILED);
        }
        return;
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && !IsFakeClient(i))
        {
            CancelEloRetry(i);
            g_iPlayerStatsLoadGeneration[i]++;
            g_bEloSlowRetry[i] = true;
            ScheduleEloRetry(i, MGE_STATS_DB_FAILED);
        }
    }

    PrintHintTextToAll("%t", "DatabaseDownStats", g_iReconnectInterval);
    UpdateHudForAll();
    LogError("Lost connection to database, attempting reconnect in %i minutes.", g_iReconnectInterval);
    g_hDBReconnectTimer = CreateTimer(float(60 * g_iReconnectInterval), Timer_ReconnectToDB, TIMER_FLAG_NO_MAPCHANGE);
}

// Handles player statistics retrieval from database and creates new player records if needed
void SQL_OnPlayerReceived(Database db, DBResultSet results, const char[] error, any data)
{
    int client;
    if (!ReadPlayerStatsLoadData(data, client))
        return;

    if (db == null)
    {
        LogError("SQL_OnPlayerReceived failed: database connection lost for client %d", client);
        HandleDatabaseConnectionLoss(client);
        return;
    }
    
    if (results == null)
    {
        LogError("SQL_OnPlayerReceived FAILED for client %d (%s): %s", 
                 client, g_sPlayerSteamID[client], error);
        ScheduleEloRetry(client);
        return;
    }

    if (!IsClientConnected(client))
        return;

    char query[512];
    char namesql_dirty[MAX_NAME_LENGTH], namesql[(MAX_NAME_LENGTH * 2) + 1];
    GetClientName(client, namesql_dirty, sizeof(namesql_dirty));
    db.Escape(namesql_dirty, namesql, sizeof(namesql));

    if (results.FetchRow())
    {
        g_iPlayerRating[client] = results.FetchInt(0);
        g_iPlayerWins[client] = results.FetchInt(1);
        g_iPlayerLosses[client] = results.FetchInt(2);

        if (results.IsFieldNull(3))
        {
            g_bPlayerGlickoSeeded[client] = false;
            g_fPlayerRD[client] = 0.0;
            g_fPlayerVolatility[client] = 0.0;
        }
        else
        {
            g_bPlayerGlickoSeeded[client] = true;
            g_fPlayerRD[client] = results.FetchFloat(3);
            g_fPlayerVolatility[client] = results.FetchFloat(4);
        }
        g_iPlayerLastPlayed[client] = results.FetchInt(5);
        g_iPlayerRatingEst[client] = g_iPlayerRating[client];
        g_fPlayerRDEst[client] = g_fPlayerRD[client];
        g_bPlayerPeriodDirty[client] = false;
        if (g_bGlickoPeriodSchemaReady && results.FieldCount > 6)
        {
            if (!results.IsFieldNull(6))
                g_iPlayerRatingEst[client] = results.FetchInt(6);
            if (!results.IsFieldNull(7))
                g_fPlayerRDEst[client] = results.FetchFloat(7);
            g_bPlayerPeriodDirty[client] = (results.FetchInt(8) != 0);
        }

        CancelEloRetry(client);
        SetPlayerStatsLoadState(client, MGE_STATS_LOADED);

        GetUpdatePlayerNameQuery(query, sizeof(query), namesql, g_sPlayerSteamID[client]);
        db.Query(SQL_OnGenericQueryFinished, query);
    }
    else
    {
        GetInsertPlayerQuery(query, sizeof(query), g_sPlayerSteamID[client], namesql, GetTime());
        db.Query(SQL_OnPlayerInserted, query, CreatePlayerStatsLoadData(client));
    }
}

// Confirms that a new statistics row exists before exposing its default values
void SQL_OnPlayerInserted(Database db, DBResultSet results, const char[] error, any data)
{
    int client;
    if (!ReadPlayerStatsLoadData(data, client))
        return;

    if (db == null)
    {
        LogError("SQL_OnPlayerInserted failed: database connection lost for client %d", client);
        HandleDatabaseConnectionLoss(client);
        return;
    }

    if (!StrEqual("", error))
    {
        LogError("SQL_OnPlayerInserted failed for client %d (%s): %s", client, g_sPlayerSteamID[client], error);
        ScheduleEloRetry(client);
        return;
    }

    g_iPlayerRating[client] = DEFAULT_STARTING_ELO;
    g_iPlayerWins[client] = 0;
    g_iPlayerLosses[client] = 0;
    if (g_eRatingEngine == RATING_ENGINE_GLICKO2)
    {
        // Matches the rd/volatility defaults GetInsertPlayerQuery just wrote to the row.
        g_bPlayerGlickoSeeded[client] = true;
        g_fPlayerRD[client] = GLICKO2_MAX_RD;
        g_fPlayerVolatility[client] = GLICKO2_DEFAULT_VOLATILITY;
        g_iPlayerRatingEst[client] = DEFAULT_STARTING_ELO;
        g_fPlayerRDEst[client] = GLICKO2_MAX_RD;
        g_bPlayerPeriodDirty[client] = false;
    }
    else
    {
        g_bPlayerGlickoSeeded[client] = false;
        g_fPlayerRD[client] = 0.0;
        g_fPlayerVolatility[client] = 0.0;
        g_iPlayerRatingEst[client] = DEFAULT_STARTING_ELO;
        g_fPlayerRDEst[client] = 0.0;
        g_bPlayerPeriodDirty[client] = false;
    }
    g_iPlayerLastPlayed[client] = 0;
    CancelEloRetry(client);
    SetPlayerStatsLoadState(client, MGE_STATS_LOADED);
}

// Generic callback for database queries with error handling and connection monitoring
void SQL_OnGenericQueryFinished(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        LogError("SQL_OnGenericQueryFinished: Database connection lost (db handle is null)");
        HandleDatabaseConnectionLoss();
    }
    else if (!StrEqual("", error))
    {
        LogError("SQL_OnGenericQueryFinished: Query failed (connection OK): %s", error);
    }
}


// ===== RESILIENT MATCH-RESULT PERSISTENCE =====
//
// A single duel touches multiple rows: the mgemod_duels(_2v2) audit row and one mgemod_stats
// UPDATE per participant. Firing those as independent SQL_OnGenericQueryFinished queries means
// any one of them can silently fail (a transient DB hiccup, lock timeout, brief disconnect)
// while the others succeed, leaving the duel log and the player's stored rating disagreeing
// with each other forever - SQL_OnGenericQueryFinished only logs a failure, it never retries.
//
// ExecuteMatchResultQueries groups every write for one match into a single SourceMod
// Transaction (all queries commit together or none do), and retries the whole transaction
// with backoff if it fails, instead of dropping the write.
// (MATCH_TXN_* constants are defined in mge/globals.sp, included before this file.)

void ExecuteMatchResultQueries(char queries[MATCH_TXN_MAX_QUERIES][MATCH_TXN_QUERY_LEN], int queryCount, int attempt = 0)
{
    Transaction txn = new Transaction();
    for (int i = 0; i < queryCount; i++)
        txn.AddQuery(queries[i]);

    DataPack pack = new DataPack();
    pack.WriteCell(queryCount);
    for (int i = 0; i < queryCount; i++)
        pack.WriteString(queries[i]);
    pack.WriteCell(attempt);

    g_DB.Execute(txn, OnMatchResultTransactionSuccess, OnMatchResultTransactionFailure, pack);
}

void OnMatchResultTransactionSuccess(Database db, DataPack pack, int numQueries, DBResultSet[] results, any[] queryData)
{
    delete pack;
}

void OnMatchResultTransactionFailure(Database db, DataPack pack, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    pack.Reset();
    int queryCount = pack.ReadCell();
    char queries[MATCH_TXN_MAX_QUERIES][MATCH_TXN_QUERY_LEN];
    for (int i = 0; i < queryCount; i++)
        pack.ReadString(queries[i], MATCH_TXN_QUERY_LEN);
    int attempt = pack.ReadCell();
    delete pack;

    if (db == null)
        HandleDatabaseConnectionLoss();

    LogError("Match-result transaction failed at query %d/%d (attempt %d): %s", failIndex, numQueries, attempt + 1, error);

    if (attempt >= MATCH_TXN_MAX_RETRIES)
    {
        LogError("Giving up on match-result transaction after %d attempts - %d quer%s for this match were not applied, manual correction required", attempt + 1, queryCount, queryCount == 1 ? "y" : "ies");
        return;
    }

    DataPack retryPack = new DataPack();
    retryPack.WriteCell(queryCount);
    for (int i = 0; i < queryCount; i++)
        retryPack.WriteString(queries[i]);
    retryPack.WriteCell(attempt + 1);
    CreateTimer(Pow(2.0, float(attempt + 1)), Timer_RetryMatchResultTransaction, retryPack);
}

Action Timer_RetryMatchResultTransaction(Handle timer, DataPack pack)
{
    pack.Reset();
    int queryCount = pack.ReadCell();
    char queries[MATCH_TXN_MAX_QUERIES][MATCH_TXN_QUERY_LEN];
    for (int i = 0; i < queryCount; i++)
        pack.ReadString(queries[i], MATCH_TXN_QUERY_LEN);
    int attempt = pack.ReadCell();
    delete pack;

    ExecuteMatchResultQueries(queries, queryCount, attempt);
    return Plugin_Stop;
}


// ===== TIMER FUNCTIONS =====

// Attempts database reconnection after connection loss with periodic retry mechanism
Action Timer_ReconnectToDB(Handle timer)
{
    g_hDBReconnectTimer = null;

    char query[256];
    GetSelectConnectionTestQuery(query, sizeof(query));
    g_DB.Query(SQLDbConnTest, query);

    return Plugin_Continue;
}


// ===== DATABASE ABSTRACTION LAYER =====

// Gets database-specific CREATE TABLE statement for mgemod_stats
void GetCreateTableQuery_Stats(char[] query, int maxlen)
{
    switch (g_DatabaseType)
    {
        case DB_SQLITE:
        {
            strcopy(query, maxlen, "CREATE TABLE IF NOT EXISTS mgemod_stats (rating INTEGER, steamid TEXT, name TEXT, wins INTEGER, losses INTEGER, lastplayed INTEGER)");
        }
        case DB_MYSQL:
        {
            strcopy(query, maxlen, "CREATE TABLE IF NOT EXISTS mgemod_stats (rating INT(4) NOT NULL, steamid VARCHAR(32) NOT NULL, name VARCHAR(64) NOT NULL, wins INT(4) NOT NULL, losses INT(4) NOT NULL, lastplayed INT(11) NOT NULL) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ENGINE = InnoDB");
        }
        case DB_POSTGRESQL:
        {
            strcopy(query, maxlen, "CREATE TABLE IF NOT EXISTS mgemod_stats (rating INTEGER NOT NULL, steamid VARCHAR(32) NOT NULL, name VARCHAR(64) NOT NULL, wins INTEGER NOT NULL, losses INTEGER NOT NULL, lastplayed INTEGER NOT NULL, rd REAL, volatility REAL)");
        }
    }
}

// Gets database-specific CREATE TABLE statement for mgemod_duels
void GetCreateTableQuery_Duels(char[] query, int maxlen)
{
    switch (g_DatabaseType)
    {
        case DB_SQLITE:
        {
            strcopy(query, maxlen, "CREATE TABLE IF NOT EXISTS mgemod_duels (winner TEXT, loser TEXT, winnerscore INTEGER, loserscore INTEGER, winlimit INTEGER, gametime INTEGER, mapname TEXT, arenaname TEXT)");
        }
        case DB_MYSQL:
        {
            strcopy(query, maxlen, "CREATE TABLE IF NOT EXISTS mgemod_duels (winner VARCHAR(32) NOT NULL, loser VARCHAR(32) NOT NULL, winnerscore INT(4) NOT NULL, loserscore INT(4) NOT NULL, winlimit INT(4) NOT NULL, gametime INT(11) NOT NULL, mapname VARCHAR(64) NOT NULL, arenaname VARCHAR(32) NOT NULL) DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE = InnoDB");
        }
        case DB_POSTGRESQL:
        {
            strcopy(query, maxlen, "CREATE TABLE IF NOT EXISTS mgemod_duels (id SERIAL PRIMARY KEY, winner VARCHAR(32) NOT NULL, winnerclass VARCHAR(64), loser VARCHAR(32) NOT NULL, loserclass VARCHAR(64), winnerscore INTEGER NOT NULL, loserscore INTEGER NOT NULL, winlimit INTEGER NOT NULL, starttime INTEGER, endtime INTEGER NOT NULL, mapname VARCHAR(64) NOT NULL, arenaname VARCHAR(32) NOT NULL, winner_previous_elo INTEGER, winner_new_elo INTEGER, loser_previous_elo INTEGER, loser_new_elo INTEGER)");
        }
    }
}

// Gets database-specific CREATE TABLE statement for mgemod_duels_2v2
void GetCreateTableQuery_Duels2v2(char[] query, int maxlen)
{
    switch (g_DatabaseType)
    {
        case DB_SQLITE:
        {
            strcopy(query, maxlen, "CREATE TABLE IF NOT EXISTS mgemod_duels_2v2 (winner TEXT, winner2 TEXT, loser TEXT, loser2 TEXT, winnerscore INTEGER, loserscore INTEGER, winlimit INTEGER, gametime INTEGER, mapname TEXT, arenaname TEXT)");
        }
        case DB_MYSQL:
        {
            strcopy(query, maxlen, "CREATE TABLE IF NOT EXISTS mgemod_duels_2v2 (winner VARCHAR(32) NOT NULL, winner2 VARCHAR(32) NOT NULL, loser VARCHAR(32) NOT NULL, loser2 VARCHAR(32) NOT NULL, winnerscore INT(4) NOT NULL, loserscore INT(4) NOT NULL, winlimit INT(4) NOT NULL, gametime INT(11) NOT NULL, mapname VARCHAR(64) NOT NULL, arenaname VARCHAR(32) NOT NULL) DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE = InnoDB");
        }
        case DB_POSTGRESQL:
        {
            strcopy(query, maxlen, "CREATE TABLE IF NOT EXISTS mgemod_duels_2v2 (id SERIAL PRIMARY KEY, winner VARCHAR(32) NOT NULL, winnerclass VARCHAR(64), winner2 VARCHAR(32) NOT NULL, winner2class VARCHAR(64), loser VARCHAR(32) NOT NULL, loserclass VARCHAR(64), loser2 VARCHAR(32) NOT NULL, loser2class VARCHAR(64), winnerscore INTEGER NOT NULL, loserscore INTEGER NOT NULL, winlimit INTEGER NOT NULL, starttime INTEGER, endtime INTEGER NOT NULL, mapname VARCHAR(64) NOT NULL, arenaname VARCHAR(32) NOT NULL, winner_previous_elo INTEGER, winner_new_elo INTEGER, winner2_previous_elo INTEGER, winner2_new_elo INTEGER, loser_previous_elo INTEGER, loser_new_elo INTEGER, loser2_previous_elo INTEGER, loser2_new_elo INTEGER)");
        }
    }
}

// Gets database-specific CREATE TABLE statement for mgemod_migrations
void GetCreateTableQuery_Migrations(char[] query, int maxlen)
{
    switch (g_DatabaseType)
    {
        case DB_SQLITE:
        {
            strcopy(query, maxlen, "CREATE TABLE IF NOT EXISTS mgemod_migrations (id INTEGER PRIMARY KEY, migration_name TEXT UNIQUE, executed_at INTEGER)");
        }
        case DB_MYSQL:
        {
            strcopy(query, maxlen, "CREATE TABLE IF NOT EXISTS mgemod_migrations (id INT AUTO_INCREMENT PRIMARY KEY, migration_name VARCHAR(255) UNIQUE, executed_at INT) DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE = InnoDB");
        }
        case DB_POSTGRESQL:
        {
            strcopy(query, maxlen, "CREATE TABLE IF NOT EXISTS mgemod_migrations (id SERIAL PRIMARY KEY, migration_name VARCHAR(255) UNIQUE, executed_at INTEGER)");
        }
    }
}

// Gets database-specific INSERT statement for player stats.
// Under Glicko-2, rd/volatility are seeded to their defaults immediately on row creation instead
// of staying NULL until the player's first duel - this is what keeps "NULL rd" meaning exactly
// one thing (Elo is active), never "Glicko-2 player who just hasn't played yet". See
// Rating_GetGlickoReconcileQuery for the runtime/migration side of the same invariant.
void GetInsertPlayerQuery(char[] query, int maxlen, const char[] steamid, const char[] name, int timestamp)
{
    bool seedGlicko = (g_eRatingEngine == RATING_ENGINE_GLICKO2);

    switch (g_DatabaseType)
    {
        case DB_SQLITE:
        {
            if (seedGlicko)
                g_DB.Format(query, maxlen, "INSERT INTO mgemod_stats (rating, steamid, name, wins, losses, lastplayed, rd, volatility) VALUES (1600, '%s', '%s', 0, 0, %i, %f, %f)", steamid, name, timestamp, GLICKO2_MAX_RD, GLICKO2_DEFAULT_VOLATILITY);
            else
                g_DB.Format(query, maxlen, "INSERT INTO mgemod_stats (rating, steamid, name, wins, losses, lastplayed) VALUES (1600, '%s', '%s', 0, 0, %i)", steamid, name, timestamp);
        }
        case DB_MYSQL:
        {
            if (seedGlicko)
                g_DB.Format(query, maxlen, "INSERT INTO mgemod_stats (rating, steamid, name, wins, losses, lastplayed, rd, volatility) VALUES (1600, '%s', '%s', 0, 0, %i, %f, %f)", steamid, name, timestamp, GLICKO2_MAX_RD, GLICKO2_DEFAULT_VOLATILITY);
            else
                g_DB.Format(query, maxlen, "INSERT INTO mgemod_stats (rating, steamid, name, wins, losses, lastplayed) VALUES (1600, '%s', '%s', 0, 0, %i)", steamid, name, timestamp);
        }
        case DB_POSTGRESQL:
        {
            if (seedGlicko)
                g_DB.Format(query, maxlen, "INSERT INTO mgemod_stats (rating, steamid, name, wins, losses, lastplayed, rd, volatility) VALUES (1600, '%s', '%s', 0, 0, %i, %f, %f) ON CONFLICT (steamid) DO UPDATE SET name = EXCLUDED.name, lastplayed = EXCLUDED.lastplayed", steamid, name, timestamp, GLICKO2_MAX_RD, GLICKO2_DEFAULT_VOLATILITY);
            else
                g_DB.Format(query, maxlen, "INSERT INTO mgemod_stats (rating, steamid, name, wins, losses, lastplayed) VALUES (1600, '%s', '%s', 0, 0, %i) ON CONFLICT (steamid) DO UPDATE SET name = EXCLUDED.name, lastplayed = EXCLUDED.lastplayed", steamid, name, timestamp);
        }
    }
}

// Gets database-specific SELECT statement for player stats
void GetSelectPlayerStatsQuery(char[] query, int maxlen, const char[] steamid)
{
    if (g_bGlickoPeriodSchemaReady)
        g_DB.Format(query, maxlen, "SELECT rating, wins, losses, rd, volatility, lastplayed, rating_est, rd_est, period_dirty FROM mgemod_stats WHERE steamid='%s' LIMIT 1", steamid);
    else
        g_DB.Format(query, maxlen, "SELECT rating, wins, losses, rd, volatility, lastplayed FROM mgemod_stats WHERE steamid='%s' LIMIT 1", steamid);
}

// Gets database-specific UPDATE statement for player name
void GetUpdatePlayerNameQuery(char[] query, int maxlen, const char[] name, const char[] steamid)
{
    g_DB.Format(query, maxlen, "UPDATE mgemod_stats SET name='%s' WHERE steamid='%s'", name, steamid);
}

// Gets database-specific UPDATE statement for winner stats.
// ratingDelta is applied as "rating = rating + delta" rather than an absolute SET, so this
// write always lands relative to whatever is currently stored in the row - it can never
// clobber a newer value written by another game server sharing this region's database in
// the meantime, even if this server's own cached copy of the player's rating is stale.
void GetUpdateWinnerStatsQuery(char[] query, int maxlen, int ratingDelta, int timestamp, const char[] steamid)
{
    g_DB.Format(query, maxlen, "UPDATE mgemod_stats SET rating=rating+(%i),wins=wins+1,lastplayed=%i WHERE steamid='%s'", ratingDelta, timestamp, steamid);
}

// Gets database-specific UPDATE statement for loser stats (see GetUpdateWinnerStatsQuery for why ratingDelta is relative).
void GetUpdateLoserStatsQuery(char[] query, int maxlen, int ratingDelta, int timestamp, const char[] steamid)
{
    g_DB.Format(query, maxlen, "UPDATE mgemod_stats SET rating=rating+(%i),losses=losses+1,lastplayed=%i WHERE steamid='%s'", ratingDelta, timestamp, steamid);
}

// Gets database-specific UPDATE statement for winner stats under the Glicko-2 engine (also persists rd/volatility).
// rd/volatility are still written as absolute snapshots - they're confidence trackers rather
// than a point total, so occasional staleness there doesn't lose player-earned/lost rating points
// the way an absolute rating SET would. ratingDelta itself is relative for the same reason as
// the classic Elo path above.
void GetUpdateWinnerGlickoStatsQuery(char[] query, int maxlen, int ratingDelta, float rd, float volatility, int timestamp, const char[] steamid)
{
    g_DB.Format(query, maxlen, "UPDATE mgemod_stats SET rating=rating+(%i),rd=%f,volatility=%f,wins=wins+1,lastplayed=%i WHERE steamid='%s'", ratingDelta, rd, volatility, timestamp, steamid);
}

// Gets database-specific UPDATE statement for loser stats under the Glicko-2 engine (also persists rd/volatility)
void GetUpdateLoserGlickoStatsQuery(char[] query, int maxlen, int ratingDelta, float rd, float volatility, int timestamp, const char[] steamid)
{
    g_DB.Format(query, maxlen, "UPDATE mgemod_stats SET rating=rating+(%i),rd=%f,volatility=%f,losses=losses+1,lastplayed=%i WHERE steamid='%s'", ratingDelta, rd, volatility, timestamp, steamid);
}

void GetUpdateWinsOnlyQuery(char[] query, int maxlen, int timestamp, const char[] steamid)
{
    g_DB.Format(query, maxlen, "UPDATE mgemod_stats SET wins=wins+1,lastplayed=%i WHERE steamid='%s'", timestamp, steamid);
}

void GetUpdateLossesOnlyQuery(char[] query, int maxlen, int timestamp, const char[] steamid)
{
    g_DB.Format(query, maxlen, "UPDATE mgemod_stats SET losses=losses+1,lastplayed=%i WHERE steamid='%s'", timestamp, steamid);
}

// Gets database-specific INSERT statement for duel results
void GetInsertDuelQuery(char[] query, int maxlen, const char[] winner, const char[] loser, int winnerScore, int loserScore, int fragLimit, int endTime, int startTime, const char[] mapName, const char[] arenaName, const char[] winnerClass, const char[] loserClass, int winnerPrevElo, int winnerNewElo, int loserPrevElo, int loserNewElo, int periodId = 0, float winnerSealedRd = 0.0, float winnerSealedVol = 0.0, float loserSealedRd = 0.0, float loserSealedVol = 0.0)
{
    if (g_bGlickoPeriodSchemaReady)
    {
        switch (g_DatabaseType)
        {
            case DB_SQLITE:
            {
                g_DB.Format(query, maxlen, "INSERT OR IGNORE INTO mgemod_duels (winner, loser, winnerscore, loserscore, winlimit, endtime, starttime, mapname, arenaname, winnerclass, loserclass, winner_previous_elo, winner_new_elo, loser_previous_elo, loser_new_elo, period_id, winner_sealed_rating, winner_sealed_rd, winner_sealed_volatility, loser_sealed_rating, loser_sealed_rd, loser_sealed_volatility, period_sealed) VALUES ('%s', '%s', %i, %i, %i, %i, %i, '%s', '%s', '%s', '%s', %i, %i, %i, %i, %i, %i, %f, %f, %i, %f, %f, 0)",
                    winner, loser, winnerScore, loserScore, fragLimit, endTime, startTime, mapName, arenaName, winnerClass, loserClass, winnerPrevElo, winnerNewElo, loserPrevElo, loserNewElo, periodId, winnerPrevElo, winnerSealedRd, winnerSealedVol, loserPrevElo, loserSealedRd, loserSealedVol);
            }
            case DB_MYSQL:
            {
                g_DB.Format(query, maxlen, "INSERT IGNORE INTO mgemod_duels (winner, loser, winnerscore, loserscore, winlimit, endtime, starttime, mapname, arenaname, winnerclass, loserclass, winner_previous_elo, winner_new_elo, loser_previous_elo, loser_new_elo, period_id, winner_sealed_rating, winner_sealed_rd, winner_sealed_volatility, loser_sealed_rating, loser_sealed_rd, loser_sealed_volatility, period_sealed) VALUES ('%s', '%s', %i, %i, %i, %i, %i, '%s', '%s', '%s', '%s', %i, %i, %i, %i, %i, %i, %f, %f, %i, %f, %f, 0)",
                    winner, loser, winnerScore, loserScore, fragLimit, endTime, startTime, mapName, arenaName, winnerClass, loserClass, winnerPrevElo, winnerNewElo, loserPrevElo, loserNewElo, periodId, winnerPrevElo, winnerSealedRd, winnerSealedVol, loserPrevElo, loserSealedRd, loserSealedVol);
            }
            default:
            {
                g_DB.Format(query, maxlen, "INSERT INTO mgemod_duels (winner, loser, winnerscore, loserscore, winlimit, endtime, starttime, mapname, arenaname, winnerclass, loserclass, winner_previous_elo, winner_new_elo, loser_previous_elo, loser_new_elo, period_id, winner_sealed_rating, winner_sealed_rd, winner_sealed_volatility, loser_sealed_rating, loser_sealed_rd, loser_sealed_volatility, period_sealed) VALUES ('%s', '%s', %i, %i, %i, %i, %i, '%s', '%s', '%s', '%s', %i, %i, %i, %i, %i, %i, %f, %f, %i, %f, %f, 0) ON CONFLICT (winner, loser, starttime, endtime) DO NOTHING",
                    winner, loser, winnerScore, loserScore, fragLimit, endTime, startTime, mapName, arenaName, winnerClass, loserClass, winnerPrevElo, winnerNewElo, loserPrevElo, loserNewElo, periodId, winnerPrevElo, winnerSealedRd, winnerSealedVol, loserPrevElo, loserSealedRd, loserSealedVol);
            }
        }
        return;
    }

    switch (g_DatabaseType)
    {
        case DB_SQLITE:
        {
            g_DB.Format(query, maxlen, "INSERT INTO mgemod_duels VALUES (NULL, '%s', '%s', %i, %i, %i, %i, %i, '%s', '%s', '%s', '%s', %i, %i, %i, %i)",
                winner, loser, winnerScore, loserScore, fragLimit, endTime, startTime, mapName, arenaName, winnerClass, loserClass, winnerPrevElo, winnerNewElo, loserPrevElo, loserNewElo);
        }
        case DB_MYSQL, DB_POSTGRESQL:
        {
            g_DB.Format(query, maxlen, "INSERT INTO mgemod_duels (winner, loser, winnerscore, loserscore, winlimit, endtime, starttime, mapname, arenaname, winnerclass, loserclass, winner_previous_elo, winner_new_elo, loser_previous_elo, loser_new_elo) VALUES ('%s', '%s', %i, %i, %i, %i, %i, '%s', '%s', '%s', '%s', %i, %i, %i, %i)",
                winner, loser, winnerScore, loserScore, fragLimit, endTime, startTime, mapName, arenaName, winnerClass, loserClass, winnerPrevElo, winnerNewElo, loserPrevElo, loserNewElo);
        }
    }
}

// Gets database-specific INSERT statement for 2v2 duel results
void GetInsert2v2DuelQuery(char[] query, int maxlen, const char[] winner, const char[] winner2, const char[] loser, const char[] loser2, int winnerScore, int loserScore, int fragLimit, int endTime, int startTime, const char[] mapName, const char[] arenaName, const char[] winnerClass, const char[] winner2Class, const char[] loserClass, const char[] loser2Class, int winnerPrevElo, int winnerNewElo, int winner2PrevElo, int winner2NewElo, int loserPrevElo, int loserNewElo, int loser2PrevElo, int loser2NewElo)
{
    switch (g_DatabaseType)
    {
        case DB_SQLITE:
        {
            g_DB.Format(query, maxlen, "INSERT INTO mgemod_duels_2v2 VALUES (NULL, '%s', '%s', '%s', '%s', %i, %i, %i, %i, %i, '%s', '%s', '%s', '%s', '%s', '%s', %i, %i, %i, %i, %i, %i, %i, %i)",
                winner, winner2, loser, loser2, winnerScore, loserScore, fragLimit, endTime, startTime, mapName, arenaName, winnerClass, winner2Class, loserClass, loser2Class, winnerPrevElo, winnerNewElo, winner2PrevElo, winner2NewElo, loserPrevElo, loserNewElo, loser2PrevElo, loser2NewElo);
        }
        case DB_MYSQL, DB_POSTGRESQL:
        {
            g_DB.Format(query, maxlen, "INSERT INTO mgemod_duels_2v2 (winner, winner2, loser, loser2, winnerscore, loserscore, winlimit, endtime, starttime, mapname, arenaname, winnerclass, winner2class, loserclass, loser2class, winner_previous_elo, winner_new_elo, winner2_previous_elo, winner2_new_elo, loser_previous_elo, loser_new_elo, loser2_previous_elo, loser2_new_elo) VALUES ('%s', '%s', '%s', '%s', %i, %i, %i, %i, %i, '%s', '%s', '%s', '%s', '%s', '%s', %i, %i, %i, %i, %i, %i, %i, %i)",
                winner, winner2, loser, loser2, winnerScore, loserScore, fragLimit, endTime, startTime, mapName, arenaName, winnerClass, winner2Class, loserClass, loser2Class, winnerPrevElo, winnerNewElo, winner2PrevElo, winner2NewElo, loserPrevElo, loserNewElo, loser2PrevElo, loser2NewElo);
        }
    }
}

// Gets database-specific SELECT statement for player wins rank
void GetSelectPlayerWinsRankQuery(char[] query, int maxlen, const char[] steamid)
{
    g_DB.Format(query, maxlen, "SELECT COUNT(*) + 1 FROM mgemod_stats WHERE wins > (SELECT wins FROM mgemod_stats WHERE steamid='%s')", steamid);
}

// Gets database-specific SELECT statement for player losses rank
void GetSelectPlayerLossesRankQuery(char[] query, int maxlen, const char[] steamid)
{
    g_DB.Format(query, maxlen, "SELECT COUNT(*) + 1 FROM mgemod_stats WHERE losses < (SELECT losses FROM mgemod_stats WHERE steamid='%s')", steamid);
}


// Gets database-specific SELECT statement for database connection test
void GetSelectConnectionTestQuery(char[] query, int maxlen)
{
    g_DB.Format(query, maxlen, "SELECT rating FROM mgemod_stats LIMIT 1");
}

// Gets database-specific SELECT statement to check migration status
void GetSelectMigrationStatusQuery(char[] query, int maxlen, const char[] migrationName)
{
    g_DB.Format(query, maxlen, "SELECT COUNT(*) FROM mgemod_migrations WHERE migration_name = '%s'", migrationName);
}

// Gets database-specific INSERT statement to mark migration complete
void GetInsertMigrationCompleteQuery(char[] query, int maxlen, const char[] migrationName, int timestamp)
{
    g_DB.Format(query, maxlen, "INSERT INTO mgemod_migrations (migration_name, executed_at) VALUES ('%s', %d)", migrationName, timestamp);
}