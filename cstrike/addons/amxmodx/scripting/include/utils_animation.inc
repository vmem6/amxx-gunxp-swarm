#if defined _UTILS_ANIMATION_INC
  #endinput
#endif
#define _UTILS_ANIMATION_INC

#include <fakemeta>

#include <utils_offsets>

stock uanim_play(pid, Float:time, Float:frame_rate, sequence)
{
  set_pev(pid, pev_animtime, time);
  set_pev(pid, pev_framerate, frame_rate);
  set_pev(pid, pev_sequence, sequence);
  set_pev(pid, pev_gaitsequence, sequence);
}

stock uanim_send_weaponanim(pid, sequence, Float:time)
{
  set_pev(pid, pev_weaponanim, sequence);

  message_begin(MSG_ONE, SVC_WEAPONANIM, _, pid);
  write_byte(sequence);
  write_byte(0); // weapon model body group
  message_end();

  new item = get_pdata_cbase(pid, UXO_P_ACTIVE_ITEM, UXO_LINUX_DIFF_PLAYER);
  set_pdata_float(pid, UXO_FL_NEXT_ATTACK, time, UXO_LINUX_DIFF_PLAYER);
  set_pdata_float(item, UXO_FL_TIME_WEAPON_IDLE, time, UXO_LINUX_DIFF_WEAPON);
}