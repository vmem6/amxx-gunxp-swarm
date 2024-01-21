/*
 * TODO:
 *   - move resources (sounds, models, sprites) to INI, and parse them in
 *     `gunxp_swarm_config.sma`;
 *   - move code in `fm_touch_pre` concerned with obtaining weapon ID from
 *     weaponbox entity to a separate stock;
 *   - check, on round start, whether we have at least one registered class per
 *     team; if not - set fail state;
 *   - move greater part of `task_start_countdown()` to `gunxp_swarm_ui.sma`;
 *   - store no. of seconds before game start in CVar;
 *   - store `FORCE_BALANCE_AFTER` in CVar;
 *   - store `NEWBIE_{MAX_PRS, MAX_USED_PRS, MAX_XP}` in CVars;
 *   - check against config to see if provided ID exists
 *     (`native_register_class()`);
 *   - check to see if class has not yet been registered
 *     (`native_register_class()`);
 *   - store `MAX_RANDOM_CLASS_ATTEMPTS` in CVar;
 *   - move `transfer_player` to Team Balancer as a native;
 *   - store min. time a player has to be connected before loading their data in
 *     CVar;
 *   - abstract `native_set_player_stat` away, and introduce possibility to set
 *     the value of an arbitrary index of an array in `native_set_player_data`.
 *
 * POSSIBLE TODO:
 *   - rename `g_gxp_round`?
 *   - omit "player_" substring from natives?
 *   - cache class instead of retrieving it every time (`get_class()`)?
 *   - remove checks for plugins in `plugin_cfg()`?
 *   - remove `reset_player_data()`?
 */

#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fakemeta>
#include <fakemeta_util>
#include <cstrike>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_sql>
#include <gunxp_swarm_uls>
#include <gunxp_swarm_powers>
#include <gunxp_swarm_ui>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

#include <state>

#include <team_balancer>
#include <team_balancer_skill>

#include <utils_effects>
#include <utils_offsets>

#define SOUND_LEVELLED_UP	"level_up_new.wav"
#define SOUND_PRESTIGED 	"level_up_new.wav"

enum _:RegisteredClass
{
	reg_cls_id[GXP_MAX_CLASS_ID_LENGTH + 1],
	reg_cls_acc_callback[GXP_MAX_CALLBACK_LENGTH + 1],
	reg_cls_req_callback[GXP_MAX_CALLBACK_LENGTH + 1],
	reg_cls_plugin[64 + 1]
};

enum (+= 1000)
{
	tid_respawn = 2367,
	tid_game_start_countdown
};

new const g_human_win_sounds[][] =
{
	"jailassounds/swarm3.wav",
	"jailassounds/swarm1.wav",
	"jailassounds/77.mp3"
};

new const g_zm_win_sounds[][] =
{ 
	"jailassounds/swarm2.wav", 
	"jailassounds/swarm4.wav",
	"jailassounds/K35.mp3"
};

new const g_clcmds[][][32 + 1] = 
{
  { "/prs",    		"handle_say_prs" },
  { "/prestige", 	"handle_say_prs" }
};

new g_players[MAX_PLAYERS + 1][GxpPlayer];

new bool:g_game_started;
new bool:g_game_starting;
new bool:g_round_ended;
new bool:g_round_ending;
new bool:g_freeze_time;
new g_gxp_round;

new g_bonus_hp_per_respawn;
new g_max_respawns_for_bonus_hp;
new g_max_newbie_respawns_for_bonus_hp;

new g_multi_max_n;
new g_multi_xp_base;
new g_multi_xp_delta;
new g_multi_kills_base;
new g_multi_kills_delta;

new g_survival_min_players;
new g_survival_xp;
new g_survival_mod_min_players;
new g_survival_mod_xp;

new Array:g_survivor_classes;
new Array:g_zombie_classes;

new g_pcvar_xp_method;
new g_pcvar_rounds_per_team;
new g_pcvar_respawn_delay;

/* Resources */

new g_spr_level_up;

/* Forwards */

new g_fwd_cleanup;

new g_fwd_game_started;
new g_fwd_round_started;
new g_fwd_round_ended;

new g_fwd_teams_swapped;

new g_fwd_player_spawned;
new g_fwd_player_cleanup;

new g_fwd_player_used_ability;
new g_fwd_player_used_secn_ability;

new g_fwd_player_knife_slash;
new g_fwd_player_knife_hitwall;
new g_fwd_player_knife_hit;
new g_fwd_player_knife_stab;

new g_fwd_player_suffer;
new g_fwd_player_died;

new g_fwd_player_gained_xp;
new g_fwd_player_levelled_up;
new g_fwd_player_attempted_prs;

new g_fwd_player_survived;

/* Maintained for backwards compatibility. */
new g_fwd_bc_game_started;

/* Messages */

new g_msgid_textmsg;

/* HUD sync */

new g_hudsync_tc;

public plugin_natives()
{
	register_library("gxp_swarm_core");

	register_native("gxp_has_game_started", "native_has_game_started");
	register_native("gxp_has_round_started", "native_has_round_started");
	register_native("gxp_has_round_ended", "native_has_round_ended");
	register_native("gxp_is_round_ending", "native_is_round_ending");
	register_native("gxp_in_freeze_time", "native_in_freeze_time");

	register_native("gxp_get_player_data", "native_get_player_data");
	register_native("gxp_set_player_data", "native_set_player_data");
	register_native("gxp_get_player_stat", "native_get_player_stat");
	register_native("gxp_set_player_stat", "native_set_player_stat");
	register_native("gxp_get_player_class", "native_get_player_class");

	register_native("gxp_register_class", "native_register_class");

	register_native("gxp_give_xp", "native_give_xp");
	register_native("gxp_take_xp", "native_take_xp");
	register_native("gxp_give_gun", "native_give_gun");

	register_native("gxp_is_newbie", "native_is_newbie");
	register_native("gxp_is_vip", "native_is_vip");
	register_native("gxp_is_admin", "native_is_admin");
	register_native("gxp_is_sadmin", "native_is_sadmin");

	register_native("gxp_get_max_hp", "native_get_max_hp");

	/* Maintained for backwards compatibility. */

	register_native("is_zombie", "native_bc_is_zombie");

	register_native("get_user_xp", "native_bc_get_user_xp");
	register_native("set_user_xp", "native_bc_set_user_xp");
	register_native("get_user_level", "native_bc_get_user_level");
}

public plugin_precache()
{
	precache_sound(SOUND_LEVELLED_UP);
	precache_sound(SOUND_PRESTIGED);

	g_spr_level_up = engfunc(EngFunc_PrecacheModel, "sprites/blast.spr");

	for (new i = 0; i != sizeof(g_human_win_sounds); ++i)
		precache_sound(g_human_win_sounds[i]);
	for (new i = 0; i != sizeof(g_zm_win_sounds); ++i)
		precache_sound(g_zm_win_sounds[i]);
}

