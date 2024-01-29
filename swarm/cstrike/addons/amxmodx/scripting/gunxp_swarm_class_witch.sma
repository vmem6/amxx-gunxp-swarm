#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

#include <utils_effects>
#include <utils_bits>

new g_angry_speed;
new Float:g_angry_duration;
new Float:g_angry_dmg;

new Float:g_vel[3];

new g_id;
new g_props[GxpClass];

/* Bitfields */

new g_angry;

new g_of_class;

public plugin_init()
{
  register_plugin(_GXP_SWARM_WITCH_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards > FakeMeta */

  register_forward(FM_PlayerPreThink, "fm_playerprethink_pre");

  /* Forwards > Ham */

  RegisterHam(Ham_TakeDamage, "player", "ham_takedamage_pre");
  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);

  /* Setup */

  gxp_config_get_class("witch", g_props);

  TrieGetCell(g_props[cls_misc], "angry_speed", g_angry_speed);
  TrieGetCell(g_props[cls_misc], "angry_duration", g_angry_duration);
  TrieGetCell(g_props[cls_misc], "angry_damage", g_angry_dmg);

  g_id = gxp_register_class("witch", tm_zombie);
}

/* Forwards > GunXP > Player */

public gxp_player_cleanup(pid)
{
  calm_down(pid);
}

public gxp_player_spawned(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props)) {
    UBITS_PUNSET(g_of_class, pid);
    return;
  }

  UBITS_PSET(g_of_class, pid);
  UBITS_PUNSET(g_angry, pid);

  set_pev(pid, pev_gravity, g_props[cls_gravity]);
  gxp_user_set_model(pid, g_props);
}

public gxp_player_used_ability(pid)
{
  if (!UBITS_PCHECK(g_of_class, pid))
    return;

  new Float:time = get_gametime();
  if (time - Float:gxp_get_player_data(pid, pd_ability_last_used) < g_props[cls_ability_cooldown])
    return;

  UBITS_SET(g_angry, pid);

  set_pev(pid, pev_maxspeed, float(g_angry_speed));

  ufx_screenfade(pid, 0.0, 0.0, ufx_ffade_stayout, {255, 0, 0, 150});

  set_task_ex(g_angry_duration, "calm_down", pid);
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

public fm_playerprethink_pre(pid)
{
  if (!UBITS_PCHECK(g_of_class, pid) || !UBITS_PCHECK(g_angry, pid))
    return;

  static origin[3];
  get_user_origin(pid, origin);
  ufx_te_dlight(origin, 150, {200, 0, 0}, 10, 0);

  pev(pid, pev_velocity, g_vel);
}

public fm_playerprethink_post(pid)
{
  if (UBITS_PCHECK(g_of_class, pid))
    set_pev(pid, pev_velocity, g_vel);
}

/* Forwards > Ham */

public ham_takedamage_pre(victim, inflictor, attacker, Float:dmg, dmg_bits)
{
  if (
    victim != attacker
    && attacker >= 1 && attacker <= MAX_PLAYERS
    && UBITS_PCHECK(g_of_class, attacker)
    && get_user_weapon(attacker) == CSW_KNIFE
    && UBITS_CHECK(g_angry, attacker)
  ) {
    SetHamParamFloat(4, g_angry_dmg);
    return HAM_HANDLED;
  }
  return HAM_IGNORED;
}

public ham_item_preframe_post(pid)
{
  if (!is_user_alive(pid) || !UBITS_PCHECK(g_of_class, pid))
    return HAM_IGNORED;
  set_pev(
    pid, pev_maxspeed, float(UBITS_PCHECK(g_angry, pid) ? g_angry_speed : g_props[cls_speed])
  );
  return HAM_SUPERCEDE;
}

/* Miscellaneous */

public calm_down(pid)
{
  if (!UBITS_PCHECK(g_of_class, pid))
    return;

  ufx_screenfade(pid, 1.0, 0.0, ufx_ffade_in, {180, 0, 0, 200});

  UBITS_UNSET(g_angry, pid);
  set_pev(pid, pev_maxspeed, float(g_props[cls_speed]));
}
