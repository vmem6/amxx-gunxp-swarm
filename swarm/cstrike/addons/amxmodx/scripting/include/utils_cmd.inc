#if defined _UTILS_CMD_INC
  #endinput
#endif
#define _UTILS_CMD_INC

/* Defines */

/* Mostly arbitrary. */
#define UCMD_MAX_CMD_LENGTH           32
#define UCMD_MAX_HANDLER_NAME_LENGTH  96
#define UCMD_MAX_CMD_STRING_LENGTH    76

/* Macros */

/*
 * Wrapper around `ucmd_handle_cmd()` that alleviates the need to explicitly
 * read the command string.
 *
 * @param %0          ID of player who invoked the command.
 * @param %1          List of handlers, each of which must be of type `UCmdCommand`.
 * @param %2          Size of `handlers`.
 *
 * @return            `PLUGIN_HANDLED` if an appropriate handler is found; `PLUGIN_CONTINUE` otherwise.
 * 
 */
#define UCMD_HANDLE_CMD_EX(%0,%1,%2)          \
  new buffer[UCMD_MAX_CMD_STRING_LENGTH + 1]; \
  read_args(buffer, charsmax(buffer));        \
  return ucmd_handle_cmd(%0, buffer, %1, %2)

/* Enums */

/*
 * Command structure:
 *   - `ucmd_cmd` - the actual command;
 *   - `ucmd_handler` - command handler, the prototype of which is
 *     
 *       public cmd_handler(pid, const args[UCMD_MAX_CMD_STRING_LENGTH])
 *
 *     where:
 *       - `pid` - ID of player who invoked the command;
 *       - `args` - argument string.
 *
 */
enum UCmdCommand
{
  ucmd_cmd[UCMD_MAX_CMD_LENGTH + 1],
  ucmd_handler[UCMD_MAX_HANDLER_NAME_LENGTH + 1]
};

/* Stocks */

/*
 * Given a command string in the form of
 *
 *   CMD ARG1 ARG2 ARG3
 *
 * searches through `handlers` for a handler function to which the player ID and
 * argument string are then passed.
 * Assumed usage is in clcmd/concmd hooks, so it returns `PLUGIN_HANDLED` if an
 * appropriate handler is found in order to surpress any further processing
 * (most notably, printing to chat).
 *
 * @param pid               ID of player who invoked the command.
 * @param buffer            Command string.
 * @param handlers          List of handlers, each of which is of type `UCmdCommand`.
 * @param sz                Size of `handlers`.
 *
 * @return                  `PLUGIN_HANDLED` if an appropriate handler is found; `PLUGIN_CONTINUE` otherwise.
 */
stock ucmd_handle_cmd(
  pid, buffer[UCMD_MAX_CMD_STRING_LENGTH + 1], const handlers[][UCmdCommand], sz
)
{
  new cmd[UCMD_MAX_CMD_LENGTH + 1];
  remove_quotes(buffer);
  argparse(buffer, 0, cmd, charsmax(cmd));

  for (new i = 0; i != sz; ++i) {
    if (equali(cmd, handlers[i][ucmd_cmd])) {
      callfunc_begin(handlers[i][ucmd_handler]);
      callfunc_push_int(pid);
      /* Pass the rest of the cmd as arguments. */
      replace_stringex(buffer, charsmax(buffer), cmd, "");
      trim(buffer);
      callfunc_push_str(buffer);
      callfunc_end();
      return PLUGIN_HANDLED;
    }
  }

  return PLUGIN_CONTINUE;
}