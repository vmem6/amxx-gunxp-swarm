/*
 * TODO:
 *   - split this into separate plugins for: guns, powers, unlocks.
 */

#define DEBUG

#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fakemeta_util>

#include <gunxp_swarm>
#include <gunxp_swarm_config>
#include <gunxp_swarm_sql>
#include <gunxp_swarm_uls>
#include <gunxp_swarm_powers>
#include <gunxp_swarm_const>

#include <team_balancer_skill>

#include <utils_menu>
#include <utils_log>
#include <utils_bits>
#include <utils_text>

#define GMID(%0) %0 - g_mids[0]

#define HUD_COLOR_SURVIVOR    0, 109, 128
#define HUD_COLOR_ZOMBIE    136,  19,  19
#define HUD_COLOR_SPECTATOR  64,  64,  64

enum _:MenuID
{
  /* Global categories */
  mid_main_ctg = 0,
  mid_guns_ctg,

  /* Main > Categories */
  mid_main_uls_ctg,
  mid_main_powers_ctg,
  mid_main_ulremove_ctg,

  /* Guns > Categories */
  mid_secn_ctg,
  mid_prim_ctg,
  /* Guns > Items */
  mid_select_prev_item,
  mid_remember_sel_item,

  /* UL remove > Items */
  mid_ulremove_yes_item = mid_remember_sel_item + _GXP_GUN_COUNT + _GXP_POWER_COUNT + 1,
  mid_ulremove_no_item,

  /* ULs > Categories */
  mid_ul_knives,
  mid_ul_secondaries,
  mid_ul_primaries,
  mid_ul_nades,
  mid_ul_items
};

enum _:TaskID (+= 1000)
{
  tid_show_gun_menu = 3785,
  tid_show_primary_hud,
  tid_show_zombie_hud,
  tid_show_spec_hud
};

new const g_clcmds[][][32 + 1] = 
{
  /* Guns */
  { "guns",       "handle_say_guns"     },
  { "ginklai",    "handle_say_guns"     },
  { "/guns",      "handle_say_guns"     },
  { "/ginklai",   "handle_say_guns"     },
  /* Powers */
  { "powers",     "handle_say_powers"   },
  { "power",      "handle_say_powers"   },
  { "galios",     "handle_say_powers"   },
  { "/powers",    "handle_say_powers"   },
  { "/power",     "handle_say_powers"   },
  { "/galios",    "handle_say_powers"   },
  /* Unlocks */
  { "unlocks",    "handle_say_unlocks"  },
  { "ul",         "handle_say_unlocks"  },
  { "uls",        "handle_say_unlocks"  },
  { "/unlocks",   "handle_say_unlocks"  },
  { "/ul",        "handle_say_unlocks"  },
  { "/uls",       "handle_say_unlocks"  },
  { "ulremove",   "handle_say_ulremove" },
  { "/ulremove",  "handle_say_ulremove" }
};

new g_mids[MenuID];
new g_gun_mids[_GXP_GUN_COUNT];
new g_pwr_mids[_GXP_POWER_COUNT];
new g_ul_mids[GxpUlClass][GXP_SWARM_UL_MAX_ULS_PER_CLASS];

new g_chose_once;
new g_chose_primary;
new g_chose_secondary;

new g_hudsync_tl;
new g_hudsync_tr;
new g_hudsync_bl;
new g_hudsync_xp[2];

new g_prefix[_GXP_MAX_PREFIX_LENGTH + 1];

new Float:g_base_he_regen;
new Float:g_base_sg_regen;

public plugin_natives()
{
  register_library("gxp_swarm_ui");

  register_native("gxp_ui_get_colors", "native_get_colors");
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_UI_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);
  register_dictionary(_GXP_SWARM_DICTIONARY);

  /* Events */

  register_event_ex("TextMsg", "event_textmsg", RegisterEvent_Single, "2&#Spec_Mode");

  /* Client commands */

  register_clcmd("say", "clcmd_say");
  register_clcmd("say_team", "clcmd_say");
  register_clcmd("chooseteam", "clcmd_chooseteam");

  /* Miscellaneous */

  g_hudsync_tl = CreateHudSyncObj();
  g_hudsync_tr = CreateHudSyncObj();
  g_hudsync_bl = CreateHudSyncObj();
  for (new i = 0; i != sizeof(g_hudsync_xp); ++i)
    g_hudsync_xp[i] = CreateHudSyncObj();

  ulog_register_logger("gxp_ui", "gunxp_swarm");
}

public plugin_cfg()
{
  bind_pcvar_string(get_cvar_pointer("gxp_info_prefix"), g_prefix, charsmax(g_prefix));
  fix_colors(g_prefix, charsmax(g_prefix));

  bind_pcvar_float(get_cvar_pointer("gxp_pwr_he_regen_base"), g_base_he_regen);
  bind_pcvar_float(get_cvar_pointer("gxp_pwr_sg_regen_base"), g_base_sg_regen);

  setup();
}

/* Forwards > Client */

public client_disconnected(pid, bool:drop, message[], maxlen)
{
  remove_task(pid + tid_show_primary_hud);
  remove_task(pid + tid_show_zombie_hud);

  UBITS_PUNSET(g_chose_once, pid);
}

/* Forwards > Internal > UMenu */

