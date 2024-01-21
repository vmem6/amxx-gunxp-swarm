#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <fakemeta_util>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

#include <utils_animation>
#include <utils_effects>

/* In seconds */
#define ANIM_DURATION_SKILL_TO_SHOOT    30/30.0
#define ANIM_DURATION_SKILL_GUARD       75/30.0
#define ANIM_DURATION_SKILL_TO_IDLE     31/30.0
#define ANIM_DURATION_SKILL_REINFORCE   31/30.0

enum ChargeState
{
  cs_none,
  cs_start,
  cs_active,
  cs_ready,
  cs_end
}

enum _:Charge
{
  ChargeState:charge_state,
  charge_accumulated_dmg,
  charge_level
};

enum (+= 100)
{
  tid_charge = 1789,
  tid_discharge,
  tid_block_velocity
};

enum
{
  anim_wpn_seq_skill_start = 8,
  anim_wpn_seq_skill_guard1,
  anim_wpn_seq_skill_guard2,
  anim_wpn_seq_skill_guard3,
  anim_wpn_seq_skill_guard4,
  anim_wpn_seq_skill_guard5,
  anim_wpn_seq_skill_to_shoot,
  anim_wpn_seq_skill_to_idle,
  anim_wpn_seq_skill_reinforce
};

enum
{
  anim_seq_skill_start = 111,
  anim_seq_skill_loop,
  anim_seq_skill_shoot,
  anim_seq_skill_idle
};

new const g_charge_lvl_dmg_map[5] = { 50, 50, 75, 100, 125 };

new g_charges[MAX_PLAYERS + 1][Charge];

new g_id;

new g_props[GxpClass];

public plugin_init()
{
  register_plugin(_GXP_SWARM_YAKSHA_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards > Ham */

  RegisterHam(Ham_TraceAttack, "player", "ham_traceattack_post", .Post = 1);
  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);

  /* Setup */

  gxp_config_get_class("yaksha", g_props);

  g_id = gxp_register_class("yaksha", tm_zombie);
}

/* Forwards > GunXP > Player */

public gxp_player_spawned(pid)
{
  if (!gxp_is_player_of_class(pid, g_id, g_props)) {
    return;
  }

  set_pev(pid, pev_health, float(g_props[cls_health]));
  set_pev(pid, pev_armorvalue, float(g_props[cls_armour]));
  set_pev(pid, pev_gravity, g_props[cls_gravity]);

  gxp_user_set_model(pid, g_props);
  gxp_user_set_viewmodel(pid, g_props);
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

  if (g_charges[pid][charge_state] == cs_none) {
    g_charges[pid][charge_state] = cs_start;

    set_task_ex(13/30.0, "task_charge", pid + tid_charge);
    set_task_ex(0.1, "task_block_velocity", pid + tid_block_velocity, .flags = SetTask_Repeat);

    fm_set_rendering(pid, kRenderFxGlowShell, 255, 69, 0, kRenderNormal, 8);

    uanim_send_weaponanim(pid, anim_wpn_seq_skill_start, 99.0);
    uanim_play(pid, 3.0, 0.5, anim_seq_skill_start);

    gxp_emit_sound(pid, "abilitycharge", g_id, g_props, CHAN_WEAPON);
  } else if (
    g_charges[pid][charge_state] == cs_active
    && pev(pid, pev_weaponanim) == anim_wpn_seq_skill_guard5
  ) {
    remove_task(pid + tid_discharge);

    g_charges[pid][charge_state] = cs_ready;
    shoot_energy_ball(pid);

    uanim_send_weaponanim(pid, anim_wpn_seq_skill_to_shoot, ANIM_DURATION_SKILL_TO_SHOOT);
    uanim_play(pid, 3.0, 1.0, anim_seq_skill_shoot);

    set_task_ex(ANIM_DURATION_SKILL_TO_SHOOT, "task_discharge", pid + tid_discharge);

    gxp_emit_sound(pid, "abilityshoot", g_id, g_props, CHAN_ITEM);
  }
}

public gxp_player_used_secn_ability(pid)
{

}

public gxp_player_knife_slashed(pid)  { gxp_emit_sound(pid, "miss", g_id, g_props); }
public gxp_player_knife_hitwall(pid)  { gxp_emit_sound(pid, "miss", g_id, g_props); }
public gxp_player_knife_hit(pid)      { gxp_emit_sound(pid, "hit",  g_id, g_props); }
public gxp_player_knife_stabbed(pid)  { gxp_emit_sound(pid, "hit",  g_id, g_props); }

public gxp_player_suffer(pid) { gxp_emit_sound(pid, "pain",  g_id, g_props); }
public gxp_player_died(pid)   { gxp_emit_sound(pid, "death", g_id, g_props); }

/* Forwards > Ham */

