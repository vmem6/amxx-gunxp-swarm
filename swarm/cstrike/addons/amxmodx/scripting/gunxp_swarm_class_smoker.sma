#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <xs>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

#include <utils_effects>

enum
{
  tid_fish = 7834
};

new g_id;
new g_props[GxpClass];

new g_spr_white;

public plugin_precache()
{
  g_spr_white = engfunc(EngFunc_PrecacheModel, "sprites/white.spr");
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_SMOKER_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards > FakeMeta */

  register_forward(FM_PlayerPreThink, "fm_playerprethink_post", ._post = 1);

  /* Forwards > Ham */

  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);

  /* Setup */

  gxp_config_get_class("smoker", g_props);

  g_id = gxp_register_class("smoker", tm_zombie);
}

/* Forwards > GunXP > Player */

public gxp_cleanup()
{
  for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid)
    remove_task(tid_fish + pid);
}

public gxp_player_spawned(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  set_pev(pid, pev_gravity, g_props[cls_gravity]);

  gxp_user_set_model(pid, g_props);
}

public gxp_player_cleanup(pid)
{
  if (_gxp_is_player_of_class(pid, g_id, g_props))
    remove_task(tid_fish + pid);
}

public gxp_player_used_ability(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  if (task_exists(tid_fish + pid)) {
    remove_task(tid_fish + pid);
    return;
  }

  new Float:time = get_gametime();
  if (time - Float:gxp_get_player_data(pid, pd_ability_last_used) < g_props[cls_ability_cooldown])
    return;

  new target;
  get_user_aiming(pid, target);
  if (
    target >= 1 && target <= MAX_PLAYERS
    && GxpTeam:gxp_get_player_data(target, pd_team) == tm_survivor
  ) {
    new data[1]; data[0] = target;
    set_task_ex(0.1, "task_fish", tid_fish + pid, data, sizeof(data), SetTask_Repeat);
  } else {
    new aim_pos[3];
    get_user_origin(pid, aim_pos, 3);
    ufx_te_beamentpoint(pid, aim_pos, g_spr_white, 0, 0, 1, 6, 1, {155, 155, 0}, 40, 0);
  }

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

public fm_playerprethink_post(pid)
{
  if (_gxp_is_player_of_class(pid, g_id, g_props) && task_exists(tid_fish + pid)) {
    static Float:vel[3];
    pev(pid, pev_velocity, vel);
    vel[0] = 0.0;
    vel[1] = 0.0;
    set_pev(pid, pev_velocity, vel);
  }
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

/* Tasks */

public task_fish(const data[1], tid)
{
  new pid_smoker = tid - tid_fish;
  new pid_survivor = data[0];

  if (!is_user_alive(pid_survivor)) {
    remove_task(tid);
    return;
  }

  static smoker_origin[3];
  static survivor_origin[3];

  get_user_origin(pid_smoker, smoker_origin, 1);
  get_user_origin(pid_survivor, survivor_origin);

  new dist = get_distance(smoker_origin, survivor_origin);

  static Float:vel[3];
  pev(pid_survivor, pev_velocity, vel);

  if (dist > 4) {
    new Float:time = dist / 300.0;
    vel[0] = (smoker_origin[0] - survivor_origin[0]) / time;
    vel[1] = (smoker_origin[1] - survivor_origin[1]) / time;
  } else {
    vel[0] = 0.0;
    vel[1] = 0.0;
  }

  set_pev(pid_survivor, pev_velocity, vel);

  ufx_te_beaments(
    pid_smoker, pid_survivor, g_spr_white, 0, 0.0, 0.1, 0.8, 0.1, {155, 155, 55}, 90, 10.0
  );
}