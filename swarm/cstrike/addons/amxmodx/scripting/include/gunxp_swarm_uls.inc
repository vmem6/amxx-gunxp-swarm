#if defined _GUNXP_SWARM_ULS_INC
  #endinput
#endif
#define _GUNXP_SWARM_ULS_INC

#include <gunxp_swarm_const>

/* Natives */

/* Maintained for backwards compatibility. */
native register_gxm_item(const title[], const desc[], cost, level, GxpUlClass:class, access, weapon_id);
native register_item_gxm(const title[], const desc[], cost, level, GxpUlClass:class, access, weapon_id);

native Array:gxp_ul_get_class_items(GxpUlClass:class);
native gxp_ul_get_by_id(id, ul[GxpUl]);

native gxp_ul_activate(pid, const ul[GxpUl]);
native gxp_ul_activate_free(pid);
native gxp_ul_activate_newbie(pid);

/* Forward */

forward gxp_ul_activated(pid, ul_id, bool:automatic);

/* Maintained for backwards compatibility. */
forward gxm_item_enabled(pid);