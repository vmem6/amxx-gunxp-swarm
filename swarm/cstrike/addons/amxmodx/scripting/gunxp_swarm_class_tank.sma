#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <fakemeta_util>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_ui>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

#include <utils_effects>
#include <utils_fakemeta>

#define ROCK_CLASSNAME "gxp_tank_rock"

new bool:g_exists;
new Float:g_time_of_last;

new bool:g_cleaned_up;
new bool:g_init_spawn_handled;

new g_hp_min;
new g_hp_max;
new g_hp_per_survivor;
new Float:g_rock_dmg;
new g_rock_speed;

new g_id;
new g_props[GxpClass];

new g_spr_white;
new g_mdl_rockgibs;
new g_mdl_rock[GXP_SWARM_CONFIG_MAX_PROP_LENGTH + 1];

public plugin_precache()
{
  g_spr_white = engfunc(EngFunc_PrecacheModel, "sprites/white.spr");
  g_mdl_rockgibs = engfunc(EngFunc_PrecacheModel, "models/rockgibs.mdl")
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_TANK_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards > FakeMeta */

  register_forward(FM_PlayerPreThink, "fm_playerprethink_pre");
  register_forward(FM_Touch, "fm_touch_post", ._post = 1);

  /* Forwards > Ham */

  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);

  /* Setup */

  g_time_of_last = get_gametime() - 91.0;

  gxp_config_get_class("tank", g_props);

  TrieGetCell(g_props[cls_misc], "health_minimum", g_hp_min);
  TrieGetCell(g_props[cls_misc], "health_maximum", g_hp_max);
  TrieGetCell(g_props[cls_misc], "health_per_survivor", g_hp_per_survivor);
  TrieGetCell(g_props[cls_misc], "rock_damage", g_rock_dmg);
  TrieGetCell(g_props[cls_misc], "rock_speed", g_rock_speed);

  g_id = gxp_register_class("tank", tm_zombie, "cb_gxp_is_available", "cb_gxp_is_required");

  copy(g_mdl_rock, charsmax(g_mdl_rock), "models/");
  TrieGetString(
    g_props[cls_models], "rock",
    g_mdl_rock[strlen(g_mdl_rock)], charsmax(g_mdl_rock) + strlen(g_mdl_rock)
  );
}

/* Forwards > GunXP > Player */

public gxp_cleanup()
{
  g_exists = false;
  g_time_of_last = get_gametime() - 91.0;

  g_cleaned_up = true;

  ufm_remove_entities(ROCK_CLASSNAME);
}

public gxp_round_started(round)
{
  g_init_spawn_handled = false;
}

public gxp_player_cleanup(pid)
{
  if (_gxp_is_player_of_class(pid, g_id, g_props) && !g_cleaned_up) {
    g_exists = false;
    g_time_of_last = get_gametime();
  }
}

public gxp_player_spawned(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  g_exists = true;
  g_cleaned_up = false;

  new alive_ct = get_playersnum_ex(GetPlayers_ExcludeDead | GetPlayers_MatchTeam, "CT");
  g_props[cls_health] = clamp(alive_ct*g_hp_per_survivor, g_hp_min, g_hp_max);
  gxp_config_set_class("tank", g_props);

  set_pev(pid, pev_health, float(g_props[cls_health]));
  set_pev(pid, pev_gravity, g_props[cls_gravity]);

  client_cmd(0, "spk vox/danger");

  new name[MAX_NAME_LENGTH + 1];
  get_user_name(pid, name, charsmax(name));

  for (new pid_r = 1; pid_r != MAX_PLAYERS + 1; ++pid_r) {
    if (is_user_bot(pid_r) || !is_user_connected(pid_r))
      continue;

    new colors[3];
    gxp_ui_get_colors(pid_r, colors);
    set_dhudmessage(colors[0], colors[1], colors[2], -1.0, 0.2, 0, 0.75, 10.0, 0.75, 0.75);
    show_dhudmessage(pid_r, "%L", pid_r, "GXP_HUD_MORPHED_INTO_TANK", name);
  }

  gxp_user_set_model(pid, g_props);
}

public gxp_player_used_ability(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  new Float:time = get_gametime();
  if (time - Float:gxp_get_player_data(pid, pd_ability_last_used) < g_props[cls_ability_cooldown])
    return;

  new Float:origin[3];
  new Float:vel[3];
  new Float:angle[3];

  pev(pid, pev_origin, origin);
  pev(pid, pev_v_angle, angle);

  new rock = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
  set_pev(rock, pev_classname, ROCK_CLASSNAME);
  engfunc(EngFunc_SetModel, rock, g_mdl_rock);
  engfunc(EngFunc_SetSize, rock, Float:{-3.5, -3.5, -3.5}, Float:{3.5, 3.5, 3.5});
  set_pev(rock, pev_origin, origin);
  set_pev(rock, pev_angles, angle);
  set_pev(rock, pev_solid, SOLID_TRIGGER);
  set_pev(rock, pev_movetype, MOVETYPE_TOSS);
  set_pev(rock, pev_gravity, 0.5);
  set_pev(rock, pev_scale, 4.0);
  set_pev(rock, pev_owner, pid);
  velocity_by_aim(pid, g_rock_speed, vel);
  set_pev(rock, pev_velocity, vel);

  ufx_te_beamfollow(rock, g_spr_white, 1.0, 1.0, {255, 0, 0}, 200);

  gxp_emit_sound(pid, "ability", g_id, g_props);

  gxp_set_player_data(pid, pd_ability_last_used, time);
}

