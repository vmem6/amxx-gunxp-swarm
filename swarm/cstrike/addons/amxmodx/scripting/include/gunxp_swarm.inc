#if defined _GUNXP_SWARM_INC
  #endinput
#endif
#define _GUNXP_SWARM_INC

#include <gunxp_swarm_const>

/* Defines > Internal */

#define _GXP_SWARM_CORE_PLUGIN    "GunXP: Core (Swarm)"
#define _GXP_SWARM_UI_PLUGIN      "GunXP: Interface (Swarm)"
#define _GXP_SWARM_SQL_PLUGIN     "GunXP: SQL (Swarm)"
#define _GXP_SWARM_CONFIG_PLUGIN  "GunXP: Config (Swarm)"
#define _GXP_SWARM_ULS_PLUGIN     "GunXP: Unlocks (Swarm)"
#define _GXP_SWARM_INFO_PLUGIN    "GunXP: Information (Swarm)"
#define _GXP_SWARM_POWERS_PLUGIN  "GunXP: Powers (Swarm)"

/* Base class plugins > Survivors */
#define _GXP_SWARM_SURVIVOR_PLUGIN        "GunXP: Survivor Class (Swarm)"
/* Base class plugins > Zombies */
#define _GXP_SWARM_HUNTER_PLUGIN          "GunXP: Hunter Class (Swarm)"
#define _GXP_SWARM_JUMP_HUNTER_PLUGIN     "GunXP: Jump Hunter Class (Swarm)"
#define _GXP_SWARM_CHARGER_PLUGIN         "GunXP: Charger Class (Swarm)"
#define _GXP_SWARM_WITCH_PLUGIN           "GunXP: Witch Class (Swarm)"
#define _GXP_SWARM_SPITTER_PLUGIN         "GunXP: Spitter Class (Swarm)"
#define _GXP_SWARM_DANGER_SPITTER_PLUGIN  "GunXP: Danger Spitter Class (Swarm)"
#define _GXP_SWARM_CHAINSAW_PLUGIN        "GunXP: Chainsaw Class (Swarm)"
#define _GXP_SWARM_BOOMER_PLUGIN          "GunXP: Boomer Class (Swarm)"
#define _GXP_SWARM_DANGER_BOOMER_PLUGIN   "GunXP: Danger Boomer Class (Swarm)"
#define _GXP_SWARM_SMOKER_PLUGIN          "GunXP: Smoker Class (Swarm)"
#define _GXP_SWARM_TANK_PLUGIN            "GunXP: Tank Class (Swarm)"
#define _GXP_SWARM_JOCKEY_PLUGIN          "GunXP: Jockey Class (Swarm)"
#define _GXP_SWARM_HEALER_PLUGIN          "GunXP: Healer Class (Swarm)"
#define _GXP_SWARM_ARMORED_PLUGIN         "GunXP: Armored Class (Swarm)"
#define _GXP_SWARM_FLY_PLUGIN             "GunXP: Fly Class (Swarm)"
#define _GXP_SWARM_YAKSHA_PLUGIN          "GunXP: Yaksha Class (Swarm)"
#define _GXP_SWARM_ARACHNE_PLUGIN         "GunXP: Arachne Class (Swarm)"

#define _GXP_SWARM_VERSION  "0.1.0-beta"
#define _GXP_SWARM_AUTHOR   "RiviT, Scott & prnl0"

#define _GXP_SWARM_DICTIONARY "gunxp_swarm.txt"

/* Natives */

native bool:gxp_has_game_started();
native bool:gxp_has_round_started();
native bool:gxp_has_round_ended();

/*
 * Retrieves player data identified by `data_field`.
 * If data field identified by `data_field` is an array, `buffer` of an
 * appropriate length must be provided.
 *
 * @param pid                PID of player whose data to retrieve.
 * @param data_field         Data type specifier (i.e., what data to retrieve).
 * @param buffer             Array to store data in (if `data_field` points to array).
 *
 * @return                   Data as identified by `data_field`, or -1 if `data_field` points to array.
 */
native gxp_get_player_data(pid, GxpPlayer:data_field, buffer[] = "");

/*
 * Sets player data identified by `data_field`.
 *
 * @param pid                PID of player whose data to set.
 * @param data_field         Data type specifier (i.e., what data to set).
 * @param value              Value to set data to.
 * @param buffer             Array to set data to (if `data_field` points to array).
 *
 * @noreturn
 */
native gxp_set_player_data(pid, GxpPlayer:data_field, any:value = 0, const buffer[] = {});

native gxp_get_player_class(pid, class[GxpClass]);

native gxp_register_class(const id[GXP_MAX_CLASS_ID_LENGTH + 1], GxpTeam:team);

native gxp_give_xp(pid, xp);
native gxp_take_xp(pid, xp);
native gxp_give_gun(pid, gun_id);

native bool:gxp_is_vip(pid);
native bool:gxp_is_admin(pid);
native bool:gxp_is_sadmin(pid);

/* Forwards > Public */

forward gxp_cleanup();

forward gxp_game_started();
forward gxp_round_started(round);
forward gxp_round_ended(round);

forward gxp_teams_switched();

forward gxp_player_spawned(pid);
forward gxp_player_cleanup(pid);

forward gxp_player_used_ability(pid);
forward gxp_player_used_secn_ability(pid);

/* TODO: change "slashed" and "stabbed" to "slash" and "stab", respectively. */
forward gxp_player_knife_slashed(pid);
forward gxp_player_knife_hitwall(pid);
forward gxp_player_knife_hit(pid);
forward gxp_player_knife_stabbed(pid);

forward gxp_player_suffer(pid);
forward gxp_player_died(pid);

forward gxp_player_gained_xp(pid, xp, bonus_xp, const desc[]);
forward gxp_player_attempted_prs(pid, bool:successful);

/*
 * Forwards > Internal
 *
 * NOTE: these are 'one' forwards, and are only sent to the SQL plugin. They
 *       are not intended to be caught anywhere else.
 */

/*
 * Called when SQL plugin should perform initial set-up.
 *
 * @noreturn
 */
forward _gxp_set_up();

/*
 * Called when SQL plugin should load player data.
 *
 * @param pid          ID of player whose data to load.
 *
 * @noreturn
 */
forward _gxp_load_player_data(pid);

/*
 * Called when SQL plugin should save player data.
 *
 * @param pid          ID of player whose data to save.
 *
 * @noreturn
 */
forward _gxp_save_player_data(pid);