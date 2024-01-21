#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

new g_id;

new g_props[GxpClass];

public plugin_init()
{
  register_plugin(_GXP_SWARM_ARACHNE_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards > Ham */

  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);

  /* Setup */

  gxp_config_get_class("arachne", g_props);

  g_id = gxp_register_class("arachne", tm_zombie);
}

/* Forwards > GunXP > Player */

public gxp_player_spawn(pid)
{
  if (!gxp_is_player_of_class(pid, g_id, g_props)) {
    return;
  }

  set_pev(pid, pev_health, float(g_props[cls_health]));
  set_pev(pid, pev_armorvalue, float(g_props[cls_armour]));
  set_pev(pid, pev_gravity, g_props[cls_gravity]);

  gxp_user_set_model(pid, g_props);
}

public gxp_player_cleanup(pid)
{
  if (gxp_is_player_of_class(pid, g_id, g_props)) {
  }
}

public gxp_player_used_ability(pid)
{
  if (!gxp_is_player_of_class(pid, g_id, g_props)) {
    return;
  }

  new Float:time = get_gametime();
  if (time - Float:gxp_get_player_data(pid, pd_ability_last_used) < g_props[cls_ability_cooldown]) {
    return;
  }
}

public gxp_player_knife_slashed(pid)  { gxp_emit_sound(pid, "miss", g_id, g_props); }
public gxp_player_knife_hitwall(pid)  { gxp_emit_sound(pid, "miss", g_id, g_props); }
public gxp_player_knife_hit(pid)      { gxp_emit_sound(pid, "hit",  g_id, g_props); }
public gxp_player_knife_stabbed(pid)  { gxp_emit_sound(pid, "hit",  g_id, g_props); }

public gxp_player_suffer(pid) { gxp_emit_sound(pid, "pain",  g_id, g_props); }
public gxp_player_died(pid)   { gxp_emit_sound(pid, "death", g_id, g_props); }

/* Forwards > Ham */

public ham_item_preframe_post(pid)
{
  if (is_user_alive(pid) && gxp_is_player_of_class(pid, g_id, g_props)) {
    set_pev(pid, pev_maxspeed, float(g_props[cls_speed]));
    return HAM_SUPERCEDE;
  }
  return HAM_IGNORED;
}