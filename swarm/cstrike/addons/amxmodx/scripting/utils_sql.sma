#include <amxmodx>
#include <cellarray>
#include <sqlx>

#include <utils_sql_stocks>
#include <utils_sql_const>

#define MAX_PLUGINS 512

#define MAX_QUERY_LENGTH 1536

enum Plugin
{
  Handle:plg_tuple,
  plg_data[MAX_SQL_DATA_SIZE],
  plg_data_sz,
  plg_table[MAX_SQL_TABLE_NAME_LENGTH + 1],
  plg_query_fwd
}

new g_plugins[MAX_PLUGINS][Plugin];

new g_query[MAX_QUERY_LENGTH + 1];

public plugin_natives()
{
  register_library("utils_sql");

  register_native("usql_cache_info", "native_cache_info");
  register_native("usql_set_data", "native_set_data");
  register_native("usql_query", "native_query");
  register_native("usql_create_table", "native_create_table");
  register_native("usql_set_table", "native_set_table");
  register_native("usql_fetch", "native_fetch");
  register_native("usql_insert", "native_insert");
  register_native("usql_update", "native_update");
}

public plugin_init()
{
  // TODO: register_plugin(...);

  /* Miscellaneous */

  for (new i = 0; i != sizeof(g_plugins); ++i) {
    g_plugins[i][plg_tuple] = Handle:INVALID_HANDLE;
    g_plugins[i][plg_query_fwd] = INVALID_HANDLE;
  }
}

public plugin_end()
{
  for (new i = 0; i != MAX_PLUGINS; ++i) {
    if (_:g_plugins[i][plg_tuple] != INVALID_HANDLE) {
      DestroyForward(g_plugins[i][plg_query_fwd]);
      SQL_FreeHandle(g_plugins[i][plg_tuple]);
    }
  }
}

/* Natives */

public bool:native_cache_info(plugin, argc)
{
  if (_:g_plugins[plugin][plg_tuple] != INVALID_HANDLE) {
    SQL_FreeHandle(g_plugins[plugin][plg_tuple]);
    DestroyForward(g_plugins[plugin][plg_query_fwd]);
  }

  enum {
    param_host = 1,
    param_user = 2,
    param_pass = 3,
    param_db = 4
  };

  new host[MAX_SQL_HOSTNAME_LENGTH + 1];
  new user[MAX_SQL_USER_NAME_LENGTH + 1];
  new pass[MAX_SQL_PASSWORD_LENGTH + 1];
  new db[MAX_SQL_DATABASE_NAME_LENGTH + 1];

  get_string(param_host, host, charsmax(host));
  get_string(param_user, user, charsmax(user));
  get_string(param_pass, pass, charsmax(pass));
  get_string(param_db, db, charsmax(db));

  g_plugins[plugin][plg_tuple] = SQL_MakeDbTuple(host, user, pass, db);
  SQL_SetCharset(g_plugins[plugin][plg_tuple], "utf8");
  if (_:g_plugins[plugin][plg_tuple] != INVALID_HANDLE) {
    g_plugins[plugin][plg_query_fwd] = CreateOneForward(
      plugin,
      "usql_query_finished",
      FP_CELL, FP_CELL, FP_CELL, FP_STRING, FP_CELL, FP_ARRAY, FP_CELL
    );
    return true;
  }

  return false;
}

public native_set_data(plugin, argc)
{
  enum {
    param_data    = 1,
    param_cleanup = 2
  };

  new Array:data = Array:get_param(param_data);
  for (new i = 0; i != ArraySize(data); ++i)
    g_plugins[plugin][plg_data][i] = ArrayGetCell(data, i);
  g_plugins[plugin][plg_data_sz] = ArraySize(data);

  if (bool:get_param(param_cleanup))
    ArrayDestroy(data);
}

public native_query(plugin, argc)
{
  /* TODO: ensure `plg_tuple` is initialized and valid. */

  enum { param_query = 1 };
  get_string(param_query, g_query, charsmax(g_query));
  exec_query(sq_query, plugin);
}