public umenu_render(pid, id, UMenuContext:ctx, UMenuContextPosition:pos, Array:title, page, pagenum)
{
  new prim = gxp_get_player_data(pid, pd_primary_gun);
  new secn = gxp_get_player_data(pid, pd_secondary_gun);

  new GxpRememberSelection:remember_sel =
    GxpRememberSelection:gxp_get_player_data(pid, pd_remember_sel);

  new _title[64 + 1];
  UMENU_SET_STRING(title, "\rBAD! REPORT THIS!")
  switch (GMID(id)) {
    /* Global categories */
    case mid_main_ctg: formatex(_title, charsmax(_title), "%L", pid, "GXP_MENU_MAIN_TITLE");
    case mid_guns_ctg: formatex(_title, charsmax(_title), "%L", pid, "GXP_MENU_GUNS_TITLE");

    /* Main > Categories */
    case mid_main_uls_ctg: {
      if (pos == umenu_cp_list)
        formatex(_title, charsmax(_title), "%L", pid, "GXP_MENU_MAIN_UNLOCKS");
      else
        formatex(_title, charsmax(_title), "%L", pid, "GXP_MENU_ULS_TITLE");
    }
    case mid_main_powers_ctg: {
      if (pos == umenu_cp_list)
        formatex(_title, charsmax(_title), "%L", pid, "GXP_MENU_MAIN_POWERS");
      else
        formatex(_title, charsmax(_title), "%L", pid, "GXP_MENU_POWERS_TITLE");
    }
    case mid_main_ulremove_ctg: {
      if (pos == umenu_cp_list)
        formatex(_title, charsmax(_title), "%L", pid, "GXP_MENU_MAIN_ULREMOVE");
      else
        formatex(_title, charsmax(_title), "%L", pid, "GXP_MENU_ULREMOVE_TITLE");
    }

    /* Guns > Categories */
    case mid_prim_ctg: {
      if (pos == umenu_cp_list) {
        if (gxp_get_player_data(pid, pd_level) < _GXP_SECN_GUN_COUNT) {
          formatex(
            _title, charsmax(_title),
            "%L \r[%L]^n",
            pid, "GXP_MENU_PRIMARY_GUN", pid, "GXP_MENU_LEVELN_OR_HIGHER", _GXP_SECN_GUN_COUNT
          );
        } else if (remember_sel == gxp_remember_sel_off) {
          formatex(_title, charsmax(_title), "%L^n", pid, "GXP_MENU_PRIMARY_GUN");
        } else {
          formatex(
            _title, charsmax(_title), "%L \y[%s]^n", pid, "GXP_MENU_PRIMARY_GUN", _gxp_gun_names[prim]
          );
        }
      } else {
        if (remember_sel == gxp_remember_sel_off) {
          formatex(
            _title, charsmax(_title), "%L", pid, "GXP_MENU_PRIMARY_GUN_TITLE_PLAIN", page, pagenum
          );
        } else {
          formatex(
            _title, charsmax(_title), "%L", pid, "GXP_MENU_PRIMARY_GUN_TITLE",
            _gxp_gun_names[prim], page, pagenum
          );
        }
      }
    }
    case mid_secn_ctg: {
      if (pos == umenu_cp_list) {
        if (remember_sel == gxp_remember_sel_off) {
          formatex(_title, charsmax(_title), "%L", pid, "GXP_MENU_SECONDARY_GUN");
        } else {
          formatex(
            _title, charsmax(_title),
            "%L \y[%s]", pid, "GXP_MENU_SECONDARY_GUN", _gxp_gun_names[secn]
          );
        }
      } else {
        if (remember_sel == gxp_remember_sel_off) {
          formatex(
            _title, charsmax(_title), "%L", pid, "GXP_MENU_SECONDARY_GUN_TITLE_PLAIN", page, pagenum
          );
        } else {
          formatex(
            _title, charsmax(_title), "%L", pid, "GXP_MENU_SECONDARY_GUN_TITLE",
            _gxp_gun_names[secn], page, pagenum
          );
        }
      }
    }

    /* Guns > Items */
    case mid_select_prev_item:
      formatex(_title, charsmax(_title), "%L", pid, "GXP_MENU_SELECT_PREVIOUS");
    case mid_remember_sel_item: {
      static const ml_map[GxpRememberSelection][] = {
        "GXP_MENU_NEVER",
        "GXP_MENU_THIS_SESSION",
        "GXP_MENU_PERMANENTLY"
      };

      formatex(
        _title, charsmax(_title),
        "%L",
        pid, "GXP_MENU_REMEMBER_SELECTION",
        pid, ml_map[GxpRememberSelection:gxp_get_player_data(pid, pd_remember_sel)]
      );
    }

    /* ULs > Categories */
    case mid_ul_knives..mid_ul_items: {
      static const ml_map[GxpUlClass][] = {
        "GXP_MENU_UL_KNIVES",
        "GXP_MENU_UL_SECONDARY_GUNS",
        "GXP_MENU_UL_PRIMARY_GUNS",
        "GXP_MENU_UL_NADES",
        "GXP_MENU_UL_ITEMS"
      };

      new class = GMID(id) - mid_ul_knives;
      new Array:player_uls[GxpUlClass];
      gxp_get_player_data(pid, pd_uls, _:player_uls);

      if (pos == umenu_cp_list) {
        formatex(
          _title, charsmax(_title),
          "%L", pid, ml_map[class],
          ArraySize(player_uls[class]), ArraySize(gxp_ul_get_class_items(GxpUlClass:class))
        );
      } else {
        new ml[UMENU_MAX_TITLE_LENGTH + 1];
        formatex(ml, charsmax(ml), "%s_TITLE", ml_map[class]);
        formatex(
          _title, charsmax(_title),
          "%L", pid, ml, 
          ArraySize(player_uls[class]), ArraySize(gxp_ul_get_class_items(GxpUlClass:class)),
          page, pagenum
        );
      }
    }

    case mid_ulremove_yes_item: formatex(_title, charsmax(_title), "%L", pid, "GXP_MENU_YES");
    case mid_ulremove_no_item: formatex(_title, charsmax(_title), "%L", pid, "GXP_MENU_NO");

    default: {
      /* Guns/Primary&Secondary > Items */
      if (id <= g_gun_mids[_GXP_GUN_COUNT - 1]) {
        new lvl = gxp_get_player_data(pid, pd_level);
        for (new i = 0; i != _GXP_GUN_COUNT; ++i) {
          if (g_gun_mids[i] == id) {
            /* Current selection */
            if (
              (i == prim || i == secn)
              && GxpRememberSelection:gxp_get_player_data(pid, pd_remember_sel)
                != gxp_remember_sel_off
            ) {
              formatex(
                _title, charsmax(_title), "%s \y[%L] [%L]",
                _gxp_gun_names[i], pid, "GXP_MENU_LEVEL", i, pid, "GXP_MENU_CURRENT"
              );
            /* Others */
            } else {
              formatex(
                _title, charsmax(_title), "%s %s[%L]",
                _gxp_gun_names[i], lvl < i ? "\r" : "\y", pid, "GXP_MENU_LEVEL", i
              );
            }
            break;
          }
        }
      /* Powers */
      } else if (id <= g_pwr_mids[sizeof(g_pwr_mids) - 1]) {
        format_powers(pid, id, _title, charsmax(_title));
      /* ULs > Items */
      } else {
        new ul[GxpUl];
        if (find_ul_by_mid(id, ul)) {
          formatex(_title, charsmax(_title), "%s", ul[gxp_ul_title]);

          new bool:owned;
          new bool:accessible;
          new buff[64];

          if (is_ul_available(pid, ul, owned, accessible)) {
            formatex(
              buff, charsmax(buff)," \y[xp: %d | lvl: %d]", ul[gxp_ul_cost], ul[gxp_ul_level]
            );
          } else if (owned) {
            formatex(buff, charsmax(buff), " \y[%L]", pid, "GXP_MENU_OWNED");
            if (ul[gxp_ul_newbie] && gxp_is_newbie(pid)) {
              add(_title, charsmax(_title), buff);
              formatex(buff, charsmax(buff), " [%L]", pid, "GXP_NEWBIE");
            }
          } else {
            new xp = gxp_get_player_data(pid, pd_xp_curr);
            new lvl = gxp_get_player_data(pid, pd_level);
            if (xp < ul[gxp_ul_cost] || lvl < ul[gxp_ul_level]) {
              formatex(
                buff, charsmax(buff),
                " \r[\%sxp: %d \r| \%slvl: %d\r]",
                xp < ul[gxp_ul_cost] ? "r" : "y", ul[gxp_ul_cost],
                lvl < ul[gxp_ul_level] ? "r" : "y", ul[gxp_ul_level]
              );
            } else {
              formatex(buff, charsmax(buff), " \r[%L]", pid, "GXP_MENU_SIMILAR_OWNED");
            }
          }
          
          if (ul[gxp_ul_cost] == 0) {
            add(_title, charsmax(_title), buff);
            formatex(buff, charsmax(buff), " [%L]", pid, "GXP_FREE");
          }

          if (ul[gxp_ul_access] != 0 && ul[gxp_ul_access] != 4) {
            static const access_map[][] = {
              "UNUSED",
              "VIP",
              "ADMIN",
              "S. ADMIN"
            };
            add(_title, charsmax(_title), buff);
            formatex(buff, charsmax(buff), " \r[%s]", access_map[ul[gxp_ul_access]]);
          }

          add(_title, charsmax(_title), buff);
        }
      }
    }
  }
  UMENU_SET_STRING(title, _title)
}

