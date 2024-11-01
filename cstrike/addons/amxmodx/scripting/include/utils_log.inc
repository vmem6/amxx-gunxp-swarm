#if defined _UTILS_LOG_INC
  #endinput
#endif
#define _UTILS_LOG_INC

#include <amxmodx>

/* Defines */

#define GLOBAL  0
#define INFO    1
#define WARNING 2
#define ERROR   3
#define FATAL   4

/* Macros */

#if defined DEBUG
  #define ULOG(%0,%1,%2) ulogex(%0, %1, %2)
#else
  #define ULOG(%0,%1,%2) //
#endif // DEBUG

/* Natives */

native ulog_register_logger(const id[], const path[], verbosity = GLOBAL);
native ulog(const logger_id[], verbosity, pid, const msg[]);

stock ulogex(const logger_id[], verbosity, pid, const fmt[], any:...)
{
  static msg[512 + 1];
  vformat(msg, charsmax(msg), fmt, 5);
  ulog(logger_id, verbosity, pid, msg);
}
