#include <amxmodx>
#include <hamsandwich>
#include <cstrike>
#include <fakemeta_util>

#include <gunxp_swarm>
#include <gunxp_swarm_const>

#include <utils_offsets>

#define MAX_PLUGINS 512

new Array:g_uls[GxpUlClass];

new g_ul_id;

new g_fwd_activated_ul;

/* Maintained for backwards compatibility. */
new g_fwd_bc_activated_ul[MAX_PLUGINS];
new g_fwd_bc_deactivated_ul;

/* Messages */

new g_msgid_curweapon;

public plugin_natives()
{
  register_library("gxp_swarm_unlocks");

  register_native("gxp_ul_get_class_items", "native_get_class_items");
  register_native("gxp_ul_get_by_id", "native_get_by_id");

  register_native("gxp_ul_activate", "native_activate");
  register_native("gxp_ul_activate_free", "native_activate_free");
  register_native("gxp_ul_activate_newbie", "native_activate_newbie");

  register_native("gxp_ul_deactivate", "native_deactivate");

  /* Maintained for backwards compatibility. */
  register_native("register_gxm_item", "native_register_item");
  register_native("register_item_gxm", "native_register_item");
}

public plugin_precache()
{
  g_uls[gxp_ul_cls_knife]     = ArrayCreate(GxpUl);
  g_uls[gxp_ul_cls_secondary] = ArrayCreate(GxpUl);
  g_uls[gxp_ul_cls_primary]   = ArrayCreate(GxpUl);
  g_uls[gxp_ul_cls_nade]      = ArrayCreate(GxpUl);
  g_uls[gxp_ul_cls_item]      = ArrayCreate(GxpUl);
}

public plugin_init()
{
  register_plugin(_GXP_SWARM_ULS_PLUGIN, _GXP_SWARM_VERSION, _GXP_SWARM_AUTHOR);

  /* Forwards */

  g_fwd_activated_ul = CreateMultiForward("gxp_ul_activated", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);

  /* Forwards > Maintained for backwards compatibility */

  g_fwd_bc_deactivated_ul = CreateMultiForward("gxm_item_disabled", ET_IGNORE, FP_CELL);

  /* Messages */

  g_msgid_curweapon = get_user_msgid("CurWeapon");
}

public plugin_end()
{
  ArrayDestroy(Array:g_uls[gxp_ul_cls_knife]);
  ArrayDestroy(Array:g_uls[gxp_ul_cls_secondary]);
  ArrayDestroy(Array:g_uls[gxp_ul_cls_primary]);
  ArrayDestroy(Array:g_uls[gxp_ul_cls_nade]);
  ArrayDestroy(Array:g_uls[gxp_ul_cls_item]);

  DestroyForward(g_fwd_activated_ul);
  for (new i = 0; i != sizeof(g_fwd_activated_ul); ++i)
    DestroyForward(g_fwd_bc_activated_ul[i]);
  DestroyForward(g_fwd_bc_deactivated_ul);
}

/* Natives */

public native_register_item(plugin, argc)
{
  /* TODO: add validation. */

  enum {
    param_title     = 1,
    param_desc      = 2,
    param_cost      = 3,
    param_level     = 4,
    param_class     = 5,
    param_access    = 6,
    param_weapon_id = 7
  };

  new ul[GxpUl];

  get_string(param_title, ul[gxp_ul_title], charsmax(ul[gxp_ul_title]));
  get_string(param_desc, ul[gxp_ul_description], charsmax(ul[gxp_ul_description]));

  trim(ul[gxp_ul_title]);
  trim(ul[gxp_ul_description]);

  new class = get_param(param_class);

  ul[gxp_ul_id]         = ++g_ul_id;
  ul[gxp_ul_plugin]     = plugin;
  /* This hackery is used to maintain compatibility with existing ULs. */
  ul[gxp_ul_class]      = GxpUlClass:((class & ~(1 << 4)) - 1);
  ul[gxp_ul_cost]       = get_param(param_cost);
  ul[gxp_ul_level]      = get_param(param_level);
  ul[gxp_ul_access]     = get_param(param_access);
  ul[gxp_ul_weapon_id]  = get_param(param_weapon_id);
  ul[gxp_ul_newbie]     = bool:(class & (1 << 4));

  ArrayPushArray(g_uls[_:ul[gxp_ul_class]], ul);

  g_fwd_bc_activated_ul[plugin] = CreateOneForward(plugin, "gxm_item_enabled", FP_CELL);

  return g_ul_id;
}

public Array:native_get_class_items(plugin, argc)
{
  enum { param_class = 1 };
  return g_uls[get_param(param_class)];
}

public native_get_by_id(plugin, argc)
{
  enum {
    param_id = 1,
    param_ul = 2
  };
  new ul[GxpUl];
  get_ul_by_id(get_param(param_id), ul);
  set_array(param_ul, ul, sizeof(ul));
}

public native_activate(plugin, argc)
{
  enum {
    param_pid = 1,
    param_ul = 2
  };
  new ul[GxpUl];
  get_array(param_ul, ul, sizeof(ul));
  activate(get_param(param_pid), ul);
}

