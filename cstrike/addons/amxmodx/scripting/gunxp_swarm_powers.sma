#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <fakemeta_util>
#include <engine>

#include <gunxp_swarm>
#include <gunxp_swarm_const>

#include <utils_effects>
#include <utils_text>
#include <utils_offsets>

#define BASE_GRAVITY 800.0

#define RETURN_IF_NOT_SURVIVOR(%0) \
  if (                                                      \
    GxpTeam:gxp_get_player_data(%0, pd_team) != tm_survivor \
    || gxp_get_player_data(%0, pd_class) == 0               \
  ) return
#define RETURN_X_IF_NOT_SURVIVOR(%0,%1) \
  if (                                                      \
    GxpTeam:gxp_get_player_data(%0, pd_team) != tm_survivor \
    || gxp_get_player_data(%0, pd_class) == 0               \
  ) return %1
#define RETURN_IF_NO_PWR(%0) if (%0 == 0) return
#define RETURN_X_IF_NO_PWR(%0,%1) if (%0 == 0) return %1

#define GET_POWER_LEVEL(%0,%1,%2) \
  new _powers[GxpPower];                        \
  gxp_get_player_data(%1, pd_powers, _powers);  \
  new %0 = _powers[%2]

#define PRS_THRESHOLD_REACHED(%0,%1) gxp_get_player_data(%0, pd_prs_used) > %1

enum _:TaskID (+= 1235)
{
  tid_respawn = 5911,
  tid_hp_regen,
  tid_he_regen,
  tid_sg_regen
};

new Float:g_vip_gravity;
new Float:g_freevip_gravity;

new Float:g_respawn_delay;
new Float:g_hp_regen_interval;

new Float:g_base_he_regen;
new Float:g_base_sg_regen;

new g_delta[GxpPower];

new g_prefix[_GXP_MAX_PREFIX_LENGTH + 1];

new g_spr_boom;

public plugin_natives()
{
  register_library("gxp_swarm_powers");

  register_native("gxp_power_get_delta", "native_get_delta");
  
  /* Maintained for backwards compatibility. */
  register_native("gxp_get_jump_bomb_bonus_dmg", "native_bc_get_jump_bomb_bonus_dmg");
  register_native("get_user_bonus_health", "native_bc_get_user_bonus_health");
}

public plugin_precache()
{
  g_spr_boom = precache_model("sprites/bexplo.spr");
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_POWERS_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);
 
  /* CVars */

  bind_pcvar_float(register_cvar("gxp_vip_gravity", "0.91"), g_vip_gravity);
  bind_pcvar_float(register_cvar("gxp_freevip_gravity", "0.94"), g_freevip_gravity);
  
  bind_pcvar_float(register_cvar("gxp_pwr_he_regen_base", "120.0"), g_base_he_regen);
  bind_pcvar_float(register_cvar("gxp_pwr_sg_regen_base", "120.0"), g_base_sg_regen);

  bind_pcvar_num(register_cvar("gxp_pwr_speed_delta",             "20"),  g_delta[pwr_speed]);
  bind_pcvar_num(register_cvar("gxp_pwr_respawn_chance_delta",    "10"),  g_delta[pwr_respawn_chance]);
  bind_pcvar_num(register_cvar("gxp_pwr_hp_delta",                "20"),  g_delta[pwr_base_hp]);
  bind_pcvar_num(register_cvar("gxp_pwr_gravity_delta",           "30"),  g_delta[pwr_gravity]);
  bind_pcvar_num(register_cvar("gxp_pwr_hp_regen_delta",          "1"),   g_delta[pwr_hp_regen]);
  bind_pcvar_num(register_cvar("gxp_pwr_bonus_xp_delta",          "100"), g_delta[pwr_bonus_xp]);
  bind_pcvar_num(register_cvar("gxp_pwr_expl_dmg_delta",          "300"), g_delta[pwr_expl_dmg]);
  bind_pcvar_num(register_cvar("gxp_pwr_he_regen_delta",          "12"),  g_delta[pwr_he_regen]);
  bind_pcvar_num(register_cvar("gxp_pwr_sg_regen_delta",          "12"),  g_delta[pwr_sg_regen]);
  bind_pcvar_num(register_cvar("gxp_pwr_fall_dmg_delta",          "20"),  g_delta[pwr_fall_dmg]);
  bind_pcvar_num(register_cvar("gxp_pwr_jump_bomb_chance_delta",  "10"),  g_delta[pwr_jump_bomb_chance]);
  bind_pcvar_num(register_cvar("gxp_pwr_jump_bomb_dmg_delta",     "5"),   g_delta[pwr_jump_bomb_dmg]);
  bind_pcvar_num(register_cvar("gxp_pwr_zm_add_health_delta",     "100"), g_delta[pwr_zm_add_health]);

  bind_pcvar_float(register_cvar("gxp_pwr_dmg_delta", "0.1"), Float:g_delta[pwr_damage]);
  bind_pcvar_float(
    register_cvar("gxp_pwr_shooting_interval_delta", "0.15"), Float:g_delta[pwr_shooting_interval]
  );

  bind_pcvar_float(register_cvar("gxp_pwr_hp_regen_interval", "1.0"), g_hp_regen_interval);

  /* Forwards > Ham */

  RegisterHam(Ham_TakeDamage, "player", "ham_player_takedamage_pre");
  RegisterHam(Ham_Item_PreFrame, "player", "ham_item_preframe_post", .Post = 1);
  RegisterHam(Ham_Killed, "player", "ham_killed_post", .Post = 1);

