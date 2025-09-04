#include <sourcemod>
#include <sdktools>

StringMap g_migrationProgress;

void InitializeMigrationSystem()
{
    if (g_migrationProgress != null)
        delete g_migrationProgress;
    g_migrationProgress = new StringMap();
}

void RunDatabaseMigrations()
{
    LogMessage("[Migrations] Starting database schema migrations");
    InitializeMigrationSystem();
    CreateMigrationsTable();
}

void CreateMigrationsTable()
{
    char query[512];
    if (g_bUseSQLite)
    {
        g_DB.Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS mgemod_migrations (id INTEGER PRIMARY KEY, migration_name TEXT UNIQUE, executed_at INTEGER)");
    }
    else
    {
        g_DB.Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS mgemod_migrations (id INT AUTO_INCREMENT PRIMARY KEY, migration_name VARCHAR(255) UNIQUE, executed_at INT) DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE = InnoDB");
    }
    g_DB.Query(CreateMigrationsTableCallback, query);
}

void CreateMigrationsTableCallback(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        LogError("[Migrations] Database connection lost while creating migrations table");
        return;
    }
    
    if (!StrEqual("", error))
    {
        LogError("[Migrations] Failed to create migrations table: %s", error);
        return;
    }
    
    LogMessage("[Migrations] Migrations table ready");
    
    // Run individual migrations
    CheckAndRunMigration("001_add_class_columns");
    CheckAndRunMigration("002_duel_timing_columns");
    CheckAndRunMigration("003_add_primary_keys");
    CheckAndRunMigration("004_add_elo_tracking");
}

void CheckAndRunMigration(const char[] migrationName)
{
    char query[256];
    g_DB.Format(query, sizeof(query), "SELECT COUNT(*) FROM mgemod_migrations WHERE migration_name = '%s'", migrationName);
    
    DataPack pack = new DataPack();
    pack.WriteString(migrationName);
    
    g_DB.Query(CheckMigrationCallback, query, pack);
}

void CheckMigrationCallback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    pack.Reset();
    char migrationName[64];
    pack.ReadString(migrationName, sizeof(migrationName));
    delete pack;
    
    if (db == null)
    {
        LogError("[Migrations] Database connection lost while checking migration: %s", migrationName);
        return;
    }
    
    if (!StrEqual("", error))
    {
        LogError("[Migrations] Failed to check migration %s: %s", migrationName, error);
        return;
    }
    
    if (results.FetchRow())
    {
        int migrationExists = results.FetchInt(0);
        if (migrationExists == 0)
        {
            LogMessage("[Migrations] Running migration: %s", migrationName);
            RunMigration(migrationName);
        }
        else
        {
            LogMessage("[Migrations] Migration %s already executed (skipping)", migrationName);
        }
    }
}

void RunMigration(const char[] migrationName)
{
    if (StrEqual(migrationName, "001_add_class_columns"))
    {
        g_migrationProgress.SetValue(migrationName, 6);
        Migration_001_AddClassColumns();
    }
    else if (StrEqual(migrationName, "002_duel_timing_columns"))
    {
        g_migrationProgress.SetValue(migrationName, 4);
        Migration_002_DuelTimingColumns();
    }
    else if (StrEqual(migrationName, "003_add_primary_keys"))
    {
        g_migrationProgress.SetValue(migrationName, 3);
        Migration_003_AddPrimaryKeys();
    }
    else if (StrEqual(migrationName, "004_add_elo_tracking"))
    {
        g_migrationProgress.SetValue(migrationName, 12);
        Migration_004_AddEloTracking();
    }
}

void ExecuteMigrationStep(const char[] migrationName, const char[] query, int stepNumber)
{
    DataPack pack = new DataPack();
    pack.WriteString(migrationName);
    pack.WriteCell(stepNumber);
    g_DB.Query(GenericMigrationCallback, query, pack);
}