public bool:umenu_select(pid, id, UMenuContext:ctx)
{
  if (ctx == umenu_ctx_category)
    return true;

  /* Guns/Select previous */
  if (GMID(id) == mid_select_prev_item) {
    new lvl = gxp_get_player_data(pid, pd_level);
    new secn = gxp_get_player_data(pid, pd_secondary_gun);
    if (lvl >= secn) {
      gxp_give_gun(pid, secn);
      UBITS_PSET(g_chose_secondary, pid);

      new prim = gxp_get_player_data(pid, pd_primary_gun);
      if (lvl >= prim) {
        gxp_give_gun(pid, prim);
        UBITS_PSET(g_chose_primary, pid);
      }
    }
    return false;
  /* Guns/Remember selection */
  } else if (GMID(id) == mid_remember_sel_item) {
    gxp_set_player_data(
      pid,
      pd_remember_sel,
      (gxp_get_player_data(pid, pd_remember_sel) + 1) % _:GxpRememberSelection
    );
  /* Guns/Primary&Secondary > Items */
  } else if (id <= g_gun_mids[_GXP_GUN_COUNT - 1]) {
    for (new i = 0; i != _GXP_GUN_COUNT; ++i) {
      if (g_gun_mids[i] == id) {
        UBITS_PSET(g_chose_once, pid);

        new bool:sel_prim = UBITS_PCHECK(g_chose_primary, pid);
        new bool:sel_secn = UBITS_PCHECK(g_chose_secondary, pid);
        if (i >= _GXP_SECN_GUN_COUNT) {
          gxp_set_player_data(pid, pd_primary_gun, i);
          if (!sel_prim) {
            UBITS_PSET(g_chose_primary, pid);
            gxp_give_gun(pid, i);
            if (!sel_secn)
              umenu_display(pid, g_mids[mid_secn_ctg]);
            return false;
          }
        } else {
          gxp_set_player_data(pid, pd_secondary_gun, i);
          if (!sel_secn) {
            UBITS_PSET(g_chose_secondary, pid);
            gxp_give_gun(pid, i);
            if (!sel_prim && gxp_get_player_data(pid, pd_level) >= _GXP_SECN_GUN_COUNT)
              umenu_display(pid, g_mids[mid_prim_ctg]);
            return false;
          }
        }
        break;
      }
    }
  /* Powers */
  } else if (id <= g_pwr_mids[sizeof(g_pwr_mids) - 1]) {
    /* TODO: move out into `gunxp_swarm_powers.sma`. */
    new pwrs[_:GxpPower];
    gxp_get_player_data(pid, pd_powers, pwrs);
    new pwr = id - g_pwr_mids[0];
    new lvl = pwrs[pwr];
    gxp_set_player_data(pid, pd_prs_stored, gxp_get_player_data(pid, pd_prs_stored) - _gxp_power_prices[lvl]);
    gxp_set_player_data(pid, pd_prs_used, gxp_get_player_data(pid, pd_prs_used) + _gxp_power_prices[lvl]);
    ++pwrs[pwr];
    gxp_set_player_data(pid, pd_powers, .buffer = pwrs);
  /* UL remove/Yes */
  } else if (GMID(id) == mid_ulremove_yes_item) {
    gxp_ul_deactivate(pid);
    if (!umenu_is_ctg_chain_empty(pid))
      umenu_display(pid, g_mids[mid_main_ctg], .clear_ctg_chain = true);
    return false;
  /* UL remove/No */
  } else if (GMID(id) == mid_ulremove_no_item) {
    if (!umenu_is_ctg_chain_empty(pid))
      umenu_display(pid, g_mids[mid_main_ctg], .clear_ctg_chain = true);
    return false;
  /* ULs */
  } else {
    new ul[GxpUl];
    find_ul_by_mid(id, ul);
    gxp_ul_activate(pid, ul);
  }

  return true;
}

