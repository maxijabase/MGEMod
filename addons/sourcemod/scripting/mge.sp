#pragma semicolon 1
#pragma newdecls required

// Hack for unrestricted maxplayers
#if defined (MAXPLAYERS)
    #undef MAXPLAYERS
    #define MAXPLAYERS 101
#endif

#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#include <morecolors>
#include <clientprefs>
#include <convar_class>
#include <mge>

#define PL_VERSION "3.1.0-2v2-beta9"

#define MAXARENAS 63
#define MAXSPAWNS 15
#define HUDFADEOUTTIME 120.0

#pragma newdecls required

// Globals
#include "mge/globals.sp"

// Modules
#include "mge/elo.sp"
#include "mge/sql.sp"
#include "mge/hud.sp"
#include "mge/arenas.sp"
#include "mge/player.sp"
#include "mge/spectator.sp"
#include "mge/statistics.sp"
#include "mge/migrations.sp"

#include "mge/gamemodes/bball.sp"
#include "mge/gamemodes/koth.sp"
#include "mge/gamemodes/2v2.sp"
#include "mge/gamemodes/ammomod.sp"
#include "mge/gamemodes/endif.sp"

// API
#include "mge/api/forwards.sp"
#include "mge/api/natives.sp"

public Plugin myinfo =
{
    name        = "MGE",
    author      = "Originally by Lange & Cprice; based on kAmmomod by Krolus - maintained by sappho.io, PepperKick, and others",
    description = "Duel mod for TF2 with realistic game situations.",
    version     =  PL_VERSION,
    url         = "https://github.com/sapphonie/MGEMod"
}


// ===== PLUGIN CORE LIFECYCLE =====

