/*
 * TODO:
 *   - eventually, move most of this into `gunxp_swarm_sql.sma`. Doing so will
 *     necessitate rewriting some part of `utils_sql.sma` in order to
 *     accommodate multiple databases per plugin;
 *   - move aggro zone loading to `gunxp_swarm_config.sma`.
 */

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine>
#include <cellarray>
#include <fakemeta_util>

#include <gunxp_swarm>
#include <gunxp_swarm_const>

#include <state>

#include <team_balancer_skill>

#include <utils_sql>
#include <utils_sql_stocks>
#include <utils_log>
#include <utils_bits>

#define READ_SQL_RESULT(%0)         SQL_ReadResult(query, SQL_FieldNameToNum(query, #%0))
#define READ_SQL_SRESULT(%0,%1,%2)  SQL_ReadResult(query, SQL_FieldNameToNum(query, #%0), %1, %2)

#define INC_STAT(%0,%1) gxp_set_player_stat(%0, %1, gxp_get_player_stat(%0, %1) + 1)

#define AGGRO_ZONE_CLASSNAME "gxp_aggro_zone"

native afk_is_in_godmode(pid);

enum
{
  tid_check_aggression = 8753
};

enum KillContributor
{
  kc_pid = 0,
  Float:kc_dmg
};

new const g_cols[][SQLColumn] =
{
  { "id",             sct_int, 11, "0", true, false },
  { "kills",          sct_int, 16, "0", true, false },
  { "assists",        sct_int, 16, "0", true, false },
  { "weighted_kills", sct_int, 16, "0", true, false },
  { "deaths",         sct_int, 16, "0", true, false },
  { "hs",             sct_int, 16, "0", true, false },
  { "suicides",       sct_int, 16, "0", true, false },
  { "survivals",      sct_int, 16, "0", true, false },
  { "playtime",       sct_int, 16, "0", true, false }
};

new g_fwd_int_player_loaded;

new bool:g_aggro_zones_exist;
new g_aggro_zone_num;
new g_aggro_min_players = 5;
new g_aggro_min_zm_in_zones = 2;
new Array:g_survivors_aggroing;

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

  /* Forwards > Engine */

  register_think(AGGRO_ZONE_CLASSNAME, "gxp_aggro_zone_think");

  /* Forwards > GunXP */

  g_fwd_int_player_loaded = CreateMultiForward("_gxp_stats_player_loaded", ET_IGNORE, FP_CELL);

  /* Loggers */

  ulog_register_logger("gxp_stats", "gunxp_swarm");

  /* Miscellaneous */

  load_aggro_zones();
}

public plugin_end()
{
  DestroyForward(g_fwd_int_player_loaded);
  ArrayDestroy(g_survivors_aggroing);
}

/* Forwards > Engine */

public gxp_aggro_zone_think(eid)
{
  set_pev(eid, pev_nextthink, get_gametime() + 1.0);

  if (!gxp_has_game_started() || gxp_has_round_ended())
    return;

  new total_players = get_playersnum_ex(GetPlayers_ExcludeHLTV | GetPlayers_MatchTeam, "TERRORIST")
    + get_playersnum_ex(GetPlayers_ExcludeHLTV | GetPlayers_MatchTeam, "CT");
  if (total_players < g_aggro_min_players)
    return;

  static zid = 0;
  static zm_in_zones = 0;
  static in_zone = 0;

  for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid) {
    if (!is_user_connected(pid) || !is_user_alive(pid))
      continue;

    if (GxpTeam:gxp_get_player_data(pid, pd_team) == tm_zombie) {
      if (!UBITS_PCHECK(in_zone, pid) && entity_intersects(pid, eid)) {
        ++zm_in_zones;
        UBITS_PSET(in_zone, pid);
      }
    } else if (!is_user_bot(pid)) {
      if (zid == 0)
        INC_STAT(pid, gxp_pstats_playtime_ct);
      if (!UBITS_PCHECK(in_zone, pid) && entity_intersects(pid, eid)) {
        ArrayPushCell(g_survivors_aggroing, pid);
        UBITS_PSET(in_zone, pid);
      }
    }
  }

  if (++zid >= g_aggro_zone_num) {
    zid = 0;

    if (zm_in_zones >= g_aggro_min_zm_in_zones) {
      for (new i = 0, end = ArraySize(g_survivors_aggroing); i != end; ++i) {
        new pid = ArrayGetCell(g_survivors_aggroing, i);
        if (is_user_connected(pid))
          INC_STAT(pid, gxp_pstats_aggro_time);
      }
    }

    ArrayClear(g_survivors_aggroing);
    in_zone = 0;
    zm_in_zones = 0;
  }
}

