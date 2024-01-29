/*
 * TODO:
 *   - fix up `chat_print` so that it would work with multilingual global
 *     messages.
 */

#include <amxmodx>
#include <amxmisc>

#include <gunxp_swarm>
#include <gunxp_swarm_uls>
#include <gunxp_swarm_powers>
#include <gunxp_swarm_const>

#include <utils_text>

new const g_clcmds[][][32 + 1] = 
{
  { "round",    "handle_say_round" },
  { "raundas",  "handle_say_round" },
  { "roundas",  "handle_say_round" },
  { "/round",   "handle_say_round" },
  { "/raundas", "handle_say_round" },
  { "/roundas", "handle_say_round" }
};

new g_prefix[_GXP_MAX_PREFIX_LENGTH + 1];

new g_remind_prs_every_n_spawn;

new g_round;
new g_rounds_per_team;

new g_bonus_hp_per_respawn;
new g_max_respawns_for_bonus_hp;
new g_max_newbie_respawns_for_bonus_hp;

new g_survivor_num;
new g_survivor_xp;

new g_spawns[MAX_PLAYERS + 1];

public plugin_init()
{
  register_plugin(_GXP_SWARM_INFO_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);
  register_dictionary(_GXP_SWARM_DICTIONARY);

  /* CVars */

  new pcvar_prefix = register_cvar("gxp_info_prefix", "^3[GXP:S]^1 ");
  bind_pcvar_string(pcvar_prefix, g_prefix, charsmax(g_prefix));
  hook_cvar_change(pcvar_prefix, "hook_prefix_change");

  bind_pcvar_num(
    register_cvar("gxp_info_remind_prs_every_n_spawn", "3"), g_remind_prs_every_n_spawn
  );

  /* Client commands */

  register_clcmd("say", "clcmd_say");
  register_clcmd("say_team", "clcmd_say");
}

public plugin_cfg()
{
  fix_colors(g_prefix, charsmax(g_prefix));

  /* Core CVars */

  bind_pcvar_num(get_cvar_pointer("gxp_rounds_per_team"), g_rounds_per_team);

  bind_pcvar_num(get_cvar_pointer("gxp_bonus_hp_per_respawn"), g_bonus_hp_per_respawn);
  bind_pcvar_num(get_cvar_pointer("gxp_max_respawns_for_bonus_hp"), g_max_respawns_for_bonus_hp);
  bind_pcvar_num(
    get_cvar_pointer("gxp_max_newbie_respawns_for_bonus_hp"), g_max_newbie_respawns_for_bonus_hp
  );
}

/* Hooks */

public hook_prefix_change(pcvar, const old_val[], const new_val[])
{
  fix_colors(g_prefix, charsmax(g_prefix));
}

/* Forwards > Core */

public gxp_round_started(round)
{
  g_round = round;
  g_survivor_num = 0;
}

public gxp_round_ended(round)
{
  if (!gxp_has_game_started())
    return;

  if (g_survivor_num > 0) {
    for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid) {
      if (is_user_connected(pid) && !is_user_bot(pid))
        chat_print(pid, g_prefix, "%L", pid, "GXP_CHAT_N_SURVIVED", g_survivor_num, g_survivor_xp);
    }
  }

  for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid)
    g_spawns[pid] = 0;

  if (round == g_rounds_per_team)
    return;

  for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid) {
    if (is_user_connected(pid) && !is_user_bot(pid))
      chat_print(pid, g_prefix, "%L", pid, "GXP_CHAT_ROUND_ENDED", g_rounds_per_team - round);
  }
}

public gxp_teams_swapped()
{
  for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid) {
    if (is_user_connected(pid) && !is_user_bot(pid))
      chat_print(pid, g_prefix, "%L", pid, "GXP_CHAT_TEAMS_SWAPPED");
  }
}

