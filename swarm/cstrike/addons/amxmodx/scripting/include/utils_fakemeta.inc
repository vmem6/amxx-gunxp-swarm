#if defined _UTILS_FAKEMETA_INC
  #endinput
#endif
#define _UTILS_FAKEMETA_INC

#include <fakemeta>

stock ufm_remove_entity(eid)
{
  set_pev(eid, pev_flags, FL_KILLME);
  dllfunc(DLLFunc_Think, eid);
}

stock ufm_remove_entities(const classname[31 + 1])
{
  new ent = 0;
  while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", classname)) && pev_valid(ent))
    ufm_remove_entity(ent);
}