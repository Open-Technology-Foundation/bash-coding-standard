/*
 * dirname.c - bash loadable builtin for dirname functionality
 *
 * Usage: dirname [OPTION] NAME...
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <libgen.h>

#include "loadables.h"

char *dirname_doc[] = {
    "Output each NAME with its last non-slash component removed.",
    "If NAME contains no slashes, output '.' (meaning the current directory).",
    "",
    "Options:",
    "  -z    Separate output with NUL rather than newline",
    "",
    "Exit Status:",
    "Returns success unless an invalid option is given.",
    (char *)NULL
};

int dirname_builtin(WORD_LIST *);

struct builtin dirname_struct = {
    "dirname",
    dirname_builtin,
    BUILTIN_ENABLED,
    dirname_doc,
    "dirname [-z] NAME...",
    0
};

int dirname_builtin(WORD_LIST *list) {
    int opt;
    int zero_term = 0;
    char separator = '\n';
    char *result;
    char *input;

    reset_internal_getopt();
    while ((opt = internal_getopt(list, "z")) != -1) {
        switch (opt) {
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
        input = list->word->word;

        char *path_copy = strdup(input);
        if (path_copy == NULL) {
            builtin_error("memory allocation failed");
            return EXECUTION_FAILURE;
        }

        result = dirname(path_copy);
        printf("%s%c", result, separator);

        free(path_copy);
        list = list->next;
    }

    return EXECUTION_SUCCESS;
}