void GenericMigrationCallback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    pack.Reset();
    char migrationName[64];
    pack.ReadString(migrationName, sizeof(migrationName));
    int stepNumber = pack.ReadCell();
    delete pack;
    
    if (db == null)
    {
        LogError("[Migration %s] Database connection lost during step %d", migrationName, stepNumber);
        return;
    }
    
    if (!StrEqual("", error))
    {
        LogError("[Migration %s] Step %d failed: %s", migrationName, stepNumber, error);
        return;
    }
    
    // Get expected total steps for this migration
    int totalSteps;
    if (!g_migrationProgress.GetValue(migrationName, totalSteps))
    {
        LogError("[Migration %s] No step count registered for migration", migrationName);
        return;
    }
    
    // Get current progress (completed steps)
    char progressKey[128];
    Format(progressKey, sizeof(progressKey), "%s_completed", migrationName);
    int completedSteps;
    g_migrationProgress.GetValue(progressKey, completedSteps);
    
    completedSteps++;
    g_migrationProgress.SetValue(progressKey, completedSteps);
    
    LogMessage("[Migration %s] Step %d/%d completed", migrationName, completedSteps, totalSteps);
    
    // When all steps are complete, mark migration as done
    if (completedSteps >= totalSteps)
    {
        LogMessage("[Migration %s] All steps completed successfully", migrationName);
        MarkMigrationComplete(migrationName);
        
        // Clean up progress tracking for this migration
        g_migrationProgress.Remove(migrationName);
        g_migrationProgress.Remove(progressKey);
    }
}

void MarkMigrationComplete(const char[] migrationName)
{
    char query[256];
    g_DB.Format(query, sizeof(query), "INSERT INTO mgemod_migrations (migration_name, executed_at) VALUES ('%s', %d)", migrationName, GetTime());
    g_DB.Query(MarkMigrationCallback, query);
}

void MarkMigrationCallback(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        LogError("[Migrations] Database connection lost while marking migration complete");
        return;
    }
    
    if (!StrEqual("", error))
    {
        LogError("[Migrations] Failed to mark migration complete: %s", error);
        return;
    }
}

