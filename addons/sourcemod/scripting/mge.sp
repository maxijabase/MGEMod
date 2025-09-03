#pragma semicolon 1 // Force strict semicolon mode.
#pragma newdecls required

// hack for unrestricted maxplayers. sorry.
#if defined (MAXPLAYERS)
    #undef MAXPLAYERS
    #define MAXPLAYERS 101
#endif

// ====[ INCLUDES ]====================================================
#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#include <morecolors>
#include <clientprefs>
// ====[ CONSTANTS ]===================================================
#define PL_VERSION "3.1.0-beta2"
#define MAXARENAS 63
#define MAXSPAWNS 15
#define HUDFADEOUTTIME 120.0

#pragma newdecls required

// arena slots
enum
{
    SLOT_ONE = 1,
    SLOT_TWO,
    SLOT_THREE,
    SLOT_FOUR
};

// teams
enum
{
    TEAM_NONE = 0,
    TEAM_SPEC,
    TEAM_RED,
    TEAM_BLU
};

//arena status
enum
{
    AS_IDLE = 0,
    AS_PRECOUNTDOWN,
    AS_COUNTDOWN,
    AS_FIGHT,
    AS_AFTERFIGHT,
    AS_REPORTED,
    AS_WAITING_READY
};

// for neutral cap points
#define NEUTRAL 1

//sounds
#define STOCK_SOUND_COUNT 24
//
#define DEFAULT_CDTIME 3
//
#define MODEL_POINT             "models/props_gameplay/cap_point_base.mdl"
#define MODEL_BRIEFCASE         "models/flag/briefcase.mdl"
#define MODEL_AMMOPACK          "models/items/ammopack_small.mdl"
#define MODEL_LARGE_AMMOPACK    "models/items/ammopack_large.mdl"

//#define DEBUG_LOG

// ====[ VARIABLES ]===================================================
// Handle, String, Float, Bool, NUM, TFCT
bool
    g_bNoStats,
    g_bNoDisplayRating;

// HUD Handles
Handle
    hm_HP,
    hm_Score,
    hm_TeammateHP,
    hm_KothTimerBLU,
    hm_KothTimerRED,
    hm_KothCap;

// Cookie Handles
Handle g_hShowEloCookie;

// Global Variables
char g_sMapName[256];

bool g_bBlockFallDamage,
     g_bUseSQLite,
     g_bAutoCvar,
     g_b2v2SkipCountdown;

int
    g_iDefaultFragLimit,
    g_iAirshotHeight = 80;

// Database
Database g_DB; // Connection to SQL database.
Handle g_hDBReconnectTimer;

char g_sDBConfig[256];
int g_iReconnectInterval;

// Global CVar Handles
ConVar
    gcvar_WfP,
    gcvar_fragLimit,
    gcvar_allowedClasses,
    gcvar_blockFallDamage,
    gcvar_dbConfig,
    gcvar_midairHP,
    gcvar_airshotHeight,
    gcvar_RocketForceX,
    gcvar_RocketForceY,
    gcvar_RocketForceZ,
    gcvar_autoCvar,
    gcvar_bballParticle_red,
    gcvar_bballParticle_blue,
    gcvar_noDisplayRating,
    gcvar_stats,
    gcvar_reconnectInterval,
    gcvar_2v2SkipCountdown;

// Classes
bool g_tfctClassAllowed[10];

// Arena Vars
Handle g_tKothTimer         [MAXARENAS + 1];
char
    g_sArenaName            [MAXARENAS + 1][64],
    // from chillymge
    g_sArenaOriginalName    [MAXARENAS + 1][64],
    // Cap point trggier name for KOTH
    g_sArenaCapTrigger      [MAXARENAS + 1][64],
    // Cap point name for KOTH
    g_sArenaCap             [MAXARENAS + 1][64];

float
    g_fArenaSpawnOrigin     [MAXARENAS + 1][MAXSPAWNS+1][3],
    g_fArenaSpawnAngles     [MAXARENAS + 1][MAXSPAWNS+1][3],
    g_fArenaHPRatio         [MAXARENAS + 1],
    g_fArenaMinSpawnDist    [MAXARENAS + 1],
    g_fArenaRespawnTime     [MAXARENAS + 1],
    g_fKothCappedPercent    [MAXARENAS + 1],
    g_fTotalTime            [MAXARENAS + 1],
    g_fCappedTime           [MAXARENAS + 1];

bool
    g_bArenaAmmomod         [MAXARENAS + 1],
    g_bArenaMidair          [MAXARENAS + 1],
    g_bArenaMGE             [MAXARENAS + 1],
    g_bArenaEndif           [MAXARENAS + 1],
    g_bArenaBBall           [MAXARENAS + 1],
    g_bVisibleHoops         [MAXARENAS + 1],
    g_bArenaInfAmmo         [MAXARENAS + 1],
    g_bFourPersonArena      [MAXARENAS + 1],
    g_bArenaAllowChange     [MAXARENAS + 1],
    g_bArenaAllowKoth       [MAXARENAS + 1],
    g_bArenaKothTeamSpawn   [MAXARENAS + 1],
    g_bArenaShowHPToPlayers [MAXARENAS + 1],
    g_bArenaUltiduo         [MAXARENAS + 1],
    g_bArenaKoth            [MAXARENAS + 1],
    g_bPlayerTouchPoint     [MAXARENAS + 1][5],
    g_bArenaTurris          [MAXARENAS + 1],
    g_bOvertimePlayed       [MAXARENAS + 1][4],
    g_bTimerRunning         [MAXARENAS + 1],
    g_bArenaHasCap          [MAXARENAS + 1],
    g_bArenaHasCapTrigger   [MAXARENAS + 1],
    g_bArenaBoostVectors    [MAXARENAS + 1],
    g_bArenaClassChange     [MAXARENAS + 1];

int
    g_iArenaCount,
    g_iArenaAirshotHeight   [MAXARENAS + 1],
    g_iCappingTeam          [MAXARENAS + 1],
    g_iCapturePoint         [MAXARENAS + 1],
    g_iDefaultCapTime       [MAXARENAS + 1],
    g_iArenaDuelStartTime   [MAXARENAS + 1],  // Unix timestamp when duel started
    //                      [what arena is the cap point in][Team Red or Team Blu Time left]
    g_iKothTimer            [MAXARENAS + 1][4],
    // 1 = neutral, 2 = RED, 3 = BLU
    g_iPointState           [MAXARENAS + 1],
    g_iArenaScore           [MAXARENAS + 1][3],
    g_iArenaQueue           [MAXARENAS + 1][MAXPLAYERS + 1],
    g_iArenaStatus          [MAXARENAS + 1],
    // countdown to round start
    g_iArenaCd              [MAXARENAS + 1],
    g_iArenaFraglimit       [MAXARENAS + 1],
    g_iArenaMgelimit        [MAXARENAS + 1],
    g_iArenaCaplimit        [MAXARENAS + 1],
    g_iArenaMinRating       [MAXARENAS + 1],
    g_iArenaMaxRating       [MAXARENAS + 1],
    g_iArenaCdTime          [MAXARENAS + 1],
    g_iArenaSpawns          [MAXARENAS + 1],
    //                      [What arena the hoop is in][Hoop 1 or Hoop 2]
    g_iBBallHoop            [MAXARENAS + 1][3],
    g_iBBallIntel           [MAXARENAS + 1],
    g_iArenaEarlyLeave      [MAXARENAS + 1],
    g_iELOMenuPage          [MAXARENAS + 1];

//int g_tfctArenaAllowedClasses[MAXARENAS + 1][TFClassType+1];
bool g_tfctArenaAllowedClasses[MAXARENAS + 1][10];

// Player vars
char g_sPlayerSteamID       [MAXPLAYERS + 1][32]; //saving steamid

bool
    g_bPlayerTakenDirectHit [MAXPLAYERS + 1],//player was hit directly
    g_bPlayerRestoringAmmo  [MAXPLAYERS + 1],//player is awaiting full ammo restore
    g_bPlayerHasIntel       [MAXPLAYERS + 1],
    g_bHitBlip              [MAXPLAYERS + 1],
    g_bShowHud              [MAXPLAYERS + 1] = { true, ... },
    g_bShowElo              [MAXPLAYERS + 1] = { true, ... },
    g_iPlayerWaiting        [MAXPLAYERS + 1],
    g_bCanPlayerSwap        [MAXPLAYERS + 1],
    g_bCanPlayerGetIntel    [MAXPLAYERS + 1];

int
    g_iPlayerArena          [MAXPLAYERS + 1],
    g_iPlayerSlot           [MAXPLAYERS + 1],
    g_iPlayerHP             [MAXPLAYERS + 1], //true HP of players
    g_iPlayerSpecTarget     [MAXPLAYERS + 1],
    g_iPlayerMaxHP          [MAXPLAYERS + 1],
    g_iClientParticle       [MAXPLAYERS + 1],
    g_iPlayerClip           [MAXPLAYERS + 1][3],
    g_iPlayerWins           [MAXPLAYERS + 1],
    g_iPlayerLosses         [MAXPLAYERS + 1],
    g_iPlayerRating         [MAXPLAYERS + 1],
    g_iPlayerHandicap       [MAXPLAYERS + 1];

TFClassType g_tfctPlayerClass[MAXPLAYERS + 1];

// 2v2 System Variables
bool g_bPlayer2v2Ready[MAXPLAYERS + 1];  // Player ready status for 2v2 matches


// Class tracking for duels
TFClassType g_tfctPlayerDuelClass[MAXPLAYERS + 1];

// Track all classes used during a duel (for arenas with class changes allowed)
ArrayList g_alPlayerDuelClasses[MAXPLAYERS + 1];

// Bot things
bool g_bPlayerAskedForBot[MAXPLAYERS + 1];

// Midair
int g_iMidairHP;

// Debug log
char g_sLogFile[PLATFORM_MAX_PATH];

// Endif
float
    g_fRocketForceX,
    g_fRocketForceY,
    g_fRocketForceZ;

// Bball
char
    g_sBBallParticleRed[64],
    g_sBBallParticleBlue[64];

static const char stockSounds[][] =  // Sounds that do not need to be downloaded.
{
    "vo/intel_teamcaptured.wav",
    "vo/intel_teamdropped.wav",
    "vo/intel_teamstolen.wav",
    "vo/intel_enemycaptured.wav",
    "vo/intel_enemydropped.wav",
    "vo/intel_enemystolen.wav",
    "vo/announcer_ends_5sec.wav",
    "vo/announcer_ends_4sec.wav",
    "vo/announcer_ends_3sec.wav",
    "vo/announcer_ends_2sec.wav",
    "vo/announcer_ends_1sec.wav",
    "vo/announcer_ends_10sec.wav",
    "vo/announcer_control_point_warning.wav",
    "vo/announcer_control_point_warning2.wav",
    "vo/announcer_control_point_warning3.wav",
    "vo/announcer_overtime.wav",
    "vo/announcer_overtime2.wav",
    "vo/announcer_overtime3.wav",
    "vo/announcer_overtime4.wav",
    "vo/announcer_we_captured_control.wav",
    "vo/announcer_we_lost_control.wav",
    "items/spawn_item.wav",
    "vo/announcer_victory.wav",
    "vo/announcer_you_failed.wav"
};

public Plugin myinfo =
{
    name        = "MGE",
    author      = "Originally by Lange & Cprice; based on kAmmomod by Krolus - maintained by sappho.io, PepperKick, and others",
    description = "Duel mod for TF2 with realistic game situations.",
    version     =  PL_VERSION,
    url         = "https://github.com/sapphonie/MGEMod"
}
/*
** ------------------------------------------------------------------
**     ____           ______                  __  _
**    / __ \____     / ____/__  ______  _____/ /_(_)____  ____  _____
**   / / / / __ \   / /_   / / / / __ \/ ___/ __/ // __ \/ __ \/ ___/
**  / /_/ / / / /  / __/  / /_/ / / / / /__/ /_/ // /_/ / / / (__  )
**  \____/_/ /_/  /_/     \__,_/_/ /_/\___/\__/_/ \____/_/ /_/____/
**
** ------------------------------------------------------------------
**/

/* OnPluginStart()
 *
 * When the plugin is loaded.
 * Cvars, variables, and console commands are initialzed here.
 * -------------------------------------------------------------------------- */
public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    LoadTranslations("mgemod.phrases");

    // Initialize cookies
    g_hShowEloCookie = RegClientCookie("mgemod_showelo", "MGEMod ELO display preference", CookieAccess_Private);

    //ConVars
    CreateConVar("sm_mgemod_version", PL_VERSION, "MGEMod version", FCVAR_SPONLY | FCVAR_NOTIFY);
    gcvar_fragLimit = CreateConVar("mgemod_fraglimit", "3", "Default frag limit in duel", FCVAR_NONE, true, 1.0);
    gcvar_allowedClasses = CreateConVar("mgemod_allowed_classes", "soldier demoman scout", "Classes that players allowed to choose by default");
    gcvar_blockFallDamage = CreateConVar("mgemod_blockdmg_fall", "0", "Block falldamage? (0 = Disabled)", FCVAR_NONE, true, 0.0, true, 1.0);
    gcvar_dbConfig = CreateConVar("mgemod_dbconfig", "mgemod", "Name of database config");
    gcvar_stats = CreateConVar("mgemod_stats", "1", "Enable/Disable stats.");
    gcvar_airshotHeight = CreateConVar("mgemod_airshot_height", "80", "The minimum height at which it will count airshot", FCVAR_NONE, true, 10.0, true, 500.0);
    gcvar_RocketForceX = CreateConVar("mgemod_endif_force_x", "1.1", "The amount by which to multiply the X push force on Endif.", FCVAR_NONE, true, 1.0, true, 10.0);
    gcvar_RocketForceY = CreateConVar("mgemod_endif_force_y", "1.1", "The amount by which to multiply the Y push force on Endif.", FCVAR_NONE, true, 1.0, true, 10.0);
    gcvar_RocketForceZ = CreateConVar("mgemod_endif_force_z", "2.15", "The amount by which to multiply the Z push force on Endif.", FCVAR_NONE, true, 1.0, true, 10.0);
    gcvar_autoCvar = CreateConVar("mgemod_autocvar", "1", "Automatically set recommended game cvars? (0 = Disabled)", FCVAR_NONE, true, 0.0, true, 1.0);
    gcvar_bballParticle_red = CreateConVar("mgemod_bball_particle_red", "player_intel_trail_red", "Particle effect to attach to Red players in BBall.");
    gcvar_bballParticle_blue = CreateConVar("mgemod_bball_particle_blue", "player_intel_trail_blue", "Particle effect to attach to Blue players in BBall.");
    gcvar_WfP = FindConVar("mp_waitingforplayers_cancel");
    gcvar_midairHP = CreateConVar("mgemod_midair_hp", "5", "", FCVAR_NONE, true, 1.0);
    gcvar_noDisplayRating = CreateConVar("mgemod_hide_rating", "0", "Hide the in-game display of rating points. They will still be tracked in the database.");
    gcvar_reconnectInterval = CreateConVar("mgemod_reconnect_interval", "5", "How long (in minutes) to wait between database reconnection attempts.");
    gcvar_2v2SkipCountdown = CreateConVar("mgemod_2v2_skip_countdown", "0", "Skip countdown between 2v2 rounds? (0 = Normal countdown, 1 = Skip countdown)", FCVAR_NONE, true, 0.0, true, 1.0);

    // Populate global variables with their corresponding convar values.
    g_iDefaultFragLimit = gcvar_fragLimit.IntValue;
    g_bBlockFallDamage = gcvar_blockFallDamage.IntValue ? true : false;
    g_iAirshotHeight = gcvar_airshotHeight.IntValue;
    g_iMidairHP = gcvar_midairHP.IntValue;
    g_bAutoCvar = gcvar_autoCvar.IntValue ? true : false;
    g_bNoDisplayRating = gcvar_noDisplayRating.IntValue ? true : false;
    g_iReconnectInterval = gcvar_reconnectInterval.IntValue;
    g_b2v2SkipCountdown = gcvar_2v2SkipCountdown.IntValue ? true : false;

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

    // Hook convar changes.
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

    // Create/register client commands.
    RegConsoleCmd("mgemod", Command_Menu, "MGEMod Menu");
    RegConsoleCmd("add", Command_Menu, "Usage: add <arena number/arena name>. Add to an arena.");
    RegConsoleCmd("swap", Command_Swap, "Ask your teammate to swap classes with you in ultiduo");
    RegConsoleCmd("remove", Command_Remove, "Remove from current arena.");
    RegConsoleCmd("top5", Command_Top5, "Display the Top 5 players.");
    RegConsoleCmd("hitblip", Command_ToogleHitblip, "Toggle hitblip!");
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

    RegAdminCmd("loc", Command_Loc, ADMFLAG_BAN, "Shows client origin and angle vectors");
    RegAdminCmd("botme", Command_AddBot, ADMFLAG_BAN, "Add bot to your arena");
    RegAdminCmd("conntest", Command_ConnectionTest, ADMFLAG_BAN, "MySQL connection test");

    // from chillymge
    RegConsoleCmd("1v1", Command_OneVsOne, "Change arena to 1v1");
    RegConsoleCmd("2v2", Command_TwoVsTwo, "Change arena to 2v2");
    RegAdminCmd("koth", Command_Koth, ADMFLAG_BAN, "Change arena to KOTH Mode");
    RegAdminCmd("mge", Command_Mge, ADMFLAG_BAN, "Change arena to MGE Mode");
    
    // 2v2 Ready System Commands
    RegConsoleCmd("ready", Command_Ready, "Mark yourself as ready for 2v2 match");
    RegConsoleCmd("r", Command_Ready, "Mark yourself as ready for 2v2 match");

    AddCommandListener(Command_DropItem, "dropitem");

    // Create the HUD text handles for later use.
    hm_HP           = CreateHudSynchronizer();
    hm_Score        = CreateHudSynchronizer();
    hm_KothTimerBLU = CreateHudSynchronizer();
    hm_KothTimerRED = CreateHudSynchronizer();
    hm_KothCap      = CreateHudSynchronizer();
    hm_TeammateHP   = CreateHudSynchronizer();

    // Set up the log file for debug logging.
    BuildPath(Path_SM, g_sLogFile, sizeof(g_sLogFile), "logs/mgemod.log");

    PrintToChatAll("[MGEMod] Plugin reloaded. Slaying all players to avoid bugs.");

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

public void OnConfigsExecuted()
{
    // Only connect to the SQL DB if stats are enabled.
    // This is here so we don't have a race condition where we load from sqlite no matter what since we don't wait until db cfg is set.
    // Most of the rest of the cvar checking logic in this plugin needs moved here too.
    if (!g_bNoStats)
    {
        PrepareSQL();
    }
}



/* OnMapStart()
*
* When the map starts.
* Sounds, models, and spawns are loaded here.
* Most events are hooked here as well.
* -------------------------------------------------------------------------- */
public void OnMapStart()
{
    for (int i = 0; i < STOCK_SOUND_COUNT; i++)/* Stock sounds are considered mandatory. */
    PrecacheSound(stockSounds[i], true);

    // Models. These are used for the artifical flag in BBall.
    PrecacheModel(MODEL_BRIEFCASE, true);
    PrecacheModel(MODEL_AMMOPACK, true);
    //Used for ultiduo/koth arenas
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
            /*  MGEMod often creates situtations where the number of players on RED and BLU will be uneven.
            If the server tries to force a player to a different team due to autobalance being on, it will interfere with MGEMod's queue system.
            These cvar settings are considered mandatory for MGEMod. */
            ServerCommand("mp_autoteambalance 0");
            ServerCommand("mp_teams_unbalance_limit 32");
            ServerCommand("mp_tournament 0");
            LogMessage("AutoCvar: Setting mp_autoteambalance 0, mp_teams_unbalance_limit 32, & mp_tournament 0");
        }

        HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
        HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
        HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
        HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Post);
        HookEvent("teamplay_win_panel", Event_WinPanel, EventHookMode_Post);

        AddNormalSoundHook(sound_hook);
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

/* OnMapEnd()
 *
 * When the map ends.
 * Repeating timers can be killed here.
 * Hooks are removed here.
 * -------------------------------------------------------------------------- */
public void OnMapEnd()
{
    g_hDBReconnectTimer = null;
    g_bNoStats = gcvar_stats.BoolValue ? false : true;

    UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
    UnhookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    UnhookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
    UnhookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Post);
    UnhookEvent("teamplay_win_panel", Event_WinPanel, EventHookMode_Post);

    RemoveNormalSoundHook(sound_hook);

    for (int arena_index = 1; arena_index < g_iArenaCount; arena_index++)
    {
        if (g_bTimerRunning[arena_index])
        {
            delete g_tKothTimer[arena_index];
            g_bTimerRunning[arena_index] = false;
        }
    }
}

/* OnEntityCreated(entity, const String:classname[])
 *
 * When an entity is created.
 * This is an SDKHooks forward.
 * -------------------------------------------------------------------------- */
public void OnEntityCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "tf_projectile_rocket") || StrEqual(classname, "tf_projectile_pipe"))
        SDKHook(entity, SDKHook_Touch, OnProjectileTouch);
}

/* OnProjectileTouch(int entity, int other)
 *
 * When a projectile is touched.
 * This is how direct hits from pipes are rockets are detected.
 * -------------------------------------------------------------------------- */
void OnProjectileTouch(int entity, int other)
{
    if (other > 0 && other <= MaxClients)
        g_bPlayerTakenDirectHit[other] = true;

}

/* OnClientPostAdminCheck(client)
 *
 * Called once a client is fully in-game, and authorized with Steam.
 * Client-specific variables are initialized here.
 * 
 * NOTE: This needs to not be here. This will break when steam is down, this probably has other issues as well
 * 
 * Most of this should be in OnClientPutInServer
 * -------------------------------------------------------------------------- */
public void OnClientPostAdminCheck(int client)
{
    if (IsFakeClient(client))
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (g_bPlayerAskedForBot[i])
            {
                int arena_index = g_iPlayerArena[i];
                DataPack pack = new DataPack();
                CreateDataTimer(1.5, Timer_AddBotInQueue, pack);
                pack.WriteCell(GetClientUserId(client));
                pack.WriteCell(arena_index);
                g_iPlayerRating[client] = 1551;
                g_bPlayerAskedForBot[i] = false;
                break;
            }
        }
    }
    else
    {
        ChangeClientTeam(client, TEAM_SPEC);
        CreateTimer(5.0, Timer_ShowAdv, GetClientUserId(client)); /* Show advice to type !add in chat */
        g_bHitBlip[client] = false;
        g_bShowHud[client] = true;
        g_bPlayerRestoringAmmo[client] = false;
        g_bShowElo[client] = true;
        
        // Load ELO display preference from cookie
        char cookieValue[8];
        GetClientCookie(client, g_hShowEloCookie, cookieValue, sizeof(cookieValue));
        if (strlen(cookieValue) > 0)
            g_bShowElo[client] = (StringToInt(cookieValue) == 1);
        
        // Initialize class tracking ArrayList
        if (g_alPlayerDuelClasses[client] != null)
            delete g_alPlayerDuelClasses[client];
        g_alPlayerDuelClasses[client] = new ArrayList();
        
        CreateTimer(15.0, Timer_WelcomePlayer, GetClientUserId(client));

        if (!g_bNoStats)
        {
            char steamid_dirty[31], steamid[64], query[256];
            GetClientAuthId(client, AuthId_Steam2, steamid_dirty, sizeof(steamid_dirty));
            g_DB.Escape(steamid_dirty, steamid, sizeof(steamid));
            strcopy(g_sPlayerSteamID[client], 32, steamid);
            Format(query, sizeof(query), "SELECT rating, hitblip, wins, losses FROM mgemod_stats WHERE steamid='%s' LIMIT 1", steamid);
            g_DB.Query(T_SQLQueryOnConnect, query, client);
        }
    }

    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