// Initialize the plugin, register commands, create convars, and set up core systems
public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    LoadTranslations("mgemod.phrases");

    // Initialize cookies
    g_hShowEloCookie = new Cookie("mgemod_showelo", "MGEMod ELO display preference", CookieAccess_Private);

    // ConVars
    CreateConVar("sm_mgemod_version", PL_VERSION, "MGEMod version", FCVAR_SPONLY | FCVAR_NOTIFY);
    gcvar_fragLimit = new Convar("mgemod_fraglimit", "1", "Default frag limit in duel", FCVAR_NONE, true, 1.0);
    gcvar_allowedClasses = new Convar("mgemod_allowed_classes", "soldier demoman scout", "Classes that players allowed to choose by default");
    gcvar_blockFallDamage = new Convar("mgemod_blockdmg_fall", "0", "Block falldamage? (0 = Disabled)", FCVAR_NONE, true, 0.0, true, 1.0);
    gcvar_dbConfig = new Convar("mgemod_dbconfig", "mgemod", "Name of database config");
    gcvar_stats = new Convar("mgemod_stats", "1", "Enable/Disable stats.");
    gcvar_airshotHeight = new Convar("mgemod_airshot_height", "80", "The minimum height at which it will count airshot", FCVAR_NONE, true, 10.0, true, 500.0);
    gcvar_RocketForceX = new Convar("mgemod_endif_force_x", "1.1", "The amount by which to multiply the X push force on Endif.", FCVAR_NONE, true, 1.0, true, 10.0);
    gcvar_RocketForceY = new Convar("mgemod_endif_force_y", "1.1", "The amount by which to multiply the Y push force on Endif.", FCVAR_NONE, true, 1.0, true, 10.0);
    gcvar_RocketForceZ = new Convar("mgemod_endif_force_z", "2.15", "The amount by which to multiply the Z push force on Endif.", FCVAR_NONE, true, 1.0, true, 10.0);
    gcvar_autoCvar = new Convar("mgemod_autocvar", "1", "Automatically set recommended game cvars? (0 = Disabled)", FCVAR_NONE, true, 0.0, true, 1.0);
    gcvar_bballParticle_red = new Convar("mgemod_bball_particle_red", "player_intel_trail_red", "Particle effect to attach to Red players in BBall.");
    gcvar_bballParticle_blue = new Convar("mgemod_bball_particle_blue", "player_intel_trail_blue", "Particle effect to attach to Blue players in BBall.");
    gcvar_midairHP = new Convar("mgemod_midair_hp", "5", "Minimum health for midair detection", FCVAR_NONE, true, 1.0);
    gcvar_noDisplayRating = new Convar("mgemod_hide_rating", "0", "Hide the in-game display of rating points. They will still be tracked in the database.");
    gcvar_reconnectInterval = new Convar("mgemod_reconnect_interval", "5", "How long (in minutes) to wait between database reconnection attempts.");
    gcvar_2v2SkipCountdown = new Convar("mgemod_2v2_skip_countdown", "0", "Skip countdown between 2v2 rounds? (0 = Normal countdown, 1 = Skip countdown)", FCVAR_NONE, true, 0.0, true, 1.0);
    gcvar_2v2Elo = new Convar("mgemod_2v2_elo", "1", "Enable ELO calculation and display for 2v2 matches? (0 = Disabled, 1 = Enabled)", FCVAR_NONE, true, 0.0, true, 1.0);
    gcvar_clearProjectiles = new Convar("mgemod_clear_projectiles", "0", "Clear projectiles when a new round starts? (0 = Disabled, 1 = Enabled)", FCVAR_NONE, true, 0.0, true, 1.0);

    // Create config file
    Convar.CreateConfig("mge");

    // Populate global variables with their corresponding convar values.
    g_iDefaultFragLimit = gcvar_fragLimit.IntValue;
    g_bBlockFallDamage = gcvar_blockFallDamage.IntValue ? true : false;
    g_iAirshotHeight = gcvar_airshotHeight.IntValue;
    g_iMidairHP = gcvar_midairHP.IntValue;
    g_bAutoCvar = gcvar_autoCvar.IntValue ? true : false;
    g_bNoDisplayRating = gcvar_noDisplayRating.IntValue ? true : false;
    g_iReconnectInterval = gcvar_reconnectInterval.IntValue;
    g_b2v2SkipCountdown = gcvar_2v2SkipCountdown.IntValue ? true : false;
    g_b2v2Elo = gcvar_2v2Elo.IntValue ? true : false;
    g_bClearProjectiles = gcvar_clearProjectiles.IntValue ? true : false;

    gcvar_dbConfig.GetString(g_sDBConfig, sizeof(g_sDBConfig));
    gcvar_bballParticle_red.GetString(g_sBBallParticleRed, sizeof(g_sBBallParticleRed));
    gcvar_bballParticle_blue.GetString(g_sBBallParticleBlue, sizeof(g_sBBallParticleBlue));

    g_bNoStats = gcvar_stats.BoolValue ? false : true;

    g_fRocketForceX = gcvar_RocketForceX.FloatValue;
    g_fRocketForceY = gcvar_RocketForceY.FloatValue;
    g_fRocketForceZ = gcvar_RocketForceZ.FloatValue;

    for (int i = 0; i < MAXARENAS + 1; ++i)
    {
        g_bTimerRunning[i] = false;
        g_fCappedTime[i] = 0.0;
        g_fTotalTime[i] = 0.0;
    }

    // Parse default list of allowed classes.
    ParseAllowedClasses("", g_tfctClassAllowed);

    // Hook convar changes
    gcvar_fragLimit.AddChangeHook(handler_ConVarChange);
    gcvar_allowedClasses.AddChangeHook(handler_ConVarChange);
    gcvar_blockFallDamage.AddChangeHook(handler_ConVarChange);
    gcvar_dbConfig.AddChangeHook(handler_ConVarChange);
    gcvar_stats.AddChangeHook(handler_ConVarChange);
    gcvar_airshotHeight.AddChangeHook(handler_ConVarChange);
    gcvar_midairHP.AddChangeHook(handler_ConVarChange);
    gcvar_RocketForceX.AddChangeHook(handler_ConVarChange);
    gcvar_RocketForceY.AddChangeHook(handler_ConVarChange);
    gcvar_RocketForceZ.AddChangeHook(handler_ConVarChange);
    gcvar_autoCvar.AddChangeHook(handler_ConVarChange);
    gcvar_bballParticle_red.AddChangeHook(handler_ConVarChange);
    gcvar_bballParticle_blue.AddChangeHook(handler_ConVarChange);
    gcvar_noDisplayRating.AddChangeHook(handler_ConVarChange);
    gcvar_reconnectInterval.AddChangeHook(handler_ConVarChange);
    gcvar_2v2SkipCountdown.AddChangeHook(handler_ConVarChange);
    gcvar_2v2Elo.AddChangeHook(handler_ConVarChange);
    gcvar_clearProjectiles.AddChangeHook(handler_ConVarChange);

    // Client commands
    RegConsoleCmd("mgemod", Command_Menu, "MGEMod Menu");
    RegConsoleCmd("add", Command_Menu, "Usage: add <arena number/arena name/@player>. Add to an arena.");
    RegConsoleCmd("swap", Command_Swap, "Ask your teammate to swap classes with you in ultiduo");
    RegConsoleCmd("remove", Command_Remove, "Remove from current arena.");
    RegConsoleCmd("top5", Command_Top5, "Display the Top players.");
    RegConsoleCmd("hud", Command_ToggleHud, "Toggle text hud.");
    RegConsoleCmd("hidehud", Command_ToggleHud, "Toggle text hud. (alias)");
    RegConsoleCmd("elo", Command_ToggleElo, "Toggle ELO display.");
    RegConsoleCmd("rank", Command_Rank, "Usage: rank <player name>. Show that player's rank.");
    RegConsoleCmd("stats", Command_Rank, "Alias for \"rank\".");
    RegConsoleCmd("mgehelp", Command_Help);
    RegConsoleCmd("first", Command_First, "Join the first available arena.");
    RegConsoleCmd("handicap", Command_Handicap, "Reduce your maximum HP. Type '!handicap off' to disable.");
    RegConsoleCmd("spec_next", Command_Spec);
    RegConsoleCmd("spec_prev", Command_Spec);
    RegConsoleCmd("autoteam", Command_AutoTeam);
    RegConsoleCmd("jointeam", Command_JoinTeam);
    RegConsoleCmd("joinclass", Command_JoinClass);
    RegConsoleCmd("join_class", Command_JoinClass);
    RegConsoleCmd("eureka_teleport", Command_EurekaTeleport);
    RegConsoleCmd("1v1", Command_OneVsOne, "Change arena to 1v1");
    RegConsoleCmd("2v2", Command_TwoVsTwo, "Change arena to 2v2");

    // Admin commands
    RegAdminCmd("koth", Command_Koth, ADMFLAG_BAN, "Change arena to KOTH Mode");
    RegAdminCmd("mge", Command_Mge, ADMFLAG_BAN, "Change arena to MGE Mode");
    RegAdminCmd("loc", Command_Loc, ADMFLAG_BAN, "Shows client origin and angle vectors");
    RegAdminCmd("botme", Command_AddBot, ADMFLAG_BAN, "Add bot to your arena");
    RegAdminCmd("conntest", Command_ConnectionTest, ADMFLAG_BAN, "MySQL connection test");
    
    // 2v2 Ready System Commands
    RegConsoleCmd("ready", Command_Ready, "Mark yourself as ready for 2v2 match");
    RegConsoleCmd("r", Command_Ready, "Mark yourself as ready for 2v2 match");
    
    AddCommandListener(Command_DropItem, "dropitem");

    // HUD synchronizers
    hm_HP           = CreateHudSynchronizer();
    hm_Score        = CreateHudSynchronizer();
    hm_KothTimerBLU = CreateHudSynchronizer();
    hm_KothTimerRED = CreateHudSynchronizer();
    hm_KothCap      = CreateHudSynchronizer();
    hm_TeammateHP   = CreateHudSynchronizer();

    // Set up the log file for debug logging
    BuildPath(Path_SM, g_sLogFile, sizeof(g_sLogFile), "logs/mgemod.log");

    MC_PrintToChatAll("%t", "PluginReloaded");

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
            ForcePlayerSuicide(i);
            g_bCanPlayerSwap[i] = true;
            g_bCanPlayerGetIntel[i] = true;
            
            if (g_alPlayerDuelClasses[i] != null)
                delete g_alPlayerDuelClasses[i];
            g_alPlayerDuelClasses[i] = new ArrayList();
        }
    }
}

