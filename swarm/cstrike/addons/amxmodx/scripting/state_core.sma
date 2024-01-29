#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#include <state>
#include <state_const>

#include <utils_sql>
#include <utils_sql_stocks>
#include <utils_sql_const>
#include <utils_menu>
#include <utils_text>
#include <utils_bits>

#define DEBUG
#if defined DEBUG
  #define DEBUG_DIR "addons/amxmodx/logs/others/state"
  #define LOG(%0) log_to_file(g_log_filepath, %0)
  #define LOG_SQL(%0) log_to_file(g_log_filepath_sql, %0)
  #define GET_INFO(%0) \
    new _name[MAX_NAME_LENGTH + 1]; get_user_name(%0, _name, charsmax(_name)); \
    new _sid = state_get_player_sid(%0)

  new g_log_filepath[PLATFORM_MAX_PATH + 1];
  new g_log_filepath_sql[PLATFORM_MAX_PATH + 1];
#else
  #define LOG(%0) //
  #define LOG_SQL(%0) //
  #define GET_INFO(%0) //
#endif

#define SQL_PLAYERS_TABLE "players"

new const g_sql_cols[][SQLColumn] =
{
  { "static_id",  sct_int,     11, "1", true, true  },
  { "dynamic_id", sct_varchar, 64, "",  true, false },
  { "nick",       sct_varchar, 33, "",  true, false }
};

new g_prefix[16 + 1];

new g_fwd_player_loaded;

new g_sids[MAX_PLAYERS + 1];
new StateDynamicIDType:g_did_types[MAX_PLAYERS + 1];

new g_names[MAX_PLAYERS + 1][MAX_NAME_LENGTH + 1];
new g_stored_names[MAX_PLAYERS + 1][MAX_NAME_LENGTH + 1];

/* Bit fields */

new g_did_changed;

new g_forcing_name;

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
  register_dictionary(_STATE_DICTIONARY);

  /* CVars */

  USQL_REGISTER_CVARS(state_player);

  bind_pcvar_string(
    register_cvar("state_info_prefix", "^3[STATE]^1 "), g_prefix, charsmax(g_prefix)
  );

  /* Forwards */

  g_fwd_player_loaded = CreateMultiForward("state_player_loaded", ET_IGNORE, FP_CELL, FP_CELL);

  /* Forwards > FakeMeta */

  register_forward(FM_ClientUserInfoChanged, "fm_clientuserinfochanged_pre");

  /* Miscellaneous */

#if defined DEBUG
  new filename[20 + 1];

  get_time("core_%Y_%m_%d.log", filename, charsmax(filename));
  formatex(g_log_filepath, charsmax(g_log_filepath), "%s/%s", DEBUG_DIR, filename);

  get_time("sql_%Y_%m_%d.log", filename, charsmax(filename));
  formatex(g_log_filepath_sql, charsmax(g_log_filepath_sql), "%s/%s", DEBUG_DIR, filename);
#endif
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
  g_sids[pid] = 0;
  UBITS_PUNSET(g_did_changed, pid);

  get_user_name(pid, g_names[pid], charsmax(g_names[]));
  g_stored_names[pid][0] = '^0';
  UBITS_PUNSET(g_forcing_name, pid);

  if (!is_user_hltv(pid) && !is_user_bot(pid))
    load_player_state(pid, 1);
}

public client_disconnected(pid, bool:drop, message[], maxlen)
{
  if (is_user_hltv(pid) || is_user_bot(pid))
    return;

  if (!equal(g_names[pid], g_stored_names[pid])) {
    usql_sanitize(g_names[pid], charsmax(g_names[]));
    usql_update_ex(
      usql_sarray("nick"), usql_sarray(g_names[pid]),
      Array:-1, true,
      "`static_id`='%d'", g_sids[pid]
    );
  } else {
    server_print("ok: ^"%s^" == ^"%s^"", g_names[pid], g_stored_names[pid]);
  }
}

/* Forwards > FakeMeta */

