<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Section 12: Style & Development

## BCS1200 Section Overview

Code formatting, comments, development practices, debugging, dry-run patterns, and testing support. These conventions ensure consistent, maintainable scripts.

## BCS1201 Code Formatting

**Tier:** style

- 2 spaces for indentation, never tabs. Two exceptions, where the tab is syntax rather than layout: the body of a `<<-` heredoc, whose leading tabs Bash strips (BCS0304), and a Makefile recipe line, which must begin with a tab (BCS1212)
- Lines under 120 characters (except URLs/paths)
- When a line must exceed the limit, break it with `\` continuation

## BCS1202 Comments

**Tier:** style

Write comments that add information not present in the code: constraints, gotchas, trade-offs, references to context. A comment that paraphrases the next statement in natural language adds no information and is a violation.

**Mechanical test for a violating comment:**

1. Remove the comment.
2. Read the code below it.
3. If the comment conveys no information that a competent reader couldn't recover from the code alone, it is a violation.

```bash
# correct — information not in the code (constraint + rationale)
# PROFILE_DIR hardcoded to /etc/profile.d for system-wide bash integration
declare -r PROFILE_DIR=/etc/profile.d

# correct — documents a non-obvious semantic
# readarray quirk: single empty element means no results
((fnd == 1)) && [[ -z ${found_files[0]} ]] && fnd=0 ||:

# wrong — paraphrases the statement below
# Set verbose to 1
VERBOSE=1

# wrong — restates a visible test
# Check if file exists
[[ -f $file ]]
```

LLM-based checkers should flag comments that mechanically paraphrase the next line. They should NOT flag comments that are terse but add information (e.g., the "readarray quirk:" example above).

## BCS1203 Blank Lines

**Tier:** style

- One blank line between functions
- One blank line between logical sections within functions
- One blank line before section comments, none between the comment and the code it marks
- Blank lines before and after multi-line blocks
- Never multiple consecutive blank lines
- No blank lines between short, related statements

## BCS1204 Section Comments

**Tier:** style

Section comments mark logical divisions within a script. They must be:

- A single line
- 2-4 words
- Prefixed with a single `#` (no box-drawing characters, no ASCII art frames)
- Placed directly above the first statement it marks, with a blank line before the comment

```bash
# correct — single #, 2-4 words, blank line before, none after
# Default values
declare -i VERBOSE=1 DEBUG=0

# Derived paths
declare -- BIN_DIR="$PREFIX"/bin

# Core message function
_msg() { :; }

# wrong — box drawing / multi-line frames
#############################
# Default values            #
#############################

# wrong — full sentence, too long
# These are the default values used when no user override is provided
declare -i VERBOSE=1 DEBUG=0
```

Reserve 80-dash separators (`# ----`) for major script divisions only. Two or three per file is plenty for a typical script. Large monolithic scripts -- subcommand dispatchers, multi-backend tools, framework-style libraries -- legitimately need more, and one divider per subcommand or per major architectural layer is fine. The test is whether each divider marks a real navigational landmark: if every minor section gets one, none of them help.

## BCS1205 Language Best Practices

**Tier:** style

Prefer shell builtins over external commands (10-100x faster).

```bash
# correct — builtins
$((x + y))                          # not $(expr $x + $y)
${path##*/}                         # not $(basename "$path")
${path%/*}                          # not $(dirname "$path")
${var^^}                            # not $(echo "$var" | tr a-z A-Z)
${var,,}                            # not $(echo "$var" | tr A-Z a-z)
[[ condition ]]                     # not [ condition ] or test: cite BCS0501 or BCS0901
var=$(command)                      # not backticks: cite BCS0302
{1..10}                             # not $(seq 1 10)

# not this rule — parsing a variable with an external tool: cite BCS0507
minor=$(echo "$tag" | cut -d. -f2)
```

Parsing a shell variable with an external tool (`grep -oE`, `cut -d`, `sed -n`,
`awk '{print $N}'`) is **BCS0507's** finding, not this rule's. The `[[ ]]` and
`$()` lines above are listed for completeness only: a `[ ]` or `test` is owned by
BCS0501 (strings, numbers) or BCS0901 (files), and a backtick by BCS0302. This rule
covers the remaining builtin substitutions listed above.