public gxp_player_knife_slashed(pid)  { gxp_emit_sound(pid, "miss", g_id, g_props, CHAN_WEAPON); }
public gxp_player_knife_hitwall(pid)  { gxp_emit_sound(pid, "miss", g_id, g_props, CHAN_WEAPON); }
public gxp_player_knife_hit(pid)      { gxp_emit_sound(pid, "hit",  g_id, g_props, CHAN_WEAPON); }
public gxp_player_knife_stabbed(pid)  { gxp_emit_sound(pid, "hit",  g_id, g_props, CHAN_WEAPON); }

public gxp_player_suffer(pid) { gxp_emit_sound(pid, "pain",  g_id, g_props, CHAN_VOICE); }
public gxp_player_died(pid)   { gxp_emit_sound(pid, "death", g_id, g_props, CHAN_VOICE); }

/* Forwards > FakeMeta */

public fm_playerprethink_pre(pid)
{
  if (!is_user_alive(pid) || !_gxp_is_player_of_class(pid, g_id, g_props))
    return FMRES_IGNORED;

  /* Indefinitely defer actual footsteps.  */
  set_pev(pid, pev_flTimeStepSound, 999);

  static time_step_sound[MAX_PLAYERS + 1];
  new buttons = pev(pid, pev_button);
  if ((pev(pid, pev_flags) & FL_ONGROUND) && fm_get_speed(pid) > 0 && !(buttons & IN_DUCK)) {
    if (time_step_sound[pid] > 0) {
      --time_step_sound[pid];
    } else {
      gxp_emit_sound(pid, "step", g_id, g_props);
      time_step_sound[pid] = 150;
    }
  }

  return FMRES_IGNORED;
}

public fm_touch_post(ent, pid)
{
  static classname[31 + 1];

  if (!pev_valid(ent) || !pev_valid(pid))
    return;

  pev(ent, pev_classname, classname, charsmax(classname));
  if (!equal(classname, ROCK_CLASSNAME))
    return;

  /* TODO: used for breaking glass, etc? */
  if (equal(classname, "func_breakable") && pev(ent, pev_solid) != SOLID_NOT) {
    pev(pid, pev_classname, classname, charsmax(classname));
    if (equal(classname, ROCK_CLASSNAME)) {
      dllfunc(DLLFunc_Use, ent, pid);
      return;
    }
  }

  if (pid < 1 || pid > MAX_PLAYERS)
    return;

  if (GxpTeam:gxp_get_player_data(pid, pd_team) == tm_zombie || !is_user_alive(pid))
    return;

  static origin[3];
  get_user_origin(pid, origin);

  static velocity[3];
  velocity[0] = random_num(-50, 50);
  velocity[1] = random_num(-50, 50);
  velocity[2] = 25;

  ufx_screenshake(pid, 8.0, 1.0, 8.0);
  ufx_te_break_model(
    origin, {16, 16, 16}, velocity, 1, g_mdl_rockgibs, 10, 3.8, ufx_break_model_metal
  );

  ExecuteHamB(Ham_TakeDamage, pid, 0, pev(ent, pev_owner), g_rock_dmg, DMG_BULLET);

  gxp_emit_sound(pid, "hit", g_id, g_props);

  ufm_remove_entity(ent);
}

/* Forwards > Ham */

public ham_item_preframe_post(pid)
{
  if (is_user_alive(pid) && _gxp_is_player_of_class(pid, g_id, g_props)) {
    set_pev(pid, pev_maxspeed, float(g_props[cls_speed]));
    return HAM_SUPERCEDE;
  }
  return HAM_IGNORED;
}

/* Callbacks */

public cb_gxp_is_available(pid, &bool:available)
{
  /* `cb_gxp_is_required` takes precedence. */
  available = false;
}

public cb_gxp_is_required(pid, &bool:required)
{
  if (!gxp_has_game_started() || gxp_has_round_ended()) {
    required = false;
    return;
  }

  if (g_exists || get_playersnum_ex(GetPlayers_ExcludeHLTV) < 12) {
    required = false;
  /* Try to pick a random TT on new round. */
  } else if (!g_init_spawn_handled) {
    new last_tt_pid = 0;
    new tt_num = 0;

    for (new pid_r = 1; pid_r != MAX_PLAYERS + 1; ++pid_r) {
      if (is_user_connected(pid_r) && cs_get_user_team(pid_r) == CS_TEAM_T) {
        last_tt_pid = pid_r;
        ++tt_num;
      }
    }

    if (random_num(1, 100) <= clamp(100/tt_num, 10, 100) || last_tt_pid == pid) {
      required = true;
      g_init_spawn_handled = true;
    }
  } else if (get_gametime() - g_time_of_last > 90.0) {
    required = true;
  }
}