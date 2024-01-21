#if defined _UTILS_SQL_INC
  #endinput
#endif
#define _UTILS_SQL_INC

#include <amxmodx>
#include <sqlx>

#include <utils_sql_const>

/* Macros */

/*
 * Defines (global) variables for storing SQL pCVar values in.
 */
#define USQL_DEFINE_VARS() \
  new g_pcvar_sql_host; \
  new g_pcvar_sql_user; \
  new g_pcvar_sql_pass; \
  new g_pcvar_sql_db;

/*
 * Registers necessary CVars for connecting to SQL server:
 *   - hostname;
 *   - username;
 *   - password;
 *   - database;
 *   - database table.
 * 
 * @param %0          CVar prefix.
 */
#define USQL_REGISTER_CVARS(%0) \
  g_pcvar_sql_host    = register_cvar(#%0+"_sql_host", "127.0.0.1", FCVAR_PROTECTED); \
  g_pcvar_sql_user    = register_cvar(#%0+"_sql_user", "root", FCVAR_PROTECTED); \
  g_pcvar_sql_pass    = register_cvar(#%0+"_sql_pass", "pass", FCVAR_PROTECTED); \
  g_pcvar_sql_db      = register_cvar(#%0+"_sql_db", "db", FCVAR_PROTECTED);

/*
 * Fetches the values of SQL CVars registered through `SQL_REGISTER_CVARS`.
 */
#define USQL_FETCH_CVARS() \
  new _host[MAX_SQL_HOSTNAME_LENGTH + 1]; \
  new _user[MAX_SQL_USER_NAME_LENGTH + 1]; \
  new _pass[MAX_SQL_PASSWORD_LENGTH + 1]; \
  new _db[MAX_SQL_DATABASE_NAME_LENGTH + 1]; \
  get_pcvar_string(g_pcvar_sql_host, _host, charsmax(_host)); \
  get_pcvar_string(g_pcvar_sql_user, _user, charsmax(_user)); \
  get_pcvar_string(g_pcvar_sql_pass, _pass, charsmax(_pass)); \
  get_pcvar_string(g_pcvar_sql_db, _db, charsmax(_db));

/* Natives */

/*
 * Caches SQL info. for use in future queries.
 *
 * @param host            Hostname of SQL server.
 * @param user            Username of user that can access `db` database.
 * @param pass            Password of user that can access `db` database.
 * @param db              Database name.
 *
 * @return                `true` if provided info. was successfully cached; `false` otherwise.
 */
native bool:usql_cache_info(const host[], const user[], const pass[], const db[]);

/*
 * Sets per-plugin data that will be passed to the handler of the next query
 * issued by a plugin.
 *
 * @param data             Data to be passed to the query handler.
 * @param cleanup          Whether to free memory allocated to `data`.
 *
 * @noreturn
 */
native usql_set_data(Array:data, bool:cleanup = true);

/*
 * Executes custom query.
 * `query` must be sanitized beforehand.
 *
 * @param query           Query to be executed.
 *
 * @return                Query handle.
 */
native usql_query(const query[]);

/*
 * Creates a table using `columns` if it does not yet exist.
 * Additionally, caches said table for future use.
 *
 * @param table            Name of table that should be created.
 * @param columns          Dynamic array of `SQLColumn`s that determines the table structure.
 * @param pkey             Name of primary key/-s.
 * @param cleanup          Whether to free memory allocated to `columns`.
 *
 * @return                 `true` if query was submitted for execution; `false` otherwise.
 */
native bool:usql_create_table(const table[], Array:columns, const pkey[], bool:cleanup = true);

/*
 * Changes cached table to specified one.
 *
 * @param table          Name of table that should replace the cached one.
 *
 * @noreturn
 */
native usql_set_table(const table[]);

/*
 * Fetches `cols` from table that satisfy `cond`.
 * If `table` is left unspecified, uses cached table.
 * All data must be sanitized beforehand.
 *
 * @param columns          Columns of records to fetch. If unspecified, fetches all columns.
 * @param cond             Condition that `columns` must satisfy in order to be retrieved. If unspecified, fetches all `columns`.
 * @param cleanup          Whether to free memory allocated to `columns`.
 *
 * @noreturn
 */
native usql_fetch(Array:columns = Invalid_Array, const cond[] = "", bool:cleanup = true);

/*
 * Inserts a new record with `values` for `columns.`
 * All data must be sanitized beforehand.
 *
 * @param columns          Columns for which to provide an explicit value.
 * @param values           Values to use for `columns`.
 * @param cleanup          Whether to free memory allocated to `columns` and `values`.
 *
 * @noreturn
 */
native usql_insert(Array:columns, Array:values, bool:cleanup = true);

/*
 * Updates a record that satisfies `cond`.
 * The combined sizes of `nvalues` and `svalues` must match that of `columns`.
 * All data must be sanitized beforehand.
 *
 * @param columns          Columns to update. Size must match that of `values`.
 * @param nvalues          Numeric values to which to set columns to.
 * @param svalues          String values to which to set columns to. Corresponding columns must be trailing.
 * @param cond             Condition that record must satisfy in order to be updated.
 * @param cleanup          Whether to free memory allocated to `columns` and `values`.
 *
 * @noreturn
 */
native usql_update(Array:columns, Array:nvalues, Array:svalues, const cond[], bool:cleanup = true);

/* Forwards */

/*
 * Called when SQL server responds to query.
 *
 * @param query            SQL query type.
 * @param handle           SQL query handle.
 * @param success          Whether the query was successfully executed.
 * @param error            If an error occurred, the error message; empty otherwise.
 * @param errnum           If an error occurred, the error code; 0 otherwise.
 * @param data             Data passed by query invoker.
 * @param sz               Size of `data`.
 *
 * @noreturn
 */
forward usql_query_finished(SQLQuery:query, Handle:handle, bool:success, error[], errnum, data[], sz);