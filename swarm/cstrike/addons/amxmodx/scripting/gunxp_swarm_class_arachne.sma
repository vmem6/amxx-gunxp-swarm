#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

#include <utils_effects>
#include <utils_animation>

#define TIGHTROPE_CLASSNAME "arachne_tightrope"
#define TIGHTROPE_SPRITE    "sprites/jailas_swarm/arachne_spider_effect.spr"
#define TIGHTROPE_SEQ_SHOOT "skill_shoot"
#define TIGHTROPE_SEQ_LOOP  "skill_loop"

#define WEB_BOMB_CLASSNAME "arachne_web_bomb"
#define WEB_TRAP_CLASSNAME "arachne_web_trap"

#define ANIM_DURATION_SKILL_SHOOT 21.0/1.0

enum
{
  anim_wpn_seq_skill_shoot = 9
};

new g_rope_velocity;
new g_rope_speed;

new g_id;

new g_props[GxpClass];

new g_spr_tightrope;

new g_alloc_str_info_target;
new g_alloc_str_tightrope;
new g_alloc_str_web_bomb;
new g_alloc_str_web_trap;

public plugin_precache()
{
  g_spr_tightrope = engfunc(EngFunc_PrecacheModel, TIGHTROPE_SPRITE);

  g_alloc_str_info_target = engfunc(EngFunc_AllocString, "info_target");
  g_alloc_str_tightrope = engfunc(EngFunc_AllocString, TIGHTROPE_CLASSNAME);
  g_alloc_str_web_bomb = engfunc(EngFunc_AllocString, WEB_BOMB_CLASSNAME);
  g_alloc_str_web_trap = engfunc(EngFunc_AllocString, WEB_TRAP_CLASSNAME);
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_ARACHNE_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards > FakeMeta */

  register_forward(FM_Think, "fm_think_pre");

  /* Forwards > Ham */

  RegisterHam(Ham_Touch, "info_target", "ham_info_target_touch_pre");
  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);

  /* Setup */

  gxp_config_get_class("arachne", g_props);

  TrieGetCell(g_props[cls_misc], "rope_velocity", g_rope_velocity);
  TrieGetCell(g_props[cls_misc], "rope_speed", g_rope_speed);

  g_id = gxp_register_class("arachne", tm_zombie);
}

/* Forwards > GunXP > Player */

public gxp_player_spawned(pid)
{
  if (_gxp_is_player_of_class(pid, g_id, g_props)) {
    set_pev(pid, pev_gravity, g_props[cls_gravity]);
    gxp_user_set_model(pid, g_props);
  }
}

public gxp_player_cleanup(pid)
{
  if (_gxp_is_player_of_class(pid, g_id, g_props)) {
  }
}

public gxp_player_used_ability(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  new Float:time = get_gametime();
  if (time - Float:gxp_get_player_data(pid, pd_ability_last_used) < g_props[cls_ability_cooldown])
    return;

  shoot_rope(pid);
}

public gxp_player_used_secn_ability(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  new Float:time = get_gametime();
  if (
    time - Float:gxp_get_player_data(pid, pd_secn_ability_last_used) <
      g_props[cls_secn_ability_cooldown]) {
    return;
  }


}

public gxp_player_knife_slashed(pid)  { gxp_emit_sound(pid, "miss", g_id, g_props); }
public gxp_player_knife_hitwall(pid)  { gxp_emit_sound(pid, "miss", g_id, g_props); }
public gxp_player_knife_hit(pid)      { gxp_emit_sound(pid, "hit",  g_id, g_props); }
public gxp_player_knife_stabbed(pid)  { gxp_emit_sound(pid, "hit",  g_id, g_props); }

public gxp_player_suffer(pid) { gxp_emit_sound(pid, "pain",  g_id, g_props); }
public gxp_player_died(pid)   { gxp_emit_sound(pid, "death", g_id, g_props); }

/* Forwards > FakeMeta */

public fm_think_pre(ent)
{
  if (pev_valid(ent) != 2)
    return HAM_IGNORED;

  new classname_idx = pev(ent, pev_classname);
  if (classname_idx == g_alloc_str_tightrope) {
    new owner = pev(ent, pev_owner);
    if (!is_user_alive(owner)) {
      ufx_te_killbeam(owner);
      set_pev(ent, pev_flags, FL_KILLME);
      return HAM_IGNORED;
    }

    static Float:owner_origin[3];
    static Float:ent_origin[3];
    static Float:dist;
    static Float:dmg_time;

    pev(owner, pev_origin, owner_origin);
    pev(ent, pev_origin, ent_origin);
    dist = get_distance_f(ent_origin, owner_origin);
    pev(ent, pev_dmgtime, dmg_time);

    if (dist <= 40.0 || dmg_time <= get_gametime()) {
      ufx_te_killbeam(owner);
      set_pev(ent, pev_flags, FL_KILLME);
      gxp_set_player_data(owner, pd_ability_last_used, get_gametime());
      return HAM_IGNORED;
    }

    static Float:vel[3];
    vel[0] = (ent_origin[0] - owner_origin[0]) * (float(g_rope_speed) / dist);
    vel[1] = (ent_origin[1] - owner_origin[1]) * (float(g_rope_speed) / dist);
    vel[2] = (ent_origin[2] - owner_origin[2]) * (float(g_rope_speed) / dist);

    set_pev(owner, pev_velocity, vel);
    set_pev(ent, pev_nextthink, get_gametime());
  }

  return HAM_IGNORED;
}