void Migration_001_AddClassColumns()
{
    LogMessage("[Migration 001] Adding class tracking columns");
    
    if (g_bUseSQLite)
    {
        ExecuteMigrationStep("001_add_class_columns", "ALTER TABLE mgemod_duels ADD COLUMN winnerclass TEXT DEFAULT NULL", 1);
        ExecuteMigrationStep("001_add_class_columns", "ALTER TABLE mgemod_duels ADD COLUMN loserclass TEXT DEFAULT NULL", 2);
        ExecuteMigrationStep("001_add_class_columns", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN winnerclass TEXT DEFAULT NULL", 3);
        ExecuteMigrationStep("001_add_class_columns", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN winner2class TEXT DEFAULT NULL", 4);
        ExecuteMigrationStep("001_add_class_columns", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN loserclass TEXT DEFAULT NULL", 5);
        ExecuteMigrationStep("001_add_class_columns", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN loser2class TEXT DEFAULT NULL", 6);
    }
    else
    {
        ExecuteMigrationStep("001_add_class_columns", "ALTER TABLE mgemod_duels ADD COLUMN winnerclass VARCHAR(64) DEFAULT NULL", 1);
        ExecuteMigrationStep("001_add_class_columns", "ALTER TABLE mgemod_duels ADD COLUMN loserclass VARCHAR(64) DEFAULT NULL", 2);
        ExecuteMigrationStep("001_add_class_columns", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN winnerclass VARCHAR(64) DEFAULT NULL", 3);
        ExecuteMigrationStep("001_add_class_columns", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN winner2class VARCHAR(64) DEFAULT NULL", 4);
        ExecuteMigrationStep("001_add_class_columns", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN loserclass VARCHAR(64) DEFAULT NULL", 5);
        ExecuteMigrationStep("001_add_class_columns", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN loser2class VARCHAR(64) DEFAULT NULL", 6);
    }
}

void Migration_002_DuelTimingColumns()
{
    LogMessage("[Migration 002] Converting gametime to endtime and adding starttime column");
    
    if (g_bUseSQLite)
    {
        ExecuteMigrationStep("002_duel_timing_columns", "ALTER TABLE mgemod_duels RENAME COLUMN gametime TO endtime", 1);
        ExecuteMigrationStep("002_duel_timing_columns", "ALTER TABLE mgemod_duels ADD COLUMN starttime INTEGER DEFAULT NULL", 2);
        ExecuteMigrationStep("002_duel_timing_columns", "ALTER TABLE mgemod_duels_2v2 RENAME COLUMN gametime TO endtime", 3);
        ExecuteMigrationStep("002_duel_timing_columns", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN starttime INTEGER DEFAULT NULL", 4);
    }
    else
    {
        ExecuteMigrationStep("002_duel_timing_columns", "ALTER TABLE mgemod_duels CHANGE gametime endtime INT(11) NOT NULL", 1);
        ExecuteMigrationStep("002_duel_timing_columns", "ALTER TABLE mgemod_duels ADD COLUMN starttime INT(11) DEFAULT NULL", 2);
        ExecuteMigrationStep("002_duel_timing_columns", "ALTER TABLE mgemod_duels_2v2 CHANGE gametime endtime INT(11) NOT NULL", 3);
        ExecuteMigrationStep("002_duel_timing_columns", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN starttime INT(11) DEFAULT NULL", 4);
    }
}

void Migration_003_AddPrimaryKeys()
{
    LogMessage("[Migration 003] Adding primary keys to database tables");
    
    if (g_bUseSQLite)
    {
        ExecuteMigrationStep("003_add_primary_keys", "CREATE TABLE mgemod_duels_backup AS SELECT * FROM mgemod_duels", 1);
        ExecuteMigrationStep("003_add_primary_keys", "CREATE TABLE mgemod_duels_new (id INTEGER PRIMARY KEY, winner TEXT, loser TEXT, winnerscore INTEGER, loserscore INTEGER, winlimit INTEGER, endtime INTEGER, starttime INTEGER, mapname TEXT, arenaname TEXT, winnerclass TEXT, loserclass TEXT, winner_previous_elo INTEGER, winner_new_elo INTEGER, loser_previous_elo INTEGER, loser_new_elo INTEGER)", 2);
        ExecuteMigrationStep("003_add_primary_keys", "INSERT INTO mgemod_duels_new SELECT NULL, winner, loser, winnerscore, loserscore, winlimit, endtime, starttime, mapname, arenaname, winnerclass, loserclass, winner_previous_elo, winner_new_elo, loser_previous_elo, loser_new_elo FROM mgemod_duels", 3);
        ExecuteMigrationStep("003_add_primary_keys", "DROP TABLE mgemod_duels", 4);
        ExecuteMigrationStep("003_add_primary_keys", "ALTER TABLE mgemod_duels_new RENAME TO mgemod_duels", 5);
        ExecuteMigrationStep("003_add_primary_keys", "CREATE TABLE mgemod_duels_2v2_backup AS SELECT * FROM mgemod_duels_2v2", 6);
        ExecuteMigrationStep("003_add_primary_keys", "CREATE TABLE mgemod_duels_2v2_new (id INTEGER PRIMARY KEY, winner TEXT, winner2 TEXT, loser TEXT, loser2 TEXT, winnerscore INTEGER, loserscore INTEGER, winlimit INTEGER, endtime INTEGER, starttime INTEGER, mapname TEXT, arenaname TEXT, winnerclass TEXT, winner2class TEXT, loserclass TEXT, loser2class TEXT, winner_previous_elo INTEGER, winner_new_elo INTEGER, winner2_previous_elo INTEGER, winner2_new_elo INTEGER, loser_previous_elo INTEGER, loser_new_elo INTEGER, loser2_previous_elo INTEGER, loser2_new_elo INTEGER)", 7);
        ExecuteMigrationStep("003_add_primary_keys", "INSERT INTO mgemod_duels_2v2_new SELECT NULL, winner, winner2, loser, loser2, winnerscore, loserscore, winlimit, endtime, starttime, mapname, arenaname, winnerclass, winner2class, loserclass, loser2class, winner_previous_elo, winner_new_elo, winner2_previous_elo, winner2_new_elo, loser_previous_elo, loser_new_elo, loser2_previous_elo, loser2_new_elo FROM mgemod_duels_2v2", 8);
        ExecuteMigrationStep("003_add_primary_keys", "DROP TABLE mgemod_duels_2v2", 9);
        ExecuteMigrationStep("003_add_primary_keys", "ALTER TABLE mgemod_duels_2v2_new RENAME TO mgemod_duels_2v2", 10);
        ExecuteMigrationStep("003_add_primary_keys", "CREATE UNIQUE INDEX IF NOT EXISTS idx_stats_steamid ON mgemod_stats (steamid)", 11);
        
    }
    else
    {
        ExecuteMigrationStep("003_add_primary_keys", "ALTER TABLE mgemod_duels ADD COLUMN id INT AUTO_INCREMENT PRIMARY KEY FIRST", 1);
        ExecuteMigrationStep("003_add_primary_keys", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN id INT AUTO_INCREMENT PRIMARY KEY FIRST", 2);
        ExecuteMigrationStep("003_add_primary_keys", "ALTER TABLE mgemod_stats ADD PRIMARY KEY (steamid)", 3);
        ExecuteMigrationStep("003_add_primary_keys", "CREATE UNIQUE INDEX IF NOT EXISTS idx_stats_steamid ON mgemod_stats (steamid)", 4);
    }
}

void Migration_004_AddEloTracking()
{
    LogMessage("[Migration 004] Adding ELO tracking columns to duel tables");
    
    if (g_bUseSQLite)
    {
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels ADD COLUMN winner_previous_elo INTEGER DEFAULT NULL", 1);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels ADD COLUMN winner_new_elo INTEGER DEFAULT NULL", 2);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels ADD COLUMN loser_previous_elo INTEGER DEFAULT NULL", 3);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels ADD COLUMN loser_new_elo INTEGER DEFAULT NULL", 4);
        
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN winner_previous_elo INTEGER DEFAULT NULL", 5);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN winner_new_elo INTEGER DEFAULT NULL", 6);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN winner2_previous_elo INTEGER DEFAULT NULL", 7);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN winner2_new_elo INTEGER DEFAULT NULL", 8);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN loser_previous_elo INTEGER DEFAULT NULL", 9);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN loser_new_elo INTEGER DEFAULT NULL", 10);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN loser2_previous_elo INTEGER DEFAULT NULL", 11);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN loser2_new_elo INTEGER DEFAULT NULL", 12);
    }
    else
    {
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels ADD COLUMN winner_previous_elo INT(4) DEFAULT NULL", 1);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels ADD COLUMN winner_new_elo INT(4) DEFAULT NULL", 2);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels ADD COLUMN loser_previous_elo INT(4) DEFAULT NULL", 3);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels ADD COLUMN loser_new_elo INT(4) DEFAULT NULL", 4);
        
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN winner_previous_elo INT(4) DEFAULT NULL", 5);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN winner_new_elo INT(4) DEFAULT NULL", 6);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN winner2_previous_elo INT(4) DEFAULT NULL", 7);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN winner2_new_elo INT(4) DEFAULT NULL", 8);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN loser_previous_elo INT(4) DEFAULT NULL", 9);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN loser_new_elo INT(4) DEFAULT NULL", 10);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN loser2_previous_elo INT(4) DEFAULT NULL", 11);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN loser2_new_elo INTEGER DEFAULT NULL", 12);
    }
}