public bool:native_create_table(plugin, argc)
{
  if (_:g_plugins[plugin][plg_tuple] == INVALID_HANDLE)
    return false;

  enum {
    param_table     = 1,
    param_columns   = 2,
    param_pkey      = 3,
    param_cleanup   = 4
  };

  new table[MAX_SQL_TABLE_NAME_LENGTH + 1];
  get_string(param_table, table, charsmax(table));

  formatex(g_query, charsmax(g_query), "CREATE TABLE IF NOT EXISTS `%s` (", table);

  /* Add columns. */
  new buf[MAX_SQL_COLUMN_VALUE_LENGTH * 2 + 1];
  new column[SQLColumn];
  new Array:columns = Array:get_param(param_columns);
  for (new i = 0; i != ArraySize(columns); ++i) {
    ArrayGetArray(columns, i, column);

    new def_val[MAX_SQL_COLUMN_VALUE_LENGTH + 1];
    if (column[sc_type] == sct_int)
      formatex(def_val, charsmax(def_val), "%d", strtol(column[sc_def_val]));
    else
      formatex(def_val, charsmax(def_val), "^"%s^"", column[sc_def_val]);

    formatex(
      buf, charsmax(buf),
      "`%s` %s(%d) ",
      column[sc_name],
      column[sc_type] == sct_int ? "int" : "varchar",
      column[sc_size]
    );
    add(g_query, charsmax(g_query), buf);

    if (!column[sc_auto_increment]) {
      formatex(buf, charsmax(buf), "DEFAULT %s ", def_val);
      add(g_query, charsmax(g_query), buf);
    }

    formatex(
      buf, charsmax(buf), "%s %s, ",
      column[sc_not_null] ? "NOT NULL" : "",
      column[sc_auto_increment] ? "AUTO_INCREMENT" : ""
    );
    add(g_query, charsmax(g_query), buf);
  }

  /* Append primary key. */
  get_string(param_pkey, buf, charsmax(buf));
  add(g_query, charsmax(g_query), "PRIMARY KEY (");
  add(g_query, charsmax(g_query), buf);

  /* Set engine and default charset. */
  add(g_query, charsmax(g_query), ")) ENGINE=INNODB DEFAULT CHARSET=utf8mb4;");

  exec_query(sq_create_table, plugin);

  /* Cache new table. */
  copy(g_plugins[plugin][plg_table], charsmax(g_plugins[][plg_table]), table);

  if (bool:get_param(param_cleanup))
    ArrayDestroy(columns);

  return true;
}

public native_set_table(plugin, argc)
{
  enum { param_table = 1 };

  new table[MAX_SQL_TABLE_NAME_LENGTH + 1];
  get_string(param_table, table, charsmax(table));
  copy(g_plugins[plugin][plg_table], charsmax(g_plugins[][plg_table]), table);
}

public native_fetch(plugin, argc)
{
  /* TODO: ensure `plg_tuple` is initialized and valid. */

  enum {
    param_columns = 1,
    param_cond    = 2,
    param_cleanup = 3
  };

  copy(g_query, charsmax(g_query), "SELECT ");

  /* Populate columns. */
  new Array:columns = Array:get_param(param_columns);
  if (columns == Invalid_Array)
    add(g_query, charsmax(g_query), "* ");
  else
    populate_field(columns, .outer_casing = false, .inner_casing = "`");

  /* Specify table. */
  add(g_query, charsmax(g_query), "FROM ");
  add(g_query, charsmax(g_query), g_plugins[plugin][plg_table]);

  /* Set condition. */
  new cond[MAX_SQL_CONDITION_LENGTH + 1];
  get_string(param_cond, cond, charsmax(cond));
  if (cond[0] != '^0') {
    add(g_query, charsmax(g_query), " WHERE ");
    add(g_query, charsmax(g_query), cond);
  }

  exec_query(sq_fetch, plugin);

  if (bool:get_param(param_cleanup))
    ArrayDestroy(columns);
}

public native_insert(plugin, argc)
{
  enum {
    param_columns = 1,
    param_values  = 2,
    param_cleanup = 3
  };

  new Array:values = Array:get_param(param_values);
  if (ArraySize(values) == 0) {
    /* TODO: return false. */
    return;
  }

  /* Set up query base. */
  formatex(g_query, charsmax(g_query), "INSERT INTO `%s` ", g_plugins[plugin][plg_table]);

  /* Populate columns. */
  new Array:columns = Array:get_param(param_columns);
  if (ArraySize(columns) > 0)
    populate_field(columns);

  /* Populate values. */
  add(g_query, charsmax(g_query), "VALUES ");
  populate_field(values, .inner_casing = "'");
  add(g_query, charsmax(g_query), ";");

  exec_query(sq_insert, plugin);

  if (bool:get_param(param_cleanup)) {
    ArrayDestroy(columns);
    ArrayDestroy(values);
  }
}

