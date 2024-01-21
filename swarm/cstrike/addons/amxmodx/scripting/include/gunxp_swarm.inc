#if defined _GUNXP_SWARM_INC
  #endinput
#endif
#define _GUNXP_SWARM_INC

#include <gunxp_swarm_const>

/* Defines > Internal */

#define _GXP_SWARM_CORE_PLUGIN        "GunXP: Core (Swarm)"
#define _GXP_SWARM_UI_PLUGIN          "GunXP: Interface (Swarm)"
#define _GXP_SWARM_SQL_PLUGIN         "GunXP: SQL (Swarm)"
#define _GXP_SWARM_CONFIG_PLUGIN      "GunXP: Config (Swarm)"
#define _GXP_SWARM_ULS_PLUGIN         "GunXP: Unlocks (Swarm)"
#define _GXP_SWARM_INFO_PLUGIN        "GunXP: Information (Swarm)"
#define _GXP_SWARM_POWERS_PLUGIN      "GunXP: Powers (Swarm)"
#define _GXP_SWARM_STATS_PLUGIN       "GunXP: Stats (Swarm)"
#define _GXP_SWARM_ENVIRONMENT_PLUGIN "GunXP: Environment (Swarm)"
#define _GXP_SWARM_INTEGRITY_PLUGIN   "GunXP: Integrity (Swarm)"

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

/*
 * States whether the game has started or not.
 *
 * @return         `true` if the game has started; `false` otherwise.
 */
native bool:gxp_has_game_started();

/*
 * States whether the round has started or not.
 *
 * @return         `true` if the round has started; `false` otherwise.
 */
native bool:gxp_has_round_started();

/*
 * States whether the round has ended or not.
 *
 * @return         `true` if the round has ended; `false` otherwise.
 */
native bool:gxp_has_round_ended();

/*
 * States whether the round is ending or not.
 *
 * @return         `true` if the round is ending; `false` otherwise.
 */
native bool:gxp_is_round_ending();

/*
 * States whether freeze time is currently active.
 *
 * @return         `true` if freeze time is currently active; `false` otherwise.
 */
native bool:gxp_in_freeze_time();

/*
 * Retrieves player data identified by `data_field`.
 * If `data_field` is an array, `buffer` of an appropriate length must be
 * provided.
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

/*
 * Retrieves player statistic identified by `stat`.
 * NOTE: this native is temporary and will be merged with `gxp_get_player_data`
 *       at some point.
 *
 * @param pid          PID of player whose data to retrieve.
 * @param stat         Statistic specifier.
 *
 * @return             Value of statistics as identified by `stat`.
 */
native gxp_get_player_stat(pid, GxpPlayerStats:stat);

/*
 * Sets player statistic identified by `stat`.
 * NOTE: this native is temporary and will be merged with `gxp_set_player_data`
 *       at some point.
 *
 * @param pid           PID of player whose stat to set.
 * @param stat          Statistic specifier.
 * @param value         Value to set stat to.
 *
 * @noreturn
 */
native gxp_set_player_stat(pid, GxpPlayerStats:stat, any:value = 0);

native gxp_get_player_class(pid, class[GxpClass]);

native gxp_register_class(const id[GXP_MAX_CLASS_ID_LENGTH + 1], GxpTeam:team, const acc_callback[] = "", const req_callback[] = "");

native gxp_give_xp(pid, xp);
native gxp_take_xp(pid, xp);
native gxp_give_gun(pid, gun_id);

/*
 * States whether player is a newbie or not.
 *
 * @param pid         ID of player.
 *
 * @return            `true` if player is a newbie; `false` otherwise.
 */
native bool:gxp_is_newbie(pid);

/*
 * States whether player is a VIP or not.
 *
 * @param pid         ID of player.
 *
 * @return            `true` if player is a VIP; `false` otherwise.
 */
native bool:gxp_is_vip(pid);

/*
 * States whether player is an admin or not.
 *
 * @param pid         ID of player.
 *
 * @return            `true` if player is an admin; `false` otherwise.
 */
native bool:gxp_is_admin(pid);

/*
 * States whether player is a super admin or not.
 *
 * @param pid         ID of player.
 *
 * @return            `true` if player is a super admin; `false` otherwise.
 */
native bool:gxp_is_sadmin(pid);

/*
 * Retrieves the maximum HP a player can have.
 *
 * @param pid         ID of player.
 *
 * @return            Maximum HP player can have.
 */
native gxp_get_max_hp(pid);

/* Natives > Backwards compatibility */

/*
 * [DEPRECATED]
 * Retrieves the amount of XP a given player has.
 *
 * @param pid         ID of player.
 *
 * @return            XP a player has.
 */
native get_user_xp(pid);

/*
 * [DEPRECATED]
 * Sets the amount of XP a given player has.
 *
 * @param pid         ID of player.
 * @param xp          XP amount.
 *
 * @noreturn
 */
native set_user_xp(pid, xp);

/*
 * [DEPRECATED]
 * Retrieves level of given player.
 *
 * @param pid         ID of player.
 *
 * @return            Level of player.
 */
native get_user_level(pid);

/*
 * [DEPRECATED]
 * States whether given player is a zombie or not.
 *
 * @param pid         ID of player.
 *
 * @return            `true` if player is a zombie; `false` otherwise.
 */
native bool:is_zombie(pid);

/*
 * [DEPRECATED]
 * States whether given player is frozen by a nade or not.
 *
 * @param pid         ID of player.
 *
 * @return            `true` if player is frozen by nade; `false` otherwise.
 */
native bool:is_frozen(pid);

native jump_bomb_add(pid, amount);
native gxp_get_jump_bomb_bonus_dmg(pid);

/* Forwards > Public */

forward gxp_cleanup();

forward gxp_game_started();
forward gxp_round_started(round);
forward gxp_round_ended(round);

forward gxp_teams_swapped();

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
forward gxp_player_levelled_up(pid, prev_lvl, new_lvl);
forward gxp_player_attempted_prs(pid, bool:successful);

forward gxp_player_survived(pid, xp_gained);
