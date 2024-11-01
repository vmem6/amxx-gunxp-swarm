#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

#include <utils_effects>
#include <utils_fakemeta>

#define SPIT_CLASSNAME "gxp_spitter_spit"

new Float:g_spit_dmg;
new g_spit_speed;

new g_id;
new g_props[GxpClass];

new g_spr_white;
new g_mdl_spit[GXP_SWARM_CONFIG_MAX_PROP_LENGTH + 1];

public plugin_precache()
{
  g_spr_white = engfunc(EngFunc_PrecacheModel, "sprites/white.spr");
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_SPITTER_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards > FakeMeta */

  register_forward(FM_Touch, "fm_touch_post", ._post = 1);

  /* Forwards > Ham */

  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);

  /* Setup */

  gxp_config_get_class("spitter", g_props);

  TrieGetCell(g_props[cls_misc], "spit_damage", g_spit_dmg);
  TrieGetCell(g_props[cls_misc], "spit_speed", g_spit_speed);

  g_id = gxp_register_class("spitter", tm_zombie);

  copy(g_mdl_spit, charsmax(g_mdl_spit), "models/");
  TrieGetString(
    g_props[cls_models], "spit",
    g_mdl_spit[strlen(g_mdl_spit)], charsmax(g_mdl_spit) + strlen(g_mdl_spit)
  );
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
  set_pev(spit, pev_solid, SOLID_TRIGGER);
  set_pev(spit, pev_movetype, MOVETYPE_TOSS);
  set_pev(spit, pev_gravity, 0.5);
  set_pev(spit, pev_rendermode, 5);
  set_pev(spit, pev_renderamt, 10.0);
  set_pev(spit, pev_scale, 0.5);
  set_pev(spit, pev_owner, pid);
  velocity_by_aim(pid, g_spit_speed, vel);
  set_pev(spit, pev_velocity, vel);

  ufx_te_beamfollow(spit, g_spr_white, 0.1, 0.3, {0, 250, 0}, 200);

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

public fm_touch_post(ent, pid)
{
  new classname[31 + 1];

  if (!pev_valid(ent) || !pev_valid(pid))
    return;

  pev(ent, pev_classname, classname, charsmax(classname));
  if (!equal(classname, SPIT_CLASSNAME))
    return;

  pev(pid, pev_classname, classname, charsmax(classname));
  if (!equal(classname, "player"))
    return;

  if (GxpTeam:gxp_get_player_data(pid, pd_team) == tm_zombie || !is_user_alive(pid))
    return;

  static const decalnum[4] = { 7, 8, 26, 27 };

  new Float:origin[3];
  pev(ent, pev_origin, origin);
  origin[0] = random_float(0.0, 5.0);
  origin[1] = random_float(0.0, 5.0);
  origin[2] = random_float(0.0, 5.0);
  ufx_te_splash(origin, decalnum[random(sizeof decalnum)]);

  ExecuteHamB(Ham_TakeDamage, pid, 0, pev(ent, pev_owner), g_spit_dmg, DMG_BULLET);

  gxp_emit_sound(pid, "spithit", g_id, g_props);
  gxp_emit_sound(pid, "aciddeath", g_id, g_props);

  ufm_remove_entity(ent);
}

/* Forwards > Ham */

public ham_item_preframe_post(pid)
{
  if (is_user_alive(pid) && _gxp_is_player_of_class(pid, g_id, g_props)) {
    set_pev(pid, pev_maxspeed, float(g_props[cls_speed]));
    return HAM_SUPERCEDE;
  }
  return HAM_IGNORED;
}