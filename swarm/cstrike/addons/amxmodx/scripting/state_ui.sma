#include <amxmodx>
#include <amxmisc>

#include <state>
#include <state_ui>
#include <state_const>

#include <utils_menu>
#include <utils_menu_const>
#include <utils_cmd>

#define MAX_CMD_LENGTH          32
#define MAX_HANDLER_NAME_LENGTH 96

new const g_clcmds[][UCmdCommand] =
{
  { "/nuostatos",   "handle_say_prefs" },
  { "/nustatymai",  "handle_say_prefs" },
  { "/prefs",       "handle_say_prefs" },
  { "/preferences", "handle_say_prefs" },
  { "/settings",    "handle_say_prefs" },
  { "/tipas",       "handle_say_id"    },
  { "/save",        "handle_say_id"    },
  { "/id",          "handle_say_id"    }
};

new g_ctg;

new g_id_ctg;
new g_id_authid_item;
new g_id_ip_item;
new g_id_name_item;

public plugin_natives()
{
  // register_library("state_ui");
  // register_native("state_ui_register_category", "native_register_category");
  // register_native("state_ui_add_item", "native_add_item");
}

public plugin_init()
{
  register_plugin(_STATE_UI_PLUGIN, _STATE_VERSION, _STATE_AUTHOR);
  register_dictionary(_STATE_DICTIONARY);

  /* Client commands */

  register_clcmd("say", "clcmd_say");
  register_clcmd("say_team", "clcmd_say");

  /* Miscellaneous */

  g_ctg = umenu_register_category();
  g_id_ctg = umenu_register_category(g_ctg);
  g_id_authid_item = umenu_add_item(g_id_ctg);
  g_id_ip_item = umenu_add_item(g_id_ctg);
  g_id_name_item = umenu_add_item(g_id_ctg);
}

/* Natives */

// public native_register_category(plugin, argc)
// {
//   enum { param_category_id = 1 };
//   return register_category(plugin, get_param(param_category_id));
// }
// 
// public native_add_item(plugin, argc)
// {
//   enum { param_category_id = 1 };
//   return add_item(plugin, get_param(param_category_id));
// }

/* Forwards */

public umenu_render(pid, id, UMenuContext:ctx, UMenuContextPosition:pos, Array:title)
{
  new _title[64 + 1];
  if (ctx == umenu_ctx_item) {
    if (id == g_id_authid_item)
      formatex(_title, charsmax(_title), "%L", pid, "STATE_AUTHID");
    else if (id == g_id_ip_item)
      formatex(_title, charsmax(_title), "%L", pid, "STATE_IP");
    else
      formatex(_title, charsmax(_title), "%L %L", pid, "STATE_NAME", pid, "STATE_UI_MENU_INSECURE");
  } else if (id == g_ctg) {
    formatex(
      _title, charsmax(_title), "%s%L",
      pos == umenu_cp_title ? "\r" : "", pid, "STATE_UI_MENU_SETTINGS_TITLE"
    );
  } else {
    static const did_ml_map[StateDynamicIDType][] = {
      "", // unused
      "STATE_AUTHID",
      "STATE_IP",
      "STATE_NAME"
    };
    formatex(
      _title, charsmax(_title), "%L",
      pid, pos == umenu_cp_list ? "STATE_UI_MENU_UNIQUE_ID" : "STATE_UI_MENU_UNIQUE_ID_TITLE",
      pid, did_ml_map[state_get_player_did_type(pid)]
    );
  }
  UMENU_SET_STRING(title, _title)
}

public bool:umenu_select(pid, id, UMenuContext:ctx)
{
  if (ctx != umenu_ctx_item)
    return false;
  if (id == g_id_authid_item)
    state_set_player_did_type(pid, s_did_t_authid);
  else if (id == g_id_ip_item)
    state_set_player_did_type(pid, s_did_t_ip);
  else
    state_set_player_did_type(pid, s_did_t_name);
  return true;
}

public umenu_access(pid, id, UMenuContext:ctx)
{
  if (ctx == umenu_ctx_item) {
    new StateDynamicIDType:did_t = state_get_player_did_type(pid);
    if (
      (did_t == s_did_t_authid && id == g_id_authid_item)
      || (did_t == s_did_t_ip && id == g_id_ip_item)
      || (did_t == s_did_t_name && id == g_id_name_item)
    ) {
      return ITEM_DISABLED;
    }
  }
  return ITEM_IGNORE;
}

/* Client commands */

public clcmd_say(const pid)
{
  UCMD_HANDLE_CMD_EX(pid, g_clcmds, sizeof(g_clcmds));
}

/* `say`/`say_team` client command handlers */

public handle_say_prefs(const pid, const args[])
{
  umenu_display(pid, g_ctg, true);
}

public handle_say_id(const pid, const args[])
{
  umenu_display(pid, g_id_ctg, true);
}