#include <amxmodx>
#include <cellarray>

#include <gunxp_swarm>
#include <gunxp_swarm_stats>
#include <gunxp_swarm_const>

#include <state>

#include <utils_sql>
#include <utils_sql_stocks>
#include <utils_string>

/* TODO: remove this at some point. */
#include "l4d.inl"

#define READ_SQL_RESULT(%0)         SQL_ReadResult(query, SQL_FieldNameToNum(query, #%0))
#define READ_SQL_SRESULT(%0,%1,%2)  SQL_ReadResult(query, SQL_FieldNameToNum(query, #%0), %1, %2)

enum SQLState
{
  st_load_base = 0,
  st_load_powers
};

new const g_player_cols[][SQLColumn] =
{
  { "id",             sct_int,     11, "0", true, false },
  { "xp_curr",        sct_int,     16, "0", true, false },
  { "xp_bought",      sct_int,     16, "0", true, false },
  { "level",          sct_int,     8,  "0", true, false },
  { "prs_stored",     sct_int,     16, "0", true, false },
  { "prs_used",       sct_int,     16, "0", true, false },
  { "prs_bought",     sct_int,     16, "0", true, false },
  { "primary_gun",    sct_int,     5,  "6", true, false },
  { "secondary_gun",  sct_int,     5,  "0", true, false },
  { "remember_sel",   sct_int,     2,  "0", true, false }
};

new const g_power_cols[][SQLColumn] =
{
  { "id",                 sct_int,     11,  "0", true, false },
  { "speed",              sct_int,     5,   "0", true, false },
  { "respawn_chance",     sct_int,     5,   "0", true, false },
  { "base_hp",            sct_int,     5,   "0", true, false },
  { "damage",             sct_int,     5,   "0", true, false },
  { "gravity",            sct_int,     5,   "0", true, false },
  { "hp_regen",           sct_int,     5,   "0", true, false },
  { "bonus_xp",           sct_int,     5,   "0", true, false },
  { "explosion_dmg",      sct_int,     5,   "0", true, false },
  { "he_regen",           sct_int,     5,   "0", true, false },
  { "sg_regen",           sct_int,     5,   "0", true, false },
  { "shooting_interval",  sct_int,     5,   "0", true, false },
  { "fall_dmg",           sct_int,     5,   "0", true, false },
  { "jump_bomb_chance",   sct_int,     5,   "0", true, false },
  { "jump_bomb_dmg",      sct_int,     5,   "0", true, false },
  { "zm_add_health",      sct_int,     5,   "0", true, false },
  { "vaccines",           sct_int,     5,   "0", true, false },
  /* Default value generated dynamically. */
  { "chosen_vaccines",    sct_varchar, 128, "",  true, false }
};

new Array:g_queued_players;

new g_fwd_player_data_loaded;

public plugin_natives()
{
  register_library("gxp_swarm_sql");

  register_native("_gxp_sql_set_up", "native_set_up");
  register_native("_gxp_sql_load_player_data", "native_load_player_data");
  register_native("_gxp_sql_save_player_data", "native_save_player_data");
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_SQL_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* CVars */

  USQL_REGISTER_CVARS(gxp_swarm);

  /* Forwards */

  g_fwd_player_data_loaded = CreateMultiForward("gxp_player_data_loaded", ET_IGNORE, FP_CELL);

  /* Miscellaneous */

  g_queued_players = ArrayCreate();
}

public plugin_cfg()
{
  if (is_plugin_loaded(_GXP_SWARM_CORE_PLUGIN) == INVALID_PLUGIN_ID)
    set_fail_state("^"%s^" must be loaded.", _GXP_SWARM_CORE_PLUGIN);
}

public plugin_end()
{
  DestroyForward(g_fwd_player_data_loaded);

  ArrayDestroy(g_queued_players);
}

/* Natives > Internal */