## BCS1206 Static Analysis Directives

**Tier:** core

ShellCheck compliance is compulsory. Use `#shellcheck disable=SCxxxx` only for documented exceptions, and `#bcscheck disable=BCSxxxx` likewise to suppress a specific BCS rule. *Documented* means the directive carries its reason: a comment after the directive on the same line, or on the line directly above it, saying why the warning does not apply here, or why it is accepted. A bare directive with no reason is a finding under this rule, whatever it suppresses.

Suppression scope follows ShellCheck conventions — the directive covers the **next command**, which may be a single line or a brace/block group:

```bash
# correct — suppresses the next line, reason on the directive
#bcscheck disable=BCS0606  # info() already guards on VERBOSE
((DRY_RUN)) && info 'Dry-run mode' ||:

# correct — suppresses the next compound command (here a whole case block)
#bcscheck disable=BCS0806  # -n/-N mean prompt here, not dry-run
case $opt in
  -p|-n|--prompt)    PROMPT=1; VERBOSE=1 ;;
  -P|-N|--no-prompt) PROMPT=0 ;;
esac

# correct — documented shellcheck exception (here an accepted one)
#shellcheck disable=SC2155  # accepted: declare masks realpath's exit status (BCS0103)
declare -r SCRIPT_PATH=$(realpath -- "$0")

# wrong — bare directive: nothing says why the warning does not apply
#shellcheck disable=SC2155
declare -r SCRIPT_PATH=$(realpath -- "$0")
```

Severity of a finding comes from the rule's tier alone; see the Compliance Checking Reference at the end of this document. (End-marker requirements are defined by BCS0109; performance idioms by BCS1205.)

## BCS1207 Debugging

**Tier:** recommended

Gate debug output on an integer `DEBUG` variable (`declare -i DEBUG=${DEBUG:-0}`, validated first because it comes from the environment: BCS1005), send it to stderr, and never ship an unconditional `set -x`. A trace prints every command with its values expanded, secrets included: keep `set -x` away from code that handles credentials.

```bash
# correct — among the globals, before die() exists, so the check exits by hand
[[ ${DEBUG:-0} =~ ^[0-9]+$ ]] || { >&2 echo "${0##*/}: DEBUG must be a non-negative integer"; exit 22; }
declare -i DEBUG=${DEBUG:-0}
((DEBUG)) && set -x ||:

# enhanced trace output
export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:+${FUNCNAME[0]}():} '

# debug function
debug() { ((DEBUG)) || return 0; _msg "$RED⦿$NC" "$@"; }   # _msg writes to stderr (BCS0703)

# runtime activation
DEBUG=1 ./script.sh
```

## BCS1208 Dry-Run Pattern

**Tier:** recommended

```bash
# correct
declare -i DRY_RUN=0
# parse: -n|--dry-run) DRY_RUN=1 ;;

deploy() {
  if ((DRY_RUN)); then
    info '[DRY-RUN] Would deploy to production'
    return 0
  fi
  # actual deployment
}
```

Dry-run maintains identical control flow (same function calls, same logic paths) to verify logic without side effects. Show detailed preview of what would happen with `[DRY-RUN]` prefix.

## BCS1209 Testing Support

**Tier:** recommended

```bash
# correct — dependency injection
declare -f find_cmd >/dev/null || find_cmd() { find "$@"; }
# override in tests: find_cmd() { echo 'mocked_file.txt'; }

# correct — test mode flag, validated before declare -i evaluates it (BCS1005)
[[ ${TEST_MODE:-0} =~ ^[0-9]+$ ]] || die 22 "Invalid TEST_MODE ${TEST_MODE@Q}"
declare -i TEST_MODE=${TEST_MODE:-0}

# correct — assert function; it records the failure, because a test called from
# `if` runs with set -e suspended (BCS0601) and carries on past a failed assert
declare -i TEST_FAILED=0
assert() {
  local -- expected=$1 actual=$2 msg=${3:-assertion}
  [[ $expected == "$actual" ]] || {
    error "FAIL: $msg: expected ${expected@Q}, got ${actual@Q}"
    TEST_FAILED=1
    return 1
  }
}

# correct — test runner: a test passes only if it returns 0 and no assert failed
run_tests() {
  local -i passed=0 failed=0
  local -- fn
  while read -r _ _ fn; do
    TEST_FAILED=0
    if "$fn" && ((TEST_FAILED == 0)); then
      passed+=1
    else
      failed+=1
    fi
  done < <(declare -F | grep -E '^declare -f test_')
  echo "Passed: $passed, Failed: $failed"
  ((failed == 0))
}
```

