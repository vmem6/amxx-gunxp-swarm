/*
 * TODO:
 *   - fix fog not re-applying on new round;
 */

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <fakemeta_util>
#include <engine>

#include <gunxp_swarm>
#include <gunxp_swarm_sql>
#include <gunxp_swarm_integrity>

#include <state>
#include <state_ui>

#include <utils_sql>
#include <utils_sql_stocks>
#include <utils_menu>
#include <utils_bits>
#include <utils_text>

#include <utils_effects>
#include <utils_fakemeta>

#define SKY_CLASSNAME "dynamic_sky"
#define SKY_MODEL     "models/jailas_swarm/sky.mdl"

#define AMBIENCE_WAV          "ambience/rain.wav"
#define AMBIENCE_WAV_DURATION 54.0 // in secs

#define FOG_COLOR       {100, 100, 100} // rgb
#define FOG_DEF_DENSITY "0.0008"  // [0.0001; 0.25]
#define FOG_MIN_DENSITY 0.0007    // [0.0001; 0.25]
#define FOG_MAX_DENSITY 0.0100    // [0.0001; 0.25]

#define WEATHER_ROTATION_INTERVAL 60.0 // in secs

#define LIGHTNING_ROLL_INTERVAL   30.0 // in secs
#define LIGHTNING_CHANCE          75.0 // in %
#define LIGHTNING_WAV             "ambience/thunder_clap.wav"

enum _:WeatherStage
{
  Float:ws_intensity_range[2],
  Float:ws_fog_density
};

enum (+= 1000)
{
  tid_update_fog = 3731
};

new const g_env_state_table[][SQLColumn] =
{
  { "weather_intensity",  sct_float,  2, "1.00",          true, false },
  { "weather_rotation",   sct_int,    1, "1",             true, false },
  { "fog_density",        sct_float,  4, FOG_DEF_DENSITY, true, false },
  { "ambience",           sct_int,    1, "1",             true, false },
  { "lightning",          sct_int,    1, "1",             true, false }
};

new const g_weather_stages[][WeatherStage] =
{
  { { 0.00, 0.00 }, 0.000000 },
  { { 0.15, 0.35 }, 0.000075 },
  { { 0.36, 0.50 }, 0.000150 },
  { { 0.51, 0.70 }, 0.000225 },
  { { 0.71, 0.85 }, 0.000300 },
  { { 0.86, 1.05 }, 0.000375 },
  { { 1.06, 1.20 }, 0.000450 },
  { { 1.21, 1.40 }, 0.000525 },
  { { 1.41, 1.55 }, 0.000600 },
  { { 1.56, 1.75 }, 0.000675 },
  { { 1.76, 1.90 }, 0.000750 },
  { { 1.91, 2.10 }, 0.000825 },
  { { 2.11, 2.25 }, 0.000900 },
  { { 2.26, 2.45 }, 0.000975 },
  { { 2.46, 2.60 }, 0.001125 },
  { { 2.61, 2.80 }, 0.001200 },
  { { 2.81, 3.00 }, 0.001275 },
  { { 2.80, 2.99 }, 0.001200 },
  { { 2.60, 2.79 }, 0.001125 },
  { { 2.45, 2.59 }, 0.001050 },
  { { 2.25, 2.44 }, 0.000975 },
  { { 2.10, 2.24 }, 0.000900 },
  { { 1.90, 2.09 }, 0.000825 },
  { { 1.75, 1.89 }, 0.000750 },
  { { 1.55, 1.74 }, 0.000675 },
  { { 1.40, 1.54 }, 0.000600 },
  { { 1.20, 1.39 }, 0.000525 },
  { { 1.05, 1.19 }, 0.000450 },
  { { 0.85, 1.04 }, 0.000375 },
  { { 0.70, 0.84 }, 0.000300 },
  { { 0.50, 0.69 }, 0.000225 },
  { { 0.35, 0.49 }, 0.000150 },
  { { 0.15, 0.34 }, 0.000075 }
};

new Float:g_real_weather_intensities[MAX_PLAYERS + 1];
new Float:g_weather_intensities[MAX_PLAYERS + 1];
new Float:g_fog_densities[MAX_PLAYERS + 1];

new Float:g_weather_intensity;
new Float:g_fog_density;
new g_weather_lvl;

/* Bitfields */

new g_data_loaded;
new g_cvars_loaded;

new g_stuffcmd_filtered;

new g_weather_rotn_enabled;
new g_ambience_enabled;
new g_lightning_enabled;

