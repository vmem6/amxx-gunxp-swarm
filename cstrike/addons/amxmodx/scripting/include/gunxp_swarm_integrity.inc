#if defined _GUNXP_SWARM_INTEGRITY_INC
  #endinput
#endif
#define _GUNXP_SWARM_INTEGRITY_INC

/* Natives */

native gxp_intg_watch_cvar(const cvar[]);

native gxp_intg_update_cvar(pid, const cvar[]);

native gxp_intg_get_cvar_int(pid, const cvar[]);
native Float:gxp_intg_get_cvar_float(pid, const cvar[]);
native gxp_intg_get_cvar_str(pid, const cvar[], buffer[], maxlen);

forward gxp_intg_cvar_changed(pid, const cvar[], const value[]);