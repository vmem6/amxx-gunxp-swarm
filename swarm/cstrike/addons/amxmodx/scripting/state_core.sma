#define DEBUG

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#include <state>
#include <state_const>

#include <utils_sql>
#include <utils_sql_stocks>
#include <utils_sql_const>
#include <utils_menu>
#include <utils_log>
#include <utils_text>
#include <utils_bits>

#define SQL_COMMON_TABLE "common"

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

new Trie:g_state_tables;
new Trie:g_player_states[MAX_PLAYERS + 1];

new g_names[MAX_PLAYERS + 1][MAX_NAME_LENGTH + 1];
new g_stored_names[MAX_PLAYERS + 1][MAX_NAME_LENGTH + 1];

/* Bit fields */

new g_did_changed;

new g_forcing_name;

public plugin_natives()
{
  g_state_tables = TrieCreate();

  register_library("state_core");

  register_native("state_queue_table", "native_queue_table");

  register_native("state_get_player_sid", "native_get_sid");
  register_native("state_get_player_did_type", "native_get_did_type");
  register_native("state_set_player_did_type", "native_set_did_type");

  register_native("state_get_val", "native_get_val");
  register_native("state_set_val", "native_set_val");
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

  ulog_register_logger("state_core", "state");
  ulog_register_logger("state_sql", "state");
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

public plugin_end()
{
  // new table[StateTable];
  // for (new i = 0, end = ArraySize(g_state_tables); i != end; ++i) {
  //   ArrayGetArray(g_state_tables, i, table);
  //   ArrayDestroy(table[st_cols]);
  // }
  // ArrayDestroy(g_state_tables);

  for (new i = 0; i != MAX_PLAYERS + 1; ++i) {
    if (!g_player_states[i])
      continue;

    new TrieIter:iter = TrieIterCreate(g_player_states[i]);
    for (new Trie:pstate; TrieIterGetCell(iter, pstate); TrieIterNext(iter))
      TrieDestroy(pstate);
    TrieIterDestroy(iter);

    TrieDestroy(g_player_states[i]);
  }
}

/* Forwards > Client */

public client_putinserver(pid)
{
  g_sids[pid] = 0;
  UBITS_PUNSET(g_did_changed, pid);

  get_user_name(pid, g_names[pid], charsmax(g_names[]));
  g_stored_names[pid][0] = '^0';
  UBITS_PUNSET(g_forcing_name, pid);

  if (!is_user_hltv(pid) && !is_user_bot(pid)) {
    if (g_player_states[pid])
      TrieClear(g_player_states[pid]);
    load_player_state(pid, 1);
  }
}

public client_disconnected(pid, bool:drop, message[], maxlen)
{
  if (is_user_hltv(pid) || is_user_bot(pid))
    return;

  if (!equal(g_names[pid], g_stored_names[pid])) {
    /* For whatever reason, names sometimes contain extraneous slashes (\), so
     * desanitize them beforehand. */
    usql_desanitize(g_names[pid], charsmax(g_names[]));
    usql_sanitize(g_names[pid], charsmax(g_names[]));
    usql_update_ex(
      usql_sarray("nick"), usql_sarray(g_names[pid]),
      Array:-1, true, "",
      "`static_id`='%d'", g_sids[pid]
    );
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
    usql_sanitize(new_name, charsmax(new_name));
    usql_set_data(usql_array(pid));
    if (g_did_types[pid] == s_did_t_name) {
      usql_update_ex(
        usql_sarray("dynamic_id"), usql_sarray(new_name),
        Array:-1, true, "qcb_change_nick",
        "`static_id`='%d'", g_sids[pid]
      );
    } else {
      usql_fetch_ex(
        usql_sarray("static_id"), true, "qcb_change_nick", "`dynamic_id`='%s'", new_name
      );
    }

    /* Defer name change until we know that the query succeeded. */
    set_user_info(pid, "name", old_name);
    return FMRES_HANDLED;
  }

  UBITS_PUNSET(g_forcing_name, pid);

  return FMRES_IGNORED;
}

/* Natives */

public native_queue_table(plugin, argc)
{
  enum {
    param_table = 1,
    param_cols  = 2
  };

  new table[MAX_SQL_TABLE_NAME_LENGTH + 1];
  get_string(param_table, table, charsmax(table));

  new Array:cols = Array:get_param(param_cols);

  /* Add `id` column if it doesn't exist. */
  new col[SQLColumn];
  new bool:id_col_exists = false;
  for (new i = 0, end = ArraySize(cols); i != end; ++i) {
    ArrayGetArray(cols, i, col);
    if (equali(col[sc_name], "id")) {
      id_col_exists = true;
      break;
    }
  }
  if (!id_col_exists) {
    copy(col[sc_name], charsmax(col[sc_name]), "id");
    col[sc_type] = sct_int;
    col[sc_size] = 11;
    copy(col[sc_def_val], charsmax(col[sc_def_val]), "0");
    col[sc_not_null] = true;
    col[sc_auto_increment] = false;
    ArrayInsertArrayBefore(cols, 0, col);
  }

  usql_create_table(table, cols, "id", .cleanup = false);
  usql_set_table(SQL_COMMON_TABLE);

  TrieSetCell(g_state_tables, table, cols);
}

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
    usql_sarray("dynamic_id"), usql_sarray(did), Array:-1, true, "qcb_update_did",
    "`static_id`='%d'", g_sids[pid]
  );

  g_did_types[pid] = did_t;
  UBITS_PSET(g_did_changed, pid);
}

