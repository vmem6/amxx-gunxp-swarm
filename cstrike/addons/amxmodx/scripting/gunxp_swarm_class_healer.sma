#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

#include <utils_effects>

#define CAM_CLASSNAME "gxp_healer_cam"

enum (+= 1000)
{
  tid_heal = 7834,
  tid_heal_effects,
  tid_create_cam
};

new g_id;

new g_heal_time;

new g_props[GxpClass];

new g_spr_heal;
new g_cams[MAX_PLAYERS + 1];

public plugin_precache()
{
  /* TODO: move out to INI. */
  g_spr_heal = engfunc(EngFunc_PrecacheModel, "sprites/jailas_swarm/heal.spr");
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_HEALER_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards > Ham */

  RegisterHam(Ham_TakeDamage, "player", "ham_takedamage_pre");
  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);

  /* Setup */

  gxp_config_get_class("healer", g_props);

  TrieGetCell(g_props[cls_misc], "heal_time", g_heal_time);
  if (g_heal_time < 1) {
    g_heal_time = 1;
  }

  g_id = gxp_register_class("healer", tm_zombie);
}

/* Forwards > GunXP > Player */

public gxp_player_cleanup(pid)
{
  if (_gxp_is_player_of_class(pid, g_id, g_props)) {
    ufx_bartime(pid, 0);

    remove_cam(pid);

    remove_task(tid_heal + pid);
    remove_task(tid_heal_effects + pid);    

    set_pev(pid, pev_flags, pev(pid, pev_flags) & ~FL_FROZEN);
  }
}

public gxp_player_spawned(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  gxp_set_player_data(pid, pd_ability_available, false);
  set_pev(pid, pev_gravity, g_props[cls_gravity]);
  gxp_user_set_model(pid, g_props);
}

public gxp_player_used_ability(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  new Float:time = get_gametime();
  if (time - Float:gxp_get_player_data(pid, pd_ability_last_used) < g_props[cls_ability_cooldown])
    return;

  new Float:health;
  pev(pid, pev_health, health);
  if (health >= float(gxp_get_max_hp(pid)))
    return;

  ufx_bartime(pid, g_heal_time);

  set_pev(pid, pev_flags, pev(pid, pev_flags) | FL_FROZEN & ~FL_DUCKING);
  set_pev(pid, pev_button, pev(pid, pev_button) & ~IN_DUCK);

  set_task_ex(0.1, "task_create_cam", tid_create_cam + pid);
  set_task_ex(0.7, "task_heal_effects", tid_heal_effects + pid);
  set_task_ex(float(g_heal_time), "task_heal", tid_heal + pid);

  gxp_set_player_data(pid, pd_ability_last_used, time);
  gxp_set_player_data(pid, pd_ability_in_use, true);
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
  if (_gxp_is_player_of_class(victim, g_id, g_props) && dmg > 0.0)
    gxp_set_player_data(victim, pd_ability_available, true);
  return HAM_IGNORED;
}

public ham_item_preframe_post(pid)
{
  if (is_user_alive(pid) && _gxp_is_player_of_class(pid, g_id, g_props))
    set_pev(pid, pev_maxspeed, float(g_props[cls_speed]));
}

/* Tasks */

public task_create_cam(tid)
{
  new pid = tid - tid_create_cam;

  new cam = g_cams[pid] = engfunc(
    EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target")
  );
  if (!cam)
    return;

  /* Set up base properties. */
  set_pev(cam, pev_classname, CAM_CLASSNAME);
  engfunc(EngFunc_SetModel, cam, "models/w_usp.mdl");
  set_pev(cam, pev_solid, SOLID_TRIGGER);
  set_pev(cam, pev_movetype, MOVETYPE_FLYMISSILE);
  set_pev(cam, pev_rendermode, kRenderTransTexture);
  set_pev(cam, pev_renderamt, 0.0);

  /* Fix view on back of player. */

  new Float:trace_beg[3]; 
  new Float:trace_end[3];
  pev(pid, pev_origin, trace_beg);
  pev(pid, pev_origin, trace_end);

  /* Fetch origin 150.0 units back of player, or that which is nearest to
   * 150.0 u but doesn't intersect a brush. */
  new Float:angle[3];
  pev(pid, pev_v_angle, angle);

  new Float:fwd[3]; 
  angle_vector(angle, ANGLEVECTOR_FORWARD, fwd);

  trace_end[0] += -fwd[0]*150.0;
  trace_end[1] += -fwd[1]*150.0;
  trace_end[2] += -fwd[2]*150.0 + 20.0;

  new tr = create_tr2();
  engfunc(EngFunc_TraceLine, trace_beg, trace_end, IGNORE_GLASS, 0, tr);
  get_tr2(tr, TR_vecEndPos, trace_end);
  free_tr2(tr);

  /* Move cam into position. */
  set_pev(cam, pev_origin, trace_end);
  set_pev(cam, pev_angles, angle);

  /* Attach players' view to cam. */
  engfunc(EngFunc_SetView, pid, cam);
}

public task_heal_effects(tid)
{
  new pid = tid - tid_heal_effects;
  if (is_user_connected(pid) && _gxp_is_player_of_class(pid, g_id, g_props)) {
    new origin[3];
    get_user_origin(pid, origin);
    ufx_te_sprite(origin, g_spr_heal, 0.8, 255);
  }
}

public task_heal(tid)
{
  new pid = tid - tid_heal;
  if (is_user_connected(pid) && _gxp_is_player_of_class(pid, g_id, g_props)) {
    remove_cam(pid);

    set_pev(pid, pev_health, float(gxp_get_max_hp(pid)));
    set_pev(pid, pev_flags, pev(pid, pev_flags) & ~FL_FROZEN);

    gxp_set_player_data(pid, pd_ability_available, false);
    gxp_set_player_data(pid, pd_ability_in_use, false);

    TrieClear(Trie:gxp_get_player_data(pid, pd_kill_contributors));
  }
}

/* Helpers */

remove_cam(pid)
{
  new eid = g_cams[pid];
  if (pev_valid(eid)) {
    engfunc(EngFunc_SetView, pid, pid);

    set_pev(eid, pev_flags, FL_KILLME);
    dllfunc(DLLFunc_Think, eid);
    g_cams[pid] = 0;
  }
}