## BCS1210 Progressive State Management

**Tier:** recommended

Separate user intent from runtime state.

```bash
# correct
declare -i BUILTIN_REQUESTED=1       # user asked for it
declare -i INSTALL_BUILTIN=0         # what will actually happen

# validate prerequisites
if ((BUILTIN_REQUESTED)); then
  if build_builtin; then
    INSTALL_BUILTIN=1
  else
    warn 'Builtin build failed, skipping'
  fi
fi

# execute based on final state
((INSTALL_BUILTIN)) && install_builtin ||:
```

Apply state changes in logical order: parse, validate, execute. Never modify flags during execution phase.

## BCS1211 Utility Functions

**Tier:** style

Common helper functions:

```bash
# Argument validation
noarg() { (($# > 1)) || die 22 "Option ${1@Q} requires an argument"; }

# Trim whitespace
trim() { local -- v="$*"; v=${v#"${v%%[![:blank:]]*}"}; printf '%s' "${v%"${v##*[![:blank:]]}"}"; }

# Debug variable display (an unknown name reports itself and returns 1)
decp() { declare -p "$@" | sed 's/^declare -[a-zA-Z-]* //'; }

# Pluralization (a string test: an arithmetic one would evaluate its argument)
s() { [[ ${1:-1} == 1 ]] || printf 's'; }
```

## BCS1212 Makefile Installation

**Tier:** recommended

Bash projects that install to the system must include a Makefile. The Makefile must be non-interactive, silent by default (no banners or colour output), and idempotent.

### Required Targets

```
install     Install all project files
uninstall   Remove all installed files
check       Verify installation (commands found in PATH)
test        Run project test suite (if tests exist)
help        Show targets and variables
```

`all` should alias `help`, not `install` — accidental `make` must never modify the system.

### Required Variables

```makefile
PREFIX  ?= /usr/local
BINDIR  ?= $(PREFIX)/bin
MANDIR  ?= $(PREFIX)/share/man/man1
# /etc/bash_completion.d only for a system prefix; a custom PREFIX keeps its
# completions under itself instead of writing to the host's /etc
ifeq ($(filter /usr /usr/local,$(PREFIX)),)
COMPDIR ?= $(PREFIX)/share/bash-completion/completions
else
COMPDIR ?= /etc/bash_completion.d
endif
DESTDIR ?=
```

`DESTDIR` enables staged installs for packaging (`make DESTDIR=/tmp/pkg install`). Never hardcode paths — always use variables.

### Installation Rules

- Use `install(1)`, not `cp` + `chmod`.
- Use `install -d` for directory creation.
- Executables: `install -m 755`.
- Data files (manpages, completions, libraries): `install -m 644`.
- Symlinks: `ln -sf`.
- If the project contains manpages (`.1`, `.8`, etc.), the `install` target must install them.
- If the project contains bash completion files, the `install` target must install them (skip gracefully if `COMPDIR` does not exist).
- Configuration files: install a default only when none exists (`[ -e $(DESTDIR)$(CONFDIR)/app.conf ] || install -m 644 app.conf.example $(DESTDIR)$(CONFDIR)/app.conf`); `install` must never overwrite a user's edited configuration on upgrade.
- `uninstall` must remove everything `install` creates.
- `check` must verify installed commands are callable. Skip `check` when `DESTDIR` is set (staged installs).

### Source Path Anchoring

Install recipes must not depend on the invoking working directory. Anchor every *source* path (not destination) to the Makefile's own directory, so `sudo make -f /path/to/project/Makefile install` from an arbitrary CWD behaves identically to `cd project && sudo make install`.

```makefile
# Directory of this Makefile (trailing slash). Anchors source paths so
# 'make install' works regardless of invoking CWD and never picks up a
# like-named file from a parent directory.
srcdir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
```

