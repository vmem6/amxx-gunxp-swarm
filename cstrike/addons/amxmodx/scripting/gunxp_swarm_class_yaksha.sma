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
#include <utils_text>

#define FLAME_CLASSNAME "yaksha_fireball"
#define FLAME_SPRITE    "sprites/jailas_swarm/ef_aksha_fireball.spr"
#define FLAME_SPRITE_EF "sprites/jailas_swarm/ef_aksha_fireballdestroy.spr"

#define EXPLOSION_SPRITE            "sprites/jailas_swarm/ef_aksha_fireballexplosion.spr"
#define EXPLOSION_SHOCKWAVE_SPRITE  "sprites/shockwave.spr"

#define RECOVERY_CLASSNAME  "yaksha_recovery"
#define RECOVERY_SPRITE     "sprites/jailas_swarm/heal.spr"

/* In seconds */
#define ANIM_DURATION_SKILL_TO_SHOOT    30/30.0 - 0.5
#define ANIM_DURATION_SKILL_GUARD       75/30.0
#define ANIM_DURATION_SKILL_TO_IDLE     31/30.0
#define ANIM_DURATION_SKILL_REINFORCE   31/30.0

#define CHARGE_LEVELS 5

#define EXPLOSION_DMG       random_num(175, 350)
#define EXPLOSION_DMG_TYPE  (DMG_NEVERGIB | DMG_SLASH)

enum e_charge_state
{
  cs_none,
  cs_start,
  cs_active,
  cs_ready
}

enum _:e_charge
{
  e_charge_state:charge_state,
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

new g_prefix[_GXP_MAX_PREFIX_LENGTH + 1];

new const g_charge_lvl_dmg_map[5] = { 50, 50, 75, 100, 125 };

new g_explosion_radius;
new Float:g_recovery_hp;

new g_charges[MAX_PLAYERS + 1][e_charge];

new g_id;

new g_props[GxpClass];

new g_spr_flame_effect;

new g_spr_explosion;
new g_spr_explosion_shockwave;

public plugin_precache()
{
  engfunc(EngFunc_PrecacheModel, FLAME_SPRITE)
  g_spr_flame_effect = engfunc(EngFunc_PrecacheModel, FLAME_SPRITE_EF);

  g_spr_explosion = engfunc(EngFunc_PrecacheModel, EXPLOSION_SPRITE);
  g_spr_explosion_shockwave = engfunc(EngFunc_PrecacheModel, EXPLOSION_SHOCKWAVE_SPRITE);

  engfunc(EngFunc_PrecacheModel, RECOVERY_SPRITE);
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_YAKSHA_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards > FakeMeta */

  register_forward(FM_Think, "fm_think_pre");

  /* Forwards > Ham */

  RegisterHam(Ham_Touch, "info_target", "ham_info_target_touch_pre");
  RegisterHam(Ham_TraceAttack, "player", "ham_traceattack_post", .Post = 1);
  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);

  /* Setup */

  gxp_config_get_class("yaksha", g_props);

  TrieGetCell(g_props[cls_misc], "explosion_radius", g_explosion_radius);
  TrieGetCell(g_props[cls_misc], "recovery_hp", g_recovery_hp);

  g_id = gxp_register_class("yaksha", tm_zombie, "cb_gxp_is_available");
}

public plugin_cfg()
{
  bind_pcvar_string(get_cvar_pointer("gxp_info_prefix"), g_prefix, charsmax(g_prefix));
  fix_colors(g_prefix, charsmax(g_prefix));
}

/* Forwards > GunXP > Player */

public gxp_player_cleanup(pid)
{
  if (_gxp_is_player_of_class(pid, g_id, g_props)) {
    discharge(pid);

    remove_task(tid_charge + pid);
    remove_task(tid_discharge + pid);
    remove_task(tid_block_velocity + pid);
  }
}