#define UTILITIES \
  ((1 << CSW_KNIFE) | (1 << CSW_HEGRENADE) | (1 << CSW_FLASHBANG) | (1 << CSW_SMOKEGRENADE))
  new wpn_name[32];
  for (new wid = CSW_P228; wid <= CSW_P90; ++wid) {
    if (UTILITIES & (1 << wid) || get_weaponname(wid, wpn_name, charsmax(wpn_name)) == 0)
      continue;
    RegisterHam(Ham_Weapon_PrimaryAttack, wpn_name, "ham_weapon_primaryattack_post", .Post = 1);
  }

  /* Events */

  register_event_ex(
    "CurWeapon", "event_curweapon", RegisterEvent_Single | RegisterEvent_OnlyAlive, "1=1"
  );
}

public plugin_cfg()
{
  bind_pcvar_string(get_cvar_pointer("gxp_info_prefix"), g_prefix, charsmax(g_prefix));
  fix_colors(g_prefix, charsmax(g_prefix));

  bind_pcvar_float(get_cvar_pointer("gxp_respawn_delay"), g_respawn_delay);
}

/* Natives */

public native_get_delta(plugin, argc)
{
  enum { param_power = 1 };
  return g_delta[get_param(param_power)];
}

/* Natives > Backwards compatibility */

public native_bc_get_jump_bomb_bonus_dmg(plugin, argc)
{
  enum { param_pid = 1 };
  GET_POWER_LEVEL(lvl, get_param(param_pid), pwr_jump_bomb_dmg);
  return g_delta[pwr_jump_bomb_dmg]*lvl;
}

public native_bc_get_user_bonus_health(plugin, argc)
{
  enum { param_pid = 1 };
  GET_POWER_LEVEL(lvl, get_param(param_pid), pwr_base_hp);
  return g_delta[pwr_base_hp]*lvl;
}

/* Forwards */

public grenade_throw(pid, nade_idx, wpn_id)
{
  if (!is_user_connected(pid) || GxpTeam:gxp_get_player_data(pid, pd_team) != tm_survivor)
    return;

  new pwrs[GxpPower];
  gxp_get_player_data(pid, pd_powers, _:pwrs);

  new lvl;
  new data[1];
  data[0] = wpn_id;
  if (wpn_id == CSW_HEGRENADE) {
    /* POWER:HE REGEN */
    lvl = pwrs[pwr_he_regen];
    if (lvl > 0) {
      remove_task(pid + tid_he_regen);
      set_task_ex(
        g_base_he_regen - float(g_delta[pwr_he_regen]*lvl),
        "task_nade_regen", pid + tid_he_regen, data, sizeof(data)
      );
    }
  } else if (wpn_id == CSW_SMOKEGRENADE) {
    /* POWER:SG REGEN */
    lvl = pwrs[pwr_sg_regen];
    if (lvl > 0) {
      remove_task(pid + tid_sg_regen);
      set_task_ex(
        g_base_sg_regen - float(g_delta[pwr_sg_regen]*lvl),
        "task_nade_regen", pid + tid_sg_regen, data, sizeof(data)
      );
    }
  }

}

/* Forwards > Internal */

public gxp_player_cleanup(pid)
{
  remove_tasks(pid);
}

