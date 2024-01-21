#if defined _GUNXP_SWARM_CONST_INC
  #endinput
#endif
#define _GUNXP_SWARM_CONST_INC

#include <amxmisc>
#include <amxconst>

#include "l4d.inl"

/* Common > Internal */

#define _GXP_PRIM_GUN_COUNT 18
#define _GXP_SECN_GUN_COUNT 6
#define _GXP_GUN_COUNT      _GXP_PRIM_GUN_COUNT + _GXP_SECN_GUN_COUNT

stock const _gxp_gun_names[_GXP_GUN_COUNT][] =
{
  "Glock 18C",
  "USP .45 ACP Tactical",
  "P228 Compact",
  "FiveseveN",
  "Desert Eagle .50 AE",
  "Dual Elite Berettas",
  "Schmidt TMP",
  "Ingram MAC-10",
  "UMP 45",
  "MP5 Navy",
  "ES P90",
  "Scout",
  "Famas",
  "IMI Galil",
  "M3 Super 90",
  "XM1014 M4",
  "AK-47",
  "M4A1 Carbine",
  "Steyr AUG A1",
  "SG-552 Commando",
  "SG-550 Auto-Sniper",
  "G3SG1 Auto-Sniper",
  "AWP Magnum Sniper",
  "M249 Para Machinegun"
};

stock const _gxp_internal_gun_names[_GXP_GUN_COUNT][] =
{
  "weapon_glock18",
  "weapon_usp",
  "weapon_p228",
  "weapon_fiveseven",
  "weapon_deagle",
  "weapon_elite",
  "weapon_tmp",
  "weapon_mac10",
  "weapon_ump45",
  "weapon_mp5navy",
  "weapon_p90",
  "weapon_scout",
  "weapon_famas",
  "weapon_galil",
  "weapon_m3",
  "weapon_xm1014",
  "weapon_ak47",
  "weapon_m4a1",
  "weapon_aug",
  "weapon_sg552",
  "weapon_sg550",
  "weapon_g3sg1",
  "weapon_awp",
  "weapon_m249"
};

stock const _gxp_weapon_ids[_GXP_GUN_COUNT] =
{
  CSW_GLOCK18,
  CSW_USP,
  CSW_P228,
  CSW_FIVESEVEN,
  CSW_DEAGLE,
  CSW_ELITE,
  CSW_TMP,
  CSW_MAC10,
  CSW_UMP45,
  CSW_MP5NAVY,
  CSW_P90,
  CSW_SCOUT,
  CSW_FAMAS,
  CSW_GALIL,
  CSW_M3,
  CSW_XM1014,
  CSW_AK47,
  CSW_M4A1,
  CSW_AUG,
  CSW_SG552,
  CSW_SG550,
  CSW_G3SG1,
  CSW_AWP,
  CSW_M249
};

stock const _gxp_bpammo[_GXP_GUN_COUNT] =
{
  400,  // glock18
  400,  // usp
  400,  // p228
  400,  // fiveseven
  400,  // deagle
  400,  // elite
  400,  // tmp
  400,  // mac10
  400,  // ump45
  400,  // mp5navy
  400,  // p90
  400,  // scout
  400,  // famas
  400,  // galil
  80,   // m3
  80,   // xm1014
  400,  // ak47
  400,  // m4a1
  400,  // aug
  400,  // sg552
  200,  // sg550
  200,  // g3sg1
  90,   // awp
  400   // m249
};

/* Common > Public */

#define GXP_MAX_LEVEL _GXP_GUN_COUNT

/* GXP:SWARM:POWERS */

/* Public */

enum _:GxpPower
{
  pwr_speed = 0,
  pwr_respawn_chance,
  pwr_base_hp,
  pwr_damage,
  pwr_gravity,
  pwr_hp_regen,
  pwr_bonus_xp,
  pwr_expl_dmg,
  pwr_he_regen,
  pwr_sg_regen,
  pwr_shooting_interval,
  pwr_death_xp,
  pwr_fall_dmg,
  pwr_jump_bomb_chance,
  pwr_jump_bomb_dmg,
  pwr_zm_add_health,
  pwr_vaccines,
  pwr_chosen_vaccines[MAXCLASS]
}

/* Internal */

#define _GXP_POWER_COUNT      GxpPower - MAXCLASS
#define _GXP_POWER_MAX_LEVEL  5

stock const _gxp_power_ml_names[_GXP_POWER_COUNT][] =
{
  "GXP_PWR_SPEED",
  "GXP_PWR_RESPAWN_CHANCE",
  "GXP_PWR_BASE_HP",
  "GXP_PWR_DAMAGE",
  "GXP_PWR_GRAVITY",
  "GXP_PWR_HP_REGEN",
  "GXP_PWR_BONUS_XP",
  "GXP_PWR_EXPLOSION_DAMAGE",
  "GXP_PWR_HE_REGEN",
  "GXP_PWR_SG_REGEN",
  "GXP_PWR_SHOOTING_INTERVAL",
  "GXP_PWR_DEATH_XP",
  "GXP_PWR_FALL_DMG",
  "GXP_PWR_JUMP_BOMB_CHANCE",
  "GXP_PWR_JUMP_BOMB_DMG",
  "GXP_PWR_ZM_ADD_HEALTH",
  "GXP_PWR_VACCINES"
};

/* GXP:SWARM:SQL */

