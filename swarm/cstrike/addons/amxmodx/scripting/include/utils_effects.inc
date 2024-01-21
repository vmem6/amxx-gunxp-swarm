#if defined _UTILS_EFFECTS_INC
  #endinput
#endif
#define _UTILS_EFFECTS_INC

#include <amxmodx>

#define _UFX_FETCH_MSGID(%0)                            \
  static _msg_id_%0 = 0;                                \
  if (_msg_id_%0 == 0) _msg_id_%0 = get_user_msgid(#%0)
#define _UFX_MSGID(%0) _msg_id_%0

/* https://github.com/ValveSoftware/halflife/blob/
 * c7240b965743a53a29491dd49320c88eecf6257b/engine/shake.h#L39-L43 */
enum UfxFFade
{
  ufx_ffade_in        = 0x0000, // just here so we don't pass 0 into the
                                // function
  ufx_ffade_out       = 0x0001, // fade out (not in)
  ufx_ffade_modulate  = 0x0002, // modulate (don't blend)
  ufx_ffade_stayout   = 0x0004, // ignore the duration, stay faded out until new
                                // ScreenFade message received
  ufx_ffade_longfade  = 0x0008  // used to indicate the fade can be longer than
                                // 16 seconds (added for czero)
};

/* https://github.com/ValveSoftware/halflife/blob/
 * c7240b965743a53a29491dd49320c88eecf6257b/common/const.h#L652-L663 */
enum UfxBreakModel
{
  ufx_break_model_typemask  = 0x4f,
  ufx_break_model_glass     = 0x01,
  ufx_break_model_metal     = 0x02,
  ufx_break_model_flesh     = 0x04,
  ufx_break_model_wood      = 0x08,
  ufx_break_model_smoke     = 0x10,
  ufx_break_model_trans     = 0x20,
  ufx_break_model_concrete  = 0x40,
  ufx_break_model_2         = 0x80
}

/* https://github.com/ValveSoftware/halflife/blob/
 * c7240b965743a53a29491dd49320c88eecf6257b/common/const.h#L159-L164 */
enum UfxExplosion
{
  ufx_explosion_none        = 0,        // all flags clear makes default Half-Life explosion
  ufx_explosion_noadditive  = (1 << 0), // sprite will be drawn opaque (ensure
                                        // that the sprite you send is a
                                        // non-additive sprite)
  ufx_explosion_nodlights   = (1 << 1), // do not render dynamic lights
  ufx_explosion_nosound     = (1 << 2), // do not play client explosion sound
  ufx_explosion_noparticles = (1 << 3)  // do not draw particles
};

stock ufx_screenfade(pid, Float:duration, Float:hold_time, UfxFFade:fade_type, const rgba[4])
{
  _UFX_FETCH_MSGID(ScreenFade);
  message_begin(MSG_ONE, _UFX_MSGID(ScreenFade), _, pid);
  write_short(_ufx_fixed_unsigned_16(duration, 1 << 12));
  write_short(_ufx_fixed_unsigned_16(hold_time, 1 << 12));
  write_short(_:fade_type);
  write_byte(rgba[0]); // red
  write_byte(rgba[1]); // green
  write_byte(rgba[2]); // blue
  write_byte(rgba[3]); // alpha
  message_end();
}

stock ufx_damage(pid, const Float:origin[3])
{
  _UFX_FETCH_MSGID(Damage);
  message_begin(MSG_ONE, _UFX_MSGID(Damage), {0, 0, 0}, pid);
  write_byte(21);
  write_byte(20);
  write_long(0);
  write_coord(floatround(origin[0]));
  write_coord(floatround(origin[1]));
  write_coord(floatround(origin[2]));
  message_end();
}

stock ufx_screenshake(pid, Float:amplitude, Float:duration, Float:frequency)
{
  _UFX_FETCH_MSGID(ScreenShake);
  message_begin(MSG_ONE, _UFX_MSGID(ScreenShake), {0, 0, 0}, pid);
  write_short(_ufx_fixed_unsigned_16(amplitude, 1 << 12));
  write_short(_ufx_fixed_unsigned_16(duration, 1 << 12));   // duration
  write_short(_ufx_fixed_unsigned_16(frequency, 1 << 12)); // frequency
  message_end();
}

/* Credits: jtp10181 @ https://forums.alliedmods.net/showthread.php?p=19346 */
stock ufx_blood_splatter(pid)
{
  static origin[3];
  get_user_origin(pid, origin);

  new Float:vector[3];
  vector[0] = random_float(-360.0, 360.0);
  vector[1] = random_float(-360.0, 360.0);
  vector[2] = -10.0;

  ufx_te_bloodstream(origin, vector, 70, random_num(50, 100));

  for (new i = 0; i != 4; ++i) {
    new tmp_origin[3];
    tmp_origin[0] = origin[0] + random_num(-100, 100);
    tmp_origin[2] = origin[1] + random_num(-100, 100);
    tmp_origin[2] = origin[2] + random_num(-100, 100);
    ufx_te_splash(tmp_origin, random_num(190, 197));
  }
}

stock ufx_bartime(pid, length)
{
  _UFX_FETCH_MSGID(BarTime);
  message_begin(MSG_ONE, _UFX_MSGID(BarTime), .player = pid);
  write_short(length);
  message_end();
}

stock ufx_fog(const pid, const rgb[3], const Float:density = 0.001, bool:clear = false)
{
  _UFX_FETCH_MSGID(Fog);
  message_begin(pid ? MSG_ONE : MSG_BROADCAST, _UFX_MSGID(Fog), .player = pid);
  write_byte(clamp(rgb[0], 0, 255));
  write_byte(clamp(rgb[1], 0, 255));
  write_byte(clamp(rgb[2], 0, 255));
  write_long(clear ? 0 : _:floatclamp(density, 0.0001, 0.25));
  message_end();
}

/* Temporary events */

stock ufx_te_beamfollow(pid, spr, Float:life, Float:line_width, const rgb[3], brightness)
{
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_BEAMFOLLOW);
  write_short(pid);
  write_short(spr);
  write_byte(floatround(life/0.1));
  write_byte(floatround(line_width/0.1));
  write_byte(rgb[0]); // red
  write_byte(rgb[1]); // green
  write_byte(rgb[2]); // blue
  write_byte(brightness);
  message_end();
}

