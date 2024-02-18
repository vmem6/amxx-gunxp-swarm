/*
 * TODO:
 *   - impose stricter config structure (i.e., validate it).
 */

#include <amxmodx>
#include <amxmisc>
#include <textparse_ini>
#include <fakemeta>

#include <gunxp_swarm>
#include <gunxp_swarm_const>

#include <utils_string>

enum _:Config
{
  cfg_classes,
  cfg_class_sounds,
  cfg_class_models,
  // cfg_sounds,
  // cfg_models,
  cfg_cvars
};

enum _:PropertyType
{
  pt_int,
  pt_float,
  pt_string,
  pt_bool
};

enum _:Property
{
  p_id,
  PropertyType:p_type,
  p_maxlen
};

new const g_kp_map[][] =
{
  { "title",            cls_title,            pt_string, GXP_MAX_CLASS_TITLE_LENGTH },
  { "default_sounds",   cls_default_sounds,   pt_bool,   5                          },
  { "health",           cls_health,           pt_int,    1                          },
  { "armour",           cls_armour,           pt_int,    1                          },
  { "speed",            cls_speed,            pt_int,    1                          },
  { "gravity",          cls_gravity,          pt_float,  1                          },
  { "ability_cooldown", cls_ability_cooldown, pt_float,  1                          },
  { "xp_when_killed",   cls_xp_when_killed,   pt_int,    1                          },
  { "midair_ability",   cls_midair_ability,   pt_bool,   5                          }
};

new g_class[GxpClass];
new Trie:g_classes;

new g_configs[Config][PLATFORM_MAX_PATH + 1];
new Config:g_parsed_cfg;

/* Used for easy access to non-class data. */
new Array:g_sounds;
new Array:g_models;
new Trie:g_model_map;

new INIParser:g_parser;
new bool:g_should_save;

new Trie:g_key_prop_map;

public plugin_natives()
{
  register_library("gxp_swarm_config");

  register_native("gxp_config_get_class", "native_get_class");
  register_native("gxp_config_set_class", "native_set_class");
  register_native("gxp_config_get_model_idx", "native_get_model_idx");

  register_native("gxp_config_get_aggro_zones", "native_get_aggro_zones");
}

public plugin_precache()
{
  new cfgdir[PLATFORM_MAX_PATH + 1];
  get_configsdir(cfgdir, charsmax(cfgdir));

  new const cfg_relpaths[Config][] = {
    _GXP_SWARM_CONFIG_CLASS,
    _GXP_SWARM_CONFIG_CLASS_SOUNDS,
    _GXP_SWARM_CONFIG_CLASS_MODELS,
    // _GXP_SWARM_CONFIG_SOUNDS,
    // _GXP_SWARM_CONFIG_MODELS,
    _GXP_SWARM_CONFIG_CVARS
  }

  for (new i = 0; i != sizeof(cfg_relpaths) - 1; ++i) {
    formatex(g_configs[i], charsmax(g_configs[]), "%s/%s", cfgdir, cfg_relpaths[i]);
    if (!file_exists(g_configs[i]))
      set_fail_state("Could not find class configuration file: configs/%s", cfg_relpaths[i]);
  }

  formatex(g_configs[cfg_cvars], charsmax(g_configs[]), "%s/%s", cfgdir, cfg_relpaths[cfg_cvars]);
  if (!file_exists(g_configs[cfg_cvars]))
    log_amx("Could not find CVar configuration file: configs/%s", _GXP_SWARM_CONFIG_CVARS);

  setup_parser();
  parse_classes_config();

  new filepath[PLATFORM_MAX_PATH + 1];

  for (new i = 0; i != ArraySize(g_sounds); ++i) {
    ArrayGetString(g_sounds, i, filepath, charsmax(filepath));
    engfunc(EngFunc_PrecacheSound, filepath);
  }

  new abs_path[PLATFORM_MAX_PATH + 1];
  for (new i = 0; i != ArraySize(g_models); ++i) {
    ArrayGetString(g_models, i, filepath, charsmax(filepath));
    formatex(abs_path, charsmax(abs_path), "models/%s", filepath);
    TrieSetCell(g_model_map, filepath, engfunc(EngFunc_PrecacheModel, abs_path));
  }
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_CONFIG_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);
}

public plugin_cfg()
{
  if (file_exists(g_configs[cfg_cvars])) {
    server_cmd("exec %s", g_configs[cfg_cvars]);
    server_exec();
  }
}

