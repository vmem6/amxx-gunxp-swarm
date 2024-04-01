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

#define DEBUG

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

#include <utils_log>
#include <utils_effects>
#include <utils_text>
#include <utils_offsets>

#define VALIDATE_PID(%0) 						\
	new pid = get_param(param_pid);		\
	if (pid < 1 || pid > MAX_PLAYERS)	\
		return %0

#define SOUND_LEVELLED_UP	"level_up_new.wav"
#define SOUND_PRESTIGED 	"level_up_new.wav"

native afk_is_in_godmode(pid);

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
	tid_game_start_countdown,
	tid_give_jump_bomb
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

new g_skill_levels[SkillLevels][SkillLevel] =
{
  { "L-",   0.0 },
  { "L",   31.0 },
  { "L+",  41.0 },
  { "M-",  51.0 },
  { "M",   61.0 },
  { "M+",  71.0 },
  { "H-",  86.0 },
  { "H",  101.0 },
  { "H+", 116.0 },
  { "P-", 131.0 },
  { "P",  146.0 },
  { "P+", 161.0 }
};

new g_players[MAX_PLAYERS + 1][GxpPlayer];
new bool:g_player_loaded[MAX_PLAYERS + 1];

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

new Float:g_skill_base;

/* Resources */

new g_spr_level_up;
new g_spr_zombie_spawn;

/* Forwards */

new g_fwd_cleanup;

new g_fwd_game_started;
new g_fwd_round_started;
new g_fwd_round_ended;

new g_fwd_teams_swapped;

new g_fwd_player_spawned;
new g_fwd_player_killed;
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

/* Miscellaneous */

new g_prefix[_GXP_MAX_PREFIX_LENGTH + 1];

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
	register_native("gxp_is_freevip", "native_is_freevip");
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
	g_spr_zombie_spawn = engfunc(EngFunc_PrecacheModel, "sprites/jailas_swarm/poison_spr.spr");

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

	g_fwd_player_spawned 	= CreateMultiForward("gxp_player_spawned", ET_IGNORE, FP_CELL);
	g_fwd_player_killed 	=
		CreateMultiForward("gxp_player_killed", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL);
	g_fwd_player_cleanup 	= CreateMultiForward("gxp_player_cleanup", ET_IGNORE, FP_CELL);

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
	register_forward(FM_CmdStart, "fm_cmdstart_post", ._post = 1);

	/* Forwards > Ham */

	RegisterHam(Ham_TakeDamage, "player", "ham_player_takedamage_pre");
	RegisterHam(Ham_Touch, "weaponbox", "ham_weaponbox_touch_pre");
	RegisterHam(Ham_TakeDamage, "player", "ham_player_takedamage_post", .Post = 1);
	RegisterHam(Ham_Killed, "player", "ham_player_killed_post", .Post = 1);
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
	register_event_ex("TeamInfo", "event_teaminfo", RegisterEvent_Global);
	register_event_ex("ResetHUD", "event_resethud", RegisterEvent_Single);
	register_event_ex("HideWeapon", "event_hideweapon", RegisterEvent_Single);
	register_event_ex("WeapPickup", "event_weappickup", RegisterEvent_Single);

	register_logevent("logevent_round_start", 2, "1=Round_Start");
	register_logevent("logevent_round_end", 2, "1=Round_End");

	/* Client commands */

	register_clcmd("drop", "clcmd_drop");
	register_clcmd("say", "clcmd_say");
	register_clcmd("say_team", "clcmd_say");

	/* Loggers */

	ulog_register_logger("gxp_core", "gunxp_swarm");
	ulog_register_logger("gxp_level", "gunxp_swarm");

	ULOG("gxp_core", INFO, 0, "Plugin initialized.");
	ULOG("gxp_level", INFO, 0, "Plugin initialized.");

	/* Miscellaneous */

	g_survivor_classes = ArrayCreate(RegisteredClass);
	g_zombie_classes = ArrayCreate(RegisteredClass);

	g_hudsync_tc = CreateHudSyncObj();

	new Array:levels = ArrayCreate(SkillLevel);
	for (new i = 0; i != SkillLevels; ++i)
		ArrayPushArray(levels, g_skill_levels[i]);
	tb_set_skill_levels(levels);
	ArrayDestroy(levels);
}