// Execute configuration after all configs are loaded
public void OnConfigsExecuted()
{
    if (!g_bNoStats)
    {
        PrepareSQL();
    }
}

// Initialize map-specific systems, precache models, hook events, and set up arenas
public void OnMapStart()
{
    for (int i = 0; i < sizeof(stockSounds); i++) {
        PrecacheSound(stockSounds[i], true);
    }

    // Models. These are used for the artifical flag in BBall.
    PrecacheModel(MODEL_BRIEFCASE, true);
    PrecacheModel(MODEL_AMMOPACK, true);
    // Used for ultiduo/koth arenas
    PrecacheModel(MODEL_POINT, true);

    g_bNoStats = gcvar_stats.BoolValue ? false : true; /* Reset this variable, since it is forced to false during Event_WinPanel */

    // Spawns
    bool isMapAm = LoadSpawnPoints();
    if (isMapAm)
    {
        for (int i = 0; i <= g_iArenaCount; i++)
        {
            if (g_bArenaBBall[i])
            {
                g_iBBallHoop[i][SLOT_ONE] = -1;
                g_iBBallHoop[i][SLOT_TWO] = -1;
                g_iBBallIntel[i] = -1;
            }
            if (g_bArenaKoth[i])
            {
                g_iCapturePoint[i] = -1;
            }
        }

        CreateTimer(1.0, Timer_SpecHudToAllArenas, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);

        if (g_bAutoCvar)
        {
            FindConVar("mp_autoteambalance").SetInt(0);
            FindConVar("mp_teams_unbalance_limit").SetInt(101);
            FindConVar("mp_tournament").SetInt(0);
        }

        HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
        HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
        HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
        HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Post);
        HookEvent("teamplay_win_panel", Event_WinPanel, EventHookMode_Post);
        HookEvent("player_team", Event_Suppress, EventHookMode_Pre);
        HookEvent("player_class", Event_Suppress, EventHookMode_Pre);

        AddNormalSoundHook(Sound_BlockSound);
    } else {
        SetFailState("Map not supported. MGEMod disabled.");
    }

    for (int i = 0; i < MAXPLAYERS; i++)
    {
        g_iPlayerWaiting[i] = false;
        g_bCanPlayerSwap[i] = true;
        g_bCanPlayerGetIntel[i] = true;

    }

    for (int i = 0; i < MAXARENAS; i++)
    {
        g_bTimerRunning[i] = false;
        g_fCappedTime[i] = 0.0;
        g_fTotalTime[i] = 0.0;
    }
}

