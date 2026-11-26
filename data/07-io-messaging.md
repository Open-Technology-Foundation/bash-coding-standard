<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Section 07: I/O & Messaging

## BCS0700 Section Overview

All status messages go to stderr. Only data output goes to stdout. This separation enables script composition and piping.

## BCS0701 Message Control Flags

**Tier:** style

Declare message control flags as integers at script start.

```bash
declare -i VERBOSE=1 PROMPT=1 DEBUG=0
```

## BCS0702 STDOUT vs STDERR Separation

**Tier:** core

```bash
# correct — status to stderr, data to stdout
info 'Processing files...'           # → stderr (via messaging function)
echo "$result"                       # → stdout (data output)
printf '%s\n' "$result"              # → stdout (data output)

# correct — place >&2 at the BEGINNING
>&2 echo 'error: something failed'
>&2 printf '%s\n' 'error: something failed'

# discouraged (style, not a violation) — >&2 at end works but is harder to spot
echo 'error: something failed' >&2
printf '%s\n' 'error: something failed' >&2

# wrong — status on stdout, so data=$(./script.sh) captures it as data
echo 'Processing files...'
printf 'all launched\n'
echo "error: ${file@Q} not found"
```

This rule owns the **stream**: status, progress or error text written to
stdout, and data written to stderr, whatever command prints it. Whether a
script that defines `info()`/`warn()`/`error()` ought to have used one in place
of a raw `echo` is BCS0705's question -- cite BCS0702 for the misdirected
stream, BCS0705 for the wrong mechanism, never both for one line.

Stream separation enables: `data=$(./script.sh)` captures only data, `./script.sh 2>errors.log` separates errors, `./script.sh | process` pipes data while showing messages.

## BCS0703 Core Messaging System

**Tier:** recommended

Structure:

- SCRIPT_NAME (already defined from Script Metadata section)
- Define Messaging Flags (as/if required)
- Define Messaging Colours (as/if required)
- Define Messaging Functions
  - Implement `_msg()` as the core output function
  - Implement `error()` and `die()`
  - Where script requires, implement `vecho` `info()` `warn()` `success()` `debug()`

```bash
# SCRIPT_NAME already defined in script metadata section

# Define Messaging Flags (VERBOSE, DEBUG, as/if required)
declare -i VERBOSE=1 DEBUG=0

# Define Messaging Colors (RED GREEN YELLOW etc, as/if required)
if [[ -t 1 && -t 2 ]]; then
  declare -r RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  declare -r RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

# Define Messaging Functions (add/remove as required by the specific script)
# Core:
_msg() { >&2 printf "$SCRIPT_NAME: $1 %s\n" "${@:2}"; }
error()   { _msg "$RED✗$NC" "$@"; }
die()     { (($# < 2)) || error "${@:2}"; exit "${1:-0}"; }
# Optional:
warn()    { _msg "$YELLOW▲$NC" "$@"; }
vecho()   { ((VERBOSE)) || return 0; _msg '' "$@"; }
info()    { ((VERBOSE)) || return 0; _msg "$CYAN◉$NC" "$@"; }
success() { ((VERBOSE)) || return 0; _msg "$GREEN✓$NC" "$@"; }
debug()   { ((DEBUG)) || return 0; _msg "$RED⦿$NC" "$@"; }
```

Rules:
- `error()` must be unconditional — always outputs to stderr
- `warn()` should be unconditional (warnings are important)
- `info()`, `success()`, `vecho()` respect VERBOSE flag
- `debug()` respects DEBUG flag
- `die()` takes exit code as first argument

### Simple No-Colour Messaging System:

```bash
declare -i VERBOSE=1
_msg() { >&2 printf "$SCRIPT_NAME: $1 %s\n" "${@:2}"; }
info()    { ((VERBOSE)) || return 0; _msg '◉' "$@"; }
success() { ((VERBOSE)) || return 0; _msg '✓' "$@"; }
warn()    { _msg '▲' "$@"; }
error()   { _msg '✗' "$@"; }
die()     { (($# < 2)) || error "${@:2}"; exit "${1:-0}"; }
```

