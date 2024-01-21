#if defined _GUNXP_SWARM_STATS_INC
  #endinput
#endif
#define _GUNXP_SWARM_STATS_INC

/* Natives > Internal */

/*
 * Performs initial set-up of SQL database (i.e., creates tables, if necessary).
 *
 * @noreturn
 */
native _gxp_stats_set_up();

/*
 * Loads player stats from SQL database.
 *
 * @param pid          ID of player whose stats to load.
 *
 * @noreturn
 */
native _gxp_stats_load_player(pid);

/*
 * Commits player stats to SQL database.
 *
 * @param pid          ID of player whose stats to commit/save.
 *
 * @noreturn
 */
native _gxp_stats_save_player(pid);

/* Forwards > Internal */

/*
 * Called when player stats have been fully loaded.
 *
 * @param pid         ID of player whose data has been loaded.
 *
 * @noreturn
 */
forward _gxp_stats_player_loaded(pid);
