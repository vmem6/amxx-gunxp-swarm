#define DEBUG

#include <amxmodx>

#include <gunxp_swarm>
#include <gunxp_swarm_sql>

#include <utils_log>
#include <utils_bits>

#define MAX_CVAR_NAME_LENGTH  64
#define MAX_CVAR_VALUE_LENGTH 32

#define FILTERSTUFFCMD_STRING "7k2wEb2m5N"

enum (+= 1000)
{
  tid_query_cvar = 4782,
  tid_query_filterstuffcmd_cvar
};

new Array:g_monitored_cvars;
new Trie:g_player_cvars[MAX_PLAYERS + 1];

new g_fwd_cvar_changed;

/* Bitfields */

new g_say_cmd_blocked;
new g_stuffcmd_filtered;
new g_informed_of_stuffcmd;

public plugin_natives()
{
  register_library("gxp_swarm_integrity");

  register_native("gxp_intg_watch_cvar", "native_watch_cvar");

  register_native("gxp_intg_update_cvar", "native_update_cvar");

  register_native("gxp_intg_get_cvar_int", "native_get_cvar_int");
  register_native("gxp_intg_get_cvar_float", "native_get_cvar_float");
  register_native("gxp_intg_get_cvar_str", "native_get_cvar_str");
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_INTEGRITY_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);
  register_dictionary(_GXP_SWARM_DICTIONARY);

  /* Forwards */

  g_fwd_cvar_changed =
    CreateMultiForward("gxp_intg_cvar_changed", ET_IGNORE, FP_CELL, FP_STRING, FP_STRING);

  /* Client commands */

  register_clcmd("say _gxp[" + FILTERSTUFFCMD_STRING + "]", "clcmd_say_filterstuffcmd");

  /* Logger */

  ulog_register_logger("gxp_integrity", "gunxp_swarm");

  /* Miscellaneous */

  g_monitored_cvars = ArrayCreate(MAX_CVAR_NAME_LENGTH + 1);
  for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid)
    g_player_cvars[pid] = TrieCreate();

  watch_cvar("gl_fog");
}

public plugin_end()
{
  ArrayDestroy(g_monitored_cvars);
  for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid)
    TrieDestroy(g_player_cvars[pid]);

  DestroyForward(g_fwd_cvar_changed);
}

/* Forwards > Client */

public client_putinserver(pid)
{
  TrieClear(g_player_cvars[pid]);

  UBITS_PUNSET(g_say_cmd_blocked, pid);
  UBITS_PSET(g_stuffcmd_filtered, pid);
  UBITS_PUNSET(g_informed_of_stuffcmd, pid);
}

public client_disconnected(pid, bool:drop, message[], maxlen)
{
  remove_task(pid + tid_query_cvar);
  remove_task(pid + tid_query_filterstuffcmd_cvar);
}

/* Forwards > GunXP */

public gxp_player_data_loaded(pid)
{
  set_task_ex(0.5, "task_query_cvars", pid + tid_query_cvar, .flags = SetTask_Repeat);
  set_task_ex(
    2.0, "task_query_filterstuffcmd_cvar", pid + tid_query_filterstuffcmd_cvar,
    .flags = SetTask_Repeat
  );
  task_query_filterstuffcmd_cvar(pid + tid_query_filterstuffcmd_cvar);
}

/* Client commands */

public clcmd_say_filterstuffcmd(pid)
{
  UBITS_PUNSET(g_say_cmd_blocked, pid);
  if (UBITS_PCHECK(g_stuffcmd_filtered, pid) || !UBITS_PCHECK(g_informed_of_stuffcmd, pid)) {
    ExecuteForward(g_fwd_cvar_changed, _, pid, "cl_filterstuffcmd", "0");
    UBITS_PUNSET(g_stuffcmd_filtered, pid);
    UBITS_PSET(g_informed_of_stuffcmd, pid);
  }
  return PLUGIN_HANDLED;
}

/* Tasks */

