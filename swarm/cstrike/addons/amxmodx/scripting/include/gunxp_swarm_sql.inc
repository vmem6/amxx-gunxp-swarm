#if defined _GUNXP_SWARM_SQL_INC
  #endinput
#endif
#define _GUNXP_SWARM_SQL_INC

/* Forwards */

/*
 * Called when player data has been fully loaded.
 *
 * @param pid         ID of player whose data has been loaded.
 *
 * @noreturn
 */
forward gxp_player_data_loaded(pid);