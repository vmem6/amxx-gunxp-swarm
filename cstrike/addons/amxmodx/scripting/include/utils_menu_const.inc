#if defined _UTILS_MENU_CONST_INC
  #endinput
#endif
#define _UTILS_MENU_CONST_INC

/* Defines */

#define UMENU_INVALID_CATEGORY  -1
#define UMENU_INVALID_ITEM      -1
#define UMENU_INVALID_NOTICE    -1

#define UMENU_MAX_TITLE_LENGTH  256
#define UMENU_MAX_NOTICE_LENGTH 128

/* Enums */

enum UMenuContext
{
  umenu_ctx_item = 0,
  umenu_ctx_category,
  umenu_ctx_notice
}

enum UMenuContextPosition
{
  umenu_cp_list = 0,
  umenu_cp_title,
  umenu_cp_notice
}
