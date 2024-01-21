#if defined _UTILS_MENU_INC
  #endinput
#endif
#define _UTILS_MENU_INC

#include <utils_menu_const>

/* Macros */

#define UMENU_READ_STRING(%0,%1)  ArrayGetString(%0, 0, %1, charsmax(%1));
#define UMENU_SET_STRING(%0,%1)   ArraySetString(%0, 0, %1);

/* Natives */

native umenu_register_category(cid = 0, bool:items_first = true);
native umenu_add_item(cid);

native umenu_display(pid, cid, bool:clear_ctg_chain = false);
native umenu_close(pid);

native umenu_get_current_ctg(pid);

native umenu_is_ctg_chain_empty(pid);

/* Forwards */

forward umenu_render(pid, id, UMenuContext:ctx, UMenuContextPosition:pos, Array:title, page, pagenum);
forward bool:umenu_select(pid, id, UMenuContext:ctx);
forward umenu_access(pid, id, UMenuContext:ctx);