public native_set_up(plugin, argc)
{
  /* Generate default value for `chosen_vaccines` power column. */
  for (new i = 0; i != sizeof(g_power_cols); ++i) {
    if (equali(g_power_cols[i][sc_name], "chosen_vaccines")) {
      /* TODO: replace `MAXCLASS`. */
      for (new j = 0; j != MAXCLASS; ++j)
        add(g_power_cols[i][sc_def_val], charsmax(g_power_cols[][sc_def_val]), "0 ");
    }
  }

  usql_cache_info(g_usql_host, g_usql_user, g_usql_pass, g_usql_db);
  usql_create_table(
    _GXP_SWARM_SQL_PLAYERS_TABLE,
    usql_2darray(g_player_cols, sizeof(g_player_cols), SQLColumn),
    "`id`"
  );
  usql_create_table(
    _GXP_SWARM_SQL_POWERS_TABLE,
    usql_2darray(g_power_cols, sizeof(g_power_cols), SQLColumn),
    "`id`"
  );

  _gxp_stats_set_up();
}

public bool:native_load_player_data(plugin, argc)
{
  enum { param_pid = 1 };
  queue_player(get_param(param_pid));
}

public native_save_player_data(plugin, argc)
{
  enum { param_pid = 1 };
  new pid = get_param(param_pid);
  save_player(pid, state_get_player_sid(pid));
}

/* Forwards > Stats */

public _gxp_stats_player_loaded(pid)
{
  ExecuteForward(g_fwd_player_data_loaded, _, pid);
}

/* Forwards > State */

public state_player_loaded(pid, sid)
{
  queue_player(pid, sid);
}

/* Forwards > USQL */

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
  new SQLState:load = SQLState:data[2];

  if (SQL_NumResults(handle) > 0) {
    if (load == st_load_base) {
      parse_player_base(pid, handle);
      load_player(pid, sid, st_load_powers);
    } else {
      parse_player_powers(pid, handle);
      _gxp_stats_load_player(pid);
    }
  } else {
    usql_insert(usql_sarray("id"), usql_asarray(sid));
    load_player(pid, sid, load);
  }
}

/* Main */

load_player(pid, sid, SQLState:load = st_load_base)
{
  usql_set_table(load == st_load_base ? _GXP_SWARM_SQL_PLAYERS_TABLE : _GXP_SWARM_SQL_POWERS_TABLE);
  usql_set_data(usql_array(pid, sid, load));
  usql_fetch_ex(Invalid_Array, true, "`id`='%d'", sid);
}

parse_player_base(pid, Handle:query)
{
  gxp_set_player_data(pid, pd_xp_curr,        READ_SQL_RESULT(xp_curr));
  gxp_set_player_data(pid, pd_xp_bought,      READ_SQL_RESULT(xp_bought));
  gxp_set_player_data(pid, pd_level,          READ_SQL_RESULT(level));
  gxp_set_player_data(pid, pd_prs_stored,     READ_SQL_RESULT(prs_stored));
  gxp_set_player_data(pid, pd_prs_used,       READ_SQL_RESULT(prs_used));
  gxp_set_player_data(pid, pd_prs_bought,     READ_SQL_RESULT(prs_bought));
  gxp_set_player_data(pid, pd_primary_gun,    READ_SQL_RESULT(primary_gun));
  gxp_set_player_data(pid, pd_secondary_gun,  READ_SQL_RESULT(secondary_gun));
  gxp_set_player_data(pid, pd_remember_sel,   READ_SQL_RESULT(remember_sel));
}

