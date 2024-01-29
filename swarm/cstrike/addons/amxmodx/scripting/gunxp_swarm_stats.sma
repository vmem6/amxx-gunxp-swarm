/*
 * TODO:
 *   - eventually, move most of this into `gunxp_swarm_sql.sma`. Doing so will
 *     necessitate rewriting some part of `utils_sql.sma` in order to
 *     accommodate multiple databases per plugin.
 */

#include <amxmodx>
#include <amxmisc>
#include <cellarray>

#include <gunxp_swarm>
#include <gunxp_swarm_const>

#include <state>

#include <utils_sql>
#include <utils_sql_stocks>

#define READ_SQL_RESULT(%0)         SQL_ReadResult(query, SQL_FieldNameToNum(query, #%0))
#define READ_SQL_SRESULT(%0,%1,%2)  SQL_ReadResult(query, SQL_FieldNameToNum(query, #%0), %1, %2)

#define INC_STAT(%0,%1) gxp_set_player_stat(%0, %1, gxp_get_player_stat(%0, %1) + 1)

new const g_cols[][SQLColumn] =
{
  { "id",         sct_int, 11, "0", true, false },
  { "kills",      sct_int, 16, "0", true, false },
  { "deaths",     sct_int, 16, "0", true, false },
  { "hs",         sct_int, 16, "0", true, false },
  { "suicides",   sct_int, 16, "0", true, false },
  { "survivals",  sct_int, 16, "0", true, false },
  { "playtime",   sct_int, 16, "0", true, false }
};

new g_fwd_int_player_loaded;

public plugin_natives()
{
  register_library("gxp_swarm_stats");

  register_native("_gxp_stats_set_up", "native_set_up");
  register_native("_gxp_stats_load_player", "native_load_player");
  register_native("_gxp_stats_save_player", "native_save_player");
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_STATS_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* CVars */

  USQL_REGISTER_CVARS(gxp_swarm_stats);

  /* Forwards */

  g_fwd_int_player_loaded = CreateMultiForward("_gxp_stats_player_loaded", ET_IGNORE, FP_CELL);

  /* Events */

  register_event_ex("DeathMsg", "event_deathmsg", RegisterEvent_Global);
}

public plugin_end()
{
  DestroyForward(g_fwd_int_player_loaded);
}

/* Events */

public event_deathmsg()
{
  enum {
    data_killer = 1,
    data_victim = 2,
    data_hs     = 3
  };

  new pid_killer = read_data(data_killer);
  new pid_victim = read_data(data_victim);

  INC_STAT(pid_victim, gxp_pstats_deaths);

  if (pid_killer != pid_victim) {
    INC_STAT(pid_killer, gxp_pstats_kills);
    if (read_data(data_hs) == 1)
      INC_STAT(pid_killer, gxp_pstats_hs);
  } else {
    INC_STAT(pid_killer, gxp_pstats_suicides);
  }
}

/* SQL */

load_player(pid, sid)
{
  usql_set_table(_GXP_SWARM_SQL_STATS_TABLE);
  usql_set_data(usql_array(pid, sid));
  usql_fetch_ex(Invalid_Array, true, "`id`='%d'", sid);
}

parse_player_data(pid, Handle:query)
{
  gxp_set_player_stat(pid, gxp_pstats_kills,    READ_SQL_RESULT(kills));
  gxp_set_player_stat(pid, gxp_pstats_deaths,   READ_SQL_RESULT(deaths));
  gxp_set_player_stat(pid, gxp_pstats_hs,       READ_SQL_RESULT(hs));
  gxp_set_player_stat(pid, gxp_pstats_playtime, READ_SQL_RESULT(playtime));
}

save_player(pid, sid)
{
  usql_set_table(_GXP_SWARM_SQL_STATS_TABLE);
  usql_update_ex(
    usql_sarray(
      "kills",
      "deaths",
      "hs",
      "suicides",
      "playtime"
    ),
    usql_asarray(
      gxp_get_player_stat(pid, gxp_pstats_kills),
      gxp_get_player_stat(pid, gxp_pstats_deaths),
      gxp_get_player_stat(pid, gxp_pstats_hs),
      gxp_get_player_stat(pid, gxp_pstats_suicides),
      gxp_get_player_stat(pid, gxp_pstats_playtime)
    ),
    Array:-1,
    true,
    "`id`='%d'", sid
  );
}

public usql_query_finished(SQLQuery:query, Handle:handle, bool:success, error[], errnum, data[], sz)
{
  if (!success) {
    /* TODO: log and inform player. */
    return;
  }

  if (query != sq_fetch)
    return;

  new pid = data[0];
  new sid = data[1];

  if (SQL_NumResults(handle) > 0) {
    parse_player_data(pid, handle);
    ExecuteForward(g_fwd_int_player_loaded, _, pid);
  } else {
    usql_insert(usql_sarray("id"), usql_asarray(sid));
    load_player(pid, sid);
  }
}

/* Natives */

public native_set_up(plugin, argc)
{
  usql_cache_info(g_usql_host, g_usql_user, g_usql_pass, g_usql_db);
  usql_create_table(
    _GXP_SWARM_SQL_STATS_TABLE, usql_2darray(g_cols, sizeof(g_cols), SQLColumn), "`id`"
  );
}

public native_load_player(plugin, argc)
{
  enum { param_pid = 1 };
  new pid = get_param(param_pid);
  load_player(pid, state_get_player_sid(pid));
}

public native_save_player(plugin, argc)
{
  enum { param_pid = 1 };
  new pid = get_param(param_pid);
  save_player(pid, state_get_player_sid(pid));
}