// Clean up resources and unhook events when map ends
public void OnMapEnd()
{
    delete g_hDBReconnectTimer;
    g_bNoStats = gcvar_stats.BoolValue ? false : true;

    UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
    UnhookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    UnhookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
    UnhookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Post);
    UnhookEvent("teamplay_win_panel", Event_WinPanel, EventHookMode_Post);

    RemoveNormalSoundHook(Sound_BlockSound);

    for (int arena_index = 1; arena_index < g_iArenaCount; arena_index++)
    {
        if (g_bTimerRunning[arena_index])
        {
            delete g_tKothTimer[arena_index];
            g_bTimerRunning[arena_index] = false;
        }
    }
}


// ===== ENTITY & PROJECTILE SYSTEM =====

// Hook projectiles for direct hit detection when entities are created
public void OnEntityCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "tf_projectile_rocket") || StrEqual(classname, "tf_projectile_pipe"))
        SDKHook(entity, SDKHook_Touch, OnProjectileTouch);
}

// Track direct hits from projectiles for airshot calculations
void OnProjectileTouch(int entity, int other)
{
    if (other > 0 && other <= MaxClients)
        g_bPlayerTakenDirectHit[other] = true;
}


// ===== CLIENT LIFECYCLE MANAGEMENT =====

// Load client preferences from cookies when they become available
public void OnClientCookiesCached(int client)
{
    if (IsFakeClient(client))
        return;
    
    // Load ELO display preference from cookie
    char cookieValue[8];
    g_hShowEloCookie.Get(client, cookieValue, sizeof(cookieValue));
    if (strlen(cookieValue) > 0)
        g_bShowElo[client] = (StringToInt(cookieValue) == 1);
}