parse_player_powers(pid, Handle:query)
{
  new powers[GxpPower];
  powers[pwr_speed]             = READ_SQL_RESULT(speed);
  powers[pwr_respawn_chance]    = READ_SQL_RESULT(respawn_chance);
  powers[pwr_base_hp]           = READ_SQL_RESULT(base_hp);
  powers[pwr_damage]            = READ_SQL_RESULT(damage);
  powers[pwr_gravity]           = READ_SQL_RESULT(gravity);
  powers[pwr_hp_regen]          = READ_SQL_RESULT(hp_regen);
  powers[pwr_bonus_xp]          = READ_SQL_RESULT(bonus_xp);
  powers[pwr_expl_dmg]          = READ_SQL_RESULT(explosion_dmg);
  powers[pwr_he_regen]          = READ_SQL_RESULT(he_regen);
  powers[pwr_sg_regen]          = READ_SQL_RESULT(sg_regen);
  powers[pwr_shooting_interval] = READ_SQL_RESULT(shooting_interval);
  powers[pwr_fall_dmg]          = READ_SQL_RESULT(fall_dmg);
  powers[pwr_jump_bomb_chance]  = READ_SQL_RESULT(jump_bomb_chance);
  powers[pwr_jump_bomb_dmg]     = READ_SQL_RESULT(jump_bomb_dmg);
  powers[pwr_zm_add_health]     = READ_SQL_RESULT(zm_add_health);
  powers[pwr_vaccines]          = READ_SQL_RESULT(vaccines);

  new buf[MAXCLASS * (1 + 1) + 1];
  READ_SQL_SRESULT(chosen_vaccines, buf, charsmax(buf));
  ustr_explode(buf, powers[pwr_chosen_vaccines], MAXCLASS);

  gxp_set_player_data(pid, pd_powers, .buffer = powers);
}

save_player(pid, sid)
{
  /* TODO: should eventually be simplified to avoid having to retype power
   *       names, which might introduce bugs. */

  usql_set_table(_GXP_SWARM_SQL_PLAYERS_TABLE);
  usql_update_ex(
    usql_sarray(
      "xp_curr",
      "xp_bought",
      "level",
      "prs_stored",
      "prs_used",
      "prs_bought",
      "primary_gun",
      "secondary_gun",
      "remember_sel"
    ),
    usql_asarray(
      gxp_get_player_data(pid, pd_xp_curr),
      gxp_get_player_data(pid, pd_xp_bought),
      gxp_get_player_data(pid, pd_level),
      gxp_get_player_data(pid, pd_prs_stored),
      gxp_get_player_data(pid, pd_prs_used),
      gxp_get_player_data(pid, pd_prs_bought),
      gxp_get_player_data(pid, pd_primary_gun),
      gxp_get_player_data(pid, pd_secondary_gun),
      gxp_get_player_data(pid, pd_remember_sel)
    ),
    Array:-1,
    true, // cleanup
    "`id`='%d'", sid
  );

  new powers[GxpPower];
  new chosen_vaccines[MAX_SQL_COLUMN_VALUE_LENGTH + 1];
  gxp_get_player_data(pid, pd_powers, powers);
  ustr_implode(powers[pwr_chosen_vaccines], MAXCLASS, chosen_vaccines, charsmax(chosen_vaccines));

  usql_set_table(_GXP_SWARM_SQL_POWERS_TABLE);
  usql_update_ex(
    usql_sarray(
      "speed",
      "respawn_chance",
      "base_hp",
      "damage",
      "gravity",
      "hp_regen",
      "bonus_xp",
      "explosion_dmg",
      "he_regen",
      "sg_regen",
      "shooting_interval",
      "fall_dmg",
      "jump_bomb_chance",
      "jump_bomb_dmg",
      "zm_add_health",
      "vaccines",
      "chosen_vaccines"
    ),
    usql_asarray(
      powers[pwr_speed],
      powers[pwr_respawn_chance],
      powers[pwr_base_hp],
      powers[pwr_damage],
      powers[pwr_gravity],
      powers[pwr_hp_regen],
      powers[pwr_bonus_xp],
      powers[pwr_expl_dmg],
      powers[pwr_he_regen],
      powers[pwr_sg_regen],
      powers[pwr_shooting_interval],
      powers[pwr_fall_dmg],
      powers[pwr_jump_bomb_chance],
      powers[pwr_jump_bomb_dmg],
      powers[pwr_zm_add_health],
      powers[pwr_vaccines]
    ),
    usql_sarray(chosen_vaccines),
    true, // cleanup
    "`id`='%d'", sid
  );

  _gxp_stats_save_player(pid);
}

/* Helpers */

queue_player(pid, sid = 0)
{
  new idx = ArrayFindValue(g_queued_players, pid);
  if (idx != -1) {
    load_player(pid, sid == 0 ? state_get_player_sid(pid) : sid);
    ArrayDeleteItem(g_queued_players, idx);
  } else {
    ArrayPushCell(g_queued_players, pid);
  }
}