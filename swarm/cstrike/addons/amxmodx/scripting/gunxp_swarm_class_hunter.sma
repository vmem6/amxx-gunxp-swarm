#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

new g_id;

new Float:g_jump_max_z;
new g_jump_speed;

new g_props[GxpClass];

public plugin_init()
{
  register_plugin(_GXP_SWARM_HUNTER_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards > Ham */

  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);

  /* Setup */

  gxp_config_get_class("hunter", g_props);

  TrieGetCell(g_props[cls_misc], "jump_max_z", g_jump_max_z);
  TrieGetCell(g_props[cls_misc], "jump_speed", g_jump_speed);

  g_id = gxp_register_class("hunter", tm_zombie);
}

/* Forwards > GunXP > Player */

public gxp_player_spawned(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  set_pev(pid, pev_gravity, g_props[cls_gravity]);

  gxp_user_set_model(pid, g_props);
}

public gxp_player_used_ability(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  new Float:time = get_gametime();
  if (time - Float:gxp_get_player_data(pid, pd_ability_last_used) < g_props[cls_ability_cooldown])
    return;

  new Float:vel[3];
  velocity_by_aim(pid, g_jump_speed, vel);
  vel[2] = g_jump_max_z;
  set_pev(pid, pev_velocity, vel);

  gxp_emit_sound(pid, "ability", g_id, g_props);

  gxp_set_player_data(pid, pd_ability_last_used, time);
}

public gxp_player_knife_slashed(pid)  { gxp_emit_sound(pid, "miss", g_id, g_props, CHAN_WEAPON); }
public gxp_player_knife_hitwall(pid)  { gxp_emit_sound(pid, "miss", g_id, g_props, CHAN_WEAPON); }
public gxp_player_knife_hit(pid)      { gxp_emit_sound(pid, "hit",  g_id, g_props, CHAN_WEAPON); }
public gxp_player_knife_stabbed(pid)  { gxp_emit_sound(pid, "hit",  g_id, g_props, CHAN_WEAPON); }

public gxp_player_suffer(pid) { gxp_emit_sound(pid, "pain",  g_id, g_props, CHAN_VOICE); }
public gxp_player_died(pid)   { gxp_emit_sound(pid, "death", g_id, g_props, CHAN_VOICE); }

/* Forwards > Ham */

public ham_item_preframe_post(pid)
{
  if (is_user_alive(pid) && _gxp_is_player_of_class(pid, g_id, g_props))
    set_pev(pid, pev_maxspeed, float(g_props[cls_speed]));
}