public gxp_player_spawned(pid)
{
  static spawn_count[MAX_PLAYERS + 1];
  if (++spawn_count[pid] % g_remind_prs_every_n_spawn == 0) {
    if (gxp_get_player_data(pid, pd_xp_curr) == _GXP_MAX_XP)
      chat_print(pid, g_prefix, "%L", pid, "GXP_CHAT_PRS_NOTICE");
  }

  new GxpTeam:team = GxpTeam:gxp_get_player_data(pid, pd_team);
  if (team == tm_survivor) {
    if (GxpRememberSelection:gxp_get_player_data(pid, pd_remember_sel) == gxp_remember_sel_off)
      return;
    chat_print(pid, g_prefix, "%L", pid, "GXP_CHAT_REMINDER_REMEMBER_SEL");
  } else if (team == tm_zombie) {
    if (!gxp_has_game_started())
      return;

    new respawns = gxp_get_player_data(pid, pd_respawn_count);
    if (respawns > 0) {
      new max_respawns = gxp_is_newbie(pid)
        ? g_max_newbie_respawns_for_bonus_hp
        : g_max_respawns_for_bonus_hp;
      if (respawns > max_respawns)
        return;

      new bonus_hp = g_bonus_hp_per_respawn*clamp(respawns, 0, max_respawns);
      chat_print(pid, g_prefix, "%L", pid, "GXP_CHAT_RESPAWN_BONUS_HP", bonus_hp, respawns);
    }
  }
}

public gxp_player_gained_xp(pid, xp, bonus_xp, const desc[])
{
  if (gxp_get_player_data(pid, pd_xp_curr) == _GXP_MAX_XP)
    chat_print(pid, g_prefix, "%L", pid, "GXP_CHAT_PRS_NOTICE");
}

public gxp_player_levelled_up(pid, prev_lvl, new_lvl)
{
  new lvl_diff = new_lvl - prev_lvl;
  new name[MAX_NAME_LENGTH + 1];
  get_user_name(pid, name, charsmax(name));

  if (lvl_diff > 1) {
    for (new pid_n = 1; pid_n != MAX_PLAYERS + 1; ++pid_n) {
      chat_print(
        pid_n, g_prefix, "%L", pid_n, "GXP_CHAT_ASCENDED_N_LEVELS_TO_N", name, lvl_diff, new_lvl
      );
    }
  } else {
    for (new pid_n = 1; pid_n != MAX_PLAYERS + 1; ++pid_n)
      chat_print(pid_n, g_prefix, "%L", pid_n, "GXP_CHAT_REACHED_LEVEL_N", name, new_lvl);
  }
}

public gxp_player_attempted_prs(pid, bool:successful)
{
  if (!successful) {
    chat_print(
      pid, g_prefix,
      "%L", pid, "GXP_CHAT_PRS_NOT_ENOUGH_XP", gxp_get_player_data(pid, pd_xp_curr), _GXP_MAX_XP
    );
  } else {
    chat_print(pid, g_prefix, "%L", pid, "GXP_CHAT_PRS", gxp_get_player_data(pid, pd_prs_stored));
  }
}

public gxp_player_survived(pid, xp_gained)
{
  ++g_survivor_num;
  g_survivor_xp = xp_gained;
  chat_print(pid, g_prefix, "%L", pid, "GXP_CHAT_YOU_SURVIVED", xp_gained);
}

/* Forwards > ULs */

public gxp_ul_activated(pid, ul_id, bool:automatic)
{
  if (!automatic) {
    new ul[GxpUl];
    gxp_ul_get_by_id(ul_id, ul);
    chat_print(pid, g_prefix, "%L", pid, "GXP_CHAT_UL_ACTIVATED", ul[gxp_ul_title]);
    chat_print(pid, g_prefix, "%L", pid, "GXP_CHAT_UL_ACTIVATED_DESC", ul[gxp_ul_description]);
  }
}

/* Client commands */

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

public handle_say_round(pid)
{
  if (!gxp_has_game_started()) {
    chat_print(pid, g_prefix, "%L", pid, "GXP_CHAT_GAME_NOT_STARTED");
  } else {
    chat_print(
      pid, g_prefix, "%L", pid, "GXP_CHAT_CURRENT_ROUND", g_round, g_rounds_per_team - g_round
    );
  }
}
