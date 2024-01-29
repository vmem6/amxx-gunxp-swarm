#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

new Float:g_touch_origin[MAX_PLAYERS + 1][3];

new g_id;

new g_climb_speed;

new g_props[GxpClass];

public plugin_init()
{
  register_plugin(_GXP_SWARM_JOCKEY_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards > FakeMeta */

  register_forward(FM_Touch, "fm_touch_post", ._post = 1);
  register_forward(FM_PlayerPreThink, "fm_playerprethink_post", ._post = 1);

  /* Forwards > Ham */

  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);

  /* Setup */

  gxp_config_get_class("jockey", g_props);

  TrieGetCell(g_props[cls_misc], "climb_speed", g_climb_speed);

  g_id = gxp_register_class("jockey", tm_zombie);
}

/* Forwards > GunXP > Player */

public gxp_player_spawned(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  gxp_set_player_data(pid, pd_ability_available, false);
  set_pev(pid, pev_gravity, g_props[cls_gravity]);
  gxp_user_set_model(pid, g_props);
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
  if (is_user_alive(pid) && _gxp_is_player_of_class(pid, g_id, g_props))
    pev(pid, pev_origin, g_touch_origin[pid]);
}

public fm_playerprethink_post(pid)
{
  if (!is_user_alive(pid) || !_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  static button;
  button = pev(pid, pev_button);

  if (!(button & IN_USE) || (pev(pid, pev_flags) & FL_ONGROUND))
    return;

  static Float:origin[3];
  pev(pid, pev_origin, origin);
  if (get_distance_f(origin, g_touch_origin[pid]) < 25.0) {
    static Float:vel[3];
    arrayset(vel, 0.0, sizeof(vel));
    if (button & IN_FORWARD)
      velocity_by_aim(pid, g_climb_speed, vel);
    else if (button & IN_BACK)
      velocity_by_aim(pid, -g_climb_speed, vel);
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