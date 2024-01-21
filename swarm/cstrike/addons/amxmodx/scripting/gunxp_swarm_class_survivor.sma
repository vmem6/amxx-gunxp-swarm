#include <amxmodx>
#include <fakemeta>
#include <cstrike>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

new g_id;

new g_props[GxpClass];

#define PRINT(%0,%1) server_print(%0, g_props[cls_%1])

public plugin_init()
{
  register_plugin(_GXP_SWARM_SURVIVOR_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Setup */

  gxp_config_get_class("survivor", g_props);
  g_id = gxp_register_class("survivor", tm_survivor);
}

/* Forwards > GunXP > Player */

public gxp_player_spawned(pid)
{
  if (_gxp_is_player_of_class(pid, g_id, g_props))
    gxp_user_set_model(pid, g_props);
}