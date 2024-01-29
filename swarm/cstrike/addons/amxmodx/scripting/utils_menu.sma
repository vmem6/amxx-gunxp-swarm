#include <amxmodx>
#include <amxmisc>

#include <utils_menu>
#include <utils_menu_const>

#define MAX_PLUGINS 512

enum _:Category
{
  ctg_id,
  ctg_parent_id,
  ctg_plugin,
  bool:ctg_items_first,
  Array:ctg_items,
  Array:ctg_categories
};

enum _:Item
{
  item_id,
  item_parent_id,
  item_plugin
};

enum _:Menu
{
  menu_page,
  menu_ctg
};

new g_id;
new Array:g_categories;
new Array:g_ctg_chain[MAX_PLAYERS + 1];

/* Used to modify strings passed in forwards. */
new Array:g_str;

new g_render_fwds[MAX_PLUGINS];
new g_select_fwds[MAX_PLUGINS];
new g_access_fwds[MAX_PLUGINS];

new g_menus[MAX_PLAYERS + 1][Menu];

public plugin_natives()
{
  register_library("utils_menu");

  register_native("umenu_register_category", "native_register_category");
  register_native("umenu_add_item", "native_add_item");

  register_native("umenu_display", "native_display");
  register_native("umenu_close", "native_close");
  register_native("umenu_refresh", "native_refresh");

  register_native("umenu_get_current_ctg", "native_get_current_ctg");

  register_native("umenu_is_ctg_chain_empty", "native_is_ctg_chain_empty");
}

public plugin_init()
{
  // TODO: register_plugin(...);

  /* Miscellaneous */

  g_categories = ArrayCreate(Category);
  for (new i = 1; i != sizeof(g_ctg_chain); ++i)
    g_ctg_chain[i] = ArrayCreate();

  g_str = ArrayCreate(UMENU_MAX_TITLE_LENGTH + 1);
  ArrayPushString(g_str, "");
}

public plugin_end()
{
  destroy_categories(g_categories);
  for (new i = 1; i != sizeof(g_ctg_chain); ++i)
    ArrayDestroy(g_ctg_chain[i]);

  ArrayDestroy(g_str);
}

destroy_categories(Array:categories)
{
  new ctg[Category];
  for (new i = 0; i != ArraySize(categories); ++i) {
    ArrayGetArray(categories, i, ctg);
    ArrayDestroy(ctg[ctg_items]);
    if (ctg[ctg_categories] != Array:0) {
      destroy_categories(ctg[ctg_categories]);
      ArrayDestroy(ctg[ctg_categories]);
    }
  }
  ArrayDestroy(categories);

  for (new i = 0; i != MAX_PLUGINS; ++i) {
    DestroyForward(g_render_fwds[i]);
    DestroyForward(g_select_fwds[i]);
    DestroyForward(g_access_fwds[i]);
  }
}

/* Hooks */

public client_putinserver(pid)
{
  ArrayClear(g_ctg_chain[pid]);
}

/* Natives */

public native_register_category(plugin, argc)
{
  enum {
    param_cid = 1,
    param_items_first = 2
  };
  return register_category(plugin, get_param(param_cid), bool:get_param(param_items_first));
}

public native_add_item(plugin, argc)
{
  enum { param_cid = 1 };
  return add_item(plugin, get_param(param_cid));
}

public native_display(plugin, argc)
{
  enum {
    param_pid = 1,
    param_cid = 2,
    param_clear_ctg_chain = 3
  };
  render(get_param(param_pid), get_param(param_cid), 0, bool:get_param(param_clear_ctg_chain));
}

public native_close(plugin, argc)
{
  enum { param_pid = 1 };

  new pid = get_param(param_pid);

  ArrayClear(g_ctg_chain[pid]);
  g_menus[pid][menu_page] = 0;
  g_menus[pid][menu_ctg]  = -1;

  if (is_user_connected(pid))
    menu_cancel(pid);
}

public native_refresh(plugin, argc)
{
  enum { param_pid = 1 };
  new pid = get_param(param_pid);
  if (g_menus[pid][menu_ctg] != -1)
    render(pid, g_menus[pid][menu_ctg], g_menus[pid][menu_page]);
}

public native_get_current_ctg(plugin, argc)
{
  enum { param_pid = 1 };
  return g_menus[get_param(param_pid)][menu_ctg];
}

public native_is_ctg_chain_empty(plugin, argc)
{
  enum { param_pid = 1 };
  return ArraySize(g_ctg_chain[get_param(param_pid)]) == 0;
}

/* Interface */

