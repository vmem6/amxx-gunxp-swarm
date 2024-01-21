#if defined _GUNXP_SWARM_SQL_INC
  #endinput
#endif
#define _GUNXP_SWARM_SQL_INC

/* Natives > Internal */

/*
 * Performs initial set-up of SQL database (i.e., creates tables, if necessary).
 *
 * @noreturn
 */
native _gxp_sql_set_up();

/*
 * Loads player data from SQL database.
 *
 * @param pid          ID of player whose data to load.
 *
 * @noreturn
 */
native _gxp_sql_load_player_data(pid);

/*
 * Commits player data to SQL database.
 *
 * @param pid          ID of player whose data to commit/save.
 *
 * @noreturn
 */
native _gxp_sql_save_player_data(pid);

/* Forwards */

/*
 * Called when player data has been fully loaded.
 *
 * @param pid         ID of player whose data has been loaded.
 *
 * @noreturn
 */
forward gxp_player_data_loaded(pid);