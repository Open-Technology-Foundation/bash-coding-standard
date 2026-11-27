/* trim_common.h - shared CLI / stdin / escape helpers for trim-c family */
#ifndef TRIM_COMMON_H
#define TRIM_COMMON_H

#include <stdio.h>
#include <stdbool.h>
#include <stddef.h>

#define TRIM_VERSION "1.0.0"
#define EXIT_INVAL   22  /* matches Bash die 22 */

typedef struct {
    bool        escape;        /* -e flag */
    const char *prog;          /* argv[0] basename */
    char      **args;          /* positional args (NULL if none) */
    int         argc;          /* count of positional args */
} trim_opts_t;

/* Parse argv. On --help/--version prints and exits 0.
 * On unknown option prints "$prog: ✗ Unknown option '...'" and exits 22.
 * Returns 0 on success; opts->args/argc filled. */
int  trim_parse(int argc, char **argv, trim_opts_t *opts,
                const char *short_desc, const char *help_body);

/* Join opts->args[0..argc-1] with single space into malloc'd buffer
 * (Bash $* with default IFS). If opts->escape, runs trim_escape on result.
 * Returns NULL if opts->argc == 0. Caller frees. */
char *trim_join_args(const trim_opts_t *opts, size_t *out_len);

/* printf %b semantics: \\ \a \b \c \e \f \n \r \t \v \" \' \0NNN \NNN \xHH.
 * \c halts emission. Returns malloc'd buffer (caller frees). *out_len set. */
char *trim_escape(const char *in, size_t in_len, size_t *out_len);

/* die: print "$prog: ✗ msg\n" to stderr and exit(code). Never returns. */
void  trim_die(const trim_opts_t *opts, int code, const char *fmt, ...);

/* Iterate stdin line-by-line (newline stripped). Final unterminated line
 * still fires the callback (matches `read -r REPLY || [[ -n $REPLY ]]`). */
typedef void (*line_cb)(const char *line, size_t len, void *user);
void  trim_each_stdin_line(line_cb cb, void *user);

/* Emit string + newline to stdout. */
void  trim_emit(const char *s, size_t len);

#endif
/*fin*/