public umenu_access(pid, id, UMenuContext:ctx)
{
  new GxpRememberSelection:remember_sel =
    GxpRememberSelection:gxp_get_player_data(pid, pd_remember_sel);
  /* Main/UL remove */
  if (GMID(id) == mid_main_ulremove_ctg) {
    if (!has_any_unlocks(pid))
      return ITEM_DISABLED;
  /* Guns/Primary */
  } else if (GMID(id) == mid_prim_ctg) {
    if (
      gxp_get_player_data(pid, pd_level) < _GXP_SECN_GUN_COUNT
      || (remember_sel == gxp_remember_sel_off && UBITS_PCHECK(g_chose_primary, pid))
    ) {
      return ITEM_DISABLED;
    }
  /* Guns/Secondary */
  } else if (GMID(id) == mid_secn_ctg) {
    if (remember_sel == gxp_remember_sel_off && UBITS_PCHECK(g_chose_secondary, pid))
      return ITEM_DISABLED;
  /* Guns/Select previous */
  } else if (GMID(id) == mid_select_prev_item) {
    if (!UBITS_PCHECK(g_chose_once, pid))
      return ITEM_DISABLED;

    if (
      remember_sel != gxp_remember_sel_off
      || UBITS_PCHECK(g_chose_primary, pid)
      || UBITS_PCHECK(g_chose_secondary, pid)
    ) {
      return ITEM_DISABLED;
    }

    new lvl = gxp_get_player_data(pid, pd_level);
    if (
      lvl < gxp_get_player_data(pid, pd_primary_gun)
      && lvl < gxp_get_player_data(pid, pd_secondary_gun)
    ) {
      return ITEM_DISABLED;
    }
  /* Guns/Primary&Secondary > Items */
  } else if (id <= g_gun_mids[_GXP_GUN_COUNT - 1]) {
    new lvl = gxp_get_player_data(pid, pd_level);
    for (new i = 0; i != _GXP_GUN_COUNT; ++i) {
      /* Disable item if the players' level is too low. */
      if (g_gun_mids[i] == id && lvl < i)
        return ITEM_DISABLED;
    }
  /* Powers */
  } else if (id <= g_pwr_mids[sizeof(g_pwr_mids) - 1]) {
    if (!is_power_available(pid, id - g_pwr_mids[0]))
      return ITEM_DISABLED;
  /* ULs */
  } else if (GMID(id) > mid_ul_items) {
    new rendered_ul[GxpUl];
    find_ul_by_mid(id, rendered_ul);
    if (!is_ul_available(pid, rendered_ul))
      return ITEM_DISABLED;
  }
  return ITEM_IGNORE;
}

/* Forwards > Internal > GunXP */

public gxp_player_spawned(pid)
{
  new GxpTeam:team = GxpTeam:gxp_get_player_data(pid, pd_team);

  if (team == tm_survivor)
    remove_task(pid + tid_show_zombie_hud);
  else if (!task_exists(pid + tid_show_zombie_hud))
    set_task_ex(1.0, "task_show_zombie_hud", pid + tid_show_zombie_hud, .flags = SetTask_Repeat);

  cleanup(pid);

  if (GxpRememberSelection:gxp_get_player_data(pid, pd_remember_sel) != gxp_remember_sel_off)
    return;

  UBITS_PUNSET(g_chose_primary, pid);
  UBITS_PUNSET(g_chose_secondary, pid);

  if (team == tm_survivor)
    set_task_ex(0.5, "task_show_gun_menu", tid_show_gun_menu + pid);
}