/* Auxiliaries */

new g_prefix[_GXP_MAX_PREFIX_LENGTH + 1];

new g_spr_laserbeam;

new g_sky_ent;

new g_thunder_idx;

new bool:g_settings_exist;
new Float:g_sky_z;
new Float:g_skybox_offsets[3] = { 0.0, 0.0, 2000.0 };
new Float:g_map_mins[2] = { -2000.0, -2000.0 };
new Float:g_map_maxs[2] = { 2000.0, 2000.0 };

new g_ctg;
new g_id_stuffcmd_filter_notice[2];
new g_id_weather_intensity_item;
new g_id_weather_rotation_item;
new g_id_fog_density_item;
new g_id_ambience_item;
new g_id_lightning_item;

public plugin_precache()
{
  /* Sounds */
  precache_sound(AMBIENCE_WAV);
  g_thunder_idx = precache_sound(LIGHTNING_WAV);

  /* Models */
  engfunc(EngFunc_PrecacheModel, SKY_MODEL);

  /* Sprites */
  g_spr_laserbeam = engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr");

  /* Miscellaneous */
  engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_rain"));
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_ENVIRONMENT_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);
  register_dictionary(_GXP_SWARM_DICTIONARY);

  /* Forwards */

  register_forward(FM_CheckVisibility, "fm_check_visibility_pre");
  register_forward(FM_EmitSound, "fm_emitsound_pre");
  register_forward(FM_AddToFullPack, "fm_add_to_full_pack_post", ._post = 1);

  /* Events */

  register_event_ex("HLTV", "event_new_round", RegisterEvent_Global, "1=0", "2=0");

  /* Setup */

  setup();
  setup_ui();
}

public plugin_cfg()
{
  bind_pcvar_string(get_cvar_pointer("gxp_info_prefix"), g_prefix, charsmax(g_prefix));
  fix_colors(g_prefix, charsmax(g_prefix));

  /* TODO: move this somewhere else because `state_core.sma` sets up SQL on
   *       `plugin_cfg` as well. */
  state_queue_table(
    "swarm_env", usql_2darray(g_env_state_table, sizeof(g_env_state_table), SQLColumn)
  );
  gxp_intg_watch_cvar("cl_weather");

  load_env_settings();
}

public plugin_end()
{
  ufm_remove_entity(g_sky_ent);
}

/* Forwards > Client */

public client_putinserver(pid)
{
  UBITS_PUNSET(g_cvars_loaded, pid);
  UBITS_PSET(g_stuffcmd_filtered, pid);
}

public client_disconnected(pid, bool:drop, message[], maxlen)
{
  if (UBITS_PCHECK(g_data_loaded, pid)) {
    state_set_val(pid, "swarm_env", "weather_intensity", g_weather_intensities[pid]);
    state_set_val(pid, "swarm_env", "weather_rotation", UBITS_PCHECK(g_weather_rotn_enabled, pid));
    state_set_val(pid, "swarm_env", "fog_density", g_fog_densities[pid]);
    state_set_val(pid, "swarm_env", "ambience", UBITS_PCHECK(g_ambience_enabled, pid));
    state_set_val(pid, "swarm_env", "lightning", UBITS_PCHECK(g_lightning_enabled, pid));
  }

  g_real_weather_intensities[pid] = 0.0;
  g_weather_intensities[pid]      = 0.0;
  g_fog_densities[pid]            = 0.0;

  UBITS_PUNSET(g_ambience_enabled, pid);
  UBITS_PUNSET(g_weather_rotn_enabled, pid);

  UBITS_PUNSET(g_data_loaded, pid);
}

/* Forwards > GunXP */

public gxp_player_data_loaded(pid)
{
  set_task_ex(0.1, "task_update_fog", pid + tid_update_fog);

  g_weather_intensities[pid] = Float:state_get_val(pid, "swarm_env", "weather_intensity");
  g_fog_densities[pid] = Float:state_get_val(pid, "swarm_env", "fog_density");

  if (state_get_val(pid, "swarm_env", "weather_rotation"))
    UBITS_PSET(g_weather_rotn_enabled, pid);
  if (state_get_val(pid, "swarm_env", "ambience"))
    UBITS_PSET(g_ambience_enabled, pid);
  if (state_get_val(pid, "swarm_env", "lightning"))
    UBITS_PSET(g_lightning_enabled, pid);

  UBITS_PSET(g_data_loaded, pid);
}

