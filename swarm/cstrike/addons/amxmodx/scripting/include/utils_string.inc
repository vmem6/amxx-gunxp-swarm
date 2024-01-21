#if defined _UTILS_STRING_INC
  #endinput
#endif
#define _UTILS_STRING_INC

#include <string>

/* Stocks */

/*
 * Splits `str` into numbers along `delim`, and stores them in `dst`.
 *
 * @param src            String to split into numbers.
 * @param dst            Array to store parsed numbers into.
 * @param sz             Maximum size of `dst`. If unspecified, assumes `dst` is capable of storing all numbers present in `src`.
 * @param delim          Delimiter along which to split `src`.
 *
 * @noreturn
 */
stock ustr_explode(const src[], dst[], sz = -1, const delim[] = " ")
{
#define BUF_SIZE 11 // max. length of signed 32-bit integer
  new buf[BUF_SIZE + 1];
#undef BUF_SIZE
  for (new i = 0, j = 0, idx = 0; i != sz && idx != -1; j += idx) {
    idx = split_string(src[j], delim, buf, charsmax(buf));
    if (buf[0] == '^0') {
      continue;
    }

    new end_pos = 0;
    new num = strtol(buf, end_pos);
    if (end_pos != 0) {
      dst[i++] = num;
    }
  }
}

/*
 * Concatenates number array into string `src`, delimited by `delim`.
 *
 * @param src             Array of numbers to concatenate.
 * @param sz              Size of `src`.
 * @param dst             Buffer to store concatenated string into.
 * @param maxlen          Maximum length of `dst`.
 * @param delim           Delimiter with which to separate numbers in `dst`.
 *
 * @noreturn
 */
stock ustr_implode(const src[], sz, dst[], maxlen, const sep[] = " ")
{
#define BUF_SIZE 11 // max. length of signed 32-bit integer
  new buf[BUF_SIZE + 1];
#undef BUF_SIZE
  for (new i = 0, len = 0; i != sz; ++i) {
    num_to_str(src[i], buf, charsmax(buf));
    if (len + strlen(buf) + strlen(sep) > maxlen) {
      break;
    }
    add(dst, maxlen, buf);
    len = add(dst, maxlen, sep);
  }
}

/*
 * Derived from https://forums.alliedmods.net/showpost.php?s=31d29c7a7d14420f07b7dc22a91b88d7&p=1707048&postcount=3
 */
stock bool:ustr_is_num(const str[], bool:require_decimal = false)
{
  new bool:decimal_found = false;
  for (new i = 0, ch = str[0]; ch != '^0'; ch = str[++i]) {
    if (ch == '.') {
      if (decimal_found) {
        return false;
      }
      decimal_found = true;
    } else if (!isdigit(ch) && !(i == 0 && ch == '-')) {
      return false;
    }
  }
  return !require_decimal || decimal_found;
}