#define GXP_SWARM_SQL_PLAYERS_TABLE "swarm_players"
#define GXP_SWARM_SQL_POWERS_TABLE  "swarm_powers"

/* GXP:SWARM:CONFIG */

/* Internal */

#define _GXP_SWARM_CONFIG_BASE_DIR      "gunxp_swarm"
#define _GXP_SWARM_CONFIG_CLASS         _GXP_SWARM_CONFIG_BASE_DIR + "/classes.ini"
#define _GXP_SWARM_CONFIG_CLASS_SOUNDS  _GXP_SWARM_CONFIG_BASE_DIR + "/classes-sounds.ini"
#define _GXP_SWARM_CONFIG_CLASS_MODELS  _GXP_SWARM_CONFIG_BASE_DIR + "/classes-models.ini"
#define _GXP_SWARM_CONFIG_SOUNDS        _GXP_SWARM_CONFIG_BASE_DIR + "/sounds.ini"
#define _GXP_SWARM_CONFIG_MODELS        _GXP_SWARM_CONFIG_BASE_DIR + "/models.ini"
#define _GXP_SWARM_CONFIG_CVARS         _GXP_SWARM_CONFIG_BASE_DIR + "/cvars.cfg"

/* Public */

#define GXP_MAX_SURVIVOR_CLASSES  10
#define GXP_MAX_ZOMBIE_CLASSES    90

#define GXP_MAX_CLASS_ID_LENGTH     MAX_NAME_LENGTH
#define GXP_MAX_CLASS_TITLE_LENGTH  MAX_NAME_LENGTH

#define GXP_SWARM_CONFIG_MAX_KEY_LENGTH   64
#define GXP_SWARM_CONFIG_MAX_PROP_LENGTH  PLATFORM_MAX_PATH

enum _:GxpClass
{
  cls_id[GXP_MAX_CLASS_ID_LENGTH + 1],
  cls_title[GXP_MAX_CLASS_TITLE_LENGTH + 1],
  GxpTeam:cls_team,
  cls_health,
  cls_armour,
  cls_speed,
  Float:cls_gravity,
  Float:cls_ability_cooldown,
  cls_xp_when_killed,
  bool:cls_default_sounds,
  Trie:cls_misc,
  Trie:cls_sounds,
  Trie:cls_models
};

/* GXP:SWARM:ULS */

#define GXP_SWARM_UL_MAX_TITLE_LENGTH       64
#define GXP_SWARM_UL_MAX_DESCRIPTION_LENGTH 64

#define GXP_SWARM_UL_MAX_ULS_PER_CLASS 25

enum _:GxpUlClass
{
  gxp_ul_cls_knife = 0,
  gxp_ul_cls_secondary,
  gxp_ul_cls_primary,
  gxp_ul_cls_nade,
  gxp_ul_cls_item
};

enum _:GxpUl
{
  gxp_ul_id,
  gxp_ul_plugin,
  GxpUlClass:gxp_ul_class,
  gxp_ul_title[GXP_SWARM_UL_MAX_TITLE_LENGTH + 1],
  gxp_ul_description[GXP_SWARM_UL_MAX_DESCRIPTION_LENGTH + 1],
  gxp_ul_cost,
  gxp_ul_level,
  gxp_ul_access,
  gxp_ul_weapon_id,
  bool:gxp_ul_newbie
};

/* GXP:SWARM:CORE */

/* Public */

enum GxpTeam
{
  tm_unclassified = 0,
  tm_survivor,
  tm_zombie
};

enum GxpRememberSelection
{
  gxp_remember_sel_off = 0,
  gxp_remember_sel_map,
  gxp_remember_sel_perm
};

enum GxpXpMethod
{
  gxp_xp_dmg = 0,
  gxp_xp_kill
};

enum _:GxpPrivileges
{
  gxp_priv_vip = 0,
  gxp_priv_admin,
  gxp_priv_sadmin
};

enum GxpPlayer
{
  GxpTeam:pd_team,
  pd_class,
  pd_kills,
  pd_hs,
  pd_deaths,
  pd_xp_curr,
  pd_xp_bought,
  pd_level,
  pd_prs_stored,
  pd_prs_used,
  pd_prs_bought,
  pd_primary_gun,
  pd_secondary_gun,
  GxpRememberSelection:pd_remember_sel,
  Float:pd_ability_last_used,
  pd_powers[GxpPower],
  Array:pd_uls[GxpUlClass],
  pd_respawn_count
};

/* Internal */

#define _GXP_MAX_LEVEL  _GXP_GUN_COUNT - 1
#define _GXP_MAX_XP     700000

stock const _gxp_xp_level_map[_GXP_MAX_LEVEL + 1] =
{
  0, // level 0 (base; unused)
  1000,
  3000,
  4500,
  8000,
  18000,
  31000,
  48000,
  67000,
  89000,
  116000,
  143000,
  176000,
  207000,
  240000,
  284000,
  323000,
  367000,
  412000,
  457000,
  503000,
  560000,
  610000,
  670000
};

stock const _gxp_access_map[GxpPrivileges] =
{
  ADMIN_CHAT,     // vip
  ADMIN_KICK,     // admin
  ADMIN_IMMUNITY  // s. admin
};

/* GXP:INFO */

/* Internal */

#define _GXP_MAX_PREFIX_LENGTH 16