public gxp_intg_cvar_changed(pid, const cvar[], const value[])
{
  if (equal(cvar, "cl_filterstuffcmd")) {
    if (!str_to_num(value)) {
      UBITS_PUNSET(g_stuffcmd_filtered, pid);
      if (!UBITS_PCHECK(g_cvars_loaded, pid) && !UBITS_PCHECK(g_weather_rotn_enabled, pid))
        client_cmd(pid, "cl_weather %.2f", g_weather_intensities[pid]);
    } else {
      UBITS_PSET(g_stuffcmd_filtered, pid);
      if (!UBITS_PCHECK(g_cvars_loaded, pid) && !UBITS_PCHECK(g_weather_rotn_enabled, pid))
        chat_print(pid, g_prefix, "%L", pid, "GXP_CHAT_ENV_COULD_NOT_APPLY_WEATHER");
    }

    UBITS_PSET(g_cvars_loaded, pid);

    update_weather(pid);
    umenu_refresh(pid);
  } else if (equal(cvar, "cl_weather")) {
    new Float:fval = str_to_float(value);

    if (!UBITS_PCHECK(g_weather_rotn_enabled, pid))
      g_weather_intensities[pid] = fval;

    if (UBITS_PCHECK(g_ambience_enabled, pid)) {
      if (g_real_weather_intensities[pid] <= 0.0001 && fval > 0.0)
        play_ambience(pid);
      else if (g_real_weather_intensities[pid] > 0.0 && fval <= 0.0001)
        client_cmd(pid, "stopsound");
    }

    g_real_weather_intensities[pid] = fval;

    umenu_refresh(pid);
  }
}

/* Forwards > UMenu */

public umenu_render(pid, id, UMenuContext:ctx, UMenuContextPosition:pos, Array:title)
{
  new _title[64 + 1];

  if (id == g_ctg) {
    formatex(
      _title, charsmax(_title), "%s%L",
      pos == umenu_cp_title ? "\r" : "", pid, "GXP_STATE_UI_MENU_ENV_TITLE"
    );
  } else if (ctx == umenu_ctx_item) {
    if (id == g_id_weather_intensity_item) {
      new Float:intensity = g_weather_intensities[pid];
      if (intensity > 0.0)
        formatex(_title, charsmax(_title), "%L", pid, "GXP_STATE_UI_MENU_ENV_WEATHER", intensity);
      else
        formatex(_title, charsmax(_title), "%L", pid, "GXP_STATE_UI_MENU_ENV_WEATHER_DISABLED");
    } else if (id == g_id_weather_rotation_item) {
      new bool:enabled =
        UBITS_PCHECK(g_weather_rotn_enabled, pid) && !UBITS_PCHECK(g_stuffcmd_filtered, pid);
      formatex(
        _title, charsmax(_title), "%L",
        pid, "GXP_STATE_UI_MENU_ENV_WEATHER_ROTATION",
        enabled ? "\y" : "\r", pid, enabled ? "MENU_ENABLED" : "MENU_DISABLED"
      );
    } else if (id == g_id_fog_density_item) {
      formatex(
        _title, charsmax(_title),
        "%L", pid, "GXP_STATE_UI_MENU_ENV_FOG_DENSITY", g_fog_densities[pid]
      );
    } else if (id == g_id_ambience_item) {
      new bool:enabled =
        UBITS_PCHECK(g_ambience_enabled, pid) && g_real_weather_intensities[pid] > 0.0;
      formatex(
        _title, charsmax(_title), "%L",
        pid, "GXP_STATE_UI_MENU_ENV_AMBIENCE",
        enabled ? "\y" : "\r", pid, enabled ? "MENU_ENABLED" : "MENU_DISABLED"
      );
    } else if (id == g_id_lightning_item) {
      formatex(
        _title, charsmax(_title), "%L",
        pid, "GXP_STATE_UI_MENU_ENV_LIGHTNING",
        UBITS_PCHECK(g_lightning_enabled, pid) ? "\y" : "\r",
        pid, UBITS_PCHECK(g_lightning_enabled, pid) ? "MENU_ENABLED" : "MENU_DISABLED"
      );
    }
  } else {
    if (UBITS_PCHECK(g_stuffcmd_filtered, pid)) {
      if (id == g_id_stuffcmd_filter_notice[0])
        formatex(_title, charsmax(_title), "%L", pid, "GXP_STATE_UI_MENU_ENV_WARN1");
      else if (id == g_id_stuffcmd_filter_notice[1])
        formatex(_title, charsmax(_title), "%L", pid, "GXP_STATE_UI_MENU_ENV_WARN2");
    } else {
      return false;
    }
  }

  UMENU_SET_STRING(title, _title)
  return true;
}