public gxp_player_cleanup(pid)
{
  cleanup(pid);
}

public gxp_player_gained_xp(pid, xp, bonus_xp, const desc[])
{
  new msg[64];
  formatex(msg, charsmax(msg), "+ %d XP", xp);

  new buff[64];
  if (bonus_xp > 0)
    formatex(buff, charsmax(buff), " (+%d%s%s)", bonus_xp, desc[0] == '^0' ? "" : " ", desc);
  else if (desc[0] != '^0')
    formatex(buff, charsmax(buff), " (%s)", desc);
  add(msg, charsmax(msg), buff);

  static cycle[MAX_PLAYERS + 1];

  if (GxpTeam:gxp_get_player_data(pid, pd_team) == tm_survivor)
    set_hudmessage(HUD_COLOR_SURVIVOR, 0.8, 0.2 + 0.025*cycle[pid], 0, 0.0, 2.0, 0.0, 0.5);
  else
    set_hudmessage(HUD_COLOR_ZOMBIE, 0.8, 0.2 + 0.025*cycle[pid], 0, 0.0, 2.0, 0.0, 0.5);

  ShowSyncHudMsg(pid, g_hudsync_xp[cycle[pid]], msg);

  if (++cycle[pid] == 2)
    cycle[pid] = 0;
}

public gxp_player_attempted_prs(pid, bool:successful)
{
  if (successful)
    umenu_close(pid);
}

public gxp_player_data_loaded(pid)
{
  if (GxpRememberSelection:gxp_get_player_data(pid, pd_remember_sel) != gxp_remember_sel_off) {
    UBITS_PSET(g_chose_primary, pid);
    UBITS_PSET(g_chose_secondary, pid);
  }

  set_task_ex(1.0, "task_show_primary_hud", tid_show_primary_hud + pid, .flags = SetTask_Repeat);
}

/* Events */

public event_textmsg(pid)
{
  enum { data_msg = 2 };

  if (is_user_bot(pid) || !is_user_connected(pid))
    return;

  new spec_mode[11 + 1];
  read_data(data_msg, spec_mode, charsmax(spec_mode));
  
  if (equal(spec_mode, "#Spec_Mode2") || equal(spec_mode, "#Spec_Mode4")) {
    if (!task_exists(pid + tid_show_spec_hud))
      set_task_ex(1.0, "task_show_spec_hud", pid + tid_show_spec_hud, .flags = SetTask_Repeat);
  } else {
    remove_task(pid + tid_show_spec_hud);
  }
}

/* Client commands */

public clcmd_say(const pid)
{
  new buffer[64 + 1];
  read_args(buffer, charsmax(buffer));
  remove_quotes(buffer);

  for (new i = 0; i != sizeof(g_clcmds); ++i) {
    if (equali(buffer, g_clcmds[i][0])) {
      callfunc_begin(g_clcmds[i][1]);
      callfunc_push_int(pid);
      callfunc_end();
      return PLUGIN_HANDLED;
    }
  }

  return PLUGIN_CONTINUE;
}

public clcmd_chooseteam(const pid)
{
  umenu_display(pid, g_mids[mid_main_ctg], .clear_ctg_chain = true);
  return PLUGIN_HANDLED_MAIN;
}

/* `say`/`say_team` client command handlers */

public handle_say_guns(pid)
{
  if (GxpTeam:gxp_get_player_data(pid, pd_team) != tm_survivor)
    return;
  umenu_display(pid, g_mids[mid_guns_ctg], .clear_ctg_chain = true);
}

public handle_say_powers(pid)
{
  umenu_display(pid, g_mids[mid_main_powers_ctg], .clear_ctg_chain = true);
}

public handle_say_unlocks(pid)
{
  umenu_display(pid, g_mids[mid_main_uls_ctg], .clear_ctg_chain = true);
}

public handle_say_ulremove(pid)
{
  if (has_any_unlocks(pid))
    umenu_display(pid, g_mids[mid_main_ulremove_ctg], .clear_ctg_chain = true);
  else
    chat_print(pid, g_prefix, "%L", pid, "GXP_CHAT_NO_ULS");
}

/* Formatters */

