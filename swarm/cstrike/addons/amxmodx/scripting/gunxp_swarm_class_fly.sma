#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

#include <utils_animation>
#include <utils_effects>
#include <utils_bits>

#define FLIGHT_SOUND_INTERVAL 0.7 // in seconds

/* In seconds */
#define ANIM_DURATION_PREPARE   0.3
#define ANIM_DURATION_LIFTOFF   0.6
#define ANIM_DURATION_FALL      0.3
#define ANIM_DURATION_CRUISE    10.0
#define ANIM_DURATION_LAND      0.2

#define ANIM_FRAME_RATE_PREPARE   1.0
#define ANIM_FRAME_RATE_LIFTOFF   1.0
#define ANIM_FRAME_RATE_FALL      1.0
#define ANIM_FRAME_RATE_CRUISE    1.5
#define ANIM_FRAME_RATE_LAND      1.0

enum
{
  anim_seq_prepare = 143,
  anim_seq_liftoff,
  anim_seq_fall,
  anim_seq_cruise,
  anim_seq_land = 148
};

enum
{
  tid_liftoff = 5673,
  tid_cruise  = 9714,
  tid_fall    = 4538,
  tid_screech = 9831
};

new g_in_flight;
new g_in_descent;

new g_id;

new Float:g_flight_liftoff_z_speed;
new g_flight_cruise_speed;
new Float:g_fligt_flap_z_speed;
new g_flight_descent_speed;
new Float:g_flight_descent_z_speed;
new Float:g_flight_duration;
new Float:g_flight_descent_duration;

new g_props[GxpClass];

public plugin_init()
{
  register_plugin(_GXP_SWARM_FLY_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards > FakeMeta */

  register_forward(FM_PlayerPreThink, "fm_playerprethink_post", ._post = 1);

  /* Forwards > Ham */

  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);

  /* Setup */

  gxp_config_get_class("fly", g_props);

  TrieGetCell(g_props[cls_misc], "flight_liftoff_z_speed", g_flight_liftoff_z_speed);
  TrieGetCell(g_props[cls_misc], "flight_cruise_speed", g_flight_cruise_speed);
  TrieGetCell(g_props[cls_misc], "flight_flap_z_speed", g_fligt_flap_z_speed);
  TrieGetCell(g_props[cls_misc], "flight_descent_speed", g_flight_descent_speed);
  TrieGetCell(g_props[cls_misc], "flight_descent_z_speed", g_flight_descent_z_speed);
  TrieGetCell(g_props[cls_misc], "flight_duration", g_flight_duration);
  TrieGetCell(g_props[cls_misc], "flight_descent_duration", g_flight_descent_duration);

  g_id = gxp_register_class("fly", tm_zombie);
}

/* Forwards > GunXP > Player */

public gxp_player_spawned(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;
  set_pev(pid, pev_gravity, g_props[cls_gravity]);
  gxp_user_set_model(pid, g_props);
}

public gxp_player_cleanup(pid)
{
  if (_gxp_is_player_of_class(pid, g_id, g_props)) {
    rest(pid);

    remove_task(tid_liftoff + pid);
    remove_task(tid_cruise + pid);
    remove_task(tid_fall + pid);
    remove_task(tid_screech + pid);
  }
}

public gxp_player_used_ability(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  if (UBITS_PCHECK(g_in_flight, pid)) {
    if (!UBITS_PCHECK(g_in_descent, pid)) {
      UBITS_PSET(g_in_descent, pid);

      gxp_emit_sound(pid, "abilitydescend", g_id, g_props);

      remove_task(tid_fall + pid);
      remove_task(tid_screech + pid);
    }
  } else if (!task_exists(tid_liftoff + pid) && !task_exists(tid_screech + pid)) {
    new Float:time = get_gametime();
    if (time - Float:gxp_get_player_data(pid, pd_ability_last_used) < g_props[cls_ability_cooldown])
      return;

    uanim_play(pid, ANIM_DURATION_PREPARE, ANIM_FRAME_RATE_PREPARE, anim_seq_prepare);
    set_task_ex(ANIM_DURATION_PREPARE, "task_liftoff", tid_liftoff + pid);

    gxp_set_player_data(pid, pd_ability_in_use, true);
  }
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
  if (!is_user_alive(pid) || !_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  if (!UBITS_PCHECK(g_in_flight, pid))
    return;

  new Float:vel[3];
  if (!UBITS_PCHECK(g_in_descent, pid)) {
    velocity_by_aim(pid, g_flight_cruise_speed, vel);
    vel[2] = (pev(pid, pev_button) & IN_JUMP) ? g_fligt_flap_z_speed : 0.0;
  } else {
    if (pev(pid, pev_flags) & FL_ONGROUND) {
      uanim_play(pid, ANIM_DURATION_LAND, ANIM_FRAME_RATE_LAND, anim_seq_land);
      rest(pid);
      return;
    }

    velocity_by_aim(pid, g_flight_descent_speed, vel);
    vel[2] = g_flight_descent_z_speed;
  }
  set_pev(pid, pev_velocity, vel);
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

public task_liftoff(tid)
{
  new pid = tid - tid_liftoff;
  
  new Float:vel[3];
  pev(pid, pev_velocity, vel);
  vel[2] = g_flight_liftoff_z_speed;
  set_pev(pid, pev_velocity, vel);
  
  uanim_play(pid, ANIM_DURATION_LIFTOFF, ANIM_FRAME_RATE_LIFTOFF, anim_seq_liftoff);

  new origin[3];
  get_user_origin(pid, origin);

  ufx_te_lavasplash(origin);
  ufx_te_teleport(origin);
  ufx_screenshake(pid, 1.0, 2.0, 1.0);
  ufx_screenfade(pid, 1.0, 0.0625, ufx_ffade_in, {0, 0, 120, 4});
  
  set_task_ex(FLIGHT_SOUND_INTERVAL, "task_cruise", tid_cruise + pid);

  gxp_emit_sound(pid, "death", g_id, g_props);
}

public task_cruise(tid)
{
  new pid = tid - tid_cruise;

  UBITS_PSET(g_in_flight, pid);

  uanim_play(pid, ANIM_DURATION_CRUISE, ANIM_FRAME_RATE_CRUISE, anim_seq_cruise);

  set_task_ex(
    FLIGHT_SOUND_INTERVAL, "task_screech", tid_screech + pid,
    .flags = SetTask_RepeatTimes, .repeat = floatround(g_flight_duration / FLIGHT_SOUND_INTERVAL)
  );
  set_task_ex(g_flight_duration, "task_fall", tid_fall + pid);
}

public task_screech(tid)
{
  gxp_emit_sound(tid - tid_screech, "death", g_id, g_props, CHAN_VOICE);
}

public task_fall(tid)
{
  new pid = tid - tid_fall;
  uanim_play(pid, ANIM_DURATION_FALL, ANIM_FRAME_RATE_FALL, anim_seq_fall);
  rest(pid);
}

/* Helpers */

rest(pid)
{
  UBITS_PUNSET(g_in_flight, pid);
  UBITS_PUNSET(g_in_descent, pid);

  gxp_set_player_data(pid, pd_ability_last_used, get_gametime());
  gxp_set_player_data(pid, pd_ability_in_use, false);
}