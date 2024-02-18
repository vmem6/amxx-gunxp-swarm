#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <fakemeta_util>
#include <engine>

#include <gunxp_swarm>

#include <utils_effects>
#include <utils_fakemeta>

#define SKY_CLASSNAME "dynamic_sky"
#define SKY_MODEL     "models/jailas_swarm/sky.mdl"

// #define AMBIENCE_WAV          "jailas_swarm/howlingwind.wav"
// #define AMBIENCE_WAV_DURATION 39.615

#define FOG_COLOR   {100, 100, 100}
#define FOG_DENSITY 0.0008 // [0.0001; 0.25]

enum (+= 1000)
{
  tid_update_fog = 3731,
  tid_ambience
};

new g_sky_ent;

public plugin_precache()
{
  /* Sounds */
  // precache_sound(AMBIENCE_WAV);

  /* Models */
  engfunc(EngFunc_PrecacheModel, SKY_MODEL);

  /* Miscellaneous */
  engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_snow"));
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_ENVIRONMENT_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards */

  register_forward(FM_CheckVisibility, "fm_check_visibility_pre");
  register_forward(FM_AddToFullPack, "fm_add_to_full_pack_post", ._post = 1);

  /* Events */

  register_event_ex("HLTV", "event_new_round", RegisterEvent_Global, "1=0", "2=0");

  /* Setup */

  setup();
}

public plugin_end()
{
  ufm_remove_entity(g_sky_ent);
}

/* Forwards > Client */

public client_putinserver(pid)
{
  set_task_ex(0.1, "task_update_fog", pid + tid_update_fog);
  // set_task_ex(0.1, "task_play_ambience", pid + tid_ambience);
}

public client_disconnected(pid, bool:drop, message[], maxlen)
{
  remove_task(pid + tid_ambience);
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
    origin[2] -= 2000.0;
    set_es(es, ES_Origin, origin);
  }
}

/* Events */

public event_new_round()
{
  update_fog(0);

  // for (new pid = 1; pid != MAX_PLAYERS + 1; ++pid) {
  //   remove_task(pid + tid_ambience);
  //   if (is_user_connected(pid) && !is_user_bot(pid))
  //     play_ambience(pid);
  // }
}

/* Tasks */

public task_update_fog(tid)
{
  update_fog(tid - tid_update_fog);
}

// public task_play_ambience(tid)
// {
//   play_ambience(tid - tid_ambience);
// }

/* Helpers */

setup()
{
  set_lights("b");
  create_sky();
  remove_armouries();
}

create_sky()
{
  g_sky_ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
  set_pev(g_sky_ent, pev_classname, SKY_CLASSNAME);
  set_pev(g_sky_ent, pev_solid, SOLID_NOT);
  set_pev(g_sky_ent, pev_sequence, 0);
  set_pev(g_sky_ent, pev_framerate, 0.5);
  set_pev(g_sky_ent, pev_effects, EF_BRIGHTLIGHT | EF_DIMLIGHT);
  set_pev(g_sky_ent, pev_light_level, 10.0);
  set_pev(g_sky_ent, pev_flags, FL_PARTIALGROUND);
  engfunc(EngFunc_SetModel, g_sky_ent, SKY_MODEL);
  engfunc(EngFunc_SetOrigin, g_sky_ent, Float:{0.0, 0.0, 0.0});
}

remove_armouries()
{
  new ent = FM_NULLENT;
  while ((ent = find_ent_by_class(ent, "armoury_entity")))
    remove_entity(ent);
}

update_fog(pid)
{
  ufx_fog(pid, FOG_COLOR, FOG_DENSITY);
}

// play_ambience(pid)
// {
//   if (!task_exists(pid + tid_ambience)) {
//     client_cmd(pid, "stopsound");
//     set_task_ex(
//       AMBIENCE_WAV_DURATION, "task_play_ambience", pid + tid_ambience, _, _, SetTask_Repeat
//     );
//   }
//   client_cmd(pid, "spk ^"%s^"", AMBIENCE_WAV);
// }
