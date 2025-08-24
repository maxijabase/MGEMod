# MGEMod
> A 1v1 and 2v2 training mod for Team Fortress 2

This is a fork of sappho's repository, with the following improvements:

- Added a database migration mechanism to leave room for future features and improvements that require modifying the schema
- Fixed some database connection issues
- Split the `mgemod_spawns.cfg` file into map-specific files for better performance and UX while editing arenas
- Reduced log verbosity in console when loading the plugin
- Added class tracking in duels
- Added the possibility of blocking class change once the duel has started, via a new arena `classchange` property in the map config file
