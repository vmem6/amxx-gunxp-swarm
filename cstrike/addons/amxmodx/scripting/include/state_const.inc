#if defined _STATE_CONST_INC
  #endinput
#endif
#define _STATE_CONST_INC

#include <amxmodx>

/* STATE:CORE */

#define STATE_MAX_DYNAMIC_ID_LENGTH MAX_AUTHID_LENGTH

enum StateDynamicIDType
{
  s_did_t_unknown = 0,
  s_did_t_authid,
  s_did_t_ip,
  s_did_t_name
};