public ham_traceattack_post(victim, attacker, Float:dmg, Float:dir[3], tr_handle)
{
  if (
    !is_user_alive(attacker)
    || !is_user_alive(victim)
    || GxpTeam:gxp_get_player_data(attacker, pd_team) == tm_zombie
    || !gxp_is_player_of_class(victim, g_id, g_props)
  ) {
    return HAM_IGNORED;
  }

  if (g_charges[victim][charge_state] != cs_active) {
    return HAM_IGNORED;
  }

  set_pev(victim, pev_punchangle, { 0.0, 0.0, 0.0 });

  g_charges[victim][charge_accumulated_dmg] += floatround(dmg);

  static end_pos[3];
  get_tr2(tr_handle, TR_vecEndPos, end_pos);
  ufx_te_sparks(end_pos);

  /* TODO: rewrite, can be optimized. */

  if (g_charges[victim][charge_level] >= 5) {
    return HAM_IGNORED;
  }

  if (
    g_charges[victim][charge_accumulated_dmg] >=
      g_charge_lvl_dmg_map[g_charges[victim][charge_level]]
    && pev(victim, pev_weaponanim) < anim_wpn_seq_skill_guard5
  ) {
    ++g_charges[victim][charge_level];

    uanim_send_weaponanim(
      victim, anim_wpn_seq_skill_guard1 + g_charges[victim][charge_level], ANIM_DURATION_SKILL_GUARD
    );

    if (pev(victim, pev_weaponanim) == anim_wpn_seq_skill_guard5) {
      // inform of energy ball...
    }
  }

  return HAM_IGNORED;
}

public ham_item_preframe_post(pid)
{
  if (is_user_alive(pid) && gxp_is_player_of_class(pid, g_id, g_props)) {
    set_pev(pid, pev_maxspeed, float(g_props[cls_speed]));
    return HAM_SUPERCEDE;
  }
  return HAM_IGNORED;
}

/* Tasks */

public task_charge(tid)
{
  new pid = tid - tid_charge;

  g_charges[pid][charge_state] = cs_active;

  set_task_ex(6.0, "task_discharge", pid + tid_discharge);

  uanim_send_weaponanim(pid, anim_wpn_seq_skill_guard1, 99.0);
  uanim_play(pid, 3.0, 0.8, anim_seq_skill_loop);
}

public task_discharge(tid)
{
  new pid = tid - tid_discharge;

  fm_set_rendering(pid, kRenderFxNone);

  if (g_charges[pid][charge_state] == cs_active) {
    uanim_send_weaponanim(pid, anim_wpn_seq_skill_to_idle, ANIM_DURATION_SKILL_TO_IDLE);
    uanim_play(pid, 3.0, 1.0, anim_seq_skill_idle);
  }

  g_charges[pid][charge_state] = cs_end;

  remove_task(pid + tid_block_velocity);

  gxp_set_player_data(pid, pd_ability_last_used, get_gametime());

  // reset data?
}

public task_block_velocity(tid)
{
  set_pev(tid - tid_block_velocity, pev_velocity, {0.0, 0.0, 0.0});
}

/* Helpers */

shoot_energy_ball(pid)
{
  new ball = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));

  new Float:velocity[3];
  velocity_by_aim(pid, 500, velocity);

  new Float:origin[3];
  UTIL_GetPosition(pid, 10.0, 0.0, 15.0, origin);

  pev(iPlayer, pev_origin, vecOrigin);
  pev(iPlayer, pev_view_ofs, vecUp);
  xs_vec_add(vecOrigin, vecUp, vecOrigin);
  pev(iPlayer, pev_angles, vecAngle);

  angle_vector(vecAngle, ANGLEVECTOR_FORWARD, vecForward);
  angle_vector(vecAngle, ANGLEVECTOR_RIGHT, vecRight);
  angle_vector(vecAngle, ANGLEVECTOR_UP, vecUp);

  origin[0] = origin[0] + vecForward[0] * flForward + vecRight[0] * flRight + vecUp[0] * flUp;
  origin[1] = origin[1] + vecForward[1] * flForward + vecRight[1] * flRight + vecUp[1] * flUp;
  origin[2] = origin[2] + vecForward[2] * flForward + vecRight[2] * flRight + vecUp[2] * flUp;

  set_pev(ball, pev_classname, FLAME_CLASSNAME);
  set_pev(ball, pev_owner, pid);
  set_pev(ball, pev_solid, SOLID_TRIGGER);
  set_pev(ball, pev_movetype, MOVETYPE_TOSS);
  set_pev(ball, pev_gravity, -1.0);
  set_pev(ball, pev_velocity, velocity);
  set_pev(ball, pev_frame, 0.0);
  set_pev(ball, pev_scale, 0.3);
  set_pev(ball, pev_rendermode, kRenderTransAdd);
  set_pev(ball, pev_renderamt, 255.0);

  engfunc(EngFunc_SetModel, ball, FLAME_MODEL);
  engfunc(EngFunc_SetSize, ball, { -1.0, -1.0, -1.0 }, { 1.0, 1.0, 1.0 });
  engfunc(EngFunc_SetOrigin, ball, origin);

  set_pev(ball, pev_fuser1, get_gametime() + 0.3);
  set_pev(ball, pev_nextthink, get_gametime());
}