public gxp_player_spawned(pid)
{
  if (_gxp_is_player_of_class(pid, g_id, g_props)) {
    set_pev(pid, pev_gravity, g_props[cls_gravity]);
    gxp_user_set_model(pid, g_props);
  }
}

public gxp_player_used_ability(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  new Float:time = get_gametime();
  if (time - Float:gxp_get_player_data(pid, pd_ability_last_used) < g_props[cls_ability_cooldown])
    return;

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
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  new Float:time = get_gametime();
  if (
    time - Float:gxp_get_player_data(pid, pd_secn_ability_last_used) <
      g_props[cls_secn_ability_cooldown]
  ) {
    return;
  }

  if (g_charges[pid][charge_state] == cs_active)
    return;

  new Float:hp;
  new Float:max_hp = float(gxp_get_max_hp(pid));
  pev(pid, pev_health, hp);
  if (hp >= max_hp)
    return;

  recover_health(pid, hp, max_hp);

  uanim_send_weaponanim(pid, anim_wpn_seq_skill_reinforce, ANIM_DURATION_SKILL_REINFORCE);

  gxp_set_player_data(pid, pd_secn_ability_last_used, get_gametime());
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
  if (classname_idx == engfunc(EngFunc_AllocString, RECOVERY_CLASSNAME)) {
    static owner; owner = pev(ent, pev_owner);

    static Float:fuser3;
    pev(ent, pev_fuser3, fuser3);

    if (!is_user_alive(owner) || fuser3 <= get_gametime()) {
      set_pev(ent, pev_flags, FL_KILLME);
      return HAM_IGNORED;
    }

    static Float:origin[3];
    pev(owner, pev_origin, origin);
    origin[2] += 50.0;
    engfunc(EngFunc_SetOrigin, ent, origin);

    set_pev(ent, pev_nextthink, get_gametime() + 0.01);
  } else if (classname_idx == engfunc(EngFunc_AllocString, FLAME_CLASSNAME)) {
    static owner; owner = pev(ent, pev_owner);
    if (!is_user_connected(owner)) {
      set_pev(ent, pev_flags, FL_KILLME);
      return HAM_IGNORED;
    }

    static Float:fuser1;
    pev(ent, pev_fuser1, fuser1);

    if (fuser1 <= get_gametime() && pev(ent, pev_gravity) == -1.0)
      set_pev(ent, pev_gravity, 1.0);

    static Float:origin[3];
    pev(ent, pev_origin, origin);
    ufx_te_explosion(
      origin, g_spr_flame_effect, random_float(0.2, 0.5), 60,
      ufx_explosion_nosound | ufx_explosion_noparticles
    );

    set_pev(ent, pev_nextthink, get_gametime() + random_float(0.02, 0.03));
  }

  return HAM_IGNORED;
}

/* Forwards > Ham */