/* OnClientDisconnect(client)
*
* When a client disconnects from the server.
* Client-specific timers are killed here.
* -------------------------------------------------------------------------- */
public void OnClientDisconnect(int client)
{
    // We ignore the kick queue check for this function only so that clients that get kicked still get their elo calculated
    if (IsValidClient(client, true) && g_iPlayerArena[client])
    {
        RemoveFromQueue(client, true);
    }
    else
    {
        int
            arena_index = g_iPlayerArena[client],
            player_slot = g_iPlayerSlot[client],
            foe_slot = (player_slot == SLOT_ONE || player_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE,
            foe = g_iArenaQueue[arena_index][foe_slot];

        //Turn all this logic into a helper meathod
        int player_teammate, foe2;

        if (g_bFourPersonArena[arena_index])
        {
            player_teammate = getTeammate(player_slot, arena_index);
            foe2 = getTeammate(foe_slot, arena_index);
        }

        g_iPlayerArena[client] = 0;
        g_iPlayerSlot[client] = 0;
        g_iArenaQueue[arena_index][player_slot] = 0;
        g_iPlayerHandicap[client] = 0;
        
        // Cleanup class tracking ArrayList
        if (g_alPlayerDuelClasses[client] != null)
        {
            delete g_alPlayerDuelClasses[client];
            g_alPlayerDuelClasses[client] = null;
        }
        
        // Clear 2v2 ready status
        g_bPlayer2v2Ready[client] = false;

        // Bot cleanup logic (queue advancement is handled by RemoveFromQueue)
        if (foe && IsFakeClient(foe))
        {
            ConVar cvar = FindConVar("tf_bot_quota");
            int quota = cvar.IntValue;
            ServerCommand("tf_bot_quota %d", quota - 1);
        }

        if (foe2 && IsFakeClient(foe2))
        {
            ConVar cvar = FindConVar("tf_bot_quota");
            int quota = cvar.IntValue;
            ServerCommand("tf_bot_quota %d", quota - 1);
        }

        if (player_teammate && IsFakeClient(player_teammate))
        {
            ConVar cvar = FindConVar("tf_bot_quota");
            int quota = cvar.IntValue;
            ServerCommand("tf_bot_quota %d", quota - 1);
        }

        // Ensure any 2v2 waiting/spec players are restored on disconnect
        if (g_bFourPersonArena[arena_index])
        {
            Restore2v2WaitingSpectators(arena_index);
            CreateTimer(3.0, Timer_Restart2v2Ready, arena_index);
        }

        g_iArenaStatus[arena_index] = AS_IDLE;
        return;
    }
}

/* OnGameFrame()
 *
 * This code is run on every frame. Can be very hardware intensive.
 * -------------------------------------------------------------------------- */
// note from the future - "this can be hardware intensive" and then its repeated code like 4 times? lol ok
public void OnGameFrame()
{
    int arena_index;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsValidClient(client) && IsPlayerAlive(client))
        {
            arena_index = g_iPlayerArena[client];
            if (!g_bArenaBBall[arena_index] && !g_bArenaMGE[arena_index] && !g_bArenaKoth[arena_index])
            {
                /*  This is a hack that prevents people from getting one-shot by things
                like the direct hit in the Ammomod arenas. */
                int replacement_hp = (g_iPlayerMaxHP[client] + 512);
                SetEntProp(client, Prop_Send, "m_iHealth", replacement_hp, 1);
            }
        }
    }
    for (int arena_index2 = 1; arena_index2 <= g_iArenaCount; ++arena_index2)
    {
        if (g_bArenaKoth[arena_index2] && g_iArenaStatus[arena_index2] == AS_FIGHT)
        {
            g_fTotalTime[arena_index2] += 7;
            if (g_iPointState[arena_index2] == NEUTRAL || g_iPointState[arena_index2] == TEAM_BLU)
            {
                //If RED Team is capping and BLU Team isn't and BLU Team has the point increase the cap time
                if (!(g_bPlayerTouchPoint[arena_index2][SLOT_TWO] || g_bPlayerTouchPoint[arena_index2][SLOT_FOUR]) && (g_iCappingTeam[arena_index2] == TEAM_RED || g_iCappingTeam[arena_index2] == NEUTRAL))
                {
                    int cap = 0;

                    if (g_bPlayerTouchPoint[arena_index2][SLOT_ONE])
                    {
                        cap++;
                        //If the player is a Scout add one to the cap speed
                        if (g_tfctPlayerClass[g_iArenaQueue[arena_index2][SLOT_ONE]] == TF2_GetClass("scout"))
                            cap++;

                        int ent = GetPlayerWeaponSlot(g_iArenaQueue[arena_index2][SLOT_ONE], 2);
                        int iItemDefinitionIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");

                        //If the player has the Pain Train equipped add one to the cap speed
                        if (iItemDefinitionIndex == 154)
                            cap++;
                    }
                    if (g_bPlayerTouchPoint[arena_index2][SLOT_THREE])
                    {
                        cap++;
                        //If the player is a Scout add one to the cap speed
                        if (g_tfctPlayerClass[g_iArenaQueue[arena_index2][SLOT_THREE]] == TF2_GetClass("scout"))
                            cap++;

                        int ent = GetPlayerWeaponSlot(g_iArenaQueue[arena_index2][SLOT_THREE], 2);
                        int iItemDefinitionIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");

                        //If the player has the Pain Train equipped add one to the cap speed
                        if (iItemDefinitionIndex == 154)
                            cap++;
                    }
                    //Add cap time if needed
                    if (cap)
                    {
                        //True harmonic cap time, yes!
                        for (; cap > 0; cap--)
                        {
                            g_fCappedTime[arena_index2] += 7.0 / float(cap);
                        }
                        g_iCappingTeam[arena_index2] = TEAM_RED;
                        continue;
                    }
                }


            }

            if (g_iPointState[arena_index2] == NEUTRAL || g_iPointState[arena_index2] == TEAM_RED)
            {
                //If BLU Team is capping and Team RED isn't and Team RED has the point increase the cap time
                if (!(g_bPlayerTouchPoint[arena_index2][SLOT_ONE] || g_bPlayerTouchPoint[arena_index2][SLOT_THREE]) && (g_iCappingTeam[arena_index2] == TEAM_BLU || g_iCappingTeam[arena_index2] == NEUTRAL))
                {
                    int cap = 0;

                    if (g_bPlayerTouchPoint[arena_index2][SLOT_TWO])
                    {
                        cap++;
                        //If the player is a Scout add one to the cap speed
                        if (g_tfctPlayerClass[g_iArenaQueue[arena_index2][SLOT_TWO]] == TF2_GetClass("scout"))
                            cap++;

                        int ent = GetPlayerWeaponSlot(g_iArenaQueue[arena_index2][SLOT_TWO], 2);
                        int iItemDefinitionIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");

                        //If the player has the Pain Train equipped add one to the cap speed
                        if (iItemDefinitionIndex == 154)
                            cap++;
                    }
                    if (g_bPlayerTouchPoint[arena_index2][SLOT_FOUR])
                    {
                        cap++;
                        //If the player is a Scout add one to the cap speed
                        if (g_tfctPlayerClass[g_iArenaQueue[arena_index2][SLOT_FOUR]] == TF2_GetClass("scout"))
                            cap++;

                        int ent = GetPlayerWeaponSlot(g_iArenaQueue[arena_index2][SLOT_FOUR], 2);
                        int iItemDefinitionIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");

                        //If the player has the Pain Train equipped add one to the cap speed
                        if (iItemDefinitionIndex == 154)
                            cap++;
                    }
                    //Add cap time if needed
                    if (cap)
                    {
                        //True harmonic cap time, yes!
                        for (; cap > 0; cap--)
                        {
                            g_fCappedTime[arena_index2] += 7.0, float(cap);
                        }
                        g_iCappingTeam[arena_index2] = TEAM_BLU;
                        continue;
                    }
                }


            }

            //If BLU Team is blocking and RED Team isn't capping and BLU Team has the point increase the cap diminish rate
            if ((g_bPlayerTouchPoint[arena_index2][SLOT_TWO] || g_bPlayerTouchPoint[arena_index2][SLOT_FOUR]) &&
                (g_iPointState[arena_index2] == NEUTRAL) && g_iCappingTeam[arena_index2] == TEAM_RED &&
                !(g_bPlayerTouchPoint[arena_index2][SLOT_ONE] || g_bPlayerTouchPoint[arena_index2][SLOT_THREE]))
            {
                int cap = 0;

                if (g_bPlayerTouchPoint[arena_index2][SLOT_TWO])
                {
                    cap++;
                    //If the player is a Scout add one to the cap speed
                    if (g_tfctPlayerClass[g_iArenaQueue[arena_index2][SLOT_TWO]] == TF2_GetClass("scout"))
                        cap++;

                    int ent = GetPlayerWeaponSlot(g_iArenaQueue[arena_index2][SLOT_TWO], 2);
                    int iItemDefinitionIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");

                    //If the player has the Pain Train equipped add one to the cap speed
                    if (iItemDefinitionIndex == 154)
                        cap++;
                }
                if (g_bPlayerTouchPoint[arena_index2][SLOT_FOUR])
                {
                    cap++;
                    //If the player is a Scout add one to the cap speed
                    if (g_tfctPlayerClass[g_iArenaQueue[arena_index2][SLOT_FOUR]] == TF2_GetClass("scout"))
                        cap++;

                    int ent = GetPlayerWeaponSlot(g_iArenaQueue[arena_index2][SLOT_FOUR], 2);
                    int iItemDefinitionIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");

                    //If the player has the Pain Train equipped add one to the cap speed
                    if (iItemDefinitionIndex == 154)
                        cap++;
                }
                //Add cap time if needed
                if (cap)
                {
                    //True harmonic cap time, yes!
                    for (; cap > 0; cap--)
                    {
                        g_fCappedTime[arena_index2] -= 7.0, float(cap);
                    }
                    g_iCappingTeam[arena_index2] = TEAM_BLU;
                    continue;
                }
            }

            //If RED Team is blocking and BLU Team isn't capping and RED Team has the point increase the cap diminish rate
            if ((g_bPlayerTouchPoint[arena_index2][SLOT_ONE] || g_bPlayerTouchPoint[arena_index2][SLOT_THREE]) &&
                (g_iPointState[arena_index2] == NEUTRAL) && g_iCappingTeam[arena_index2] == TEAM_BLU &&
                !(g_bPlayerTouchPoint[arena_index2][SLOT_TWO] || g_bPlayerTouchPoint[arena_index2][SLOT_FOUR]))
            {
                int cap = 0;

                if (g_bPlayerTouchPoint[arena_index2][SLOT_ONE])
                {
                    cap++;
                    //If the player is a Scout add one to the cap speed
                    if (g_tfctPlayerClass[g_iArenaQueue[arena_index2][SLOT_ONE]] == TF2_GetClass("scout"))
                        cap++;

                    int ent = GetPlayerWeaponSlot(g_iArenaQueue[arena_index2][SLOT_ONE], 2);
                    int iItemDefinitionIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");

                    //If the player has the Pain Train equipped add one to the cap speed
                    if (iItemDefinitionIndex == 154)
                        cap++;
                }
                if (g_bPlayerTouchPoint[arena_index2][SLOT_THREE])
                {
                    cap++;
                    //If the player is a Scout add one to the cap speed
                    if (g_tfctPlayerClass[g_iArenaQueue[arena_index2][SLOT_THREE]] == TF2_GetClass("scout"))
                        cap++;

                    int ent = GetPlayerWeaponSlot(g_iArenaQueue[arena_index2][SLOT_THREE], 2);
                    int iItemDefinitionIndex = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");

                    //If the player has the Pain Train equipped add one to the cap speed
                    if (iItemDefinitionIndex == 154)
                        cap++;
                }
                //Add cap time if needed
                if (cap)
                {
                    //True harmonic cap time, yes!
                    for (; cap > 0; cap--)
                    {
                        g_fCappedTime[arena_index2] -= 7.0, float(cap);
                    }
                    g_iCappingTeam[arena_index2] = TEAM_RED;
                    continue;
                }
            }

            //If both teams are touching the point, do nothing
            if ((g_bPlayerTouchPoint[arena_index2][SLOT_TWO] || g_bPlayerTouchPoint[arena_index2][SLOT_FOUR]) && (g_bPlayerTouchPoint[arena_index2][SLOT_ONE] || g_bPlayerTouchPoint[arena_index2][SLOT_THREE]))
                continue;

            // If in overtime, revert cap at 6x speed, if not, revert cap slowly
            if (g_bOvertimePlayed[arena_index][TEAM_RED] || g_bOvertimePlayed[arena_index][TEAM_BLU])
                g_fCappedTime[arena_index2] -= 6.0;
            else
                g_fCappedTime[arena_index2]--;
        }
    }
}

/* OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
 *
 * When a client takes damage.
 * -------------------------------------------------------------------------- */
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

/* OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
*
* When a client runs a command.
* Infinite ammo is triggered here.
* -------------------------------------------------------------------------- */
public Action OnPlayerRunCmd
(
    int client,
    int& buttons,
    int& impulse,
    float vel[3],
    float angles[3],
    int& weapon,
    int& subtype,
    int& cmdnum,
    int& tickcount,
    int& seed,
    int mouse[2]
)
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

/* OnTouchPoint(int entity, int other)
*
* When the point is touched
* ------------------------------------------------------------------------- */
Action OnEndTouchPoint(int entity, int other)
{
    int client = other;

    if (!IsValidClient(client))
    {
        return Plugin_Continue;
    }
    int arena_index = g_iPlayerArena[client];
    int client_slot = g_iPlayerSlot[client];

    g_bPlayerTouchPoint[arena_index][client_slot] = false;
    return Plugin_Continue;
}

/* OnTouchPoint(int entity, int other)
*
* When the point is touched
* ------------------------------------------------------------------------- */
Action OnTouchPoint(int entity, int other)
{
    int client = other;

    if (!IsValidClient(client))
        return Plugin_Continue;

    int arena_index = g_iPlayerArena[client];
    int client_slot = g_iPlayerSlot[client];

    g_bPlayerTouchPoint[arena_index][client_slot] = true;
    return Plugin_Continue;
}

/* OnTouchHoop(int entity, int other)
*
* When a hoop is touched by a player in BBall.
* -------------------------------------------------------------------------- */
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
                //SDKUnhook(g_iBBallIntel[arena_index], SDKHook_StartTouch, OnTouchIntel);
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

        EmitSoundToClient(client, "vo/intel_teamcaptured.wav");
        EmitSoundToClient(foe, "vo/intel_enemycaptured.wav");

        if (g_bFourPersonArena[arena_index])
        {
            //This shouldn't be necessary but I'm getting invalid clients for some reason.
            if (IsValidClient(client_teammate))
                EmitSoundToClient(client_teammate, "vo/intel_teamcaptured.wav");
            if (IsValidClient(foe_teammate))
                EmitSoundToClient(foe_teammate, "vo/intel_enemycaptured.wav");
        }

        ShowSpecHudToArena(arena_index);
    }
    return Plugin_Continue;
}

/* OnTouchIntel(int entity, int other)
*
* When the intel is touched by a player in BBall.
* -------------------------------------------------------------------------- */
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
        //SDKUnhook(g_iBBallIntel[arena_index], SDKHook_StartTouch, OnTouchIntel);
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
    EmitSoundToClient(client, "vo/intel_teamstolen.wav");

    int foe = g_iArenaQueue[g_iPlayerArena[client]][(g_iPlayerSlot[client] == SLOT_ONE || g_iPlayerSlot[client] == SLOT_THREE) ? SLOT_TWO : SLOT_ONE];

    if (IsValidClient(foe))
    {
        EmitSoundToClient(foe, "vo/intel_enemystolen.wav");
        ShowPlayerHud(foe);
    }

    if (g_bFourPersonArena[g_iPlayerArena[client]])
    {
        int foe2 = g_iArenaQueue[g_iPlayerArena[client]][(g_iPlayerSlot[client] == SLOT_ONE || g_iPlayerSlot[client] == SLOT_THREE) ? SLOT_FOUR : SLOT_THREE];
        if (IsValidClient(foe2))
        {
            EmitSoundToClient(foe2, "vo/intel_enemystolen.wav");
            ShowPlayerHud(foe2);
        }
    }

    return Plugin_Continue;
}

/*
** -------------------------------------------------------------------------------
**      ____       _              ______                  __  _
**     / __ \_____(_)_   __      / ____/__  ______  _____/ /_(_)____  ____  _____
**    / /_/ / ___/ /| | / /     / /_   / / / / __ \/ ___/ __/ // __ \/ __ \/ ___/
**   / ____/ /  / / | |/ /_    / __/  / /_/ / / / / /__/ /_/ // /_/ / / / (__  )
**  /_/   /_/  /_/  |___/(_)  /_/     \__,_/_/ /_/\___/\__/_/ \____/_/ /_/____/
**
** -------------------------------------------------------------------------------
**/

int StartCountDown(int arena_index)
{
    int red_f1 = g_iArenaQueue[arena_index][SLOT_ONE]; /* Red (slot one) player. */
    int blu_f1 = g_iArenaQueue[arena_index][SLOT_TWO]; /* Blu (slot two) player. */

    if (g_bFourPersonArena[arena_index])
    {
        int red_f2 = g_iArenaQueue[arena_index][SLOT_THREE]; /* 2nd Red (slot three) player. */
        int blu_f2 = g_iArenaQueue[arena_index][SLOT_FOUR]; /* 2nd Blu (slot four) player. */

        if (red_f1)
            ResetPlayer(red_f1);
        if (blu_f1)
            ResetPlayer(blu_f1);
        if (red_f2)
            ResetPlayer(red_f2);
        if (blu_f2)
            ResetPlayer(blu_f2);


        if (red_f1 && blu_f1 && red_f2 && blu_f2)
        {
            // Store player classes for duel tracking
            g_tfctPlayerDuelClass[red_f1] = g_tfctPlayerClass[red_f1];
            g_tfctPlayerDuelClass[blu_f1] = g_tfctPlayerClass[blu_f1];
            g_tfctPlayerDuelClass[red_f2] = g_tfctPlayerClass[red_f2];
            g_tfctPlayerDuelClass[blu_f2] = g_tfctPlayerClass[blu_f2];
            
            // Initialize class tracking lists for dynamic recording
            if (g_bArenaClassChange[arena_index])
            {
                // Ensure ArrayLists are initialized for all players (including bots)
                if (g_alPlayerDuelClasses[red_f1] == null)
                    g_alPlayerDuelClasses[red_f1] = new ArrayList();
                if (g_alPlayerDuelClasses[blu_f1] == null)
                    g_alPlayerDuelClasses[blu_f1] = new ArrayList();
                if (g_alPlayerDuelClasses[red_f2] == null)
                    g_alPlayerDuelClasses[red_f2] = new ArrayList();
                if (g_alPlayerDuelClasses[blu_f2] == null)
                    g_alPlayerDuelClasses[blu_f2] = new ArrayList();
                    
                g_alPlayerDuelClasses[red_f1].Clear();
                g_alPlayerDuelClasses[blu_f1].Clear();
                g_alPlayerDuelClasses[red_f2].Clear();
                g_alPlayerDuelClasses[blu_f2].Clear();
                
                g_alPlayerDuelClasses[red_f1].Push(view_as<int>(g_tfctPlayerClass[red_f1]));
                g_alPlayerDuelClasses[blu_f1].Push(view_as<int>(g_tfctPlayerClass[blu_f1]));
                g_alPlayerDuelClasses[red_f2].Push(view_as<int>(g_tfctPlayerClass[red_f2]));
                g_alPlayerDuelClasses[blu_f2].Push(view_as<int>(g_tfctPlayerClass[blu_f2]));
            }
            
            float enginetime = GetGameTime();

            for (int i = 0; i <= 2; i++)
            {
                int ent = GetPlayerWeaponSlot(red_f1, i);

                if (IsValidEntity(ent))
                    SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + 1.1);

                ent = GetPlayerWeaponSlot(blu_f1, i);

                if (IsValidEntity(ent))
                    SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + 1.1);

                ent = GetPlayerWeaponSlot(red_f2, i);

                if (IsValidEntity(ent))
                    SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + 1.1);

                ent = GetPlayerWeaponSlot(blu_f2, i);

                if (IsValidEntity(ent))
                    SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + 1.1);
            }

            g_iArenaCd[arena_index] = g_iArenaCdTime[arena_index] + 1;
            g_iArenaStatus[arena_index] = AS_PRECOUNTDOWN;
            CreateTimer(0.1, Timer_CountDown, arena_index, TIMER_FLAG_NO_MAPCHANGE);
            return 1;
        } else {
            if (g_bFourPersonArena[arena_index])
            {
                Restore2v2WaitingSpectators(arena_index);
            }
            g_iArenaStatus[arena_index] = AS_IDLE;
            return 0;
        }
    }
    else {
        if (red_f1)
            ResetPlayer(red_f1);
        if (blu_f1)
            ResetPlayer(blu_f1);

        if (red_f1 && blu_f1)
        {
            // Store player classes for duel tracking
            g_tfctPlayerDuelClass[red_f1] = g_tfctPlayerClass[red_f1];
            g_tfctPlayerDuelClass[blu_f1] = g_tfctPlayerClass[blu_f1];
            
            // Initialize class tracking lists for dynamic recording
            if (g_bArenaClassChange[arena_index])
            {
                // Ensure ArrayLists are initialized for all players (including bots)
                if (g_alPlayerDuelClasses[red_f1] == null)
                    g_alPlayerDuelClasses[red_f1] = new ArrayList();
                if (g_alPlayerDuelClasses[blu_f1] == null)
                    g_alPlayerDuelClasses[blu_f1] = new ArrayList();
                    
                g_alPlayerDuelClasses[red_f1].Clear();
                g_alPlayerDuelClasses[blu_f1].Clear();
                
                g_alPlayerDuelClasses[red_f1].Push(view_as<int>(g_tfctPlayerClass[red_f1]));
                g_alPlayerDuelClasses[blu_f1].Push(view_as<int>(g_tfctPlayerClass[blu_f1]));
            }
            
            float enginetime = GetGameTime();

            for (int i = 0; i <= 2; i++)
            {
                int ent = GetPlayerWeaponSlot(red_f1, i);

                if (IsValidEntity(ent))
                    SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + 1.1);

                ent = GetPlayerWeaponSlot(blu_f1, i);

                if (IsValidEntity(ent))
                    SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + 1.1);
            }

            g_iArenaCd[arena_index] = g_iArenaCdTime[arena_index] + 1;
            g_iArenaStatus[arena_index] = AS_PRECOUNTDOWN;
            CreateTimer(0.1, Timer_CountDown, arena_index, TIMER_FLAG_NO_MAPCHANGE);
            return 1;
        }
        else
        {
            if (g_bFourPersonArena[arena_index])
            {
                Restore2v2WaitingSpectators(arena_index);
            }
            g_iArenaStatus[arena_index] = AS_IDLE;
            return 0;
        }
    }
}

// ====[ HUD ]====================================================
void ShowSpecHudToArena(int arena_index)
{
    if (!arena_index)
    {
        return;
    }
    for (int i = 1; i <= MaxClients; i++)
    {
        if
        (
            IsValidClient(i)
            && GetClientTeam(i) == TEAM_SPEC
            && g_iPlayerSpecTarget[i] > 0
            && g_iPlayerArena[g_iPlayerSpecTarget[i]] == arena_index
        )
        {
            ShowSpecHudToClient(i);
        }
    }
}

void ShowCountdownToSpec(int arena_index, char[] text)
{
    if (!arena_index)
    {
        return;
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        if
        (
            IsValidClient(i)
            && GetClientTeam(i) == TEAM_SPEC
            && g_iPlayerArena[g_iPlayerSpecTarget[i]] == arena_index
        )
        {
            PrintCenterText(i, text);
        }
    }
}

void ShowPlayerHud(int client)
{
    if (!IsValidClient(client))
    {
        return;
    }

    // HP
    int arena_index = g_iPlayerArena[client];
    int client_slot = g_iPlayerSlot[client];
    int client_foe_slot = (client_slot == SLOT_ONE || client_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
    int client_foe = (g_iArenaQueue[g_iPlayerArena[client]][(g_iPlayerSlot[client] == SLOT_ONE || g_iPlayerSlot[client] == SLOT_THREE) ? SLOT_TWO : SLOT_ONE]); //test
    int client_teammate;
    int client_foe2;
    char hp_report[128];

    if (g_bFourPersonArena[arena_index])
    {
        client_teammate = getTeammate(client_slot, arena_index);
        client_foe2 = getTeammate(client_foe_slot, arena_index);
    }

    if (g_bArenaKoth[arena_index])
    {
        /* if (g_iArenaStatus[arena_index] == AS_FIGHT || true) */
        {
            //Show the red team timer, if they have it capped make the timer red
            if (g_iPointState[arena_index] == TEAM_RED)
            {
                SetHudTextParams(0.40, 0.01, HUDFADEOUTTIME, 255, 0, 0, 255); // Red
            }
            else
            {
                SetHudTextParams(0.40, 0.01, HUDFADEOUTTIME, 255, 255, 255, 255);
            }

            //Set the Text for the timer
            ShowSyncHudText(client, hm_KothTimerRED, "%i:%02i", g_iKothTimer[arena_index][TEAM_RED] / 60, g_iKothTimer[arena_index][TEAM_RED] % 60);

            //Show the blue team timer, if they have it capped make the timer blue
            if (g_iPointState[arena_index] == TEAM_BLU)
            {
                SetHudTextParams(0.60, 0.01, HUDFADEOUTTIME, 0, 0, 255, 255); // Blue
            }
            else
            {
                SetHudTextParams(0.60, 0.01, HUDFADEOUTTIME, 255, 255, 255, 255);
            }
            //Set the Text for the timer
            ShowSyncHudText(client, hm_KothTimerBLU, "%i:%02i", g_iKothTimer[arena_index][TEAM_BLU] / 60, g_iKothTimer[arena_index][TEAM_BLU] % 60);

            //Show the capture point percent
            //set it red if red team is capping
            if (g_iCappingTeam[arena_index] == TEAM_RED)
            {
                SetHudTextParams(0.50, 0.80, HUDFADEOUTTIME, 255, 0, 0, 255); // Red
            }
            //Set it blue if blu team is capping
            else if (g_iCappingTeam[arena_index] == TEAM_BLU)
            {
                SetHudTextParams(0.50, 0.80, HUDFADEOUTTIME, 0, 0, 255, 255); // Blue
            }
            //Set it white if no one is capping
            else
            {
                SetHudTextParams(0.50, 0.80, HUDFADEOUTTIME, 255, 255, 255, 255);
            }
            //Show the text
            ShowSyncHudText(client, hm_KothCap, "Point Capture: %.1f", g_fKothCappedPercent[arena_index]);
        }
    }


    if (g_bArenaShowHPToPlayers[arena_index])
    {
        float hp_ratio = ((float(g_iPlayerHP[client])) / (float(g_iPlayerMaxHP[client]) * g_fArenaHPRatio[arena_index]));
        if (hp_ratio > 0.66)
        {
            SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 0, 255, 0, 255); // Green
        }
        else if (hp_ratio >= 0.33)
        {
            SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 255, 255, 0, 255); // Yellow
        }
        else if (hp_ratio < 0.33)
        {
            SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 255, 0, 0, 255); // Red
        }
        else // SANITY
        {
            SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 255, 255, 255, 255); // White
        }
        ShowSyncHudText(client, hm_HP, "Health : %d", g_iPlayerHP[client]);
    }
    else
    {
        SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 255, 255, 255, 255); // White
        ShowSyncHudText(client, hm_HP, "", g_iPlayerHP[client]);
    }



    if (g_bArenaBBall[arena_index])
    {
        if (g_iArenaStatus[arena_index] == AS_FIGHT)
        {
            if (g_bPlayerHasIntel[client])
            {
                ShowSyncHudText(client, hm_HP, "You have the intel!", g_iPlayerHP[client]);
            }
            else if (g_bFourPersonArena[arena_index] && g_bPlayerHasIntel[client_teammate])
            {
                ShowSyncHudText(client, hm_HP, "Your teammate has the intel!", g_iPlayerHP[client]);
            }
            else if (g_bPlayerHasIntel[client_foe] || (g_bFourPersonArena[arena_index] && g_bPlayerHasIntel[client_foe2]))
            {
                ShowSyncHudText(client, hm_HP, "Enemy has the intel!", g_iPlayerHP[client]);
            }
            else
            {
                ShowSyncHudText(client, hm_HP, "Get the intel!", g_iPlayerHP[client]);
            }
        }
        else
        {
            ShowSyncHudText(client, hm_HP, "", g_iPlayerHP[client]);
        }
    }

    // We want ammomod players to be able to see what their health is, even when they have the text hud turned off.
    // We also want to show them BBALL notifications
    if (!g_bShowHud[client])
    {
        return;
    }

    // Score
    SetHudTextParams(0.01, 0.01, HUDFADEOUTTIME, 255, 255, 255, 255);
    char report[128];
    int fraglimit = g_iArenaFraglimit[arena_index];

    if (g_bArenaBBall[arena_index])
    {
        if (fraglimit > 0)
            Format(report, sizeof(report), "Arena %s. Capture Limit(%d)", g_sArenaName[arena_index], fraglimit);
        else
            Format(report, sizeof(report), "Arena %s. No Capture Limit", g_sArenaName[arena_index]);
    } else {
        if (fraglimit > 0)
            Format(report, sizeof(report), "Arena %s. Frag Limit(%d)", g_sArenaName[arena_index], fraglimit);
        else
            Format(report, sizeof(report), "Arena %s. No Frag Limit", g_sArenaName[arena_index]);
    }

    int red_f1 = g_iArenaQueue[arena_index][SLOT_ONE];
    int blu_f1 = g_iArenaQueue[arena_index][SLOT_TWO];
    int red_f2;
    int blu_f2;
    if (g_bFourPersonArena[arena_index])
    {
        red_f2 = g_iArenaQueue[arena_index][SLOT_THREE];
        blu_f2 = g_iArenaQueue[arena_index][SLOT_FOUR];
    }

    if (g_bFourPersonArena[arena_index])
    {
        if (red_f1)
        {
            if (red_f2)
            {
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n%N and %N : %d", report, red_f1, red_f2, g_iArenaScore[arena_index][SLOT_ONE]);
                else
                    Format(report, sizeof(report), "%s\n%N and %N (%d): %d", report, red_f1, red_f2, g_iPlayerRating[red_f1], g_iArenaScore[arena_index][SLOT_ONE]);
            }
            else
            {
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n%N : %d", report, red_f1, g_iArenaScore[arena_index][SLOT_ONE]);
                else
                    Format(report, sizeof(report), "%s\n%N (%d): %d", report, red_f1, g_iPlayerRating[red_f1], g_iArenaScore[arena_index][SLOT_ONE]);
            }


        }
        if (blu_f1)
        {
            if (blu_f2)
            {
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n%N and %N : %d", report, blu_f1, blu_f2, g_iArenaScore[arena_index][SLOT_TWO]);
                else
                    Format(report, sizeof(report), "%s\n%N and %N (%d): %d", report, blu_f1, blu_f2, g_iPlayerRating[blu_f1], g_iArenaScore[arena_index][SLOT_TWO]);
            }
            else
            {
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n%N : %d", report, blu_f1, g_iArenaScore[arena_index][SLOT_TWO]);
                else
                    Format(report, sizeof(report), "%s\n%N (%d): %d", report, blu_f1, g_iPlayerRating[blu_f1], g_iArenaScore[arena_index][SLOT_TWO]);
            }
        }
    }

    else
    {
        if (red_f1)
        {
            if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                Format(report, sizeof(report), "%s\n%N : %d", report, red_f1, g_iArenaScore[arena_index][SLOT_ONE]);
            else
                Format(report, sizeof(report), "%s\n%N (%d): %d", report, red_f1, g_iPlayerRating[red_f1], g_iArenaScore[arena_index][SLOT_ONE]);
        }

        if (blu_f1)
        {
            if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                Format(report, sizeof(report), "%s\n%N : %d", report, blu_f1, g_iArenaScore[arena_index][SLOT_TWO]);
            else
                Format(report, sizeof(report), "%s\n%N (%d): %d", report, blu_f1, g_iPlayerRating[blu_f1], g_iArenaScore[arena_index][SLOT_TWO]);
        }
    }
    ShowSyncHudText(client, hm_Score, "%s", report);


    //Hp of teammate
    if (g_bFourPersonArena[arena_index])
    {

        if (client_teammate)
            Format(hp_report, sizeof(hp_report), "%N : %d", client_teammate, g_iPlayerHP[client_teammate]);
    }
    SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 255, 255, 255, 255);
    ShowSyncHudText(client, hm_TeammateHP, hp_report);
}