// Initialize basic client data when they connect (regardless of Steam status)
public void OnClientPutInServer(int client)
{
    HandleClientConnection(client);
}

// Handle Steam-authenticated connections and retry ELO loading if needed
public void OnClientPostAdminCheck(int client)
{
    HandleClientAuthentication(client);
}

// Clean up client data, handle arena cleanup, and manage bot removal on disconnect
public void OnClientDisconnect(int client)
{
    HandleClientDisconnection(client);
}


// ===== GAME MECHANICS & HOOKS =====

// Process continuous game mechanics like ammomod health and KOTH capture points
public void OnGameFrame()
{
    ProcessAmmomodHealthManagement();
    ProcessKothCapturePoints();
}

// Handle damage modifications including fall damage blocking
Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!IsValidClient(victim) || !IsValidClient(attacker))
        return Plugin_Continue;

    // Fall damage negation.
    if ((damagetype & DMG_FALL) && g_bBlockFallDamage)
    {
        damage = 0.0;
        return Plugin_Changed;
    }

    return Plugin_Continue;
}

// Process infinite ammo restoration for ammomod arenas
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    int arena_index = g_iPlayerArena[client];
    if (g_bArenaInfAmmo[arena_index])
    {
        if (!g_bPlayerRestoringAmmo[client] && (buttons & IN_ATTACK))
        {
            g_bPlayerRestoringAmmo[client] = true;
            CreateTimer(0.4, Timer_GiveAmmo, GetClientUserId(client));
        }
    }
    return Plugin_Continue;
}


// ===== CONFIGURATION SYSTEM =====

// Update global variables when convars change
void handler_ConVarChange(Handle convar, const char[] oldValue, const char[] newValue)
{
    // Boolean conversion helper
    bool boolValue = view_as<bool>(StringToInt(newValue));
    
    // Integer conversion helper  
    int intValue = StringToInt(newValue);
    
    // Float conversion helper
    float floatValue = StringToFloat(newValue);
    
    // Handle each convar type
    if (convar == gcvar_fragLimit)
        g_iDefaultFragLimit = intValue;
    else if (convar == gcvar_allowedClasses)
        ParseAllowedClasses(newValue, g_tfctClassAllowed);
    else if (convar == gcvar_blockFallDamage)
        g_bBlockFallDamage = boolValue;
    else if (convar == gcvar_dbConfig)
        strcopy(g_sDBConfig, sizeof(g_sDBConfig), newValue);
    else if (convar == gcvar_stats)
        g_bNoStats = !boolValue;
    else if (convar == gcvar_airshotHeight)
        g_iAirshotHeight = intValue;
    else if (convar == gcvar_midairHP)
        g_iMidairHP = intValue;
    else if (convar == gcvar_RocketForceX)
        g_fRocketForceX = floatValue;
    else if (convar == gcvar_RocketForceY)
        g_fRocketForceY = floatValue;
    else if (convar == gcvar_RocketForceZ)
        g_fRocketForceZ = floatValue;
    else if (convar == gcvar_autoCvar)
        g_bAutoCvar = boolValue;
    else if (convar == gcvar_bballParticle_red)
        strcopy(g_sBBallParticleRed, sizeof(g_sBBallParticleRed), newValue);
    else if (convar == gcvar_bballParticle_blue)
        strcopy(g_sBBallParticleBlue, sizeof(g_sBBallParticleBlue), newValue);
    else if (convar == gcvar_noDisplayRating)
        g_bNoDisplayRating = boolValue;
    else if (convar == gcvar_reconnectInterval)
        g_iReconnectInterval = intValue;
    else if (convar == gcvar_2v2SkipCountdown)
        g_b2v2SkipCountdown = boolValue;
    else if (convar == gcvar_2v2Elo)
        g_b2v2Elo = boolValue;
    else if (convar == gcvar_clearProjectiles)
        g_bClearProjectiles = boolValue;
}