/* Forwards > GunXP */

public gxp_player_killed(pid, pid_killer, bool:hs, Array:contributors)
{
  INC_STAT(pid, gxp_pstats_deaths);

  new max_hp = gxp_get_max_hp(pid);
  new kc[GxpKillContributor];
  for (new i = 0, end = ArraySize(contributors); i != end; ++i) {
    ArrayGetArray(contributors, i, kc);
    if (kc[gxp_kc_pid] != pid_killer && kc[gxp_kc_dmg]/max_hp > 0.49)
      INC_STAT(kc[gxp_kc_pid], gxp_pstats_assists);
  }

  if (pid != pid_killer) {
    INC_STAT(pid_killer, gxp_pstats_kills);

    /* Use internal skill for reasons outlined in
     * `gunxp_swarm.sma::compute_skill()`. */
    new Float:skill_killer = Float:gxp_get_player_data(pid_killer, pd_skill);
    new Float:skill_victim = Float:gxp_get_player_data(pid, pd_skill);

    new Float:wkill = 1.0;
    if (GxpTeam:gxp_get_player_data(pid_killer, pd_team) == tm_zombie) {
      new total_players =
        get_playersnum_ex(GetPlayers_ExcludeHLTV | GetPlayers_MatchTeam, "TERRORIST")
        + get_playersnum_ex(GetPlayers_ExcludeHLTV | GetPlayers_MatchTeam, "CT");

      /* Killing someone as a zombie generally requires significantly more
       * effort, so weigh the kill only if the killer is presumed to be weaker,
       * or there are few players (meaning, there isn't much resistance, and so
       * it's not that difficult for a skilled player to kill a survivor).
       *
       * TODO: should probably also consider avoiding scaling when killer is the
       *       only person on the team. */
      if (skill_killer < skill_victim || total_players <= 4)
        wkill = skill_victim/skill_killer;
      /* For the aforementioned reason of it being more strenuous when playing
       * as a zombie, increase the weight of the kill. */
      if (total_players >= 4)
        wkill += 3.0;
    /* On the other hand, a skilled player won't have much difficulty playing as a survivor (at
     * least, more so than not), no matter the player count.
     * This also means that weaker players will always benefit when playing as survivors. */
    } else {
      wkill = skill_victim/skill_killer;
    }
    new Float:wkills = Float:gxp_get_player_stat(pid_killer, gxp_pstats_weighted_kills);
    gxp_set_player_stat(pid_killer, gxp_pstats_weighted_kills, wkills + wkill);

    if (hs)
      INC_STAT(pid_killer, gxp_pstats_hs);
  } else {
    INC_STAT(pid, gxp_pstats_suicides);
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
  gxp_set_player_stat(pid, gxp_pstats_kills,          READ_SQL_RESULT(kills));
  gxp_set_player_stat(pid, gxp_pstats_assists,        READ_SQL_RESULT(assists));
  gxp_set_player_stat(pid, gxp_pstats_weighted_kills, float(READ_SQL_RESULT(weighted_kills)));
  gxp_set_player_stat(pid, gxp_pstats_deaths,         READ_SQL_RESULT(deaths));
  gxp_set_player_stat(pid, gxp_pstats_hs,             READ_SQL_RESULT(hs));
  gxp_set_player_stat(pid, gxp_pstats_suicides,       READ_SQL_RESULT(suicides));
  gxp_set_player_stat(pid, gxp_pstats_playtime,       READ_SQL_RESULT(playtime));
  gxp_set_player_stat(pid, gxp_pstats_playtime_ct,    READ_SQL_RESULT(playtime_ct));
  gxp_set_player_stat(pid, gxp_pstats_aggro_time,     READ_SQL_RESULT(aggression_time));
}

save_player(pid, sid)
{
  usql_set_table(_GXP_SWARM_SQL_STATS_TABLE);
  usql_update_ex(
    usql_sarray(
      "kills",
      "assists",
      "weighted_kills",
      "deaths",
      "hs",
      "suicides",
      "playtime",
      "playtime_ct",
      "aggression_time"
    ),
    usql_asarray(
      gxp_get_player_stat(pid, gxp_pstats_kills),
      gxp_get_player_stat(pid, gxp_pstats_assists),
      floatround(Float:gxp_get_player_stat(pid, gxp_pstats_weighted_kills)),
      gxp_get_player_stat(pid, gxp_pstats_deaths),
      gxp_get_player_stat(pid, gxp_pstats_hs),
      gxp_get_player_stat(pid, gxp_pstats_suicides),
      gxp_get_player_stat(pid, gxp_pstats_playtime),
      gxp_get_player_stat(pid, gxp_pstats_playtime_ct),
      gxp_get_player_stat(pid, gxp_pstats_aggro_time)
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

/* Helpers */

load_aggro_zones()
{
  g_survivors_aggroing = ArrayCreate();

  new INIParser:ini_parser = INI_CreateParser();
  INI_SetReaders(ini_parser, "az_kv_callback", "az_ns_callback");

  new configsdir[PLATFORM_MAX_PATH + 1];
  get_configsdir(configsdir, charsmax(configsdir));
  add(configsdir, charsmax(configsdir), "/gunxp_swarm/aggression.ini");
  INI_ParseFile(ini_parser, configsdir);

  INI_DestroyParser(ini_parser);
}

public az_ns_callback(
  INIParser:handle,
  const section[],
  bool:invalid_tokens, bool:close_bracket, bool:extra_tokens, curtok,
  any:data
)
{
  new mapname[MAX_MAPNAME_LENGTH + 1];
  get_mapname(mapname, charsmax(mapname));
  if (equal(section, mapname))
    g_aggro_zones_exist = true;
  else if (g_aggro_zones_exist)
    return false;
  return true;
}

public az_kv_callback(
  INIParser:handle,
  const key[], const value[],
  bool:invalid_tokens, bool:equal_token, bool:quotes, curtok,
  any:data
)
{
  if (!g_aggro_zones_exist)
    return true;

  if (equal(key, "players")) {
    g_aggro_min_players = str_to_num(value);
  } else if (equal(key, "zm_in_zones")) {
    g_aggro_min_zm_in_zones = str_to_num(value);
  } else {
    new rhs[512 + 1];
    new lhs[10 + 1];
    copy(rhs, charsmax(rhs), value);

    new Float:origin[3];
    new Float:mins[3];
    new Float:maxs[3];

#define AZ_PARSE_FLOAT(%0) \
  strtok2(rhs, lhs, charsmax(lhs), rhs, charsmax(rhs)); \
  %0 = str_to_float(lhs)

    // 927.3 -774.4 -19.9 -137.0 -147.0 -82.0 137.0 147.0 82.0
    AZ_PARSE_FLOAT(origin[0]);
    AZ_PARSE_FLOAT(origin[1]);
    AZ_PARSE_FLOAT(origin[2]);
    AZ_PARSE_FLOAT(mins[0]);
    AZ_PARSE_FLOAT(mins[1]);
    AZ_PARSE_FLOAT(mins[2]);
    AZ_PARSE_FLOAT(maxs[0]);
    AZ_PARSE_FLOAT(maxs[1]);
    AZ_PARSE_FLOAT(maxs[2]);

    new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
    if (!ent)
      return false;

    set_pev(ent, pev_classname, AGGRO_ZONE_CLASSNAME);
    set_pev(ent, pev_model, "models/gib_skull.mdl");
    set_pev(ent, pev_origin, origin);
    set_pev(ent, pev_solid, SOLID_NOT);
    set_pev(ent, pev_movetype, MOVETYPE_FLY);
    set_pev(ent, pev_mins, mins);
    set_pev(ent, pev_maxs, maxs);
    set_pev(ent, pev_nextthink, get_gametime() + 1.0);

    ++g_aggro_zone_num;
  }

  return true;
}