void ShowSpecHudToClient(int client)
{
    if (!IsValidClient(client) || !IsValidClient(g_iPlayerSpecTarget[client]) || !g_bShowHud[client])
        return;

    int arena_index = g_iPlayerArena[g_iPlayerSpecTarget[client]];
    int red_f1 = g_iArenaQueue[arena_index][SLOT_ONE];
    int blu_f1 = g_iArenaQueue[arena_index][SLOT_TWO];
    int red_f2;
    int blu_f2;

    if (g_bFourPersonArena[arena_index])
    {
        red_f2 = g_iArenaQueue[arena_index][SLOT_THREE];
        blu_f2 = g_iArenaQueue[arena_index][SLOT_FOUR];
    }

    char hp_report[128];

    //If its a 2v2 arena show the teamates hp's
    if (g_bFourPersonArena[arena_index])
    {
        if (red_f1)
            Format(hp_report, sizeof(hp_report), "%N : %d", red_f1, g_iPlayerHP[red_f1]);

        if (red_f2)
            Format(hp_report, sizeof(hp_report), "%s\n%N : %d", hp_report, red_f2, g_iPlayerHP[red_f2]);

        if (blu_f1)
            Format(hp_report, sizeof(hp_report), "%s\n\n%N : %d", hp_report, blu_f1, g_iPlayerHP[blu_f1]);

        if (blu_f2)
            Format(hp_report, sizeof(hp_report), "%s\n%N : %d", hp_report, blu_f2, g_iPlayerHP[blu_f2]);
    }
    else
    {
        if (red_f1)
            Format(hp_report, sizeof(hp_report), "%N : %d", red_f1, g_iPlayerHP[red_f1]);

        if (blu_f1)
            Format(hp_report, sizeof(hp_report), "%s\n%N : %d", hp_report, blu_f1, g_iPlayerHP[blu_f1]);
    }



    SetHudTextParams(0.01, 0.80, HUDFADEOUTTIME, 255, 255, 255, 255);
    ShowSyncHudText(client, hm_HP, hp_report);

    // Score
    char report[128];
    SetHudTextParams(0.01, 0.01, HUDFADEOUTTIME, 255, 255, 255, 255);

    int fraglimit = g_iArenaFraglimit[arena_index];

    if (g_iArenaStatus[arena_index] != AS_IDLE)
    {
        if (fraglimit > 0)
            Format(report, sizeof(report), "Arena %s. Frag Limit(%d)", g_sArenaName[arena_index], fraglimit);
        else
            Format(report, sizeof(report), "Arena %s. No Frag Limit", g_sArenaName[arena_index]);
    }
    else
    {
        Format(report, sizeof(report), "Arena[%s]", g_sArenaName[arena_index]);
    }

    if (g_bFourPersonArena[arena_index])
    {
        if (red_f1)
        {
            if (red_f2)
            {
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n%N and %N : %d", report, red_f1, red_f2, g_iArenaScore[arena_index][SLOT_ONE]);
                else
                    Format(report, sizeof(report), "%s\n%N and %N (%d): %d", report, red_f1, red_f2, g_iPlayerRating[red_f1], g_iArenaScore[arena_index][SLOT_ONE]);
            }
            else
            {
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n%N : %d", report, red_f1, g_iArenaScore[arena_index][SLOT_ONE]);
                else
                    Format(report, sizeof(report), "%s\n%N (%d): %d", report, red_f1, g_iPlayerRating[red_f1], g_iArenaScore[arena_index][SLOT_ONE]);
            }


        }
        if (blu_f1)
        {
            if (blu_f2)
            {
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n%N and %N : %d", report, blu_f1, blu_f2, g_iArenaScore[arena_index][SLOT_TWO]);
                else
                    Format(report, sizeof(report), "%s\n%N and %N (%d): %d", report, blu_f1, blu_f2, g_iPlayerRating[blu_f1], g_iArenaScore[arena_index][SLOT_TWO]);
            }
            else
            {
                if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                    Format(report, sizeof(report), "%s\n%N : %d", report, blu_f1, g_iArenaScore[arena_index][SLOT_TWO]);
                else
                    Format(report, sizeof(report), "%s\n%N (%d): %d", report, blu_f1, g_iPlayerRating[blu_f1], g_iArenaScore[arena_index][SLOT_TWO]);
            }
        }
    }

    else
    {
        if (red_f1)
        {
            if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                Format(report, sizeof(report), "%s\n%N : %d", report, red_f1, g_iArenaScore[arena_index][SLOT_ONE]);
            else
                Format(report, sizeof(report), "%s\n%N (%d): %d", report, red_f1, g_iPlayerRating[red_f1], g_iArenaScore[arena_index][SLOT_ONE]);
        }

        if (blu_f1)
        {
            if (g_bNoStats || g_bNoDisplayRating || !g_bShowElo[client])
                Format(report, sizeof(report), "%s\n%N : %d", report, blu_f1, g_iArenaScore[arena_index][SLOT_TWO]);
            else
                Format(report, sizeof(report), "%s\n%N (%d): %d", report, blu_f1, g_iPlayerRating[blu_f1], g_iArenaScore[arena_index][SLOT_TWO]);
        }
    }

    ShowSyncHudText(client, hm_Score, "%s", report);
}

void ShowHudToAll()
{
    for (int i = 1; i <= g_iArenaCount; i++)
    {
        ShowSpecHudToArena(i);
    }

    for (int i = 1; i <= MAXPLAYERS; i++)
    {
        if (g_iPlayerArena[i])
        {
            ShowPlayerHud(i);
        }
    }
}

void HideHud(int client)
{
    if (!IsValidClient(client))
        return;

    ClearSyncHud(client, hm_Score);
    ClearSyncHud(client, hm_HP);
}

void SendArenaJoinMessage(const char[] playername, int player_rating, const char[] arena_name, bool show_elo)
{
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (!IsClientInGame(i))
            continue;
            
        if (show_elo && g_bShowElo[i])
            MC_PrintToChat(i, "%t", "JoinsArena", playername, player_rating, arena_name);
        else
            MC_PrintToChat(i, "%t", "JoinsArenaNoStats", playername, arena_name);
    }
}

// ====[ QUEUE ]====================================================
void RemoveFromQueue(int client, bool calcstats = false, bool specfix = false)
{
    int arena_index = g_iPlayerArena[client];

    if (arena_index == 0)
    {
        return;
    }

    int player_slot = g_iPlayerSlot[client];
    g_iPlayerArena[client] = 0;
    g_iPlayerSlot[client] = 0;
    g_iArenaQueue[arena_index][player_slot] = 0;
    g_iPlayerHandicap[client] = 0;

    if (IsValidClient(client) && GetClientTeam(client) != TEAM_SPEC)
    {
        ForcePlayerSuicide(client);
        ChangeClientTeam(client, TEAM_SPEC);

        if (specfix)
            CreateTimer(0.1, Timer_SpecFix, GetClientUserId(client));
    }

    int after_leaver_slot = player_slot + 1;

    //I beleive I don't need to do this anymore BUT
    //If the player was in the arena, and the timer was running, kill it
    if (((player_slot <= SLOT_TWO) || (g_bFourPersonArena[arena_index] && player_slot <= SLOT_FOUR)) && g_bTimerRunning[arena_index])
    {
        delete g_tKothTimer[arena_index];
        g_bTimerRunning[arena_index] = false;
    }

    if (g_bFourPersonArena[arena_index])
    {
        int foe_team_slot;
        int player_team_slot;

        if (player_slot <= SLOT_FOUR && player_slot > 0)
        {
            int foe_slot = (player_slot == SLOT_ONE || player_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
            int foe = g_iArenaQueue[arena_index][foe_slot];
            int player_teammate;
            int foe2;

            foe_team_slot = (foe_slot > 2) ? (foe_slot - 2) : foe_slot;
            player_team_slot = (player_slot > 2) ? (player_slot - 2) : player_slot;

            if (g_bFourPersonArena[arena_index])
            {
                player_teammate = getTeammate(player_slot, arena_index);
                foe2 = getTeammate(foe_slot, arena_index);

            }

            if (g_bArenaBBall[arena_index])
            {
                if (IsValidEdict(g_iBBallIntel[arena_index]) && g_iBBallIntel[arena_index] > 0)
                {
                    //SDKUnhook(g_iBBallIntel[arena_index], SDKHook_StartTouch, OnTouchIntel);
                    RemoveEdict(g_iBBallIntel[arena_index]);
                    g_iBBallIntel[arena_index] = -1;
                }

                RemoveClientParticle(client);
                g_bPlayerHasIntel[client] = false;

                if (foe)
                {
                    RemoveClientParticle(foe);
                    g_bPlayerHasIntel[foe] = false;
                }

                if (foe2)
                {
                    RemoveClientParticle(foe2);
                    g_bPlayerHasIntel[foe2] = false;
                }

                if (player_teammate)
                {
                    RemoveClientParticle(player_teammate);
                    g_bPlayerHasIntel[player_teammate] = false;
                }
            }

            if (g_iArenaStatus[arena_index] >= AS_FIGHT && g_iArenaStatus[arena_index] < AS_REPORTED && calcstats && !g_bNoStats && foe)
            {
                char foe_name[MAX_NAME_LENGTH * 2];
                char player_name[MAX_NAME_LENGTH * 2];
                char foe2_name[MAX_NAME_LENGTH];
                char player_teammate_name[MAX_NAME_LENGTH];

                GetClientName(foe, foe_name, sizeof(foe_name));
                GetClientName(client, player_name, sizeof(player_name));
                GetClientName(foe2, foe2_name, sizeof(foe2_name));
                GetClientName(player_teammate, player_teammate_name, sizeof(player_teammate_name));

                Format(foe_name, sizeof(foe_name), "%s and %s", foe_name, foe2_name);
                Format(player_name, sizeof(player_name), "%s and %s", player_name, player_teammate_name);

                g_iArenaStatus[arena_index] = AS_REPORTED;

                if (g_iArenaScore[arena_index][foe_team_slot] > g_iArenaScore[arena_index][player_team_slot])
                {
                    if (g_iArenaScore[arena_index][foe_team_slot] >= g_iArenaEarlyLeave[arena_index])
                    {
                        CalcELO(foe, client);
                        CalcELO(foe2, client);
                        MC_PrintToChatAll("%t", "XdefeatsYearly", foe_name, g_iArenaScore[arena_index][foe_team_slot], player_name, g_iArenaScore[arena_index][player_team_slot], g_sArenaName[arena_index]);
                    }
                }
            }

            if (g_iArenaQueue[arena_index][SLOT_FOUR + 1])
            {
                int next_client = g_iArenaQueue[arena_index][SLOT_FOUR + 1];
                g_iArenaQueue[arena_index][SLOT_FOUR + 1] = 0;
                g_iArenaQueue[arena_index][player_slot] = next_client;
                g_iPlayerSlot[next_client] = player_slot;
                after_leaver_slot = SLOT_FOUR + 2;
                char playername[MAX_NAME_LENGTH];
                CreateTimer(2.0, Timer_Restart2v2Ready, arena_index);
                GetClientName(next_client, playername, sizeof(playername));

                SendArenaJoinMessage(playername, g_iPlayerRating[next_client], g_sArenaName[arena_index], !g_bNoStats && !g_bNoDisplayRating && g_bShowElo[next_client]);
            } else {
                if (foe && IsFakeClient(foe))
                {
                    ConVar cvar = FindConVar("tf_bot_quota");
                    int quota = cvar.IntValue;
                    ServerCommand("tf_bot_quota %d", quota - 1);
                }

                if (g_bFourPersonArena[arena_index])
                {
                    Restore2v2WaitingSpectators(arena_index);
                    CreateTimer(3.0, Timer_Restart2v2Ready, arena_index);
                }

                g_iArenaStatus[arena_index] = AS_IDLE;
                return;
            }
        }
    }

    else
    {
        if (player_slot == SLOT_ONE || player_slot == SLOT_TWO)
        {
            int foe_slot = player_slot == SLOT_ONE ? SLOT_TWO : SLOT_ONE;
            int foe = g_iArenaQueue[arena_index][foe_slot];

            if (g_bArenaBBall[arena_index])
            {
                if (IsValidEdict(g_iBBallIntel[arena_index]) && g_iBBallIntel[arena_index] > 0)
                {
                    //SDKUnhook(g_iBBallIntel[arena_index], SDKHook_StartTouch, OnTouchIntel);
                    RemoveEdict(g_iBBallIntel[arena_index]);
                    g_iBBallIntel[arena_index] = -1;
                }

                RemoveClientParticle(client);
                g_bPlayerHasIntel[client] = false;

                if (foe)
                {
                    RemoveClientParticle(foe);
                    g_bPlayerHasIntel[foe] = false;
                }
            }

            if (g_iArenaStatus[arena_index] >= AS_FIGHT && g_iArenaStatus[arena_index] < AS_REPORTED && calcstats && !g_bNoStats && foe)
            {
                char foe_name[MAX_NAME_LENGTH];
                char player_name[MAX_NAME_LENGTH];
                GetClientName(foe, foe_name, sizeof(foe_name));
                GetClientName(client, player_name, sizeof(player_name));

                g_iArenaStatus[arena_index] = AS_REPORTED;

                if (g_iArenaScore[arena_index][foe_slot] > g_iArenaScore[arena_index][player_slot])
                {
                    if (g_iArenaScore[arena_index][foe_slot] >= g_iArenaEarlyLeave[arena_index])
                    {
                        CalcELO(foe, client);
                        MC_PrintToChatAll("%t", "XdefeatsYearly", foe_name, g_iArenaScore[arena_index][foe_slot], player_name, g_iArenaScore[arena_index][player_slot], g_sArenaName[arena_index]);
                    }
                }
            }

            if (g_iArenaQueue[arena_index][SLOT_TWO + 1])
            {
                int next_client = g_iArenaQueue[arena_index][SLOT_TWO + 1];
                g_iArenaQueue[arena_index][SLOT_TWO + 1] = 0;
                g_iArenaQueue[arena_index][player_slot] = next_client;
                g_iPlayerSlot[next_client] = player_slot;
                after_leaver_slot = SLOT_TWO + 2;
                char playername[MAX_NAME_LENGTH];
                CreateTimer(2.0, Timer_StartDuel, arena_index);
                GetClientName(next_client, playername, sizeof(playername));

                SendArenaJoinMessage(playername, g_iPlayerRating[next_client], g_sArenaName[arena_index], !g_bNoStats && !g_bNoDisplayRating && g_bShowElo[next_client]);
            } else {
                if (foe && IsFakeClient(foe))
                {
                    ConVar cvar = FindConVar("tf_bot_quota");
                    int quota = cvar.IntValue;
                    ServerCommand("tf_bot_quota %d", quota - 1);
                }

                g_iArenaStatus[arena_index] = AS_IDLE;
                return;
            }
        }
    }
    if (g_iArenaQueue[arena_index][after_leaver_slot])
    {
        while (g_iArenaQueue[arena_index][after_leaver_slot])
        {
            g_iArenaQueue[arena_index][after_leaver_slot - 1] = g_iArenaQueue[arena_index][after_leaver_slot];
            g_iPlayerSlot[g_iArenaQueue[arena_index][after_leaver_slot]] -= 1;
            after_leaver_slot++;
        }
        g_iArenaQueue[arena_index][after_leaver_slot - 1] = 0;
    }
    

}

void AddInQueue(int client, int arena_index, bool showmsg = true, int playerPrefTeam = 0, bool show2v2Menu = true)
{
    if (!IsValidClient(client))
        return;

    // Handle case where player is already in an arena
    if (g_iPlayerArena[client])
    {
        // If player is already in an arena, remove them before re-adding
        // This handles team switching and moving from queue to active slot
        if (g_iPlayerSlot[client] != 0)
        {
            g_iArenaQueue[g_iPlayerArena[client]][g_iPlayerSlot[client]] = 0;
        }

        if (g_iPlayerArena[client] == arena_index)
        {
            // Player is re-selecting the same arena
            if (g_bFourPersonArena[arena_index] && playerPrefTeam == 0 && show2v2Menu)
            {
                // Show 2v2 menu for team management
                Show2v2SelectionMenu(client, arena_index);
                return;
            }
            else if (show2v2Menu && playerPrefTeam == 0)
            {
                // Regular re-selection with no specific action, just show status
                MC_PrintToChat(client, "You are already in %s", g_sArenaName[arena_index]);
                return;
            }
            // If show2v2Menu=false or playerPrefTeam!=0, this is an intentional action
            // (like converting to 1v1 or switching teams), so continue processing
        }
        else
        {
            // Player is switching to a different arena, remove from current one
            RemoveFromQueue(client, true);
        }
    }

    // Show 2v2 selection menu if this is a 2v2 arena and no team preference is set
    // Only show menu if there are available main slots (not all 4 slots filled)
    if (g_bFourPersonArena[arena_index] && playerPrefTeam == 0 && show2v2Menu)
    {
        // Check if all main slots are filled
        bool allSlotsFilled = g_iArenaQueue[arena_index][SLOT_ONE] && 
                             g_iArenaQueue[arena_index][SLOT_TWO] && 
                             g_iArenaQueue[arena_index][SLOT_THREE] && 
                             g_iArenaQueue[arena_index][SLOT_FOUR];
        
        if (!allSlotsFilled)
        {
            // Temporarily set arena to allow menu to access it
            g_iPlayerArena[client] = arena_index;
            Show2v2SelectionMenu(client, arena_index);
            return;
        }
        // If all slots filled, continue to regular queue logic
    }

    // For 2v2 arenas, only respect team preference for active slots (team switching)
    // Queued players just join the first available slot regardless of team
    int player_slot = SLOT_ONE;
    if (g_bFourPersonArena[arena_index] && playerPrefTeam != 0)
    {
        // This is team switching for active players only
        if (playerPrefTeam == TEAM_RED)
        {
            // Try main RED slots first
            if (!g_iArenaQueue[arena_index][SLOT_ONE])
                player_slot = SLOT_ONE;
            else if (!g_iArenaQueue[arena_index][SLOT_THREE])
                player_slot = SLOT_THREE;
            else
            {
                // RED slots full, put in regular queue
                player_slot = SLOT_FOUR + 1;
                while (g_iArenaQueue[arena_index][player_slot])
                    player_slot++;
            }
        }
        else if (playerPrefTeam == TEAM_BLU)
        {
            // Try main BLU slots first  
            if (!g_iArenaQueue[arena_index][SLOT_TWO])
                player_slot = SLOT_TWO;
            else if (!g_iArenaQueue[arena_index][SLOT_FOUR])
                player_slot = SLOT_FOUR;
            else
            {
                // BLU slots full, put in regular queue
                player_slot = SLOT_FOUR + 1;
                while (g_iArenaQueue[arena_index][player_slot])
                    player_slot++;
            }
        }
    }
    else
    {
        // Regular queue assignment - find first available slot
        while (g_iArenaQueue[arena_index][player_slot])
            player_slot++;
    }

    g_iPlayerArena[client] = arena_index;
    g_iPlayerSlot[client] = player_slot;
    g_iArenaQueue[arena_index][player_slot] = client;

    SetPlayerToAllowedClass(client, arena_index);

    if (showmsg)
    {
        MC_PrintToChat(client, "%t", "ChoseArena", g_sArenaName[arena_index]);
    }
    if (g_bFourPersonArena[arena_index])
    {
        if (player_slot <= SLOT_FOUR)
        {
            char name[MAX_NAME_LENGTH];
            GetClientName(client, name, sizeof(name));

            SendArenaJoinMessage(name, g_iPlayerRating[client], g_sArenaName[arena_index], !g_bNoStats && !g_bNoDisplayRating && g_bShowElo[client]);

            // Check if we have exactly 2 players per team for 2v2 match
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
                // Transition to ready waiting state instead of immediately starting
                Start2v2ReadySystem(arena_index);
            }
            else
                CreateTimer(0.1, Timer_ResetPlayer, GetClientUserId(client));
        } else {
            if (GetClientTeam(client) != TEAM_SPEC)
                ChangeClientTeam(client, TEAM_SPEC);
            if (player_slot == SLOT_FOUR + 1)
                MC_PrintToChat(client, "%t", "NextInLine");
            else
                MC_PrintToChat(client, "%t", "InLine", player_slot - SLOT_FOUR);
        }
    }
    else
    {
        if (player_slot <= SLOT_TWO)
        {
            char name[MAX_NAME_LENGTH];
            GetClientName(client, name, sizeof(name));

            SendArenaJoinMessage(name, g_iPlayerRating[client], g_sArenaName[arena_index], !g_bNoStats && !g_bNoDisplayRating && g_bShowElo[client]);

            if (g_iArenaQueue[arena_index][SLOT_ONE] && g_iArenaQueue[arena_index][SLOT_TWO])
            {
                CreateTimer(1.5, Timer_StartDuel, arena_index);
            } else
                CreateTimer(0.1, Timer_ResetPlayer, GetClientUserId(client));
        } else {
            if (GetClientTeam(client) != TEAM_SPEC)
                ChangeClientTeam(client, TEAM_SPEC);
            if (player_slot == SLOT_TWO + 1)
                MC_PrintToChat(client, "%t", "NextInLine");
            else
                MC_PrintToChat(client, "%t", "InLine", player_slot - SLOT_TWO);
        }
    }



    return;
}

// ====[ STATS ]====================================================
void CalcELO(int winner, int loser)
{
    if (IsFakeClient(winner) || IsFakeClient(loser) || g_bNoStats)
        return;

    // Store previous ELO values before calculating new ones
    int winner_previous_elo = g_iPlayerRating[winner];
    int loser_previous_elo = g_iPlayerRating[loser];

    // ELO formula
    float El = 1 / (Pow(10.0, float((g_iPlayerRating[winner] - g_iPlayerRating[loser])) / 400) + 1);
    int k = (g_iPlayerRating[winner] >= 2400) ? 10 : 15;
    int winnerscore = RoundFloat(k * El);
    g_iPlayerRating[winner] += winnerscore;
    k = (g_iPlayerRating[loser] >= 2400) ? 10 : 15;
    int loserscore = RoundFloat(k * El);
    g_iPlayerRating[loser] -= loserscore;

    int arena_index = g_iPlayerArena[winner];
    int time = GetTime();
    char query[512], sCleanArenaname[128], sCleanMapName[128];

    g_DB.Escape(g_sArenaName[g_iPlayerArena[winner]], sCleanArenaname, sizeof(sCleanArenaname));
    g_DB.Escape(g_sMapName, sCleanMapName, sizeof(sCleanMapName));

    if (IsValidClient(winner) && !g_bNoDisplayRating && g_bShowElo[winner])
        MC_PrintToChat(winner, "%t", "GainedPoints", winnerscore);

    if (IsValidClient(loser) && !g_bNoDisplayRating && g_bShowElo[loser])
        MC_PrintToChat(loser, "%t", "LostPoints", loserscore);

    //This is necessary for when a player leaves a 2v2 arena that is almost done.
    //I don't want to penalize the player that doesn't leave, so only the winners/leavers ELO will be effected.
    int winner_team_slot = (g_iPlayerSlot[winner] > 2) ? (g_iPlayerSlot[winner] - 2) : g_iPlayerSlot[winner];
    int loser_team_slot = (g_iPlayerSlot[loser] > 2) ? (g_iPlayerSlot[loser] - 2) : g_iPlayerSlot[loser];

    // DB entry for this specific duel.
    char winnerClass[64], loserClass[64];
    GetPlayerClassString(winner, arena_index, winnerClass, sizeof(winnerClass));
    GetPlayerClassString(loser, arena_index, loserClass, sizeof(loserClass));
    
    int startTime = g_iArenaDuelStartTime[arena_index];
    int endTime = time;
    
    if (g_bUseSQLite)
    {
        Format(query, sizeof(query), "INSERT INTO mgemod_duels VALUES ('%s', '%s', %i, %i, %i, %i, '%s', '%s', '%s', '%s', %i, %i, %i, %i, %i)",
            g_sPlayerSteamID[winner], g_sPlayerSteamID[loser], g_iArenaScore[arena_index][winner_team_slot], g_iArenaScore[arena_index][loser_team_slot], g_iArenaFraglimit[arena_index], endTime, g_sMapName, g_sArenaName[arena_index], winnerClass, loserClass, startTime, winner_previous_elo, g_iPlayerRating[winner], loser_previous_elo, g_iPlayerRating[loser]);
        g_DB.Query(SQLErrorCheckCallback, query);
    } else {
        Format(query, sizeof(query), "INSERT INTO mgemod_duels (winner, loser, winnerscore, loserscore, winlimit, endtime, starttime, mapname, arenaname, winnerclass, loserclass, winner_previous_elo, winner_new_elo, loser_previous_elo, loser_new_elo) VALUES ('%s', '%s', %i, %i, %i, %i, %i, '%s', '%s', '%s', '%s', %i, %i, %i, %i)",
            g_sPlayerSteamID[winner], g_sPlayerSteamID[loser], g_iArenaScore[arena_index][winner_team_slot], g_iArenaScore[arena_index][loser_team_slot], g_iArenaFraglimit[arena_index], endTime, startTime, g_sMapName, g_sArenaName[arena_index], winnerClass, loserClass, winner_previous_elo, g_iPlayerRating[winner], loser_previous_elo, g_iPlayerRating[loser]);
        g_DB.Query(SQLErrorCheckCallback, query);
    }

    //winner's stats
    Format(query, sizeof(query), "UPDATE mgemod_stats SET rating=%i,wins=wins+1,lastplayed=%i WHERE steamid='%s'",
        g_iPlayerRating[winner], time, g_sPlayerSteamID[winner]);
    g_DB.Query(SQLErrorCheckCallback, query);

    //loser's stats
    Format(query, sizeof(query), "UPDATE mgemod_stats SET rating=%i,losses=losses+1,lastplayed=%i WHERE steamid='%s'",
        g_iPlayerRating[loser], time, g_sPlayerSteamID[loser]);
    g_DB.Query(SQLErrorCheckCallback, query);
}

