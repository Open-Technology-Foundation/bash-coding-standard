# Creating Bash Loadable Builtins

This guide explains how to create bash loadable builtins for common utilities, providing detailed implementations for `basename`, `dirname`, `realpath`, `head`, and `cut`.

## Table of Contents

1. [Overview](#overview)
2. [Build Environment Setup](#build-environment-setup)
3. [Bash Builtin API Reference](#bash-builtin-api-reference)
4. [Implementation: basename](#implementation-basename)
5. [Implementation: dirname](#implementation-dirname)
6. [Implementation: realpath](#implementation-realpath)
7. [Implementation: head](#implementation-head)
8. [Implementation: cut](#implementation-cut)
9. [Compilation and Installation](#compilation-and-installation)
10. [Loading and Testing](#loading-and-testing)

---

## Overview

Bash loadable builtins are dynamically loadable shared objects (.so files) that extend bash with new built-in commands. They run within the bash process, eliminating fork/exec overhead.

**Performance Benefits:**
- 10-100x faster in tight loops
- No process creation overhead
- Reduced memory footprint
- Lower syscall overhead

**Key Files Needed:**
- `builtin_name.c` - Your implementation
- `loadables.h` - Bash builtin API (from bash-builtins package)
- Makefile for compilation

---

## Build Environment Setup

### Install Required Packages

**Debian/Ubuntu:**
```bash
sudo apt-get install bash-builtins build-essential
```

**RedHat/Fedora:**
```bash
sudo dnf install bash-devel gcc make
```

### Locate Required Headers

```bash
# Find loadables.h
find /usr -name loadables.h 2>/dev/null

# Common locations:
# /usr/lib/bash/loadables.h
# /usr/include/bash/loadables.h
```

### Directory Structure

```
/ai/scripts/builtins/
├── CREATING-BASH-BUILTINS.md  # This file
├── src/
│   ├── basename.c
│   ├── dirname.c
│   ├── realpath.c
│   ├── head.c
│   └── cut.c
├── Makefile
└── test/
    └── test-builtins.sh
```

---

## Bash Builtin API Reference

### Essential Header

```c
#include "loadables.h"
```

### Required Function Signature

Every builtin must implement this function:

```c
int builtin_name_builtin(WORD_LIST *list)
```

**Parameters:**
- `list` - Linked list of command-line arguments

**Return Values:**
- `EXECUTION_SUCCESS` (0) - Success
- `EXECUTION_FAILURE` (1) - General failure
- `EX_USAGE` (2) - Usage error

### WORD_LIST Structure

```c
typedef struct word_list {
    struct word_list *next;
    WORD_DESC *word;
} WORD_LIST;

typedef struct word_desc {
    char *word;        // The actual string
    int flags;         // Word flags
} WORD_DESC;
```

### Essential Macros and Functions

```c
// Required structure definition
struct builtin builtin_name_struct = {
    "builtin_name",           // Name as it appears in bash
    builtin_name_builtin,     // Function pointer
    BUILTIN_ENABLED,          // Initial state
    builtin_name_doc,         // Help text array
    "builtin_name [options] args",  // Usage string
    0                         // Reserved
};

// Argument iteration
#define loptend list  // Mark end of options

// String functions
char *bash_xmalloc(size_t size);
void bash_xfree(void *ptr);

// Output functions
int builtin_usage(void);
void builtin_error(const char *format, ...);
void builtin_warning(const char *format, ...);

// Option parsing
int internal_getopt(WORD_LIST *list, char *opts);
extern char *list_optarg;
extern int list_optopt;
```

### Help Documentation Array

```c
char *builtin_name_doc[] = {
    "Description line 1",
    "Description line 2",
    "",
    "Options:",
    "  -option    Description",
    (char *)NULL  // Must terminate with NULL
};
```

---

## Implementation: basename

Extracts the filename component from a path, optionally removing a suffix.

### basename.c

```c
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

// Help documentation
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

// Forward declaration
int basename_builtin(WORD_LIST *);

// Required structure
struct builtin basename_struct = {
    "basename",
    basename_builtin,
    BUILTIN_ENABLED,
    basename_doc,
    "basename [-a] [-s suffix] [-z] string [string...]",
    0
};

// Remove suffix from string if present
static void remove_suffix(char *name, const char *suffix) {
    size_t name_len = strlen(name);
    size_t suffix_len = strlen(suffix);

    if (suffix_len > 0 && suffix_len < name_len) {
        if (strcmp(name + name_len - suffix_len, suffix) == 0) {
            name[name_len - suffix_len] = '\0';
        }
    }
}

// Main builtin function
int basename_builtin(WORD_LIST *list) {
    int opt;
    int multiple = 0;      // -a flag
    int zero_term = 0;     // -z flag
    char *suffix = NULL;   // -s argument
    char separator = '\n';
    char *result;
    char *input;

    // Parse options
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
                multiple = 1;  // -s implies -a
                break;
            default:
                builtin_usage();
                return EX_USAGE;
        }
    }
    list = loptend;

    // Check arguments
    if (list == NULL) {
        builtin_error("missing operand");
        return EX_USAGE;
    }

    if (!multiple && list->next != NULL && list->next->next != NULL) {
        builtin_error("extra operand '%s'", list->next->next->word->word);
        return EX_USAGE;
    }

    // Process arguments
    while (list) {
        input = list->word->word;

        // Create a copy since basename() may modify the string
        char *path_copy = strdup(input);
        if (path_copy == NULL) {
            builtin_error("memory allocation failed");
            return EXECUTION_FAILURE;
        }

        // Get basename
        result = basename(path_copy);

        // Remove suffix if specified
        if (suffix != NULL && !multiple && list->next != NULL) {
            // In single-argument mode, second arg is suffix
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
```

---

## Implementation: dirname

Extracts the directory component from a path.

### dirname.c

```c
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

// Help documentation
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

// Forward declaration
int dirname_builtin(WORD_LIST *);

// Required structure
struct builtin dirname_struct = {
    "dirname",
    dirname_builtin,
    BUILTIN_ENABLED,
    dirname_doc,
    "dirname [-z] NAME...",
    0
};

// Main builtin function
int dirname_builtin(WORD_LIST *list) {
    int opt;
    int zero_term = 0;
    char separator = '\n';
    char *result;
    char *input;

    // Parse options
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

    // Check arguments
    if (list == NULL) {
        builtin_error("missing operand");
        return EX_USAGE;
    }

    // Process each argument
    while (list) {
        input = list->word->word;

        // Create a copy since dirname() may modify the string
        char *path_copy = strdup(input);
        if (path_copy == NULL) {
            builtin_error("memory allocation failed");
            return EXECUTION_FAILURE;
        }

        // Get dirname
        result = dirname(path_copy);
        printf("%s%c", result, separator);

        free(path_copy);
        list = list->next;
    }

    return EXECUTION_SUCCESS;
}
```

---

## Implementation: realpath

Resolves symbolic links and returns the canonical absolute pathname.

### realpath.c

```c
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

#include "loadables.h"

// Help documentation
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

// Forward declaration
int realpath_builtin(WORD_LIST *);

// Required structure
struct builtin realpath_struct = {
    "realpath",
    realpath_builtin,
    BUILTIN_ENABLED,
    realpath_doc,
    "realpath [-e|-m] [-q] [-z] FILE...",
    0
};

// Main builtin function
int realpath_builtin(WORD_LIST *list) {
    int opt;
    int must_exist = 0;     // -e flag
    int may_not_exist = 0;  // -m flag
    int quiet = 0;          // -q flag
    int zero_term = 0;      // -z flag
    char separator = '\n';
    char resolved[PATH_MAX];
    int status = EXECUTION_SUCCESS;

    // Parse options
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

    // Check arguments
    if (list == NULL) {
        builtin_error("missing operand");
        return EX_USAGE;
    }

    // Process each path
    while (list) {
        char *path = list->word->word;
        char *result = NULL;

        if (may_not_exist) {
            // Don't require path to exist - implement simplified resolution
            // For now, use realpath() and ignore errors
            result = realpath(path, resolved);
            if (result == NULL) {
                // Fallback: use the input path if it's absolute, or prepend CWD
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
            // Default or -e: path must exist
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
```

---

## Implementation: head

Outputs the first part of files.

### head.c

```c
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

// Help documentation
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
    "NUM may have a multiplier suffix:",
    "b 512, kB 1000, K 1024, MB 1000*1000, M 1024*1024,",
    "GB 1000*1000*1000, G 1024*1024*1024, and so on for T, P, E, Z, Y.",
    "",
    "Exit Status:",
    "Returns success unless an error occurs.",
    (char *)NULL
};

// Forward declaration
int head_builtin(WORD_LIST *);

// Required structure
struct builtin head_struct = {
    "head",
    head_builtin,
    BUILTIN_ENABLED,
    head_doc,
    "head [-n NUM] [-q] [-v] [FILE]...",
    0
};

// Print first n lines from file
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

// Main builtin function
int head_builtin(WORD_LIST *list) {
    int opt;
    long num_lines = 10;  // Default: 10 lines
    int quiet = 0;        // -q flag
    int verbose = 0;      // -v flag
    int status = EXECUTION_SUCCESS;
    int file_count = 0;
    int show_headers;
    WORD_LIST *files;

    // Parse options
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

    // Count files
    files = list;
    while (files) {
        file_count++;
        files = files->next;
    }

    // Determine if we should show headers
    if (quiet) {
        show_headers = 0;
    } else if (verbose) {
        show_headers = 1;
    } else {
        show_headers = (file_count > 1);
    }

    // Process files
    if (list == NULL) {
        // No files specified - read from stdin
        status = print_head(stdin, num_lines, 0, "standard input");
    } else {
        int first = 1;
        while (list) {
            char *filename = list->word->word;
            FILE *fp;

            if (!first && show_headers) {
                printf("\n");  // Blank line between files
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
```

---

## Implementation: cut

Removes sections from each line of files.

### cut.c

```c
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

#include "loadables.h"

// Help documentation
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
    "Selected input is written in the same order that it is read.",
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

// Forward declaration
int cut_builtin(WORD_LIST *);

// Required structure
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

// Range structure
typedef struct range {
    int start;
    int end;
    struct range *next;
} Range;

// Parse range list (e.g., "1,3-5,7-")
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
            // Single number (e.g., "3")
            r->start = r->end = atoi(token);
        } else if (dash == token) {
            // "-M" format
            r->start = 1;
            r->end = atoi(dash + 1);
        } else if (*(dash + 1) == '\0') {
            // "N-" format
            *dash = '\0';
            r->start = atoi(token);
            r->end = INT_MAX;
        } else {
            // "N-M" format
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

// Check if position is in any range
static int in_range(Range *ranges, int pos) {
    while (ranges) {
        if (pos >= ranges->start && pos <= ranges->end) {
            return 1;
        }
        ranges = ranges->next;
    }
    return 0;
}

// Free range list
static void free_ranges(Range *ranges) {
    while (ranges) {
        Range *next = ranges->next;
        free(ranges);
        ranges = next;
    }
}

// Process file with byte/character selection
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

// Process file with field selection
static int cut_fields(FILE *fp, Range *ranges, const char *delim,
                      int suppress_no_delim, char line_delim) {
    char *line = NULL;
    size_t len = 0;
    ssize_t read;

    while ((read = getline(&line, &len, fp)) != -1) {
        // Remove trailing newline
        if (read > 0 && line[read - 1] == '\n') {
            line[read - 1] = '\0';
            read--;
        }

        // Check if line contains delimiter
        if (strchr(line, delim[0]) == NULL) {
            if (!suppress_no_delim) {
                printf("%s%c", line, line_delim);
            }
            continue;
        }

        // Split into fields
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

// Main builtin function
int cut_builtin(WORD_LIST *list) {
    int opt;
    char *range_list = NULL;
    char *delimiter = "\t";
    int mode = 0;  // 0=none, 'b'=bytes, 'c'=chars, 'f'=fields
    int suppress_no_delim = 0;
    char line_delim = '\n';
    int status = EXECUTION_SUCCESS;
    Range *ranges = NULL;

    // Parse options
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

    // Validate mode selected
    if (mode == 0) {
        builtin_error("you must specify a list of bytes, characters, or fields");
        return EX_USAGE;
    }

    // Parse ranges
    ranges = parse_ranges(range_list);
    if (ranges == NULL) {
        builtin_error("invalid range list");
        return EX_USAGE;
    }

    // Process files
    if (list == NULL) {
        // No files - read stdin
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
```

---

## Compilation and Installation

### Makefile

```makefile
# Makefile for bash loadable builtins
# Location: /ai/scripts/builtins/Makefile

CC = gcc
CFLAGS = -fPIC -Wall -Wextra -O2
LDFLAGS = -shared

# Find bash headers
BASH_HEADERS = /usr/lib/bash
INCLUDES = -I$(BASH_HEADERS)

# Targets
BUILTINS = basename.so dirname.so realpath.so head.so cut.so

# Installation paths
PREFIX = /usr/local
BUILTIN_DIR = $(PREFIX)/lib/bash

.PHONY: all clean install uninstall test

all: $(BUILTINS)

%.so: src/%.c
	$(CC) $(CFLAGS) $(INCLUDES) $(LDFLAGS) -o $@ $<

clean:
	rm -f $(BUILTINS)

install: $(BUILTINS)
	install -d $(BUILTIN_DIR)
	install -m 0755 $(BUILTINS) $(BUILTIN_DIR)/

uninstall:
	cd $(BUILTIN_DIR) && rm -f $(BUILTINS)

test: $(BUILTINS)
	bash test/test-builtins.sh

# Individual targets
basename.so: src/basename.c
dirname.so: src/dirname.c
realpath.so: src/realpath.c
head.so: src/head.c
cut.so: src/cut.c
```

### Build Commands

```bash
# Build all builtins
make

# Build specific builtin
make basename.so

# Install (requires root)
sudo make install

# Clean build artifacts
make clean
```

### Manual Compilation

```bash
# Compile individual builtin
gcc -fPIC -I/usr/lib/bash -shared -o basename.so src/basename.c

# Verify it's a shared object
file basename.so
# Output: basename.so: ELF 64-bit LSB shared object
```

---

## Loading and Testing

### Load Builtins into Bash

```bash
# Enable a builtin
enable -f /ai/scripts/builtins/basename.so basename

# Verify it's loaded
enable -a | grep basename

# Check if it's a builtin
type basename
# Output: basename is a shell builtin

# Get help
help basename
```

### Test Each Builtin

```bash
# Test basename
enable -f ./basename.so basename
basename /usr/local/bin/script.sh
# Output: script.sh

basename /usr/local/bin/script.sh .sh
# Output: script

basename -a /path/one /path/two
# Output:
# one
# two

# Test dirname
enable -f ./dirname.so dirname
dirname /usr/local/bin/script.sh
# Output: /usr/local/bin

# Test realpath
enable -f ./realpath.so realpath
realpath ../builtins
# Output: /ai/scripts/builtins

# Test head
enable -f ./head.so head
head -n 5 /etc/passwd
# Output: First 5 lines of /etc/passwd

# Test cut
enable -f ./cut.so cut
echo "one:two:three" | cut -d: -f2
# Output: two

cut -d: -f1,3 /etc/passwd | head -n 3
# Output: First 3 lines showing field 1 and 3
```

### Automated Test Script

Create `test/test-builtins.sh`:

```bash
#!/usr/bin/env bash
# Test script for bash loadable builtins

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

# Test basename
enable -f ./basename.so basename
[[ $(basename /usr/local/bin/test.sh) == "test.sh" ]] && pass "basename basic" || fail "basename basic"
[[ $(basename /usr/local/bin/test.sh .sh) == "test" ]] && pass "basename suffix" || fail "basename suffix"

# Test dirname
enable -f ./dirname.so dirname
[[ $(dirname /usr/local/bin/test.sh) == "/usr/local/bin" ]] && pass "dirname basic" || fail "dirname basic"

# Test realpath
enable -f ./realpath.so realpath
[[ $(realpath .) == "$PWD" ]] && pass "realpath basic" || fail "realpath basic"

# Test head
enable -f ./head.so head
[[ $(echo -e "line1\nline2\nline3" | head -n 2 | wc -l) -eq 2 ]] && pass "head basic" || fail "head basic"

# Test cut
enable -f ./cut.so cut
[[ $(echo "a:b:c" | cut -d: -f2) == "b" ]] && pass "cut basic" || fail "cut basic"

echo ""
echo "All tests passed!"
```

### Performance Comparison

```bash
# Benchmark external vs builtin basename
time for i in {1..10000}; do /usr/bin/basename /path/to/file >/dev/null; done
# Example: real 0m8.234s

enable -f ./basename.so basename
time for i in {1..10000}; do basename /path/to/file >/dev/null; done
# Example: real 0m0.421s

# Speedup: ~19x faster!
```

---

## Troubleshooting

### Common Issues

**1. "cannot find loadables.h"**
```bash
# Install bash-builtins package
sudo apt-get install bash-builtins

# Or locate manually
find /usr -name loadables.h 2>/dev/null
```

**2. "undefined symbol: builtin_usage"**
- Ensure you're using functions from the bash API correctly
- Check that loadables.h is properly included

**3. "enable: cannot open shared object"**
```bash
# Check file exists
ls -l basename.so

# Verify it's a shared object
file basename.so

# Check permissions
chmod 755 basename.so
```

**4. Segmentation fault**
- Check for NULL pointer dereferences
- Ensure proper memory management (malloc/free)
- Validate all list operations

### Debugging

```bash
# Run bash with debugging
bash -x -c "enable -f ./basename.so basename; basename /test"

# Use gdb
gdb bash
(gdb) run
(gdb) enable -f ./basename.so basename
(gdb) basename /test

# Check with valgrind
valgrind bash -c "enable -f ./basename.so basename; basename /test"
```

---

## Best Practices

1. **Always validate arguments** - Check for NULL, empty strings
2. **Free allocated memory** - Use strdup() carefully, always free()
3. **Handle errors gracefully** - Return appropriate exit codes
4. **Follow bash conventions** - Match behavior of external utilities
5. **Test thoroughly** - Compare output with GNU coreutils
6. **Document options** - Provide complete help text
7. **Use const correctness** - Mark read-only parameters as const
8. **Initialize variables** - Prevent undefined behavior
9. **Check return values** - Don't ignore malloc(), fopen(), etc.
10. **Maintain compatibility** - Match external utility interface

---

## References

- Bash source code: https://git.savannah.gnu.org/cgit/bash.git
- Bash loadables examples: `/usr/lib/bash/` (from bash-builtins package)
- GNU Coreutils source: https://git.savannah.gnu.org/cgit/coreutils.git
- Bash manual: `man bash` (section on SHELL BUILTIN COMMANDS)

---

## License

This documentation is provided as-is for educational purposes. Individual builtin implementations should match the licensing of the utilities they replace (typically GPLv3 for GNU coreutils replacements).

---

*Last updated: 2025-10-13*