public plugin_init()
{
	register_plugin(_GXP_SWARM_CORE_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

	/* CVars */

	g_pcvar_xp_method 			= register_cvar("gxp_xp_method", "0");
	g_pcvar_rounds_per_team = register_cvar("gxp_rounds_per_team", "2");
	g_pcvar_respawn_delay 	= register_cvar("gxp_respawn_delay", "1.0");

	bind_pcvar_num(register_cvar("gxp_bonus_hp_per_respawn", "100"), g_bonus_hp_per_respawn);
	bind_pcvar_num(register_cvar("gxp_max_respawns_for_bonus_hp", "3"), g_max_respawns_for_bonus_hp);
	bind_pcvar_num(
		register_cvar("gxp_max_newbie_respawns_for_bonus_hp", "5"), g_max_newbie_respawns_for_bonus_hp
	);

	bind_pcvar_num(register_cvar("gxp_multi_max_n", "3"), g_multi_max_n);
	bind_pcvar_num(register_cvar("gxp_multi_xp_base", "100"), g_multi_xp_base);
	bind_pcvar_num(register_cvar("gxp_multi_xp_delta", "50"), g_multi_xp_delta);
	bind_pcvar_num(register_cvar("gxp_multi_kills_base", "3"), g_multi_kills_base);
	bind_pcvar_num(register_cvar("gxp_multi_kills_delta", "3"), g_multi_kills_delta);

	bind_pcvar_num(register_cvar("gxp_survival_min_players", "6"), g_survival_min_players);
	bind_pcvar_num(register_cvar("gxp_survival_xp", "5000"), g_survival_xp);
	bind_pcvar_num(register_cvar("gxp_survival_mod_min_players", "9"), g_survival_mod_min_players);
	bind_pcvar_num(register_cvar("gxp_survival_mod_xp", "500"), g_survival_mod_xp);

	/* Forwards */

	g_fwd_cleanup = CreateMultiForward("gxp_cleanup", ET_IGNORE);

	g_fwd_game_started 		= CreateMultiForward("gxp_game_started", ET_IGNORE);
	g_fwd_round_started 	= CreateMultiForward("gxp_round_started", ET_IGNORE, FP_CELL);
	g_fwd_round_ended 		= CreateMultiForward("gxp_round_ended", ET_IGNORE, FP_CELL);

	g_fwd_teams_swapped = CreateMultiForward("gxp_teams_swapped", ET_IGNORE);

	g_fwd_player_spawned = CreateMultiForward("gxp_player_spawned", ET_IGNORE, FP_CELL);
	g_fwd_player_cleanup = CreateMultiForward("gxp_player_cleanup", ET_IGNORE, FP_CELL);

	g_fwd_player_used_ability 			=
		CreateMultiForward("gxp_player_used_ability", ET_IGNORE, FP_CELL);
	g_fwd_player_used_secn_ability	=
		CreateMultiForward("gxp_player_used_secn_ability", ET_IGNORE, FP_CELL);

	g_fwd_player_knife_slash 		= CreateMultiForward("gxp_player_knife_slashed", ET_IGNORE, FP_CELL);
	g_fwd_player_knife_hitwall 	= CreateMultiForward("gxp_player_knife_hitwall", ET_IGNORE, FP_CELL);
	g_fwd_player_knife_hit 			= CreateMultiForward("gxp_player_knife_hit", ET_IGNORE, FP_CELL);
	g_fwd_player_knife_stab 		= CreateMultiForward("gxp_player_knife_stabbed", ET_IGNORE, FP_CELL);

	g_fwd_player_suffer 	= CreateMultiForward("gxp_player_suffer", ET_IGNORE, FP_CELL);
	g_fwd_player_died 		= CreateMultiForward("gxp_player_died", ET_IGNORE, FP_CELL);

	g_fwd_player_gained_xp 			=
		CreateMultiForward("gxp_player_gained_xp", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_STRING);
	g_fwd_player_levelled_up 		=
		CreateMultiForward("gxp_player_levelled_up", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	g_fwd_player_attempted_prs 	=
		CreateMultiForward("gxp_player_attempted_prs", ET_IGNORE, FP_CELL, FP_CELL);

	g_fwd_player_survived = CreateMultiForward("gxp_player_survived", ET_IGNORE, FP_CELL, FP_CELL);

	/* Maintained for backwards compatibility. */
	g_fwd_bc_game_started = CreateMultiForward("swarm_game_started", ET_IGNORE);

	/* Forwards > FakeMeta */

	register_forward(FM_EmitSound, "fm_emitsound_pre");
	register_forward(FM_ClientKill, "fm_clientkill_pre");
	register_forward(FM_Touch, "fm_touch_pre");

	/* Forwards > Ham */

	RegisterHam(Ham_TakeDamage, "player", "ham_player_takedamage_pre");
	RegisterHam(Ham_TraceAttack, "player", "ham_player_traceattack_pre");
	RegisterHam(Ham_TakeDamage, "player", "ham_player_takedamage_post", .Post = 1);
	RegisterHam(Ham_Spawn, "player", "ham_player_spawn_post", .Post = 1);
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "ham_item_deploy_post", .Post = 1);
	RegisterHam(Ham_Item_Deploy, "weapon_smokegrenade", "ham_item_deploy_post", .Post = 1);

	/* Messages */

	register_message(get_user_msgid("ScoreAttrib"), "message_scoreattrib");
	register_message(get_user_msgid("StatusIcon"), "message_statusicon");
	register_message(get_user_msgid("TextMsg"), "message_textmsg");
	register_message(get_user_msgid("SendAudio"), "message_sendaudio");
	register_message(get_user_msgid("HudTextArgs"), "message_hudtextargs");

	g_msgid_textmsg = get_user_msgid("TextMsg");

	/* Events */

	register_event_ex("HLTV", "event_new_round", RegisterEvent_Global, "1=0", "2=0");
	register_event_ex("DeathMsg", "event_deathmsg", RegisterEvent_Global);
	register_event_ex("TeamInfo", "event_teaminfo", RegisterEvent_Global);
	register_event_ex("ResetHUD", "event_resethud", RegisterEvent_Single);
	register_event_ex("HideWeapon", "event_hideweapon", RegisterEvent_Single);

	register_logevent("logevent_round_start", 2, "1=Round_Start");
	register_logevent("logevent_round_end", 2, "1=Round_End");

	/* Client commands */

	register_clcmd("drop", "clcmd_drop");
	register_clcmd("say", "clcmd_say");
	register_clcmd("say_team", "clcmd_say");

	/* Miscellaneous */

	g_survivor_classes = ArrayCreate(RegisteredClass);
	g_zombie_classes = ArrayCreate(RegisteredClass);

	g_hudsync_tc = CreateHudSyncObj();
}

public plugin_cfg()
{
	new sql_plugin = is_plugin_loaded(_GXP_SWARM_SQL_PLUGIN);
	if (sql_plugin == INVALID_PLUGIN_ID)
		set_fail_state("^"%s^" must be loaded.", _GXP_SWARM_SQL_PLUGIN);

	_gxp_sql_set_up();
}

public plugin_end()
{
	ArrayDestroy(g_survivor_classes);
	ArrayDestroy(g_zombie_classes);

	DestroyForward(g_fwd_cleanup);

	DestroyForward(g_fwd_game_started);
	DestroyForward(g_fwd_round_started);
	DestroyForward(g_fwd_round_ended);

	DestroyForward(g_fwd_teams_swapped);

	DestroyForward(g_fwd_player_spawned);
	DestroyForward(g_fwd_player_cleanup);

	DestroyForward(g_fwd_player_used_ability);
	DestroyForward(g_fwd_player_used_secn_ability);

	DestroyForward(g_fwd_player_knife_slash);
	DestroyForward(g_fwd_player_knife_hitwall);
	DestroyForward(g_fwd_player_knife_hit);
	DestroyForward(g_fwd_player_knife_stab);

	DestroyForward(g_fwd_player_suffer);
	DestroyForward(g_fwd_player_died);

	DestroyForward(g_fwd_player_gained_xp);
	DestroyForward(g_fwd_player_levelled_up);
	DestroyForward(g_fwd_player_attempted_prs);

	DestroyForward(g_fwd_player_survived);
}

/* Forwards > Client */

public client_putinserver(pid)
{
	if (is_user_hltv(pid))
		return;

	if (is_user_bot(pid)) {
		compute_skill(pid);
		return;
	}

	reset_player_data(pid);
	_gxp_sql_load_player_data(pid);
}

public client_disconnected(pid, bool:drop, message[], maxlen)
{
	if (is_user_hltv(pid) || is_user_bot(pid))
		return;

	for (new i = 0; i != GxpUlClass; ++i)
		ArrayDestroy(g_players[pid][pd_uls][i]);

	if (state_get_player_sid(pid) != 0 && get_user_time(pid) > 5) {
		ExecuteForward(g_fwd_player_cleanup, _, pid);

		if (g_players[pid][pd_remember_sel] == gxp_remember_sel_map)
			g_players[pid][pd_remember_sel] = gxp_remember_sel_off;

		_gxp_sql_save_player_data(pid);
	}
}

/* Forwards > GunXP */

public gxp_player_data_loaded(pid)
{
	gxp_ul_activate_free(pid);
	gxp_ul_activate_newbie(pid);

	compute_skill(pid);
}

/* Forwards > FakeMeta */

public fm_emitsound_pre(pid, chan, sample[], Float:vol, Float:attn, flag, pitch)
{
	if (!is_user_connected(pid) || g_players[pid][pd_class] == 0)
		return FMRES_IGNORED;

	new class[GxpClass];
	get_class(pid, class);

	/* `+use` */
	if (equal(sample, "common/wpn_denyselect.wav")) {
		if (
			!g_freeze_time && !g_round_ended
			&& ((pev(pid, pev_flags) & FL_ONGROUND) || class[cls_midair_ability])
		) {
			ExecuteForward(g_fwd_player_used_ability, _, pid);
		}
		return FMRES_SUPERCEDE;
	}

	if (equal(sample, "hostage", 7) || equal(sample, "nvg", 3))
		return FMRES_SUPERCEDE;

	if (class[cls_default_sounds])
		return FMRES_IGNORED;

	/* Knife */
	if (sample[0] == 'w' && sample[1] == 'e' && sample[8] == 'k' && sample[9] == 'n') {
		switch (sample[17]) {
			case 'l': return FMRES_SUPERCEDE;																					// deploy
			case 's': ExecuteForward(g_fwd_player_knife_slash, _, pid);								// slash
			case 'w': ExecuteForward(g_fwd_player_knife_hitwall, _, pid);							// hitwall
			case 'b': ExecuteForward(g_fwd_player_knife_stab, _, pid);								// stab
			case '1', '2', '3', '4': ExecuteForward(g_fwd_player_knife_hit, _, pid);	// hit
		}
		return FMRES_SUPERCEDE;
	/* Pain */
	} else if (
		sample[1] == 'l' && sample[2] == 'a' && sample[3] == 'y'
		&& (
			containi(sample, "bhit") != -1
			|| containi(sample, "pain") != -1
			|| containi(sample, "shot") != -1
		)
	) {
		ExecuteForward(g_fwd_player_suffer, _, pid);
		return FMRES_SUPERCEDE;
	/* Death */
	} else if (sample[7] == 'd' && (sample[8] == 'i' && sample[9] == 'e' || sample[12] == '6')) {
		ExecuteForward(g_fwd_player_died, _, pid);
		return FMRES_SUPERCEDE;
	}

	return FMRES_IGNORED;
}

public fm_clientkill_pre(pid)
{
	console_print(pid, "%L", pid, "GXP_CONSOLE_NO_SUICIDE");
	return FMRES_SUPERCEDE;
}

public fm_touch_pre(ent, pid)
{
	if (!pev_valid(ent) || pid < 1 || pid > MAX_PLAYERS || !is_user_alive(pid))
		return FMRES_IGNORED;

	if (g_players[pid][pd_team] == tm_zombie) {
		return FMRES_SUPERCEDE;
	} else if (g_players[pid][pd_team] == tm_survivor) {
		static ent_mdl[32 + 1];
		pev(ent, pev_model, ent_mdl, charsmax(ent_mdl));

		for (new i = 0; i <= g_players[pid][pd_level]; ++i) {
			if (equal(ent_mdl, _gxp_gun_models[i]))
				return FMRES_IGNORED;
		}

		return FMRES_SUPERCEDE;
	}

	return FMRES_IGNORED;
}

/* Forwards > Ham */

public ham_player_takedamage_pre(
	pid_victim, id_inflictor, pid_attacker, Float:dmg, dmg_type_bitsum
)
{
	enum { param_dmg = 4 };

	if (g_game_starting || g_round_ended)
		return HAM_SUPERCEDE;

	if (g_players[pid_attacker][pd_team] == tm_zombie) {
		new used_prs = g_players[pid_victim][pd_prs_used];
		new bought_prs = g_players[pid_victim][pd_prs_bought];

		if (!(used_prs >= 50 && !random(4)) && !(used_prs > 150 && random(3)))
			return HAM_IGNORED;

		new Float:mult1 = 1 + (used_prs - 50)/5.0;
		new Float:mult2 = floatclamp(mult1 * 0.15, 0.0, 0.60) + 1.0;
		
		/* Make it easier for average players while slightly harder (?) for
		 * higher-level players (who earned, not bought, their prestiges). */
		if (used_prs > 40 && mult2 > 1.5)
			mult2 -= 0.15;
		
		if (used_prs > 150 && bought_prs < 65)
			mult2 += 0.30;
		if (used_prs > 130 && bought_prs < 40)
			mult2 += 0.10;

		SetHamParamFloat(param_dmg, dmg*mult2);
		return HAM_HANDLED;
	}

	return HAM_IGNORED;
}

public ham_player_traceattack_pre(
	pid_victim, pid_attacker, Float:dmg, Float:dir[3], tr, dmg_type_bitsum
)
{
	if (!g_game_started || g_round_ended || is_frozen(pid_attacker))
		return HAM_SUPERCEDE;

	if (!(dmg_type_bitsum & DMG_BULLET))
		return HAM_IGNORED;

	if (!is_user_connected(pid_victim) || g_players[pid_victim][pd_team] != tm_zombie)
		return HAM_IGNORED;

	static ammo_type;
	ammo_type = _gxp_wpn_ammo_types[get_user_weapon(pid_attacker)];
	if (ammo_type != -1) {
		static Float:victim_origin[3];
		static Float:attacker_origin[3];
		pev(pid_victim, pev_origin, victim_origin);
		pev(pid_attacker, pev_origin, attacker_origin);

		if (get_distance_f(victim_origin, attacker_origin) <= 200.0) {
			static Float:vel[3];
			pev(pid_victim, pev_velocity, vel);

		 	static Float:org_vec_z;
		 	org_vec_z = vel[2];

		 	xs_vec_mul_scalar(dir, dmg, dir);
		 	xs_vec_mul_scalar(dir, 1.0, dir);
		 	xs_vec_mul_scalar(dir, _gxp_ammo_kb_powers[ammo_type], dir);

		 	xs_vec_add(dir, vel, vel);
		 	vel[2] = org_vec_z;

		 	set_pev(pid_victim, pev_velocity, vel);

		 	return HAM_HANDLED;
		}
	}

	return HAM_IGNORED;
}

public ham_player_takedamage_post(
	pid_victim, id_inflictor, id_attacker, Float:dmg, dmg_type_bitsum
)
{
	if (g_game_starting || g_round_ended)
		return;

	if (GxpXpMethod:get_pcvar_num(g_pcvar_xp_method) != gxp_xp_dmg)
		return;

	if (pid_victim == id_attacker || (id_attacker < 1 || id_attacker > MAX_PLAYERS))
		return;

	if (g_players[pid_victim][pd_team] == g_players[id_attacker][pd_team])
		return;

	new class[GxpClass];
	get_class(pid_victim, class);

	/* Cap damage to actual HP so there's no extraneous XP awarded. */
	new Float:hp;
	pev(pid_victim, pev_health, hp);
	if (hp < 0.0)
		dmg -= floatabs(hp);

	new bonus_xp = 0;
	new bonus_xp_lvl = g_players[id_attacker][pd_powers][pwr_bonus_xp];
	if (bonus_xp_lvl > 0) {
		bonus_xp = floatround(
			dmg*gxp_power_get_delta(GxpPower:pwr_bonus_xp)*bonus_xp_lvl/class[cls_health],
			floatround_ceil
		);
	}

	give_xp(
		id_attacker,
		floatround(dmg*class[cls_xp_when_killed]/class[cls_health]),
		bonus_xp,
		"bonus"
	);
}

public ham_player_spawn_post(pid)
{
	if (!is_user_connected(pid) || g_players[pid][pd_team] == tm_unclassified)
		return;

	g_players[pid][pd_class] = pick_class(pid);

	suit_up(pid);

	/* Reset ability cooldown if its' longer than 1 s. */
	new class[GxpClass];
	get_class(pid, class);
	if (class[cls_ability_cooldown] > 1.0)
		g_players[pid][pd_ability_last_used] = get_gametime() - class[cls_ability_cooldown] + 1.0;

	/* Set several common class properties. */
	set_pev(pid, pev_health, float(get_max_hp(pid)));
	set_pev(pid, pev_armorvalue, float(class[cls_armour]));
	set_pev(pid, pev_maxspeed, float(class[cls_speed]));

	fm_set_user_rendering(pid, kRenderFxNone);

	ExecuteForward(g_fwd_player_spawned, _, pid);
}

public ham_item_deploy_post(ent)
{
	new pid = get_pdata_cbase(ent, UXO_P_PLAYER, UXO_LINUX_DIFF_ANIMATING);
	if (!is_user_alive(pid) || g_players[pid][pd_team] != tm_zombie || g_players[pid][pd_class] == 0)
		return;

	new classname[32 + 1];
	pev(ent, pev_classname, classname, charsmax(classname));
	if (equali(classname, "weapon_smokegrenade"))
		return;

	new class[GxpClass];
	get_class(pid, class);
	gxp_user_set_viewmodel(pid, class);
}

/* Messages */

public message_scoreattrib(msg_id, msg_dest, pid)
{
	enum { arg_flag = 2 };
#define MSG_SCOREATTRIB_NONE 0
#define MSG_SCOREATTRIB_DEAD (1 << 1)
	if (get_msg_arg_int(arg_flag) == MSG_SCOREATTRIB_DEAD)
		set_msg_arg_int(arg_flag, ARG_BYTE, MSG_SCOREATTRIB_NONE);
}

public message_statusicon(msg_id, msg_dest, pid)
{
	enum {
		arg_status 			= 1,
		arg_sprite_name = 2
	};

	new spr[5];
	get_msg_arg_string(arg_sprite_name, spr, charsmax(spr));
	if (spr[0] == 'b' && spr[2] == 'y' && spr[3] == 'z' && get_msg_arg_int(arg_status) == 1) {
		/* Omit buyzone from clients' map zones. */
		set_pdata_int(
			pid, UXO_F_CLIENT_MAP_ZONE, get_pdata_int(pid, UXO_F_CLIENT_MAP_ZONE) & ~(1 << 0)
		);
		return PLUGIN_HANDLED;
	} else if (equal(spr, "c4") || equal(spr, "buy")) {
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public message_textmsg(msg_id, msg_dest, pid)
{
	enum {
		arg_dest_type = 1,
		arg_msg				= 2
	};

#define MSG_TEXTMSG_DEST_TYPE_NOTIFY 	1
#define MSG_TEXTMSG_DEST_TYPE_CONSOLE 2
#define MSG_TEXTMSG_DEST_TYPE_CHAT		3
#define MSG_TEXTMSG_DEST_TYPE_CENTER 	4
#define MSG_TEXTMSG_DEST_TYPE_RADIO 	5

	new dest_type = get_msg_arg_int(arg_dest_type);
	if (dest_type != MSG_TEXTMSG_DEST_TYPE_CENTER) {
		if (dest_type == MSG_TEXTMSG_DEST_TYPE_RADIO && g_players[pid][pd_team] == tm_zombie)
			return PLUGIN_HANDLED;
		return PLUGIN_CONTINUE;
	}

	new msg[32];
	get_msg_arg_string(arg_msg, msg, charsmax(msg));

	if (
		equal(msg, "#Terrorists_Win")
		|| equal(msg, "#Target_Saved") || equal(msg, "#CTs_Win") || equal(msg, "#Hostages_Not_Rescued")
	) {
		new ml[32 + 1];
		copy(
			ml, charsmax(ml),
			equal(msg, "#Terrorists_Win")
				? "GXP_PRINT_ZOMBIES_DOMINATED"
				: "GXP_PRINT_SURVIVORS_DOMINATED"
		);

		for (new pid_r = 1; pid_r != MAX_PLAYERS + 1; ++pid_r) {
			if (!is_user_connected(pid_r) || is_user_bot(pid_r))
				continue;

			formatex(msg, charsmax(msg), "%L", pid_r, ml);
			message_begin(MSG_ONE, g_msgid_textmsg, .player = pid_r);
			write_byte(dest_type);
			write_string(msg);
			message_end();
		}
	}

	return PLUGIN_HANDLED;
}

public message_sendaudio(msg_id, msg_dest, pid)
{
	enum { arg_audiocode = 2 };

	new audiocode[22];
	get_msg_arg_string(arg_audiocode, audiocode, charsmax(audiocode));

	if (equal(audiocode[7], "terwin")) {
		set_msg_arg_string(arg_audiocode, g_zm_win_sounds[random(sizeof g_zm_win_sounds)]);
	} else if(equal(audiocode[7], "ctwin")) {
		set_msg_arg_string(arg_audiocode, g_human_win_sounds[random(sizeof g_human_win_sounds)]);
	} else {
		if (g_players[pid][pd_team] == tm_zombie)
			return PLUGIN_HANDLED;

		static const blocked_sounds[][] = { "rounddraw" };
		for (new i = 0; i != sizeof(blocked_sounds); ++i) {
			if (equal(audiocode[7], blocked_sounds[i]))
				return PLUGIN_HANDLED;
		}
	}

	return PLUGIN_CONTINUE;
}

public message_hudtextargs(msg_id, msg_dest, pid)
{
	return PLUGIN_HANDLED;
}

/* Events */

public event_new_round()
{
	g_round_ended = false;
	g_freeze_time = true;

	if (g_game_starting && !task_exists(tid_game_start_countdown)) {
		g_game_started = true;
		g_game_starting = false;
		g_gxp_round = 1;
		ExecuteForward(g_fwd_game_started);
	}

	for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid) {
		g_players[pid][pd_respawn_count] 	= 0;
		g_players[pid][pd_round_kills] 		= 0;
	}

	ExecuteForward(g_fwd_round_started, _, g_gxp_round);
}

public event_deathmsg()
{
	enum {
		data_killer = 1,
		data_victim = 2
	};

	new pid_killer = read_data(data_killer);
	new pid_victim = read_data(data_victim);

	g_players[pid_victim][pd_round_kills] = 0;

	if (pid_killer != pid_victim) {
		++g_players[pid_killer][pd_round_kills];

		if (GxpXpMethod:get_pcvar_num(g_pcvar_xp_method) == gxp_xp_kill) {
			new class[GxpClass];
			get_class(pid_victim, class);

			new bonus_xp_lvl = g_players[pid_killer][pd_powers][pwr_bonus_xp];
			if (bonus_xp_lvl > 0) {
				give_xp(
					pid_killer,
					class[cls_xp_when_killed],
					gxp_power_get_delta(GxpPower:pwr_bonus_xp)*bonus_xp_lvl,
					"bonus"
				);
			} else {
				give_xp(pid_killer, class[cls_xp_when_killed]);
			}
		}

		if (g_multi_max_n > 0) {
			new kills = g_players[pid_killer][pd_round_kills];
			for (new i = g_multi_max_n; i > 0; --i) {
				new kills_req = g_multi_kills_base + g_multi_kills_delta*(i - 1);
				if (kills >= kills_req) {
					new desc[10 + 1];
					formatex(desc, charsmax(desc), "multi-%d", kills_req);
					give_xp(pid_killer, g_multi_xp_base + g_multi_xp_delta*(i - 1), .desc = desc);
					break;
				}
			}
		}
	}

	ExecuteForward(g_fwd_player_cleanup, _, pid_victim);

	if (g_players[pid_victim][pd_team] == tm_zombie)
		set_task_ex(get_pcvar_float(g_pcvar_respawn_delay), "task_respawn", pid_victim + tid_respawn);
}

public event_teaminfo()
{
	new pid = read_data(1);
	new team[2];
	read_data(2, team, charsmax(team));
	if (team[0] == 'C') {
		g_players[pid][pd_team] = tm_survivor;
	} else if (team[0] == 'T') {
		g_players[pid][pd_team] = tm_zombie;
		if (!g_round_ended)
			set_task_ex(get_pcvar_float(g_pcvar_respawn_delay), "task_respawn", pid + tid_respawn);
	} else {
		g_players[pid][pd_team] = tm_unclassified;
	}

	/* Assign temporary class so that there is no conflict between team and class
	 * before new round. */
	g_players[pid][pd_class] = 1;
}

/* Credits: ConnorMcLeod @
 *   https://forums.alliedmods.net/showpost.php?p=846236&postcount=21 */

#define HUD_HIDE_CAL		(1 << 0)
#define HUD_HIDE_FLASH	(1 << 1)
#define HUD_HIDE_ALL		(1 << 2)
#define HUD_HIDE_RHA		(1 << 3)
#define HUD_HIDE_TIMER	(1 << 4)
#define HUD_HIDE_MONEY	(1 << 5)
#define HUD_HIDE_CROSS	(1 << 6)
#define HUD_DRAW_CROSS	(1 << 7)

#define HUD_HIDE_GEN_CROSS \
	(HUD_HIDE_FLASH | HUD_HIDE_RHA | HUD_HIDE_TIMER | HUD_HIDE_MONEY | HUD_DRAW_CROSS)

#define ZM_HUD_BITFLAGS (HUD_HIDE_FLASH | HUD_HIDE_RHA | HUD_HIDE_MONEY | HUD_HIDE_CAL)

public event_resethud(pid)
{
	if (g_players[pid][pd_team] == tm_zombie) {
		set_pdata_int(pid, UXO_I_CLIENT_HIDE_HUD, 0);
		set_pdata_int(pid, UXO_I_HIDE_HUD, ZM_HUD_BITFLAGS);
	}
}

public event_hideweapon(pid)
{
	enum { data_flags = 1 };

	if (g_players[pid][pd_team] != tm_zombie)
		return;

	new flags = read_data(data_flags);

	if ((flags & ZM_HUD_BITFLAGS != ZM_HUD_BITFLAGS)) {
		set_pdata_int(pid, UXO_I_CLIENT_HIDE_HUD, 0);
		set_pdata_int(pid, UXO_I_HIDE_HUD, flags | ZM_HUD_BITFLAGS);
	}

	if (flags & HUD_HIDE_GEN_CROSS && is_user_alive(pid))
		set_pdata_cbase(pid, UXO_P_CLIENT_ACTIVE_ITEM, FM_NULLENT);
}

public logevent_round_start()
{
	g_freeze_time = false;
}

public logevent_round_end()
{
	if (g_game_starting)
		return;

	static bool:first_round = true;
	if (first_round) {
		g_game_starting = true;
		first_round = false;
		set_task_ex(
			1.0, "task_start_countdown",
			tid_game_start_countdown, .flags = SetTask_RepeatTimes, .repeat = 30
		);
		return;
	}

	/* We postpone the work of actually ending the round a bit to let some powers
	 * (e.g., explosion on death) execute.
	 * `g_round_ending` is, conversely, used to prevent certain other powers from
	 * executing (such as respawn). */
	g_round_ending = true;
	set_task_ex(0.1, "task_end_round");
}

/* Client commands */

public clcmd_drop(pid)
{
	if (g_players[pid][pd_team] == tm_zombie) {
		ExecuteForward(g_fwd_player_used_secn_ability, _, pid);
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public clcmd_say(pid)
{
  new buffer[64 + 1];
  read_args(buffer, charsmax(buffer));
  remove_quotes(buffer);

  for (new i = 0; i != sizeof(g_clcmds); ++i) {
    if (equali(buffer, g_clcmds[i][0])) {
      callfunc_begin(g_clcmds[i][1]);
      callfunc_push_int(pid);
      callfunc_end();
      return PLUGIN_HANDLED;
    }
  }

  return PLUGIN_CONTINUE;
}

/* `say`/`say_team` client command handlers */

public handle_say_prs(pid)
{
	if (g_players[pid][pd_xp_curr] < _GXP_MAX_XP) {
		ExecuteForward(g_fwd_player_attempted_prs, _, pid, false);
		return;
	}

	++g_players[pid][pd_prs_stored];
	ExecuteForward(g_fwd_player_attempted_prs, _, pid, true);
	
	emit_sound(pid, CHAN_ITEM, SOUND_PRESTIGED, 1.0, ATTN_NORM, 0, PITCH_NORM);

	g_players[pid][pd_xp_curr] 				= 0;
	g_players[pid][pd_level] 					= 0;
	g_players[pid][pd_primary_gun] 		= 6;
	g_players[pid][pd_secondary_gun] 	= 0;

	if (g_players[pid][pd_team] == tm_survivor)
		suit_up(pid, .bypass_remember_sel = true);

	gxp_ul_deactivate(pid);
	gxp_ul_activate_free(pid);
	gxp_ul_activate_newbie(pid);
}

/* Tasks */

public task_start_countdown()
{
	static counter = 30;

	new color[3];

	if (--counter <= 0) {
		server_cmd("sv_restart 1");

		for (new pid = 1; pid != MAX_PLAYERS; ++pid) {
			if (!is_user_connected(pid) || !is_user_alive(pid) || is_user_bot(pid))
				continue;

			gxp_ui_get_colors(pid, color);
			set_hudmessage(color[0], color[1], color[2], -1.0, 0.1, 0, 0.0, 1.0, 0.1, 0.1);
			ShowSyncHudMsg(pid, g_hudsync_tc, "%L", pid, "GXP_HUD_GAME_STARTING");
		}

		/* Maintained for backwards compatibility. */
		ExecuteForward(g_fwd_bc_game_started);
	} else {
		for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid) {
			if (!is_user_connected(pid) || !is_user_alive(pid))
				continue;

			if (!is_user_bot(pid)) {
				gxp_ui_get_colors(pid, color);
				set_hudmessage(color[0], color[1], color[2], -1.0, 0.1, 0, 0.0, 1.0, 0.1, 0.1);
				ShowSyncHudMsg(pid, g_hudsync_tc, "%L", pid, "GXP_HUD_GAME_WILL_START_IN_N", counter);
			}

			if (g_players[pid][pd_team] == tm_survivor)
				fm_set_user_rendering(pid, kRenderFxGlowShell, 0, 35, 240, kRenderNormal, 70);
			else if (g_players[pid][pd_team] == tm_zombie)
				fm_set_user_rendering(pid, kRenderFxGlowShell, 240, 35, 0, kRenderNormal, 70);
		}

#define FORCE_BALANCE_AFTER 27
		if (counter == 30 - FORCE_BALANCE_AFTER)
			tb_balance(0);
	}
}

public task_respawn(tid)
{
	new pid = tid - tid_respawn;
	if (is_user_connected(pid) && !is_user_alive(pid) && g_players[pid][pd_team] == tm_zombie) {
		ExecuteHamB(Ham_CS_RoundRespawn, pid);
		++g_players[pid][pd_respawn_count];
	}
}

public task_end_round()
{
	g_round_ending = false;
	g_round_ended = true;

	new total_players = get_playersnum_ex(GetPlayers_ExcludeHLTV | GetPlayers_MatchTeam, "TERRORIST")
		+ get_playersnum_ex(GetPlayers_ExcludeHLTV | GetPlayers_MatchTeam, "CT");
	if (total_players >= g_survival_min_players) {
		new xp = g_survival_xp;
		if (total_players >= g_survival_mod_min_players)
			xp += (total_players - g_survival_mod_min_players + 1)*g_survival_mod_xp;

		for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid) {
			if (!is_user_alive(pid) || g_players[pid][pd_team] != tm_survivor)
				continue;
			give_xp(pid, xp, .desc = "survival");
			ExecuteForward(g_fwd_player_survived, _, pid, xp);
		}
	}

	ExecuteForward(g_fwd_round_ended, _, g_gxp_round);
	ExecuteForward(g_fwd_cleanup);

	if (g_gxp_round++ == get_pcvar_num(g_pcvar_rounds_per_team)) {
		g_gxp_round = 1;

		for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid) {
			if (!is_user_connected(pid) || g_players[pid][pd_team] == tm_unclassified)
				continue;

			if (g_players[pid][pd_team] == tm_survivor) {
				transfer_player(pid, tm_zombie);
				fm_strip_user_weapons(pid);
				fm_give_item(pid, "weapon_knife");
			} else {
				transfer_player(pid, tm_survivor);
			}
		}

		ExecuteForward(g_fwd_teams_swapped);
	}
}

/* Utilities */

pick_class(pid)
{
	new Array:classes = g_players[pid][pd_team] == tm_survivor
		? g_survivor_classes : g_zombie_classes;
	new classnum = ArraySize(classes);
	new reg_class[RegisteredClass];

	/* See if any class requires it to be selected. */
	for (new i = 0; i != classnum; ++i) {
		ArrayGetArray(classes, i, reg_class);

		if (reg_class[reg_cls_req_callback][0] == '^0')
			continue;

		new bool:required;

		callfunc_begin(reg_class[reg_cls_req_callback], reg_class[reg_cls_plugin]);
		callfunc_push_int(pid);
		callfunc_push_intrf(required);
		callfunc_end();

		if (required)
			return i + 1;
	}

	/* If no such class is found, attempt to pick one at random. */
	for (new attempts = 0;;) {
		new cid = random_num(1, classnum);
		ArrayGetArray(classes, cid - 1, reg_class);

		if (reg_class[reg_cls_acc_callback][0] == '^0')
			return cid;

		new bool:available;

		callfunc_begin(reg_class[reg_cls_acc_callback], reg_class[reg_cls_plugin]);
		callfunc_push_int(pid);
		callfunc_push_intrf(available);
		callfunc_end();

		if (available)
			return cid;

#define MAX_RANDOM_CLASS_ATTEMPTS 10
		if (++attempts == MAX_RANDOM_CLASS_ATTEMPTS) {
			for (new i = 0; i != classnum; ++i) {
				ArrayGetArray(classes, i, reg_class);
				if (reg_class[reg_cls_acc_callback][0] == '^0')
					return i + 1;
			}
			return cid;
		}
	}

	return 1;
}

set_xp(pid, xp_new)
{
	new xp = g_players[pid][pd_xp_curr] = clamp(xp_new, 0, _GXP_MAX_XP);
	new old_lvl = g_players[pid][pd_level];	

	g_players[pid][pd_level] = 0;
	for (new i = 0; i != _GXP_MAX_LEVEL; ++i) {
		if (xp < _gxp_xp_level_map[i + 1])
			break;
		++g_players[pid][pd_level];
	}

	new lvl = g_players[pid][pd_level];
	if (old_lvl < lvl) {
		new origin[3];
		get_user_origin(pid, origin);

		ufx_te_explosion(origin, g_spr_level_up, 3.0, 15, ufx_explosion_nosound);
		emit_sound(pid, CHAN_ITEM, SOUND_LEVELLED_UP, 1.0, ATTN_NORM, 0, PITCH_NORM);

		ExecuteForward(g_fwd_player_levelled_up, _, pid, old_lvl, lvl);
	} else if (old_lvl > lvl) {
		/* Level has become insufficient for desired gun - reduce selection, and
		 * force player to choose again. */
		if (lvl < g_players[pid][pd_secondary_gun]) {
			g_players[pid][pd_secondary_gun] = lvl;
			g_players[pid][pd_remember_sel] = gxp_remember_sel_off;
		}
	}
}

give_xp(pid, xp, bonus_xp = 0, const desc[] = "")
{
	if (g_players[pid][pd_xp_curr] == _GXP_MAX_XP)
		return;
	set_xp(pid, g_players[pid][pd_xp_curr] + xp + bonus_xp);
	ExecuteForward(g_fwd_player_gained_xp, _, pid, xp, bonus_xp, desc);
}

take_xp(pid, xp)
{
	set_xp(pid, g_players[pid][pd_xp_curr] - xp);
}

suit_up(pid, bool:bypass_remember_sel = false)
{
	fm_strip_user_weapons(pid);
	fm_give_item(pid, "weapon_knife");

	if (g_players[pid][pd_team] == tm_survivor) {
		fm_give_item(pid, "weapon_flashbang");
		fm_give_item(pid, "weapon_flashbang");
		fm_give_item(pid, "weapon_hegrenade");
		fm_give_item(pid, "weapon_smokegrenade");

		if (bypass_remember_sel || g_players[pid][pd_remember_sel] != gxp_remember_sel_off) {
			if (g_players[pid][pd_level] >= _GXP_SECN_GUN_COUNT)
				give_gun(pid, g_players[pid][pd_primary_gun]);
			give_gun(pid, g_players[pid][pd_secondary_gun]);
		}
	}
}

give_gun(pid, gun_id)
{
	new base;
	new end;

	/* Gun is primary */
	if (gun_id >= _GXP_SECN_GUN_COUNT) {
		base = _GXP_SECN_GUN_COUNT;
		end = _GXP_GUN_COUNT;
	/* Gun is secondary */
	} else {
		base = 0;
		end = _GXP_SECN_GUN_COUNT;
	}

	/* Strip guns of the same category as the new gun. */
	for (new i = base; i != end; ++i)
		fm_strip_user_gun(pid, _gxp_weapon_ids[i]);

	fm_give_item(pid, _gxp_internal_gun_names[gun_id]);
	cs_set_user_bpammo(pid, _gxp_weapon_ids[gun_id], _gxp_bpammo[gun_id]);

	emit_sound(pid, CHAN_ITEM, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

compute_skill(pid)
{
  if (!is_user_connected(pid) || is_user_hltv(pid))
  	return;

  if (is_user_bot(pid)) {
  	tb_set_player_skill(pid, random_float(10.0, 400.0));
  	return;
  }

  new kills 	= g_players[pid][pd_stats][gxp_pstats_kills];
  new deaths 	= g_players[pid][pd_stats][gxp_pstats_deaths];
  new hs 			= g_players[pid][pd_stats][gxp_pstats_hs];

  if (kills == 0) {
  	tb_set_player_skill(pid, 0.0);
  	return;
  } else if (deaths == 0) {
  	tb_set_player_skill(pid, float(kills*2));
  	return;
  }

  tb_set_player_skill(
  	pid,
		0.4*(1.0*kills/deaths)*100
			+ 0.1*(1.0*hs/kills)*100
			+ 0.4*g_players[pid][pd_prs_used]
			+ 0.1*(g_players[pid][pd_prs_used] - g_players[pid][pd_prs_bought])
	);
}

reset_player_data(pid)
{
  g_players[pid][pd_team]								= tm_unclassified;
  g_players[pid][pd_class]							= 0;
  g_players[pid][pd_xp_curr] 						= 0;
  g_players[pid][pd_xp_bought] 					= 0;
  g_players[pid][pd_level] 							= 0;
  g_players[pid][pd_prs_stored] 				= 0;
  g_players[pid][pd_prs_used] 					= 0;
  g_players[pid][pd_prs_bought]					= 0;
  g_players[pid][pd_primary_gun]				= 6;
  g_players[pid][pd_secondary_gun]			= 0;
  g_players[pid][pd_remember_sel]				= gxp_remember_sel_off;
  g_players[pid][pd_ability_last_used]	= 0.0;
  g_players[pid][pd_respawn_count]			= 0;
  g_players[pid][pd_round_kills]				= 0;

  arrayset(g_players[pid][pd_powers], 0, _:GxpPower);
  for (new i = 0; i != GxpUlClass; ++i)
  	g_players[pid][pd_uls][i] = ArrayCreate();
}

transfer_player(pid, GxpTeam:team)
{
  static team_info_msgid;
  if (team_info_msgid == 0)
    team_info_msgid = get_user_msgid("TeamInfo");

  new CsTeams:team_id = team == tm_survivor ? CS_TEAM_CT : CS_TEAM_T;

  cs_set_user_team(pid, team_id, CS_NORESET, false);

  emessage_begin(MSG_ALL, team_info_msgid);
  ewrite_byte(pid);
  ewrite_string(team_id == CS_TEAM_T ? "TERRORIST" : "CT");
  emessage_end();
}

get_class(pid, class[GxpClass])
{
	new reg_class[RegisteredClass];
	ArrayGetArray(
		g_players[pid][pd_team] == tm_survivor ? g_survivor_classes : g_zombie_classes,
		g_players[pid][pd_class] - 1,
		reg_class
	);
	gxp_config_get_class(reg_class[reg_cls_id], class);
}

get_max_hp(pid)
{
	if (g_players[pid][pd_team] == tm_unclassified)
		return 0;

	new class[GxpClass];
	get_class(pid, class);

	if (g_players[pid][pd_team] == tm_survivor) {
		new base_hp_lvl = g_players[pid][pd_powers][pwr_base_hp];
		return class[cls_health] + gxp_power_get_delta(GxpPower:pwr_base_hp)*base_hp_lvl;
	} else {
		new respawns = clamp(
			g_players[pid][pd_respawn_count],
			0,
			is_newbie(pid) ? g_max_newbie_respawns_for_bonus_hp : g_max_respawns_for_bonus_hp
		);
    /* POWER:ZM ADD HEALTH */
		new bonus_hp_lvl = g_players[pid][pd_powers][pwr_zm_add_health];
		return class[cls_health]
			+ g_bonus_hp_per_respawn*respawns
			+ gxp_power_get_delta(GxpPower:pwr_zm_add_health)*bonus_hp_lvl;
	}
}

bool:is_newbie(pid)
{
#define NEWBIE_MAX_PRS 			0
#define NEWBIE_MAX_USED_PRS 0
#define NEWBIE_MAX_XP 			699999
	return g_players[pid][pd_prs_stored] <= NEWBIE_MAX_PRS
		&& g_players[pid][pd_prs_used] <= NEWBIE_MAX_USED_PRS
		&& g_players[pid][pd_xp_curr] <= NEWBIE_MAX_XP;
}

/* Natives */

public bool:native_has_game_started(plugin, argc)
{
	return g_game_started;
}

public bool:native_has_round_started(plugin, argc)
{
	return !g_round_ended;
}

public bool:native_has_round_ended(plugin, argc)
{
	return g_round_ended;
}

public bool:native_is_round_ending(plugin, argc)
{
	return g_round_ending;
}

public bool:native_in_freeze_time(plugin, argc)
{
	return g_freeze_time;
}

public native_get_player_data(plugin, argc)
{
	enum {
		param_pid 				= 1,
		param_data_field	= 2,
		param_buffer 			= 3
	};

	new pid = get_param(param_pid);
	new GxpPlayer:df = GxpPlayer:get_param(param_data_field);
	if (df == pd_powers)
		set_array(param_buffer, g_players[pid][pd_powers], sizeof(g_players[][pd_powers]));
	else if (df == pd_uls)
		set_array(param_buffer, _:g_players[pid][pd_uls], sizeof(g_players[][pd_uls]));
	else
		return g_players[pid][df];

	return -1;
}

public native_set_player_data(plugin, argc)
{
	enum {
		param_pid 				= 1,
		param_data_field 	= 2,
		param_value 			= 3,
		param_buffer 			= 4
	};

	new GxpPlayer:df = GxpPlayer:get_param(param_data_field);
	if (df == pd_uls)
		return;

	new pid = get_param(param_pid);	
	if (df == pd_powers)
		get_array(param_buffer, g_players[pid][pd_powers], sizeof(g_players[][pd_powers]));
	else
		g_players[pid][df] = get_param(param_value);
}

public native_get_player_stat(plugin, argc)
{
	enum {
		param_pid		= 1,
		param_stat	= 2
	};
	return g_players[get_param(param_pid)][pd_stats][GxpPlayerStats:get_param(param_stat)];
}

public native_set_player_stat(plugin, argc)
{
	enum {
		param_pid		= 1,
		param_stat	= 2,
		param_value	= 3
	};
	g_players[get_param(param_pid)][pd_stats][GxpPlayerStats:get_param(param_stat)] =
		get_param(param_value);
}

public native_get_player_class(plugin, argc)
{
	enum {
		param_pid 	= 1,
		param_class	= 2
	};
	new class[GxpClass];
	get_class(get_param(param_pid), class);
	set_array(param_class, class, sizeof(class));
}

public native_register_class(plugin, argc)
{
	enum {
		param_id							= 1,
		param_team						= 2,
		param_acc_callback		= 3,
		param_req_callback		= 4
	};

	new GxpTeam:team = GxpTeam:get_param(param_team);
	if (team == tm_unclassified)
		return -1;

	new Array:classes;

	if (team == tm_survivor) {
		classes = g_survivor_classes;
		if (ArraySize(classes) == GXP_MAX_SURVIVOR_CLASSES)
			return -1;
	} else {
		classes = g_zombie_classes;
		if (ArraySize(classes) == GXP_MAX_ZOMBIE_CLASSES)
			return -1;
	}

	new class[RegisteredClass];
	get_string(param_id, class[reg_cls_id], charsmax(class[reg_cls_id]));
	get_string(
		param_acc_callback, class[reg_cls_acc_callback], charsmax(class[reg_cls_acc_callback])
	);
	get_string(
		param_req_callback, class[reg_cls_req_callback], charsmax(class[reg_cls_req_callback])
	);
	get_plugin(plugin, class[reg_cls_plugin], charsmax(class[reg_cls_plugin]));

	ArrayPushArray(classes, class);

	return ArraySize(classes);
}

public native_give_xp(plugin, argc)
{
	enum {
		param_pid = 1,
		param_xp	= 2
	};
	give_xp(get_param(param_pid), get_param(param_xp));
}

public native_take_xp(plugin, argc)
{
	enum {
		param_pid = 1,
		param_xp	= 2
	};
	take_xp(get_param(param_pid), get_param(param_xp));
}

public native_give_gun(plugin, argc)
{
	enum {
		param_pid 		= 1,
		param_gun_id	= 2
	};
	give_gun(get_param(param_pid), get_param(param_gun_id));
}

public bool:native_is_newbie(plugin, argc)
{
	enum { param_pid = 1 };
	return is_newbie(get_param(param_pid));
}

public bool:native_is_vip(plugin, argc)
{
	enum { param_pid = 1 };
	return bool:(get_user_flags(get_param(param_pid)) & _gxp_access_map[gxp_priv_vip]);
}

public bool:native_is_admin(plugin, argc)
{
	enum { param_pid = 1 };
	return bool:(get_user_flags(get_param(param_pid)) & _gxp_access_map[gxp_priv_admin]);
}

public bool:native_is_sadmin(plugin, argc)
{
	enum { param_pid = 1 };
	return bool:(get_user_flags(get_param(param_pid)) & _gxp_access_map[gxp_priv_sadmin]);
}

public native_get_max_hp(plugin, argc)
{
	enum { param_pid = 1 };
	return get_max_hp(get_param(param_pid));
}

/* Natives > Backwards compatibility */

public bool:native_bc_is_zombie(plugin, argc)
{
	enum { param_pid = 1 };
	return g_players[get_param(param_pid)][pd_team] == tm_zombie;
}

public native_bc_get_user_level(plugin, argc)
{
	enum { param_pid = 1 };
	return g_players[get_param(param_pid)][pd_level];
}

public native_bc_get_user_xp(plugin, argc)
{
	enum { param_pid = 1 };
	return g_players[get_param(param_pid)][pd_xp_curr];
}

public native_bc_set_user_xp(plugin, argc)
{
	enum {
		param_pid = 1,
		param_xp 	= 2
	};
	set_xp(get_param(param_pid), get_param(param_xp));
}