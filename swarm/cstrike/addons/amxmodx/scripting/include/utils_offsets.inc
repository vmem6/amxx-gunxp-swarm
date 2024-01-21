#if defined _UTILS_OFFSETS_INC
  #endinput
#endif
#define _UTILS_OFFSETS_INC

/* Sourced from ConnorMcLeod @
 * https://forums.alliedmods.net/showpost.php?p=1712101?p=1712101 */

/* Linux offset diffs. */
#define UXO_LINUX_DIFF_PLAYER     5
#define UXO_LINUX_DIFF_ANIMATING  4
#define UXO_LINUX_DIFF_WEAPONBOX  4
#define UXO_LINUX_DIFF_WEAPON     4

/* CBasePlayer */
#define UXO_FL_PAIN_SHOCK         108
#define UXO_FL_LAST_ATTACK_TIME   220
#define UXO_F_CLIENT_MAP_ZONE     235
#define UXO_I_HIDE_HUD            361
#define UXO_I_CLIENT_HIDE_HUD     362
#define UXO_P_ACTIVE_ITEM         373
#define UXO_P_CLIENT_ACTIVE_ITEM  374
#define UXO_SZ_ANIM_EXTENSION     492

/* CBaseAnimating */
#define UXO_FL_FRAMERATE              36
#define UXO_FL_GROUND_SPEED           37
#define UXO_FL_LAST_EVENT_CHECK       38
#define UXO_F_SEQUENCE_FINISHED       39
#define UXO_F_SEQUENCE_LOOPS          40
#define UXO_P_PLAYER                  41
#define UXO_FL_NEXT_PRIMARY_ATTACK    46
#define UXO_FL_NEXT_SECONDARY_ATTACK  47
#define UXO_FL_TIME_WEAPON_IDLE       48

/* CBaseMonster */
#define UXO_ACTIVITY        73
#define UXO_IDEAL_ACTIVITY  74
#define UXO_LAST_HIT_GROUP  75
#define UXO_FL_NEXT_ATTACK  83

/* CWeaponBox */

#define UXO_CWEAPONBOX 4

stock const uxo_rgp_player_items[6] = { 34 , 35 , ... };