public umenu_access(pid, id, UMenuContext:ctx)
{
  if (id == g_id_weather_intensity_item) {
    if (UBITS_PCHECK(g_weather_rotn_enabled, pid) || UBITS_PCHECK(g_stuffcmd_filtered, pid))
      return ITEM_DISABLED;
  } else if (id == g_id_weather_rotation_item) {
    if (UBITS_PCHECK(g_stuffcmd_filtered, pid) || UBITS_PCHECK(g_stuffcmd_filtered, pid))
      return ITEM_DISABLED;
  } else if (id == g_id_fog_density_item) {
    if (UBITS_PCHECK(g_weather_rotn_enabled, pid) && !UBITS_PCHECK(g_stuffcmd_filtered, pid))
      return ITEM_DISABLED;
  } else if (id == g_id_ambience_item) {
    if (g_real_weather_intensities[pid] <= 0.0001)
      return ITEM_DISABLED;
  }
  return ITEM_IGNORE;
}

public bool:umenu_select(pid, id, UMenuContext:ctx)
{
  if (id == g_id_weather_intensity_item) {
    gxp_intg_update_cvar(pid, "cl_weather");
    new Float:intensity = gxp_intg_get_cvar_float(pid, "cl_weather");
    intensity = intensity >= 3.0 ? 0.0 : floatclamp(intensity + 0.5, 0.0, 3.0);
    client_cmd(pid, "cl_weather %.2f", intensity);
  } else if (id == g_id_weather_rotation_item) {
    ubits_ptoggle(g_weather_rotn_enabled, pid);
    update_weather(pid);
  } if (id == g_id_fog_density_item) {
    new Float:density = g_fog_densities[pid];
    g_fog_densities[pid] = density + 0.0003 >= FOG_MAX_DENSITY ? FOG_MIN_DENSITY : density + 0.0003;
    update_fog(pid);
  } else if (id == g_id_ambience_item) {
    if (UBITS_PCHECK(g_ambience_enabled, pid)) {
      UBITS_PUNSET(g_ambience_enabled, pid);
      client_cmd(pid, "stopsound");
    } else {
      UBITS_PSET(g_ambience_enabled, pid);
      play_ambience(pid);
    }
  } else if (id == g_id_lightning_item) {
    ubits_ptoggle(g_lightning_enabled, pid);
  }

  return true;
}

/* Forwards > FakeMeta */

public fm_check_visibility_pre(const ent, const pset)
{
  /* Ensure actual skybox doesn't obstruct our model. */
  if (ent == g_sky_ent) {
    forward_return(FMV_CELL, 1);
    return FMRES_SUPERCEDE;
  }
  return FMRES_IGNORED;
}

public fm_add_to_full_pack_post(
  const es,
  const e,
  const ent,
  const host,
  const hostflags,
  const player,
  const pset
)
{
  /* Fake animated skybox origin. */
  if (ent == g_sky_ent) {
    static Float:origin[3];
    pev(host, pev_origin, origin);
    xs_vec_sub(origin, g_skybox_offsets, origin);
    set_es(es, ES_Origin, origin);
  }
}

/* Events */

public event_new_round()
{
  new players[MAX_PLAYERS];
  new playersnum;
  get_players_ex(players, playersnum, GetPlayers_ExcludeHLTV | GetPlayers_ExcludeBots);

  for (new i = 0; i != playersnum; ++i) {
    new pid = players[i];
    update_fog(pid);
    if (UBITS_PCHECK(g_ambience_enabled, pid))
      play_ambience(pid);
  }
}

/* Tasks */

public task_update_weather()
{
  g_weather_intensity = random_float(
    g_weather_stages[g_weather_lvl][ws_intensity_range][0],
    g_weather_stages[g_weather_lvl][ws_intensity_range][1]
  );
  g_fog_density = g_weather_stages[g_weather_lvl][ws_fog_density];

  for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid) {
    if (is_user_connected(pid) && !is_user_bot(pid) && UBITS_PCHECK(g_weather_rotn_enabled, pid))
      update_weather(pid);
  }

  if (++g_weather_lvl >= sizeof(g_weather_stages))
    g_weather_lvl = 0;
}

