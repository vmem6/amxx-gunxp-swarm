#if defined _UTILS_BITS_INC
  #endinput
#endif
#define _UTILS_BITS_INC

/* Credits: Bugsy @ https://forums.alliedmods.net/showthread.php?t=139916 */

#define UBITS_PSET(%0,%1)   %0 |= (1 << (%1 & 31))
#define UBITS_PUNSET(%0,%1) %0 &= ~(1 << (%1 & 31))
#define UBITS_PCHECK(%0,%1) bool:!!(%0 & (1 << (%1 & 31)))

#define UBITS_SET(%0,%1)    %0 |= (1 << %1)
#define UBITS_UNSET(%0,%1)  %0 &= ~(1 << %1)
#define UBITS_CHECK(%0,%1)  bool:!!(%0 & (1 << %1))

stock bool:ubits_ptoggle(&bitfield, idx)
{
  if (UBITS_PCHECK(bitfield, idx))
    UBITS_PUNSET(bitfield, idx);
  else
    UBITS_PSET(bitfield, idx);
  return UBITS_PCHECK(bitfield, idx);
}

stock bool:ubits_toggle(&bitfield, idx)
{
  if (UBITS_CHECK(bitfield, idx))
    UBITS_UNSET(bitfield, idx);
  else
    UBITS_SET(bitfield, idx);
  return UBITS_CHECK(bitfield, idx);
}