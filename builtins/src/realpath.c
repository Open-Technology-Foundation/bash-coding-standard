/*
 * realpath.c - bash loadable builtin for realpath functionality
 *
 * Usage: realpath [OPTION]... FILE...
 */

#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>

#include "loadables.h"

char *realpath_doc[] = {
    "Print the resolved absolute file name.",
    "All components of the file path are resolved to their canonical form.",
    "",
    "Options:",
    "  -e    All path components must exist",
    "  -m    No path components need exist",
    "  -q    Suppress error messages",
    "  -z    Separate output with NUL rather than newline",
    "",
    "Exit Status:",
    "Returns success if all paths were resolved successfully.",
    (char *)NULL
};

int realpath_builtin(WORD_LIST *);

struct builtin realpath_struct = {
    "realpath",
    realpath_builtin,
    BUILTIN_ENABLED,
    realpath_doc,
    "realpath [-e|-m] [-q] [-z] FILE...",
    0
};

int realpath_builtin(WORD_LIST *list) {
    int opt;
    int must_exist = 0;
    int may_not_exist = 0;
    int quiet = 0;
    int zero_term = 0;
    char separator = '\n';
    char resolved[PATH_MAX];
    int status = EXECUTION_SUCCESS;

    reset_internal_getopt();
    while ((opt = internal_getopt(list, "emqz")) != -1) {
        switch (opt) {
            case 'e':
                must_exist = 1;
                may_not_exist = 0;
                break;
            case 'm':
                may_not_exist = 1;
                must_exist = 0;
                break;
            case 'q':
                quiet = 1;
                break;
            case 'z':
                zero_term = 1;
                separator = '\0';
                break;
            default:
                builtin_usage();
                return EX_USAGE;
        }
    }
    list = loptend;

    if (list == NULL) {
        builtin_error("missing operand");
        return EX_USAGE;
    }

    while (list) {
        char *path = list->word->word;
        char *result = NULL;

        if (may_not_exist) {
            result = realpath(path, resolved);
            if (result == NULL) {
                if (path[0] == '/') {
                    strncpy(resolved, path, PATH_MAX - 1);
                    resolved[PATH_MAX - 1] = '\0';
                    result = resolved;
                } else {
                    if (getcwd(resolved, PATH_MAX) != NULL) {
                        size_t len = strlen(resolved);
                        if (len + strlen(path) + 2 < PATH_MAX) {
                            resolved[len] = '/';
                            strcpy(resolved + len + 1, path);
                            result = resolved;
                        }
                    }
                }
            }
        } else {
            result = realpath(path, resolved);
        }

        if (result == NULL) {
            if (!quiet) {
                builtin_error("%s: %s", path, strerror(errno));
            }
            status = EXECUTION_FAILURE;
        } else {
            printf("%s%c", result, separator);
        }

        list = list->next;
    }

    return status;
}