render(pid, cid, page = 0, bool:clear_ctg_chain = false)
{
  if (clear_ctg_chain)
    ArrayClear(g_ctg_chain[pid]);

  if (!is_user_connected(pid))
    return;

  new ctg[Category];
  if (!find(cid, umenu_ctx_category, g_categories, .ctg_ret = ctg)) {
    /* TODO: set fail state/log? */
    return;
  }

  new mid = menu_create("", "handle_menu");
  g_menus[pid][menu_page] = page;
  g_menus[pid][menu_ctg] = ctg[ctg_id];

  if (ctg[ctg_items_first]) {
    render_ctx(pid, umenu_ctx_item, ctg, mid);
    render_ctx(pid, umenu_ctx_category, ctg, mid);
  } else {
    render_ctx(pid, umenu_ctx_category, ctg, mid);
    render_ctx(pid, umenu_ctx_item, ctg, mid);
  }

  menu_setprop(mid, MPROP_SHOWPAGE, false);
  menu_setprop(mid, MPROP_PAGE_CALLBACK, "page_callback");
  menu_setprop(mid, MPROP_EXIT, "MEXIT_ALL");

  new str[UMENU_MAX_TITLE_LENGTH + 1];

  formatex(str, charsmax(str), "%L", pid, "MENU_PREV_PAGE");
  menu_setprop(mid, MPROP_BACKNAME, str);

  formatex(str, charsmax(str), "%L", pid, "MENU_NEXT_PAGE");
  menu_setprop(mid, MPROP_NEXTNAME, str);

  formatex(
    str, charsmax(str), "%L", pid, ArraySize(g_ctg_chain[pid]) > 0 ? "MENU_RETURN" : "MENU_EXIT"
  );
  menu_setprop(mid, MPROP_EXITNAME, str);

  menu_update_title(pid, mid);

  menu_display(pid, mid, page);
}

render_ctx(pid, UMenuContext:ctx, ctg_parent[Category], menu)
{
  new str[UMENU_MAX_TITLE_LENGTH];
  new info[3];
  new Array:arr;

  if (ctx == umenu_ctx_item) {
    new item[Item];
    arr = ctg_parent[ctg_items];
    for (new i = 0; i != ArraySize(arr); ++i) {
      ArrayGetArray(arr, i, item);
      ExecuteForward(
        g_render_fwds[item[item_plugin]], _,
        pid, item[item_id], umenu_ctx_item, umenu_cp_list, g_str, 0, 0
      );
      UMENU_READ_STRING(g_str, str)

      info[0] = item[item_id];
      info[1] = _:umenu_ctx_item;
      menu_additem(menu, str, info, .callback = menu_makecallback("item_access_callback"));
    }
  } else {
    new ctg[Category];
    arr = ctg_parent[ctg_categories];
    for (new i = 0; i != ArraySize(arr); ++i) {
      ArrayGetArray(arr, i, ctg);
      ExecuteForward(
        g_render_fwds[ctg[ctg_plugin]], _,
        pid, ctg[ctg_id], umenu_ctx_category, umenu_cp_list, g_str, 0, 0
      );
      UMENU_READ_STRING(g_str, str)

      info[0] = ctg[ctg_id];
      info[1] = _:umenu_ctx_category;
      info[2] = ctg_parent[ctg_id];
      menu_additem(menu, str, info, .callback = menu_makecallback("item_access_callback"));
    }
  }
}

public page_callback(pid, status, mid)
{
  g_menus[pid][menu_page] += status == MENU_MORE ? 1 : -1;
  menu_update_title(pid, mid);
}

public item_access_callback(pid, menu, item)
{
  new info[3];
  menu_item_getinfo(menu, item, .info = info, .infolen = sizeof(info));

  new plugin;

  new id = info[0];
  new UMenuContext:ctx = UMenuContext:info[1];
  if (ctx == umenu_ctx_item) {
    new item[Item];
    find(id, umenu_ctx_item, g_categories, .item_ret = item);
    plugin = item[item_plugin];
  } else {
    new ctg[Category];
    find(id, umenu_ctx_category, g_categories, .ctg_ret = ctg);
    plugin = ctg[ctg_plugin];
  }

  new ret;
  ExecuteForward(g_access_fwds[plugin], ret, pid, id, ctx);

  return ret;
}

