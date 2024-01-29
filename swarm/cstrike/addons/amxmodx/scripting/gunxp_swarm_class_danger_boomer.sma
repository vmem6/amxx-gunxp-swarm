/*
 * TODO:
 *   - make explosion deal damage rather than directly kill survivors within
 *     certain radius.
 */

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <fakemeta_util>
#include <xs>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_stocks>
#include <gunxp_swarm_const>

#include <utils_effects>

new g_vomit_max_dist;
new Float:g_vomit_dmg;
new g_expl_kill_radius;

new g_id;
new g_props[GxpClass];

new g_spr_poison;
new g_spr_steam;
new g_spr_dexplo;
new g_spr_white;

public plugin_precache()
{
  g_spr_poison  = engfunc(EngFunc_PrecacheModel, "sprites/poison.spr");
  g_spr_steam   = engfunc(EngFunc_PrecacheModel, "sprites/steam1.spr");
  g_spr_dexplo  = engfunc(EngFunc_PrecacheModel, "sprites/dexplo.spr");
  g_spr_white   = engfunc(EngFunc_PrecacheModel, "sprites/white.spr");
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_DANGER_BOOMER_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards > Ham */

  RegisterHam(Ham_Killed, "player", "ham_killed_post", .Post = 1);
  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);

  /* Setup */

  gxp_config_get_class("dangerboomer", g_props);

  TrieGetCell(g_props[cls_misc], "vomit_max_dist", g_vomit_max_dist);
  TrieGetCell(g_props[cls_misc], "vomit_damage", g_vomit_dmg);
  TrieGetCell(g_props[cls_misc], "explosion_kill_radius", g_expl_kill_radius);

  g_id = gxp_register_class("dangerboomer", tm_zombie);
}

/* Forwards > GunXP > Player */

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

  new eye_pos[3];
  new aim_pos[3];
  get_user_origin(pid, eye_pos, 1);
  get_user_origin(pid, aim_pos, 3);

  new Float:aim_dist[3];
  aim_dist[0] = float(aim_pos[0] - eye_pos[0]);
  aim_dist[1] = float(aim_pos[1] - eye_pos[1]);
  aim_dist[2] = float(aim_pos[2] - eye_pos[2]);

  /* Make vomit traverse distance to hit point in 1 s/0.003 ~= 285.71 s. */
  new Float:vel[3];
  xs_vec_mul_scalar(aim_dist, 0.0035, vel);

  eye_pos[2] -= 2;
  ufx_te_spray(eye_pos, vel, g_spr_poison, 8, 70, 100, 5);

  new target;
  get_user_aiming(pid, target, .dist = g_vomit_max_dist);
  if (
    target >= 1 && target <= MAX_PLAYERS
    && GxpTeam:gxp_get_player_data(target, pd_team) == tm_survivor
  ) {
    ExecuteHamB(Ham_TakeDamage, target, pid, pid, g_vomit_dmg, DMG_BULLET);
  }

  gxp_emit_sound(pid, "ability", g_id, g_props);

  gxp_set_player_data(pid, pd_ability_last_used, time);
}

public gxp_player_knife_slashed(pid)  { gxp_emit_sound(pid, "miss", g_id, g_props, CHAN_WEAPON); }
public gxp_player_knife_hitwall(pid)  { gxp_emit_sound(pid, "miss", g_id, g_props, CHAN_WEAPON); }
public gxp_player_knife_hit(pid)      { gxp_emit_sound(pid, "hit",  g_id, g_props, CHAN_WEAPON); }
public gxp_player_knife_stabbed(pid)  { gxp_emit_sound(pid, "hit",  g_id, g_props, CHAN_WEAPON); }

public gxp_player_suffer(pid) { gxp_emit_sound(pid, "pain",  g_id, g_props, CHAN_VOICE); }
public gxp_player_died(pid)
{
  gxp_emit_sound(pid, "death", g_id, g_props, CHAN_VOICE);
  gxp_emit_sound(pid, "explode", g_id, g_props, CHAN_BODY);
}

/* Forwards > Ham */

public ham_killed_post(victim, killer)
{
  if (!_gxp_is_player_of_class(victim, g_id, g_props))
    return HAM_IGNORED;

  new origin[3];
  get_user_origin(victim, origin);

  ufx_te_smoke(origin, g_spr_steam, random_float(8.0, 15.0), random_num(5, 10));
  ufx_te_gunshotdecal(origin, random_num(46, 48));
  ufx_te_explosion(origin, g_spr_dexplo, 3.2, 20, ufx_explosion_none);

  new axis[3];
  axis[1] = origin[1] + 200;
  axis[2] = origin[2] + 200;
  ufx_te_beamcylinder(origin, axis, g_spr_white, 0, 0.0, 1.0, 1.0, 25.5, {0, 255, 0}, 128, 0.5)

  fm_set_user_rendering(victim, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 0);

  new splash_org[3];
  splash_org[0] = origin[0];
  splash_org[1] = origin[1];
  splash_org[2] = origin[2] - 26;
  ufx_te_lavasplash(splash_org);

  new players[MAX_PLAYERS];
  new pnum;
  get_players_ex(players, pnum, GetPlayers_ExcludeDead | GetPlayers_ExcludeHLTV);

  new pos[3];
  for (new i = 0; i != pnum; ++i) {
    new pid = players[i];
    if (GxpTeam:gxp_get_player_data(pid, pd_team) == tm_survivor) {
      get_user_origin(pid, pos);
      if (get_distance(pos, origin) <= g_expl_kill_radius)
        ExecuteHamB(Ham_Killed, pid, victim, 0);
    }
  }

  return HAM_HANDLED;
}

public ham_item_preframe_post(pid)
{
  if (is_user_alive(pid) && _gxp_is_player_of_class(pid, g_id, g_props)) {
    set_pev(pid, pev_maxspeed, float(g_props[cls_speed]));
    return HAM_SUPERCEDE;
  }
  return HAM_IGNORED;
}
