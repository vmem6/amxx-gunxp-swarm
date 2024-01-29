#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <xs>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

#include <utils_effects>
#include <utils_bits>

new g_charging;

new g_charge_speed;
new g_charge_cruise_speed;
new g_charge_dmg;
new Float:g_charge_duration;
new g_smash_min_req_speed;
new Float:g_smash_timeout;
new Float:g_smash_vel[3];

new g_id;
new g_props[GxpClass];

new g_spr_white;

new g_chargers;

public plugin_precache()
{
  g_spr_white = engfunc(EngFunc_PrecacheModel, "sprites/white.spr");
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_CHARGER_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards > FakeMeta */

  register_forward(FM_Touch, "fm_touch_post", ._post = 1);

  /* Forwards > Ham */

  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);

  /* Setup */

  gxp_config_get_class("charger", g_props);

  TrieGetCell(g_props[cls_misc], "charge_speed", g_charge_speed);
  TrieGetCell(g_props[cls_misc], "charge_cruise_speed", g_charge_cruise_speed);
  TrieGetCell(g_props[cls_misc], "charge_damage", g_charge_dmg);
  TrieGetCell(g_props[cls_misc], "charge_duration", g_charge_duration);
  TrieGetCell(g_props[cls_misc], "smash_min_req_speed", g_smash_min_req_speed);
  TrieGetCell(g_props[cls_misc], "smash_timeout", g_smash_timeout);
  TrieGetCell(g_props[cls_misc], "smash_vel_x", g_smash_vel[0]);
  TrieGetCell(g_props[cls_misc], "smash_vel_y", g_smash_vel[1]);
  TrieGetCell(g_props[cls_misc], "smash_vel_z", g_smash_vel[2]);

  g_id = gxp_register_class("charger", tm_zombie);
}

/* Forwards > GunXP > Player */

public gxp_player_cleanup(pid)
{
  if (_gxp_is_player_of_class(pid, g_id, g_props)) {
    stop_charge(pid);
    --g_chargers;
  }
}

public gxp_player_spawned(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  UBITS_PUNSET(g_charging, pid);

  set_pev(pid, pev_gravity, g_props[cls_gravity]);
  gxp_user_set_model(pid, g_props);

  ++g_chargers;
}

public gxp_player_used_ability(pid)
{
  if (g_chargers == 0 || !_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  new Float:time = get_gametime();
  if (time - Float:gxp_get_player_data(pid, pd_ability_last_used) < g_props[cls_ability_cooldown])
    return;

  UBITS_SET(g_charging, pid);

  /* Propel player, and ... */
  new Float:vel[3];
  new Float:org_vel[3];
  pev(pid, pev_velocity, org_vel);
  velocity_by_aim(pid, g_charge_speed, vel);
  vel[2] = org_vel[2];
  set_pev(pid, pev_velocity, vel);

  ufx_te_beamfollow(pid, g_spr_white, 0.3, 2.0, {255, 0, 0}, 220);
  ufx_screenfade(pid, 0.0, 0.0, ufx_ffade_stayout, {255, 0, 0, 150});

  new data[1]; data[0] = pid;
  set_task_ex(g_charge_duration, "task_stop_charge", .parameter = data, .len = sizeof(data));
  gxp_emit_sound(pid, "ability", g_id, g_props);

  /* ... afterwards, cap maxspeed to cruise speed. */
  set_pev(pid, pev_maxspeed, float(g_charge_cruise_speed));

  gxp_set_player_data(pid, pd_ability_last_used, time);
}

public gxp_player_knife_slashed(pid)  { gxp_emit_sound(pid, "miss", g_id, g_props, CHAN_WEAPON); }
public gxp_player_knife_hitwall(pid)  { gxp_emit_sound(pid, "miss", g_id, g_props, CHAN_WEAPON); }
public gxp_player_knife_hit(pid)      { gxp_emit_sound(pid, "hit",  g_id, g_props, CHAN_WEAPON); }
public gxp_player_knife_stabbed(pid)  { gxp_emit_sound(pid, "hit",  g_id, g_props, CHAN_WEAPON); }

public gxp_player_suffer(pid) { gxp_emit_sound(pid, "pain",  g_id, g_props, CHAN_VOICE); }
public gxp_player_died(pid)   { gxp_emit_sound(pid, "death", g_id, g_props, CHAN_VOICE); }

/* Forwards > FakeMeta */

public fm_touch_post(ent, pid)
{
  if (g_chargers == 0 || !gxp_has_game_started() || gxp_has_round_ended())
    return;

  if (!pev_valid(ent) || !pev_valid(pid))
    return;

  new classname[31 + 1];

  pev(ent, pev_classname, classname, charsmax(classname));
  if (!equal(classname, "player") || GxpTeam:gxp_get_player_data(ent, pd_team) == tm_zombie)
    return;

  pev(pid, pev_classname, classname, charsmax(classname));
  if (!equal(classname, "player") || !_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  static Float:times[MAX_PLAYERS + 1];
  new Float:time = get_gametime();

  if (times[ent] - time > 0)
    return;

  new Float:vel[3];
  pev(pid, pev_velocity, vel);
  if (xs_vec_len(vel) < float(g_smash_min_req_speed))
    return;

  /* Punch player back in the direction opposite to Charger. */
  new Float:charger_origin[3];
  new Float:survivor_origin[3];
  pev(pid, pev_origin, charger_origin);
  pev(ent, pev_origin, survivor_origin);

  vel[0] = survivor_origin[0] - charger_origin[0];
  vel[1] = survivor_origin[1] - charger_origin[1];
  vel[2] = 0.4;
  xs_vec_normalize(vel, survivor_origin);
  vel[0] *= g_smash_vel[0];
  vel[1] *= g_smash_vel[1];
  vel[2] *= g_smash_vel[2];
  set_pev(ent, pev_velocity, vel);

  ufx_damage(ent, charger_origin);
  /* TODO: test this. */
  ufx_screenshake(ent, 5.0, 1.0, 2.0);

  new Float:punchangle[3];
  punchangle[0] = random_float(25.0, 50.0);
  punchangle[1] = random_float(25.0, 50.0);
  punchangle[2] = 10.0;
  set_pev(ent, pev_punchangle, punchangle);

  ExecuteHamB(Ham_TakeDamage, ent, 0, pid, g_charge_dmg, DMG_BULLET);

  gxp_emit_sound(pid, "smash", g_id, g_props);

  times[ent] = time + g_smash_timeout;
}

/* Forwards > Ham */

public ham_item_preframe_post(pid)
{
  if (!is_user_alive(pid) || !_gxp_is_player_of_class(pid, g_id, g_props))
    return HAM_IGNORED;
  set_pev(
    pid,
    pev_maxspeed,
    float(UBITS_PCHECK(g_charging, pid) ? g_charge_cruise_speed : g_props[cls_speed])
  );
  return HAM_SUPERCEDE;
}

/* Miscellaneous */

public task_stop_charge(const data[1], tid)
{
  stop_charge(data[0]);
}

/* Helpers */

public stop_charge(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  ufx_screenfade(pid, 1.0, 0.0, ufx_ffade_in, {180, 0, 0, 200});

  UBITS_UNSET(g_charging, pid);
  set_pev(pid, pev_maxspeed, float(g_props[cls_speed]));
}
