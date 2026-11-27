/* trimall.c - normalize whitespace (IFS-style: space/tab/newline collapse) */
#include "trim_common.h"

#include <ctype.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char HELP_BODY[] =
"Usage: trimall [-e] string    # Normalize whitespace in string\n"
"       trimall < file         # Process stdin stream\n"
"\n"
"Strips leading and trailing whitespace and collapses consecutive blanks\n"
"(spaces, tabs, newlines) to single spaces.\n"
"\n"
"Options:\n"
"  -e             Process escape sequences (\\t \\n \\\\ \\xHH \\c-halts)\n"
"  --             End of options\n"
"  -V, --version  Display version\n"
"  -h, --help     Display this help message\n"
"\n"
"Examples:\n"
"  echo \"  a  b  c  \" | trimall     # Output: \"a b c\"\n"
"\n"
"See also: trim, ltrim, rtrim, squeeze\n";

static void normalize(const char *in, size_t len, bool force_newline) {
    bool any = false;
    size_t i = 0;
    while (i < len) {
        while (i < len && isspace((unsigned char)in[i])) i++;
        if (i >= len) break;
        size_t start = i;
        while (i < len && !isspace((unsigned char)in[i])) i++;
        if (any) fputc(' ', stdout);
        fwrite(in + start, 1, i - start, stdout);
        any = true;
    }
    if (any || force_newline) fputc('\n', stdout);
}

static char *slurp_stdin(size_t *out_len) {
    size_t cap = 8192, len = 0;
    char *buf = malloc(cap);
    if (!buf) { perror("malloc"); exit(1); }
    size_t n;
    while ((n = fread(buf + len, 1, cap - len, stdin)) > 0) {
        len += n;
        if (len == cap) {
            cap *= 2;
            char *nb = realloc(buf, cap);
            if (!nb) { perror("realloc"); exit(1); }
            buf = nb;
        }
    }
    *out_len = len;
    return buf;
}

int main(int argc, char **argv) {
    trim_opts_t opts;
    trim_parse(argc, argv, &opts,
               "Normalize whitespace in string", HELP_BODY);

    if (opts.argc > 0) {
        size_t len;
        char *v = trim_join_args(&opts, &len);
        normalize(v ? v : "", len, true);
        free(v);
    } else if (!isatty(STDIN_FILENO)) {
        size_t len;
        char *buf = slurp_stdin(&len);
        normalize(buf, len, len > 0);
        free(buf);
    } else {
        trim_die(&opts, EXIT_INVAL,
                 "Usage: %s [-e] string  |  %s < file",
                 opts.prog, opts.prog);
    }
    return 0;
}
/*fin*/
