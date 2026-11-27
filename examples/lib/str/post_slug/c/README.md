# post_slug (C port)

A C implementation of `post_slug`, byte-compatible with the peer
`post_slug.{bash,php,py,js}` modules in the parent directory. Exposes both a
linkable C library (`libpost_slug.a`) and a standalone CLI binary
(`_post_slug`).

Transliteration path: glibc `iconv` (`UTF-8` → `ASCII//TRANSLIT`). Matches the
Bash/PHP modules, which is what the cross-language `validate_slug_scripts`
harness validates against.

**Version**: 1.1.0

## Build

The Makefile is BCS1212-compliant: `make` with no target prints `help`; it
never modifies the system unless an explicit target is given.

```bash
make build      # builds _post_slug (CLI) and libpost_slug.a (static lib)
make install    # installs binary -> $(BINDIR)/post_slug (+ slugify link),
                #          library -> $(LIBDIR)/libpost_slug.a,
                #          header  -> $(INCLUDEDIR)/post_slug.h,
                #          manpage -> $(MANDIR)/post_slug.1 (+ slugify.1 link)
make uninstall  # removes installed files
make check      # verifies post_slug and slugify are callable
make test       # runs cross-language validation on edge_cases dataset
make clean      # removes build artefacts
make help       # shows targets and variables
```

Variables (overridable):

| Variable     | Default                                          |
|--------------|--------------------------------------------------|
| `PREFIX`     | `/usr/local`                                     |
| `BINDIR`     | `$(PREFIX)/bin`                                  |
| `LIBDIR`     | `$(PREFIX)/lib`                                  |
| `INCLUDEDIR` | `$(PREFIX)/include`                              |
| `MANDIR`     | `$(PREFIX)/share/man/man1`                       |
| `DESTDIR`    | (empty — set for staged/packaging installs)      |
| `CC`         | `cc`                                             |
| `CFLAGS`     | `-O2 -std=c11 -Wall -Wextra -Wpedantic`          |

Examples:

```bash
make CC=clang build
make PREFIX=$HOME/.local install
make DESTDIR=/tmp/pkg install     # staged install for packaging
```

Requires glibc 2.34+ (for `iconv` `ASCII//TRANSLIT`, and `pthread_once` in
libc). No external link flag needed on Ubuntu 24.04+; on older glibc, add
`-pthread`.

## CLI usage

```bash
./_post_slug "Hello, World!"                # hello-world
./_post_slug "Hello, World!" _ 1            # Hello_World
./_post_slug "A title with Ŝtřãņġę chars"   # a-title-with-strange-chars
./_post_slug "Long phrase here" - 0 8       # long
./_post_slug --stdin _ < titles.txt         # one slug per input line
./_post_slug -- -h                          # h  (slug a string that looks like an option)
```

Arguments (positional):

| # | Name            | Default | Description                                   |
|---|-----------------|---------|-----------------------------------------------|
| 1 | `input_str`     | —       | Required unless `--stdin`. Input string.      |
| 2 | `sep_char`      | `-`     | One ASCII character; only the first is used.  |
| 3 | `preserve_case` | `0`     | `0` = lowercase, `1` = preserve.              |
| 4 | `max_len`       | `0`     | `0` = unlimited; else truncated.              |

Options, recognised only as the first argument:

| Option        | Effect                                                         |
|---------------|----------------------------------------------------------------|
| `--stdin`     | Read input strings from stdin, one per line. The remaining arguments are `sep_char`, `preserve_case`, `max_len`. |
| `-h`, `--help`| Print help and exit.                                           |
| `--`          | Treat the next argument as `input_str`, even `-h` or `--stdin`. |

A literal `-` is an ordinary input string (its slug is empty), not stdin.

Output is the slug followed by a newline (matches the Python/PHP/JS wrappers).
In `--stdin` mode there is exactly one output line per input line, empty
lines included, so `paste` can pair input with output:

```bash
paste titles.txt <(./_post_slug --stdin < titles.txt)
```

One process handles any number of lines: about 0.05 s for 10,000 titles,
against about 8 s when starting `_post_slug` once per title.

Exit codes:

| Code | Meaning                                                              |
|------|----------------------------------------------------------------------|
| 0    | Success                                                              |
| 1    | Out of memory, or a read/write error (message on stderr)             |
| 2    | No input string given (help printed to stderr)                       |
| 22   | Non-ASCII `sep_char`, or `preserve_case`/`max_len` not a non-negative integer |

Output does not depend on the caller's locale: the same slugs come out under
`LC_ALL=C`, under cron, or when `LANG` names a locale that is not installed.

## Library usage

```c
#include "post_slug.h"
#include <stdio.h>
#include <stdlib.h>

int main(void) {
  char *slug = post_slug("Hello, World!", '-', 0, 0);
  if (slug) {
    puts(slug);   /* "hello-world" */
    free(slug);
  }
  return 0;
}
```

Compile against the static library:

```bash
cc -O2 -I/path/to/c -o myapp myapp.c /path/to/c/libpost_slug.a
```

Or just drop `post_slug.c` and `post_slug.h` into your project and compile with
`-DPOST_SLUG_LIB_ONLY` to omit the CLI `main()`.

### API contract

```c
char *post_slug(const char *input_str,
                char        sep_char,       /* '\0' or '-' → default '-' */
                int         preserve_case,  /* 0 = lowercase, 1 = preserve */
                size_t      max_len);       /* 0 = unlimited */
```

- The returned buffer is heap-allocated; the caller owns it and must `free()`.
- Returns `NULL` only on allocation failure.
- Returns a malloc'd empty string on any other error (mirrors the
  "empty string on failure" contract of the peer modules). A non-ASCII
  `sep_char` byte is such an error.
- Input is truncated to 255 UTF-8 codepoints before processing.
- Input that is not valid UTF-8 gives `""`, as in the Bash and PHP modules.
- Locale-independent and thread-safe: each call runs under `C.UTF-8` via
  `uselocale()`, which is per-thread and restored before returning. The host
  program's global locale and any per-thread locale it set are left as they
  were.

## Cross-language validation

The C binary takes part in the cross-language harness,
`../unittests/validate_slug_scripts`. The harness runs `make build` first
(so a stale binary is never the one tested), then compares every input
against the Python, JS, PHP and Bash outputs, using `--stdin` so each
implementation starts once per separator and case setting. Without `make`
and `cc` it tests an existing build, and without one it skips C.

```bash
cd ../unittests \
  && ./validate_slug_scripts -q datasets/headlines.txt \
  && ./validate_slug_scripts -q datasets/booktitles.txt 127 '-' 0 \
  && ./validate_slug_scripts -q datasets/products.txt   0   '_,-' '0,1' \
  && ./validate_slug_scripts -q datasets/edge_cases.txt
```

## Files

- `post_slug.c` — module body + optional CLI `main()`.
- `post_slug.h` — public API.
- `post_slug.1` — manpage for `post_slug` and `slugify`.
- `Makefile`   — build CLI, static library, install, clean.

#fin