// ===== UTILITY FUNCTIONS =====

// Convert TF2 class enum to readable string representation
char[] TFClassToString(TFClassType class)
{
    char className[16];
    switch (class)
    {
        case TFClass_Scout: strcopy(className, sizeof(className), "scout");
        case TFClass_Sniper: strcopy(className, sizeof(className), "sniper");
        case TFClass_Soldier: strcopy(className, sizeof(className), "soldier");
        case TFClass_DemoMan: strcopy(className, sizeof(className), "demoman");
        case TFClass_Medic: strcopy(className, sizeof(className), "medic");
        case TFClass_Heavy: strcopy(className, sizeof(className), "heavy");
        case TFClass_Pyro: strcopy(className, sizeof(className), "pyro");
        case TFClass_Spy: strcopy(className, sizeof(className), "spy");
        case TFClass_Engineer: strcopy(className, sizeof(className), "engineer");
        default: strcopy(className, sizeof(className), "unknown");
    }
    return className;
}


// ===== ADMIN COMMANDS =====

// Display client's current position and angles for debugging
Action Command_Loc(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    float vec[3];
    float ang[3];
    GetClientAbsOrigin(client, vec);
    GetClientEyeAngles(client, ang);
    PrintToChat(client, "%.0f %.0f %.0f %.0f", vec[0], vec[1], vec[2], ang[1]);
    return Plugin_Handled;
}

// Test database connection for troubleshooting
Action Command_ConnectionTest(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    char query[256];
    g_DB.Format(query, sizeof(query), "SELECT rating FROM mgemod_stats LIMIT 1");
    g_DB.Query(SQL_OnTestReceived, query, client);

    return Plugin_Handled;
}


// ===== HELP SYSTEM =====

// Display available commands and usage information to players
// TODO: refactor to menu
Action Command_Help(int client, int args)
{
    if (!client || !IsValidClient(client))
        return Plugin_Continue;

    PrintToChat(client, "%t", "Cmd_SeeConsole");
    PrintToConsole(client, "\n\n----------------------------");
    PrintToConsole(client, "%t", "Cmd_MGECmds");
    PrintToConsole(client, "%t", "Cmd_MGEMod");
    PrintToConsole(client, "%t", "Cmd_Add");
    PrintToConsole(client, "%t", "Cmd_Remove");
    PrintToConsole(client, "%t", "Cmd_First");
    PrintToConsole(client, "%t", "Cmd_Top5");
    PrintToConsole(client, "%t", "Cmd_Rank");
    PrintToConsole(client, "%t", "Cmd_Hud");
    PrintToConsole(client, "%t", "Cmd_Elo");
    PrintToConsole(client, "%t", "Cmd_Handicap");
    PrintToConsole(client, "----------------------------\n\n");

    return Plugin_Handled;
}


// ===== SOUND SYSTEM =====

// Block unwanted sounds like fall damage and regeneration
Action Sound_BlockSound(int clients[MAXPLAYERS], int& numClients, char sample[PLATFORM_MAX_PATH], int& entity, int& channel, float& volume, int& level, int& pitch, int& flags, char soundEntry[PLATFORM_MAX_PATH], int& seed)
{
    if (StrContains(sample, "pl_fallpain") >= 0 && g_bBlockFallDamage)
    {
        return Plugin_Handled;
    }

    if (StrContains(sample, "regenerate") >= 0)
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}


// ===== GAME EVENTS =====

// Disable stats tracking when match ends to prevent point loss from leavers
Action Event_WinPanel(Event event, const char[] name, bool dontBroadcast)
{
    // Disable stats so people leaving at the end of the map don't lose points.
    g_bNoStats = true;
    return Plugin_Continue;
}