public plugin_cfg()
{
	new sql_plugin = is_plugin_loaded(_GXP_SWARM_SQL_PLUGIN);
	if (sql_plugin == INVALID_PLUGIN_ID)
		set_fail_state("^"%s^" must be loaded.", _GXP_SWARM_SQL_PLUGIN);

	_gxp_sql_set_up();

	bind_pcvar_string(get_cvar_pointer("gxp_info_prefix"), g_prefix, charsmax(g_prefix));
	fix_colors(g_prefix, charsmax(g_prefix));

	bind_pcvar_float(get_cvar_pointer("tb_skill_base"), g_skill_base);
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
	DestroyForward(g_fwd_player_killed);
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

	reset_player_data(pid);

	if (is_user_bot(pid)) {
		gxp_ul_activate_bot(pid);
		compute_skill(pid);
	} else {
		_gxp_sql_load_player_data(pid);
	}
}

public client_disconnected(pid, bool:drop, message[], maxlen)
{
	if (is_user_hltv(pid))
		return;

	ExecuteForward(g_fwd_player_cleanup, _, pid);

	g_players[pid][pd_ability_in_use] = false;

	for (new i = 0; i != GxpUlClass; ++i)
		ArrayDestroy(g_players[pid][pd_uls][i]);

	TrieDestroy(g_players[pid][pd_kill_contributors]);

	if (is_user_bot(pid))
		return;

	if (state_get_player_sid(pid) == 0 || get_user_time(pid) < 5 || !g_player_loaded[pid])
		return;

	if (g_players[pid][pd_remember_sel] == gxp_remember_sel_map)
		g_players[pid][pd_remember_sel] = gxp_remember_sel_off;

	g_players[pid][pd_stats][gxp_pstats_playtime] += get_user_time(pid);

	_gxp_sql_save_player_data(pid);
}

/* Forwards > GunXP */

public gxp_player_data_loaded(pid)
{
	g_player_loaded[pid] = true;

	gxp_ul_activate_free(pid);
	gxp_ul_activate_newbie(pid);

	compute_skill(pid);

#if defined DEBUG
	new pwrs[GxpPower];
	copy(pwrs, sizeof(pwrs), g_players[pid][pd_powers]);

	new stats[GxpPlayerStats];
	copy(stats, sizeof(stats), g_players[pid][pd_stats]);

	ULOG( \
		"gxp_core", INFO, pid, \
		"Loaded data for ^"@name^" (@id/%d). [AuthID: @authid] [IP: @ip] \
		[Primary: xc: %d; xb: %d; l: %d; ps: %d; pu: %d; pb: %d] \
		[Powers: s: %d; rc: %d; bh: %d; d: %d; g: %d; hr: %d; bx: %d; ed: %d; her: %d; \
		sgr: %d; si: %d; fd: %d; jc: %d; jd: %d; zah: %d] \
		[Stats: k: %d; wk: %.1f; d: %d; h: %d; sui: %d; sur: %d; p: %d; pc: %d; at: %d]", \
		state_get_player_sid(pid), \
		g_players[pid][pd_xp_curr], g_players[pid][pd_xp_bought], g_players[pid][pd_level], \
		g_players[pid][pd_prs_stored], g_players[pid][pd_prs_used], g_players[pid][pd_prs_bought], \
		pwrs[pwr_speed], pwrs[pwr_respawn_chance], pwrs[pwr_base_hp], pwrs[pwr_damage], \
		pwrs[pwr_gravity], pwrs[pwr_hp_regen], pwrs[pwr_bonus_xp], pwrs[pwr_expl_dmg], \
		pwrs[pwr_he_regen], pwrs[pwr_sg_regen], pwrs[pwr_shooting_interval], pwrs[pwr_fall_dmg], \
		pwrs[pwr_jump_bomb_chance], pwrs[pwr_jump_bomb_dmg], pwrs[pwr_zm_add_health], \
		stats[gxp_pstats_kills], stats[gxp_pstats_weighted_kills], stats[gxp_pstats_deaths], \
		stats[gxp_pstats_hs], stats[gxp_pstats_suicides], stats[gxp_pstats_survivals], \
		stats[gxp_pstats_playtime], stats[gxp_pstats_playtime_ct], stats[gxp_pstats_aggro_time] \
	);
#endif // DEBUG
}