**Note**: Per BCS0405, scripts should only include the messaging functions they actually call — omitting unused functions (e.g., `success()`, `debug()`, `vecho()`) is correct, not a violation.

## BCS0704 Usage Documentation

**Tier:** style

**Scope.** This rule governs help text that runs to more than one line: structure it in sections and print it from a single heredoc with `cat`. It does not require every script to carry such a help text. A script with a small option set may answer `-h` with a one-line usage string, as the `basic` template does, and a script may offer no help at all (BCS0806); neither is a finding. The findings are multi-line help assembled from a run of `echo` or `printf` calls, and help or version output sent through a messaging function.

```bash
show_help() {
  cat <<HELP
$SCRIPT_NAME $VERSION - a brief description of the script

Usage: $SCRIPT_NAME [OPTIONS] FILE [FILE ...]

A more detailed description of what the script does.

Options:

  -n, --dry-run     Dry run mode
  -v, --verbose     Verbose output (default)
  -q, --quiet       Quiet mode
  -V, --version     Show version
  -h, --help        Show this help

Examples:
  $SCRIPT_NAME file.txt
  $SCRIPT_NAME --dry-run *.csv
HELP
}
```

Never use messaging functions for help output. Help and version must always display regardless of VERBOSE setting.

```bash
# correct — a small option set: a one-line usage string is enough
-h|--help) printf 'Usage: %s [-m BYTES] [DIR]\n' "$SCRIPT_NAME"; exit 0 ;;

# wrong — multi-line help built call by call; use one heredoc
show_help() {
  echo "Usage: $SCRIPT_NAME [OPTIONS] FILE"
  echo ''
  echo 'Options:'
  echo '  -v, --verbose     Verbose output'
  echo '  -h, --help        Show this help'
}

# wrong — help through a messaging function: --quiet silences it
-h|--help) info "Usage: $SCRIPT_NAME [OPTIONS] FILE"; exit 0 ;;
```

## BCS0705 Echo vs Messaging Functions

**Tier:** recommended

```bash
# correct — messaging for status
info 'Validating environment...'
warn 'Deprecated option used'
error 'Connection failed'

# correct — printf or echo for data and help
printf '%s\n' "$result"              # data output; echo would swallow a value of -n or -e
echo "$SCRIPT_NAME $VERSION"         # version output
# help text
cat <<HELP
...
HELP

# correct — functions returning data write it to stdout
get_value() {
  printf '%s\n' "$result"            # stdout for callers to capture
}

# wrong — mixing streams
info "$result"                       # data via messaging function
echo 'Processing...' >&2             # status by hand, though info() exists

# not this rule — no messaging functions here; the defect is the stream:
# cite BCS0702
echo 'Processing...'
```

This rule governs the **mechanism**: a script that defines messaging functions
routes status through them, and never sends data through them. Which stream the
text lands on is BCS0702's finding, so a bare `echo 'Processing...'` in a script
with no messaging functions is cited under BCS0702 alone.

Never mix data and status on the same stream.

## BCS0706 Color Definitions

**Tier:** recommended

Use a conditional block to define colors.

```bash
# correct — basic color set (5 variables)
if [[ -t 1 && -t 2 ]]; then
  declare -r RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  declare -r RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi
```

```bash
# extended set (add only when needed, and only those colours that are required)
if [[ -t 1 && -t 2 ]]; then
  declare -r RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m' \
      BLUE=$'\033[0;34m' MAGENTA=$'\033[0;35m' BOLD=$'\033[1m' ITALIC=$'\033[3m' UNDERLINE=$'\033[4m' DIM=$'\033[2m' REVERSE=$'\033[7m'
else
  declare -r RED='' GREEN='' YELLOW='' CYAN='' NC='' \
      BLUE='' MAGENTA='' BOLD='' ITALIC='' UNDERLINE='' DIM='' REVERSE=''
fi
```

Per BCS0405, declare only the colors the script actually uses. A script with no `success()` function may not need `GREEN`. Both branches of the `if`/`else` must declare the same set of variables.

