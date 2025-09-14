# MGEMod
> A 1v1 and 2v2 training mod for Team Fortress 2

This is a fork of sappho's repository, with the following improvements:

## Database & Backend

* Added a database migration mechanism to leave room for future features and improvements that require modifying the schema
* Fixed some database connection issues
* Added PostgreSQL support (only <=9.6 as per SourceMod's limitations)
* Added some measures to prevent ELOs from corrupting randomly due to database connection errors
* Added an API layer of natives and forwards

## Duel & Statistics Tracking

* Added class tracking in duels
* Added start time tracking in duels
* Added previous and new score tracking in duels
* Added elo tracking in duels, displaying previous elo and new elo of each player in every match record
* Added new `!elo` command to toggle client score display (like a local-only no stats)

## Arena & Gameplay

* Split the `mgemod_spawns.cfg` file into map-specific files for better performance and UX while editing arenas
* Added the possibility of blocking class change once the duel has started and score is still 0-0, via a new arena `classchange` property in the map config file
* Modified !add command to support a player name as argument to join the arena that player is in (`!add @ampere`)
* Added `mgemod_clear_projectiles` (0/1) ConVar to allow server owners to enable/disable projectile deletion upon the start of a new round
* Blocked eureka effect teleport usage
* Blocked the repeating resupply sound due to some maps not blocking them in certain arenas
* Fixed a small bug in the random spawn logic
* Attempted to fix situations of death momentum carryover on respawn, which results in respawning with non-zero velocity

## User Interface & Experience

* Fixed arena player count display in the !add menu not working properly
* Fixed HUD not reflecting changes on time or not displaying players properly sometimes
* Improved the interface and usage experience of the !top5 menu
* Fixed some sounds not working due to the plugin using their .wav version instead of .mp3
* Forced menu close on players that had the !add menu open but decided to join an arena via chat, to prevent accidental arena changes
* Fixed some commands not having their return type properly, making users users receive "Unknown command" upon running them
* Added missing translations for all hardcoded english strings across the entire plugin, and added some languages

## 2v2 System

* Implemented a new menu upon selecting a 2v2 arena to join a specific team, or to switch that arena to 1v1
* Implemented a ready system
  * Plugin prompts players for their ready status once it detects 2 players per team in the arena
  * Players can either confirm ready via menu or `!r`/`!ready` commands in chat
  * Players get notified of everyone in the arena's ready status via a center hint text
* Players can switch teams either via the !add menu selecting their current arena, or switching teams manually
* Added `mgemod_2v2_skip_countdown` (0/1) ConVar to allow server owners to enable/disable countdown between 2v2 rounds (author: [tommy-mor](https://github.com/sapphonie/MGEMod/pull/24))
* Fixed names sometimes getting cut off in the HUD text
* Improved displaying player names in the HUD
* Teammates no longer spawn in the same spot
* Added `mgemod_2v2_elo` (0/1) ConVar to allow server owners to enable/disable 2v2 duels from affecting players ELOs

## Developer Experience

* Reduced log verbosity in console when loading the plugin
* Modernized some parts of the source code with methodmap usage
* Fixed some bugs with `!botme` usage
* Completely modularized the code in separate script files to reduce the +7000 lines main file

The plugin is ready to be a drop-in replacement for the standard MGE version. Database modifications will be performed automatically and safely.

## Pending bug fixes and ideas

### Hot Reload Support

The plugin may have bugs when hot-reloaded (reloaded without server restart) due to incomplete cleanup of player states, arena data, and database connections. This can cause players to get stuck in arenas, lose their ratings, or experience other state inconsistencies. Hot reload support is halfway through, either complete or remove.

### Arena Property Editing

Currently requires manually editing map config files and reloading the plugin/map to change arena properties like spawn points, class restrictions, or game modes. This is time-consuming and error-prone for server administrators.

**Implementation ideas:**
- Add in-game arena property editor commands
- Create web-based configuration interface
- Implement real-time arena property updates
- Add arena property validation and error checking

### Mapmaker Configuration System

Mapmakers currently need to manually create and edit complex config files for their MGE maps, which requires understanding the plugin's configuration syntax and can be error-prone.

**Implementation ideas:**
- Create interactive map configuration tool/plugin
- Build visual arena placement and property editor
- Implement config file generation from in-game setup
- Add configuration templates and wizards for common map types

### 2v2 ELO Display in HUD

The ELO display logic in 2v2 mode is confusing since individual ELOs get merged/combined in 2v2 matches. The current implementation may not be relevant or useful for players in 2v2 scenarios.

**Decision needed:**
- Remove ELO display from 2v2 HUD entirely
- Implement team-based ELO calculation and display
- Show individual ELOs but with clear indication they're not used for 2v2 matchmaking
- Redesign ELO system to be more intuitive for 2v2 gameplay

### Make all timers configurable

Make game start, round start, game end, round end and any other timer configurable.