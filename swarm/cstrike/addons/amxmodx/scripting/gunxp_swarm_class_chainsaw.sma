#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

#include <utils_effects>
#include <utils_offsets>

new Float:g_damage;
new Float:g_pattack_rate;
new Float:g_pattack_recoil;
new Float:g_sattack_rate;
new Float:g_sattack_recoil;

new g_id;
new g_props[GxpClass];

public plugin_init()
{
  register_plugin(_GXP_SWARM_CHAINSAW_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards > Ham */

  RegisterHam(Ham_TakeDamage, "player", "ham_takedamage_pre");
  RegisterHam(
    Ham_Weapon_PrimaryAttack, "weapon_knife", "ham_weapon_primaryattack_knife_post", .Post = 1
  );
  RegisterHam(
    Ham_Weapon_SecondaryAttack, "weapon_knife", "ham_weapon_secondaryattack_knife_post", .Post = 1
  );
  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);

  /* Setup */

  gxp_config_get_class("chainsaw", g_props);

  TrieGetCell(g_props[cls_misc], "damage", g_damage);
  TrieGetCell(g_props[cls_misc], "attack1_rate", g_pattack_rate);
  TrieGetCell(g_props[cls_misc], "attack2_rate", g_sattack_rate);
  TrieGetCell(g_props[cls_misc], "attack1_recoil", g_pattack_recoil);
  TrieGetCell(g_props[cls_misc], "attack2_recoil", g_sattack_recoil);

  g_id = gxp_register_class("chainsaw", tm_zombie);
}

/* Forwards > GunXP > Player */

public gxp_player_spawned(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;
  set_pev(pid, pev_gravity, g_props[cls_gravity]);
  gxp_user_set_model(pid, g_props);
}

public gxp_player_knife_slashed(pid)  { gxp_emit_sound(pid, "miss", g_id, g_props, CHAN_WEAPON); }
public gxp_player_knife_hitwall(pid)  { gxp_emit_sound(pid, "miss", g_id, g_props, CHAN_WEAPON); }
public gxp_player_knife_hit(pid)      { gxp_emit_sound(pid, "hit",  g_id, g_props, CHAN_WEAPON); }
public gxp_player_knife_stabbed(pid)  { gxp_emit_sound(pid, "hit",  g_id, g_props, CHAN_WEAPON); }

public gxp_player_suffer(pid) { gxp_emit_sound(pid, "pain",  g_id, g_props, CHAN_VOICE); }
public gxp_player_died(pid)   { gxp_emit_sound(pid, "death", g_id, g_props, CHAN_VOICE); }

/* Forwards > Ham */

public ham_takedamage_pre(victim, inflictor, attacker, Float:dmg, dmg_bits)
{
  if (
    victim != attacker
    && _gxp_is_player_of_class(attacker, g_id, g_props)
    && get_user_weapon(attacker) == CSW_KNIFE
  ) {
    ufx_blood_splatter(victim);
    SetHamParamFloat(4, g_damage);
    return HAM_HANDLED;
  }
  return HAM_IGNORED;
}

public ham_weapon_primaryattack_knife_post(wid)
{
  new pid = get_pdata_cbase(wid, UXO_P_PLAYER, 4);
  if (is_user_alive(pid) && _gxp_is_player_of_class(pid, g_id, g_props))
    fix_knife_params(pid, wid, g_pattack_rate, g_pattack_recoil);
}

public ham_weapon_secondaryattack_knife_post(wid)
{
  new pid = get_pdata_cbase(wid, UXO_P_PLAYER, 4);
  if (is_user_alive(pid) && _gxp_is_player_of_class(pid, g_id, g_props))
    fix_knife_params(pid, wid, g_sattack_rate, g_sattack_recoil);
}

public ham_item_preframe_post(pid)
{
  if (is_user_alive(pid) && _gxp_is_player_of_class(pid, g_id, g_props))
    set_pev(pid, pev_maxspeed, float(g_props[cls_speed]));
}

/* Helpers */

fix_knife_params(pid, wid, Float:rate, Float:recoil)
{
  set_pdata_float(wid, UXO_FL_NEXT_PRIMARY_ATTACK, rate, UXO_LINUX_DIFF_ANIMATING);
  set_pdata_float(wid, UXO_FL_NEXT_SECONDARY_ATTACK, rate, UXO_LINUX_DIFF_ANIMATING);
  set_pdata_float(wid, UXO_FL_TIME_WEAPON_IDLE, rate, UXO_LINUX_DIFF_ANIMATING);

  new Float:punchangle[3];
  punchangle[0] = recoil;
  set_pev(pid, pev_punchangle, punchangle);
}