void CalcELO2(int winner, int winner2, int loser, int loser2)
{
    if (IsFakeClient(winner) || IsFakeClient(loser) || g_bNoStats || IsFakeClient(loser2) || IsFakeClient(winner2))
        return;

    // Store previous ELO values before calculating new ones
    int winner_previous_elo = g_iPlayerRating[winner];
    int winner2_previous_elo = g_iPlayerRating[winner2];
    int loser_previous_elo = g_iPlayerRating[loser];
    int loser2_previous_elo = g_iPlayerRating[loser2];

    float Losers_ELO = float((g_iPlayerRating[loser] + g_iPlayerRating[loser2]) / 2);
    float Winners_ELO = float((g_iPlayerRating[winner] + g_iPlayerRating[winner2]) / 2);

    // ELO formula
    float El = 1 / (Pow(10.0, (Winners_ELO - Losers_ELO) / 400) + 1);
    int k = (Winners_ELO >= 2400) ? 10 : 15;
    int winnerscore = RoundFloat(k * El);
    g_iPlayerRating[winner] += winnerscore;
    g_iPlayerRating[winner2] += winnerscore;
    k = (Losers_ELO >= 2400) ? 10 : 15;
    int loserscore = RoundFloat(k * El);
    g_iPlayerRating[loser] -= loserscore;
    g_iPlayerRating[loser2] -= loserscore;

    int winner_team_slot = (g_iPlayerSlot[winner] > 2) ? (g_iPlayerSlot[winner] - 2) : g_iPlayerSlot[winner];
    int loser_team_slot = (g_iPlayerSlot[loser] > 2) ? (g_iPlayerSlot[loser] - 2) : g_iPlayerSlot[loser];

    int arena_index = g_iPlayerArena[winner];
    int time = GetTime();
    char query[512], sCleanArenaname[128], sCleanMapName[128];

    g_DB.Escape(g_sArenaName[g_iPlayerArena[winner]], sCleanArenaname, sizeof(sCleanArenaname));
    g_DB.Escape(g_sMapName, sCleanMapName, sizeof(sCleanMapName));

    if (IsValidClient(winner) && !g_bNoDisplayRating && g_bShowElo[winner])
        MC_PrintToChat(winner, "%t", "GainedPoints", winnerscore);

    if (IsValidClient(winner2) && !g_bNoDisplayRating && g_bShowElo[winner2])
        MC_PrintToChat(winner2, "%t", "GainedPoints", winnerscore);

    if (IsValidClient(loser) && !g_bNoDisplayRating && g_bShowElo[loser])
        MC_PrintToChat(loser, "%t", "LostPoints", loserscore);

    if (IsValidClient(loser2) && !g_bNoDisplayRating && g_bShowElo[loser2])
        MC_PrintToChat(loser2, "%t", "LostPoints", loserscore);


    // DB entry for this specific duel.
    char winnerClass[64], winner2Class[64], loserClass[64], loser2Class[64];
    GetPlayerClassString(winner, arena_index, winnerClass, sizeof(winnerClass));
    GetPlayerClassString(winner2, arena_index, winner2Class, sizeof(winner2Class));
    GetPlayerClassString(loser, arena_index, loserClass, sizeof(loserClass));
    GetPlayerClassString(loser2, arena_index, loser2Class, sizeof(loser2Class));
    
    int startTime = g_iArenaDuelStartTime[arena_index];
    int endTime = time;
    
    if (g_bUseSQLite)
    {
        Format(query, sizeof(query), "INSERT INTO mgemod_duels_2v2 VALUES ('%s', '%s', '%s', '%s', %i, %i, %i, %i, '%s', '%s', '%s', '%s', '%s', '%s', %i, %i, %i, %i, %i, %i, %i, %i, %i, %i)",
            g_sPlayerSteamID[winner], g_sPlayerSteamID[winner2], g_sPlayerSteamID[loser], g_sPlayerSteamID[loser2], g_iArenaScore[arena_index][winner_team_slot], g_iArenaScore[arena_index][loser_team_slot], g_iArenaFraglimit[arena_index], endTime, g_sMapName, g_sArenaName[arena_index], winnerClass, winner2Class, loserClass, loser2Class, startTime, winner_previous_elo, g_iPlayerRating[winner], winner2_previous_elo, g_iPlayerRating[winner2], loser_previous_elo, g_iPlayerRating[loser], loser2_previous_elo, g_iPlayerRating[loser2]);
        g_DB.Query(SQLErrorCheckCallback, query);
    } else {
        Format(query, sizeof(query), "INSERT INTO mgemod_duels_2v2 (winner, winner2, loser, loser2, winnerscore, loserscore, winlimit, endtime, starttime, mapname, arenaname, winnerclass, winner2class, loserclass, loser2class, winner_previous_elo, winner_new_elo, winner2_previous_elo, winner2_new_elo, loser_previous_elo, loser_new_elo, loser2_previous_elo, loser2_new_elo) VALUES ('%s', '%s', '%s', '%s', %i, %i, %i, %i, %i, '%s', '%s', '%s', '%s', '%s', '%s', %i, %i, %i, %i, %i, %i, %i, %i)",
            g_sPlayerSteamID[winner], g_sPlayerSteamID[winner2], g_sPlayerSteamID[loser], g_sPlayerSteamID[loser2], g_iArenaScore[arena_index][winner_team_slot], g_iArenaScore[arena_index][loser_team_slot], g_iArenaFraglimit[arena_index], endTime, startTime, g_sMapName, g_sArenaName[arena_index], winnerClass, winner2Class, loserClass, loser2Class, winner_previous_elo, g_iPlayerRating[winner], winner2_previous_elo, g_iPlayerRating[winner2], loser_previous_elo, g_iPlayerRating[loser], loser2_previous_elo, g_iPlayerRating[loser2]);
        g_DB.Query(SQLErrorCheckCallback, query);
    }

    //winner's stats
    Format(query, sizeof(query), "UPDATE mgemod_stats SET rating=%i,wins=wins+1,lastplayed=%i WHERE steamid='%s'",
        g_iPlayerRating[winner], time, g_sPlayerSteamID[winner]);
    g_DB.Query(SQLErrorCheckCallback, query);

    //winner's teammate stats
    Format(query, sizeof(query), "UPDATE mgemod_stats SET rating=%i,wins=wins+1,lastplayed=%i WHERE steamid='%s'",
        g_iPlayerRating[winner2], time, g_sPlayerSteamID[winner2]);
    g_DB.Query(SQLErrorCheckCallback, query);

    //loser's stats
    Format(query, sizeof(query), "UPDATE mgemod_stats SET rating=%i,losses=losses+1,lastplayed=%i WHERE steamid='%s'",
        g_iPlayerRating[loser], time, g_sPlayerSteamID[loser]);
    g_DB.Query(SQLErrorCheckCallback, query);

    //loser's teammate stats
    Format(query, sizeof(query), "UPDATE mgemod_stats SET rating=%i,losses=losses+1,lastplayed=%i WHERE steamid='%s'",
        g_iPlayerRating[loser2], time, g_sPlayerSteamID[loser2]);
    g_DB.Query(SQLErrorCheckCallback, query);
}
// ====[ UTIL ]====================================================
bool LoadSpawnPoints()
{
    char txtfile[256];
    GetCurrentMap(g_sMapName, sizeof(g_sMapName));

    //  "workshop/mge_training_v8_beta4b.ugc1996603816"
    if (StrContains(g_sMapName, "workshop/", false) != -1)
    {
        char nonWorkshopName[256];
        if (!GetMapDisplayName(g_sMapName, nonWorkshopName, sizeof(nonWorkshopName)))
        {
            LogError("Failed to convert workshop map name %s to pretty name! This map will probably not work!");
        }
        else
        {
            strcopy(g_sMapName, sizeof(g_sMapName), nonWorkshopName);
        }
    }

    // Build path to map-specific config file: configs/mge/{mapname}.cfg
    Format(txtfile, sizeof(txtfile), "configs/mge/%s.cfg", g_sMapName);
    BuildPath(Path_SM, txtfile, sizeof(txtfile), txtfile);

    KeyValues kv = new KeyValues("SpawnConfigs");

    char spawn[64];
    char spawnCo[6][16];
    int count;
    int i;
    g_iArenaCount = 0;

    for (int j = 0; j <= MAXARENAS; j++)
    {
        g_iArenaSpawns[j] = 0;
    }

    if (!kv.ImportFromFile(txtfile))
    {
        LogError("Error. Can't find cfg file: %s", txtfile);
        delete kv;
        return false;
    }
    
    if (!kv.GotoFirstSubKey())
    {
        LogError("Error in cfg file: %s", txtfile);
        delete kv;
        return false;
    }
    
    do
    {
        g_iArenaCount++;
        kv.GetSectionName(g_sArenaOriginalName[g_iArenaCount], 64);
        int id;
        if (kv.GetNameSymbol("1", id))
        {
            char intstr[4];
            char intstr2[4];
            do
            {
                g_iArenaSpawns[g_iArenaCount]++;
                IntToString(g_iArenaSpawns[g_iArenaCount], intstr, sizeof(intstr));
                IntToString(g_iArenaSpawns[g_iArenaCount]+1, intstr2, sizeof(intstr2));
                kv.GetString(intstr, spawn, sizeof(spawn));
                count = ExplodeString(spawn, " ", spawnCo, 6, 16);
                if (count==6)
                {
                    for (i=0; i<3; i++)
                    {
                        g_fArenaSpawnOrigin[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][i] = StringToFloat(spawnCo[i]);
                    }
                    for (i=3; i<6; i++)
                    {
                        g_fArenaSpawnAngles[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][i-3] = StringToFloat(spawnCo[i]);
                    }
                } else if(count==4) {
                    for (i=0; i<3; i++)
                    {
                        g_fArenaSpawnOrigin[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][i] = StringToFloat(spawnCo[i]);
                    }
                    g_fArenaSpawnAngles[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][0] = 0.0;
                    g_fArenaSpawnAngles[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][1] = StringToFloat(spawnCo[3]);
                    g_fArenaSpawnAngles[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][2] = 0.0;
                } else {
                    SetFailState("Error in cfg file. Wrong number of parameters (%d) on spawn <%i> in arena <%s>",count,g_iArenaSpawns[g_iArenaCount],g_sArenaOriginalName[g_iArenaCount]);
                }
            } while (kv.GetNameSymbol(intstr2, id));
        } else {
            LogError("Could not load spawns on arena %s.", g_sArenaOriginalName[g_iArenaCount]);
        }

        if (kv.GetNameSymbol("cap", id)) {
            kv.GetString("cap",  g_sArenaCap[g_iArenaCount], 64);
            g_bArenaHasCap[g_iArenaCount] = true;
        } else {
            g_bArenaHasCap[g_iArenaCount] = false;
        }

        if (kv.GetNameSymbol("cap_trigger", id)) {
            kv.GetString("cap_trigger",  g_sArenaCapTrigger[g_iArenaCount], 64);
            g_bArenaHasCapTrigger[g_iArenaCount] = true;
        }

        // Optional parameters
        g_iArenaMgelimit[g_iArenaCount] = kv.GetNum("fraglimit", g_iDefaultFragLimit);
        g_iArenaCaplimit[g_iArenaCount] = kv.GetNum("caplimit", g_iDefaultFragLimit);
        g_iArenaMinRating[g_iArenaCount] = kv.GetNum("minrating", -1);
        g_iArenaMaxRating[g_iArenaCount] = kv.GetNum("maxrating", -1);
        g_bArenaMidair[g_iArenaCount] = kv.GetNum("midair", 0) ? true : false;
        g_iArenaCdTime[g_iArenaCount] = kv.GetNum("cdtime", DEFAULT_CDTIME);
        g_bArenaMGE[g_iArenaCount] = kv.GetNum("mge", 0) ? true : false;
        g_fArenaHPRatio[g_iArenaCount] = kv.GetFloat("hpratio", 1.5);
        g_bArenaEndif[g_iArenaCount] = kv.GetNum("endif", 0) ? true : false;
        g_iArenaAirshotHeight[g_iArenaCount] = kv.GetNum("airshotheight", 250);
        g_bArenaBoostVectors[g_iArenaCount] = kv.GetNum("boostvectors", 0) ? true : false;
        g_bArenaBBall[g_iArenaCount] = kv.GetNum("bball", 0) ? true : false;
        g_bVisibleHoops[g_iArenaCount] = kv.GetNum("vishoop", 0) ? true : false;
        g_iArenaEarlyLeave[g_iArenaCount] = kv.GetNum("earlyleave", 0);
        g_bArenaInfAmmo[g_iArenaCount] = kv.GetNum("infammo", 1) ? true : false;
        g_bArenaShowHPToPlayers[g_iArenaCount] = kv.GetNum("showhp", 1) ? true : false;
        g_fArenaMinSpawnDist[g_iArenaCount] = kv.GetFloat("mindist", 100.0);
        g_bFourPersonArena[g_iArenaCount] = kv.GetNum("4player", 0) ? true : false;
        g_bArenaAllowChange[g_iArenaCount] = kv.GetNum("allowchange", 0) ? true : false;
        g_bArenaAllowKoth[g_iArenaCount] = kv.GetNum("allowkoth", 0) ? true : false;
        g_bArenaKothTeamSpawn[g_iArenaCount] = kv.GetNum("kothteamspawn", 0) ? true : false;
        g_fArenaRespawnTime[g_iArenaCount] = kv.GetFloat("respawntime", 0.1);
        g_bArenaAmmomod[g_iArenaCount] = kv.GetNum("ammomod", 0) ? true : false;
        g_bArenaUltiduo[g_iArenaCount] = kv.GetNum("ultiduo", 0) ? true : false;
        g_bArenaKoth[g_iArenaCount] = kv.GetNum("koth", 0) ? true : false;
        g_bArenaTurris[g_iArenaCount] = kv.GetNum("turris", 0) ? true : false;
        g_bArenaClassChange[g_iArenaCount] = kv.GetNum("classchange", 1) ? true : false;
        g_iDefaultCapTime[g_iArenaCount] = kv.GetNum("timer", 180);

        // Parsing allowed classes for current arena
        char sAllowedClasses[128];
        kv.GetString("classes", sAllowedClasses, sizeof(sAllowedClasses));
        ParseAllowedClasses(sAllowedClasses,g_tfctArenaAllowedClasses[g_iArenaCount]);
        g_iArenaFraglimit[g_iArenaCount] = g_iArenaMgelimit[g_iArenaCount];
        UpdateArenaName(g_iArenaCount);
    } while (kv.GotoNextKey());
    
    if (g_iArenaCount)
    {
        LogMessage("Loaded %d arenas from %s. MGEMod enabled.", g_iArenaCount, txtfile);
        delete kv;
        return true;
    } else {
        LogMessage("No arenas found in %s.", txtfile);
        delete kv;
        return false;
    }
}

int ResetPlayer(int client)
{
    int arena_index = g_iPlayerArena[client];
    int player_slot = g_iPlayerSlot[client];

    if (!arena_index || !player_slot)
    {
        return 0;
    }

    g_iPlayerSpecTarget[client] = 0;

    if (player_slot == SLOT_ONE || player_slot == SLOT_THREE)
        ChangeClientTeam(client, TEAM_RED);
    else
        ChangeClientTeam(client, TEAM_BLU);

    //This logic doesn't work with 2v2's
    //new team = GetClientTeam(client);
    //if (player_slot - team != SLOT_ONE - TEAM_RED)
    //  ChangeClientTeam(client, player_slot + TEAM_RED - SLOT_ONE);

    TFClassType class;
    class = g_tfctPlayerClass[client] ? g_tfctPlayerClass[client] : TFClass_Soldier;

    if (!IsPlayerAlive(client) || g_bArenaBBall[arena_index])
    {
        if (class != TF2_GetPlayerClass(client))
            TF2_SetPlayerClass(client, class);

        TF2_RespawnPlayer(client);
    } else {
        TF2_RegeneratePlayer(client);
        ExtinguishEntity(client);
    }

    g_iPlayerMaxHP[client] = GetEntProp(client, Prop_Data, "m_iMaxHealth");

    if (g_bArenaMidair[arena_index])
        g_iPlayerHP[client] = g_iMidairHP;
    else
        g_iPlayerHP[client] = g_iPlayerHandicap[client] ? g_iPlayerHandicap[client] : RoundToNearest(float(g_iPlayerMaxHP[client]) * g_fArenaHPRatio[arena_index]);

    if (g_bArenaMGE[arena_index] || g_bArenaBBall[arena_index])
        SetEntProp(client, Prop_Data, "m_iHealth", g_iPlayerHandicap[client] ? g_iPlayerHandicap[client] : RoundToNearest(float(g_iPlayerMaxHP[client]) * g_fArenaHPRatio[arena_index]));

    ShowPlayerHud(client);
    ResetClientAmmoCounts(client);
    CreateTimer(0.1, Timer_Tele, GetClientUserId(client));

    return 1;
}

void ResetKiller(int killer, int arena_index)
{
    int reset_hp = g_iPlayerHandicap[killer] ? g_iPlayerHandicap[killer] : RoundToNearest(float(g_iPlayerMaxHP[killer]) * g_fArenaHPRatio[arena_index]);
    g_iPlayerHP[killer] = reset_hp;
    SetEntProp(killer, Prop_Data, "m_iHealth", reset_hp);
    RequestFrame(RegenKiller, killer);
}

void ResetClientAmmoCounts(int client)
{
    // Crutch.
    g_iPlayerClip[client][SLOT_ONE] = -1;
    g_iPlayerClip[client][SLOT_TWO] = -1;

    // Check how much ammo each gun can hold in its clip and store it in a global variable so it can be set to that amount later.
    if (IsValidEntity(GetPlayerWeaponSlot(client, 0)))
        g_iPlayerClip[client][SLOT_ONE] = GetEntProp(GetPlayerWeaponSlot(client, 0), Prop_Data, "m_iClip1");
    if (IsValidEntity(GetPlayerWeaponSlot(client, 1)))
        g_iPlayerClip[client][SLOT_TWO] = GetEntProp(GetPlayerWeaponSlot(client, 1), Prop_Data, "m_iClip1");
}

void ResetIntel(int arena_index, any client = -1)
{
    if (g_bArenaBBall[arena_index])
    {
        if (IsValidEdict(g_iBBallIntel[arena_index]) && g_iBBallIntel[arena_index] > 0)
        {
            //SDKUnhook(g_iBBallIntel[arena_index], SDKHook_StartTouch, OnTouchIntel);
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

        //Should fix the intel being an ammopack
        DispatchKeyValue(g_iBBallIntel[arena_index], "powerup_model", MODEL_BRIEFCASE);
        DispatchSpawn(g_iBBallIntel[arena_index]);
        TeleportEntity(g_iBBallIntel[arena_index], intel_loc, NULL_VECTOR, NULL_VECTOR);
        SetEntProp(g_iBBallIntel[arena_index], Prop_Send, "m_iTeamNum", 1, 4);
        SetEntPropFloat(g_iBBallIntel[arena_index], Prop_Send, "m_flModelScale", 1.15);

        //Doesn't work anymore
        //SetEntityModel(g_iBBallIntel[arena_index], MODEL_BRIEFCASE);
        //SDKUnhook(g_iBBallIntel[arena_index], SDKHook_StartTouch, OnTouchIntel);
        SDKHook(g_iBBallIntel[arena_index], SDKHook_StartTouch, OnTouchIntel);
        AcceptEntityInput(g_iBBallIntel[arena_index], "Enable");
    }
}

void SetPlayerToAllowedClass(int client, int arena_index)
{  // If a player's class isn't allowed, set it to one that is.
    if (g_tfctPlayerClass[client] == TFClass_Unknown || !g_tfctArenaAllowedClasses[arena_index][g_tfctPlayerClass[client]])
    {
        for (int i = 1; i <= 9; i++)
        {
            if (g_tfctArenaAllowedClasses[arena_index][i])
            {
                if (g_bArenaUltiduo[arena_index] && g_bFourPersonArena[arena_index] && g_iPlayerSlot[client] > SLOT_TWO)
                {
                    int client_teammate = getTeammate(g_iPlayerSlot[client], arena_index);
                    if (view_as<TFClassType>(i) == g_tfctPlayerClass[client_teammate])
                    {
                        //Tell the player what he did wrong
                        MC_PrintToChat(client, "Your team already has that class!");
                        //Change him classes and set his class to the only one available
                        if (g_tfctPlayerClass[client_teammate] == TFClass_Soldier)
                        {
                            g_tfctPlayerClass[client] = TFClass_Medic;
                        }
                        else
                        {
                            g_tfctPlayerClass[client] = TFClass_Soldier;
                        }
                    }
                }
                else
                    g_tfctPlayerClass[client] = view_as<TFClassType>(i);

                break;
            }
        }
    }
}

void ParseAllowedClasses(const char[] sList, bool[] output)
{
    int count;
    char a_class[9][9];

    if (strlen(sList) > 0)
    {
        count = ExplodeString(sList, " ", a_class, 9, 9);
    } else {
        char sDefList[128];
        gcvar_allowedClasses.GetString(sDefList, sizeof(sDefList));
        count = ExplodeString(sDefList, " ", a_class, 9, 9);
    }

    for (int i = 1; i <= 9; i++) {
        output[i] = false;
    }

    for (int i = 0; i < count; i++)
    {
        TFClassType c = TF2_GetClass(a_class[i]);

        if (c)
            output[view_as<int>(c)] = true;
    }
}

// Particles ------------------------------------------------------------------

void AttachParticle(int ent, char[] particleType, int &particle) // Particle code borrowed from "The Amplifier" and "Presents!".
{
    particle = CreateEntityByName("info_particle_system");

    float pos[3];

    // Get position of entity
    GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);

    // Teleport, set up
    TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
    DispatchKeyValue(particle, "effect_name", particleType);

    SetVariantString("!activator");
    AcceptEntityInput(particle, "SetParent", ent, particle, 0);

    // All entities in presents are given a targetname to make clean up easier
    DispatchKeyValue(particle, "targetname", "tf2particle");

    // Spawn and start
    DispatchSpawn(particle);
    ActivateEntity(particle);
    AcceptEntityInput(particle, "Start");
}

void RemoveClientParticle(int client)
{
    int particle = EntRefToEntIndex(g_iClientParticle[client]);

    if (particle != 0 && IsValidEntity(particle))
        RemoveEdict(particle);

    g_iClientParticle[client] = 0;
}

// ====[ SWAP MENU ]=====================================================
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

// ====[ MAIN MENU ]====================================================
void ShowMainMenu(int client, bool listplayers = true)
{
    if (!IsValidClient(client))
        return;

    char title[128];
    char menu_item[128];

    Menu menu = new Menu(Menu_Main);

    Format(title, sizeof(title), "%T", "MenuTitle", client);
    menu.SetTitle(title);
    char si[4];

    for (int i = 1; i <= g_iArenaCount; i++)
    {
        int numslots = 0;
        for (int NUM = 1; NUM <= MAXPLAYERS + 1; NUM++)
        {
            if (g_iArenaQueue[i][NUM])
                numslots++;
            else
                break;
        }

        if (numslots > 2)
            Format(menu_item, sizeof(menu_item), "%s (2)(%d)", g_sArenaName[i], (numslots - 2));
        else if (numslots > 0)
            Format(menu_item, sizeof(menu_item), "%s (%d)", g_sArenaName[i], numslots);
        else
            Format(menu_item, sizeof(menu_item), "%s", g_sArenaName[i]);

        IntToString(i, si, sizeof(si));
        menu.AddItem(si, menu_item);
    }

    Format(menu_item, sizeof(menu_item), "%T", "MenuRemove", client);
    menu.AddItem("1000", menu_item);

    menu.ExitButton = true;
    menu.Display(client, 0);

    char report[128];

    //listing players
    if (!listplayers)
        return;

    for (int i = 1; i <= g_iArenaCount; i++)
    {
        int red_f1 = g_iArenaQueue[i][SLOT_ONE];
        int blu_f1 = g_iArenaQueue[i][SLOT_TWO];
        if (red_f1 > 0 || blu_f1 > 0)
        {
            Format(report, sizeof(report), "\x05%s:", g_sArenaName[i]);

            if (!g_bNoDisplayRating)
            {
                if (red_f1 > 0 && blu_f1 > 0)
                    Format(report, sizeof(report), "%s \x04%N \x03(%d) \x05vs \x04%N (%d) \x05", report, red_f1, g_iPlayerRating[red_f1], blu_f1, g_iPlayerRating[blu_f1]);
                else if (red_f1 > 0)
                    Format(report, sizeof(report), "%s \x04%N (%d)\x05", report, red_f1, g_iPlayerRating[red_f1]);
                else if (blu_f1 > 0)
                    Format(report, sizeof(report), "%s \x04%N (%d)\x05", report, blu_f1, g_iPlayerRating[blu_f1]);
            } else {
                if (red_f1 > 0 && blu_f1 > 0)
                    Format(report, sizeof(report), "%s \x04%N \x05vs \x04%N \x05", report, red_f1, blu_f1);
                else if (red_f1 > 0)
                    Format(report, sizeof(report), "%s \x04%N \x05", report, red_f1);
                else if (blu_f1 > 0)
                    Format(report, sizeof(report), "%s \x04%N \x05", report, blu_f1);
            }

            if (g_iArenaQueue[i][SLOT_TWO + 1])
            {
                Format(report, sizeof(report), "%s Waiting: ", report);
                int j = SLOT_TWO + 1;
                while (g_iArenaQueue[i][j + 1])
                {
                    Format(report, sizeof(report), "%s\x04%N \x05, ", report, g_iArenaQueue[i][j]);
                    j++;
                }
                Format(report, sizeof(report), "%s\x04%N", report, g_iArenaQueue[i][j]);
            }
            PrintToChat(client, "%s", report);
        }
    }
}

int Menu_Main(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            int client = param1;
            if (!client)return 0;
            char capt[32];
            char sanum[32];

            menu.GetItem(param2, sanum, sizeof(sanum), _, capt, sizeof(capt));
            int arena_index = StringToInt(sanum);

            if (arena_index > 0 && arena_index <= g_iArenaCount)
            {
                //checking rating (but allow re-selection of same arena)
                if (arena_index != g_iPlayerArena[client])
                {
                    int playerrating = g_iPlayerRating[client];
                    int minrating = g_iArenaMinRating[arena_index];
                    int maxrating = g_iArenaMaxRating[arena_index];

                    if (minrating > 0 && playerrating < minrating)
                    {
                        MC_PrintToChat(client, "%t", "LowRating", playerrating, minrating);
                        ShowMainMenu(client, false);
                        return 0;
                    } else if (maxrating > 0 && playerrating > maxrating) {
                        MC_PrintToChat(client, "%t", "HighRating", playerrating, maxrating);
                        ShowMainMenu(client, false);
                        return 0;
                    }
                }

                // Always call AddInQueue - it handles re-selection logic internally
                if (g_iPlayerArena[client] && arena_index != g_iPlayerArena[client])
                    RemoveFromQueue(client, true);

                AddInQueue(client, arena_index);

            } else {
                RemoveFromQueue(client, true);
            }
        }
        case MenuAction_Cancel:
        {
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }

    return 0;
}

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

void ShowTop5Menu(int client, char[][] name, int[] rating)
{
    if (!IsValidClient(client))
        return;

    char title[128];
    char temp[128];
    //char menu_item[128];

    Menu menu = new Menu(Menu_Top5);

    Format(title, sizeof(title), "ELO Rankings \n", client);

    char si[4];

    if (!g_bNoDisplayRating)
    {
        for (int i = 0; i < 5; i++)
        {
            int pos = (i + 1) + (g_iELOMenuPage[client] * 5);
            IntToString((i + 1), si, sizeof(si));
            //changed menu_item to title
            Format(temp, sizeof(temp), "%i %s (%i) \n", pos, name[i], rating[i]);
            StrCat(title, sizeof(title), temp);
            //menu.AddItem(si, menu_item);
        }
    } else {
        for (int i = 0; i < 5; i++)
        {
            int pos = (i + 1) + (g_iELOMenuPage[client] * 5);
            IntToString(i, si, sizeof(si));
            //changed menu_item to title
            Format(temp, sizeof(temp), "%i %s (%i) \n", pos, name[i], rating[i]);
            StrCat(title, sizeof(title), temp);
            //menu.AddItem(si, menu_item);
        }
    }
    menu.SetTitle(title);

    menu.AddItem("1", "Next");
    if (g_iELOMenuPage[client] != 0)
    {
        menu.AddItem("2", "back");
    }

    menu.ExitButton = true;
    menu.Display(client, 0);
}

int Menu_Top5(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[32];
            menu.GetItem(param2, info, sizeof(info));
            //If he selected next, query the next menu
            if (param2 == 0)
            {
                g_iELOMenuPage[param1]++;
                char query[256];
                Format(query, sizeof(query), "SELECT rating,name FROM mgemod_stats ORDER BY rating DESC LIMIT %i, 5", g_iELOMenuPage[param1] * 5);
                //new data[] = {param1, param2+5, false};
                g_DB.Query(T_SQL_Top5, query, param1);
            }
            //If the player selected back show the previous menu
            if (param2 == 1)
            {
                g_iELOMenuPage[param1]--;
                if (g_iELOMenuPage[param1] == 0)
                {
                    char query[256];
                    Format(query, sizeof(query), "SELECT rating,name FROM mgemod_stats ORDER BY rating DESC LIMIT 5");
                    //new data[] = {param1, param2-5, true};
                    g_DB.Query(T_SQL_Top5, query, param1);
                }
                else
                {
                    char query[256];
                    Format(query, sizeof(query), "SELECT rating,name FROM mgemod_stats ORDER BY rating DESC LIMIT %i, 5", g_iELOMenuPage[param1] * 5);
                    //new data[] = {param1, param2-5, false};
                    g_DB.Query(T_SQL_Top5, query, param1);
                }
            }
        }
        case MenuAction_Cancel:
        {
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }

    return 0;
}

// ====[ 2V2 SELECTION MENU ]============================================
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
    
    int total_players = red_count + blu_count;

    // Option 1: Join normally and switch arena to 1v1 (only if logical)
    bool can_convert_to_1v1 = false;
    char disable_reason[64];
    
    if (already_in_arena)
    {
        // Player is already in arena - use existing logic
        if (total_players <= 1)
        {
            // 0-1 players: Can convert (waiting for opponent)
            can_convert_to_1v1 = true;
        }
        else if (total_players == 2 && red_count == 1 && blu_count == 1)
        {
            // Exactly 2 players on opposite teams: Perfect for 1v1
            can_convert_to_1v1 = true;
        }
        else if (total_players == 2)
        {
            // 2 players on same team: Doesn't make sense for 1v1
            Format(disable_reason, sizeof(disable_reason), "disabled - both players on same team");
        }
        else
        {
            // 3+ players: Too many for 1v1
            Format(disable_reason, sizeof(disable_reason), "disabled - %d players in arena", total_players);
        }
    }
    else
    {
        // Player is NOT in arena - allow 1v1 conversion if arena is empty or has exactly 1 player
        if (total_players == 0)
        {
            can_convert_to_1v1 = true;
        }
        else if (total_players == 1)
        {
            // 1 player in arena: Perfect for joining and converting to 1v1
            can_convert_to_1v1 = true;
        }
        else
        {
            Format(disable_reason, sizeof(disable_reason), "disabled - arena not empty", total_players);
        }
    }
    
    if (can_convert_to_1v1)
    {
        Format(menu_item, sizeof(menu_item), "Join normally and switch arena to 1v1");
        menu.AddItem("1", menu_item);
    }
    else
    {
        Format(menu_item, sizeof(menu_item), "Switch to 1v1 (%s)", disable_reason);
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

int Menu_2v2Selection(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            int client = param1;
            char info[32];
            menu.GetItem(param2, info, sizeof(info));
            
            // Get arena index from stored data or player context
            int arena_index = g_iPlayerArena[client]; // Should be set when showing menu
            
            if (StringToInt(info) == 1)
            {
                // Safety check: Only allow 1v1 conversion if logical
                int red_count = 0, blu_count = 0;
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
                
                int total_players = red_count + blu_count;
                bool can_convert = false;
                
                // Check if player is already in this arena
                int current_slot = g_iPlayerSlot[client];
                bool already_in_arena = (g_iPlayerArena[client] == arena_index && current_slot >= SLOT_ONE && current_slot <= SLOT_FOUR);
                
                if (already_in_arena)
                {
                    // Player is already in arena - use existing logic
                    if (total_players <= 1)
                    {
                        can_convert = true; // Waiting for opponent
                    }
                    else if (total_players == 2 && red_count == 1 && blu_count == 1)
                    {
                        can_convert = true; // Perfect 1v1 setup
                    }
                }
                else
                {
                    // Player is NOT in arena - allow 1v1 conversion if arena is empty or has exactly 1 player
                    if (total_players == 0)
                    {
                        can_convert = true;
                    }
                    else if (total_players == 1)
                    {
                        // 1 player in arena: Perfect for joining and converting to 1v1
                        can_convert = true;
                    }
                }
                
                if (!can_convert)
                {
                    if (already_in_arena)
                    {
                        if (total_players == 2)
                            PrintToChat(client, "Cannot convert to 1v1 - both players on same team");
                        else
                            PrintToChat(client, "Cannot convert to 1v1 - too many players (%d)", total_players);
                    }
                    else
                    {
                        if (total_players == 1)
                            PrintToChat(client, "Cannot convert to 1v1 - arena has 1 player but you are not in arena");
                        else
                            PrintToChat(client, "Cannot convert to 1v1 - arena not empty (%d players)", total_players);
                    }
                    return 0;
                }
                
                // Switch arena to 1v1 (same logic as !1v1 command)
                g_bFourPersonArena[arena_index] = false;
                g_iArenaCdTime[arena_index] = DEFAULT_CDTIME;
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
            }
            else if (StringToInt(info) == 2)
            {
                // Join RED team
                Handle2v2TeamSwitchFromMenu(client, arena_index, TEAM_RED);
            }
            else if (StringToInt(info) == 3)
            {
                // Join BLU team
                Handle2v2TeamSwitchFromMenu(client, arena_index, TEAM_BLU);
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

// ====[ 2V2 READY SYSTEM ]==============================================
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
}

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

            char name[MAX_NAME_LENGTH];
            GetClientName(client, name, sizeof(name));
            
            if (ready)
            {
                PrintToChatArena(arena_index, "%s is ready!", name);
            }
            else
            {
                PrintToChatArena(arena_index, "%s is not ready.", name);
            }

            Update2v2ReadyStatus(arena_index);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }

    return 0;
}

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
        PrintToChatArena(arena_index, "Ready status: %d/4 players ready", ready_count);
        
        if (ready_count == 4)
        {
            // All players ready, start the match
            PrintToChatArena(arena_index, "All players ready! Starting match...");
            CreateTimer(1.5, Timer_StartDuel, arena_index);
        }
    }
}

