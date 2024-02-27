#if defined _GUNXP_SWARM_CONST_INC
  #endinput
#endif
#define _GUNXP_SWARM_CONST_INC

#include <amxmisc>
#include <amxconst>

/* Common > Internal > Definitions */

#define _GXP_MAX_CLASS_NUM 18

#define _GXP_PRIM_GUN_COUNT 18
#define _GXP_SECN_GUN_COUNT 6
#define _GXP_GUN_COUNT      _GXP_PRIM_GUN_COUNT + _GXP_SECN_GUN_COUNT

/* Common > Internal > Enums */

enum _:GxpAmmoType
{
  gxp_ammo_357sig = 0,
  gxp_ammo_762nato,
  gxp_ammo_buckshot,
  gxp_ammo_45acp,
  gxp_ammo_556nato,
  gxp_ammo_9mm,
  gxp_ammo_57mm,
  gxp_ammo_338magnum,
  gxp_ammo_556natobox,
  gxp_ammo_50ae
};

/* Common > Internal > Other */

/* TODO: this should eventually be rethought. */

/* Ordered by level (0 - 23). */
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

/* Ordered by level (0 - 23). */
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

/* Ordered by level (0 - 23). */
stock const _gxp_gun_models[_GXP_GUN_COUNT][] =
{
  "models/w_glock18.mdl",
  "models/w_usp.mdl",
  "models/w_p228.mdl",
  "models/w_fiveseven.mdl",
  "models/w_deagle.mdl",
  "models/w_elite.mdl",
  "models/w_tmp.mdl",
  "models/w_mac10.mdl",
  "models/w_ump45.mdl",
  "models/w_mp5.mdl",
  "models/w_p90.mdl",
  "models/w_scout.mdl",
  "models/w_famas.mdl",
  "models/w_galil.mdl",
  "models/w_m3.mdl",
  "models/w_xm1014.mdl",
  "models/w_ak47.mdl",
  "models/w_m4a1.mdl",
  "models/w_aug.mdl",
  "models/w_sg552.mdl",
  "models/w_sg550.mdl",
  "models/w_g3sg1.mdl",
  "models/w_awp.mdl",
  "models/w_m249.mdl"
};

/* Ordered by level (0 - 23). */
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

/* Ordered by level (0 - 23). */
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

stock const Float:_gxp_ammo_kb_powers[] =
{
  0.5, // 357sig
  1.5, // 762nato
  4.5, // buckshot
  0.5, // 45acp
  0.5, // 556nato
  0.5, // 9mm
  0.5, // 57mm
  6.5, // 338magnum
  0.8, // 556natobox
  0.8  // 50ae
};

/* Mapped to internal CS weapon IDs. */
stock const _gxp_wpn_ammo_types[] =
{
  -1,                   // unused
  gxp_ammo_357sig,      // p228
  -1,                   // unused (glock; see glock18)
  gxp_ammo_762nato,     // scout
  -1,                   // unused (he grenade)
  gxp_ammo_buckshot,    // xm1014
  -1,                   // unused (c4)
  gxp_ammo_45acp,       // mac10
  gxp_ammo_556nato,     // aug
  -1,                   // unused (smoke grenade)
  gxp_ammo_9mm,         // elite
  gxp_ammo_57mm,        // fiveseven
  gxp_ammo_45acp,       // ump45
  gxp_ammo_556nato,     // sg550
  gxp_ammo_556nato,     // galil
  gxp_ammo_556nato,     // famas
  gxp_ammo_45acp,       // usp
  gxp_ammo_9mm,         // glock18
  gxp_ammo_338magnum,   // awp
  gxp_ammo_9mm,         // mp5navy
  gxp_ammo_556natobox,  // m249
  gxp_ammo_buckshot,    // m3
  gxp_ammo_556nato,     // m4a1
  gxp_ammo_9mm,         // tmp
  gxp_ammo_762nato,     // g3sg1
  -1,                   // unused (flashbang)
  gxp_ammo_50ae,        // deagle
  gxp_ammo_556nato,     // sg552
  gxp_ammo_762nato,     // ak47
  -1,                   // unused (knife)
  gxp_ammo_57mm         // p90
};

/* Mapped to internal CS weapon IDs. */
stock const _gxp_wpn_default_clip[] =
{
  0,    // unused
  13,   // p228
  0,    // unused (glock; see glock18)
  10,   // scout
  0,    // he grenade
  7,    // xm1014
  0,    // unused (c4)
  30,   // mac10
  30,   // aug
  0,    // smoke grenade
  30,   // elite
  20,   // fiveseven
  25,   // ump45
  30,   // sg550
  35,   // galil
  25,   // famas
  12,   // usp
  20,   // glock18
  10,   // awp
  30,   // mp5navy
  100,  // m249
  8,    // m3
  30,   // m4a1
  30,   // tmp
  20,   // g3sg1
  0,    // unused (flashbang)
  7,    // deagle
  30,   // sg552
  30,   // ak47
  0,    // unused (knife)
  50    // p90
};