// Initialize BBall hoops and KOTH capture points when round starts
Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    FindConVar("mp_waitingforplayers_cancel").SetInt(1); // Cancel waiting for players

    // Be totally certain that the models are cached so they can be hooked
    PrecacheModel(MODEL_BRIEFCASE, true);
    PrecacheModel(MODEL_AMMOPACK, true);

    for (int i = 0; i <= g_iArenaCount; i++)
    {
        if (g_bArenaBBall[i])
        {
            float hoop_2_loc[3];
            hoop_2_loc[0] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][0];
            hoop_2_loc[1] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][1];
            hoop_2_loc[2] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][2];

            float hoop_1_loc[3];
            hoop_1_loc[0] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i] - 1][0];
            hoop_1_loc[1] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i] - 1][1];
            hoop_1_loc[2] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i] - 1][2];

            if (IsValidEdict(g_iBBallHoop[i][SLOT_ONE]) && g_iBBallHoop[i][SLOT_ONE] > 0)
            {
                RemoveEdict(g_iBBallHoop[i][SLOT_ONE]);
                g_iBBallHoop[i][SLOT_ONE] = -1;
            } else if (g_iBBallHoop[i][SLOT_ONE] != -1) {  // g_iBBallHoop[i][SLOT_ONE] equaling -1 is not a bad thing, so don't print an error for it.
                g_iBBallHoop[i][SLOT_ONE] = -1;
            }

            if (IsValidEdict(g_iBBallHoop[i][SLOT_TWO]) && g_iBBallHoop[i][SLOT_TWO] > 0)
            {
                RemoveEdict(g_iBBallHoop[i][SLOT_TWO]);
                g_iBBallHoop[i][SLOT_TWO] = -1;
            } else if (g_iBBallHoop[i][SLOT_TWO] != -1) {  // g_iBBallHoop[i][SLOT_TWO] equaling -1 is not a bad thing, so don't print an error for it.
                g_iBBallHoop[i][SLOT_TWO] = -1;
            }

            if (g_iBBallHoop[i][SLOT_ONE] == -1)
            {
                g_iBBallHoop[i][SLOT_ONE] = CreateEntityByName("item_ammopack_small");
                TeleportEntity(g_iBBallHoop[i][SLOT_ONE], hoop_1_loc, NULL_VECTOR, NULL_VECTOR);
                DispatchSpawn(g_iBBallHoop[i][SLOT_ONE]);
                SetEntProp(g_iBBallHoop[i][SLOT_ONE], Prop_Send, "m_iTeamNum", 1, 4);

                SDKHook(g_iBBallHoop[i][SLOT_ONE], SDKHook_StartTouch, OnTouchHoop);
            }

            if (g_iBBallHoop[i][SLOT_TWO] == -1)
            {
                g_iBBallHoop[i][SLOT_TWO] = CreateEntityByName("item_ammopack_small");
                TeleportEntity(g_iBBallHoop[i][SLOT_TWO], hoop_2_loc, NULL_VECTOR, NULL_VECTOR);
                DispatchSpawn(g_iBBallHoop[i][SLOT_TWO]);
                SetEntProp(g_iBBallHoop[i][SLOT_TWO], Prop_Send, "m_iTeamNum", 1, 4);

                SDKHook(g_iBBallHoop[i][SLOT_TWO], SDKHook_StartTouch, OnTouchHoop);
            }

            if (g_bVisibleHoops[i] == false)
            {
                // Could have used SetRenderMode here, but it had the unfortunate side-effect of also making the intel invisible.
                // Luckily, inputting "Disable" to most entities makes them invisible, so it was a valid workaround.
                AcceptEntityInput(g_iBBallHoop[i][SLOT_ONE], "Disable");
                AcceptEntityInput(g_iBBallHoop[i][SLOT_TWO], "Disable");
            }
        }

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
            // g_iCapturePoint[i] equaling -1 is not a bad thing, so don't print an error for it.
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

            // Could have used SetRenderMode here, but it had the unfortunate side-effect of also making the intel invisible.
            // Luckily, inputting "Disable" to most entities makes them invisible, so it was a valid workaround.
            AcceptEntityInput(g_iCapturePoint[i], "Disable");

        }
    }

    return Plugin_Continue;
}

// Suppress team and class change broadcasts
Action Event_Suppress(Event event, const char[] name, bool dontBroadcast)
{
    event.BroadcastDisabled = true;
    return Plugin_Continue;
}