format_powers(pid, id, title[], title_sz)
{
  new pwr = id - g_pwr_mids[0];
  if (pwr == pwr_vaccines) {
    formatex(title, title_sz, "%L", pid, _gxp_power_ml_names[_:pwr_vaccines]);
    return;
  }

  new pwrs[_:GxpPower];
  gxp_get_player_data(pid, pd_powers, pwrs);
  new lvl = pwrs[pwr];
  new delta = gxp_power_get_delta(GxpPower:pwr);
  new amt = lvl*delta;
  new Float:famt = lvl*Float:delta;

  if (pwr == pwr_he_regen || pwr == pwr_sg_regen) {
    amt = floatround(pwr == pwr_he_regen ? g_base_he_regen : g_base_sg_regen) - amt;
    delta = -delta;
  }

  new tmp[32];

  if (lvl == _GXP_POWER_MAX_LEVEL) {
    formatex(
      title, title_sz, "%L \y[max] [%s", pid, _gxp_power_ml_names[pwr], _gxp_power_sign[pwr]
    );

    /* Add the actual power value. */
    if (pwr == pwr_damage || pwr == pwr_shooting_interval)
      formatex(tmp, charsmax(tmp), "%.2f", famt);
    else
      formatex(tmp, charsmax(tmp), "%d", amt);
    add(title, title_sz, tmp);

    /* Seperate value from units if there are units. */
    if (_gxp_power_units[pwr][0] != '^0')
      add(title, title_sz, " ");

    /* Add units. */
    formatex(tmp, charsmax(tmp), "%s]", _gxp_power_units[pwr]);
    add(title, title_sz, tmp);

    return;
  }

  formatex(title, title_sz, "%L \y[lvl: %d] [", pid, _gxp_power_ml_names[pwr], lvl);

  switch (pwr) {
    case pwr_damage, pwr_shooting_interval:
      formatex(
        tmp, charsmax(tmp),
        "%s%.2f -> %s%.2f %s",
        _gxp_power_sign[pwr], famt,
        _gxp_power_sign[pwr], famt + Float:delta,
        _gxp_power_units[pwr]
      );
    default:
      formatex(
        tmp, charsmax(tmp),
        "%s%d -> %s%d %s",
        _gxp_power_sign[pwr], amt,
        _gxp_power_sign[pwr], amt + delta,
        _gxp_power_units[pwr]
      );
  }
  add(title, title_sz, tmp);

  formatex(
    tmp, charsmax(tmp),
    "] \%s[%L: %d prs]",
    gxp_get_player_data(pid, pd_prs_stored) < _gxp_power_prices[lvl] ? "r" : "y",
    pid, "GXP_MENU_COST",
    _gxp_power_prices[lvl]
  );
  add(title, title_sz, tmp);
}

/* Tasks */

public task_show_gun_menu(tid)
{
  new pid = tid - tid_show_gun_menu;
  if (is_user_alive(pid))
    umenu_display(tid - tid_show_gun_menu, g_mids[mid_guns_ctg], .clear_ctg_chain = true);
}

public task_show_primary_hud(tid)
{
  new pid = tid - tid_show_primary_hud;

  new xp = gxp_get_player_data(pid, pd_xp_curr);
  new lvl = gxp_get_player_data(pid, pd_level);

  if (!is_user_alive(pid)) {
    set_hudmessage(HUD_COLOR_SPECTATOR, 0.02, 0.2, 0, 0.0, 1.0, 0.1, 0.1);
  } else {
    if (GxpTeam:gxp_get_player_data(pid, pd_team) == tm_survivor)
      set_hudmessage(HUD_COLOR_SURVIVOR, 0.02, 0.2, 0, 0.0, 1.0, 0.1, 0.1);
    else
      set_hudmessage(HUD_COLOR_ZOMBIE, 0.02, 0.2, 0, 0.0, 1.0, 0.1, 0.1);
  }

  new skill_lvl[32 + 1];
  new Float:skill = tb_get_player_skill(pid, skill_lvl);
  new Float:internal_skill = Float:gxp_get_player_data(pid, pd_skill);

  new skill_diff[12 + 1];
  if (floatabs(internal_skill - skill) > 0.01) {
    formatex(
      skill_diff, charsmax(skill_diff),
      " (%s%.2f)", internal_skill > skill ? "+" : "", internal_skill - skill
    );
  }

  if (lvl == _GXP_MAX_LEVEL) {
    ShowSyncHudMsg(
      pid,
      g_hudsync_tl,
      "%L", pid, "GXP_HUD_PRIMARY_MAX",
      lvl, xp, xp == _GXP_MAX_XP ? " (MAX)" : "",
      _gxp_gun_names[lvl],
      skill, skill_diff, skill_lvl,
      gxp_get_player_data(pid, pd_prs_stored)
    );
  } else {
    new xp_left = _gxp_xp_level_map[lvl + 1] - xp;
    new lvl_xp_diff = _gxp_xp_level_map[lvl + 1] - _gxp_xp_level_map[lvl];
    ShowSyncHudMsg(
      pid,
      g_hudsync_tl,
      "%L", pid, "GXP_HUD_PRIMARY",
      lvl, xp, _gxp_xp_level_map[lvl + 1], floatround(100 - xp_left*1.0/lvl_xp_diff*100),
      _gxp_gun_names[lvl],
      skill, skill_diff, skill_lvl,
      gxp_get_player_data(pid, pd_prs_stored)
    );
  }
}

public task_show_zombie_hud(tid)
{
  new pid = tid - tid_show_zombie_hud;

  if (GxpTeam:gxp_get_player_data(pid, pd_team) != tm_zombie) {
    remove_task(tid);
    return;
  }

  if (!is_user_alive(pid))
    return;

  set_hudmessage(HUD_COLOR_ZOMBIE, 0.02, 0.92, 0, 0.0, 1.0, 0.1, 0.1);

  new class[GxpClass];
  gxp_get_player_class(pid, class);

  static msg[512];

  if (bool:gxp_get_player_data(pid, pd_ability_available)) {
    new cooldown_left = floatround(
      class[cls_ability_cooldown] -
        (get_gametime() - Float:gxp_get_player_data(pid, pd_ability_last_used))
    );
    if (cooldown_left > 0) {
      formatex(
        msg, charsmax(msg),
        "%L", pid, "GXP_HUD_ZOMBIE_STATUS_COOLDOWN",
        class[cls_title], pev(pid, pev_health), cooldown_left
      );
    } else {
      formatex(
        msg, charsmax(msg),
        "%L", pid, "GXP_HUD_ZOMBIE_STATUS_READY", class[cls_title], pev(pid, pev_health)
      );
    }
  } else {
    formatex(
      msg, charsmax(msg),
      "%L", pid, "GXP_HUD_ZOMBIE_STATUS", class[cls_title], pev(pid, pev_health)
    );
  }

  /* Only classes that have a secondary ability cooldown defined pass this.
   *
   * TODO: this should eventually change. */
  if (Float:class[cls_secn_ability_cooldown] > 0.0) {
    static buff[128];
    new cooldown_left = floatround(
      class[cls_secn_ability_cooldown] -
        (get_gametime() - Float:gxp_get_player_data(pid, pd_secn_ability_last_used))
    );
    if (cooldown_left > 0) {
      formatex(
        buff, charsmax(buff), "%L", pid, "GXP_HUD_ZOMBIE_STATUS_SECN_POWER_CDOWN", cooldown_left
      );
    } else {
      formatex(buff, charsmax(buff), "%L", pid, "GXP_HUD_ZOMBIE_STATUS_SECN_POWER");
    }
    add(msg, charsmax(buff), buff);
  }

  ShowSyncHudMsg(pid, g_hudsync_bl, msg);
}

