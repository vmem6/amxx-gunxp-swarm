/* NOTE: for internal use. */

#if defined _GUNXP_SWARM_STOCKS_INC
  #endinput
#endif
#define _GUNXP_SWARM_STOCKS_INC

#include <cstrike>

#include <gunxp_swarm>
#include <gunxp_swarm_const>

stock bool:_gxp_is_player_of_class(pid, cid, const props[GxpClass])
{
  return gxp_get_player_data(pid, pd_class) == cid
    && GxpTeam:gxp_get_player_data(pid, pd_team) == props[cls_team];
}

stock gxp_user_set_model(pid, props[GxpClass])
{
  new mdl[GXP_SWARM_CONFIG_MAX_PROP_LENGTH + 1];
  TrieGetString(props[cls_models], "player", mdl, charsmax(mdl));
  cs_set_user_model(pid, mdl);
}

stock gxp_user_set_viewmodel(pid, props[GxpClass])
{
  new mdl[GXP_SWARM_CONFIG_MAX_PROP_LENGTH + 1];
  copy(mdl, charsmax(mdl), "models/");
  TrieGetString(props[cls_models], "hands", mdl[strlen(mdl)], charsmax(mdl) + strlen(mdl));
  set_pev(pid, pev_viewmodel2, mdl);
  set_pev(pid, pev_weaponmodel2, "")
}

stock gxp_emit_sound(
  ent, const sound_id[GXP_SWARM_CONFIG_MAX_KEY_LENGTH + 1],
  cid, const props[GxpClass],
  chan = CHAN_AUTO
)
{
  if (1 <= ent && ent <= MAX_PLAYERS && !_gxp_is_player_of_class(ent, cid, props))
    return;

  /* Fetch sound catalogue corresponding to `sound_id`. */
  new Array:sounds;
  TrieGetCell(props[cls_sounds], sound_id, sounds);
  /* Choose random sound from said catalogue. */
  new sound[GXP_SWARM_CONFIG_MAX_PROP_LENGTH + 1];
  ArrayGetString(sounds, random_num(0, ArraySize(sounds) - 1), sound, charsmax(sound));
  /* Play it. */
  emit_sound(ent, chan, sound, 1.0, ATTN_NORM, 0, PITCH_NORM);
}