void PrintToChatArena(int arena_index, const char[] message, any ...)
{
    char buffer[256];
    VFormat(buffer, sizeof(buffer), message, 3);
    
    for (int i = SLOT_ONE; i <= SLOT_FOUR; i++)
    {
        int client = g_iArenaQueue[arena_index][i];
        if (client)
        {
            PrintToChat(client, buffer);
        }
    }
    
    // Also show to spectators in this arena
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && GetClientTeam(i) == TEAM_SPEC && 
            g_iPlayerSpecTarget[i] > 0 && g_iPlayerArena[g_iPlayerSpecTarget[i]] == arena_index)
        {
            PrintToChat(i, buffer);
        }
    }
}

Action Timer_ShowReadyMenu(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client)
    {
        Show2v2ReadyMenu(client);
    }
    return Plugin_Continue;
}

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
        g_iArenaStatus[arena_index] = AS_IDLE;
        // Still restore any parked spectators in case teams refill
        Restore2v2WaitingSpectators(arena_index);
        ResetArena(arena_index);
    }

    return Plugin_Continue;
}

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
    

}

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
            g_iArenaStatus[arena_index] = AS_IDLE;
            if (g_bFourPersonArena[arena_index])
            {
                Restore2v2WaitingSpectators(arena_index);
            }
            PrintToChatArena(arena_index, "Team balance lost (RED: %d, BLU: %d). Need exactly 2 players per team.", red_count, blu_count);
        }
    }
}



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

// ====[ ENDIF ]====================================================
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



// ====[ CVARS ]====================================================
// i think this shit needs a switch case rewrite

void handler_ConVarChange(Handle convar, const char[] oldValue, const char[] newValue)
{
    if (convar == gcvar_blockFallDamage) {
        StringToInt(newValue) ? (g_bBlockFallDamage = true) : (g_bBlockFallDamage = false);
        if (g_bBlockFallDamage)
            AddNormalSoundHook(sound_hook);
        else
            RemoveNormalSoundHook(sound_hook);
    }
    else if (convar == gcvar_fragLimit)
        g_iDefaultFragLimit = StringToInt(newValue);
    else if (convar == gcvar_airshotHeight)
        g_iAirshotHeight = StringToInt(newValue);
    else if (convar == gcvar_midairHP)
        g_iMidairHP = StringToInt(newValue);
    else if (convar == gcvar_RocketForceX)
        g_fRocketForceX = StringToFloat(newValue);
    else if (convar == gcvar_RocketForceY)
        g_fRocketForceY = StringToFloat(newValue);
    else if (convar == gcvar_RocketForceZ)
        g_fRocketForceZ = StringToFloat(newValue);
    else if (convar == gcvar_autoCvar)
        StringToInt(newValue) ? (g_bAutoCvar = true) : (g_bAutoCvar = false);
    else if (convar == gcvar_bballParticle_red)
        strcopy(g_sBBallParticleRed, sizeof(g_sBBallParticleRed), newValue);
    else if (convar == gcvar_bballParticle_blue)
        strcopy(g_sBBallParticleBlue, sizeof(g_sBBallParticleBlue), newValue);
    else if (convar == gcvar_noDisplayRating)
        StringToInt(newValue) ? (g_bNoDisplayRating = true) : (g_bNoDisplayRating = false);
    else if (convar == gcvar_stats)
        g_bNoStats = gcvar_stats.BoolValue ? false : true;
    else if (convar == gcvar_reconnectInterval)
        g_iReconnectInterval = StringToInt(newValue);
    else if (convar == gcvar_dbConfig)
        strcopy(g_sDBConfig, sizeof(g_sDBConfig), newValue);
    else if (convar == gcvar_2v2SkipCountdown)
        StringToInt(newValue) ? (g_b2v2SkipCountdown = true) : (g_b2v2SkipCountdown = false);

}

// ====[ COMMANDS ]====================================================
Action Command_Menu(int client, int args)
{
    //handle commands "!ammomod" "!add" and such //building queue's menu and listing arena's
    int playerPrefTeam = 0;

    if (!IsValidClient(client))
        return Plugin_Continue;

    char sArg[32];
    if (GetCmdArg(1, sArg, sizeof(sArg)) > 0)
    {
        //If they want to add to a color
        char cArg[32];
        if (GetCmdArg(2, cArg, sizeof(cArg)) > 0)
        {
            if (StrContains("blu", cArg, false) >= 0)
            {
                playerPrefTeam = TEAM_BLU;
            }
            else if (StrContains("red", cArg, false) >= 0)
            {
                playerPrefTeam = TEAM_RED;
            }
        }
        // Was the argument an arena_index number?
        int iArg = StringToInt(sArg);
        if (iArg > 0 && iArg <= g_iArenaCount)
        {
            // Always call AddInQueue - it will handle re-selection logic internally
            // This allows 2v2 menu to show when re-selecting same arena
            if (g_iPlayerArena[client] && g_iPlayerArena[client] != iArg)
                RemoveFromQueue(client, true);

            AddInQueue(client, iArg, true, playerPrefTeam);
            return Plugin_Handled;
        }

        // Was the argument an arena name?
        GetCmdArgString(sArg, sizeof(sArg));
        int found_arena;
        for(int i = 1; i <= g_iArenaCount; i++)
        {
            if(StrContains(g_sArenaName[i], sArg, false) >= 0)
            {
                if (g_iArenaStatus[i] == AS_IDLE) {
                    found_arena = i;
                    break;
                }
            }
        }
        // If there was only one string match, and it was a valid match, place the player in that arena if they aren't already in it.
        if (found_arena > 0 && found_arena <= g_iArenaCount && found_arena != g_iPlayerArena[client])
        {
            if (g_iPlayerArena[client])
                RemoveFromQueue(client, true);

            AddInQueue(client, found_arena, true, playerPrefTeam);
            return Plugin_Handled;
        }


    }

    // Couldn't find a matching arena for the argument.
    ShowMainMenu(client);
    return Plugin_Handled;
}

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

Action Command_Top5(int client, int args)
{
    if (g_bNoStats || !IsValidClient(client))
    {
        PrintToChat(client, "No Stats is true");
        return Plugin_Continue;
    }

    g_iELOMenuPage[client] = 0;
    char query[256];
    Format(query, sizeof(query), "SELECT rating,name FROM mgemod_stats ORDER BY rating DESC LIMIT 5");
    g_DB.Query(T_SQL_Top5, query, client);
    return Plugin_Continue;
}

Action Command_Remove(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Continue;

    RemoveFromQueue(client, true);
    return Plugin_Handled;
}

Action Command_Ready(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Continue;

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

    char name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));
    
    if (g_bPlayer2v2Ready[client])
    {
        PrintToChatArena(arena_index, "%s is ready!", name);
    }
    else
    {
        PrintToChatArena(arena_index, "%s is not ready.", name);
    }

    Update2v2ReadyStatus(arena_index);
    return Plugin_Handled;
}

Action Command_AutoTeam(int client, int args)
{
    // Block autoteam command usage, and show add menu instead
    if (!IsValidClient(client))
        return Plugin_Continue;
    
    if (TF2_GetClientTeam(client) == TFTeam_Spectator)
    {
        ShowMainMenu(client);
    }
    return Plugin_Stop;
}

Action Command_JoinTeam(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Continue;

    // Get the team argument
    char team[16];
    GetCmdArg(1, team, sizeof(team));

    // Allow spectate command to pass through
    if (!strcmp(team, "spectate"))
    {
        // Handle spectating in arenas - treat as !remove for any arena type
        int arena_index = g_iPlayerArena[client];
        if (arena_index > 0)
        {
            // For any arena (1v1 or 2v2), going to spec means they want to leave
            MC_PrintToChat(client, "%t", "SpecRemove");
            RemoveFromQueue(client, true);
        }

        // Handle spectator HUD and target logic (moved from Event_PlayerTeam)
        HideHud(client);
        CreateTimer(1.0, Timer_ChangeSpecTarget, GetClientUserId(client));

        return Plugin_Continue;
    }
    else
    {
        // Check if player is in a 2v2 arena and trying to switch teams
        int arena_index = g_iPlayerArena[client];
        TFTeam currentTeam = TF2_GetClientTeam(client);

        if (arena_index > 0 && g_bFourPersonArena[arena_index] &&
            currentTeam != TFTeam_Spectator && currentTeam != TFTeam_Unassigned)
        {
            // Player is in a 2v2 arena - allow team switching
            int target_team = 0;
            if (!strcmp(team, "red"))
                target_team = TEAM_RED;
            else if (!strcmp(team, "blue") || !strcmp(team, "blu"))
                target_team = TEAM_BLU;

            if (target_team != 0)
            {
                // Use existing 2v2 team switch logic
                Handle2v2TeamSwitch(client, arena_index, target_team);
                return Plugin_Stop;
            }
        }

        // Block manual team joining for red/blue teams (default behavior)
        if (currentTeam == TFTeam_Spectator)
        {
            ShowMainMenu(client);
        }
        else
        {
            // Warn players who are already on a team that they can't manually switch
            MC_PrintToChat(client, "You cannot manually join teams. Use !add to join an arena or !remove to leave.");

            // Spawn exploit prevention (moved from Event_PlayerTeam)
            if (arena_index == 0)
            {
                TF2_SetPlayerClass(client, view_as<TFClassType>(0));
            }
        }
        return Plugin_Stop;
    }
}

Action Command_JoinClass(int client, int args)
{
    if (!IsValidClient(client))
    {
        return Plugin_Continue;
    }

    if (args)
    {
        int arena_index = g_iPlayerArena[client];
        int client_teammate;
        if (g_bFourPersonArena[arena_index])
        {
            client_teammate = getTeammate(g_iPlayerSlot[client], arena_index);
        }
        char s_class[64];
        GetCmdArg(1, s_class, sizeof(s_class));
        TFClassType new_class = TF2_GetClass(s_class);

        if (new_class == g_tfctPlayerClass[client])
        {
            return Plugin_Handled;
        }

        if (arena_index == 0) // if client is on arena
        {
            if (!g_tfctClassAllowed[view_as<int>(new_class)]) // checking global class restrctions
            {
                MC_PrintToChat(client, "%t", "ClassIsNotAllowed");
                return Plugin_Handled;
            } else {
                //if its ultiduo and a 4 man arena
                if (g_bArenaUltiduo[arena_index] && g_bFourPersonArena[arena_index])
                {
                    //and you try to join as the same class as your teammate
                    if (new_class == g_tfctPlayerClass[client_teammate])
                    {
                        //Tell the player what he did wrong
                        MC_PrintToChat(client, "Your team already has that class!");
                        return Plugin_Handled;
                    }
                    else
                    {
                        TF2_SetPlayerClass(client, new_class);
                        g_tfctPlayerClass[client] = new_class;

                    }
                }
                else
                {
                    TF2_SetPlayerClass(client, new_class);
                    g_tfctPlayerClass[client] = new_class;

                }
                ChangeClientTeam(client, TEAM_SPEC);
                ShowSpecHudToArena(g_iPlayerArena[client]);
            }
        }
        else
        {
            if (!g_tfctArenaAllowedClasses[arena_index][new_class])
            {
                MC_PrintToChat(client, "%t", "ClassIsNotAllowed");
                return Plugin_Handled;
            }

            //if its ultiduo and a 4 man arena
            if (g_bArenaUltiduo[arena_index] && g_bFourPersonArena[arena_index])
            {
                //and you try to join as the same class as your teammate
                if (new_class == g_tfctPlayerClass[client_teammate])
                {
                    //Tell the player what he did wrong
                    MC_PrintToChat(client, "Your team already has that class!");
                    return Plugin_Handled;
                }
                else
                {
                    TF2_SetPlayerClass(client, new_class);
                    g_tfctPlayerClass[client] = new_class;
                }
            }


            if (g_iPlayerSlot[client] == SLOT_ONE || g_iPlayerSlot[client] == SLOT_TWO || (g_bFourPersonArena[arena_index] && (g_iPlayerSlot[client] == SLOT_FOUR || g_iPlayerSlot[client] == SLOT_THREE)))
            {
                // Special 2v2 class change rules
                if (g_bFourPersonArena[arena_index])
                {
                    if (!g_bArenaClassChange[arena_index])
                    {
                        // Class changes only allowed during waiting phase
                        if (g_iArenaStatus[arena_index] != AS_WAITING_READY && g_iArenaStatus[arena_index] != AS_IDLE)
                        {
                            MC_PrintToChat(client, "Class changes are only allowed while waiting for 2v2 match to start!");
                            return Plugin_Handled;
                        }
                    }
                    else
                    {
                        // Class changes allowed during countdown, but slay during fight
                        if (g_iArenaStatus[arena_index] == AS_FIGHT)
                        {
                            MC_PrintToChat(client, "Class change during fight! You will be slayed and respawn next round.");
                            ForcePlayerSuicide(client);
                            TF2_SetPlayerClass(client, new_class);
                            g_tfctPlayerClass[client] = new_class;
                            return Plugin_Handled;
                        }
                    }
                }
                else
                {
                    // Original logic for 1v1 arenas
                    // Check if arena has class change disabled and fight has started
                    // Allow class changes if score is still 0-0, even during fight
                    if (!g_bArenaClassChange[arena_index] && g_iArenaStatus[arena_index] == AS_FIGHT && 
                        (g_iArenaScore[arena_index][SLOT_ONE] != 0 || g_iArenaScore[arena_index][SLOT_TWO] != 0))
                    {
                        MC_PrintToChat(client, "Class changes are disabled during fights in this arena!");
                        return Plugin_Handled;
                    }
                }
                
                if (g_iArenaStatus[arena_index] != AS_FIGHT || g_bArenaMGE[arena_index] || g_bArenaEndif[arena_index] || g_bArenaKoth[arena_index])
                {
                    TF2_SetPlayerClass(client, new_class);
                    g_tfctPlayerClass[client] = new_class;
                    
                    // Add class to tracking list if class changes are allowed and duel is active
                    if (g_bArenaClassChange[arena_index] && g_iArenaStatus[arena_index] != AS_IDLE && 
                        g_alPlayerDuelClasses[client].FindValue(view_as<int>(new_class)) == -1)
                    {
                        g_alPlayerDuelClasses[client].Push(view_as<int>(new_class));
                    }
                    if (IsPlayerAlive(client))
                    {
                        if ((g_iArenaStatus[arena_index] == AS_FIGHT && g_bArenaMGE[arena_index] || g_bArenaEndif[arena_index]))
                        {
                            int killer_slot = (g_iPlayerSlot[client] == SLOT_ONE || g_iPlayerSlot[client] == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
                            int fraglimit = g_iArenaFraglimit[arena_index];
                            int killer = g_iArenaQueue[arena_index][killer_slot];
                            int killer_teammate;
                            int killer_team_slot = (killer_slot > 2) ? (killer_slot - 2) : killer_slot;
                            int client_team_slot = (g_iPlayerSlot[client] > 2) ? (g_iPlayerSlot[client] - 2) : g_iPlayerSlot[client];

                            if (g_bFourPersonArena[arena_index])
                            {
                                killer_teammate = getTeammate(killer_slot, arena_index);
                            }
                            if (g_iArenaStatus[arena_index] == AS_FIGHT && killer)
                            {
                                // Only award points on class change if arena allows class changes
                                if (g_bArenaClassChange[arena_index])
                                {
                                    g_iArenaScore[arena_index][killer_team_slot] += 1;
                                    MC_PrintToChat(killer, "%t", "ClassChangePointOpponent");
                                    MC_PrintToChat(client, "%t", "ClassChangePoint");
                                }

                                if (g_bFourPersonArena[arena_index] && killer_teammate)
                                {
                                    CreateTimer(3.0, Timer_NewRound, arena_index);
                                }
                            }

                            ShowPlayerHud(client);

                            if (IsValidClient(killer))
                            {
                                ResetKiller(killer, arena_index);
                                ShowPlayerHud(killer);
                            }

                            if (g_bFourPersonArena[arena_index])
                            {
                                if (IsValidClient(killer_teammate))
                                {
                                    ResetKiller(killer_teammate, arena_index);
                                    ShowPlayerHud(killer_teammate);
                                }
                                if (IsValidClient(client_teammate))
                                {
                                    ResetKiller(client_teammate, arena_index);
                                    ShowPlayerHud(client_teammate);
                                }
                            }

                            if (g_iArenaStatus[arena_index] == AS_FIGHT && fraglimit > 0 && g_iArenaScore[arena_index][killer_team_slot] >= fraglimit)
                            {
                                char killer_name[(MAX_NAME_LENGTH * 2) + 5];
                                char victim_name[(MAX_NAME_LENGTH * 2) + 5];
                                GetClientName(killer, killer_name, sizeof(killer_name));
                                GetClientName(client, victim_name, sizeof(victim_name));
                                if (g_bFourPersonArena[arena_index])
                                {
                                    char killer_teammate_name[MAX_NAME_LENGTH];
                                    char victim_teammate_name[MAX_NAME_LENGTH];

                                    GetClientName(killer_teammate, killer_teammate_name, sizeof(killer_teammate_name));
                                    GetClientName(client_teammate, victim_teammate_name, sizeof(victim_teammate_name));

                                    Format(killer_name, sizeof(killer_name), "%s and %s", killer_name, killer_teammate_name);
                                    Format(victim_name, sizeof(victim_name), "%s and %s", victim_name, victim_teammate_name);
                                }
                                MC_PrintToChatAll("%t", "XdefeatsY", killer_name, g_iArenaScore[arena_index][killer_team_slot], victim_name, g_iArenaScore[arena_index][client_team_slot], fraglimit, g_sArenaName[arena_index]);

                                g_iArenaStatus[arena_index] = AS_REPORTED;

                                if (!g_bNoStats && g_bFourPersonArena[arena_index]/* && !g_arenaNoStats[arena_index]*/)
                                    CalcELO2(killer, killer_teammate, client, client_teammate);
                                else
                                    CalcELO(killer, client);
                                if (g_bFourPersonArena[arena_index] && g_iArenaQueue[arena_index][SLOT_FOUR + 1])
                                {
                                    RemoveFromQueue(client, false);
                                    AddInQueue(client, arena_index, false, 0, false);

                                    RemoveFromQueue(client_teammate, false);
                                    AddInQueue(client_teammate, arena_index, false, 0, false);
                                }
                                else if (g_iArenaQueue[arena_index][SLOT_TWO + 1])
                                {
                                    RemoveFromQueue(client, false);
                                    AddInQueue(client, arena_index, false, 0, false);
                                }
                                else
                                {
                                    // For 2v2 arenas, return to ready state instead of restarting immediately
                                    if (g_bFourPersonArena[arena_index])
                                    {
                                        CreateTimer(3.0, Timer_Restart2v2Ready, arena_index);
                                    }
                                    else
                                    {
                                        CreateTimer(3.0, Timer_StartDuel, arena_index);
                                    }
                                }
                            }


                        }

                        CreateTimer(0.1, Timer_ResetPlayer, GetClientUserId(client));
                    }
                    //Reset Handicap on class change to prevent an exploit where players could set their handicap to 299 as soldier
                    //And then play scout as 299
                    g_iPlayerHandicap[client] = 0;
                    ShowSpecHudToArena(g_iPlayerArena[client]);
                    return Plugin_Continue;
                }
                else
                {
                    MC_PrintToChat(client, "%t", "NoClassChange");
                    return Plugin_Handled;
                }
            }
            else
            {
                g_tfctPlayerClass[client] = new_class;
                ChangeClientTeam(client, TEAM_SPEC);
            }
        }
    }

    return Plugin_Handled;
}

Action Command_OneVsOne(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Continue;

    int arena_index = g_iPlayerArena[client];
    //new player_slot = g_iPlayerSlot[client];

    if (!arena_index) {
        PrintToChat(client, "You are not in an arena!");
        return Plugin_Continue;
    }

    if (!g_bFourPersonArena[arena_index]) {
        PrintToChat(client, "This arena is already in 1v1 mode!");
        return Plugin_Continue;
    }

    if (!g_bArenaAllowChange[arena_index]) {
        PrintToChat(client, "Cannot change to 1v1 in this arena!");
        return Plugin_Continue;
    }

    if (g_iArenaStatus[arena_index] != AS_IDLE) {
        PrintToChat(client, "Cannot switch to 1v1 now!");
        return Plugin_Continue;
    }

    if(g_iArenaQueue[arena_index][SLOT_THREE] || g_iArenaQueue[arena_index][SLOT_FOUR]) {
        PrintToChat(client, "There are more then 2 players in this arena");
        return Plugin_Continue;
    }

    g_bFourPersonArena[arena_index] = false;
    g_iArenaCdTime[arena_index] = DEFAULT_CDTIME;
    CreateTimer(1.5, Timer_StartDuel, arena_index);
    UpdateArenaName(arena_index);

    if(g_iArenaQueue[arena_index][SLOT_ONE]) {
        PrintToChat(g_iArenaQueue[arena_index][SLOT_ONE], "Changed current arena to 1v1 arena!");
    }

    if(g_iArenaQueue[arena_index][SLOT_TWO]) {
        PrintToChat(g_iArenaQueue[arena_index][SLOT_TWO], "Changed current arena to 1v1 arena!");
    }

    return Plugin_Handled;
}

Action Command_TwoVsTwo(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Continue;

    int arena_index = g_iPlayerArena[client];
    //new player_slot = g_iPlayerSlot[client];

    if (!arena_index) {
        PrintToChat(client, "You are not in an arena!");
        return Plugin_Continue;
    }

    if(g_bFourPersonArena[arena_index]) {
        PrintToChat(client, "This arena is already in 2v2 mode!");
        return Plugin_Continue;
    }

    if (!g_bArenaAllowChange[arena_index]) {
        PrintToChat(client, "Cannot change to 2v2 in this arena!");
        return Plugin_Continue;
    }

    if (g_iArenaStatus[arena_index] != AS_IDLE) {
        PrintToChat(client, "Cannot switch to 2v2 now!");
        return Plugin_Continue;
    }

    g_bFourPersonArena[arena_index] = true;
    g_iArenaCdTime[arena_index] = 0;
    CreateTimer(1.5, Timer_StartDuel, arena_index);
    UpdateArenaName(arena_index);

    if(g_iArenaQueue[arena_index][SLOT_ONE]) {
        PrintToChat(g_iArenaQueue[arena_index][SLOT_ONE], "Changed current arena to 2v2 arena!");
    }

    if(g_iArenaQueue[arena_index][SLOT_TWO]) {
        PrintToChat(g_iArenaQueue[arena_index][SLOT_TWO], "Changed current arena to 2v2 arena!");
    }

    return Plugin_Handled;
}

Action Command_Spec(int client, int args)
{  //detecting spectator target
    if (!IsValidClient(client))
        return Plugin_Continue;

    CreateTimer(0.1, Timer_ChangeSpecTarget, GetClientUserId(client));
    return Plugin_Continue;
}

Action Command_EurekaTeleport(int client, int args)
{
    return Plugin_Handled;
}

Action Command_AddBot(int client, int args)
{  //adding bot to client's arena
    if (!IsValidClient(client))
        return Plugin_Continue;

    int arena_index = g_iPlayerArena[client];
    int player_slot = g_iPlayerSlot[client];

    if (arena_index && (player_slot == SLOT_ONE || player_slot == SLOT_TWO || (g_bFourPersonArena[arena_index] && (player_slot == SLOT_THREE || player_slot == SLOT_FOUR))))
    {
        ServerCommand("tf_bot_add");
        g_bPlayerAskedForBot[client] = true;
    }
    return Plugin_Handled;
}

Action Command_Loc(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Continue;

    float vec[3];
    float ang[3];
    GetClientAbsOrigin(client, vec);
    GetClientEyeAngles(client, ang);
    PrintToChat(client, "%.0f %.0f %.0f %.0f", vec[0], vec[1], vec[2], ang[1]);
    return Plugin_Handled;
}

Action Command_ToogleHitblip(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Continue;

    PrintToChat(client, "This doesn't do anything and hasn't for a long time. Have a hitsound instead!");

    ClientCommand(client, "playgamesound \"ui/hitsound.wav\"");
    return Plugin_Handled;
}

Action Command_ConnectionTest(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Continue;

    char query[256];
    Format(query, sizeof(query), "SELECT rating FROM mgemod_stats LIMIT 1");
    g_DB.Query(T_SQL_Test, query, client);

    return Plugin_Handled;
}

Action Command_ToggleHud(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Continue;

    g_bShowHud[client] = !g_bShowHud[client];

    if (g_bShowHud[client])
    {
        if (g_iPlayerArena[client])
            ShowPlayerHud(client);
        else
            ShowSpecHudToClient(client);
    }
    else
    {
        HideHud(client);
    }

    PrintToChat(client, "\x01HUD is \x04%sabled\x01.", g_bShowHud[client] ? "en":"dis");
    return Plugin_Handled;
}

Action Command_ToggleElo(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Continue;

    g_bShowElo[client] = !g_bShowElo[client];

    // Save the preference to client cookie
    SetClientCookie(client, g_hShowEloCookie, g_bShowElo[client] ? "1" : "0");

    PrintToChat(client, "\x01ELO display is \x04%sabled\x01.", g_bShowElo[client] ? "en":"dis");
    return Plugin_Handled;
}

Action Command_Rank(int client, int args)
{
    if (g_bNoStats || !IsValidClient(client))
        return Plugin_Continue;

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
                PrintToChat(client, "\x03%N\x01 has \x04%i\x01 wins and \x04%i\x01 losses. You have a \x04%i%%\x01 chance of beating him.", targ, g_iPlayerWins[targ], g_iPlayerLosses[targ], RoundFloat((1 / (Pow(10.0, float((g_iPlayerRating[targ] - g_iPlayerRating[client])) / 400) + 1)) * 100));
            else
                PrintToChat(client, "\x03%N\x01's rating is \x04%i\x01. You have a \x04%i%%\x01 chance of beating him.", targ, g_iPlayerRating[targ], RoundFloat((1 / (Pow(10.0, float((g_iPlayerRating[targ] - g_iPlayerRating[client])) / 400) + 1)) * 100));
        }
    }

    return Plugin_Handled;
}

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
    PrintToConsole(client, "%t", "Cmd_HitBlip");
    PrintToConsole(client, "%t", "Cmd_Hud");
    PrintToConsole(client, "%t", "Cmd_Elo");
    PrintToConsole(client, "%t", "Cmd_Handicap");
    PrintToConsole(client, "----------------------------\n\n");

    return Plugin_Handled;
}

Action Command_First(int client, int args)
{
    if (!client || !IsValidClient(client))
        return Plugin_Continue;

    // Try to find an arena with one person in the queue..
    for (int i = 1; i <= g_iArenaCount; i++)
    {
        if (!g_iArenaQueue[i][SLOT_TWO] && g_iPlayerArena[client] != i)
        {
            if (g_iArenaQueue[i][SLOT_ONE])
            {
                if (g_iPlayerArena[client])
                    RemoveFromQueue(client, true);

                AddInQueue(client, i, true);
                return Plugin_Handled;
            }
        }
    }

    // Couldn't find an arena with only one person in the queue, so find one with none.
    if (!g_iPlayerArena[client])
    {
        for (int i = 1; i <= g_iArenaCount; i++)
        {
            if (!g_iArenaQueue[i][SLOT_TWO] && g_iPlayerArena[client] != i)
            {
                if (g_iPlayerArena[client])
                    RemoveFromQueue(client, true);

                AddInQueue(client, i, true);
                return Plugin_Handled;
            }
        }
    }

    // Couldn't find any empty or half-empty arenas, so display the menu.
    ShowMainMenu(client);
    return Plugin_Handled;
}