public ham_info_target_touch_pre(ent, touched_ent) {
  if (pev_valid(ent) != 2)
    return HAM_IGNORED;

  if (pev(ent, pev_classname) != engfunc(EngFunc_AllocString, FLAME_CLASSNAME))
    return HAM_IGNORED;

  new owner = pev(ent, pev_owner);
  if (touched_ent == owner)
    return HAM_SUPERCEDE;

  if (!is_user_connected(owner)) {
    set_pev(ent, pev_flags, FL_KILLME);
    return HAM_IGNORED;
  }

  static Float:origin[3];
  pev(ent, pev_origin, origin);

  new _ent = FM_NULLENT;
  while (
    (_ent = engfunc(EngFunc_FindEntityInSphere, _ent, origin, float(g_explosion_radius))) != 0
  ) {
    if (pev(_ent, pev_takedamage) == DAMAGE_NO)
      continue;

    if (is_user_alive(_ent) && GxpTeam:gxp_get_player_data(_ent, pd_team) == tm_zombie)
      continue;
    
    if (pev(_ent, pev_solid) == SOLID_BSP && (pev(_ent, pev_spawnflags) & SF_BREAK_TRIGGER_ONLY))
      continue;

    ExecuteHamB(Ham_TakeDamage, _ent, ent, owner, float(EXPLOSION_DMG), EXPLOSION_DMG_TYPE);

    if (is_user_alive(_ent)) {
      new Float:_origin[3];
      pev(_ent, pev_origin, _origin);
      ufx_te_bloodsprite(
        _origin,
        engfunc(EngFunc_PrecacheModel, "sprites/bloodspray.spr"),
        engfunc(EngFunc_PrecacheModel, "sprites/blood.spr"),
        ExecuteHamB(Ham_BloodColor, _ent),
        min(max(3, EXPLOSION_DMG / 10), 16)
      );

      set_pdata_int(_ent, UXO_LAST_HIT_GROUP, HIT_CHEST, UXO_LINUX_DIFF_MONSTER);
      set_pdata_float(_ent, UXO_FL_PAIN_SHOCK, 0.1, UXO_LINUX_DIFF_PLAYER);

      ufx_screenfade(_ent, 1.0, 1.0, ufx_ffade_in, {255, 69, 0, 100});
      ufx_screenshake(_ent, 16.0, 4.0, 4.0);
    }
  }

  ufx_te_explosion(origin, g_spr_explosion, 1.5, 25, ufx_explosion_nosound);

  new Float:axis[3];
  axis[0] = origin[0];
  axis[1] = origin[1];
  axis[2] = origin[2] + float(g_explosion_radius);

  origin[2] += 10.0;
  ufx_te_beamcylinder(
    origin, axis, g_spr_explosion_shockwave, 0, 0.0, 2.0, 2.0, 0.0, {255, 69, 0}, 255, 0.0
  );

  gxp_emit_sound(ent, "abilityexplode", g_id, g_props, CHAN_ITEM);

  set_pev(ent, pev_flags, FL_KILLME);

  return HAM_IGNORED;
}

public ham_traceattack_post(victim, attacker, Float:dmg, Float:dir[3], tr_handle)
{
  if (
    !is_user_alive(attacker)
    || !is_user_alive(victim)
    || GxpTeam:gxp_get_player_data(attacker, pd_team) == tm_zombie
    || !_gxp_is_player_of_class(victim, g_id, g_props)
  ) {
    return HAM_IGNORED;
  }

  if (g_charges[victim][charge_state] != cs_active)
    return HAM_IGNORED;

  set_pev(victim, pev_punchangle, { 0.0, 0.0, 0.0 });

  g_charges[victim][charge_accumulated_dmg] += floatround(dmg);

  static end_pos[3];
  get_tr2(tr_handle, TR_vecEndPos, end_pos);
  ufx_te_sparks(end_pos);

  if (g_charges[victim][charge_level] >= CHARGE_LEVELS - 1)
    return HAM_IGNORED;

  if (
    g_charges[victim][charge_accumulated_dmg] >=
      g_charge_lvl_dmg_map[g_charges[victim][charge_level]]
    && pev(victim, pev_weaponanim) < anim_wpn_seq_skill_guard5
  ) {
    if (++g_charges[victim][charge_level] == CHARGE_LEVELS - 1)
      chat_print(victim, g_prefix, "%L", victim, "GXP_CHAT_YAKSHA_ENERGY_REACHED");

    uanim_send_weaponanim(
      victim, anim_wpn_seq_skill_guard1 + g_charges[victim][charge_level], ANIM_DURATION_SKILL_GUARD
    );
  }

  return HAM_IGNORED;
}

public ham_item_preframe_post(pid)
{
  if (is_user_alive(pid) && _gxp_is_player_of_class(pid, g_id, g_props))
    set_pev(pid, pev_maxspeed, float(g_props[cls_speed]));
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
  discharge(pid);
  gxp_set_player_data(pid, pd_ability_last_used, get_gametime());
}

public task_block_velocity(tid)
{
  new pid = tid - tid_block_velocity;
  static Float:vel[3];
  pev(pid, pev_velocity, vel);
  vel[0] = vel[1] = 0.0;
  set_pev(pid, pev_velocity, vel);
}

