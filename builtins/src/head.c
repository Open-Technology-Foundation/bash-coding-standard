/*
 * head.c - bash loadable builtin for head functionality
 *
 * Usage: head [OPTION]... [FILE]...
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include "loadables.h"

char *head_doc[] = {
    "Print the first 10 lines of each FILE to standard output.",
    "With more than one FILE, precede each with a header giving the file name.",
    "",
    "With no FILE, or when FILE is -, read standard input.",
    "",
    "Options:",
    "  -n NUM    Print first NUM lines instead of first 10",
    "  -q        Never print headers giving file names",
    "  -v        Always print headers giving file names",
    "",
    "Exit Status:",
    "Returns success unless an error occurs.",
    (char *)NULL
};

int head_builtin(WORD_LIST *);

struct builtin head_struct = {
    "head",
    head_builtin,
    BUILTIN_ENABLED,
    head_doc,
    "head [-n NUM] [-q] [-v] [FILE]...",
    0
};

static int print_head(FILE *fp, long lines, int show_header, const char *filename) {
    char *line = NULL;
    size_t len = 0;
    ssize_t read;
    long count = 0;

    if (show_header) {
        printf("==> %s <==\n", filename);
    }

    while ((read = getline(&line, &len, fp)) != -1 && count < lines) {
        fputs(line, stdout);
        count++;
    }

    if (line) {
        free(line);
    }

    return EXECUTION_SUCCESS;
}

int head_builtin(WORD_LIST *list) {
    int opt;
    long num_lines = 10;
    int quiet = 0;
    int verbose = 0;
    int status = EXECUTION_SUCCESS;
    int file_count = 0;
    int show_headers;
    WORD_LIST *files;

    reset_internal_getopt();
    while ((opt = internal_getopt(list, "n:qv")) != -1) {
        switch (opt) {
            case 'n':
                num_lines = atol(list_optarg);
                if (num_lines <= 0) {
                    builtin_error("invalid number of lines: '%s'", list_optarg);
                    return EX_USAGE;
                }
                break;
            case 'q':
                quiet = 1;
                verbose = 0;
                break;
            case 'v':
                verbose = 1;
                quiet = 0;
                break;
            default:
                builtin_usage();
                return EX_USAGE;
        }
    }
    list = loptend;

    files = list;
    while (files) {
        file_count++;
        files = files->next;
    }

    if (quiet) {
        show_headers = 0;
    } else if (verbose) {
        show_headers = 1;
    } else {
        show_headers = (file_count > 1);
    }

    if (list == NULL) {
        status = print_head(stdin, num_lines, 0, "standard input");
    } else {
        int first = 1;
        while (list) {
            char *filename = list->word->word;
            FILE *fp;

            if (!first && show_headers) {
                printf("\n");
            }
            first = 0;

            if (strcmp(filename, "-") == 0) {
                fp = stdin;
                filename = "standard input";
            } else {
                fp = fopen(filename, "r");
                if (fp == NULL) {
                    builtin_error("%s: %s", filename, strerror(errno));
                    status = EXECUTION_FAILURE;
                    list = list->next;
                    continue;
                }
            }

            print_head(fp, num_lines, show_headers, filename);

            if (fp != stdin) {
                fclose(fp);
            }

            list = list->next;
        }
    }

    return status;
}