public task_show_spec_hud(tid)
{
  new pid = tid - tid_show_spec_hud;
  new target = pev(pid, pev_iuser2);

#if defined DEBUG
  if (!is_user_connected(pid)) {
    remove_task(tid);
    ULOG( \
      "gxp_ui", INFO, 0, "Player with PID %d has disconnected but SPEC task still exists. \
      Removing.", pid \
    );
    return;
  }
#endif // DEBUG

  new ul_msg[512 + 1];
  new bool:any_uls = false;

  new Float:y_pos = 0.7;

  if (GxpTeam:gxp_get_player_data(target, pd_team) == tm_survivor) {
    formatex(ul_msg, charsmax(ul_msg), "%L", pid, "GXP_HUD_UNLOCKS");

    new wpns[32];
    new wpn_num;
    get_user_weapons(target, wpns, wpn_num);

    new Array:uls[GxpUlClass];
    gxp_get_player_data(target, pd_uls, _:uls);

    new tmp[GxpUl];
    for (new i = 0; i != GxpUlClass; ++i) {
#if defined DEBUG
      if (!uls[i]) {
        ULOG( \
          "gxp_ui", INFO, target, \
          "^"@name^" (@id) has an invalid UL array. [AuthID: @authid] [IP: @ip] [Team: @team] \
          [Connected: %s] [Spectator: %d (connected: %s)]", \
          is_user_connected(target) ? "true" : "false", \
          pid, is_user_connected(pid) ? "true" : "false" \
        );
      }
#endif // DEBUG
      for (new j = 0; j != ArraySize(uls[i]); ++j) {
        gxp_ul_get_by_id(ArrayGetCell(uls[i], j), tmp);
        for (new k = 0; k != wpn_num; ++k) {
          if (tmp[gxp_ul_weapon_id] == wpns[k]) {
#define HUD_UNLOCK_TITLE_Y_HEIGHT 0.05
            y_pos -= HUD_UNLOCK_TITLE_Y_HEIGHT;
            any_uls = true;
            add(ul_msg, charsmax(ul_msg), "  - ");
            add(ul_msg, charsmax(ul_msg), tmp[gxp_ul_title]);
            add(ul_msg, charsmax(ul_msg), "^n");
          }
        }
      }
    }
  }

  set_hudmessage(HUD_COLOR_SPECTATOR, -1.0, y_pos, 0, 0.0, 1.0, 0.1, 0.1);

  new msg[512 + 1];

  new name[MAX_NAME_LENGTH + 1];
  get_user_name(target, name, charsmax(name));

  new xp = gxp_get_player_data(target, pd_xp_curr);
  new lvl = gxp_get_player_data(target, pd_level);

  new skill_lvl[32 + 1];
  new Float:skill = tb_get_player_skill(target, skill_lvl);

  if (lvl == _GXP_MAX_LEVEL) {
    formatex(
      msg, charsmax(msg),
      "%L", pid, "GXP_HUD_SPEC_MAX",
      name,
      lvl, xp, xp == _GXP_MAX_XP ? " (MAX)" : "",
      _gxp_gun_names[lvl],
      skill, skill_lvl,
      gxp_get_player_data(target, pd_prs_stored)
    );
  } else {
    new xp_left = _gxp_xp_level_map[lvl + 1] - xp;
    new lvl_xp_diff = _gxp_xp_level_map[lvl + 1] - _gxp_xp_level_map[lvl];
    formatex(
      msg, charsmax(msg),
      "%L", pid, "GXP_HUD_SPEC",
      name,
      lvl, xp, _gxp_xp_level_map[lvl + 1], floatround(100 - xp_left*1.0/lvl_xp_diff*100),
      _gxp_gun_names[lvl],
      skill, skill_lvl,
      gxp_get_player_data(target, pd_prs_stored)
    );
  }

  if (GxpTeam:gxp_get_player_data(target, pd_team) == tm_zombie) {
    ShowSyncHudMsg(pid, g_hudsync_tr, msg);
    return;
  }

  if (any_uls)
    add(msg, charsmax(msg), ul_msg);

  ShowSyncHudMsg(pid, g_hudsync_tr, msg);
}

/* Helpers */

