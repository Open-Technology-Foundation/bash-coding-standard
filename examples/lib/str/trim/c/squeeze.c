/* squeeze.c - tab->space, collapse double-spaces; preserve edge spaces */
#include "trim_common.h"
#include <stdbool.h>
#include <stdlib.h>
#include <unistd.h>

static const char HELP_BODY[] =
"Usage: squeeze [-e] string   # Squeeze consecutive blanks to single space\n"
"       squeeze < file        # Process stdin stream\n"
"\n"
"Squeezes consecutive blank characters (spaces and tabs) into single spaces.\n"
"Preserves leading and trailing whitespace.\n"
"\n"
"Options:\n"
"  -e             Process escape sequences (\\t \\n \\\\ \\xHH \\c-halts)\n"
"  --             End of options\n"
"  -V, --version  Display version\n"
"  -h, --help     Display this help message\n"
"\n"
"Examples:\n"
"  echo \"a  b   c\" | squeeze     # Output: \"a b c\"\n"
"\n"
"See also: trim, ltrim, rtrim, trimall\n";

static void on_line(const char *line, size_t len, void *user) {
    (void)user;
    char *out = malloc(len + 1);
    if (!out) { perror("malloc"); exit(1); }
    size_t o = 0;
    bool prev_space = false;
    for (size_t i = 0; i < len; i++) {
        char c = (line[i] == '\t') ? ' ' : line[i];
        if (c == ' ' && prev_space) continue;
        out[o++] = c;
        prev_space = (c == ' ');
    }
    trim_emit(out, o);
    free(out);
}

int main(int argc, char **argv) {
    trim_opts_t opts;
    trim_parse(argc, argv, &opts,
               "Squeeze consecutive blanks to single space", HELP_BODY);

    if (opts.argc > 0) {
        size_t len;
        char *v = trim_join_args(&opts, &len);
        on_line(v, len, NULL);
        free(v);
    } else if (!isatty(STDIN_FILENO)) {
        trim_each_stdin_line(on_line, NULL);
    } else {
        trim_die(&opts, EXIT_INVAL,
                 "Usage: %s [-e] string  |  %s < file",
                 opts.prog, opts.prog);
    }
    return 0;
}
/*fin*/
