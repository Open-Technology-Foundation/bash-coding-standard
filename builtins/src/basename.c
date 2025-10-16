/*
 * basename.c - bash loadable builtin for basename functionality
 *
 * Usage: basename string [suffix]
 *        basename -a [-s suffix] string [string...]
 *        basename -z [-s suffix] string [string...]
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <libgen.h>

#include "loadables.h"

char *basename_doc[] = {
    "Strip directory and suffix from filenames.",
    "",
    "Print NAME with any leading directory components removed.",
    "If SUFFIX is specified and is identical to the end of NAME,",
    "remove SUFFIX as well.",
    "",
    "Options:",
    "  -a        Support multiple arguments",
    "  -s SUFFIX Remove a trailing SUFFIX (implies -a)",
    "  -z        Separate output with NUL rather than newline",
    "",
    "Exit Status:",
    "Returns success unless an invalid option is given.",
    (char *)NULL
};

int basename_builtin(WORD_LIST *);

struct builtin basename_struct = {
    "basename",
    basename_builtin,
    BUILTIN_ENABLED,
    basename_doc,
    "basename [-a] [-s suffix] [-z] string [string...]",
    0
};

static void remove_suffix(char *name, const char *suffix) {
    size_t name_len = strlen(name);
    size_t suffix_len = strlen(suffix);

    if (suffix_len > 0 && suffix_len < name_len) {
        if (strcmp(name + name_len - suffix_len, suffix) == 0) {
            name[name_len - suffix_len] = '\0';
        }
    }
}

int basename_builtin(WORD_LIST *list) {
    int opt;
    int multiple = 0;
    int zero_term = 0;
    char *suffix = NULL;
    char separator = '\n';
    char *result;
    char *input;

    reset_internal_getopt();
    while ((opt = internal_getopt(list, "azs:")) != -1) {
        switch (opt) {
            case 'a':
                multiple = 1;
                break;
            case 'z':
                zero_term = 1;
                separator = '\0';
                break;
            case 's':
                suffix = list_optarg;
                multiple = 1;
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

    if (!multiple && list->next != NULL && list->next->next != NULL) {
        builtin_error("extra operand '%s'", list->next->next->word->word);
        return EX_USAGE;
    }

    while (list) {
        input = list->word->word;

        char *path_copy = strdup(input);
        if (path_copy == NULL) {
            builtin_error("memory allocation failed");
            return EXECUTION_FAILURE;
        }

        result = basename(path_copy);

        if (suffix != NULL && !multiple && list->next != NULL) {
            suffix = list->next->word->word;
            remove_suffix(result, suffix);
            printf("%s%c", result, separator);
            free(path_copy);
            break;
        } else if (suffix != NULL) {
            remove_suffix(result, suffix);
        }

        printf("%s%c", result, separator);
        free(path_copy);

        if (!multiple) {
            break;
        }
        list = list->next;
    }

    return EXECUTION_SUCCESS;
}
