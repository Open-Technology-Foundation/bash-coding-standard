/* trim_common.c - shared helpers for trim-c family */
#define _POSIX_C_SOURCE 200809L
#include "trim_common.h"

#include <ctype.h>
#include <errno.h>
#include <getopt.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char *prog_basename(const char *argv0) {
    const char *p = strrchr(argv0, '/');
    return p ? p + 1 : argv0;
}

void trim_die(const trim_opts_t *opts, int code, const char *fmt, ...) {
    fprintf(stderr, "%s: \xe2\x9c\x97 ", opts ? opts->prog : "trim");
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fputc('\n', stderr);
    exit(code);
}

void trim_emit(const char *s, size_t len) {
    if (len) fwrite(s, 1, len, stdout);
    fputc('\n', stdout);
}

static void print_help(const trim_opts_t *opts,
                       const char *short_desc, const char *help_body) {
    printf("%s %s - %s\n\n", opts->prog, TRIM_VERSION, short_desc);
    if (help_body && *help_body) printf("%s", help_body);
}

int trim_parse(int argc, char **argv, trim_opts_t *opts,
               const char *short_desc, const char *help_body) {
    opts->escape = false;
    opts->prog   = prog_basename(argv[0]);
    opts->args   = NULL;
    opts->argc   = 0;

    static const struct option longopts[] = {
        { "help",    no_argument, 0, 'h' },
        { "version", no_argument, 0, 'V' },
        { 0, 0, 0, 0 }
    };

    opterr = 0;  /* suppress getopt's own error printing */
    int c;
    while ((c = getopt_long(argc, argv, "+ehV", longopts, NULL)) != -1) {
        switch (c) {
            case 'e': opts->escape = true; break;
            case 'h': print_help(opts, short_desc, help_body); exit(0);
            case 'V': printf("%s %s\n", opts->prog, TRIM_VERSION); exit(0);
            case '?':
            default:
                /* optopt holds short option char; for long opts it's 0 and
                 * optind points past the offending arg. */
                if (optopt) {
                    trim_die(opts, EXIT_INVAL, "Unknown option '-%c'", optopt);
                } else {
                    trim_die(opts, EXIT_INVAL, "Unknown option '%s'",
                             argv[optind - 1]);
                }
        }
    }

    if (optind < argc) {
        opts->args = &argv[optind];
        opts->argc = argc - optind;
    }
    return 0;
}

char *trim_join_args(const trim_opts_t *opts, size_t *out_len) {
    if (opts->argc == 0) { if (out_len) *out_len = 0; return NULL; }

    size_t total = 0;
    for (int i = 0; i < opts->argc; i++) total += strlen(opts->args[i]);
    total += (size_t)opts->argc - 1;  /* separator spaces */

    char *buf = malloc(total + 1);
    if (!buf) { perror("malloc"); exit(1); }

    size_t off = 0;
    for (int i = 0; i < opts->argc; i++) {
        if (i) buf[off++] = ' ';
        size_t l = strlen(opts->args[i]);
        memcpy(buf + off, opts->args[i], l);
        off += l;
    }
    buf[off] = '\0';

    if (opts->escape) {
        size_t elen;
        char *esc = trim_escape(buf, off, &elen);
        free(buf);
        if (out_len) *out_len = elen;
        return esc;
    }
    if (out_len) *out_len = off;
    return buf;
}

/* printf %b: \\ \a \b \c(halts) \e \E \f \n \r \t \v \" \' \0NNN \NNN \xHH.
 * Unknown escape: emit backslash + char verbatim (matches bash printf %b). */
char *trim_escape(const char *in, size_t in_len, size_t *out_len) {
    char *out = malloc(in_len + 1);
    if (!out) { perror("malloc"); exit(1); }
    size_t o = 0;
    size_t i = 0;
    while (i < in_len) {
        char c = in[i];
        if (c != '\\' || i + 1 >= in_len) {
            out[o++] = c;
            i++;
            continue;
        }
        char n = in[i + 1];
        switch (n) {
            case '\\': out[o++] = '\\'; i += 2; break;
            case 'a':  out[o++] = '\a'; i += 2; break;
            case 'b':  out[o++] = '\b'; i += 2; break;
            case 'e':
            case 'E':  out[o++] = 0x1b; i += 2; break;
            case 'f':  out[o++] = '\f'; i += 2; break;
            case 'n':  out[o++] = '\n'; i += 2; break;
            case 'r':  out[o++] = '\r'; i += 2; break;
            case 't':  out[o++] = '\t'; i += 2; break;
            case 'v':  out[o++] = '\v'; i += 2; break;
            case '"':  out[o++] = '"';  i += 2; break;
            case '\'': out[o++] = '\''; i += 2; break;
            case 'c':  /* halt */
                if (out_len) *out_len = o;
                out[o] = '\0';
                return out;
            case 'x': {
                int v = 0, d = 0;
                size_t j = i + 2;
                while (d < 2 && j < in_len && isxdigit((unsigned char)in[j])) {
                    int x = in[j];
                    int dv = (x >= '0' && x <= '9') ? x - '0'
                           : (x >= 'a' && x <= 'f') ? x - 'a' + 10
                           : x - 'A' + 10;
                    v = v * 16 + dv;
                    j++; d++;
                }
                if (d == 0) { out[o++] = '\\'; out[o++] = 'x'; i += 2; }
                else { out[o++] = (char)v; i = j; }
                break;
            }
            case '0': case '1': case '2': case '3':
            case '4': case '5': case '6': case '7': {
                int v = 0, d = 0;
                size_t j = i + 1;
                if (n == '0') j++;  /* allow \0NNN form */
                while (d < 3 && j < in_len
                       && in[j] >= '0' && in[j] <= '7') {
                    v = v * 8 + (in[j] - '0');
                    j++; d++;
                }
                if (d == 0) { out[o++] = '\\'; out[o++] = n; i += 2; }
                else { out[o++] = (char)v; i = j; }
                break;
            }
            default:
                /* unknown - pass backslash + char through */
                out[o++] = '\\';
                out[o++] = n;
                i += 2;
        }
    }
    out[o] = '\0';
    if (out_len) *out_len = o;
    return out;
}

void trim_each_stdin_line(line_cb cb, void *user) {
    char *line = NULL;
    size_t cap = 0;
    ssize_t n;
    while ((n = getline(&line, &cap, stdin)) != -1) {
        size_t len = (size_t)n;
        if (len > 0 && line[len - 1] == '\n') len--;
        cb(line, len, user);
    }
    free(line);
}

/*fin*/
