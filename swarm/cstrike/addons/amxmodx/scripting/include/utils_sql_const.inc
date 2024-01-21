#if defined _UTILS_SQL_CONST_INC
  #endinput
#endif
#define _UTILS_SQL_CONST_INC

/* Defines */

/* These are mostly arbitrary. */

#define MAX_SQL_HOSTNAME_LENGTH        64
#define MAX_SQL_USER_NAME_LENGTH       64
#define MAX_SQL_PASSWORD_LENGTH        128
#define MAX_SQL_DATABASE_NAME_LENGTH   128
#define MAX_SQL_TABLE_NAME_LENGTH      128

#define MAX_SQL_COLUMN_NAME_LENGTH  64
#define MAX_SQL_COLUMN_VALUE_LENGTH 128

#define MAX_SQL_COLUMNS 64

#define MAX_SQL_CONDITION_LENGTH 512

#define MAX_SQL_DATA_SIZE 16

/* Enums */

enum SQLColumnType
{
  sct_int = 0,
  sct_varchar
}

enum _:SQLColumn
{
  sc_name[MAX_SQL_COLUMN_NAME_LENGTH + 1],
  SQLColumnType:sc_type,
  sc_size,
  sc_def_val[MAX_SQL_COLUMN_VALUE_LENGTH + 1],
  bool:sc_not_null,
  bool:sc_auto_increment
}

enum SQLQuery
{
  sq_query = 0,
  sq_create_table,
  sq_fetch,
  sq_insert,
  sq_update
}