/* Mapped to internal CS weapon IDs. */
stock const _gxp_wpn_default_bpammo[] =
{
  0,    // unused
  52,   // p228
  0,    // unused (glock; see glock18)
  90,   // scout
  1,    // he grenade
  32,   // xm1014
  0,    // unused (c4)
  100,  // mac10
  90,   // aug
  1,    // smoke grenade
  120,  // elite
  100,  // fiveseven
  100,  // ump45
  90,   // sg550
  90,   // galil
  90,   // famas
  100,  // usp
  120,  // glock18
  30,   // awp
  120,  // mp5navy
  200,  // m249
  32,   // m3
  90,   // m4a1
  120,  // tmp
  90,   // g3sg1
  1,    // unused (flashbang)
  35,   // deagle
  90,   // sg552
  90,   // ak47
  0,    // unused (knife)
  100   // p90
};

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
  pwr_fall_dmg,
  pwr_jump_bomb_chance,
  pwr_jump_bomb_dmg,
  pwr_zm_add_health,
  pwr_vaccines,
  pwr_chosen_vaccines[_GXP_MAX_CLASS_NUM]
};

/* Internal */

#define GXP_MAX_CALLBACK_LENGTH 64

/* Internal */

#define _GXP_POWER_COUNT      GxpPower - _GXP_MAX_CLASS_NUM
#define _GXP_POWER_MAX_LEVEL  5

stock const _gxp_power_prices[_GXP_POWER_COUNT] = { 1, 3, 6, 12, 25 };

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
  "GXP_PWR_FALL_DMG",
  "GXP_PWR_JUMP_BOMB_CHANCE",
  "GXP_PWR_JUMP_BOMB_DMG",
  "GXP_PWR_ZM_ADD_HEALTH",
  "GXP_PWR_VACCINES"
};

stock const _gxp_power_units[_GXP_POWER_COUNT - 1][] =
{
  "u/s",    // speed
  "%",      // respawn chance
  "hp",     // base hp
  "×",      // damage
  "g",      // gravity
  "hp/s",   // hp regen
  "xp",     // bonus xp
  "dmg",    // explosion damage
  "s",      // he regen
  "s",      // sg regen
  "s",      // shooting interval
  "%",      // fall dmg
  "%",      // jump bomb chance
  "dmg",    // jump bomb dmg
  "hp"      // zm add health
};

stock const _gxp_power_sign[_GXP_POWER_COUNT - 1][] =
{
  "+",  // speed
  "",   // respawn chance
  "+",  // base hp
  "",   // damage
  "-",  // gravity
  "",   // hp regen
  "",   // bonus xp
  "",   // explosion damage
  "",   // he regen
  "",   // sg regen
  "-",  // shooting interval
  "-",  // fall dmg
  "",   // jump bomb chance
  "",   // jump bomb dmg
  "+"   // zm add health
};

/* GXP:SWARM:SQL */

#define _GXP_SWARM_SQL_PLAYERS_TABLE  "swarm_players"
#define _GXP_SWARM_SQL_POWERS_TABLE   "swarm_powers"
#define _GXP_SWARM_SQL_STATS_TABLE    "swarm"

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
  bool:cls_midair_ability,
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

/* GXP:SWARM:STATS */

enum _:GxpPlayerStats
{
  gxp_pstats_kills,
  gxp_pstats_assists,
  Float:gxp_pstats_weighted_kills,
  gxp_pstats_deaths,
  gxp_pstats_hs,
  gxp_pstats_suicides,
  gxp_pstats_survivals,
  gxp_pstats_playtime,
  gxp_pstats_playtime_ct,
  gxp_pstats_aggro_time
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
  gxp_priv_freevip = 0,
  gxp_priv_vip,
  gxp_priv_admin,
  gxp_priv_sadmin
};

enum _:GxpKillContributor
{
  gxp_kc_pid = 0,
  Float:gxp_kc_dmg
};

enum GxpPlayer
{
  GxpTeam:pd_team,
  pd_class,
  pd_xp_curr,
  pd_xp_bought,
  pd_level,
  pd_prs_stored,
  pd_prs_used,
  pd_prs_bought,
  pd_primary_gun,
  pd_secondary_gun,
  pd_respawn_count,
  GxpRememberSelection:pd_remember_sel,
  Float:pd_ability_last_used,
  bool:pd_ability_available,
  bool:pd_ability_in_use,
  pd_powers[GxpPower],
  Array:pd_uls[GxpUlClass],
  pd_stats[GxpPlayerStats],
  pd_round_kills,
  Trie:pd_kill_contributors,
  Float:pd_skill
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
  ADMIN_LEVEL_H,  // freevip
  ADMIN_CHAT,     // vip
  ADMIN_KICK,     // admin
  ADMIN_IMMUNITY  // s. admin
};

/* GXP:INFO */

/* Internal */

#define _GXP_MAX_PREFIX_LENGTH 16