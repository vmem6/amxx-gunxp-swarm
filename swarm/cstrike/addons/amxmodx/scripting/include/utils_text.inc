#if defined _UTILS_TEXT_INC
  #endinput
#endif
#define _UTILS_TEXT_INC

/*
 * Prints formatted message to the players' chat/-s.
 *
 * @param pid         Receiving player ID (or 0 for all players).
 * @param prefix      Prefix to prepend the message with.
 * @param fmt         Formatting rules.
 * @param ...         Variable number of formatting parameters.
 *
 * @noreturn
 *
 * NOTE: should only be used when either `pid` != 0, formatting doesn't include
 * multilingual specifier, or language specifier is `LANG_SERVER`. If `pid` is
 * 0, formatting is multilingual, and the language specifier is `LANG_PLAYER`,
 * this will yield unpredictable results (e.g., text in random languages not
 * chosen by the end-user).
 *
 * TODO: eventually, the above should somehow be fixed.
 */
stock chat_print(const pid, const prefix[], const fmt[], any:...)
{
  new msg[MAX_FMT_LENGTH + 1];
  vformat(msg, charsmax(msg), fmt, 4);
  client_print_color(pid, print_team_default, "%s%s", prefix, msg);
}

/*
 * Prints formatted message to players' console/-s.
 *
 * @param pid         Receiving player ID (or 0 for all players).
 * @param fmt         Formatting rules.
 * @param ...         Variable number of formatting parameters.
 *
 * @noreturn
 */
stock con_print(const pid, const fmt[], any:...)
{
  static msg[1024 + 1];
  vformat(msg, charsmax(msg), fmt, 3);

  if (pid != 0) {
    console_print(pid, msg);
    return;
  }

  new players[MAX_PLAYERS];
  new playersnum = 0;
  get_players_ex(players, playersnum, GetPlayers_ExcludeBots);
  for (new i = 0; i != playersnum; ++i) {
    console_print(players[i], msg);
  }
}

/*
 * Ellipsizes string (replaces chars with ellipsis (...)) if it is longer than
 * specified max. length.
 *
 * @param str         String to be ellipsized.
 * @param maxlen      Max. length `str` can be before it is ellipsized.
 *
 * @noreturn
 */
stock ellipsize(str[], maxlen)
{
  if (strlen(str) <= maxlen || maxlen < (1 + 3 + 3)) {
    return;
  }

  new len = strlen(str);
  str[maxlen - 6] = '.';
  str[maxlen - 5] = '.';
  str[maxlen - 4] = '.';
  str[maxlen - 3] = str[len - 3];
  str[maxlen - 2] = str[len - 2];
  str[maxlen - 1] = str[len - 1];
  str[maxlen - 0] = str[len - 0];
  copy(str, maxlen, str);
}

/*
 * Replaces instances of `^1`, `^2`, `^3`, and `^4` with corresponding bytes.
 * Necessary when AMX Mod X fails to interpret these strings for us. (Note:
 * doesn't seem to be an issue on AMXX v1.10.x, though further testing is
 * needed.)
 *
 * @param str         String to be fixed.
 * @param maxlen      Maximum length of string buffer.
 *
 * @noreturn
 */
stock fix_colors(str[], maxlen)
{
  new color[3] = { '^^', '1', '^0' };
  new fixed[2] = { 0x1, '^0' };
#define TB_COLOR_DEFAULT  0x1
#define TB_COLOR_GREEN    0x4
  for (new i = TB_COLOR_DEFAULT; i <= TB_COLOR_GREEN; ++i) {
    color[1] = '0' + i;
    fixed[0] = i;
    replace_string(str, maxlen, color, fixed);
  }
}