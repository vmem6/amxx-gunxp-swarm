#if defined _STATE_INC
  #endinput
#endif
#define _STATE_INC

/* Defines > Internal */

#define _STATE_CORE_PLUGIN  "State: Core"
#define _STATE_UI_PLUGIN    "State: Interface"

#define _STATE_VERSION "0.1.0-beta"
#define _STATE_AUTHOR  "prnl0"

#define _STATE_DICTIONARY "state.txt"

#define _STATE_CONFIG "state.cfg"

/* Natives */

native state_queue_table(const table[], Array:cols);

/*
 * Retrieves a players' static ID.
 *
 * @param pid         Player ID.
 *
 * @return            Static ID of player, or -1 if player is not connected.
 */
native state_get_player_sid(pid);

/*
 * Retrieves a players' dynamic ID type.
 *
 * @param pid         Player ID.
 *
 * @return            Dynamic ID type of player, or `s_did_t_unknown` if player is not connected.
 */
native StateDynamicIDType:state_get_player_did_type(pid);

/*
 * Sets a players' dynamic ID type.
 *
 * @param pid           Player ID.
 * @param did_t         Dynamic ID type.
 *
 * @noreturn
 */
native state_set_player_did_type(pid, StateDynamicIDType:did_t);

native state_get_val(pid, const pstate[], const field[], buffer[] = "", maxlen = 0);
native state_set_val(pid, const pstate[], const field[], any:val);

/* Forwards */

/*
 * Called when a players' state has been loaded.
 *
 * @param         Player ID.
 * @param         Player unique static ID.
 *
 * @noreturn
 */
forward state_player_loaded(pid, sid);