/* Helpers */

shoot_energy_ball(pid)
{
  static str;
  new ball = engfunc(
    EngFunc_CreateNamedEntity, str ? str : (str = engfunc(EngFunc_AllocString, "info_target"))
  );

  new Float:velocity[3];
  velocity_by_aim(pid, 500, velocity);

  new Float:origin[3];
  new Float:angle[3];
  new Float:up[3];
  new Float:fwd[3];

  pev(pid, pev_origin, origin);
  pev(pid, pev_view_ofs, up);
  xs_vec_add(origin, up, origin);
  pev(pid, pev_angles, angle);

  angle_vector(angle, ANGLEVECTOR_FORWARD, fwd);
  angle_vector(angle, ANGLEVECTOR_UP, up);

  origin[0] = origin[0] + fwd[0] * 10.0 + up[0] * 15.0;
  origin[1] = origin[1] + fwd[1] * 10.0 + up[1] * 15.0;
  origin[2] = origin[2] + fwd[2] * 10.0 + up[2] * 15.0;

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

  engfunc(EngFunc_SetModel, ball, FLAME_SPRITE);
  engfunc(EngFunc_SetSize, ball, { -1.0, -1.0, -1.0 }, { 1.0, 1.0, 1.0 });
  engfunc(EngFunc_SetOrigin, ball, origin);

  set_pev(ball, pev_fuser1, get_gametime() + 0.3);
  set_pev(ball, pev_nextthink, get_gametime());
}

recover_health(pid, Float:hp, Float:max_hp)
{
  set_pev(pid, pev_health, floatclamp(hp + g_recovery_hp, 0.0, max_hp));

  static str;
  new spr = engfunc(
    EngFunc_CreateNamedEntity, str ? str : (str = engfunc(EngFunc_AllocString, "env_sprite"))
  );

  static Float:origin[3];
  pev(pid, pev_origin, origin);
  origin[2] += 50.0;

  set_pev(spr, pev_classname, RECOVERY_CLASSNAME);
  set_pev(spr, pev_owner, pid);
  set_pev(spr, pev_frame, 0.0);
  set_pev(spr, pev_framerate, 10.0);
  set_pev(spr, pev_animtime, get_gametime());
  set_pev(spr, pev_rendermode, kRenderTransAdd);
  set_pev(spr, pev_renderamt, 255.0);

  engfunc(EngFunc_SetModel, spr, RECOVERY_SPRITE);
  engfunc(EngFunc_SetOrigin, spr, origin);

  dllfunc(DLLFunc_Spawn, spr);

  set_pev(spr, pev_fuser3, get_gametime() + 19/10.0);
  set_pev(spr, pev_nextthink, get_gametime());

  ufx_screenfade(pid, 1.0, 1.0, ufx_ffade_in, {255, 69, 0, 50});

  gxp_emit_sound(pid, "abilityheal", g_id, g_props, CHAN_ITEM);
}

discharge(pid)
{
  fm_set_rendering(pid, kRenderFxNone);

  if (is_user_alive(pid) && g_charges[pid][charge_state] == cs_active) {
    uanim_send_weaponanim(pid, anim_wpn_seq_skill_to_idle, ANIM_DURATION_SKILL_TO_IDLE);
    uanim_play(pid, 3.0, 1.0, anim_seq_skill_idle);
  }

  g_charges[pid][charge_state]            = cs_none;
  g_charges[pid][charge_accumulated_dmg]  = 0;
  g_charges[pid][charge_level]            = 0;

  remove_task(pid + tid_block_velocity);
}

/* Callbacks */

public cb_gxp_is_available(pid, &bool:available)
{
  new total_players =
    get_playersnum_ex(GetPlayers_ExcludeHLTV | GetPlayers_MatchTeam, "TERRORIST")
    + get_playersnum_ex(GetPlayers_ExcludeHLTV | GetPlayers_MatchTeam, "CT");
  available = total_players >= 10;
}

