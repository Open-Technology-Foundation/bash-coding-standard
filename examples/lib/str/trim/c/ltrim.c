/* ltrim.c - strip leading [:blank:] (space + tab) per line */
#include "trim_common.h"
#include <stdlib.h>
#include <unistd.h>

static const char HELP_BODY[] =
"Usage: ltrim [-e] string    # Remove leading whitespace\n"
"       ltrim < file         # Process stdin stream\n"
"\n"
"Options:\n"
"  -e            Process escape sequences (\\t \\n \\\\ \\xHH \\c-halts)\n"
"  --            End of options\n"
"  -V, --version Display version\n"
"  -h, --help    Display this help message\n"
"\n"
"Examples:\n"
"  echo \"  text  \" | ltrim     # Output: \"text  \"\n"
"\n"
"See also: trim, rtrim, trimall, squeeze\n";

static void on_line(const char *line, size_t len, void *user) {
    (void)user;
    size_t i = 0;
    while (i < len && (line[i] == ' ' || line[i] == '\t')) i++;
    trim_emit(line + i, len - i);
}

int main(int argc, char **argv) {
    trim_opts_t opts;
    trim_parse(argc, argv, &opts, "Remove leading blanks", HELP_BODY);

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
