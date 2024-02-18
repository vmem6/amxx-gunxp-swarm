#include <amxmodx>
#include <celltrie>
#include <cstrike>

#include <utils_log>

enum _:Logger
{
  lgr_path[PLATFORM_MAX_PATH + 1],
  lgr_verbosity
};

enum _:FormatSpecifier
{
  fs_id,
  fs_name,
  fs_ip,
  fs_authid,
  fs_team
};

new const g_format_spec_map[FormatSpecifier][] =
{
  "@id",
  "@name",
  "@ip",
  "@authid",
  "@team"
};

new Trie:g_loggers;

new g_verbosity;

public plugin_natives()
{
  register_library("utils_log");

  register_native("ulog_register_logger", "native_register_logger");
  register_native("ulog", "native_log");

  register_native("ulog_set_verbosity", "native_set_verbosity");
}

public plugin_init()
{
  // TODO: register_plugin(...);

  /* CVars */

  bind_pcvar_num(register_cvar("usql_log_global_verbosity", "1"), g_verbosity);

  /* Setup */

  g_loggers = TrieCreate();
}

public plugin_end()
{
  TrieDestroy(g_loggers);
}

/* Natives */

public native_register_logger(plugin, argc)
{
  enum {
    param_id        = 1,
    param_path      = 2,
    param_verbosity = 3
  };

  new id[32 + 10 + 1];
  get_string(param_id, id, charsmax(id));
  if (TrieKeyExists(g_loggers, id))
    return;

  new tmp[64 + 1];
  get_string(param_path, tmp, charsmax(tmp));

  new logger[Logger];
  formatex(logger[lgr_path], charsmax(logger[lgr_path]), "addons/amxmodx/logs/%s/", tmp);
  if (!dir_exists(logger[lgr_path]) && !mkdir(logger[lgr_path]))
    return;

  get_time("_%Y%m%d.log", tmp, charsmax(tmp));
  add(logger[lgr_path], charsmax(logger[lgr_path]), id);
  add(logger[lgr_path], charsmax(logger[lgr_path]), tmp);

  logger[lgr_verbosity] = get_param(param_verbosity);

  TrieSetArray(g_loggers, id, logger, sizeof(logger));
}

public native_log(plugin, argc)
{
  enum {
    param_logger_id = 1,
    param_verbosity = 2,
    param_pid       = 3,
    param_msg       = 4
  };

  new lgr_id[32 + 10 + 1];
  get_string(param_logger_id, lgr_id, charsmax(lgr_id));

  static logger[Logger];
  if (!TrieGetArray(g_loggers, lgr_id, logger, sizeof(logger)))
    return;

  strtoupper(lgr_id);

  new verbosity = get_param(param_verbosity);
  if (logger[lgr_verbosity] > GLOBAL) {
    if (verbosity < logger[lgr_verbosity])
      return;
  } else if (verbosity < g_verbosity) {
    return;
  }

  new verbosity_str[7 + 1];
  verbosity_to_str(verbosity, verbosity_str, charsmax(verbosity_str));

  static msg[512 + 1];
  get_string(param_msg, msg, charsmax(msg));

  static log[1024 + 1];
  formatex(log, charsmax(log), "[%s] [%s] ", lgr_id, verbosity_str);
  add(log, charsmax(log), msg);

  new buff[64 + 1];
  new pid = get_param(param_pid);
  for (new fs = fs_id; fs != FormatSpecifier; ++fs) {
    if (!contain(log, g_format_spec_map[fs]))
      continue;

    switch (fs) {
      case fs_id:     num_to_str(pid, buff, charsmax(buff));
      case fs_name:   get_user_name(pid, buff, charsmax(buff));
      case fs_ip:     get_user_ip(pid, buff, charsmax(buff), .without_port = true);
      case fs_authid: get_user_authid(pid, buff, charsmax(buff));
      case fs_team:   get_team_str(pid, buff, charsmax(buff));
    }

    replace_string(log, charsmax(log), g_format_spec_map[fs], buff);
  }

  log_to_file(logger[lgr_path], log);
}

public native_set_verbosity(plugin, argc)
{
  enum {
    param_logger_id = 1,
    param_verbosity = 2
  };

  new id[32 + 1];
  get_string(param_logger_id, id, charsmax(id));

  new logger[Logger];
  if (!TrieGetArray(g_loggers, id, logger, sizeof(logger)))
    return;

  logger[lgr_verbosity] = get_param(param_verbosity);

  TrieSetArray(g_loggers, id, logger, sizeof(logger));
}

/* Helpers */

get_team_str(pid, team[], maxlen)
{
  if (pid == 0 || is_user_connected(pid)) {
    copy(team, maxlen, "N/A");
    return;
  }

  switch (cs_get_user_team(pid)) {
    case CS_TEAM_CT:          copy(team, maxlen, "CT");
    case CS_TEAM_T:           copy(team, maxlen, "TERRORIST");
    case CS_TEAM_SPECTATOR:   copy(team, maxlen, "SPECTATOR");
    case CS_TEAM_UNASSIGNED:  copy(team, maxlen, "UNASSIGNED");
  }
}

verbosity_to_str(verbosity, buff[], maxlen)
{
  switch (verbosity) {
    case INFO:    copy(buff, maxlen, "INFO");
    case WARNING: copy(buff, maxlen, "WARNING");
    case ERROR:   copy(buff, maxlen, "ERROR");
    case FATAL:   copy(buff, maxlen, "FATAL");
  }
}