public fm_clientuserinfochanged_pre(pid)
{
  static old_name[MAX_NAME_LENGTH + 1];
  pev(pid, pev_netname, old_name, charsmax(old_name));
  if (old_name[0] == '^0')
    return FMRES_IGNORED;

  static new_name[MAX_NAME_LENGTH + 1];
  get_user_info(pid, "name", new_name, charsmax(new_name));
  if (equal(old_name, new_name))
    return FMRES_IGNORED;

  copy(g_names[pid], charsmax(g_names[]), new_name);

  if (!UBITS_PCHECK(g_forcing_name, pid)) {
    usql_set_data(usql_array(pid));
    usql_sanitize(new_name, charsmax(new_name));
    if (g_did_types[pid] == s_did_t_name) {
      usql_update_ex(
        usql_sarray("dynamic_id"), usql_sarray(new_name),
        Array:-1, true,
        "`static_id`='%d'", g_sids[pid]
      );
    } else {
      usql_fetch_ex(usql_sarray("static_id"), true, "`dynamic_id`='%s'", new_name);
    }

    /* Defer name change until we know that the query succeeded. */
    set_user_info(pid, "name", old_name);
    return FMRES_HANDLED;
  }

  UBITS_PUNSET(g_forcing_name, pid);

  return FMRES_IGNORED;
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
  if (!is_user_connected(pid) || g_sids[pid] == 0)
    return;

  new StateDynamicIDType:did_t = StateDynamicIDType:get_param(param_did_type);
  if (did_t == g_did_types[pid])
    return;

  new did[STATE_MAX_DYNAMIC_ID_LENGTH + 1];

  switch (did_t) {
    case s_did_t_authid:  get_user_authid(pid, did, charsmax(did));
    case s_did_t_ip:      get_user_ip(pid, did, charsmax(did), .without_port = true);
    case s_did_t_name:    copy(did, charsmax(did), g_names[pid]);
  }

  usql_set_data(usql_array(pid, g_did_types[pid]));
  usql_sanitize(did, charsmax(did));
  usql_update_ex(
    usql_sarray("dynamic_id"), usql_sarray(did), Array:-1, true, "`static_id`='%d'", g_sids[pid]
  );

  g_did_types[pid] = did_t;
  UBITS_PSET(g_did_changed, pid);
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
#if defined DEBUG
    new _name[MAX_NAME_LENGTH + 1];
    get_user_name(pid, _name, charsmax(_name));

    new ip[MAX_IP_LENGTH + 1];
    get_user_ip(pid, ip, charsmax(ip), .without_port = true);

    new authid[MAX_AUTHID_LENGTH + 1];
    get_user_authid(pid, authid, charsmax(authid));

    LOG( \
      "[STATE:CORE::load_player_state] No record found for ^"%s^" (%d). Inserting new one. \
      [IP: %s] [AuthID: %s]", \
      _name, pid, ip, authid \
    );
#endif // DEBUG

    g_did_types[pid] = s_did_t_authid;

    new name[MAX_NAME_LENGTH + 1];
    get_user_name(pid, name, charsmax(name));
    get_user_authid(pid, did, charsmax(did));

    usql_sanitize(name, charsmax(name));
    usql_sanitize(did, charsmax(did));
    usql_insert(usql_sarray("dynamic_id", "nick"), usql_sarray(did, name));
  }

  usql_set_data(usql_array(pid, call_n));
  usql_sanitize(did, charsmax(did));
  usql_fetch_ex(usql_sarray("static_id", "nick"), true, "`dynamic_id`='%s'", did);
}

parse_data(pid, Handle:handle)
{
  g_sids[pid] = SQL_ReadResult(handle, SQL_FieldNameToNum(handle, "static_id"));
  SQL_ReadResult(
    handle, SQL_FieldNameToNum(handle, "nick"), g_stored_names[pid], charsmax(g_stored_names[])
  );
}

public usql_query_finished(SQLQuery:query, Handle:handle, bool:success, error[], errnum, data[], sz)
{
  if (!success) {
    if (query == sq_fetch) {
      LOG_SQL("[STATE:CORE::usql_query_finished] Query failed. Error (%d): %s", errnum, error);
      // chat_print(0, g_prefix, "%L", pid, "STATE_CHAT_INTERNAL_ERROR", 1);
      return;
    }

    /* Attempted DID or name change, and, most likely, a similar record already
     * exists. */
    if (sz > 0) {
      new pid = data[0];
      /* DID change - restore old DID type. */
      if (sz == 2)
        g_did_types[pid] = StateDynamicIDType:data[1];
      /* Name change - restore previous name. */
      else
        get_user_name(pid, g_names[pid], charsmax(g_names[]));

      umenu_refresh(pid);

      console_print(pid, "%L", pid, "STATE_NAME_RESERVED");
      chat_print(pid, g_prefix, "%L", pid, "STATE_NAME_RESERVED");
    }

    LOG_SQL("[STATE:CORE::usql_query_finished] Query failed. Error (%d): %s", errnum, error);
    return;
  /* Attempted name change. */
  } else if (sz == 1) {
    new pid = data[0];

    /* Attempted to change name to one that is used by someone else as a DID. */
    if (query == sq_fetch && SQL_NumResults(handle) > 0) {
      console_print(pid, "%L", pid, "STATE_NAME_RESERVED");
      chat_print(pid, g_prefix, "%L", pid, "STATE_NAME_RESERVED");
      return;
    }

    UBITS_PSET(g_forcing_name, pid);
    set_user_info(pid, "name", g_names[pid]);
  }

  if (query == sq_fetch) {
    new pid = data[0];
    if (SQL_NumResults(handle) > 0) {
      parse_data(pid, handle);
      ExecuteForward(g_fwd_player_loaded, _, pid, g_sids[pid]);
    } else {
      load_player_state(pid, data[1] + 1);
    }
  }
}