Action Command_Handicap(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Continue;

    int arena_index = g_iPlayerArena[client];

    if (!arena_index || g_bArenaMidair[arena_index])
    {
        MC_PrintToChat(client, "%t", "MustJoinArena");
        g_iPlayerHandicap[client] = 0;
        return Plugin_Handled;
    }

    if (args == 0)
    {
        if (g_iPlayerHandicap[client] == 0)
            MC_PrintToChat(client, "%t", "NoCurrentHandicap", g_iPlayerHandicap[client]);
        else
            MC_PrintToChat(client, "%t", "CurrentHandicap", g_iPlayerHandicap[client]);
    } else {
        char argstr[64];
        GetCmdArgString(argstr, sizeof(argstr));
        int argint = StringToInt(argstr);

        if (StrEqual(argstr, "off", false))
        {
            MC_PrintToChat(client, "%t", "HandicapDisabled");
            g_iPlayerHandicap[client] = 0;
            return Plugin_Handled;
        }

        if (argint > RoundToNearest(float(g_iPlayerMaxHP[client]) * g_fArenaHPRatio[arena_index]))
        {
            MC_PrintToChat(client, "%t", "InvalidHandicap");
            g_iPlayerHandicap[client] = 0;
        } else if (argint <= 0) {
            MC_PrintToChat(client, "%t", "InvalidHandicap");
        } else {
            g_iPlayerHandicap[client] = argint;

            //If the client currently has more health than their handicap allows, lower it to the proper amount.
            if (IsPlayerAlive(client) && g_iPlayerHP[client] > g_iPlayerHandicap[client])
            {
                if (g_bArenaMGE[arena_index] || g_bArenaBBall[arena_index])
                {
                    //Prevent an possible exploit where a player could restore their buff if it decayed naturally without them taking damage.
                    if (GetEntProp(client, Prop_Data, "m_iHealth") > g_iPlayerHandicap[client])
                    {
                        SetEntProp(client, Prop_Data, "m_iHealth", g_iPlayerHandicap[client]);
                        g_iPlayerHP[client] = g_iPlayerHandicap[client];
                    }
                } else {
                    g_iPlayerHP[client] = g_iPlayerHandicap[client];
                }

                //Update overlay huds to reflect health change.
                int
                    player_slot = g_iPlayerSlot[client],
                    foe_slot = player_slot == SLOT_ONE ? SLOT_TWO : SLOT_ONE,
                    foe = g_iArenaQueue[arena_index][foe_slot],
                    foe_teammate,
                    player_teammate;

                if (g_bFourPersonArena[arena_index])
                {
                    player_teammate = getTeammate(player_slot, arena_index);
                    foe_teammate = getTeammate(foe_slot, arena_index);

                    ShowPlayerHud(player_teammate);
                    ShowPlayerHud(foe_teammate);
                }

                ShowPlayerHud(client);
                ShowPlayerHud(foe);
                ShowSpecHudToArena(g_iPlayerArena[client]);
            }
        }
    }

    return Plugin_Handled;
}

/* OnDropIntel(client, command, argc)
*
* When a player drops the intel in BBall.
* -------------------------------------------------------------------------- */
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

            //This should fix the ammopack not being turned into a briefcase
            DispatchKeyValue(g_iBBallIntel[arena_index], "powerup_model", MODEL_BRIEFCASE);
            TeleportEntity(g_iBBallIntel[arena_index], pos, NULL_VECTOR, NULL_VECTOR);
            DispatchSpawn(g_iBBallIntel[arena_index]);
            SetEntProp(g_iBBallIntel[arena_index], Prop_Send, "m_iTeamNum", 1, 4);
            SetEntPropFloat(g_iBBallIntel[arena_index], Prop_Send, "m_flModelScale", 1.15);

            //Doesn't work anymore
            //SetEntityModel(g_iBBallIntel[arena_index], MODEL_BRIEFCASE);
            //SDKUnhook(g_iBBallIntel[arena_index], SDKHook_StartTouch, OnTouchIntel);
            SDKHook(g_iBBallIntel[arena_index], SDKHook_StartTouch, OnTouchIntel);
            AcceptEntityInput(g_iBBallIntel[arena_index], "Enable");

            EmitSoundToClient(client, "vo/intel_teamdropped.wav");

            RemoveClientParticle(client);

            g_bCanPlayerGetIntel[client] = false;
            CreateTimer(0.5, Timer_AllowPlayerCap, client);
        }
    }

    return Plugin_Continue;
}

//blocking sounds
Action sound_hook(int clients[MAXPLAYERS], int& numClients, char sample[PLATFORM_MAX_PATH], int& entity, int& channel, float& volume, int& level, int& pitch, int& flags, char soundEntry[PLATFORM_MAX_PATH], int& seed)
{
    if (StrContains(sample, "pl_fallpain") >= 0 && g_bBlockFallDamage)
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

// ====[ SQL ]====================================================
void PrepareSQL() // Opens the connection to the database, and creates the tables if they dont exist.
{
    char error[256];

    // initial mysql connect
    if (g_DB == null && SQL_CheckConfig(g_sDBConfig))
    {
        g_DB = SQL_Connect(g_sDBConfig, /* persistent */ true, error, sizeof(error));
    }

    // failed mysql connect for whatever reason (likely no config in databases.cfg)
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
        g_DB.Query(SQLErrorCheckCallback, "CREATE TABLE IF NOT EXISTS mgemod_stats (rating INTEGER, steamid TEXT, name TEXT, wins INTEGER, losses INTEGER, lastplayed INTEGER, hitblip INTEGER)");
        g_DB.Query(SQLErrorCheckCallback, "CREATE TABLE IF NOT EXISTS mgemod_duels (winner TEXT, loser TEXT, winnerscore INTEGER, loserscore INTEGER, winlimit INTEGER, gametime INTEGER, mapname TEXT, arenaname TEXT) ");
        g_DB.Query(SQLErrorCheckCallback, "CREATE TABLE IF NOT EXISTS mgemod_duels_2v2 (winner TEXT, winner2 TEXT, loser TEXT, loser2 TEXT, winnerscore INTEGER, loserscore INTEGER, winlimit INTEGER, gametime INTEGER, mapname TEXT, arenaname TEXT) ");
    }
    else
    {
        g_DB.Query(SQLErrorCheckCallback, "CREATE TABLE IF NOT EXISTS mgemod_stats (rating INT(4) NOT NULL, steamid VARCHAR(32) NOT NULL, name VARCHAR(64) NOT NULL, wins INT(4) NOT NULL, losses INT(4) NOT NULL, lastplayed INT(11) NOT NULL, hitblip INT(2) NOT NULL) DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE = InnoDB ");
        g_DB.Query(SQLErrorCheckCallback, "CREATE TABLE IF NOT EXISTS mgemod_duels (winner VARCHAR(32) NOT NULL, loser VARCHAR(32) NOT NULL, winnerscore INT(4) NOT NULL, loserscore INT(4) NOT NULL, winlimit INT(4) NOT NULL, gametime INT(11) NOT NULL, mapname VARCHAR(64) NOT NULL, arenaname VARCHAR(32) NOT NULL) DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE = InnoDB ");
        g_DB.Query(SQLErrorCheckCallback, "CREATE TABLE IF NOT EXISTS mgemod_duels_2v2 (winner VARCHAR(32) NOT NULL, winner2 VARCHAR(32) NOT NULL, loser VARCHAR(32) NOT NULL, loser2 VARCHAR(32) NOT NULL, winnerscore INT(4) NOT NULL, loserscore INT(4) NOT NULL, winlimit INT(4) NOT NULL, gametime INT(11) NOT NULL, mapname VARCHAR(64) NOT NULL, arenaname VARCHAR(32) NOT NULL) DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE = InnoDB ");
    }

    RunDatabaseMigrations();
}

// Migration tracking structure
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
        // For SQLite: rename gametime to endtime, then add starttime
        ExecuteMigrationStep("002_duel_timing_columns", "ALTER TABLE mgemod_duels RENAME COLUMN gametime TO endtime", 1);
        ExecuteMigrationStep("002_duel_timing_columns", "ALTER TABLE mgemod_duels ADD COLUMN starttime INTEGER DEFAULT NULL", 2);
        ExecuteMigrationStep("002_duel_timing_columns", "ALTER TABLE mgemod_duels_2v2 RENAME COLUMN gametime TO endtime", 3);
        ExecuteMigrationStep("002_duel_timing_columns", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN starttime INTEGER DEFAULT NULL", 4);
    }
    else
    {
        // For MySQL: change column name and add new column
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
        // SQLite: Add auto-incrementing ID columns and primary key constraint
        ExecuteMigrationStep("003_add_primary_keys", "ALTER TABLE mgemod_duels ADD COLUMN id INTEGER PRIMARY KEY", 1);
        ExecuteMigrationStep("003_add_primary_keys", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN id INTEGER PRIMARY KEY", 2);
        ExecuteMigrationStep("003_add_primary_keys", "CREATE UNIQUE INDEX idx_stats_steamid ON mgemod_stats (steamid)", 3);
    }
    else
    {
        // MySQL: Add auto-incrementing ID columns and primary key constraint
        ExecuteMigrationStep("003_add_primary_keys", "ALTER TABLE mgemod_duels ADD COLUMN id INT AUTO_INCREMENT PRIMARY KEY FIRST", 1);
        ExecuteMigrationStep("003_add_primary_keys", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN id INT AUTO_INCREMENT PRIMARY KEY FIRST", 2);
        ExecuteMigrationStep("003_add_primary_keys", "ALTER TABLE mgemod_stats ADD PRIMARY KEY (steamid)", 3);
    }
}

void Migration_004_AddEloTracking()
{
    LogMessage("[Migration 004] Adding ELO tracking columns to duel tables");
    
    if (g_bUseSQLite)
    {
        // SQLite: Add ELO tracking columns for 1v1 duels
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels ADD COLUMN winner_previous_elo INTEGER DEFAULT NULL", 1);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels ADD COLUMN winner_new_elo INTEGER DEFAULT NULL", 2);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels ADD COLUMN loser_previous_elo INTEGER DEFAULT NULL", 3);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels ADD COLUMN loser_new_elo INTEGER DEFAULT NULL", 4);
        
        // SQLite: Add ELO tracking columns for 2v2 duels
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
        // MySQL: Add ELO tracking columns for 1v1 duels
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels ADD COLUMN winner_previous_elo INT(4) DEFAULT NULL", 1);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels ADD COLUMN winner_new_elo INT(4) DEFAULT NULL", 2);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels ADD COLUMN loser_previous_elo INT(4) DEFAULT NULL", 3);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels ADD COLUMN loser_new_elo INT(4) DEFAULT NULL", 4);
        
        // MySQL: Add ELO tracking columns for 2v2 duels
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN winner_previous_elo INT(4) DEFAULT NULL", 5);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN winner_new_elo INT(4) DEFAULT NULL", 6);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN winner2_previous_elo INT(4) DEFAULT NULL", 7);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN winner2_new_elo INT(4) DEFAULT NULL", 8);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN loser_previous_elo INT(4) DEFAULT NULL", 9);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN loser_new_elo INT(4) DEFAULT NULL", 10);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN loser2_previous_elo INT(4) DEFAULT NULL", 11);
        ExecuteMigrationStep("004_add_elo_tracking", "ALTER TABLE mgemod_duels_2v2 ADD COLUMN loser2_new_elo INT(4) DEFAULT NULL", 12);
    }
}

void MarkMigrationComplete(const char[] migrationName)
{
    char query[256];
    Format(query, sizeof(query), "INSERT INTO mgemod_migrations (migration_name, executed_at) VALUES ('%s', %d)", migrationName, GetTime());
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

void GetPlayerClassString(int client, int arena_index, char[] buffer, int maxlen)
{
    if (g_bArenaClassChange[arena_index] && g_alPlayerDuelClasses[client] != null && g_alPlayerDuelClasses[client].Length > 0)
    {
        // Build comma-separated list of all classes used
        buffer[0] = '\0';
        for (int i = 0; i < g_alPlayerDuelClasses[client].Length; i++)
        {
            char className[16];
            strcopy(className, sizeof(className), TFClassToString(view_as<TFClassType>(g_alPlayerDuelClasses[client].Get(i))));
            
            if (i > 0)
                StrCat(buffer, maxlen, ",");
            StrCat(buffer, maxlen, className);
        }
    }
    else
    {
        // Use single class from duel start
        strcopy(buffer, maxlen, TFClassToString(g_tfctPlayerDuelClass[client]));
    }
}

void T_SQLQueryOnConnect(Database db, DBResultSet results, const char[] error, any data)
{
    int client = data;

    if (db == null)
    {
        LogError("T_SQLQueryOnConnect failed: database connection lost");
        return;
    }
    
    if (results == null)
    {
        LogError("T_SQLQueryOnConnect failed: %s", error);
        return;
    }

    if ( client < 1 || client > MaxClients || !IsClientConnected(client) )
    {
        LogError("T_SQLQueryOnConnect failed: client %d <%s> is invalid.", client, g_sPlayerSteamID[client]);
        return;
    }

    char query[512];
    char namesql_dirty[MAX_NAME_LENGTH], namesql[(MAX_NAME_LENGTH * 2) + 1];
    GetClientName(client, namesql_dirty, sizeof(namesql_dirty));
    db.Escape(namesql_dirty, namesql, sizeof(namesql));

    if (results.FetchRow())
    {
        g_iPlayerRating[client] = results.FetchInt(0);
        g_bHitBlip[client] = results.FetchInt(1) == 1;
        g_iPlayerWins[client] = results.FetchInt(2);
        g_iPlayerLosses[client] = results.FetchInt(3);

        Format(query, sizeof(query), "UPDATE mgemod_stats SET name='%s' WHERE steamid='%s'", namesql, g_sPlayerSteamID[client]);
        db.Query(SQLErrorCheckCallback, query);
    } else {
        if (g_bUseSQLite)
        {
            Format(query, sizeof(query), "INSERT INTO mgemod_stats VALUES(1600, '%s', '%s', 0, 0, %i, 1)", g_sPlayerSteamID[client], namesql, GetTime());
            db.Query(SQLErrorCheckCallback, query);
        } else {
            Format(query, sizeof(query), "INSERT INTO mgemod_stats (rating, steamid, name, wins, losses, lastplayed, hitblip) VALUES (1600, '%s', '%s', 0, 0, %i, 1)", g_sPlayerSteamID[client], namesql, GetTime());
            db.Query(SQLErrorCheckCallback, query);
        }

        g_iPlayerRating[client] = 1600;
        g_bHitBlip[client] = false;
    }
}

void T_SQL_Top5(Database db, DBResultSet results, const char[] error, any data)
{
    int client = data;

    if (db == null)
    {
        LogError("[Top5] Query failed: database connection lost");
        return;
    }
    
    if (results == null)
    {
        LogError("[Top5] Query failed: %s", error);
        return;
    }

    if (client < 1 || client > MaxClients || !IsClientConnected(client))
    {
        LogError("T_SQL_Top5 failed: client %d <%s> is invalid.", client, g_sPlayerSteamID[client]);
        return;
    }

    if (SQL_GetRowCount(results) == 5)
    {
        int rating[5], i;
        char name[5][MAX_NAME_LENGTH];

        while (results.FetchRow())
        {
            if (i > 5)
                break;

            results.FetchString(1, name[i], 64);
            rating[i] = results.FetchInt(0);

            i++;
        }

        ShowTop5Menu(client, name, rating);
    } else {
        MC_PrintToChat(client, "%t", "top5error");
    }

}

void T_SQL_Test(Database db, DBResultSet results, const char[] error, any data)
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
        LogError("T_SQL_Test failed: client %d <%s> is invalid.", client, g_sPlayerSteamID[client]);
        return;
    }

    if (results.FetchRow())
        PrintToChat(client, "\x01Database is \x04Up\x01.");
    else
        PrintToChat(client, "\x01Database is \x04Down\x01.");
}

void SQLErrorCheckCallback(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        LogError("SQLErrorCheckCallback: Database connection lost (db handle is null)");
        
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
        LogError("SQLErrorCheckCallback: Query failed (connection OK): %s", error);
    }
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
                    Format(query, sizeof(query), "SELECT rating, hitblip, wins, losses FROM mgemod_stats WHERE steamid='%s' LIMIT 1", steamid);
                    db.Query(T_SQLQueryOnConnect, query, i);
                    
                    // Handle hot-loading case: initialize client state that requires DB
                    if (!IsFakeClient(i))
                    {
                        // Ensure spectator team and proper client setup
                        ChangeClientTeam(i, TEAM_SPEC);
                        g_bHitBlip[i] = false;
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


/*
** ------------------------------------------------------------------
**      ______                  __
**     / ____/_   _____  ____  / /______
**    / __/  | | / / _ \/ __ \/ __/ ___/
**   / /___  | |/ /  __/ / / / /_(__  )
**  /_____/  |___/\___/_/ /_/\__/____/
**
** ------------------------------------------------------------------
**/

Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int arena_index = g_iPlayerArena[client];

    g_tfctPlayerClass[client] = TF2_GetPlayerClass(client);


    ResetClientAmmoCounts(client);

    if (!g_bFourPersonArena[arena_index] && g_iPlayerSlot[client] != SLOT_ONE && g_iPlayerSlot[client] != SLOT_TWO)
        ChangeClientTeam(client, TEAM_SPEC);

    else if (g_bFourPersonArena[arena_index] && g_iPlayerSlot[client] != SLOT_ONE && g_iPlayerSlot[client] != SLOT_TWO && (g_iPlayerSlot[client] != SLOT_THREE && g_iPlayerSlot[client] != SLOT_FOUR))
        ChangeClientTeam(client, TEAM_SPEC);

    if (g_bArenaMGE[arena_index])
    {
        g_iPlayerHP[client] = RoundToNearest(float(g_iPlayerMaxHP[client]) * g_fArenaHPRatio[arena_index]);
        ShowSpecHudToArena(arena_index);
    }

    if (g_bArenaBBall[arena_index])
    {
        g_bPlayerHasIntel[client] = false;
    }

    return Plugin_Continue;
}

Action Event_WinPanel(Event event, const char[] name, bool dontBroadcast)
{
    // Disable stats so people leaving at the end of the map don't lose points.
    g_bNoStats = true;

    return Plugin_Continue;
}

Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));

    if (!IsValidClient(victim))
        return Plugin_Continue;

    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int arena_index = g_iPlayerArena[victim];
    int iDamage = event.GetInt("damageamount");

    if (attacker > 0 && victim != attacker) // If the attacker wasn't the person being hurt, or the world (fall damage).
    {
        bool shootsRocketsOrPipes = ShootsRocketsOrPipes(attacker);
        if (g_bArenaEndif[arena_index])
        {
            if (shootsRocketsOrPipes)
                CreateTimer(0.1, BoostVectors, GetClientUserId(victim));
        }

        if (g_bPlayerTakenDirectHit[victim])
        {
            bool isVictimInAir = !(GetEntityFlags(victim) & (FL_ONGROUND));

            if (isVictimInAir)
            {
                //airshot
                float dist = DistanceAboveGround(victim);
                if (dist >= g_iAirshotHeight)
                {
                    if (g_bArenaMidair[arena_index])
                        g_iPlayerHP[victim] -= 1;

                    if (g_bArenaEndif[arena_index] && dist >= 250)
                    {
                        g_iPlayerHP[victim] = -1;
                    }
                }
            }
        }
    }

    g_bPlayerTakenDirectHit[victim] = false;

    if (g_bArenaMGE[arena_index] || g_bArenaBBall[arena_index])
        g_iPlayerHP[victim] = GetClientHealth(victim);
    else if (g_bArenaAmmomod[arena_index])
        g_iPlayerHP[victim] -= iDamage;

    //TODO: Look into getting rid of the crutch. Possible memory leak/performance issue?
    g_bPlayerRestoringAmmo[attacker] = false; //inf ammo crutch

    if (g_bArenaAmmomod[arena_index] || g_bArenaMidair[arena_index] || g_bArenaEndif[arena_index])
    {
        if (g_iPlayerHP[victim] <= 0)
            SetEntityHealth(victim, 0);
        else
            SetEntityHealth(victim, g_iPlayerMaxHP[victim]);
    }

    ShowPlayerHud(victim);
    ShowPlayerHud(attacker);
    ShowSpecHudToArena(g_iPlayerArena[victim]);

    return Plugin_Continue;
}

Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int arena_index = g_iPlayerArena[victim];
    int victim_slot = g_iPlayerSlot[victim];


    int killer_slot = (victim_slot == SLOT_ONE || victim_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
    int killer = g_iArenaQueue[arena_index][killer_slot];
    int killer_teammate;
    int victim_teammate;

    //gets the killer and victims team slot (red 1, blu 2)
    int killer_team_slot = (killer_slot > 2) ? (killer_slot - 2) : killer_slot;
    int victim_team_slot = (victim_slot > 2) ? (victim_slot - 2) : victim_slot;

    // don't detect dead ringer deaths
    int victim_deathflags = event.GetInt("death_flags");
    if (victim_deathflags & 32)
    {
        return Plugin_Continue;
    }

    if (g_bFourPersonArena[arena_index])
    {
        victim_teammate = getTeammate(victim_slot, arena_index);
        killer_teammate = getTeammate(killer_slot, arena_index);
    }

    RemoveClientParticle(victim);

    if (!arena_index)
        ChangeClientTeam(victim, TEAM_SPEC);

    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (g_iArenaStatus[arena_index] < AS_FIGHT && IsValidClient(attacker) && IsPlayerAlive(attacker))
    {
        TF2_RegeneratePlayer(attacker);
        int raised_hp = RoundToNearest(float(g_iPlayerMaxHP[attacker]) * g_fArenaHPRatio[arena_index]);
        g_iPlayerHP[attacker] = raised_hp;
        SetEntProp(attacker, Prop_Data, "m_iHealth", raised_hp);
    }

    if (g_iArenaStatus[arena_index] < AS_FIGHT || g_iArenaStatus[arena_index] > AS_FIGHT)
    {
        CreateTimer(0.1, Timer_ResetPlayer, GetClientUserId(victim));
        return Plugin_Handled;
    }

    if ((g_bFourPersonArena[arena_index] && !IsPlayerAlive(killer)) || (g_bFourPersonArena[arena_index] && !IsPlayerAlive(killer_teammate) && !IsPlayerAlive(killer)))
    {
        if (g_bArenaAmmomod[arena_index] || g_bArenaMidair[arena_index])
            return Plugin_Handled;
    }

    if (!g_bArenaBBall[arena_index] && !g_bArenaKoth[arena_index] && (!g_bFourPersonArena[arena_index] || (g_bFourPersonArena[arena_index] && !IsPlayerAlive(victim_teammate)))) // Kills shouldn't give points in bball. Or if only 1 player in a two person arena dies
        g_iArenaScore[arena_index][killer_team_slot] += 1;

    if (!g_bArenaEndif[arena_index]) // Endif does not need to display health, since it is one-shot kills.
    {
        //We must get the player that shot you last in 4 player arenas
        //The valid client check shouldn't be necessary but I'm getting invalid clients here for some reason
        //This may be caused by players killing themselves in 1v1 arenas without being attacked, or dieing after
        //A player disconnects but before the arena status transitions out of fight mode?
        //TODO: check properly
        if (g_bFourPersonArena[arena_index] && IsValidClient(attacker) && IsPlayerAlive(attacker))
        {
            if ((g_bArenaMGE[arena_index] || g_bArenaBBall[arena_index] || g_bArenaKoth[arena_index]) && (victim != attacker))
                MC_PrintToChat(victim, "%t", "HPLeft", GetClientHealth(attacker));
            else if (victim != attacker)
                MC_PrintToChat(victim, "%t", "HPLeft", g_iPlayerHP[attacker]);
        }
        //in 1v1 arenas we can assume the person who killed you is the other person in the arena
        else if (IsValidClient(killer) && IsPlayerAlive(killer))
        {
            if (g_bArenaMGE[arena_index] || g_bArenaBBall[arena_index] || g_bArenaKoth[arena_index])
                MC_PrintToChat(victim, "%t", "HPLeft", GetClientHealth(killer));
            else
                MC_PrintToChat(victim, "%t", "HPLeft", g_iPlayerHP[killer]);
        }
    }

    //Currently set up so that if its a 2v2 duel the round will reset after both players on one team die and a point will be added for that round to the other team
    //Another possibility is to make it like dm where its instant respawn for every player, killer gets hp, and a point is awarded for every kill


    int fraglimit = g_iArenaFraglimit[arena_index];


    if ((!g_bFourPersonArena[arena_index] && (g_bArenaAmmomod[arena_index] || g_bArenaMidair[arena_index])) ||
        (g_bFourPersonArena[arena_index] && !IsPlayerAlive(victim_teammate) && !g_bArenaBBall[arena_index] && !g_bArenaKoth[arena_index]))
    g_iArenaStatus[arena_index] = AS_AFTERFIGHT;

    if (g_iArenaStatus[arena_index] >= AS_FIGHT && g_iArenaStatus[arena_index] < AS_REPORTED && fraglimit > 0 && g_iArenaScore[arena_index][killer_team_slot] >= fraglimit)
    {
        g_iArenaStatus[arena_index] = AS_REPORTED;
        char killer_name[128];
        char victim_name[128];
        GetClientName(killer, killer_name, sizeof(killer_name));
        GetClientName(victim, victim_name, sizeof(victim_name));


        if (g_bFourPersonArena[arena_index])
        {
            char killer_teammate_name[128];
            char victim_teammate_name[128];

            GetClientName(killer_teammate, killer_teammate_name, sizeof(killer_teammate_name));
            GetClientName(victim_teammate, victim_teammate_name, sizeof(victim_teammate_name));

            Format(killer_name, sizeof(killer_name), "%s and %s", killer_name, killer_teammate_name);
            Format(victim_name, sizeof(victim_name), "%s and %s", victim_name, victim_teammate_name);
        }

        MC_PrintToChatAll("%t", "XdefeatsY", killer_name, g_iArenaScore[arena_index][killer_team_slot], victim_name, g_iArenaScore[arena_index][victim_team_slot], fraglimit, g_sArenaName[arena_index]);

        if (!g_bNoStats && !g_bFourPersonArena[arena_index])
            CalcELO(killer, victim);

        else if (!g_bNoStats)
            CalcELO2(killer, killer_teammate, victim, victim_teammate);

        if (!g_bFourPersonArena[arena_index])
        {
            if (g_iArenaQueue[arena_index][SLOT_TWO + 1])
            {
                RemoveFromQueue(victim, false, true);
                AddInQueue(victim, arena_index, false, 0, false);
            } else {
                CreateTimer(3.0, Timer_StartDuel, arena_index);
            }
        }
        else
        {
            if (g_iArenaQueue[arena_index][SLOT_FOUR + 1] && g_iArenaQueue[arena_index][SLOT_FOUR + 2])
            {
                RemoveFromQueue(victim_teammate, false, true);
                RemoveFromQueue(victim, false, true);
                AddInQueue(victim_teammate, arena_index, false, 0, false);
                AddInQueue(victim, arena_index, false, 0, false);
            }
            else if (g_iArenaQueue[arena_index][SLOT_FOUR + 1])
            {
                RemoveFromQueue(victim, false, true);
                AddInQueue(victim, arena_index, false, 0, false);
            }
            else {
                // For 2v2 arenas, return to ready state instead of restarting immediately
                if (g_bFourPersonArena[arena_index])
                {
                    CreateTimer(3.0, Timer_Restart2v2Ready, arena_index);
                }
                else
                {
                    CreateTimer(3.0, Timer_StartDuel, arena_index);
                }
            }
        }
    }
    else if (g_bArenaAmmomod[arena_index] || g_bArenaMidair[arena_index])
    {
        if (!g_bFourPersonArena[arena_index])
            CreateTimer(3.0, Timer_NewRound, arena_index);

        else if (g_bFourPersonArena[arena_index] && !IsPlayerAlive(victim_teammate))
            CreateTimer(3.0, Timer_NewRound, arena_index);

    }
    else
    {
        if (g_bArenaBBall[arena_index])
        {
            if (g_bPlayerHasIntel[victim])
            {
                g_bPlayerHasIntel[victim] = false;
                float pos[3];
                GetClientAbsOrigin(victim, pos);
                float dist = DistanceAboveGround(victim);
                if (dist > -1)
                    pos[2] = pos[2] - dist + 5;
                else
                    pos[2] = g_fArenaSpawnOrigin[arena_index][g_iArenaSpawns[arena_index] - 3][2];

                if (g_iBBallIntel[arena_index] == -1)
                    g_iBBallIntel[arena_index] = CreateEntityByName("item_ammopack_small");
                else
                    LogError("[%s] Player died with intel, but intel [%i] already exists.", g_sArenaName[arena_index], g_iBBallIntel[arena_index]);


                //This should fix the ammopack not being turned into a briefcase
                DispatchKeyValue(g_iBBallIntel[arena_index], "powerup_model", MODEL_BRIEFCASE);
                TeleportEntity(g_iBBallIntel[arena_index], pos, NULL_VECTOR, NULL_VECTOR);
                DispatchSpawn(g_iBBallIntel[arena_index]);
                SetEntProp(g_iBBallIntel[arena_index], Prop_Send, "m_iTeamNum", 1, 4);
                SetEntPropFloat(g_iBBallIntel[arena_index], Prop_Send, "m_flModelScale", 1.15);
                //Doesn't work anymore
                //SetEntityModel(g_iBBallIntel[arena_index], MODEL_BRIEFCASE);
                //SDKUnhook(g_iBBallIntel[arena_index], SDKHook_StartTouch, OnTouchIntel);
                SDKHook(g_iBBallIntel[arena_index], SDKHook_StartTouch, OnTouchIntel);
                AcceptEntityInput(g_iBBallIntel[arena_index], "Enable");

                EmitSoundToClient(victim, "vo/intel_teamdropped.wav");
                if (IsValidClient(killer))
                    EmitSoundToClient(killer, "vo/intel_enemydropped.wav");

            }
        } else {
            if (!g_bFourPersonArena[arena_index] && !g_bArenaKoth[arena_index])
            {
                ResetKiller(killer, arena_index);
            }
            if (g_bFourPersonArena[arena_index] && (GetClientTeam(victim_teammate) == TEAM_SPEC || !IsPlayerAlive(victim_teammate)))
            {
                //Reset the teams
                ResetArena(arena_index);
                if (killer_team_slot == SLOT_ONE)
                {
                    ChangeClientTeam(victim, TEAM_BLU);
                    ChangeClientTeam(victim_teammate, TEAM_BLU);

                    ChangeClientTeam(killer_teammate, TEAM_RED);
                }
                else
                {
                    ChangeClientTeam(victim, TEAM_RED);
                    ChangeClientTeam(victim_teammate, TEAM_RED);

                    ChangeClientTeam(killer_teammate, TEAM_BLU);
                }

                //Should there be a 3 second count down in between rounds in 2v2 or just spawn and go?
                //Timer_NewRound would create a 3 second count down where as just reseting all the players would make it just go
                /*
                if (killer)
                    ResetPlayer(killer);
                if (victim_teammate)
                    ResetPlayer(victim_teammate);
                if (victim)
                    ResetPlayer(victim);
                if (killer_teammate)
                    ResetPlayer(killer_teammate);

                g_iArenaStatus[arena_index] = AS_FIGHT;
                */
                if (g_b2v2SkipCountdown)
                    CreateTimer(0.1, Timer_New2v2Round, arena_index);
                else
                    CreateTimer(0.1, Timer_NewRound, arena_index);
            }


        }


        //TODO: Check to see if its koth and apply a spawn penalty if needed depending on who's capping
        if (g_bArenaBBall[arena_index] || g_bArenaKoth[arena_index])
        {
            CreateTimer(g_fArenaRespawnTime[arena_index], Timer_ResetPlayer, GetClientUserId(victim));
        }
        else if (g_bFourPersonArena[arena_index] && victim_teammate && IsPlayerAlive(victim_teammate))
        {
            //Set the player as waiting
            g_iPlayerWaiting[victim] = true;
            //change the player to spec to keep him from respawning
            CreateTimer(5.0, Timer_ChangePlayerSpec, victim);
            //instead of respawning him
            //CreateTimer(g_fArenaRespawnTime[arena_index],Timer_ResetPlayer,GetClientUserId(victim));
        }
        else
            CreateTimer(g_fArenaRespawnTime[arena_index], Timer_ResetPlayer, GetClientUserId(victim));

    }

    ShowPlayerHud(victim);
    ShowPlayerHud(killer);

    if (g_bFourPersonArena[arena_index])
    {
        ShowPlayerHud(victim_teammate);
        ShowPlayerHud(killer_teammate);
    }

    ShowSpecHudToArena(arena_index);

    return Plugin_Continue;
}


Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    gcvar_WfP.SetInt(1); //cancel waiting for players

    //Be totally certain that the models are chached so they can be hooked
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
                //LogError("[%s] Event_RoundStart fired, but could not remove old hoop [%d]!.", g_sArenaName[i], g_iBBallHoop[i][SLOT_ONE]);
                //LogError("[%s] Resetting SLOT_ONE hoop array index %i.", g_sArenaName[i], i);
                g_iBBallHoop[i][SLOT_ONE] = -1;
            }

            if (IsValidEdict(g_iBBallHoop[i][SLOT_TWO]) && g_iBBallHoop[i][SLOT_TWO] > 0)
            {
                RemoveEdict(g_iBBallHoop[i][SLOT_TWO]);
                g_iBBallHoop[i][SLOT_TWO] = -1;
            } else if (g_iBBallHoop[i][SLOT_TWO] != -1) {  // g_iBBallHoop[i][SLOT_TWO] equaling -1 is not a bad thing, so don't print an error for it.
                //LogError("[%s] Event_RoundStart fired, but could not remove old hoop [%d]!.", g_sArenaName[i], g_iBBallHoop[i][SLOT_TWO]);
                //LogError("[%s] Resetting SLOT_TWO hoop array index %i.", g_sArenaName[i], i);
                g_iBBallHoop[i][SLOT_TWO] = -1;
            }

            if (g_iBBallHoop[i][SLOT_ONE] == -1)
            {
                g_iBBallHoop[i][SLOT_ONE] = CreateEntityByName("item_ammopack_small");
                TeleportEntity(g_iBBallHoop[i][SLOT_ONE], hoop_1_loc, NULL_VECTOR, NULL_VECTOR);
                DispatchSpawn(g_iBBallHoop[i][SLOT_ONE]);
                SetEntProp(g_iBBallHoop[i][SLOT_ONE], Prop_Send, "m_iTeamNum", 1, 4);

                //SDKUnhook(g_iBBallHoop[i][SLOT_ONE], SDKHook_StartTouch, OnTouchHoop);
                SDKHook(g_iBBallHoop[i][SLOT_ONE], SDKHook_StartTouch, OnTouchHoop);
            }

            if (g_iBBallHoop[i][SLOT_TWO] == -1)
            {
                g_iBBallHoop[i][SLOT_TWO] = CreateEntityByName("item_ammopack_small");
                TeleportEntity(g_iBBallHoop[i][SLOT_TWO], hoop_2_loc, NULL_VECTOR, NULL_VECTOR);
                DispatchSpawn(g_iBBallHoop[i][SLOT_TWO]);
                SetEntProp(g_iBBallHoop[i][SLOT_TWO], Prop_Send, "m_iTeamNum", 1, 4);

                //SDKUnhook(g_iBBallHoop[i][SLOT_TWO], SDKHook_StartTouch, OnTouchHoop);
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

                //SDKUnhook(g_iCapturePoint[i], SDKHook_StartTouch, OnTouchPoint);
                SDKHook(g_iCapturePoint[i], SDKHook_StartTouch, OnTouchPoint);
                //SDKUnhook(g_iCapturePoint[i], SDKHook_EndTouch, OnEndTouchPoint);
                SDKHook(g_iCapturePoint[i], SDKHook_EndTouch, OnEndTouchPoint);
            }

            // Could have used SetRenderMode here, but it had the unfortunate side-effect of also making the intel invisible.
            // Luckily, inputting "Disable" to most entities makes them invisible, so it was a valid workaround.
            AcceptEntityInput(g_iCapturePoint[i], "Disable");

        }
    }

    return Plugin_Continue;
}