stock ufx_te_dlight(const origin[3], radius, const rgb[3], life, decay_rate)
{
  message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
  write_byte(TE_DLIGHT);
  write_coord(origin[0]);
  write_coord(origin[1]);
  write_coord(origin[2]);
  write_byte(radius/10);
  write_byte(rgb[0]); // def 255
  write_byte(rgb[1]);
  write_byte(rgb[2]);
  write_byte(life/10);
  write_byte(decay_rate/10);
  message_end();
}

stock ufx_te_splash(const origin[3], decal_idx)
{
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_WORLDDECAL);
  write_coord(origin[0]);
  write_coord(origin[1]);
  write_coord(origin[2]);
  write_byte(decal_idx);
  message_end();
}

stock ufx_te_break_model(
  const origin[3],
  const size[3],
  const velocity[3],
  random_velocity,
  model_idx,
  count,
  Float:life,
  UfxBreakModel:flags
)
{
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY, origin);
  write_byte(TE_BREAKMODEL);
  write_coord(origin[0]);
  write_coord(origin[1]);
  write_coord(origin[2] + 24);
  write_coord(size[0]);
  write_coord(size[1]);
  write_coord(size[2]);
  write_coord(velocity[0]);
  write_coord(velocity[1]);
  write_coord(velocity[2]);
  write_byte(random_velocity * 10);
  write_short(model_idx);
  write_byte(count);
  write_byte(floatround(life/0.1));
  write_byte(_:flags);
  message_end();
}

stock ufx_te_bloodstream(const origin[3], const Float:vector[3], color, speed)
{
  message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
  write_byte(TE_BLOODSTREAM);
  write_coord(origin[0]);
  write_coord(origin[1]);
  write_coord(origin[2]);
  write_coord_f(vector[0]);
  write_coord_f(vector[1]);
  write_coord_f(vector[2]);
  write_byte(color);
  write_byte(speed);
  message_end();
}

stock ufx_te_spray(
  const origin[3], const Float:velocity[3], model_idx, count, speed, noise, render_mode
)
{
  message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
  write_byte(TE_SPRAY);
  write_coord(origin[0]);
  write_coord(origin[1]);
  write_coord(origin[2]);
  write_coord_f(velocity[0]);
  write_coord_f(velocity[1]);
  write_coord_f(velocity[2]);
  write_short(model_idx);
  write_byte(count);
  write_byte(speed);
  write_byte(noise);
  write_byte(render_mode);
  message_end();
}

stock ufx_te_smoke(const origin[3], spr_idx, Float:scale, frame_rate)
{
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_SMOKE);
  write_coord(origin[0]);
  write_coord(origin[1]);
  write_coord(origin[2]);
  write_short(spr_idx);
  write_byte(floatround(scale/0.1));
  write_byte(frame_rate);
  message_end();
}

