#include <amxmodx>

#include <gunxp_swarm>

enum (+= 1000)
{
  tid_query_cvar = 4782
};

public plugin_init()
{
  register_plugin(_GXP_SWARM_INTEGRITY_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);
  register_dictionary(_GXP_SWARM_DICTIONARY);
}

/* Forwards > Client */

public client_putinserver(pid)
{
  if (!is_user_bot(pid) && !is_user_hltv(pid))
    set_task_ex(0.5, "task_query_cvars", pid + tid_query_cvar, .flags = SetTask_Repeat);
}

public client_disconnected(pid, bool:drop, message[], maxlen)
{
  remove_task(pid + tid_query_cvar);
}

/* Tasks */

public task_query_cvars(tid)
{
  new pid = tid - tid_query_cvar;
  query_client_cvar(pid, "gl_fog", "callback_cvar_query");
}

/* Callbacks */

public callback_cvar_query(pid, const cvar[], const value[], const param[])
{
  new val = str_to_num(value);
  if (val != 1) {
    new msg[64 + 1];
    formatex(msg, charsmax(msg), "%L", pid, "GXP_CONSOLE_BAD_CVAR_INT", cvar, val, 1);
    server_cmd("kick #%d %s", get_user_userid(pid), msg);
  }
}