public native_get_val(plugin, argc)
{
  enum {
    param_pid     = 1,
    param_state   = 2,
    param_field   = 3,
    param_buffer  = 4,
    param_maxlen  = 5
  };

  new pid = get_param(param_pid);
  if (!g_player_states[pid])
    return -1;

  new table[MAX_SQL_TABLE_NAME_LENGTH + 1];
  get_string(param_state, table, charsmax(table));

  new Trie:pstate;
  if (!TrieGetCell(g_player_states[pid], table, pstate))
    return -1;

  new Array:cols;
  if (!TrieGetCell(g_state_tables, table, cols))
    return -1;

  new col_name[MAX_SQL_COLUMN_NAME_LENGTH + 1];
  get_string(param_field, col_name, charsmax(col_name));
  new col[SQLColumn];
  for (new i = 0, end = ArraySize(cols); i != end; ++i) {
    ArrayGetArray(cols, i, col);
    if (equal(col[sc_name], col_name)) {
      switch(col[sc_type]) {
        case sct_int, sct_float: {
          new val;
          TrieGetCell(pstate, col_name, val);
          return val;
        }

        case sct_varchar: {
          new buffer[MAX_SQL_COLUMN_VALUE_LENGTH + 1];
          TrieGetString(pstate, col_name, buffer, charsmax(buffer));
          set_string(param_buffer, buffer, get_param(param_maxlen));
          return strlen(buffer);
        }
      }
    }
  }

  return -1;
}

public native_set_val(plugin, argc)
{
  enum {
    param_pid   = 1,
    param_state = 2,
    param_field = 3,
    param_val   = 4
  };

  new pid = get_param(param_pid);
  if (!g_player_states[pid])
    return;

  new table[MAX_SQL_TABLE_NAME_LENGTH + 1];
  get_string(param_state, table, charsmax(table));

  new Trie:pstate;
  if (!TrieGetCell(g_player_states[pid], table, pstate))
    return;

  new Array:cols;
  if (!TrieGetCell(g_state_tables, table, cols))
    return;

  usql_set_table(table);

  new col_name[MAX_SQL_COLUMN_NAME_LENGTH + 1];
  get_string(param_field, col_name, charsmax(col_name));
  new col[SQLColumn];
  for (new i = 0, end = ArraySize(cols); i != end; ++i) {
    ArrayGetArray(cols, i, col);
    if (equal(col[sc_name], col_name)) {
      switch(col[sc_type]) {
        case sct_int: {
          new val = get_param(param_val);
          TrieSetCell(pstate, col_name, val);
          usql_update_ex(
            usql_sarray(col_name), usql_asarray(val), Array:-1, true, "",
            "`id`='%d'", g_sids[pid]
          );
        }
        case sct_float: {
          new Float:val = Float:get_param(param_val);
          TrieSetCell(pstate, col_name, val);
          usql_update_ex(
            usql_sarray(col_name), usql_fsarray(val), Array:-1, true, "",
            "`id`='%d'", g_sids[pid]
          );
        }
        case sct_varchar: {
          new val[MAX_SQL_COLUMN_VALUE_LENGTH + 1];
          get_string(param_val, val, charsmax(val));
          TrieSetString(pstate, col_name, val);
          usql_update_ex(
            usql_sarray(col_name), usql_sarray(val), Array:-1, true, "",
            "`id`='%d'", g_sids[pid]
          );
        }
      }
      break;
    }
  }

  usql_set_table(SQL_COMMON_TABLE);

  return;
}