setup()
{
  /* Global categories */
  new main_ctg      = g_mids[mid_main_ctg]      = umenu_register_category();
  new guns_ctg      = g_mids[mid_guns_ctg]      = umenu_register_category(.items_first = false);

  /* Main > Items */
  new uls_ctg       = g_mids[mid_main_uls_ctg]       = umenu_register_category(main_ctg);
  new powers_ctg    = g_mids[mid_main_powers_ctg]    = umenu_register_category(main_ctg);
  new ulremove_ctg  = g_mids[mid_main_ulremove_ctg]  = umenu_register_category(main_ctg);

  /* Guns > Categories */
  g_mids[mid_secn_ctg] = umenu_register_category(guns_ctg);
  g_mids[mid_prim_ctg] = umenu_register_category(guns_ctg);
  /* Guns > Items */
  g_mids[mid_select_prev_item]  = umenu_add_item(guns_ctg);
  g_mids[mid_remember_sel_item] = umenu_add_item(guns_ctg);
  /* Guns/Secondary > Items */
  for (new i = 0; i != _GXP_SECN_GUN_COUNT; ++i)
    g_gun_mids[i] = umenu_add_item(g_mids[mid_secn_ctg]);
  /* Guns/Primary > Items */
  for (new i = _GXP_SECN_GUN_COUNT; i != _GXP_GUN_COUNT; ++i)
    g_gun_mids[i] = umenu_add_item(g_mids[mid_prim_ctg]);

  /* Powers > Items */
  for (new i = 0; i != _GXP_POWER_COUNT; ++i)
    g_pwr_mids[i] = umenu_add_item(powers_ctg);

  /* UL remove > Items */
  g_mids[mid_ulremove_yes_item] = umenu_add_item(ulremove_ctg);
  g_mids[mid_ulremove_no_item]  = umenu_add_item(ulremove_ctg);

  /* ULs > Categories */
  g_mids[mid_ul_knives]       = umenu_register_category(uls_ctg);
  g_mids[mid_ul_secondaries]  = umenu_register_category(uls_ctg);
  g_mids[mid_ul_primaries]    = umenu_register_category(uls_ctg);
  g_mids[mid_ul_nades]        = umenu_register_category(uls_ctg);
  g_mids[mid_ul_items]        = umenu_register_category(uls_ctg);
  /* ULs > Items */
  for (new cls = 0; cls != GxpUlClass; ++cls) {
    new Array:uls = gxp_ul_get_class_items(GxpUlClass:cls);
    for (new j = 0; j != ArraySize(uls); ++j)
      g_ul_mids[cls][j] = umenu_add_item(g_mids[mid_ul_knives + _:cls]);
  }
}

cleanup(pid)
{
  new gmid = GMID(umenu_get_current_ctg(pid));
  if (gmid == mid_guns_ctg || gmid == mid_prim_ctg || gmid == mid_secn_ctg)
    umenu_close(pid);

  remove_task(pid + tid_show_spec_hud);
}

bool:find_ul_by_mid(mid, ul[GxpUl])
{
  for (new i = 0; i != sizeof(g_ul_mids); ++i) {
    for (new j = 0; j != GXP_SWARM_UL_MAX_ULS_PER_CLASS; ++j) {
      /* End reached - search other class. */
      if (g_ul_mids[i][j] == 0) {
        break;
      } else if (g_ul_mids[i][j] == mid) {
        ArrayGetArray(gxp_ul_get_class_items(GxpUlClass:i), j, ul);
        return true;
      }
    }
  }
  return false;
}

bool:is_ul_available(pid, const ul[GxpUl], &bool:owned = false, &bool:accessible = true)
{
  accessible = ul[gxp_ul_access] == 0 || ul[gxp_ul_access] == 4
    || (get_user_flags(pid) & _gxp_access_map[ul[gxp_ul_access]]);
  if (!accessible)
    return false;

  new lvl = gxp_get_player_data(pid, pd_level);
  /* Only consider XP and level if the UL is not free, and it is either not for
   * newbies or the player is not a newbie. */
  if (
    ul[gxp_ul_cost] > 0 && (!ul[gxp_ul_newbie] || !gxp_is_newbie(pid))
    && (gxp_get_player_data(pid, pd_xp_curr) < ul[gxp_ul_cost] || lvl < ul[gxp_ul_level])
  ) {
    return false;
  }

  new Array:uls[GxpUlClass];
  gxp_get_player_data(pid, pd_uls, _:uls);

  new tmp[GxpUl];
  for (new i = 0; i != GxpUlClass; ++i) {
    for (new j = 0; j != ArraySize(uls[i]); ++j) {
      gxp_ul_get_by_id(ArrayGetCell(uls[i], j), tmp);
      owned = tmp[gxp_ul_id] == ul[gxp_ul_id];
      if (owned || tmp[gxp_ul_weapon_id] == ul[gxp_ul_weapon_id])
        return false;
    }
  }

  return true;
}

bool:is_power_available(pid, pwr)
{
  new pwrs[GxpPower];
  gxp_get_player_data(pid, pd_powers, pwrs);
  new lvl = pwrs[pwr];
  return lvl < _GXP_POWER_MAX_LEVEL
    && gxp_get_player_data(pid, pd_prs_stored) >= _gxp_power_prices[lvl];
}

bool:has_any_unlocks(pid)
{
  new Array:player_uls[GxpUlClass];
  gxp_get_player_data(pid, pd_uls, _:player_uls);
  for (new ul_cls = 0; ul_cls != GxpUlClass; ++ul_cls) {
    if (ArraySize(player_uls[ul_cls]) > 0)
      return true;
  }
  return false;
}

/* Natives */

public native_get_colors(plugin, argc)
{
  enum {
    param_pid     = 1,
    param_colors  = 2
  };
  set_array(
    param_colors,
    GxpTeam:gxp_get_player_data(get_param(param_pid), pd_team) == tm_survivor
      ? { HUD_COLOR_SURVIVOR }
      : { HUD_COLOR_ZOMBIE },
    3
  );
}