/* Forwards > FakeMeta */

public fm_emitsound_pre(pid, chan, sample[], Float:vol, Float:attn, flag, pitch)
{
	if (!is_user_connected(pid) || g_players[pid][pd_class] == 0)
		return FMRES_IGNORED;

	/* `+use` */
	if (equal(sample, "common/wpn_denyselect.wav"))
		return FMRES_SUPERCEDE;

	if (equal(sample, "hostage", 7) || equal(sample, "nvg", 3))
		return FMRES_SUPERCEDE;

	new class[GxpClass];
	get_class(pid, class);
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

public fm_cmdstart_post(pid, uc_handle)
{
	if (!is_user_connected(pid) || g_players[pid][pd_class] == 0)
		return;

	new buttons = get_uc(uc_handle, UC_Buttons);
	if ((buttons & IN_USE) && !(pev(pid, pev_oldbuttons) & IN_USE)) {
		static class[GxpClass];
		get_class(pid, class);
		if (
			!g_freeze_time && !g_round_ended
			&& ((pev(pid, pev_flags) & FL_ONGROUND) || class[cls_midair_ability])
		) {
			ExecuteForward(g_fwd_player_used_ability, _, pid);
		}
	}
}

/* Forwards > Ham */

public ham_player_takedamage_pre(
	pid_victim, id_inflictor, id_attacker, Float:dmg, dmg_type_bitsum
)
{
	enum { param_dmg = 4 };

	if (!g_game_started || g_round_ended)
		return HAM_SUPERCEDE;

	if (id_attacker < 1 || id_attacker > MAX_PLAYERS)
		return HAM_IGNORED;

	if (is_frozen(id_attacker) || afk_is_in_godmode(pid_victim))
		return HAM_SUPERCEDE;

	if (g_players[id_attacker][pd_team] == tm_zombie) {
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

public ham_weaponbox_touch_pre(wpn_box, id)
{
	if (id < 1 || id > MAX_PLAYERS || !is_user_alive(id))
		return HAM_IGNORED;

	if (g_players[id][pd_team] == tm_zombie) {
		return HAM_SUPERCEDE;
	} else if (g_players[id][pd_team] == tm_survivor) {
		/* Assumes single weapon per weaponbox. */
		static wpn;
		for (new i = 0; i != sizeof(uxo_rgp_player_items); ++i) {
			wpn = get_pdata_cbase(wpn_box, uxo_rgp_player_items[i], UXO_LINUX_DIFF_WEAPONBOX);
			if (pev_valid(wpn))
				break;
		}

		if (!pev_valid(wpn))
			return HAM_IGNORED;

		static wid; wid = get_pdata_int(wpn, UXO_I_ID, UXO_LINUX_DIFF_ANIMATING);
		for (new lvl = 0; lvl <= g_players[id][pd_level]; ++lvl) {
			if (_gxp_weapon_ids[lvl] == wid)
				return HAM_IGNORED;
		}

		return HAM_SUPERCEDE;
	}

	return HAM_IGNORED;
}

public ham_player_takedamage_post(
	pid_victim, id_inflictor, id_attacker, Float:dmg, dmg_type_bitsum
)
{
	if (!g_game_started || g_round_ended)
		return;

	if (g_players[pid_victim][pd_team] == g_players[id_attacker][pd_team])
		return;

	if (afk_is_in_godmode(pid_victim))
		return;

	new Float:actual_dmg = dmg;

	/* Cap damage to actual HP so there's no extraneous XP awarded, and no
	 * additional weight of a kill to a contributor is awarded. */
	new Float:hp;
	pev(pid_victim, pev_health, hp);
	if (hp < 0.0)
		dmg -= floatabs(hp);

	if (pid_victim != id_attacker && id_attacker >= 1 && id_attacker <= MAX_PLAYERS) {
		new id_att_str[2 + 1];
		num_to_str(id_attacker, id_att_str, charsmax(id_att_str));

		new Float:stored_dmg = 0.0;
		TrieGetCell(g_players[pid_victim][pd_kill_contributors], id_att_str, stored_dmg);
		TrieSetCell(g_players[pid_victim][pd_kill_contributors], id_att_str, stored_dmg + dmg);
	}

	/* We handle some logic concerning user death here primarily because we need
	 * to keep track of contributions accurately. If we handled them on `DeathMsg`
	 * or `Ham_Killed` (which is, in reality, the same), we would lose the last
	 * contribution; if we fetched the contributions on (pre) `Ham_TakeDamage`,
	 * the damage dealt would be inaccurate since it is modified along the way
	 * many times. */
	if (!is_user_alive(pid_victim))
		handle_user_death(pid_victim, id_attacker, actual_dmg);

	if (GxpXpMethod:get_pcvar_num(g_pcvar_xp_method) != gxp_xp_dmg)
		return;

	if (pid_victim == id_attacker || (id_attacker < 1 || id_attacker > MAX_PLAYERS))
		return;

	static class[GxpClass];
	get_class(pid_victim, class);

	new Float:xp = dmg*class[cls_xp_when_killed]/class[cls_health];
	if (!is_newbie(id_attacker))
		xp *= 0.8; // -20%
	if (is_user_bot(pid_victim))
		xp *= 0.01;

	if (xp > 10000.0) {
		ULOG( \
			"gxp_core", WARNING, id_attacker, \
			"[BUG-H] ^"@name^" (@id/%d) would've received %d XP! [Damage: %.1f] [Victim: %s (%.1f HP)]", \
			state_get_player_sid(id_attacker), floatround(xp), dmg, class[cls_title], hp \
		);
		return;
	} else if (xp > 2500.0) {
		ULOG( \
			"gxp_core", WARNING, id_attacker, \
			"[BUG-M] ^"@name^" (@id/%d) received %d XP! [Damage: %.1f] [Victim: %s (%.1f HP)]", \
			state_get_player_sid(id_attacker), floatround(xp), dmg, class[cls_title], hp \
		);
	}

	new bonus_xp = 0;
	new bonus_xp_lvl = g_players[id_attacker][pd_powers][pwr_bonus_xp];
	if (bonus_xp_lvl > 0) {
		/* For example, delta = 100, and lvl = 3, then scale = 100/100 * 3/10 = 0.3. */
		new Float:scale = (gxp_power_get_delta(GxpPower:pwr_bonus_xp)/100.0)*(bonus_xp_lvl/10.0);
		bonus_xp = floatround(xp*scale, floatround_ceil);
		if (bonus_xp > 1500) {
			ULOG( \
				"gxp_core", WARNING, id_attacker, \
				"[BUG-H] ^"@name^" (@id/%d) received %d bonus XP! [Damage: %.1f] [Victim: %s (%.1f HP)]", \
				state_get_player_sid(id_attacker), bonus_xp, dmg, class[cls_title], hp \
			);
		}
	}

	give_xp(id_attacker, floatround(xp), bonus_xp, bonus_xp > 0 ? "bonus" : "");
}

public ham_player_killed_post(pid_victim, id_attacker, shouldgib)
{
	fm_set_user_rendering(pid_victim, kRenderFxNone, 0, 0, 0, kRenderNormal, 0);

	ExecuteForward(g_fwd_player_cleanup, _, pid_victim);

	g_players[pid_victim][pd_ability_in_use] = false;

	/* The victim was slayed, or they committed suicide through some means other
	 * than fall damage. In either case, `ham_player_takedamage_post` will not be
	 * invoked, and, consequently, neither will `handle_user_death`, so clear kill
	 * contributors trie here. */
	if (pid_victim == id_attacker) {
		ULOG("gxp_stats", INFO, pid_victim, "Clearing kill contributors trie for ^"@name^" (@id).");
		TrieClear(g_players[pid_victim][pd_kill_contributors]);
	}

	if (!g_round_ended && g_players[pid_victim][pd_team] == tm_zombie)
		set_task_ex(get_pcvar_float(g_pcvar_respawn_delay), "task_respawn", pid_victim + tid_respawn);
}

public ham_player_spawn_post(pid)
{
	if (!is_user_connected(pid) || g_players[pid][pd_team] == tm_unclassified)
		return;

	g_players[pid][pd_class] = pick_class(pid);

	suit_up(pid);

	/* Reset ability cooldowns to 1 s. */
	new class[GxpClass];
	get_class(pid, class);
	g_players[pid][pd_ability_last_used] = get_gametime() - class[cls_ability_cooldown] + 1.0;
	g_players[pid][pd_secn_ability_last_used] =
		get_gametime() - class[cls_secn_ability_cooldown] + 1.0;
	/* By default, assume all classes have abilities which are ready to be used
	 * the moment a player spawns. */
	g_players[pid][pd_ability_available] = true;
	g_players[pid][pd_ability_in_use] = false;

	set_pev(pid, pev_health, float(get_max_hp(pid)));
	set_pev(pid, pev_armorvalue, float(class[cls_armour]));
	set_pev(pid, pev_maxspeed, float(class[cls_speed]));

	if (g_players[pid][pd_team] == tm_zombie) {
		new origin[3];
		get_user_origin(pid, origin);
		ufx_te_sprite(origin, g_spr_zombie_spawn, 0.6, 200);
	}

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

	if (g_game_starting) {
		/* Cleanup is usually deferred to round end but round restarts (either
		 * because someone joins a team, teams are balanced, or for whatever other
		 * reason) don't trigger a "Round_End" logevent, so we perform a general
		 * cleanup on new round on such occasions (that happen only when the game is
		 * starting). */
		cleanup();

		if (!task_exists(tid_game_start_countdown)) {
			g_game_started = true;
			g_game_starting = false;
			g_gxp_round = 1;

			ExecuteForward(g_fwd_game_started);
		}
	}

	for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid) {
		g_players[pid][pd_respawn_count] 	= 0;
		g_players[pid][pd_round_kills] 		= 0;
	}

	if (task_exists(tid_give_jump_bomb))
		remove_task(tid_give_jump_bomb);
	set_task_ex(0.25, "task_give_jump_bomb", tid_give_jump_bomb);

	ExecuteForward(g_fwd_round_started, _, g_gxp_round);
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

public event_weappickup(pid)
{
	enum { data_wid = 1 };
	if (read_data(data_wid) != CSW_KNIFE)
		emit_sound(pid, CHAN_ITEM, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public logevent_round_start()
{
	g_freeze_time = false;
}

public logevent_round_end()
{
	static bool:first_round = true;
	if (first_round) {
		g_game_starting = true;
		first_round = false;
		set_task_ex(
			1.0, "task_start_countdown",
			tid_game_start_countdown, .flags = SetTask_RepeatTimes, .repeat = 30
		);
	}

	/* We postpone the work of actually ending the round a bit to let some powers
	 * (e.g., explosion on death) execute.
	 * `g_round_ending` is, conversely, used to prevent certain other powers from
	 * executing (such as respawn). */
	g_round_ending = true;
	set_task_ex(0.25, "task_end_round");
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

	ULOG( \
		"gxp_level", INFO, pid, \
		"^"@name^" (@id/%d) prestiged. [PRS: %d] [IP: @ip] [AuthID: @authid]", \
		state_get_player_sid(pid), g_players[pid][pd_prs_stored] + 1 \
	);

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
	if (g_round_ended)
		return;
	new pid = tid - tid_respawn;
	if (is_user_connected(pid) && !is_user_alive(pid) && g_players[pid][pd_team] == tm_zombie) {
		++g_players[pid][pd_respawn_count];
		ExecuteHamB(Ham_CS_RoundRespawn, pid);
	}
}

public task_end_round()
{
	cleanup();

	if (g_game_starting)
		return;

	g_round_ending = false;
	g_round_ended = true;

	new total_players =
		get_playersnum_ex(GetPlayers_ExcludeHLTV | GetPlayers_MatchTeam | GetPlayers_ExcludeBots, "TERRORIST")
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

public task_give_jump_bomb()
{
	new pnum = 0;
	new Array:zombies = ArrayCreate();

	for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid) {
		if (!is_user_connected(pid) || is_user_bot(pid) || is_user_hltv(pid))
			continue;
		if (g_players[pid][pd_team] == tm_zombie && is_user_alive(pid))
			ArrayPushCell(zombies, pid);
		++pnum;
	}

	if (ArraySize(zombies) > 0) {
		for (new i = 0; i != 1 + pnum/10; ++i) {
			new idx = random_num(0, ArraySize(zombies) - 1);
			new pid = ArrayGetCell(zombies, idx);
			jump_bomb_add(pid, 1);
			chat_print(pid, g_prefix, "%L", pid, "GXP_CHAT_RECEIVED_JUMP_BOMB");
			ArrayDeleteItem(zombies, idx);
		}
	}

	ArrayDestroy(zombies);
}

/* Utilities */

handle_user_death(pid, pid_killer, Float:death_dmg)
{
	/* Gather all kill contributors. */

	new Array:contributors = ArrayCreate(GxpKillContributor);

	/* Only consider contributions when the final blow dealt less than the
	 * victims' max. HP. Otherwise, the contributions don't matter, since the
	 * killer would have killed the victim either way. */
	if (death_dmg	< get_max_hp(pid)) {
		new TrieIter:iter = TrieIterCreate(g_players[pid][pd_kill_contributors]);
		new kc[GxpKillContributor];
		for (; TrieIterGetCell(iter, kc[gxp_kc_dmg]); TrieIterNext(iter)) {
			new pid_str[2 + 1];
			TrieIterGetKey(iter, pid_str, charsmax(pid_str));
			kc[gxp_kc_pid] = str_to_num(pid_str);
			ArrayPushArray(contributors, kc);
		}
		TrieIterDestroy(iter);
	}
	TrieClear(g_players[pid][pd_kill_contributors]);

	new bool:hs = get_pdata_int(pid, UXO_LAST_HIT_GROUP, UXO_LINUX_DIFF_MONSTER) == HIT_HEAD;
	ExecuteForward(g_fwd_player_killed, _, pid, pid_killer, hs, contributors);

	ArrayDestroy(contributors);

	/* Award XP, if necessary. */

	if (pid_killer != pid && pid_killer >= 1 && pid_killer <= MAX_PLAYERS) {
		++g_players[pid_killer][pd_round_kills];

		if (GxpXpMethod:get_pcvar_num(g_pcvar_xp_method) == gxp_xp_kill) {
			new class[GxpClass];
			get_class(pid, class);

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

	g_players[pid][pd_round_kills] = 0;

	/* Re-compute internal skills. */

	compute_skill(pid, .renew_actual_skill = false);
	if (pid != pid_killer)
		compute_skill(pid_killer, .renew_actual_skill = false);
}

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

set_xp(pid, xp_new, bool:decrease_lvl = false)
{
	new xp = g_players[pid][pd_xp_curr] = clamp(xp_new, 0, _GXP_MAX_XP);
	new old_lvl = g_players[pid][pd_level];	
	new lvl = 0;

	for (new i = 0; i != _GXP_MAX_LEVEL; ++i) {
		if (xp < _gxp_xp_level_map[i + 1])
			break;
		++lvl;
	}

	if (old_lvl < lvl) {
		g_players[pid][pd_level] = lvl;

		new Float:origin[3];
		pev(pid, pev_origin, origin);

		ufx_te_explosion(origin, g_spr_level_up, 3.0, 15, ufx_explosion_nosound);
		emit_sound(pid, CHAN_ITEM, SOUND_LEVELLED_UP, 1.0, ATTN_NORM, 0, PITCH_NORM);

		ULOG( \
			"gxp_level", INFO, pid, \
			"^"@name^" (@id/%d) reached level %d. [XP: %d] [IP: @ip] [AuthID: @authid]", \
			state_get_player_sid(pid), lvl, xp \
		);

		ExecuteForward(g_fwd_player_levelled_up, _, pid, old_lvl, lvl);
	} else if (old_lvl > lvl) {
		if (!decrease_lvl)
			return;

		g_players[pid][pd_level] = lvl;
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

take_xp(pid, xp, bool:decrease_lvl)
{
	set_xp(pid, g_players[pid][pd_xp_curr] - xp, decrease_lvl);
}

native bool:have_force(pid);
native bool:have_gas(pid);
native bool:have_pipe(pid);

suit_up(pid, bool:bypass_remember_sel = false)
{
	fm_strip_user_weapons(pid);
	fm_give_item(pid, "weapon_knife");

	if (g_players[pid][pd_team] == tm_survivor) {
		fm_give_item(pid, "weapon_flashbang");
		fm_give_item(pid, "weapon_hegrenade");

		new total_players =
			get_playersnum_ex(GetPlayers_ExcludeHLTV | GetPlayers_MatchTeam, "TERRORIST")
			+ get_playersnum_ex(GetPlayers_ExcludeHLTV | GetPlayers_MatchTeam, "CT");
		if (total_players >= 4) {
			fm_give_item(pid, "weapon_flashbang");
			fm_give_item(pid, "weapon_smokegrenade");
		} else {
			if (have_force(pid) || have_gas(pid) || have_pipe(pid))
				fm_give_item(pid, "weapon_smokegrenade");
		}

		if (is_user_bot(pid)) {
			give_gun(pid, random_num(_GXP_SECN_GUN_COUNT, _GXP_GUN_COUNT - 1)); // primary
			give_gun(pid, random_num(0, _GXP_SECN_GUN_COUNT - 1)); 							// secondary
		} else {
			if (bypass_remember_sel || g_players[pid][pd_remember_sel] != gxp_remember_sel_off) {
				if (g_players[pid][pd_level] >= _GXP_SECN_GUN_COUNT)
					give_gun(pid, g_players[pid][pd_primary_gun]);
				give_gun(pid, g_players[pid][pd_secondary_gun]);
			}
		}
	}
}

/* `gun_id` is mapped to player levels, and not internal CS weapon IDs. */
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
}

compute_skill(pid, bool:renew_actual_skill = true)
{
  if (!is_user_connected(pid) || is_user_hltv(pid))
  	return;

  if (is_user_bot(pid)) {
		g_players[pid][pd_skill] = random_float(10.0, 400.0);
		if (renew_actual_skill)
			tb_set_player_skill(pid, g_players[pid][pd_skill]);
		return;
  }

  new kills 				= g_players[pid][pd_stats][gxp_pstats_kills];
  new Float:wkills	= g_players[pid][pd_stats][gxp_pstats_weighted_kills];
  new deaths 				= g_players[pid][pd_stats][gxp_pstats_deaths];
  new hs 						= g_players[pid][pd_stats][gxp_pstats_hs];
  new playtime_ct		= g_players[pid][pd_stats][gxp_pstats_playtime_ct] + 1; // + 1 to avoid div by 0
  new aggro_time		= g_players[pid][pd_stats][gxp_pstats_aggro_time];
  new prs_s 				= g_players[pid][pd_prs_stored];
  new prs_u 				= g_players[pid][pd_prs_used];
  new prs_b 				= g_players[pid][pd_prs_bought];

  if (kills == 0 || deaths == 0) {
  	g_players[pid][pd_skill] = g_skill_base + float(kills);
  	if (renew_actual_skill)
  		tb_set_player_skill(pid, float(kills));
  	return;
	}

  new Float:skill =
  	/* [TIME/ABILITY] Helps to differentiate new players from established ones. */
  	floatclamp(0.005*(kills + hs), 0.0, 30.0) +
  	/* [TIME/ABILITY] Helps to differentiate safe players from aggressive ones. */
  	0.375*aggro_time/playtime_ct*100 +
  	/* [ABILITY] Estimates players ability. */
  	0.425*wkills/deaths*100 +
  	/* [ABILITY] Further narrows it down. */
  	0.2*hs/kills*100 +
  	/* [STRENGTH/ABILITY] Accounts for prestige influence on gameplay. */
  	0.4*prs_u +
  	/* [STRENGTH/ABILITY] Accentuates the skill component of earned prestiges. */
  	0.1*(prs_u - prs_b);

  if (renew_actual_skill)
	  tb_set_player_skill(pid, skill);

  /* We maintain an internal skill rating (SR) that doesn't affect balancing in
   * order to accomodate dynamic weighted parameter computations. If the actual
   * skill rating would be constantly updated, it would introduce instabilities,
   * where new players would sometimes gain upwards of 200-300 SR, and
   * consequently distort the balance. */
  g_players[pid][pd_skill] = g_skill_base + skill;
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
  g_players[pid][pd_secn_ability_last_used]	= 0.0;
  g_players[pid][pd_ability_last_used]	= 0.0;
  g_players[pid][pd_ability_in_use] 		= false;
  g_players[pid][pd_respawn_count]			= 0;
  g_players[pid][pd_round_kills]				= 0;
  g_players[pid][pd_kill_contributors]	= TrieCreate();
  g_players[pid][pd_skill]							= g_skill_base;

  if (is_user_bot(pid)) {
  	for (new i = 0; i != GxpPower; ++i)
  		g_players[pid][pd_powers][i] = random_num(1, 5);
	} else {
	  arrayset(g_players[pid][pd_powers], 0, _:GxpPower);
	}
  for (new i = 0; i != GxpUlClass; ++i)
  	g_players[pid][pd_uls][i] = ArrayCreate();
  arrayset(g_players[pid][pd_stats], 0, _:GxpPlayerStats);

  g_player_loaded[pid] = false;
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
    /* POWER:BASE HP */
		new base_hp_lvl = g_players[pid][pd_powers][pwr_base_hp];
		new hp = class[cls_health] + gxp_power_get_delta(GxpPower:pwr_base_hp)*base_hp_lvl;
		if (get_user_flags(pid) & _gxp_access_map[gxp_priv_vip])
			hp += 20;
		return hp;
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
#define NEWBIE_MAX_PRS 2
	return g_players[pid][pd_prs_stored] + g_players[pid][pd_prs_used] <= NEWBIE_MAX_PRS;
}

cleanup()
{
	ExecuteForward(g_fwd_cleanup);

	for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid) {
		if (!is_user_connected(pid) || g_players[pid][pd_team] == tm_unclassified)
			continue;
		ExecuteForward(g_fwd_player_cleanup, _, pid);
		TrieClear(g_players[pid][pd_kill_contributors]);
		g_players[pid][pd_ability_in_use] = false;
	}
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
	if (pid < 1 || pid > MAX_PLAYERS)
		return -1;

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
	return g_players[get_param(param_pid)][pd_stats][get_param(param_stat)];
}

public native_set_player_stat(plugin, argc)
{
	enum {
		param_pid		= 1,
		param_stat	= 2,
		param_value	= 3
	};
	g_players[get_param(param_pid)][pd_stats][get_param(param_stat)] =
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
		param_pid 			= 1,
		param_xp				= 2,
		param_bonus_xp 	= 3,
		param_desc 			= 4
	};
	new desc[64 + 1];
	get_string(param_desc, desc, charsmax(desc));
	give_xp(get_param(param_pid), get_param(param_xp), get_param(param_bonus_xp), desc);
}

public native_take_xp(plugin, argc)
{
	enum {
		param_pid 					= 1,
		param_xp						= 2,
		param_decrease_lvl	= 3
	};
	take_xp(get_param(param_pid), get_param(param_xp), bool:get_param(param_decrease_lvl));
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

public bool:native_is_freevip(plugin, argc)
{
	enum { param_pid = 1 };
	return bool:(get_user_flags(get_param(param_pid)) & _gxp_access_map[gxp_priv_freevip]);
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
	VALIDATE_PID(false);
	return g_players[pid][pd_team] == tm_zombie;
}

public native_bc_get_user_level(plugin, argc)
{
	enum { param_pid = 1 };
	VALIDATE_PID(0);
	return g_players[pid][pd_level];
}

public native_bc_get_user_xp(plugin, argc)
{
	enum { param_pid = 1 };
	VALIDATE_PID(0);
	return g_players[pid][pd_xp_curr];
}

public native_bc_set_user_xp(plugin, argc)
{
	enum {
		param_pid = 1,
		param_xp 	= 2
	};
	VALIDATE_PID();
	set_xp(get_param(param_pid), get_param(param_xp));
}