public gxp_player_spawned(pid)
{
  new pwrs[GxpPower];
  new lvl;
  gxp_get_player_data(pid, pd_powers, _:pwrs);

  new GxpTeam:team = GxpTeam:gxp_get_player_data(pid, pd_team);
  if (team == tm_survivor) {
    /* POWER:HP REGEN */
    lvl = pwrs[pwr_hp_regen];
    if (lvl != 0) {
      set_task_ex(
        g_hp_regen_interval, "task_regen_hp", pid + tid_hp_regen, .flags = SetTask_Repeat
      );
    }

    /* POWER:SPEED */
    lvl = pwrs[pwr_speed];
    if (lvl != 0)
      set_max_speed(pid, lvl);

    /* POWER:GRAVITY */
    lvl = pwrs[pwr_gravity];
    if (lvl != 0) {
      set_gravity(pid, lvl);
    } else {
      if (gxp_is_vip(pid))
        set_pev(pid, pev_gravity, g_vip_gravity);
      else if (gxp_is_freevip(pid))
        set_pev(pid, pev_gravity, g_freevip_gravity);
    }
  } else if (team == tm_zombie) {
    /* POWER:ZM ADD HEALTH */
    /* Handled in `gunxp_swarm.sma`. */

    /* POWER:JUMP BOMB CHANCE */
    if (roll_dice(g_delta[pwr_jump_bomb_chance]*pwrs[pwr_jump_bomb_chance])) {
      jump_bomb_add(pid, 1);
      chat_print(pid, g_prefix, "%L", pid, "GXP_CHAT_RECEIVED_JUMP_BOMB");
    }
  }
}

/* Forwards > Ham */

public ham_player_takedamage_pre(pid_victim, id_inflictor, pid_attacker, Float:dmg, dmg_type)
{
  enum { param_dmg = 4 };

  if (is_user_connected(pid_victim) && (dmg_type & DMG_FALL)) {
    /* POWER:FALL DAMAGE */
    RETURN_X_IF_NOT_SURVIVOR(pid_victim, HAM_IGNORED);

    GET_POWER_LEVEL(lvl, pid_victim, pwr_fall_dmg);
    RETURN_X_IF_NO_PWR(lvl, HAM_IGNORED);

    SetHamParamFloat(param_dmg, dmg*(1.0 - float(g_delta[pwr_fall_dmg]*lvl)/100.0));
  } else if (is_user_connected(pid_attacker)) {
    /* POWER:DAMAGE */
    if (!gxp_has_game_started() || gxp_has_round_ended())
      return HAM_IGNORED;

    RETURN_X_IF_NOT_SURVIVOR(pid_attacker, HAM_IGNORED);

    GET_POWER_LEVEL(lvl, pid_attacker, pwr_damage);
    RETURN_X_IF_NO_PWR(lvl, HAM_IGNORED);

    new Float:base_dmg_mult = 1.0;
    if (PRS_THRESHOLD_REACHED(pid_attacker, 150))
      base_dmg_mult -= 0.25;
    SetHamParamFloat(param_dmg, dmg*(base_dmg_mult + Float:g_delta[pwr_damage]*lvl));
  }

  return HAM_IGNORED;
}

public ham_item_preframe_post(pid)
{
  RETURN_X_IF_NOT_SURVIVOR(pid, HAM_IGNORED);

  if (!is_user_alive(pid))
    return HAM_IGNORED;

  /* POWER:SPEED */
  GET_POWER_LEVEL(lvl, pid, pwr_speed);
  RETURN_X_IF_NO_PWR(lvl, HAM_IGNORED);
  set_max_speed(pid, lvl);

  return HAM_SUPERCEDE;
}

public ham_killed_post(pid_victim, pid_killer)
{
  RETURN_IF_NOT_SURVIVOR(pid_victim);

  new pwrs[GxpPower];
  gxp_get_player_data(pid_victim, pd_powers, _:pwrs);

  /* POWER:RESPAWN CHANCE */
  new lvl = pwrs[pwr_respawn_chance];
  if (lvl != 0 && !gxp_is_round_ending()) {
    if (roll_dice(
      g_delta[pwr_respawn_chance]*lvl,
      PRS_THRESHOLD_REACHED(pid_victim, 130) ? 0.6 : 0.0
    )) {
      set_task_ex(g_respawn_delay, "task_respawn", pid_victim + tid_respawn);
    }
  }

  /* POWER:EXPLOSION DAMAGE */
  lvl = pwrs[pwr_expl_dmg];
  if (lvl != 0) {
    new origin[3];
    get_user_origin(pid_victim, origin);
    ufx_te_explosion(origin, g_spr_boom, 6.0, 15, ufx_explosion_none);

    new players[MAX_PLAYERS + 1];
    new player_num = find_sphere_class(pid_victim, "player", 200.0, players, 32);
    for (new i = 0, pid; i != player_num; ++i) {
      pid = players[i];
      if (!is_user_alive(pid) || GxpTeam:gxp_get_player_data(pid, pd_team) != tm_zombie)
        continue;
      ExecuteHamB(
        Ham_TakeDamage, pid, 0, pid_victim, float(g_delta[pwr_expl_dmg]*lvl), DMG_GENERIC
      );
    }
  }
}