public plugin_end()
{
  TrieDestroy(g_classes);
  /* TODO: iterate over classes, and destroy sound and model tries. */

  TrieDestroy(g_model_map);

  INI_DestroyParser(g_parser);
  TrieDestroy(g_key_prop_map);
}

/* Natives */

public native_get_class(plugin, argc)
{
  enum {
    param_id    = 1,
    param_class = 2
  };

  new id[GXP_MAX_CLASS_ID_LENGTH + 1];
  get_string(param_id, id, charsmax(id));
  /* TODO: check if ID exists. */

  TrieGetArray(g_classes, id, g_class, sizeof(g_class));
  /* TODO: check if successful. */

  set_array(param_class, g_class, sizeof(g_class));
}

public native_set_class(plugin, argc)
{
  enum {
    param_id    = 1,
    param_class = 2
  };

  new id[GXP_MAX_CLASS_ID_LENGTH + 1];
  get_string(param_id, id, charsmax(id));
  /* TODO: check if ID exists. */

  get_array(param_class, g_class, sizeof(g_class));

  TrieSetArray(g_classes, id, g_class, sizeof(g_class));
  /* TODO: check if successful. */
}

public native_get_model_idx(plugin, argc)
{
  enum {
    param_id = 1,
    param_model_ctg = 2,
    param_model_ctg_idx = 3
  };

  new id[GXP_MAX_CLASS_ID_LENGTH + 1];
  get_string(param_id, id, charsmax(id));
  /* TODO: check if ID exists. */

  TrieGetArray(g_classes, id, g_class, sizeof(g_class));
  /* TODO: check if successful. */

  new model_ctg[GXP_SWARM_CONFIG_MAX_KEY_LENGTH + 1];
  get_string(param_model_ctg, model_ctg, charsmax(model_ctg));

  new model_filepath[PLATFORM_MAX_PATH + 1];
  new ctg_idx = get_param(param_model_ctg_idx);
  if (ctg_idx == -1) {
    TrieGetString(g_class[cls_models], model_ctg, model_filepath, charsmax(model_filepath));
  } else {
    new Array:models;
    TrieGetCell(g_class[cls_models], model_ctg, models);
    ArrayGetString(models, ctg_idx - 1, model_filepath, charsmax(model_filepath));
  }

  new model_idx;
  TrieGetCell(g_model_map, model_filepath, model_idx);
  return model_idx;
}

public native_get_aggro_zones(plugin, argc)
{
  new mapname[MAX_MAPNAME_LENGTH + 1];
  get_mapname(mapname, charsmax(mapname));

  INI_SetReaders(g_parser, "kv_callback", "ns_callback");
  INI_SetParseEnd(g_parser, "parse_end");
}

/* Parsing */

parse_classes_config()
{
  g_classes = TrieCreate();

  INI_SetReaders(g_parser, "kv_callback", "ns_callback");
  INI_SetParseEnd(g_parser, "parse_end");

  for (new i = 0; i != sizeof(g_configs) - 1; ++i) {
    g_parsed_cfg = Config:i;
    INI_ParseFile(g_parser, g_configs[i]);
  }
}

public bool:ns_callback(
  INIParser:handle,
  const section[],
  bool:invalid_tokens, bool:close_bracket, bool:extra_tokens, curtok,
  any:data
)
{
  if (g_should_save) {
    save_class();
    /* TODO: check if class is already described. */
    reset_class();
  }

  copy(g_class[cls_id], charsmax(g_class[cls_id]), section);

  g_should_save = true;
  return true;
}

public bool:kv_callback(
  INIParser:handle,
  const key[], const value[],
  bool:invalid_tokens, bool:equal_token, bool:quotes, curtok,
  any:data
)
{
  parse_class_property(key, value);
  return true;
}