public task_query_cvars(tid)
{
  new pid = tid - tid_query_cvar;
  for (new i = 0, end = ArraySize(g_monitored_cvars); i != end; ++i) {
    new cvar[MAX_CVAR_NAME_LENGTH + 1];
    ArrayGetString(g_monitored_cvars, i, cvar, charsmax(cvar));
    query_client_cvar(pid, cvar, "callback_cvar_query");
  }
}

public task_query_filterstuffcmd_cvar(tid)
{
  new pid = tid - tid_query_filterstuffcmd_cvar;
  if (UBITS_PCHECK(g_say_cmd_blocked, pid) || !UBITS_PCHECK(g_informed_of_stuffcmd, pid)) {
    if (!UBITS_PCHECK(g_stuffcmd_filtered, pid)) {
      ExecuteForward(g_fwd_cvar_changed, _, pid, "cl_filterstuffcmd", "1");
      UBITS_PSET(g_stuffcmd_filtered, pid);
      UBITS_PSET(g_informed_of_stuffcmd, pid);
    }
  }
  UBITS_PSET(g_say_cmd_blocked, pid);
  client_cmd(pid, "say _gxp[" + FILTERSTUFFCMD_STRING + "]");
}

/* Callbacks */

public callback_cvar_query(pid, const cvar[], const value[], const param[])
{
  new val = str_to_num(value);
  if (equali(cvar, "gl_fog") && val != 1) {
    new msg[64 + 1];
    formatex(msg, charsmax(msg), "%L", pid, "GXP_CONSOLE_BAD_CVAR_INT", cvar, val, 1);
    server_cmd("kick #%d %s", get_user_userid(pid), msg);
    ULOG( \
      "gxp_integrity", INFO, pid, \
      "^"@name^" was kicked due to a CVar (gl_fog) violation (is: %d; must be: 1). \
      [AuthID: @authid] [IP: @ip]", val \
    );
  }

  new old_val[MAX_CVAR_VALUE_LENGTH + 1];
  /* Only invoke forward if we already made one request before. */
  TrieGetString(g_player_cvars[pid], cvar, old_val, charsmax(old_val));
  TrieSetString(g_player_cvars[pid], cvar, value);
  if (!equal(old_val, value) && is_user_connected(pid))
    ExecuteForward(g_fwd_cvar_changed, _, pid, cvar, value);
}

/* Helpers */

watch_cvar(const cvar[])
{
  ArrayPushString(g_monitored_cvars, cvar);
}

stock bool:fetch_cvar_val(val[], maxlen)
{
  enum {
    param_pid   = 1,
    param_cvar  = 2
  };
  new cvar[MAX_CVAR_NAME_LENGTH + 1];
  get_string(param_cvar, cvar, charsmax(cvar));
  return TrieGetString(g_player_cvars[get_param(param_pid)], cvar, val, maxlen);
}

/* Natives */

public native_watch_cvar(plugin, argc)
{
  enum { param_cvar = 1 };
  new cvar[MAX_CVAR_NAME_LENGTH + 1];
  get_string(param_cvar, cvar, charsmax(cvar));
  if (ArrayFindString(g_monitored_cvars, cvar) == -1)
    watch_cvar(cvar);
}

public native_update_cvar(plugin, argc)
{
  enum {
    param_pid   = 1,
    param_cvar  = 2
  };
  new cvar[MAX_CVAR_NAME_LENGTH + 1];
  get_string(param_cvar, cvar, charsmax(cvar));
  query_client_cvar(get_param(param_pid), cvar, "callback_cvar_query");
}

public native_get_cvar_int(plugin, argc)
{
  new val[MAX_CVAR_VALUE_LENGTH + 1];
  if (!fetch_cvar_val(val, charsmax(val)))
    return -1;
  return str_to_num(val);
}

public Float:native_get_cvar_float(plugin, argc)
{
  new val[MAX_CVAR_VALUE_LENGTH + 1];
  if (!fetch_cvar_val(val, charsmax(val)))
    return -1.0;
  return str_to_float(val);
}

public native_get_cvar_str(plugin, argc)
{
  new val[MAX_CVAR_VALUE_LENGTH + 1];
  if (!fetch_cvar_val(val, charsmax(val)))
    return -1;
  return strlen(val);
}
