#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

#include <utils_bits>

new g_id;

new Float:g_dmg_mult;

new Float:g_vel[3];

new g_props[GxpClass];

/* Bitfields */

new g_of_class;

public plugin_init()
{
  register_plugin(_GXP_SWARM_ARMORED_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards > FakeMeta */

  register_forward(FM_PlayerPreThink, "fm_playerprethink_pre");
  register_forward(FM_PlayerPreThink, "fm_playerprethink_post", ._post = true);

  /* Forwards > Ham */

  RegisterHam(Ham_TakeDamage, "player", "ham_player_takedamage_pre");
  RegisterHam(Ham_TraceAttack, "player", "ham_player_traceattack_pre");
  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);

  /* Setup */

  gxp_config_get_class("armored", g_props);

  TrieGetCell(g_props[cls_misc], "damage_multiplier", g_dmg_mult);

  g_id = gxp_register_class("armored", tm_zombie);
}

/* Forwards > GunXP > Player */

public gxp_player_spawned(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props)) {
    UBITS_PUNSET(g_of_class, pid);
    return;
  }

  UBITS_PSET(g_of_class, pid);

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

public fm_playerprethink_pre(pid)
{
  if (UBITS_PCHECK(g_of_class, pid) && (pev(pid, pev_flags) & FL_ONGROUND))
    pev(pid, pev_velocity, g_vel);
  return HAM_IGNORED;
}

public fm_playerprethink_post(pid)
{
  if (UBITS_PCHECK(g_of_class, pid) && (pev(pid, pev_flags) & FL_ONGROUND))
    set_pev(pid, pev_velocity, g_vel);
}

/* Forwards > Ham */

public ham_player_takedamage_pre(victim, inflictor, attacker, Float:dmg, dmg_bits)
{
  if (is_user_alive(victim) && UBITS_PCHECK(g_of_class, victim)) {
    SetHamParamFloat(4, dmg*g_dmg_mult);
    return HAM_HANDLED;
  }
  return HAM_IGNORED;
}

public ham_player_traceattack_pre(
  pid_victim, pid_attacker, Float:dmg, Float:dir[3], tr, dmg_type_bitsum
)
{
  if (UBITS_PCHECK(g_of_class, pid_victim))
    SetHamParamVector(4, Float:{0.0, 0.0, 0.0});
  return HAM_IGNORED;
}

public ham_item_preframe_post(pid)
{
  if (is_user_alive(pid) && UBITS_PCHECK(g_of_class, pid))
    set_pev(pid, pev_maxspeed, float(g_props[cls_speed]));
}