public native_update(plugin, argc)
{
  enum {
    param_columns = 1,
    param_nvalues = 2,
    param_svalues = 3,
    param_cond    = 4,
    param_cleanup = 5
  };

  new Array:columns = Array:get_param(param_columns);
  new Array:nvalues = Array:get_param(param_nvalues);
  new Array:svalues = Array:get_param(param_svalues);
  new colsz = ArraySize(columns);
  new nvalsz = ArraySize(nvalues);
  new svalsz = svalues == Array:-1 ? 0 : ArraySize(svalues);
  if (colsz == 0 || nvalsz == 0 || colsz != (nvalsz + svalsz)) {
    /* TODO: return false. */
    return;
  }

  new cond[MAX_SQL_CONDITION_LENGTH + 1];
  get_string(param_cond, cond, charsmax(cond));
  if (cond[0] == '^0') {
    /* TODO: return false. */
    return;
  }

  /* Set up query base. */
  formatex(g_query, charsmax(g_query), "UPDATE `%s` SET ", g_plugins[plugin][plg_table]);

  /* Populate "SET". */
  new col[MAX_SQL_COLUMN_NAME_LENGTH + 1];
  new val[MAX_SQL_COLUMN_VALUE_LENGTH + 1];
  new buf[1 + MAX_SQL_COLUMN_NAME_LENGTH + 1 + 1 + 1 + MAX_SQL_COLUMN_VALUE_LENGTH + 1 + 1];
  for (new i = 0; i != colsz; ++i) {
    ArrayGetString(columns, i, col, charsmax(col));
    i < nvalsz
      ? ArrayGetString(nvalues, i, val, charsmax(val))
      : ArrayGetString(svalues, i - nvalsz, val, charsmax(val));
    formatex(buf, charsmax(buf), "`%s`='%s'%s", col, val, i != colsz - 1 ? "," : " ");
    add(g_query, charsmax(g_query), buf);
  }

  /* Set condition. */
  add(g_query, charsmax(g_query), "WHERE ");
  add(g_query, charsmax(g_query), cond);
  add(g_query, charsmax(g_query), ";");

  exec_query(sq_update, plugin);

  if (bool:get_param(param_cleanup)) {
    ArrayDestroy(columns);
    ArrayDestroy(nvalues);
    ArrayDestroy(svalues);
  }
}

/* Query handler */

public handle_query(failstate, Handle:query, error[], errnum, data[], sz, Float:queuetime)
{
  new fwd = g_plugins[data[1]][plg_query_fwd];
  if (fwd != INVALID_HANDLE) {
    new t_query = data[0];
    sz -= 2;
    for (new i = 0; i != sz; ++i)
      data[i] = data[i + 2];
    ExecuteForward(
      fwd, _, t_query, query, failstate == TQUERY_SUCCESS, error, errnum, PrepareArray(data, sz), sz
    );
    /* TODO: clear global data? */
  }
}

/* Helpers */

exec_query(SQLQuery:query, plugin)
{
  new data[sizeof(g_plugins[][plg_data]) + 2];
  data[0] = _:query;
  data[1] = plugin;
  for (new i = 0; i != g_plugins[plugin][plg_data_sz]; ++i)
    data[i + 2] = g_plugins[plugin][plg_data][i];
  SQL_ThreadQuery(
    g_plugins[plugin][plg_tuple], "handle_query", g_query, data, g_plugins[plugin][plg_data_sz] + 2
  );
}

populate_field(
  Array:src, bool:outer_casing = true, const inner_casing[] = "^0", const sep[] = ","
)
{
  new buf[MAX_SQL_COLUMN_VALUE_LENGTH + 1];

  if (outer_casing)
    add(g_query, charsmax(g_query), "(");

  for (new i = 0; i != ArraySize(src); ++i) {
    if (inner_casing[0] != '^0')
      add(g_query, charsmax(g_query), inner_casing);
    ArrayGetString(src, i, buf, charsmax(buf));
    add(g_query, charsmax(g_query), buf);
    if (inner_casing[0] != '^0')
      add(g_query, charsmax(g_query), inner_casing);
    if (i != ArraySize(src) - 1)
      add(g_query, charsmax(g_query), sep);
  }

  if (outer_casing)
    add(g_query, charsmax(g_query), ") ");
  else
    add(g_query, charsmax(g_query), " ");
}