public task_roll_lightning()
{
  if (random_float(0.0, 100.0) <= LIGHTNING_CHANCE) {
    new beg[3];
    new end[3];
    if (!find_lightning_spot(beg, end))
      return;

    for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid) {
      if (!is_user_connected(pid) || is_user_bot(pid))
        continue;
      if (!UBITS_PCHECK(g_lightning_enabled, pid))
        continue;

      ufx_te_beampoints(0, beg, end, g_spr_laserbeam, 0, 1.0, 0.6, 3.0, 6.0, {255, 255, 255}, 255, 1.0);
      ufx_te_dlight(end, 200, {255, 255, 255}, 50, 0);

      message_begin(MSG_ONE_UNRELIABLE, SVC_SPAWNSTATICSOUND, .player = pid);
      write_coord(end[0]);
      write_coord(end[1]);
      write_coord(end[2]);
      write_short(g_thunder_idx);
      write_byte(255);  // VOL_NORM * 255
      write_byte(26);   // 0.4 * 64
      write_short(0);
      write_byte(PITCH_LOW);
      write_byte(0);
      message_end();
    }
  }
}

public task_update_fog(tid)
{
  update_fog(tid - tid_update_fog);
}

/* Helpers */

setup()
{
  set_lights("c");
  create_sky();
  remove_armouries();

  task_update_weather();
  set_task_ex(WEATHER_ROTATION_INTERVAL, "task_update_weather", .flags = SetTask_Repeat);
  set_task_ex(LIGHTNING_ROLL_INTERVAL, "task_roll_lightning", .flags = SetTask_Repeat);
}

setup_ui()
{
  g_ctg = umenu_register_category(state_ui_get_global_ctg());
  g_id_stuffcmd_filter_notice[0] = umenu_add_notice(g_ctg);
  g_id_stuffcmd_filter_notice[1] = umenu_add_notice(g_ctg);
  g_id_weather_intensity_item = umenu_add_item(g_ctg);
  g_id_weather_rotation_item = umenu_add_item(g_ctg);
  g_id_fog_density_item = umenu_add_item(g_ctg);
  g_id_ambience_item = umenu_add_item(g_ctg);
  g_id_lightning_item = umenu_add_item(g_ctg);
}

create_sky()
{
  g_sky_z = g_skybox_offsets[2] = get_sky_z();
  g_sky_ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
  set_pev(g_sky_ent, pev_classname, SKY_CLASSNAME);
  set_pev(g_sky_ent, pev_solid, SOLID_NOT);
  set_pev(g_sky_ent, pev_sequence, 0);
  set_pev(g_sky_ent, pev_framerate, 0.25);
  set_pev(g_sky_ent, pev_effects, EF_BRIGHTLIGHT | EF_DIMLIGHT);
  set_pev(g_sky_ent, pev_light_level, 10.0);
  set_pev(g_sky_ent, pev_flags, FL_PARTIALGROUND);
  engfunc(EngFunc_SetModel, g_sky_ent, SKY_MODEL);
  engfunc(EngFunc_SetOrigin, g_sky_ent, Float:{0.0, 0.0, 0.0});
}

Float:get_sky_z()
{
  new Float:origin[3] = { 0.0, 0.0, 0.0 };

  new ct_spawn_point = find_ent_by_class(FM_NULLENT, "info_player_start");
  pev(ct_spawn_point, pev_origin, origin);

#define MAX_ITERS 401
  for (new i = 0; point_contents(origin) != CONTENTS_SKY && i != MAX_ITERS; ++i)
    origin[2] += 5.0;
#undef MAX_ITERS

  return origin[2] - 5.0;
}

remove_armouries()
{
  new ent = FM_NULLENT;
  while ((ent = find_ent_by_class(ent, "armoury_entity")))
    remove_entity(ent);
}

update_weather(pid)
{
  update_fog(pid);
  if (!UBITS_PCHECK(g_stuffcmd_filtered, pid)) {
    if (UBITS_PCHECK(g_weather_rotn_enabled, pid))
      client_cmd(pid, "cl_weather %.2f", g_weather_intensity);
    else
      client_cmd(pid, "cl_weather %.2f", g_weather_intensities[pid]);
  }
}

update_fog(pid)
{
  if (UBITS_PCHECK(g_weather_rotn_enabled, pid) && !UBITS_PCHECK(g_stuffcmd_filtered, pid))
    ufx_fog(pid, FOG_COLOR, g_fog_density);
  else
    ufx_fog(pid, FOG_COLOR, g_fog_densities[pid]);
}

play_ambience(pid)
{
  client_cmd(pid, "stopsound");
  client_cmd(pid, "spk ^"%s^"", AMBIENCE_WAV);
}

