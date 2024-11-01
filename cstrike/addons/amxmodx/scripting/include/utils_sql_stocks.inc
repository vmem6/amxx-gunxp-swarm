#if defined _UTILS_SQL_STOCKS_INC
  #endinput
#endif
#define _UTILS_SQL_STOCKS_INC

#include <utils_sql>

/* Wrappers */

/*
 * Wrapper around `usql_fetch` that provides condition formatting.
 *
 * @param columns           Columns of records to fetch. If equal to -1, fetches all columns.
 * @param cleanup           Whether to free memory allocated to `columns`.
 * @param cond_fmt          Formatted condition that `columns` must satisfy in order to be retrieved. If unspecified, fetches all `columns`.
 * @param ...               Variable number of formatting parameters.
 *
 * @noreturn
 */
stock usql_fetch_ex(
  Array:columns, bool:cleanup, const callback[] = "", const cond_fmt[] = "", any:...
)
{
  new cond[MAX_SQL_CONDITION_LENGTH + 1];
  vformat(cond, charsmax(cond), cond_fmt, 5);
  usql_fetch(columns, cond, cleanup, callback);
}

/*
 * Wrapper around `usql_update` that provides condition formatting.
 *
 * @param columns           Columns to update. Size must match that of `values`.
 * @param nvalues           Numeric values to which to set columns to.
 * @param svalues           String values to which to set columns to. Corresponding columns must be trailing.
 * @param cleanup           Whether to free memory allocated to `columns` and `values`.
 * @param cond_fmt          Formatted condition that record must satisfy in order to be updated.
 * @param ...               Variable number of formatting parameters.
 *
 * @noreturn
 */
stock usql_update_ex(
  Array:columns, Array:nvalues, Array:svalues, bool:cleanup, const callback[] = "",
  const cond_fmt[] = "", any:...
)
{
  new cond[MAX_SQL_CONDITION_LENGTH + 1];
  vformat(cond, charsmax(cond), cond_fmt, 7);
  usql_update(columns, nvalues, svalues, cond, cleanup, callback);
}

/* Fixers */

/*
 * Sanitizes a string for use in SQL queries.
 *
 * @param str             String to sanitize.
 * @param maxlen          Max. length of `str`.
 *
 * @noreturn
 */
stock usql_sanitize(str[], maxlen)
{
  replace_all(str, maxlen, "\\", "\\\\");
  replace_all(str, maxlen, "\0", "\\0");
  replace_all(str, maxlen, "\n", "\\n");
  replace_all(str, maxlen, "\r", "\\r");
  replace_all(str, maxlen, "\x1a", "\Z");
  replace_all(str, maxlen, "'", "\'");
  replace_all(str, maxlen, "^"", "\^"");
  replace_all(str, maxlen, "`", "\`");
}

/*
 * Desanitizes string for representation and intermediate use.
 *
 * @param str             String to be desanitized.
 * @param maxlen          Max. length of `str`.
 *
 * @noreturn
 */
stock usql_desanitize(str[], maxlen)
{
  replace_all(str, maxlen, "\", "");
}

/* Converters */

stock Array:usql_2darray(const arr[][], size, cellsize)
{
  new Array:ret = ArrayCreate(cellsize);
  for (new i = 0; i != size; ++i)
    ArrayPushArray(ret, arr[i]);
  return ret;
}

stock Array:usql_array(any:...)
{
  new paramsnum = numargs();
  if (paramsnum == 0) {
    return Invalid_Array;
  }

  new Array:ret = ArrayCreate();
  for (new i = 0; i != paramsnum; ++i) {
    ArrayPushCell(ret, getarg(i));
  }
  return ret;
}

/* These two should somehow be reconciled. */
stock Array:usql_asarray(any:...)
{
  new paramsnum = numargs();
  if (paramsnum == 0)
    return Invalid_Array;

  new Array:ret = ArrayCreate(MAX_SQL_COLUMN_VALUE_LENGTH + 1);
  new buf[MAX_SQL_COLUMN_VALUE_LENGTH + 1];
  for (new i = 0; i != paramsnum; ++i) {
    num_to_str(getarg(i), buf, charsmax(buf));
    ArrayPushString(ret, buf);
  }
  return ret;
}

stock Array:usql_fsarray(any:...)
{
  new paramsnum = numargs();
  if (paramsnum == 0)
    return Invalid_Array;

  new Array:ret = ArrayCreate(MAX_SQL_COLUMN_VALUE_LENGTH + 1);
  new buf[MAX_SQL_COLUMN_VALUE_LENGTH + 1];
  for (new i = 0; i != paramsnum; ++i) {
    float_to_str(Float:getarg(i), buf, charsmax(buf));
    ArrayPushString(ret, buf);
  }
  return ret;
}

stock Array:usql_sarray(any:...)
{
  new paramsnum = numargs();
  if (paramsnum == 0) {
    return Invalid_Array;
  }

  new Array:ret = ArrayCreate(MAX_SQL_COLUMN_VALUE_LENGTH + 1);
  new buf[MAX_SQL_COLUMN_VALUE_LENGTH + 2 + 1];
  for (new i = 0; i != paramsnum; ++i) {
    for (new j = 0;; ++j) {
      buf[j] = getarg(i, j);
      if (buf[j] == '^0') {
        break;
      }
    }
    ArrayPushString(ret, buf);
  }
  return ret;
}