/*
** ------------------------------------------------------------------
**   _______
**   /_  __(_)____ ___  ___  __________
**    / / / // __ `__ \/ _ \/ ___/ ___/
**   / / / // / / / / /  __/ /  (__  )
**  /_/ /_//_/ /_/ /_/\___/_/  /____/
**
** ------------------------------------------------------------------
**/

void RegenKiller(any killer)
{
    TF2_RegeneratePlayer(killer);
}

Action Timer_WelcomePlayer(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (!IsValidClient(client))
    {
        return Plugin_Continue;
    }

    MC_PrintToChat(client, "%t", "Welcome1", PL_VERSION);
    if (StrContains(g_sMapName, "mge_", false) == 0)
        MC_PrintToChat(client, "%t", "Welcome2");
    MC_PrintToChat(client, "%t", "Welcome3");

    return Plugin_Continue;
}

Action Timer_SpecFix(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client))
        return Plugin_Continue;

    ChangeClientTeam(client, TEAM_RED);
    ChangeClientTeam(client, TEAM_SPEC);

    return Plugin_Continue;
}

Action Timer_SpecHudToAllArenas(Handle timer, int userid)
{
    for (int i = 1; i <= g_iArenaCount; i++)
    ShowSpecHudToArena(i);

    return Plugin_Continue;
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

Action Timer_CountDown(Handle timer, any arena_index)
{
    int red_f1 = g_iArenaQueue[arena_index][SLOT_ONE];
    int blu_f1 = g_iArenaQueue[arena_index][SLOT_TWO];
    int red_f2;
    int blu_f2;
    if (g_bFourPersonArena[arena_index])
    {
        red_f2 = g_iArenaQueue[arena_index][SLOT_THREE];
        blu_f2 = g_iArenaQueue[arena_index][SLOT_FOUR];
    }
    if (g_bFourPersonArena[arena_index])
    {
        if (red_f1 && blu_f1 && red_f2 && blu_f2)
        {
            g_iArenaCd[arena_index]--;

            if (g_iArenaCd[arena_index] > 0)
            {  // blocking +attack
                float enginetime = GetGameTime();

                for (int i = 0; i <= 2; i++)
                {
                    int ent = GetPlayerWeaponSlot(red_f1, i);

                    if (IsValidEntity(ent))
                        SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + float(g_iArenaCd[arena_index]));

                    ent = GetPlayerWeaponSlot(blu_f1, i);

                    if (IsValidEntity(ent))
                        SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + float(g_iArenaCd[arena_index]));

                    ent = GetPlayerWeaponSlot(red_f2, i);

                    if (IsValidEntity(ent))
                        SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + float(g_iArenaCd[arena_index]));

                    ent = GetPlayerWeaponSlot(blu_f2, i);

                    if (IsValidEntity(ent))
                        SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + float(g_iArenaCd[arena_index]));
                }
            }

            if (g_iArenaCd[arena_index] <= 3 && g_iArenaCd[arena_index] >= 1)
            {
                char msg[64];

                switch (g_iArenaCd[arena_index])
                {
                    case 1:msg = "ONE";
                    case 2:msg = "TWO";
                    case 3:msg = "THREE";
                }

                PrintCenterText(red_f1, msg);
                PrintCenterText(blu_f1, msg);
                PrintCenterText(red_f2, msg);
                PrintCenterText(blu_f2, msg);
                ShowCountdownToSpec(arena_index, msg);
                g_iArenaStatus[arena_index] = AS_COUNTDOWN;
            } else if (g_iArenaCd[arena_index] <= 0) {
                g_iArenaStatus[arena_index] = AS_FIGHT;
                g_iArenaDuelStartTime[arena_index] = GetTime(); // Capture duel start time
                char msg[64];
                Format(msg, sizeof(msg), "FIGHT", g_iArenaCd[arena_index]);
                PrintCenterText(red_f1, msg);
                PrintCenterText(blu_f1, msg);
                PrintCenterText(red_f2, msg);
                PrintCenterText(blu_f2, msg);
                ShowCountdownToSpec(arena_index, msg);

                //For bball.
                if (g_bArenaBBall[arena_index])
                {
                    ResetIntel(arena_index);
                }

                return Plugin_Stop;
            }


            CreateTimer(1.0, Timer_CountDown, arena_index, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            return Plugin_Stop;
        } else {
            if (g_bFourPersonArena[arena_index])
            {
                Restore2v2WaitingSpectators(arena_index);
            }
            g_iArenaStatus[arena_index] = AS_IDLE;
            g_iArenaCd[arena_index] = 0;
            return Plugin_Stop;
        }
    }
    else
    {
        if (red_f1 && blu_f1)
        {
            g_iArenaCd[arena_index]--;

            if (g_iArenaCd[arena_index] > 0)
            {  // blocking +attack
                float enginetime = GetGameTime();

                for (int i = 0; i <= 2; i++)
                {
                    int ent = GetPlayerWeaponSlot(red_f1, i);

                    if (IsValidEntity(ent))
                        SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + float(g_iArenaCd[arena_index]));

                    ent = GetPlayerWeaponSlot(blu_f1, i);

                    if (IsValidEntity(ent))
                        SetEntPropFloat(ent, Prop_Send, "m_flNextPrimaryAttack", enginetime + float(g_iArenaCd[arena_index]));
                }
            }

            if (g_iArenaCd[arena_index] <= 3 && g_iArenaCd[arena_index] >= 1)
            {
                char msg[64];

                switch (g_iArenaCd[arena_index])
                {
                    case 1:msg = "ONE";
                    case 2:msg = "TWO";
                    case 3:msg = "THREE";
                }

                PrintCenterText(red_f1, msg);
                PrintCenterText(blu_f1, msg);
                ShowCountdownToSpec(arena_index, msg);
                g_iArenaStatus[arena_index] = AS_COUNTDOWN;
            } else if (g_iArenaCd[arena_index] <= 0) {
                g_iArenaStatus[arena_index] = AS_FIGHT;
                g_iArenaDuelStartTime[arena_index] = GetTime(); // Capture duel start time
                char msg[64];
                Format(msg, sizeof(msg), "FIGHT", g_iArenaCd[arena_index]);
                PrintCenterText(red_f1, msg);
                PrintCenterText(blu_f1, msg);
                ShowCountdownToSpec(arena_index, msg);

                //For bball.
                if (g_bArenaBBall[arena_index])
                {
                    ResetIntel(arena_index);
                }
                return Plugin_Stop;
            }

            CreateTimer(1.0, Timer_CountDown, arena_index, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            return Plugin_Stop;
        } else {
            g_iArenaStatus[arena_index] = AS_IDLE;
            g_iArenaCd[arena_index] = 0;
            return Plugin_Stop;
        }
    }
    // unreachable
    // return Plugin_Continue;
}

Action Timer_Tele(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    int arena_index = g_iPlayerArena[client];

    if (!arena_index)
        return Plugin_Continue;

    int player_slot = g_iPlayerSlot[client];
    if ((!g_bFourPersonArena[arena_index] && player_slot > SLOT_TWO) || (g_bFourPersonArena[arena_index] && player_slot > SLOT_FOUR))
    {
        return Plugin_Continue;
    }

    float vel[3] =  { 0.0, 0.0, 0.0 };


    // CHECK FOR MANNTREADS IN ENDIF
    if (g_bArenaEndif[arena_index])
    {
        // loop thru client's wearable entities. not adding gamedata for this shiz
        int i = -1;
        while ((i = FindEntityByClassname(i, "tf_wearable*")) != -1)
        {
            if (client != GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity"))
            {
                continue;
            }
            int itemdef = GetEntProp(i, Prop_Send, "m_iItemDefinitionIndex");
            // manntreads itemdef
            if (itemdef == 444)
            {
                // just in case.
                RemoveEntity(i);
                PrintToChat(client, "[MGE] Arena = EndIf and you have the Manntreads. Automatically removing you from the queue.");
                // run elo calc so clients can't be cheeky if they're losing
                RemoveFromQueue(client, true);
            }
        }
    }


    // BBall and 2v2 arenas handle spawns differently, each team, has their own spawns.
    if (g_bArenaBBall[arena_index])
    {
        int random_int;
        int offset_high, offset_low;
        if (g_iPlayerSlot[client] == SLOT_ONE || g_iPlayerSlot[client] == SLOT_THREE)
        {
            offset_high = ((g_iArenaSpawns[arena_index] - 5) / 2);
            random_int = GetRandomInt(1, offset_high); //The first half of the player spawns are for slot one and three.
        } else {
            offset_high = (g_iArenaSpawns[arena_index] - 5);
            offset_low = (((g_iArenaSpawns[arena_index] - 5) / 2) + 1);
            random_int = GetRandomInt(offset_low, offset_high); //The last 5 spawns are for the intel and trigger spawns, not players.
        }

        TeleportEntity(client, g_fArenaSpawnOrigin[arena_index][random_int], g_fArenaSpawnAngles[arena_index][random_int], vel);
        EmitAmbientSound("items/spawn_item.wav", g_fArenaSpawnOrigin[arena_index][random_int], _, SNDLEVEL_NORMAL, _, 1.0);
        ShowPlayerHud(client);
        return Plugin_Continue;
    }
    else if (g_bArenaKoth[arena_index])
    {
        int random_int;
        int offset_high, offset_low;
        if (g_iPlayerSlot[client] == SLOT_ONE || g_iPlayerSlot[client] == SLOT_THREE)
        {
            offset_high = ((g_iArenaSpawns[arena_index] - 1) / 2);
            random_int = GetRandomInt(1, offset_high); //The first half of the player spawns are for slot one and three.
        } else {
            offset_high = (g_iArenaSpawns[arena_index] - 1);
            offset_low = (((g_iArenaSpawns[arena_index] + 1) / 2));
            random_int = GetRandomInt(offset_low, offset_high); //The last spawn is for the point
        }

        TeleportEntity(client, g_fArenaSpawnOrigin[arena_index][random_int], g_fArenaSpawnAngles[arena_index][random_int], vel);
        EmitAmbientSound("items/spawn_item.wav", g_fArenaSpawnOrigin[arena_index][random_int], _, SNDLEVEL_NORMAL, _, 1.0);
        ShowPlayerHud(client);
        return Plugin_Continue;
    }
    else if (g_bFourPersonArena[arena_index])
    {
        int random_int;
        int offset_high, offset_low;
        if (g_iPlayerSlot[client] == SLOT_ONE || g_iPlayerSlot[client] == SLOT_THREE)
        {
            offset_high = ((g_iArenaSpawns[arena_index]) / 2);
            random_int = GetRandomInt(1, offset_high); //The first half of the player spawns are for slot one and three.
        } else {
            offset_high = (g_iArenaSpawns[arena_index]);
            offset_low = (((g_iArenaSpawns[arena_index]) / 2) + 1);
            random_int = GetRandomInt(offset_low, offset_high);
        }

        TeleportEntity(client, g_fArenaSpawnOrigin[arena_index][random_int], g_fArenaSpawnAngles[arena_index][random_int], vel);
        EmitAmbientSound("items/spawn_item.wav", g_fArenaSpawnOrigin[arena_index][random_int], _, SNDLEVEL_NORMAL, _, 1.0);
        ShowPlayerHud(client);
        return Plugin_Continue;
    }

    // Create an array that can hold all the arena's spawns.
    int[] RandomSpawn = new int[g_iArenaSpawns[arena_index] + 1];

    // Fill the array with the spawns.
    for (int i = 0; i < g_iArenaSpawns[arena_index]; i++)
    RandomSpawn[i] = i + 1;

    // Shuffle them into a random order.
    SortIntegers(RandomSpawn, g_iArenaSpawns[arena_index], Sort_Random);

    // Now when the array is gone through sequentially, it will still provide a random spawn.
    float besteffort_dist;
    int besteffort_spawn;
    for (int i = 0; i < g_iArenaSpawns[arena_index]; i++)
    {
        int client_slot = g_iPlayerSlot[client];
        int foe_slot = (client_slot == SLOT_ONE || client_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
        if (foe_slot)
        {
            float distance;
            int foe = g_iArenaQueue[arena_index][foe_slot];
            if (IsValidClient(foe))
            {
                float foe_pos[3];
                GetClientAbsOrigin(foe, foe_pos);
                distance = GetVectorDistance(foe_pos, g_fArenaSpawnOrigin[arena_index][RandomSpawn[i]]);
                if (distance > g_fArenaMinSpawnDist[arena_index])
                {
                    TeleportEntity(client, g_fArenaSpawnOrigin[arena_index][RandomSpawn[i]], g_fArenaSpawnAngles[arena_index][RandomSpawn[i]], vel);
                    EmitAmbientSound("items/spawn_item.wav", g_fArenaSpawnOrigin[arena_index][RandomSpawn[i]], _, SNDLEVEL_NORMAL, _, 1.0);
                    ShowPlayerHud(client);
                    return Plugin_Continue;
                } else if (distance > besteffort_dist) {
                    besteffort_dist = distance;
                    besteffort_spawn = i;
                }
            }
        }
    }

    if (besteffort_spawn)
    {
        // Couldn't find a spawn that was far enough away, so use the one that was the farthest.
        TeleportEntity(client, g_fArenaSpawnOrigin[arena_index][besteffort_spawn], g_fArenaSpawnAngles[arena_index][besteffort_spawn], vel);
        EmitAmbientSound("items/spawn_item.wav", g_fArenaSpawnOrigin[arena_index][besteffort_spawn], _, SNDLEVEL_NORMAL, _, 1.0);
        ShowPlayerHud(client);
        return Plugin_Continue;
    } else {
        // No foe, so just pick a random spawn.
        int random_int = GetRandomInt(1, g_iArenaSpawns[arena_index]);
        TeleportEntity(client, g_fArenaSpawnOrigin[arena_index][random_int], g_fArenaSpawnAngles[arena_index][random_int], vel);
        EmitAmbientSound("items/spawn_item.wav", g_fArenaSpawnOrigin[arena_index][random_int], _, SNDLEVEL_NORMAL, _, 1.0);
        ShowPlayerHud(client);
        return Plugin_Continue;
    }
    // unreachable
    // return Plugin_Continue;
}

Action Timer_NewRound(Handle timer, any arena_index)
{
    StartCountDown(arena_index);

    return Plugin_Continue;
}

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

Action Timer_StartDuel(Handle timer, any arena_index)
{
    ResetArena(arena_index);

    if (g_bArenaTurris[arena_index])
    {
        CreateTimer(5.0, Timer_RegenArena, arena_index, TIMER_REPEAT);
    }
    if (g_bArenaKoth[arena_index])
    {

        g_bPlayerTouchPoint[arena_index][SLOT_ONE] = false;
        g_bPlayerTouchPoint[arena_index][SLOT_TWO] = false;
        g_bPlayerTouchPoint[arena_index][SLOT_THREE] = false;
        g_bPlayerTouchPoint[arena_index][SLOT_FOUR] = false;
        g_iKothTimer[arena_index][0] = 0;
        g_iKothTimer[arena_index][1] = 0;
        g_iKothTimer[arena_index][TEAM_RED] = g_iDefaultCapTime[arena_index];
        g_iKothTimer[arena_index][TEAM_BLU] = g_iDefaultCapTime[arena_index];
        g_iCappingTeam[arena_index] = NEUTRAL;
        g_iPointState[arena_index] = NEUTRAL;
        g_fTotalTime[arena_index] = 0.0;
        g_fCappedTime[arena_index] = 0.0;
        g_fKothCappedPercent[arena_index] = 0.0;
        g_bOvertimePlayed[arena_index][TEAM_RED] = false;
        g_bOvertimePlayed[arena_index][TEAM_BLU] = false;
        g_tKothTimer[arena_index] = CreateTimer(1.0, Timer_CountDownKoth, arena_index, TIMER_REPEAT);
        g_bTimerRunning[arena_index] = true;
    }

    g_iArenaScore[arena_index][SLOT_ONE] = 0;
    g_iArenaScore[arena_index][SLOT_TWO] = 0;
    g_iArenaDuelStartTime[arena_index] = 0; // Reset duel start time
    ShowPlayerHud(g_iArenaQueue[arena_index][SLOT_ONE]);
    ShowPlayerHud(g_iArenaQueue[arena_index][SLOT_TWO]);

    if (g_bFourPersonArena[arena_index])
    {
        ShowPlayerHud(g_iArenaQueue[arena_index][SLOT_THREE]);
        ShowPlayerHud(g_iArenaQueue[arena_index][SLOT_FOUR]);
    }

    ShowSpecHudToArena(arena_index);

    StartCountDown(arena_index);

    return Plugin_Continue;
}

Action Timer_ResetPlayer(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (IsValidClient(client))
    {
        ResetPlayer(client);
    }
    
    return Plugin_Continue;
}

Action Timer_ChangePlayerSpec(Handle timer, any player)
{
    if (IsValidClient(player) && !IsPlayerAlive(player))
    {
        ChangeClientTeam(player, TEAM_SPEC);
    }
    
    return Plugin_Continue;
}

Action Timer_ChangeSpecTarget(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (!IsValidClient(client))
    {
        return Plugin_Stop;
    }

    int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

    if (IsValidClient(target) && g_iPlayerArena[target])
    {
        g_iPlayerSpecTarget[client] = target;
        ShowSpecHudToClient(client);
    }
    else
    {
        HideHud(client);
        g_iPlayerSpecTarget[client] = 0;
    }

    return Plugin_Stop;
}

Action Timer_ShowAdv(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (IsValidClient(client) && g_iPlayerArena[client] == 0)
    {
        MC_PrintToChat(client, "%t", "Adv");
        CreateTimer(15.0, Timer_ShowAdv, userid);
    }

    return Plugin_Continue;
}

Action Timer_GiveAmmo(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!client || !IsValidEntity(client))
        return Plugin_Continue;

    g_bPlayerRestoringAmmo[client] = false;

    int weapon;

    if (g_iPlayerClip[client][SLOT_ONE] != -1)
    {
        weapon = GetPlayerWeaponSlot(client, 0);

        if (IsValidEntity(weapon))
            SetEntProp(weapon, Prop_Send, "m_iClip1", g_iPlayerClip[client][SLOT_ONE]);
    }

    if (g_iPlayerClip[client][SLOT_TWO] != -1)
    {
        weapon = GetPlayerWeaponSlot(client, 1);

        if (IsValidEntity(weapon))
            SetEntProp(weapon, Prop_Send, "m_iClip1", g_iPlayerClip[client][SLOT_TWO]);
    }

    return Plugin_Continue;
}

/*
Action Timer_DeleteParticle(Handle timer, any particle)
{
    if (IsValidEdict(particle))
    {
        char classname[64];
        GetEdictClassname(particle, classname, sizeof(classname));

        if (StrEqual(classname, "info_particle_system", false))
        {
            RemoveEdict(particle);
        }
    }

    return Plugin_Continue;
}
*/

Action Timer_AddBotInQueue(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());
    int arena_index = pack.ReadCell();
    AddInQueue(client, arena_index);

    return Plugin_Continue;
}

Action Timer_ResetSwap(Handle timer, int client)
{
    g_bCanPlayerSwap[client] = true;

    return Plugin_Continue;
}

Action Timer_ReconnectToDB(Handle timer)
{
    g_hDBReconnectTimer = null;

    char query[256];
    Format(query, sizeof(query), "SELECT rating FROM mgemod_stats LIMIT 1");
    g_DB.Query(SQLDbConnTest, query);

    return Plugin_Continue;
}