stock ufx_te_gunshotdecal(const origin[3], decal)
{
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_GUNSHOTDECAL);
  write_coord(origin[0]);
  write_coord(origin[1]);
  write_coord(origin[2]);
  write_short(0); // unknown; ent index?
  write_byte(decal);
  message_end()
}

stock ufx_te_explosion(const origin[3], spr_idx, Float:scale, frame_rate, UfxExplosion:flags)
{
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY, origin);
  write_byte(TE_EXPLOSION);
  write_coord(origin[0]);
  write_coord(origin[1]);
  write_coord(origin[2]);
  write_short(spr_idx);
  write_byte(floatround(scale/0.1));
  write_byte(frame_rate);
  write_byte(_:flags);
  message_end();
}

stock ufx_te_beamcylinder(
  const origin[3],
  const axis[3],
  spr_idx,
  start_frame,
  Float:frame_rate,
  Float:life,
  Float:line_width,
  Float:noise,
  const rgb[3],
  brightness,
  Float:scroll_speed
)
{
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY, origin);
  write_byte(TE_BEAMCYLINDER);
  write_coord(origin[0]);
  write_coord(origin[1]);
  write_coord(origin[2]);
  write_coord(axis[0]);
  write_coord(axis[1]);
  write_coord(axis[2]);
  write_short(spr_idx);
  write_byte(start_frame);
  write_byte(floatround(frame_rate/0.1));
  write_byte(floatround(life/0.1));
  write_byte(floatround(line_width/0.1));
  write_byte(floatround(noise/0.1));
  write_byte(rgb[0]);
  write_byte(rgb[1]);
  write_byte(rgb[2]);
  write_byte(brightness);
  write_byte(floatround(scroll_speed/0.1));
  message_end();
}

stock ufx_te_lavasplash(const origin[3])
{
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_LAVASPLASH);
  write_coord(origin[0]);
  write_coord(origin[1]);
  write_coord(origin[2]);
  message_end();
}

stock ufx_te_beamentpoint(
  pid,
  const origin[3],
  spr_idx,
  start_frame,
  frame_rate,
  life,
  width,
  noise,
  const rgb[3],
  brightness,
  speed
)
{
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_BEAMENTPOINT);
  write_short(pid)
  write_coord(origin[0]);
  write_coord(origin[1]);
  write_coord(origin[2]);
  write_short(spr_idx);
  write_byte(start_frame);
  write_byte(frame_rate);
  write_byte(life);
  write_byte(width);
  write_byte(noise);
  write_byte(rgb[0]);
  write_byte(rgb[1]);
  write_byte(rgb[2]);
  write_byte(brightness);
  write_byte(speed);
  message_end();
}

stock ufx_te_beaments(
  pid1,
  pid2,
  spr_idx,
  start_frame,
  Float:frame_rate,
  Float:life,
  Float:line_width,
  Float:noise,
  const rgb[3],
  brightness,
  Float:scroll_speed
)
{
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_BEAMENTS);
  write_short(pid1)
  write_short(pid2)
  write_short(spr_idx);
  write_byte(start_frame);
  write_byte(floatround(frame_rate/0.1));
  write_byte(floatround(life/0.1));
  write_byte(floatround(line_width/0.1));
  write_byte(floatround(noise/0.1));
  write_byte(rgb[0]);
  write_byte(rgb[1]);
  write_byte(rgb[2]);
  write_byte(brightness);
  write_byte(floatround(scroll_speed/0.1));
  message_end();
}

stock ufx_te_sprite(const origin[3], spr_idx, Float:scale, brightness)
{
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_SPRITE);
  write_coord(origin[0]);
  write_coord(origin[1]);
  write_coord(origin[2]);
  write_short(spr_idx);
  write_byte(floatround(scale/0.1));
  write_byte(brightness);
  message_end();
}

stock ufx_te_teleport(const origin[3])
{
  message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
  write_byte(TE_TELEPORT);
  write_coord(origin[0]);
  write_coord(origin[1]);
  write_coord(origin[2]);
  message_end();
}

stock ufx_te_sparks(const origin[3])
{
  message_begin(MSG_PVS, SVC_TEMPENTITY, origin, 0);
  write_byte(TE_SPARKS);
  write_coord(origin[0]);
  write_coord(origin[1]);
  write_coord(origin[2]);
  message_end();
}

/* Helpers */

/* https://github.com/ValveSoftware/halflife/blob/
 * c7240b965743a53a29491dd49320c88eecf6257b/dlls/util.cpp#L641-L652 */
stock _ufx_fixed_unsigned_16(Float:val, scale)
{
  new output = floatround(val*scale);
  return output < 0 ? 0 : output > 0xffff ? 0xffff : output;
}