public handle_menu(pid, menu, item)
{
  new Array:ctg_chain = g_ctg_chain[pid];
  new chainlen = ArraySize(ctg_chain);

  switch (item) {
    case MENU_EXIT: {
      /* Backtrack category chain if not empty. */
      if (chainlen > 0) {
        new prev_cid = ArrayGetCell(ctg_chain, chainlen - 1);
        ArrayDeleteItem(ctg_chain, chainlen - 1);
        render(pid, prev_cid);
      } else {
        g_menus[pid][menu_page] = 0;
        g_menus[pid][menu_ctg]  = -1;
      }
    }

    default: {
      new info[3];
      menu_item_getinfo(menu, item, .info = info, .infolen = sizeof(info));

      new id = info[0];
      new UMenuContext:ctx = UMenuContext:info[1];
      if (ctx == umenu_ctx_item) {
        new item[Item];
        find(id, umenu_ctx_item, g_categories, .item_ret = item);

        new bool:rerender;
        ExecuteForward(g_select_fwds[item[item_plugin]], rerender, pid, id, ctx);
        if (rerender)
          render(pid, item[item_parent_id], g_menus[pid][menu_page]);
      } else {
        /* Inform plugins of selected category. */
        new ctg[Category];
        find(id, umenu_ctx_category, g_categories, .ctg_ret = ctg);
        ExecuteForward(g_select_fwds[ctg[ctg_plugin]], _, pid, id, ctx);
        /* Add to category chain. */
        ArrayPushCell(ctg_chain, info[2]);
        render(pid, id);
      }
    }
  }

  menu_destroy(menu);
  return PLUGIN_HANDLED;
}

/* Helpers */

register_category(plugin, req_cid, bool:items_first)
{
  new Array:categories;
  if (req_cid == 0) {
    categories = g_categories;
  } else {
    new req_ctg[Category];
    if (!find(req_cid, umenu_ctx_category, g_categories, .ctg_ret = req_ctg)) {
      return UMENU_INVALID_CATEGORY;
    }
    categories = req_ctg[ctg_categories];
  }

  new ctg[Category];
  ctg[ctg_id]           = ++g_id;
  ctg[ctg_parent_id]    = req_cid;
  ctg[ctg_plugin]       = plugin;
  ctg[ctg_items_first]  = items_first;
  ctg[ctg_items]        = ArrayCreate(Item);
  ctg[ctg_categories]   = ArrayCreate(Category);
  ArrayPushArray(categories, ctg);
  
  if (g_render_fwds[plugin] == 0) {
    g_render_fwds[plugin] = CreateOneForward(
      plugin, "umenu_render", FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_CELL
    );
    g_select_fwds[plugin] = CreateOneForward(plugin, "umenu_select", FP_CELL, FP_CELL, FP_CELL);
    g_access_fwds[plugin] = CreateOneForward(plugin, "umenu_access", FP_CELL, FP_CELL, FP_CELL);
  }

  return g_id;
}

add_item(plugin, req_cid)
{
  new req_ctg[Category];
  if (!find(req_cid, umenu_ctx_category, g_categories, .ctg_ret = req_ctg))
    return UMENU_INVALID_ITEM;

  new item[Item];
  item[item_id]         = ++g_id;
  item[item_parent_id]  = req_cid;
  item[item_plugin]     = plugin;
  ArrayPushArray(req_ctg[ctg_items], item);

  return g_id;
}

bool:find(id, UMenuContext:ctx, Array:categories, item_ret[Item] = {}, ctg_ret[Category] = {})
{
  if (_:categories <= 0)
    return false;

  new _ctg[Category];

  /* Search surface-level. */
  if (ctx == umenu_ctx_item) {
    new item[Item];
    for (new i = 0; i != ArraySize(categories); ++i) {
      ArrayGetArray(categories, i, _ctg);
      new Array:items = _ctg[ctg_items];
      if (_:items <= 0)
        continue;

      for (new i = 0; i != ArraySize(items); ++i) {
        ArrayGetArray(items, i, item);
        if (item[item_id] == id) {
          ArrayGetArray(items, i, item_ret);
          return true;
        }
      }
    }
  } else {
    for (new i = 0; i != ArraySize(categories); ++i) {
      ArrayGetArray(categories, i, _ctg);
      if (_ctg[ctg_id] == id) {
        ArrayGetArray(categories, i, ctg_ret);
        return true;
      }
    }
  }

  /* Search through nest. */
  for (new i = 0; i != ArraySize(categories); ++i) {
    ArrayGetArray(categories, i, _ctg);
    if (find(id, ctx, _ctg[ctg_categories], item_ret, ctg_ret))
      return true;
  }

  return false;
}

menu_update_title(pid, mid)
{
  new cid = g_menus[pid][menu_ctg];
  new ctg[Category];

  if (!find(cid, umenu_ctx_category, g_categories, .ctg_ret = ctg))
    return;

  new str[UMENU_MAX_TITLE_LENGTH + 1];
  ExecuteForward(
    g_render_fwds[ctg[ctg_plugin]], _,
    pid, cid,
    umenu_ctx_category, umenu_cp_title,
    g_str,
    g_menus[pid][menu_page] + 1, menu_pages(mid)
  );
  UMENU_READ_STRING(g_str, str)
  menu_setprop(mid, MPROP_TITLE, str);
}