/* SQL */

setup_sql()
{
  usql_cache_info(g_usql_host, g_usql_user, g_usql_pass, g_usql_db);
  usql_create_table(
    SQL_COMMON_TABLE, usql_2darray(g_sql_cols, sizeof(g_sql_cols), SQLColumn), "`static_id`"
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
    ULOG( \
      "state_core", INFO, pid, \
      "No record found for ^"@name^" (@id). Inserting new one. [IP: @ip] [AuthID: @authid]" \
    );

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
  usql_fetch_ex(
    usql_sarray("static_id", "nick"), true, "qcb_fetch_state", "`dynamic_id`='%s'", did
  );
}

parse_player_state(pid, Handle:handle)
{
  g_sids[pid] = SQL_ReadResult(handle, SQL_FieldNameToNum(handle, "static_id"));
  SQL_ReadResult(
    handle, SQL_FieldNameToNum(handle, "nick"), g_stored_names[pid], charsmax(g_stored_names[])
  );
  usql_desanitize(g_stored_names[pid], charsmax(g_stored_names[]));
}

load_state_table(pid, TrieIter:table_iter)
{
  new table[MAX_SQL_TABLE_NAME_LENGTH + 1];
  TrieIterGetKey(table_iter, table, charsmax(table));
  usql_set_table(table);
  usql_set_data(usql_array(pid, table_iter));
  usql_fetch_ex(Invalid_Array, true, "qcb_fetch_state_table", "`id`='%d'", g_sids[pid]);
  usql_set_table(SQL_COMMON_TABLE);
}

parse_state_table(pid, const table[], Array:cols, Handle:handle)
{
  new Trie:pstate;
  if (!TrieGetCell(g_player_states[pid], table, pstate))
    TrieSetCell(g_player_states[pid], table, pstate = TrieCreate());

  new col[SQLColumn];
  for (new i = 0, end = ArraySize(cols); i != end; ++i) {
    ArrayGetArray(cols, i, col);
    switch (col[sc_type]) {
      case sct_int: TrieSetCell(pstate, col[sc_name], SQL_ReadResult(handle, i));
      case sct_float: {
        new Float:val;
        SQL_ReadResult(handle, i, val);
        TrieSetCell(pstate, col[sc_name], val);
      }
      case sct_varchar: {
        new val[MAX_SQL_COLUMN_VALUE_LENGTH + 1];
        SQL_ReadResult(handle, i, val, charsmax(val));
        TrieSetString(pstate, col[sc_name], val);
      }
    }
  }
}

/* SQL > Query callbacks > General */

public usql_query_finished(SQLQuery:query, Handle:handle, bool:success, error[], errnum, data[], sz)
{
  if (!success)
    handle_error(handle, "G1", error, errnum);
}

/* SQL > Query callbacks > Other */

public qcb_fetch_state(SQLQuery:query, Handle:handle, bool:success, error[], errnum, data[], sz)
{
  if (!success) {
    handle_error(handle, "FS1", error, errnum);
    return;
  }

  enum {
    data_pid    = 0,
    data_call_n = 1
  };

  new pid = data[data_pid];
  if (SQL_NumResults(handle) > 0) {
    parse_player_state(pid, handle);
    if (TrieGetSize(g_state_tables) > 0) {
      if (!g_player_states[pid])
        g_player_states[pid] = TrieCreate();
      load_state_table(pid, TrieIterCreate(g_state_tables));
    } else {
      ExecuteForward(g_fwd_player_loaded, _, pid, g_sids[pid]);
    }
  } else {
    load_player_state(pid, data[data_call_n] + 1);
  }
}

public qcb_fetch_state_table(
  SQLQuery:query, Handle:handle, bool:success, error[], errnum, data[], sz
)
{
  enum {
    data_pid        = 0,
    data_table_iter = 1
  };

  new pid = data[data_pid];
  new TrieIter:table_iter = TrieIter:data[data_table_iter];

  if (!success) {
    handle_error(handle, "FST1", error, errnum);
  } else {
    new table[MAX_SQL_TABLE_NAME_LENGTH + 1];
    TrieIterGetKey(table_iter, table, charsmax(table));
    if (SQL_NumResults(handle) > 0) {
      new Array:cols;
      TrieIterGetCell(table_iter, cols);
      parse_state_table(pid, table, cols, handle);
    } else {
      usql_set_table(table);
      usql_insert(usql_sarray("id"), usql_asarray(g_sids[pid]));
      usql_set_table(SQL_COMMON_TABLE);
      /* Reload player now that a record for him has been inserted. */
      load_state_table(pid, table_iter);
      return;
    }
  }

  TrieIterNext(table_iter);
  if (!TrieIterEnded(table_iter)) {
    load_state_table(pid, table_iter);
  } else {
    TrieIterDestroy(table_iter);
    ExecuteForward(g_fwd_player_loaded, _, pid, g_sids[pid]);
  }
}

public qcb_update_did(SQLQuery:query, Handle:handle, bool:success, error[], errnum, data[], sz)
{
  /* Attempted DID was most likely blocked because a similar record already
   * exists. */
  if (!success) {
    enum { data_pid = 0 };
    new pid = data[data_pid];

    g_did_types[pid] = StateDynamicIDType:data[1];

    umenu_refresh(pid);

    console_print(pid, "%L", pid, "STATE_NAME_RESERVED");
    chat_print(pid, g_prefix, "%L", pid, "STATE_NAME_RESERVED");
  }
}

public qcb_change_nick(SQLQuery:query, Handle:handle, bool:success, error[], errnum, data[], sz)
{
  enum { data_pid = 0 };
  new pid = data[data_pid];
  if (success) {
    /* Attempted to change name to one that is used by someone else as a DID. */
    if (query == sq_fetch && SQL_NumResults(handle) > 0) {
      console_print(pid, "%L", pid, "STATE_NAME_RESERVED");
      chat_print(pid, g_prefix, "%L", pid, "STATE_NAME_RESERVED");
      /* Block name change. */
      get_user_name(pid, g_names[pid], charsmax(g_names[]));
      return;
    }

    /* Allow name change to proceed. */
    UBITS_PSET(g_forcing_name, pid);
    set_user_info(pid, "name", g_names[pid]);
  } else {
    if (query == sq_fetch) {
      handle_error(handle, "CN1", error, errnum);
      return;
    }

    /* Attempted name change (and, consequently, DID because this scenario
     * should only occur when DID type is `s_did_t_name`) was most likely
     * blocked because a record with an identical DID already exists. */
    get_user_name(pid, g_names[pid], charsmax(g_names[]));
    console_print(pid, "%L", pid, "STATE_NAME_RESERVED");
    chat_print(pid, g_prefix, "%L", pid, "STATE_NAME_RESERVED");

    handle_error(handle, "CN2", error, errnum);
  }
}

/* Helpers */

handle_error(
  Handle:handle, const err_id[], const sql_error[], sql_errnum, bool:inform_player = false
)
{
  new qstring[256 + 1];
  SQL_GetQueryString(handle, qstring, charsmax(qstring));
  ULOG( \
    "state_sql", ERROR, 0, \
    "Query failed (%s): %s [Error (%d): %s]", err_id, qstring, sql_errnum, sql_error \
  );

  if (inform_player) {
    /* TODO: inform player. */
  }
}