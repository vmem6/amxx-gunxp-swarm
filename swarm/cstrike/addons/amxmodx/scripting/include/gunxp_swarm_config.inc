#if defined _GUNXP_SWARM_CONFIG_INC
  #endinput
#endif
#define _GUNXP_SWARM_CONFIG_INC

#include <gunxp_swarm_const>

/* Natives */

native gxp_config_get_class(const id[GXP_MAX_CLASS_ID_LENGTH + 1], class[GxpClass]);
native gxp_config_set_class(const id[GXP_MAX_CLASS_ID_LENGTH + 1], class[GxpClass]);

native gxp_config_get_model_idx(const id[GXP_MAX_CLASS_ID_LENGTH + 1], const model_ctg[GXP_SWARM_CONFIG_MAX_KEY_LENGTH + 1], idx = -1);

/* Forwards */