bool:is_point_outside(const Float:point[3])
{
  new Float:origin[3];
  origin[0] = point[0];
  origin[1] = point[1];
  origin[2] = point[2];
  new contents;
  while ((contents = point_contents(origin)) == CONTENTS_EMPTY)
    origin[2] += 2.0;
  return contents == CONTENTS_SKY;
}

bool:find_lightning_spot(beg[3], end[3])
{
  new players[MAX_PLAYERS];
  new playersnum;
  get_players_ex(players, playersnum, GetPlayers_ExcludeDead | GetPlayers_ExcludeHLTV);

  if (playersnum == 0)
    return false;

  new pid = players[random_num(0, playersnum - 1)];
  get_user_origin(pid, end);

  new Float:_end1[3];
  new Float:_end2[3];

  _end2[2] = -9999.0;

  new tr = create_tr2();

  new iter = 0;
  new bool:within_bounds;
  new bool:in_open;
  new bool:outside;
  do {
    _end1[0] = _end2[0] = float(end[0]) + random_float(-1000.0, 1000.0);
    _end1[1] = _end2[1] = float(end[1]) + random_float(-1000.0, 1000.0);
    _end1[2] = g_sky_z;

    engfunc(EngFunc_TraceLine, _end1, _end2, IGNORE_MONSTERS | IGNORE_MISSILE, 0, tr);
    get_tr2(tr, TR_EndPos, _end1);

    within_bounds =
      _end1[0] > g_map_mins[0] && _end1[0] < g_map_maxs[0] &&
      _end1[1] > g_map_mins[1] && _end1[1] < g_map_maxs[1];

    if (within_bounds) {
      in_open = point_contents(_end1) == CONTENTS_EMPTY;
      if (in_open)
        outside = is_point_outside(_end1);
    }

    ++iter;
#define MAX_ITERS 100
  } while ((!within_bounds || !in_open || !outside) && iter < MAX_ITERS);
#undef MAX_ITERS

  free_tr2(tr);

  beg[0] = floatround(_end1[0]);
  beg[1] = floatround(_end1[1]);
  beg[2] = floatround(g_sky_z);

  end[0] = floatround(_end1[0]);
  end[1] = floatround(_end1[1]);
  end[2] = floatround(_end1[2] + 5.0);

  return true;
}

load_env_settings()
{
  new INIParser:ini_parser = INI_CreateParser();
  INI_SetReaders(ini_parser, "env_kv_callback", "env_ns_callback");

  new configsdir[PLATFORM_MAX_PATH + 1];
  get_configsdir(configsdir, charsmax(configsdir));
  add(configsdir, charsmax(configsdir), "/gunxp_swarm/environment.ini");
  INI_ParseFile(ini_parser, configsdir);

  INI_DestroyParser(ini_parser);
}

public env_ns_callback(
  INIParser:handle,
  const section[],
  bool:invalid_tokens, bool:close_bracket, bool:extra_tokens, curtok,
  any:data
)
{
  new mapname[MAX_MAPNAME_LENGTH + 1];
  get_mapname(mapname, charsmax(mapname));
  if (equal(section, mapname))
    g_settings_exist = true;
  else if (g_settings_exist)
    return false;
  return true;
}

public env_kv_callback(
  INIParser:handle,
  const key[], const value[],
  bool:invalid_tokens, bool:equal_token, bool:quotes, curtok,
  any:data
)
{
  if (!g_settings_exist)
    return true;

  if (equal(key, "lights")) {
    set_lights(value);
  } else {
    new rhs[128 + 1];
    new lhs[10 + 1];
    copy(rhs, charsmax(rhs), value);

#define ENV_PARSE_FLOAT(%0) \
  strtok2(rhs, lhs, charsmax(lhs), rhs, charsmax(rhs)); \
  %0 = str_to_float(lhs)

    if (equal(key, "skybox_offsets")) {
      ENV_PARSE_FLOAT(g_skybox_offsets[0]);
      ENV_PARSE_FLOAT(g_skybox_offsets[1]);
      ENV_PARSE_FLOAT(g_skybox_offsets[2]);
    } else if (equal(key, "map_bounds")) {
      ENV_PARSE_FLOAT(g_map_mins[0]);
      ENV_PARSE_FLOAT(g_map_mins[1]);
      ENV_PARSE_FLOAT(g_map_maxs[0]);
      ENV_PARSE_FLOAT(g_map_maxs[1]);
    }
  }

  return true;
}
