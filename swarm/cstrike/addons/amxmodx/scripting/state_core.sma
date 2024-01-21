#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#include <state>
#include <state_const>

#include <utils_sql>
#include <utils_sql_stocks>
#include <utils_sql_const>

#define SQL_PLAYERS_TABLE "players"

new const g_sql_cols[][SQLColumn] =
{
  { "dynamic_id", sct_varchar, 64, "",  true, false },
  { "static_id",  sct_int,     11, "1", true, true  }
};

new g_fwd_player_loaded;

new g_sids[MAX_PLAYERS + 1];
new StateDynamicIDType:g_did_types[MAX_PLAYERS + 1];
new bool:g_changed_did[MAX_PLAYERS + 1];

public plugin_natives()
{
  register_library("state_core");
  register_native("state_get_player_sid", "native_get_sid");
  register_native("state_get_player_did_type", "native_get_did_type");
  register_native("state_set_player_did_type", "native_set_did_type");
}

public plugin_init()
{
  register_plugin(_STATE_CORE_PLUGIN, _STATE_VERSION, _STATE_AUTHOR);

  /* CVars */

  USQL_REGISTER_CVARS(state_player);

  /* Forwards */

  g_fwd_player_loaded = CreateMultiForward("state_player_loaded", ET_IGNORE, FP_CELL, FP_CELL);

  /* Forwards > FakeMeta */

  register_forward(FM_SetClientKeyValue, "fm_setclientkeyvalue_post");
}

public plugin_cfg()
{
  new configsdir[PLATFORM_MAX_PATH + 1];
  get_configsdir(configsdir, charsmax(configsdir));

  new cfg_path[PLATFORM_MAX_PATH + 1];
  formatex(cfg_path, charsmax(cfg_path), "%s/%s", configsdir, _STATE_CONFIG);

  if (!file_exists(cfg_path))
    set_fail_state("Could not find configuration file: configs/%s", _STATE_CONFIG);

  server_cmd("exec %s", cfg_path);
  server_exec();

  setup_sql();
}

/* Forwards > Client */

public client_putinserver(pid)
{
  g_sids[pid]         = 0;
  g_changed_did[pid]  = false;

  if (!is_user_hltv(pid) && !is_user_bot(pid))
    load_player_state(pid, 1);
}

public client_disconnected(pid, bool:drop, message[], maxlen)
{
  if (is_user_hltv(pid) || is_user_bot(pid))
    return;

  if (g_changed_did[pid]) {
    new did[STATE_MAX_DYNAMIC_ID_LENGTH + 1];
    new StateDynamicIDType:did_t = StateDynamicIDType:g_did_types[pid];
    if (did_t == s_did_t_authid)
      get_user_authid(pid, did, charsmax(did));
    else if (did_t == s_did_t_ip)
      get_user_ip(pid, did, charsmax(did), .without_port = true);
    else if (did_t == s_did_t_name)
      get_user_name(pid, did, charsmax(did));
    else
      return;

    usql_update_ex(
      usql_sarray("dynamic_id"), usql_sarray(did), Array:-1, true, "`static_id`='%d'", g_sids[pid]
    );
  }
}

/* Forwards > FakeMeta */

public fm_setclientkeyvalue_pre(pid, const info_buffer[], const key[], const value[])
{
  if (equal(key, "name"))
    g_changed_did[pid] = true;
}

/* Natives */

public native_get_sid(plugin, argc)
{
  enum { param_pid = 1 };
  new pid = get_param(param_pid);
  return is_user_connected(pid) ? g_sids[pid] : -1;
}

public StateDynamicIDType:native_get_did_type(plugin, argc)
{
  enum { param_pid = 1 };
  new pid = get_param(param_pid);
  return is_user_connected(pid) ? g_did_types[pid] : s_did_t_unknown;
}

/* TODO: rewrite this? brain isn't working atm... need to add a check for
 *       `did_t <= ip`. */
public native_set_did_type(plugin, argc)
{
  enum {
    param_pid = 1,
    param_did_type = 2
  };
  new pid = get_param(param_pid);
  new StateDynamicIDType:did_t = StateDynamicIDType:get_param(param_did_type);
  if (is_user_connected(pid) && g_sids[pid] != 0 && did_t != g_did_types[pid]) {
    g_did_types[pid] = did_t;
    g_changed_did[pid] = true;
  }
}

/* SQL */

setup_sql()
{
  usql_cache_info(g_usql_host, g_usql_user, g_usql_pass, g_usql_db);
  usql_create_table(
    SQL_PLAYERS_TABLE, usql_2darray(g_sql_cols, sizeof(g_sql_cols), SQLColumn), "`static_id`"
  );
}

load_player_state(pid, call_n)
{
  new did[STATE_MAX_DYNAMIC_ID_LENGTH + 2 + 1];

  if (call_n == 1) {
    g_did_types[pid] = s_did_t_authid;
    get_user_authid(pid, did, charsmax(did));
  } else if (call_n == 2) {
    g_did_types[pid] = s_did_t_ip;
    get_user_ip(pid, did, charsmax(did), .without_port = true);
  } else if (call_n == 3) {
    g_did_types[pid] = s_did_t_name;
    get_user_name(pid, did, charsmax(did));
  } else {
    g_did_types[pid] = s_did_t_authid;
    get_user_authid(pid, did, charsmax(did));
    usql_insert(usql_sarray("dynamic_id"), usql_sarray(did));
  }

  usql_set_data(usql_array(pid, call_n));
  usql_sanitize(did, charsmax(did));
  usql_fetch_ex(usql_sarray("static_id"), true, "`dynamic_id`='%s'", did);
}

public usql_query_finished(SQLQuery:query, Handle:handle, bool:success, error[], errnum, data[], sz)
{
  if (!success) {
    /* TODO: log and inform player. */
    return;
  }

  if (query == sq_fetch) {
    new pid = data[0];
    if (SQL_NumResults(handle) > 0) {
      g_sids[pid] = SQL_ReadResult(handle, SQL_FieldNameToNum(handle, "static_id"));
      ExecuteForward(g_fwd_player_loaded, _, pid, g_sids[pid]);
    } else {
      load_player_state(pid, data[1] + 1);
    }
  }
}