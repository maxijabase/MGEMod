# MGEMod
> A 1v1 and 2v2 training mod for Team Fortress 2

This is a fork of sappho's repository, with the following improvements:

- Added a database migration mechanism to leave room for future features and improvements that require modifying the schema
- Fixed some database connection issues
- Split the `mgemod_spawns.cfg` file into map-specific files for better performance and UX while editing arenas
- Reduced log verbosity in console when loading the plugin
- Added class tracking in duels
- Added start time tracking in duels
- Added previous and new score tracking in duels
- Added the possibility of blocking class change once the duel has started and score is still 0-0, via a new arena `classchange` property in the map config file
- Added `mgemod_2v2_skip_countdown` ConVar to allow server owners to toggle countdown between 2v2 rounds (0 = normal countdown, 1 = skip countdown) (author: [tommy-mor](https://github.com/sapphonie/MGEMod/pull/24))
- Added new `!elo` command to toggle client score display (like a local-only no stats)

The plugin is ready to be a drop-in replacement for the standard MGE version. Database modifications will be performed automatically and safely.

## Pending bug fixes and ideas

### ELO Corruption

Players can have their ratings reset to default values due to database connection issues. When MySQL fails, the plugin falls back to SQLite, then when MySQL reconnects, it re-queries all players and overwrites their cached ratings with SQLite fallback data.

**Fix options:**
- Database Queue System - Store pending queries locally and process when connection restored
- Fix Reconnection Logic - Only query players who need it and add ELO validation  
- Eliminate Database Switching - Remove SQLite fallback entirely
- Minimal Fix - Comment out problematic re-query loop

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