public ham_info_target_touch_pre(ent, touched_ent) {
  new classname_idx = pev(ent, pev_classname);
  if (classname_idx == g_alloc_str_tightrope) {
    static owner;
    owner = pev(ent, pev_owner);
    if (!is_user_alive(owner)) {
      ufx_te_killbeam(owner);
      set_pev(ent, pev_flags, FL_KILLME);
      return HAM_IGNORED;
    }

    if (touched_ent == owner)
      return HAM_SUPERCEDE;

    if (is_user_alive(touched_ent)) {
      ufx_te_killbeam(owner);
      uanim_send_weaponanim(owner, 11, 20/30.0);
      set_pev(ent, pev_flags, FL_KILLME);
      return HAM_IGNORED;
    }

    if (pev(ent, pev_solid) != SOLID_NOT) {
      gxp_emit_sound(owner, "abilityropeok", g_id, g_props);

      uanim_send_weaponanim(owner, 10, 90/30.0);
      uanim_play2(owner, TIGHTROPE_SEQ_LOOP);

      set_pev(ent, pev_solid, SOLID_NOT);
      set_pev(ent, pev_movetype, MOVETYPE_NONE);
      set_pev(ent, pev_dmgtime, get_gametime() + 80/30.0);
      set_pev(ent, pev_nextthink, get_gametime());
    }
  } else if (classname_idx == g_alloc_str_web_bomb) {
    static iOwner; iOwner = pev(iEntity, pev_owner);
    static Float: vecOrigin[3]; pev(iEntity, pev_origin, vecOrigin);

    if (!is_user_connected(owner) || engfunc(EngFunc_PointContents, origin) == CONTENTS_SKY) {
      set_pev(ent, pev_flags, FL_KILLME);
      return HAM_IGNORED;
    }

    if (touched_ent == owner)
      return HAM_SUPERCEDE;

    new _ent = FM_NULLENT;

    while ((iTouch = engfunc(EngFunc_FindEntityInSphere, iTouch, vecOrigin, float(WEBBOMB_RADIUS))) != 0) {
      if(pev(iTouch, pev_takedamage) == DAMAGE_NO) continue;
      if(!is_user_alive(iTouch) || g_zombie[iTouch]) continue;

      if(pev(iTouch, pev_health) - float(WEBBOMB_DAMAGE) <= float(WEBBOMB_DAMAGE)) ExecuteHamB(Ham_Killed, iTouch, iOwner, 0);
      else set_pev(iTouch, pev_health, pev(iTouch, pev_health) - float(WEBBOMB_DAMAGE));
    }

    CEntity__WebTrap(vecOrigin);

    set_pev(ent, pev_flags, FL_KILLME);
  }
  // } else if (classname_idx == g_alloc_str_web_trap) {
  //   if (touched_ent && is_user_alive(touched_ent) && !g_zombie[iTouch]) {
  //     static Float: vecVelocity[3]; pev(iTouch, pev_velocity, vecVelocity);
  //     vecVelocity[0] *= WEBTRAP_SLOWMOVE;
  //     vecVelocity[1] *= WEBTRAP_SLOWMOVE;
  //     set_pev(iTouch, pev_velocity, vecVelocity);

  //     if(!g_blockParachuteTimer[iTouch]){
  //       set_task(BLOCK_PARACHUTE_TIME, "arachne_slowdown_unblock_parachute", iTouch + TASKID_SLOWDOWN_BLOCK_PARACHUTE);
  //       g_blockParachuteTimer[iTouch] = true;
  //       parachute_pause(iTouch, BLOCK_PARACHUTE_TIME + 1.0);
  //     }
  //   }
  // }

  return HAM_IGNORED;
}

/* Forwards > Ham */

public ham_item_preframe_post(pid)
{
  if (is_user_alive(pid) && _gxp_is_player_of_class(pid, g_id, g_props))
    set_pev(pid, pev_maxspeed, float(g_props[cls_speed]));
}

/* Helpers */

shoot_rope(pid)
{
  uanim_play2(pid, TIGHTROPE_SEQ_SHOOT);
  uanim_send_weaponanim(pid, anim_wpn_seq_skill_shoot, ANIM_DURATION_SKILL_SHOOT);

  gxp_emit_sound(pid, "abilityrope", g_id, g_props);

  new rope = engfunc(EngFunc_CreateNamedEntity, g_alloc_str_info_target);

  new Float:origin[3];
  new Float:view_ofs[3];
  new Float:vel[3];

  pev(pid, pev_origin, origin);
  pev(pid, pev_view_ofs, view_ofs);
  velocity_by_aim(pid, g_rope_velocity, vel);

  origin[0] += view_ofs[0];
  origin[1] += view_ofs[1];
  origin[2] += view_ofs[2];

  set_pev_string(rope, pev_classname, g_alloc_str_tightrope);
  set_pev(rope, pev_owner, pid);
  set_pev(rope, pev_solid, SOLID_TRIGGER);
  set_pev(rope, pev_movetype, MOVETYPE_FLY);
  set_pev(rope, pev_velocity, vel);
  set_pev(rope, pev_renderfx, kRenderFxNone);
  set_pev(rope, pev_rendermode, kRenderTransAdd);
  set_pev(rope, pev_renderamt, 0.0);

  engfunc(EngFunc_SetModel, rope, TIGHTROPE_SPRITE);
  engfunc(EngFunc_SetSize, rope, Float:{ -1.0, -1.0, -1.0 }, { 1.0, 1.0, 1.0 });
  engfunc(EngFunc_SetOrigin, rope, origin);

  ufx_te_beaments(
    rope, pid,
    g_spr_tightrope, 0, 0.0, 25.5,
    random_float(5.0, 7.5), random_float(0.0, 0.1), { 255, 255, 255 }, 255, 10.0
  );
}