parse_class_property(const key[], const value[])
{
  if (_:g_parsed_cfg == cfg_classes) {
    if (equali(key, "team")) {
      g_class[cls_team] = equali(value, "survivor") ? tm_survivor : tm_zombie;
      return;
    }

    new prop[Property];
    if (TrieGetArray(g_key_prop_map, key, prop, sizeof(prop))) {
      new prop_id = prop[p_id];
      switch (prop[p_type]) {
        case pt_int: g_class[prop_id] = str_to_num(value);
        case pt_float: g_class[prop_id] = _:str_to_float(value);
        case pt_string: copy(g_class[prop_id], prop[p_maxlen], value);
        case pt_bool: g_class[prop_id] = equali(value, "true");
      }
    } else {
      if (ustr_is_num(value, .require_decimal = true))
        TrieSetCell(g_class[cls_misc], key, str_to_float(value));
      else if (ustr_is_num(value))
        TrieSetCell(g_class[cls_misc], key, str_to_num(value));
      else if (equali(value, "true") || equali(value, "false"))
        TrieSetCell(g_class[cls_misc], key, equali(value, "true"));
      else
        TrieSetString(g_class[cls_misc], key, value);
    }
  } else {
    new Trie:trie = Trie:g_class[_:g_parsed_cfg == cfg_class_sounds ? cls_sounds : cls_models];

    /* Try to split key into base and index (e.g., "miss_1", "hit_3", etc). */
    new base[GXP_SWARM_CONFIG_MAX_KEY_LENGTH + 1];
    new idx[4 + 1];
    if (strtok2(key, base, charsmax(base), idx, charsmax(idx), '_') == -1) {
      /* Key not delimited by an underscore - assume it only has a single value. */
      TrieSetString(trie, key, value);
    } else {
      /* TODO: validate index? (i.e., ensure idx == ArraySize(arr)) */

      /* Store sound/model path. */
      new Array:arr;
      if (!TrieGetCell(trie, base, arr))
        arr = ArrayCreate(PLATFORM_MAX_PATH + 1);
      ArrayPushString(arr, value);

      TrieSetCell(trie, base, arr);
    }

    /* Store path separately for easy access when precaching. */
    if (_:g_parsed_cfg == cfg_class_models) {
      if (equal(key, "player", 6)) {
        new buff[PLATFORM_MAX_PATH + 1];
        formatex(buff, charsmax(buff), "player/%s/%s.mdl", value, value);
        ArrayPushString(g_models, buff);
        return;
      }

      ArrayPushString(g_models, value);
    } else {
      ArrayPushString(g_sounds, value);
    }
  }
}

public parse_end(INIParser:handle, bool:halted, any:data)
{
  if (g_should_save) {
    save_class();
  } else {
    /* TODO: empty; do something? */
  }
}

/* Helpers */

setup_parser()
{
  g_sounds = ArrayCreate(PLATFORM_MAX_PATH + 1);
  g_models = ArrayCreate(PLATFORM_MAX_PATH + 1);
  g_model_map = TrieCreate();

  g_parser = INI_CreateParser();
  /* Set up key -> property map. */
  g_key_prop_map = TrieCreate();
  new key[32 + 1];
  new prop[Property];
  for (new i = 0; i != sizeof(g_kp_map); ++i) {
    copy(key, charsmax(key), g_kp_map[i][0]);
    prop[p_id] = g_kp_map[i][strlen(key) + 1];
    prop[p_type] = _:g_kp_map[i][strlen(key) + 2];
    prop[p_maxlen] = g_kp_map[i][strlen(key) + 3];
    TrieSetArray(g_key_prop_map, key, prop, sizeof(prop));
  }
}

save_class()
{
  if (_:g_parsed_cfg == cfg_classes) {
    TrieSetArray(g_classes, g_class[cls_id], g_class, sizeof(g_class));
  } else {
    new class[GxpClass];
    TrieGetArray(g_classes, g_class[cls_id], class, sizeof(class));
    if (_:g_parsed_cfg == cfg_class_sounds)
      class[cls_sounds] = g_class[cls_sounds];
    else
      class[cls_models] = g_class[cls_models];
    TrieSetArray(g_classes, g_class[cls_id], class, sizeof(class));
  }
}

reset_class()
{
  g_class[cls_id]               = "";
  g_class[cls_title]            = "";
  g_class[cls_default_sounds]   = false;
  g_class[cls_team]             = tm_unclassified;
  g_class[cls_health]           = 100;
  g_class[cls_armour]           = 100;
  g_class[cls_speed]            = 255;
  g_class[cls_gravity]          = 1.0;
  g_class[cls_ability_cooldown] = 1.0;
  g_class[cls_xp_when_killed]   = 0;
  g_class[cls_misc]             = TrieCreate();
  g_class[cls_sounds]           = TrieCreate();
  g_class[cls_models]           = TrieCreate();
}