public native_activate_free(plugin, argc)
{
  enum { param_pid = 1 };

  new pid = get_param(param_pid);
  new lvl = gxp_get_player_data(pid, pd_level);
  new ul[GxpUl];
  for (new i = 0; i != GxpUlClass; ++i) {
    new Array:uls = g_uls[i];
    for (new j = 0; j != ArraySize(uls); ++j) {
      ArrayGetArray(uls, j, ul);
      if (ul[gxp_ul_cost] == 0 && lvl >= ul[gxp_ul_level])
        activate(pid, ul, .bypass_reqs = true, .automatic = true);
    }
  }
}

public native_activate_newbie(plugin, argc)
{
  enum { param_pid = 1 };

  new pid = get_param(param_pid);
  if (!gxp_is_newbie(pid))
    return;

  new ul[GxpUl];
  for (new i = 0; i != GxpUlClass; ++i) {
    new Array:uls = g_uls[i];
    for (new j = 0; j != ArraySize(uls); ++j) {
      ArrayGetArray(uls, j, ul);
      if (ul[gxp_ul_newbie])
        activate(pid, ul, .bypass_reqs = true, .automatic = true);
    }
  }
}

public native_deactivate(plugin, argc)
{
  enum { param_pid = 1 };
  deactivate(get_param(param_pid));
}

/* Helpers */

activate(pid, const ul[GxpUl], bool:bypass_reqs = false, bool:automatic = false)
{
  /* TODO: add (more?) validation. */

  new Array:player_uls[GxpUlClass];
  gxp_get_player_data(pid, pd_uls, _:player_uls);
  new Array:uls = player_uls[_:ul[gxp_ul_class]];

  /* Avoid dupes. */
  for (new i = 0; i != ArraySize(uls); ++i) {
    if (ArrayGetCell(uls, i) == ul[gxp_ul_id])
      return;
  }

  if (!bypass_reqs) {
    if (
      gxp_get_player_data(pid, pd_xp_curr) < ul[gxp_ul_cost]
      || gxp_get_player_data(pid, pd_level) < ul[gxp_ul_level]
    ) {
      return;
    }
    gxp_take_xp(pid, ul[gxp_ul_cost], .decrease_lvl = false);
  }

  ArrayPushCell(uls, ul[gxp_ul_id]);

  ExecuteForward(g_fwd_activated_ul, _, pid, ul[gxp_ul_id], automatic);
  ExecuteForward(g_fwd_bc_activated_ul[ul[gxp_ul_plugin]], _, pid);

  if (get_user_weapon(pid) == ul[gxp_ul_weapon_id])
    ExecuteHamB(Ham_Item_Deploy, fm_get_user_weapon_entity(pid, ul[gxp_ul_weapon_id]));
}

deactivate(pid)
{
  ExecuteForward(g_fwd_bc_deactivated_ul, _, pid);

  new Array:player_uls[GxpUlClass];
  gxp_get_player_data(pid, pd_uls, _:player_uls);

  new ul[GxpUl];
  new bool:deployed = false;
  new wid = get_user_weapon(pid);
  for (new ul_cls = 0; ul_cls != GxpUlClass; ++ul_cls) {
    if (deployed) {
      ArrayClear(player_uls[ul_cls]);
      continue;
    }

    for (new j = 0; j != ArraySize(player_uls[ul_cls]); ++j) {
      get_ul_by_id(ArrayGetCell(player_uls[ul_cls], j), ul);

      new ul_wid = ul[gxp_ul_weapon_id];
      new bool:has_ammo = false;

      static const no_ammo_wpns[] = {
        CSW_NONE,
        CSW_HEGRENADE,
        CSW_C4,
        CSW_SMOKEGRENADE,
        CSW_FLASHBANG,
        CSW_KNIFE,
        CSW_VEST,
        CSW_VESTHELM,
        CSW_SHIELDGUN,
      };

      for (new i = 0; i != sizeof(no_ammo_wpns); ++i) {
        if (ul_wid == no_ammo_wpns[i]) {
          has_ammo = false;
          break;
        }
      }

      if (has_ammo) {
        /* Reset clip and bpammo of weapons in inventory. */
        new wpn_ent = fm_get_user_weapon_entity(pid, ul_wid);
        if (pev_valid(wpn_ent)) {
          set_pdata_int(wpn_ent, UXO_I_CLIP, _gxp_wpn_default_clip[ul_wid]);
          cs_set_user_bpammo(pid, ul_wid, _gxp_wpn_default_bpammo[ul_wid]);
        }
      }

      /* Re-deploy weapon if it's currently equipped. */
      if (wid == ul_wid) {
        if (!deployed) {
          ExecuteHamB(Ham_Item_Deploy, fm_get_user_weapon_entity(pid, wid));
          deployed = true;
        }

        emessage_begin(MSG_ONE, g_msgid_curweapon, .player = pid);
        ewrite_byte(0);
        ewrite_byte(ul_wid);
        ewrite_byte(_gxp_wpn_default_clip[ul_wid]);
        emessage_end();
      }
    }

    ArrayClear(player_uls[ul_cls]);
  }
}

get_ul_by_id(id, ul_ret[GxpUl])
{
  new ul[GxpUl];
  for (new i = 0; i != GxpUlClass; ++i) {
    for (new j = 0; j != ArraySize(g_uls[i]); ++j) {
      ArrayGetArray(g_uls[i], j, ul);
      if (ul[gxp_ul_id] == id) {
        ArrayGetArray(g_uls[i], j, ul_ret);
        return;
      }
    }
  }
}