public ham_weapon_primaryattack_post(wpn)
{
  static pid;
  pid = get_pdata_cbase(wpn, UXO_P_PLAYER, UXO_LINUX_DIFF_ANIMATING);

  if (!is_user_connected(pid))
    return;

  /* POWER:SHOOTING INTERVAL */
  RETURN_IF_NOT_SURVIVOR(pid);

  GET_POWER_LEVEL(lvl, pid, pwr_shooting_interval);
  RETURN_IF_NO_PWR(lvl);

  new Float:next_pa = get_pdata_float(wpn, UXO_FL_NEXT_PRIMARY_ATTACK, UXO_LINUX_DIFF_ANIMATING);
  new Float:delta = Float:g_delta[pwr_shooting_interval];
  if (PRS_THRESHOLD_REACHED(pid, 130))
    delta -= 0.03;
  set_pdata_float(
    wpn, UXO_FL_NEXT_PRIMARY_ATTACK, next_pa - next_pa*delta*lvl/2, UXO_LINUX_DIFF_ANIMATING
  );
}

/* Events */

public event_curweapon(pid)
{
  RETURN_IF_NOT_SURVIVOR(pid);
  /* POWER:GRAVITY */
  GET_POWER_LEVEL(lvl, pid, pwr_gravity);
  if (lvl != 0)
    set_gravity(pid, lvl)
}

/* Tasks */

public task_respawn(tid)
{
  new pid = tid - tid_respawn;
  if (is_user_connected(pid) && !is_user_alive(pid)) {
    ExecuteHamB(Ham_CS_RoundRespawn, pid);
    gxp_set_player_data(pid, pd_respawn_count, gxp_get_player_data(pid, pd_respawn_count) + 1);
  }
}

public task_regen_hp(tid)
{
  new pid = tid - tid_hp_regen;
  if (
    !is_user_connected(pid)
    || !is_user_alive(pid)
    || GxpTeam:gxp_get_player_data(pid, pd_team) != tm_survivor
  ) {
    remove_task(tid);
    return;
  }

  new pwrs[GxpPower];
  gxp_get_player_data(pid, pd_powers, pwrs);

  new Float:max_hp = float(gxp_get_max_hp(pid));
  new Float:hp;
  pev(pid, pev_health, hp);
  if (hp < max_hp) {
    new Float:new_hp = hp + float(g_delta[pwr_hp_regen]*pwrs[pwr_hp_regen]);
    set_pev(pid, pev_health, new_hp > max_hp ? max_hp : new_hp);
  } else {
    TrieClear(Trie:gxp_get_player_data(pid, pd_kill_contributors));
  }
}

public task_nade_regen(const data[1], tid)
{
  if (data[0] == CSW_HEGRENADE) {
    fm_give_item(tid - tid_he_regen, "weapon_hegrenade");
  } else {
    fm_give_item(tid - tid_sg_regen, "weapon_smokegrenade");
  }
}

/* Helpers */

bool:roll_dice(chance, Float:mod = 0.0)
{
  return random(floatround(100*(mod + 1.0))) < chance;
}

set_max_speed(pid, lvl)
{
  /* POWER:SPEED */
  new class[GxpClass];
  gxp_get_player_class(pid, class);
  set_pev(
    pid,
    pev_maxspeed,
    float(class[cls_speed] + g_delta[pwr_speed]*lvl - (PRS_THRESHOLD_REACHED(pid, 130) ? 10 : 0))
  );
}

set_gravity(pid, lvl)
{
  /* POWER:GRAVITY */
  new class[GxpClass];
  gxp_get_player_class(pid, class);
  set_pev(
    pid,
    pev_gravity,
    (BASE_GRAVITY*class[cls_gravity] - float(g_delta[pwr_gravity]*lvl))/BASE_GRAVITY
  );
}

remove_tasks(pid)
{
  remove_task(pid + tid_respawn);
  remove_task(pid + tid_hp_regen);
  remove_task(pid + tid_he_regen);
  remove_task(pid + tid_sg_regen);
}