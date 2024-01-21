#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <fakemeta_util>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

#include <utils_effects>
#include <utils_fakemeta>

#define SPIT_CLASSNAME "gxp_danger_spitter_spit"

new Float:g_spit_dmg;
new g_spit_speed;

new g_id;
new g_props[GxpClass];

new g_spr_xbeam;
new g_spr_bubble;
new g_mdl_spit[GXP_SWARM_CONFIG_MAX_PROP_LENGTH + 1];

public plugin_natives()
{
  register_library("gxp_swarm_core");

  /* Maintained for backwards compatibility. */
  register_native("swarm_renew_glow", "native_bc_swarm_renew_glow");
}

public plugin_precache()
{
  g_spr_xbeam = engfunc(EngFunc_PrecacheModel, "sprites/xbeam3.spr");
  g_spr_bubble = engfunc(EngFunc_PrecacheModel, "sprites/bubble.spr");
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_DANGER_SPITTER_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards > FakeMeta */

  register_forward(FM_Touch, "fm_touch_post", ._post = 1);

  /* Forwards > Ham */

  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);

  /* Setup */

  gxp_config_get_class("dangerspitter", g_props);

  TrieGetCell(g_props[cls_misc], "spit_damage", g_spit_dmg);
  TrieGetCell(g_props[cls_misc], "spit_speed", g_spit_speed);

  g_id = gxp_register_class("dangerspitter", tm_zombie);

  copy(g_mdl_spit, charsmax(g_mdl_spit), "models/");
  TrieGetString(
    g_props[cls_models], "spit",
    g_mdl_spit[strlen(g_mdl_spit)], charsmax(g_mdl_spit) + strlen(g_mdl_spit)
  );
}

/* Natives > Backwards compatibility */

public native_bc_swarm_renew_glow(plugin, argc)
{
  enum { param_pid = 1 };
  new pid = get_param(param_pid);
  if (_gxp_is_player_of_class(pid, g_id, g_props))
    fm_set_user_rendering(pid, kRenderFxGlowShell, 255, 0, 0);
}

/* Forwards > GunXP > Player */

public gxp_cleanup()
{
  ufm_remove_entities(SPIT_CLASSNAME);
}

public gxp_player_spawned(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  set_pev(pid, pev_gravity, g_props[cls_gravity]);
  
  gxp_user_set_model(pid, g_props);
  fm_set_user_rendering(pid, kRenderFxGlowShell, 255, 0, 0);
}

public gxp_player_used_ability(pid)
{
  if (!_gxp_is_player_of_class(pid, g_id, g_props))
    return;

  new Float:time = get_gametime();
  if (time - Float:gxp_get_player_data(pid, pd_ability_last_used) < g_props[cls_ability_cooldown])
    return;

  new Float:origin[3];
  new Float:vel[3];
  new Float:angle[3];

  pev(pid, pev_origin, origin);
  pev(pid, pev_v_angle, angle);

  new spit = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
  set_pev(spit, pev_classname, SPIT_CLASSNAME);
  engfunc(EngFunc_SetModel, spit, g_mdl_spit);
  engfunc(EngFunc_SetSize, spit, Float:{-1.5, -1.5, -1.5}, Float:{1.5, 1.5, 1.5});
  set_pev(spit, pev_origin, origin);
  set_pev(spit, pev_angles, angle);
  set_pev(spit, pev_solid, SOLID_BBOX);
  set_pev(spit, pev_movetype, MOVETYPE_TOSS);
  set_pev(spit, pev_gravity, 0.5);
  set_pev(spit, pev_rendermode, 5);
  set_pev(spit, pev_renderamt, 200.0);
  set_pev(spit, pev_scale, 1.0);
  set_pev(spit, pev_owner, pid);
  velocity_by_aim(pid, g_spit_speed, vel);
  set_pev(spit, pev_velocity, vel);

  ufx_te_beamfollow(spit, g_spr_xbeam, 0.1, 0.3, {0, 250, 0}, 200);

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

public fm_touch_post(ent_touched, ent_other)
{
  if ((ent_touched != 0 && !pev_valid(ent_touched)) || !pev_valid(ent_other))
    return;

  static touched_class[31 + 1];
  static other_class[31 + 1];

  pev(ent_touched, pev_classname, touched_class, charsmax(touched_class));
  pev(ent_other, pev_classname, other_class, charsmax(other_class));

  if (equal(other_class, SPIT_CLASSNAME)) {
    if (equal(touched_class, "func_breakable") && pev(ent_touched, pev_solid) != SOLID_NOT) {
      splatter_spit(ent_other);
      dllfunc(DLLFunc_Use, ent_touched, ent_other);
      return;
    } else if (ent_touched == 0) {
      splatter_spit(ent_other);
      return;
    }
  }

  if (ent_other < 1 || ent_other > MAX_PLAYERS)
    return;

  if (!equal(touched_class, SPIT_CLASSNAME))
    return;

  if (GxpTeam:gxp_get_player_data(ent_other, pd_team) == tm_zombie || !is_user_alive(ent_other))
    return;

  splatter_spit(ent_touched);
  ExecuteHamB(Ham_TakeDamage, ent_other, 0, pev(ent_touched, pev_owner), g_spit_dmg, DMG_BULLET);
  gxp_emit_sound(ent_other, "aciddeath", g_id, g_props);
}

/* Forwards > Ham */

public ham_item_preframe_post(pid)
{
  if (is_user_alive(pid) && _gxp_is_player_of_class(pid, g_id, g_props))
    set_pev(pid, pev_maxspeed, float(g_props[cls_speed]));
}

/* Helpers */

splatter_spit(ent)
{
  static Float:f_origin[3];
  pev(ent, pev_origin, f_origin);

  static i_origin[3];
  i_origin[0] = floatround(f_origin[0]);
  i_origin[1] = floatround(f_origin[1]);
  i_origin[2] = floatround(f_origin[2]);

  static velocity[3];
  velocity[0] = random_num(-50, 50);
  velocity[1] = random_num(-50, 50);
  velocity[2] = 25;

  ufx_te_break_model(
    i_origin, {16, 16, 16}, velocity, 1, g_spr_bubble, 10, 3.8, ufx_break_model_trans
  );

  gxp_emit_sound(ent, "spithit", g_id, g_props);

  ufm_remove_entity(ent);
}