- `$(MAKEFILE_LIST)` is GNU-make's list of parsed Makefiles.
- `$(lastword ...)` selects the currently-parsed one (robust under `include`).
- `$(abspath ...)` canonicalises to an absolute path.
- `$(dir ...)` strips the filename and keeps the trailing slash — so use `$(srcdir)LICENSE`, not `$(srcdir)/LICENSE`.

Prefix every *source* in install recipes with `$(srcdir)`. Destinations keep `$(DESTDIR)$(BINDIR)/...` form unchanged. For recipes using `tar -cf - <reldir>`, wrap with `cd $(srcdir) && tar ...` to preserve archive-internal relative paths.

```makefile
# correct — source anchored, works from any CWD
install -m 755 $(srcdir)myscript $(DESTDIR)$(BINDIR)/myscript

# wrong — resolves against invoking CWD; may silently pick up a
# like-named file from a parent directory, or fail cryptically
install -m 755 myscript $(DESTDIR)$(BINDIR)/myscript
```

### Template

```makefile
PREFIX  ?= /usr/local
BINDIR  ?= $(PREFIX)/bin
MANDIR  ?= $(PREFIX)/share/man/man1
ifeq ($(filter /usr /usr/local,$(PREFIX)),)
COMPDIR ?= $(PREFIX)/share/bash-completion/completions
else
COMPDIR ?= /etc/bash_completion.d
endif
DESTDIR ?=

# Directory of this Makefile (trailing slash). Anchors source paths so
# 'make install' works regardless of invoking CWD.
srcdir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: all install uninstall check test help

all: help

install:
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 $(srcdir)myscript $(DESTDIR)$(BINDIR)/myscript
	@# Manpages (if present)
	install -d $(DESTDIR)$(MANDIR)
	install -m 644 $(srcdir)myscript.1 $(DESTDIR)$(MANDIR)/myscript.1
	@# Bash completion: a COMPDIR under PREFIX is ours to create; a system one is used only if present
	@case "$(COMPDIR)" in "$(PREFIX)"/*) install -d $(DESTDIR)$(COMPDIR) ;; esac
	@if [ -d $(DESTDIR)$(COMPDIR) ]; then \
	  install -m 644 $(srcdir).bash_completion $(DESTDIR)$(COMPDIR)/myscript; \
	fi
	@if [ -z "$(DESTDIR)" ]; then $(MAKE) --no-print-directory check; fi

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/myscript
	rm -f $(DESTDIR)$(MANDIR)/myscript.1
	rm -f $(DESTDIR)$(COMPDIR)/myscript

check:
	@command -v myscript >/dev/null 2>&1 || { echo 'myscript: NOT FOUND (check PATH)'; exit 1; }
	@echo 'myscript: OK'

test:
	cd $(srcdir)tests && ./run_all_tests.sh

help:
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@echo '  install     Install to $(PREFIX)'
	@echo '  uninstall   Remove installed files'
	@echo '  check       Verify installation'
	@echo '  test        Run test suite'
	@echo '  help        Show this message'
```

## BCS1213 Date and Time Formatting

**Tier:** style

Prefer `printf '%()T'` (builtin strftime) over `$(date)` for date/time formatting — avoids fork overhead (~28x faster in benchmarks).

```bash
# correct — builtin, no fork
printf '%(%F)T' "$EPOCHSECONDS"
printf '%(%Y-%m-%d)T' -1
printf '%(%F %T)T' "$EPOCHSECONDS"
printf '%(%A %F %H:%M)T'

# correct — builtin, capture to variable (no subshell)
printf -v today '%(%F)T'

# correct — UTC via TZ prefix
TZ=UTC printf '%(%F %T)T'

# wrong — forks external process on every call
today=$(date +'%F %T')

# wrong — forks + unnecessary EPOCHSECONDS round-trip
date -d "@$EPOCHSECONDS" +'%Y-%m-%d'
```

Use `$EPOCHSECONDS` for integer epoch timestamps (second precision) and `$EPOCHREALTIME` for microsecond precision. Both are Bash builtins — no fork required.

`date(1)` is acceptable when `printf '%()T'` cannot provide the needed format (e.g., `date -d 'next Monday'` for relative date arithmetic).

See also: [Date Formatting Reference](../benchmarks/date_reference.md) — full `date` → `printf '%()T'` equivalence table with examples.
