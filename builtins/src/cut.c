/*
 * cut.c - bash loadable builtin for cut functionality
 *
 * Usage: cut OPTION... [FILE]...
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <ctype.h>
#include <limits.h>

#include "loadables.h"

char *cut_doc[] = {
    "Print selected parts of lines from each FILE to standard output.",
    "",
    "With no FILE, or when FILE is -, read standard input.",
    "",
    "Options:",
    "  -b LIST   Select only these bytes",
    "  -c LIST   Select only these characters",
    "  -d DELIM  Use DELIM instead of TAB for field delimiter",
    "  -f LIST   Select only these fields",
    "  -s        Do not print lines not containing delimiters",
    "  -z        Line delimiter is NUL, not newline",
    "",
    "LIST is made up of one range, or many ranges separated by commas.",
    "Each range is one of:",
    "  N     N'th byte, character or field, counted from 1",
    "  N-    From N'th byte, character or field, to end of line",
    "  N-M   From N'th to M'th (included) byte, character or field",
    "  -M    From first to M'th (included) byte, character or field",
    "",
    "Exit Status:",
    "Returns success unless an error occurs.",
    (char *)NULL
};

int cut_builtin(WORD_LIST *);

struct builtin cut_struct = {
    "cut",
    cut_builtin,
    BUILTIN_ENABLED,
    cut_doc,
    "cut -b LIST [-z] [FILE]...\n"
    "cut -c LIST [-z] [FILE]...\n"
    "cut -f LIST [-d DELIM] [-s] [-z] [FILE]...",
    0
};

typedef struct range {
    int start;
    int end;
    struct range *next;
} Range;

static Range *parse_ranges(const char *list_str) {
    Range *head = NULL;
    Range *tail = NULL;
    char *str_copy = strdup(list_str);
    char *token = strtok(str_copy, ",");

    while (token) {
        Range *r = malloc(sizeof(Range));
        if (r == NULL) {
            free(str_copy);
            return NULL;
        }

        r->next = NULL;

        char *dash = strchr(token, '-');
        if (dash == NULL) {
            r->start = r->end = atoi(token);
        } else if (dash == token) {
            r->start = 1;
            r->end = atoi(dash + 1);
        } else if (*(dash + 1) == '\0') {
            *dash = '\0';
            r->start = atoi(token);
            r->end = INT_MAX;
        } else {
            *dash = '\0';
            r->start = atoi(token);
            r->end = atoi(dash + 1);
        }

        if (head == NULL) {
            head = tail = r;
        } else {
            tail->next = r;
            tail = r;
        }

        token = strtok(NULL, ",");
    }

    free(str_copy);
    return head;
}

static int in_range(Range *ranges, int pos) {
    while (ranges) {
        if (pos >= ranges->start && pos <= ranges->end) {
            return 1;
        }
        ranges = ranges->next;
    }
    return 0;
}

static void free_ranges(Range *ranges) {
    while (ranges) {
        Range *next = ranges->next;
        free(ranges);
        ranges = next;
    }
}

static int cut_bytes(FILE *fp, Range *ranges, char line_delim) {
    char *line = NULL;
    size_t len = 0;
    ssize_t read;

    while ((read = getline(&line, &len, fp)) != -1) {
        int pos = 1;
        for (ssize_t i = 0; i < read; i++, pos++) {
            if (line[i] == '\n' || line[i] == '\0') {
                break;
            }
            if (in_range(ranges, pos)) {
                putchar(line[i]);
            }
        }
        putchar(line_delim);
    }

    if (line) {
        free(line);
    }

    return EXECUTION_SUCCESS;
}

static int cut_fields(FILE *fp, Range *ranges, const char *delim,
                      int suppress_no_delim, char line_delim) {
    char *line = NULL;
    size_t len = 0;
    ssize_t read;

    while ((read = getline(&line, &len, fp)) != -1) {
        if (read > 0 && line[read - 1] == '\n') {
            line[read - 1] = '\0';
            read--;
        }

        if (strchr(line, delim[0]) == NULL) {
            if (!suppress_no_delim) {
                printf("%s%c", line, line_delim);
            }
            continue;
        }

        char *line_copy = strdup(line);
        char *saveptr;
        char *token = strtok_r(line_copy, delim, &saveptr);
        int field = 1;
        int first_output = 1;

        while (token) {
            if (in_range(ranges, field)) {
                if (!first_output) {
                    printf("%s", delim);
                }
                printf("%s", token);
                first_output = 0;
            }
            field++;
            token = strtok_r(NULL, delim, &saveptr);
        }

        if (!first_output) {
            putchar(line_delim);
        }

        free(line_copy);
    }

    if (line) {
        free(line);
    }

    return EXECUTION_SUCCESS;
}

int cut_builtin(WORD_LIST *list) {
    int opt;
    char *range_list = NULL;
    char *delimiter = "\t";
    int mode = 0;
    int suppress_no_delim = 0;
    char line_delim = '\n';
    int status = EXECUTION_SUCCESS;
    Range *ranges = NULL;

    reset_internal_getopt();
    while ((opt = internal_getopt(list, "b:c:d:f:sz")) != -1) {
        switch (opt) {
            case 'b':
            case 'c':
                if (mode != 0) {
                    builtin_error("only one type of list may be specified");
                    return EX_USAGE;
                }
                mode = opt;
                range_list = list_optarg;
                break;
            case 'd':
                delimiter = list_optarg;
                if (strlen(delimiter) != 1) {
                    builtin_error("the delimiter must be a single character");
                    return EX_USAGE;
                }
                break;
            case 'f':
                if (mode != 0) {
                    builtin_error("only one type of list may be specified");
                    return EX_USAGE;
                }
                mode = 'f';
                range_list = list_optarg;
                break;
            case 's':
                suppress_no_delim = 1;
                break;
            case 'z':
                line_delim = '\0';
                break;
            default:
                builtin_usage();
                return EX_USAGE;
        }
    }
    list = loptend;

    if (mode == 0) {
        builtin_error("you must specify a list of bytes, characters, or fields");
        return EX_USAGE;
    }

    ranges = parse_ranges(range_list);
    if (ranges == NULL) {
        builtin_error("invalid range list");
        return EX_USAGE;
    }

    if (list == NULL) {
        if (mode == 'f') {
            status = cut_fields(stdin, ranges, delimiter, suppress_no_delim, line_delim);
        } else {
            status = cut_bytes(stdin, ranges, line_delim);
        }
    } else {
        while (list) {
            char *filename = list->word->word;
            FILE *fp;

            if (strcmp(filename, "-") == 0) {
                fp = stdin;
            } else {
                fp = fopen(filename, "r");
                if (fp == NULL) {
                    builtin_error("%s: %s", filename, strerror(errno));
                    status = EXECUTION_FAILURE;
                    list = list->next;
                    continue;
                }
            }

            if (mode == 'f') {
                cut_fields(fp, ranges, delimiter, suppress_no_delim, line_delim);
            } else {
                cut_bytes(fp, ranges, line_delim);
            }

            if (fp != stdin) {
                fclose(fp);
            }

            list = list->next;
        }
    }

    free_ranges(ranges);
    return status;
}