Never scatter inline color declarations across scripts. Centralize in a single declaration block.

## BCS0707 TUI Basics

**Tier:** recommended

"TUI elements" means output that is meaningful only on an interactive terminal:

- ANSI colour escapes (see BCS0706)
- Cursor positioning or visibility control (e.g., `\033[?25l`, `\033[H`)
- Progress bars, spinners, status lines
- Interactive prompts (see BCS0709)
- Terminal-width-dependent formatting (see BCS0708)

Each must be gated on `[[ -t 1 ]]` (or `[[ -t 1 && -t 2 ]]` when both streams matter) so that piped, redirected, or non-interactive invocations produce clean output.

```bash
# correct — TUI output gated on terminal
if [[ -t 1 ]]; then
  progress_bar 50 100
else
  echo '50% complete'
fi

# correct — hide cursor during TUI, restore on exit; the trap goes first (BCS0110),
# and a script with a cleanup() puts the restore there instead (one trap per signal)
if [[ -t 1 ]]; then
  trap 'printf "\033[?25h"' EXIT       # restore on exit
  printf '\033[?25l'                   # hide cursor
fi

# wrong — cursor escape leaks into pipes and logs
printf '\033[?25l'
```

Plain-text, JSON, or other machine-parseable output does NOT qualify as a TUI element and should flow to stdout unconditionally.

## BCS0708 Terminal Capabilities

**Tier:** recommended

Get terminal dimensions dynamically.

```bash
# correct
trap 'get_terminal_size' WINCH
cols=$(tput cols 2>/dev/null || echo 80)   # no terminal (cron, pipe): tput complains; use 80

# correct — check Unicode support (guarded; bare [[ ]] would trip errexit)
declare -i UNICODE=0
declare -- locale=${LC_ALL:-${LC_CTYPE:-${LANG:-}}}
[[ ${locale,,} =~ utf-?8 ]] && UNICODE=1 ||:   # en_US.UTF-8, C.utf8, en_US.utf8 alike
```

Never hardcode terminal width. Provide graceful fallbacks for limited terminals.

## BCS0709 Yes/No Prompt

**Tier:** style

```bash
yn() {
  ((PROMPT)) || return 0               # unattended run: the answer is yes
  local -- REPLY
  >&2 echo -n "$SCRIPT_NAME: $YELLOW▲$NC ${1:-Continue?} y/n "
  read -r -n 1
  >&2 echo
  [[ ${REPLY,,} == y ]]
}

# usage
yn 'Deploy to production?' || die 0 'Cancelled'
```

A confirmation must be suppressible, so the script can run unattended: either `yn()` returns success when `PROMPT` is 0 (declared in BCS0701, cleared by `-f`/`--force`, BCS0806), as above, or every call is guarded by `((PROMPT))`. A guard in either place satisfies this rule; a confirmation that cannot be switched off is a violation.

## BCS0710 Standard Icons

**Tier:** style

When messaging functions emit icons, use these glyphs for these purposes; do not invent alternatives.

| Icon | Purpose |
|------|---------|
| `◉` | Info |
| `⦿` | Debug |
| `▲` | Warning |
| `✓` | Success |
| `✗` | Error |
| `⚠` | Caution |

`▲` is the icon for `warn()` messages; `⚠` is reserved for inline caution markers in help and documentation text.

## BCS0711 Combined Redirection

**Tier:** style

Prefer `&>` and `&>>` over the verbose `>file 2>&1` and `>>file 2>&1` forms.

```bash
# correct — concise combined redirection
somecommand &>/dev/null
somecommand &>outfile
somecommand &>>logfile

# wrong — verbose combined redirection
somecommand >/dev/null 2>&1
somecommand >outfile 2>&1
somecommand >>logfile 2>&1
```

Use `2>/dev/null` or `2>file` when suppressing only stderr. The `&>` operator is for combined (stdout + stderr) redirection only.

`&>` also cannot be written in the wrong order. Redirections apply left to right, so `cmd 2>&1 >file` points stderr at the original stdout before stdout moves to `file`: stderr never reaches the file.