Action Timer_CountDownKoth(Handle timer, any arena_index)
{
    //If there was time spent on the point/time spent reverting the point add/remove perecent to the point for however long they were/n't standing on it
    if (g_fCappedTime[arena_index] != 0)
    {
        if (g_fKothCappedPercent[arena_index] == 0 && g_fCappedTime[arena_index] > 0)
        {
            int red_1 = g_iArenaQueue[arena_index][SLOT_ONE];
            int blu_1 = g_iArenaQueue[arena_index][SLOT_TWO];
            char SoundFileTemp[64];
            int num = GetRandomInt(1, 3);
            if (num == 1)
            {
                SoundFileTemp = "vo/announcer_control_point_warning.wav";
            }
            else if (num == 2)
            {
                SoundFileTemp = "vo/announcer_control_point_warning2.wav";
            }
            else
            {
                SoundFileTemp = "vo/announcer_control_point_warning3.wav";
            }

            if (g_iCappingTeam[arena_index] == TEAM_BLU)
            {
                if (IsValidClient(red_1))
                    EmitSoundToClient(red_1, SoundFileTemp);
            }
            else
            {
                if (IsValidClient(blu_1))
                    EmitSoundToClient(blu_1, SoundFileTemp);
            }

            if (g_bFourPersonArena[arena_index])
            {
                int red_2 = g_iArenaQueue[arena_index][SLOT_THREE];
                int blu_2 = g_iArenaQueue[arena_index][SLOT_FOUR];
                if (g_iCappingTeam[arena_index] == TEAM_BLU)
                {
                    if (IsValidClient(red_2))
                        EmitSoundToClient(red_2, SoundFileTemp);
                }
                else
                {
                    if (IsValidClient(blu_2))
                        EmitSoundToClient(blu_2, SoundFileTemp);
                }
            }

        }
        if (g_fTotalTime[arena_index] != 0)
        {
            float cap = (g_fCappedTime[arena_index] * 8.4) / g_fTotalTime[arena_index];
            if (!g_bArenaUltiduo[arena_index])
                cap = cap * 1.5;
            g_fKothCappedPercent[arena_index] += cap;
        }

        g_fCappedTime[arena_index] = 0.0;
    }
    g_fTotalTime[arena_index] = 0.0;
    //If the cap is below 0 then reset it to 0
    if (g_fKothCappedPercent[arena_index] <= 0)
    {
        g_fKothCappedPercent[arena_index] = 0.0;

        if (g_iPointState[arena_index] == NEUTRAL)
            g_iCappingTeam[arena_index] = NEUTRAL;
    }

    if (g_fKothCappedPercent[arena_index] >= 100)
    {
        int red1, red2, blu1, blu2;
        if (g_bFourPersonArena[arena_index])
        {
            red1 = g_iArenaQueue[arena_index][SLOT_ONE];
            red2 = g_iArenaQueue[arena_index][SLOT_THREE];
            blu1 = g_iArenaQueue[arena_index][SLOT_TWO];
            blu2 = g_iArenaQueue[arena_index][SLOT_FOUR];
            if (g_iPointState[arena_index] == TEAM_RED)
            {
                if (IsValidClient(red1))
                    EmitSoundToClient(red1, "vo/announcer_we_lost_control.wav");
                if (IsValidClient(red2))
                    EmitSoundToClient(red2, "vo/announcer_we_lost_control.wav");
                if (IsValidClient(blu1))
                    EmitSoundToClient(blu1, "vo/announcer_we_captured_control.wav");
                if (IsValidClient(blu2))
                    EmitSoundToClient(blu2, "vo/announcer_we_captured_control.wav");

                g_iCappingTeam[arena_index] = TEAM_RED;
                g_iPointState[arena_index] = TEAM_BLU;
            }

            else if (g_iPointState[arena_index] == TEAM_BLU)
            {
                if (IsValidClient(red1))
                    EmitSoundToClient(red1, "vo/announcer_we_captured_control.wav");
                if (IsValidClient(red2))
                    EmitSoundToClient(red2, "vo/announcer_we_captured_control.wav");
                if (IsValidClient(blu1))
                    EmitSoundToClient(blu1, "vo/announcer_we_lost_control.wav");
                if (IsValidClient(blu2))
                    EmitSoundToClient(blu2, "vo/announcer_we_lost_control.wav");
                g_iCappingTeam[arena_index] = TEAM_BLU;
                g_iPointState[arena_index] = TEAM_RED;
            }


            else
            {
                if (g_iCappingTeam[arena_index] == TEAM_RED)
                {
                    EmitSoundToClient(red1, "vo/announcer_we_captured_control.wav");
                    EmitSoundToClient(red2, "vo/announcer_we_captured_control.wav");
                    g_iPointState[arena_index] = TEAM_RED;
                    g_iCappingTeam[arena_index] = TEAM_BLU;
                }
                else
                {
                    EmitSoundToClient(blu1, "vo/announcer_we_captured_control.wav");
                    EmitSoundToClient(blu2, "vo/announcer_we_captured_control.wav");
                    g_iPointState[arena_index] = TEAM_BLU;
                    g_iCappingTeam[arena_index] = TEAM_RED;
                }
            }
        }
        else
        {
            red1 = g_iArenaQueue[arena_index][SLOT_ONE];
            blu1 = g_iArenaQueue[arena_index][SLOT_TWO];
            if (g_iPointState[arena_index] == TEAM_RED)
            {
                EmitSoundToClient(red1, "vo/announcer_we_lost_control.wav");
                EmitSoundToClient(blu1, "vo/announcer_we_captured_control.wav");
                g_iCappingTeam[arena_index] = TEAM_RED;
                g_iPointState[arena_index] = TEAM_BLU;
            }

            else if (g_iPointState[arena_index] == TEAM_BLU)
            {
                EmitSoundToClient(red1, "vo/announcer_we_captured_control.wav");
                EmitSoundToClient(blu1, "vo/announcer_we_lost_control.wav");
                g_iCappingTeam[arena_index] = TEAM_BLU;
                g_iPointState[arena_index] = TEAM_RED;
            }


            else
            {
                if (g_iCappingTeam[arena_index] == TEAM_RED)
                {
                    EmitSoundToClient(red1, "vo/announcer_we_captured_control.wav");
                    g_iPointState[arena_index] = TEAM_RED;
                    g_iCappingTeam[arena_index] = TEAM_BLU;
                }
                else
                {
                    EmitSoundToClient(blu1, "vo/announcer_we_captured_control.wav");
                    g_iPointState[arena_index] = TEAM_BLU;
                    g_iCappingTeam[arena_index] = TEAM_RED;
                }
            }
        }

        g_fKothCappedPercent[arena_index] = 0.0;
    }
    else if (g_iKothTimer[arena_index][g_iPointState[arena_index]] > 0)
    {
        g_iKothTimer[arena_index][g_iPointState[arena_index]]--;
    }

    if (g_iArenaQueue[arena_index][SLOT_ONE])
        ShowPlayerHud(g_iArenaQueue[arena_index][SLOT_ONE]);
    if (g_iArenaQueue[arena_index][SLOT_ONE])
        ShowPlayerHud(g_iArenaQueue[arena_index][SLOT_TWO]);

    if (g_bFourPersonArena[arena_index])
    {
        ShowPlayerHud(g_iArenaQueue[arena_index][SLOT_THREE]);
        ShowPlayerHud(g_iArenaQueue[arena_index][SLOT_FOUR]);
    }

    if (g_iArenaStatus[arena_index] > AS_FIGHT)
    {
        g_bTimerRunning[arena_index] = false;
        return Plugin_Stop;
    }

    //Play the count down sounds
    if (g_iKothTimer[arena_index][g_iPointState[arena_index]] <= 5 && g_iKothTimer[arena_index][g_iPointState[arena_index]] > 0)
    {
        char SoundFile[64];
        switch (g_iKothTimer[arena_index][g_iPointState[arena_index]])
        {
            case 5:
            SoundFile = "vo/announcer_ends_5sec.wav";
            case 4:
            SoundFile = "vo/announcer_ends_4sec.wav";
            case 3:
            SoundFile = "vo/announcer_ends_3sec.wav";
            case 2:
            SoundFile = "vo/announcer_ends_2sec.wav";
            case 1:
            SoundFile = "vo/announcer_ends_1sec.wav";
            default:
            SoundFile = "vo/announcer_ends_5sec.wav";
        }

        if (g_bFourPersonArena[arena_index])
        {
            int red1 = g_iArenaQueue[arena_index][SLOT_ONE];
            int red2 = g_iArenaQueue[arena_index][SLOT_THREE];
            int blu1 = g_iArenaQueue[arena_index][SLOT_TWO];
            int blu2 = g_iArenaQueue[arena_index][SLOT_FOUR];
            EmitSoundToClient(blu1, SoundFile);
            EmitSoundToClient(blu2, SoundFile);
            EmitSoundToClient(red1, SoundFile);
            EmitSoundToClient(red2, SoundFile);
        }
        else
        {
            int red1 = g_iArenaQueue[arena_index][SLOT_ONE];
            int blu1 = g_iArenaQueue[arena_index][SLOT_TWO];
            EmitSoundToClient(blu1, SoundFile);
            EmitSoundToClient(red1, SoundFile);
        }
    }

    //If the point is capped, the timer for the capped team is out and the other team is not touching the point and has no cap time on the point, end the game.
    if (g_iPointState[arena_index] > NEUTRAL && g_iKothTimer[arena_index][g_iPointState[arena_index]] <= 0 && g_fKothCappedPercent[arena_index] <= 0 && !EnemyTeamTouching(g_iPointState[arena_index], arena_index))
    {
        g_bTimerRunning[arena_index] = false;
        //I know this is shit but fuck the police
        EndKoth(arena_index, g_iPointState[arena_index] - 1);
        return Plugin_Stop;
    }
    //If the time is at 0 and a team owns the point and OT hasn't been played already tell the arena it's OT
    if (g_iPointState[arena_index] > NEUTRAL && g_iKothTimer[arena_index][g_iPointState[arena_index]] == 0)
    {
        //Fixes the infinite OT sound bug, so "Overtime!" only gets played once
        if (!g_bOvertimePlayed[arena_index][g_iPointState[arena_index]])
        {

            char SoundFileTemp[64];
            int red1 = g_iArenaQueue[arena_index][SLOT_ONE];
            int blu1 = g_iArenaQueue[arena_index][SLOT_TWO];

            switch (GetRandomInt(1, 4))
            {
                case 1: SoundFileTemp = "vo/announcer_overtime.wav";
                case 2: SoundFileTemp = "vo/announcer_overtime2.wav";
                case 3: SoundFileTemp = "vo/announcer_overtime3.wav";
                case 4: SoundFileTemp = "vo/announcer_overtime4.wav";
            }

            EmitSoundToClient(blu1, SoundFileTemp);
            EmitSoundToClient(red1, SoundFileTemp);

            if (g_bFourPersonArena[arena_index])
            {
                int blu2 = g_iArenaQueue[arena_index][SLOT_FOUR];
                int red2 = g_iArenaQueue[arena_index][SLOT_THREE];
                EmitSoundToClient(red2, SoundFileTemp);
                EmitSoundToClient(blu2, SoundFileTemp);
            }
            //the overtime sound has been played for this team and doesn't need to be played again for the rest of the round
            g_bOvertimePlayed[arena_index][g_iPointState[arena_index]] = true;
        }
    }

    return Plugin_Continue;
}

Action Timer_RegenArena(Handle timer, any arena_index)
{
    if (g_iArenaStatus[arena_index] != AS_FIGHT)
        return Plugin_Stop;

    int client = g_iArenaQueue[arena_index][SLOT_ONE];
    int client2 = g_iArenaQueue[arena_index][SLOT_TWO];

    if (IsPlayerAlive(client))
    {
        TF2_RegeneratePlayer(client);
        int raised_hp = RoundToNearest(float(g_iPlayerMaxHP[client]) * g_fArenaHPRatio[arena_index]);
        g_iPlayerHP[client] = raised_hp;
        SetEntProp(client, Prop_Data, "m_iHealth", raised_hp);
    }

    if (IsPlayerAlive(client2))
    {
        TF2_RegeneratePlayer(client2);
        int raised_hp2 = RoundToNearest(float(g_iPlayerMaxHP[client2]) * g_fArenaHPRatio[arena_index]);
        g_iPlayerHP[client2] = raised_hp2;
        SetEntProp(client2, Prop_Data, "m_iHealth", raised_hp2);
    }

    if (g_bFourPersonArena[arena_index])
    {
        int client3 = g_iArenaQueue[arena_index][SLOT_THREE];
        int client4 = g_iArenaQueue[arena_index][SLOT_FOUR];
        if (IsPlayerAlive(client3))
        {
            TF2_RegeneratePlayer(client3);
            int raised_hp3 = RoundToNearest(float(g_iPlayerMaxHP[client3]) * g_fArenaHPRatio[arena_index]);
            g_iPlayerHP[client3] = raised_hp3;
            SetEntProp(client3, Prop_Data, "m_iHealth", raised_hp3);
        }
        if (IsPlayerAlive(client4))
        {
            TF2_RegeneratePlayer(client4);
            int raised_hp4 = RoundToNearest(float(g_iPlayerMaxHP[client4]) * g_fArenaHPRatio[arena_index]);
            g_iPlayerHP[client4] = raised_hp4;
            SetEntProp(client4, Prop_Data, "m_iHealth", raised_hp4);
        }
    }

    return Plugin_Continue;
}

/*
** ------------------------------------------------------------------
**      __  ____
**     /  |/  (_)__________
**    / /|_/ / // ___/ ___/
**   / /  / / /(__  ) /__
**  /_/  /_/_//____/\___/
**
** ------------------------------------------------------------------
**/

/* TraceEntityFilterPlayer()
 *
 * Ignores players.
 * -------------------------------------------------------------------------- */
bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
    return entity > MaxClients || !entity;
}

/* TraceEntityPlayersOnly()
 *
 * Returns only players.
 * -------------------------------------------------------------------------- */
/*
bool TraceEntityPlayersOnly(int entity, int mask, int client)
{
    if (IsValidClient(entity) && entity != client)
    {
        PrintToChatAll("returning true for %d<%N>", entity, entity);
        return true;
    } else {
        PrintToChatAll("returning false for %d<%N>", entity, entity);
        return false;
    }
}
*/

/* IsValidClient()
 *
 * Checks if a client is valid.
 * -------------------------------------------------------------------------- */
bool IsValidClient(int iClient, bool bIgnoreKickQueue = false)
{
    if
    (
        // "client" is 0 (console) or lower - nope!
            0 >= iClient
        // "client" is higher than MaxClients - nope!
        || MaxClients < iClient
        // "client" isnt in game aka their entity hasn't been created - nope!
        || !IsClientInGame(iClient)
        // "client" is in the kick queue - nope!
        || (IsClientInKickQueue(iClient) && !bIgnoreKickQueue)
        // "client" is sourcetv - nope!
        || IsClientSourceTV(iClient)
        // "client" is the replay bot - nope!
        || IsClientReplay(iClient)
    )
    {
        return false;
    }
    return true;
}

/* ShootsRocketsOrPipes()
 *
 * Does this player's gun shoot rockets or pipes?
 * -------------------------------------------------------------------------- */
bool ShootsRocketsOrPipes(int client)
{
    char weapon[64];
    GetClientWeapon(client, weapon, sizeof(weapon));
    return (StrContains(weapon, "tf_weapon_rocketlauncher") == 0) || StrEqual(weapon, "tf_weapon_grenadelauncher");
}

/* DistanceAboveGround()
 *
 * How high off the ground is the player?
 * -------------------------------------------------------------------------- */
float DistanceAboveGround(int victim)
{
    float vStart[3];
    float vEnd[3];
    float vAngles[3] =  { 90.0, 0.0, 0.0 };
    GetClientAbsOrigin(victim, vStart);
    Handle trace = TR_TraceRayFilterEx(vStart, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer);

    float distance = -1.0;
    if (TR_DidHit(trace))
    {
        TR_GetEndPosition(vEnd, trace);
        distance = GetVectorDistance(vStart, vEnd, false);
    } else {
        LogError("trace error. victim %N(%d)", victim, victim);
    }

    delete trace;
    return distance;
}

/* DistanceAboveGroundAroundUser()
 *
 * How high off the ground is the player?
 *This is used for dropping
 * -------------------------------------------------------------------------- */

 // i highly suspect this also needs a switch case rewrite lol

float DistanceAboveGroundAroundPlayer(int victim)
{
    float vStart[3];
    float vEnd[3];
    float vAngles[3] =  { 90.0, 0.0, 0.0 };
    GetClientAbsOrigin(victim, vStart);
    float minDist;

    for (int i = 0; i < 5; ++i)
    {
        float tvStart[3];
        tvStart = vStart;
        float tempDist = -1.0;
        if (i == 0)
        {
            Handle trace = TR_TraceRayFilterEx(vStart, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer);

            if (TR_DidHit(trace))
            {
                TR_GetEndPosition(vEnd, trace);
                minDist = GetVectorDistance(vStart, vEnd, false);
            } else {
                LogError("trace error. victim %N(%d)", victim, victim);
            }
            delete trace;
        }
        else if (i == 1)
        {
            tvStart[0] = tvStart[0] + 10;
            Handle trace = TR_TraceRayFilterEx(tvStart, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer);

            if (TR_DidHit(trace))
            {
                TR_GetEndPosition(vEnd, trace);
                tempDist = GetVectorDistance(tvStart, vEnd, false);
            } else {
                LogError("trace error. victim %N(%d)", victim, victim);
            }
            delete trace;
        }
        else if (i == 2)
        {
            tvStart[0] = tvStart[0] - 10;
            Handle trace = TR_TraceRayFilterEx(tvStart, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer);

            if (TR_DidHit(trace))
            {
                TR_GetEndPosition(vEnd, trace);
                tempDist = GetVectorDistance(tvStart, vEnd, false);
            } else {
                LogError("trace error. victim %N(%d)", victim, victim);
            }
            delete trace;
        }
        else if (i == 3)
        {
            tvStart[1] = vStart[1] + 10;
            Handle trace = TR_TraceRayFilterEx(tvStart, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer);

            if (TR_DidHit(trace))
            {
                TR_GetEndPosition(vEnd, trace);
                tempDist = GetVectorDistance(tvStart, vEnd, false);
            } else {
                LogError("trace error. victim %N(%d)", victim, victim);
            }
            delete trace;
        }
        else if (i == 4)
        {
            tvStart[1] = vStart[1] - 10;
            Handle trace = TR_TraceRayFilterEx(tvStart, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer);

            if (TR_DidHit(trace))
            {
                TR_GetEndPosition(vEnd, trace);
                tempDist = GetVectorDistance(tvStart, vEnd, false);
            } else {
                LogError("trace error. victim %N(%d)", victim, victim);
            }
            delete trace;
        }

        if ((tempDist > -1 && tempDist < minDist) || minDist == -1)
        {
            minDist = tempDist;
        }
    }

    return minDist;
}

/* FindEntityByClassname2()
 *
 * Finds entites, and won't error out when searching invalid entities.
 * -------------------------------------------------------------------------- */
stock int FindEntityByClassname2(int startEnt, const char[] classname)
{
    /* If startEnt isn't valid shifting it back to the nearest valid one */
    while (startEnt > -1 && !IsValidEntity(startEnt))startEnt--;

    return FindEntityByClassname(startEnt, classname);
}

/* getTeammate()
 *
 * Gets a clients teammate if he's in a 4 player arena
 * This can actually be replaced by g_iArenaQueue[SLOT_X] but I didn't realize that array existed, so YOLO
 *---------------------------------------------------------------------*/
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


/*  EndUlitduo(any arena_index, any winner_team)
*
* Called when someone wins an ultiduo round
* --------------------------------------------------------------------------- */
void EndKoth(any arena_index, any winner_team)
{

    PlayEndgameSoundsToArena(arena_index, winner_team);
    g_iArenaScore[arena_index][winner_team] += 1;
    int fraglimit = g_iArenaFraglimit[arena_index];
    int client = g_iArenaQueue[arena_index][winner_team];
    int client_slot = winner_team;
    int foe_slot = (client_slot == SLOT_ONE || client_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
    int foe = g_iArenaQueue[arena_index][foe_slot];
    int client_teammate;
    int foe_teammate;

    //End the Timer if its still running
    //You shouldn't need to do this, but just incase
    if (g_bTimerRunning[arena_index])
    {
        delete g_tKothTimer[arena_index];
        g_bTimerRunning[arena_index] = false;
    }

    if (g_bFourPersonArena[arena_index])
    {
        client_teammate = getTeammate(client_slot, arena_index);
        foe_teammate = getTeammate(foe_slot, arena_index);
    }

    if (fraglimit > 0 && g_iArenaScore[arena_index][winner_team] >= fraglimit && g_iArenaStatus[arena_index] >= AS_FIGHT && g_iArenaStatus[arena_index] < AS_REPORTED)
    {
        g_iArenaStatus[arena_index] = AS_REPORTED;
        char foe_name[MAX_NAME_LENGTH];
        GetClientName(foe, foe_name, sizeof(foe_name));
        char client_name[MAX_NAME_LENGTH];
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

        MC_PrintToChatAll("%t", "XdefeatsY", client_name, g_iArenaScore[arena_index][winner_team], foe_name, g_iArenaScore[arena_index][foe_slot], fraglimit, g_sArenaName[arena_index]);

        if (!g_bNoStats && !g_bFourPersonArena[arena_index])
            CalcELO(client, foe);

        else if (!g_bNoStats)
            CalcELO2(client, client_teammate, foe, foe_teammate);

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
            // For 2v2 arenas, return to ready state instead of restarting immediately
            if (g_bFourPersonArena[arena_index])
            {
                CreateTimer(3.0, Timer_Restart2v2Ready, arena_index);
            }
            else
            {
                CreateTimer(3.0, Timer_StartDuel, arena_index);
            }
        }
    } else {
        ResetArena(arena_index);

        ResetPlayer(client);
        ResetPlayer(foe);

        if (g_bFourPersonArena[arena_index])
        {
            ResetPlayer(client_teammate);
            ResetPlayer(foe_teammate);
        }

        g_bPlayerTouchPoint[arena_index][SLOT_ONE] = false;
        g_bPlayerTouchPoint[arena_index][SLOT_TWO] = false;
        g_bPlayerTouchPoint[arena_index][SLOT_THREE] = false;
        g_bPlayerTouchPoint[arena_index][SLOT_FOUR] = false;
        g_iKothTimer[arena_index][TEAM_RED] = g_iDefaultCapTime[arena_index];
        g_iKothTimer[arena_index][TEAM_BLU] = g_iDefaultCapTime[arena_index];
        g_fKothCappedPercent[arena_index] = 0.0;
        g_iCappingTeam[arena_index] = NEUTRAL;
        g_iPointState[arena_index] = NEUTRAL;
        g_fCappedTime[arena_index] = 0.0;
        g_bOvertimePlayed[arena_index][TEAM_RED] = false;
        g_bOvertimePlayed[arena_index][TEAM_BLU] = false;
        g_tKothTimer[arena_index] = CreateTimer(1.0, Timer_CountDownKoth, arena_index, TIMER_REPEAT);
        g_bTimerRunning[arena_index] = true;
    }

    ShowPlayerHud(client);
    ShowPlayerHud(foe);

    if (g_bFourPersonArena[arena_index])
    {
        ShowPlayerHud(client_teammate);
        ShowPlayerHud(foe_teammate);
    }
}

/*  ResetArena(any arena_index)
*
* Called when a round starts to reset medics ubercharge
* --------------------------------------------------------------------------- */
void ResetArena(int arena_index)
{
    //Tell the game this was a forced suicide and it shouldn't do anything about it

    int maxSlots;
    if (g_bFourPersonArena[arena_index])
    {
        maxSlots = SLOT_FOUR;
    }
    else
    {
        maxSlots = SLOT_TWO;
    }

    for (int i = SLOT_ONE; i <= maxSlots; ++i)
    {
        int thisClient = g_iArenaQueue[arena_index][i];
        if
        (
               IsValidClient(thisClient)
            && IsPlayerAlive(thisClient)
            && TF2_GetPlayerClass(thisClient) == TFClass_Medic
        )
        {
            // medigun
            int medigunIndex = GetPlayerWeaponSlot(thisClient, TFWeaponSlot_Secondary);
            if (IsValidEntity(medigunIndex))
            {
                SetEntPropFloat(medigunIndex, Prop_Send, "m_flChargeLevel", 0.0);
            }
        }
    }
}

// Restores any 2v2 participants who were moved to spectator while waiting for their teammate
// to finish the round. Ensures they are back on the correct team, clears waiting flag, and
// schedules a reset to spawn them properly.
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

/*  swapClasses(int client, int client_teammate)
*
* Called when players want to swap classes in an ultiduo arena
* --------------------------------------------------------------------------- */
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

/*  EnemyTeamTouching(any team)
*
* Returns of a player on the other team is touching the point
* --------------------------------------------------------------------------- */
bool EnemyTeamTouching(any team, any arena_index)
{
    if (team == TEAM_RED)
    {
        if (g_bPlayerTouchPoint[arena_index][SLOT_TWO])
            return true;
        else if (g_bFourPersonArena[arena_index] && g_bPlayerTouchPoint[arena_index][SLOT_FOUR])
            return true;
        else
            return false;
    }
    else
    {
        if (g_bPlayerTouchPoint[arena_index][SLOT_ONE])
            return true;
        else if (g_bFourPersonArena[arena_index] && g_bPlayerTouchPoint[arena_index][SLOT_THREE])
            return true;
        else
            return false;
    }
}


void PlayEndgameSoundsToArena(any arena_index, any winner_team)
{
    int red_1 = g_iArenaQueue[arena_index][SLOT_ONE];
    int blu_1 = g_iArenaQueue[arena_index][SLOT_TWO];
    char SoundFileBlu[124];
    char SoundFileRed[124];

    //If the red team won
    if (winner_team == 1)
    {
        SoundFileRed = "vo/announcer_victory.wav";
        SoundFileBlu = "vo/announcer_you_failed.wav";
    }
    //Else the blu team won
    else
    {
        SoundFileBlu = "vo/announcer_victory.wav";
        SoundFileRed = "vo/announcer_you_failed.wav";
    }
    if (IsValidClient(red_1))
        EmitSoundToClient(red_1, SoundFileRed);

    if (IsValidClient(blu_1))
        EmitSoundToClient(blu_1, SoundFileBlu);

    if (g_bFourPersonArena[arena_index])
    {
        int red_2 = g_iArenaQueue[arena_index][SLOT_THREE];
        int blu_2 = g_iArenaQueue[arena_index][SLOT_FOUR];
        if (g_iCappingTeam[arena_index] == TEAM_BLU)
        {
            if (IsValidClient(red_2))
                EmitSoundToClient(red_2, SoundFileRed);
        }
        else
        {
            if (IsValidClient(blu_2))
                EmitSoundToClient(blu_2, SoundFileBlu);
        }
    }
}

Action Command_Koth(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Continue;

    int arena_index = g_iPlayerArena[client];
    //new player_slot = g_iPlayerSlot[client];

    if (!arena_index) {
        PrintToChat(client, "You are not in an arena!");
        return Plugin_Continue;
    }

    if (g_bArenaKoth[arena_index]) {
        PrintToChat(client, "This arena is already in KOTH mode!");
        return Plugin_Continue;
    }

    if (!g_bArenaAllowKoth[arena_index]) {
        PrintToChat(client, "Cannot change to KOTH mode in this arena!");
        return Plugin_Continue;
    }

    if (g_iArenaStatus[arena_index] != AS_IDLE) {
        PrintToChat(client, "Cannot switch to KOTH now!");
        return Plugin_Continue;
    }

    g_bArenaKoth[arena_index] = true;
    g_bArenaMGE[arena_index] = false;
    g_fArenaRespawnTime[arena_index] = 5.0;
    g_iArenaFraglimit[arena_index] = g_iArenaCaplimit[arena_index];
    CreateTimer(1.5, Timer_StartDuel, arena_index);
    UpdateArenaName(arena_index);

    if(g_iArenaQueue[arena_index][SLOT_ONE]) {
        PrintToChat(g_iArenaQueue[arena_index][SLOT_ONE], "Changed current arena to KOTH mode!");
    }

    if(g_iArenaQueue[arena_index][SLOT_TWO]) {
        PrintToChat(g_iArenaQueue[arena_index][SLOT_TWO], "Changed current arena to KOTH mode");
    }

    return Plugin_Handled;
}

Action Command_Mge(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Continue;

    int arena_index = g_iPlayerArena[client];
    //new player_slot = g_iPlayerSlot[client];

    if (!arena_index) {
        PrintToChat(client, "You are not in an arena!");
        return Plugin_Continue;
    }

    if (g_bArenaMGE[arena_index]) {
        PrintToChat(client, "This arena is already in MGE mode!");
        return Plugin_Continue;
    }

    g_bArenaKoth[arena_index] = false;
    g_bArenaMGE[arena_index] = true;
    g_fArenaRespawnTime[arena_index] = 0.2;
    g_iArenaFraglimit[arena_index] = g_iArenaMgelimit[arena_index];
    CreateTimer(1.5, Timer_StartDuel, arena_index);
    UpdateArenaName(arena_index);

    if(g_iArenaQueue[arena_index][SLOT_ONE]) {
        PrintToChat(g_iArenaQueue[arena_index][SLOT_ONE], "Changed current arena to MGE mode!");
    }

    if(g_iArenaQueue[arena_index][SLOT_TWO]) {
        PrintToChat(g_iArenaQueue[arena_index][SLOT_TWO], "Changed current arena to MGE mode");
    }

    return Plugin_Handled;
}

void UpdateArenaName(int arena)
{
    char mode[4], type[8];
    Format(mode, sizeof(mode), "%s", g_bFourPersonArena[arena] ? "2v2" : "1v1");
    Format(type, sizeof(type), "%s",
        g_bArenaMGE[arena] ? "MGE" :
        g_bArenaUltiduo[arena] ? "ULTI" :
        g_bArenaKoth[arena] ? "KOTH" :
        g_bArenaAmmomod[arena] ? "AMOD" :
        g_bArenaBBall[arena] ? "BBALL" :
        g_bArenaMidair[arena] ? "MIDA" :
        g_bArenaEndif[arena] ? "ENDIF" : ""
    );
    Format(g_sArenaName[arena], sizeof(g_sArenaName), "%s [%s %s]", g_sArenaOriginalName[arena], mode, type);
}
