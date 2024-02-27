// Gun Xp Mod Include File //
#if defined _gunxpmod_included
  #endinput
#endif
#define _gunxpmod_included

#include <hamsandwich>
#include <fakemeta_util>

#if !defined m_pActiveItem
	#define m_pActiveItem    373
#endif

#if !defined XO_PLAYER
	#define XO_PLAYER  5
#endif

//Unlocks levels defined
#define GUN_SECTION_KNIFE 1
#define GUN_SECTION_PISTOL 2
#define GUN_SECTION_RIFLE 3
#define GUN_SECTION_GRENADES 4
#define GUN_SECTION_ITEMS 5


//Access unlocks
#define GUN_FIRST_ACCESS_ID 1
#define GUN_FIRST_ACCESS ADMIN_CHAT
#define GUN_FIRST_ACCESS_TEXT "VIP"

#define GUN_SECOND_ACCESS_ID 2
#define GUN_SECOND_ACCESS ADMIN_KICK
#define GUN_SECOND_ACCESS_TEXT "ADMIN"

#define GUN_THIRD_ACCESS_ID 3
#define GUN_THIRD_ACCESS ADMIN_IMMUNITY
#define GUN_THIRD_ACCESS_TEXT "S.ADMIN"

#define GUN_FREE_ACCESS_ID 4
#define GUN_FREE_ACCESS ADMIN_USER
#define GUN_FREE_ACCESS_TEXT "FREE"


enum _:kAdditionalUnlockFlag (<<=1){
	UNLOCK_NEW_PLAYER_HANDICAP = 16
}

//Class PIRCES
#define CLASS_PRICE_XP 1
#define CLASS_PRICE_PR 2

native parachute_using(id);
native parachute_pause(id, Float:time);

native gxp_menu_top_players(id);
native gxp_menu_show_powers(id);

native bool:gxp_is_user_newbie(id);

forward gxp_data_loaded(id, szAuth[]);
forward gxp_level_up(id, level, reset);

native gxp_get_jump_bomb_bonus_dmg(id);
native gxp_get_bonus_hp(id);

native get_user_save_type(id);
// check_level(id)
native check_level_native(id);

//get mysql handle
native Handle:get_gxm_sql_handle();

//get mysql power level
native get_power_level_ex(id, powerId);

//set mysql power level
native add_power_level_ex(id, powerId);

// Returns player Experience.
native get_user_xp(id)

// Sets player Experience.
native set_user_xp(id, amount)

// Returns player Prestige.
native get_user_prestige(id)

//returns player used prestiges num
native get_user_used_prestige(id);

// Sets player Prestige.
native set_user_prestige(id, amount)

// Returns player Level.
native get_user_level(id)

// Sets player Level.
native set_user_level(id, amount)

// Returns player Level by Xp.
native get_user_max_level(id)

native gxp_get_user_kills(id)
native gxp_get_user_hs(id)
native gxp_get_user_deaths(id)
native gxp_get_user_bought_prs(id)

// SHOP
native register_gxm_item(item_name[], item_desc[], item_cost, item_level, item_section, item_access, weapon);
native register_item_gxm(item_name[], item_desc[], item_cost, item_level, item_section, item_access, weapon);

native gxp_shop_show_remove_unlocks_menu(id);
native gxp_show_show_unlocks_menu(id);
native gxp_get_vaccines_choices(id, vaccines[]);


stock client_printcolor(const id, const input[], any:...)
{
	new count = 1, players[32];
	static msg[191];
	vformat(msg,190,input,3);
	replace_all(msg,190,"/g","^4");// green txt
	replace_all(msg,190,"/y","^1");// orange txt
	replace_all(msg,190,"/ctr","^3");// team txt
	replace_all(msg,190,"/w","^0");// team txt
	if (id) players[0] = id; else get_players(players,count,"ch");
	for (new i=0;i<count;i++)
		if (is_user_connected(players[i]))
		{
			message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, players[i]);
			write_byte(players[i]);
			write_string(msg);
			message_end();
		}
}

stock cs_reset_user_weapon(iPlayer)
{
	new iWeapon = get_pdata_cbase(iPlayer, m_pActiveItem, XO_PLAYER);
	if(pev_valid(iWeapon))
		ExecuteHamB(Ham_Item_Deploy, iWeapon);
}
