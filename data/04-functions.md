<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Section 04: Functions & Libraries

## BCS0400 Section Overview

Organize functions bottom-up: messaging first, then helpers, then business logic, with `main()` last. Each function can safely call previously defined functions.

## BCS0401 Function Definition

**Tier:** style

Use single-line format for simple operations, multi-line for complex functions.

```bash
# correct — single-line
vecho() { ((VERBOSE)) || return 0; _msg "$@"; }

# correct — multi-line
process_file() {
  local -- filename=$1
  local -i line_count=0
  local -- line

  [[ -f $filename ]] || return 1

  while IFS= read -r line; do
    line_count+=1
  done < "$filename"

  return 0
}
```

Declare local variables before use, grouped near the function top when practical. Declarations may appear mid-body (e.g., after early-return guards, inside conditionals, or between logical sections), but must not appear inside loops. Always use proper types and `return` explicitly from complex functions.

## BCS0402 Function Names

**Tier:** recommended

```bash
# correct
process_log_file() { :; }           # lowercase with underscores
_validate_input() { :; }            # underscore prefix for private

# wrong
ProcessLogFile() { :; }             # camelCase
PROCESS_FILE() { :; }               # UPPER_CASE
my-function() { :; }                # dashes (invalid in some contexts)
cd() { :; }                         # overriding built-in
```

Never use dashes in function names. Never override built-in commands without good reason.

## BCS0403 Main Function

**Tier:** recommended

Include `main()` for scripts longer than ~200 lines. Place `main "$@"` at the bottom just before `#fin`.

```bash
# correct
main() {
  # Parse arguments
  while (($#)); do case $1 in
    -v|--verbose) VERBOSE=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    -h|--help)    show_help; exit 0 ;;
    -*)           die 22 "Invalid option ${1@Q}" ;;
    *)            FILES+=("$1") ;;
  esac; shift; done

  # Make parsed variables readonly
  readonly VERBOSE DRY_RUN

  # Business logic
  process_files
}

main "$@"
#fin
```

Always call main with all arguments: `main "$@"`, never just `main`.

This is the canonical rule for `main()` structure and content (argument parsing inside `main()`, readonly-after-parse, `main "$@"`). BCS0108 covers only the structural placement of the invocation; cite BCS0403 for main() content violations.

## BCS0404 Function Export

**Tier:** recommended

Export functions needed by child bash processes (e.g. `bash -c`, `xargs bash -c`, `find -exec bash -c ... \;`) with `declare -fx`. Subshells and command substitutions inherit functions automatically and need no export.

```bash
# correct — define first, then export
grep() { /usr/bin/grep "$@"; }
find() { /usr/bin/find "$@"; }
declare -fx grep find

# consumer — child bash process sees the exported functions
find . -name '*.txt' -exec bash -c 'grep pattern "$1"' _ {} \;
```

## BCS0405 Production Optimization

**Tier:** style

Remove unused utility functions from production scripts. **This rule takes precedence over template completeness** — do not add functions, variables, or color definitions from reference templates (BCS0703, BCS0706, BCS0701) unless the script actually uses them.

```bash
# wrong — keeping unused functions
yn() { :; }          # never called in this script
trim() { :; }        # never called in this script
debug() { :; }       # DEBUG never set in this script

# wrong — declaring unused color/flag variables
declare -r GREEN=$'\033[0;32m'       # no success() function uses it
declare -i DEBUG=0                   # no debug() function exists
```

Keep only functions and variables the script actually needs. Remove unused globals too.

## BCS0406 Dual-Purpose Scripts

**Tier:** core

For scripts that can be sourced or executed, define functions before the source fence and strict mode after it. Either fence pattern is acceptable:

```bash
# correct — BASH_SOURCE fence with conditional export
my_function() {
  local -- name=$1
  echo "Hello, $name"
}

# --- source fence ---
[[ ${BASH_SOURCE[0]} == "$0" ]] || { declare -fx my_function; return 0; }

# --- Script mode only ---
set -euo pipefail
shopt -s inherit_errexit
my_function "$@"
#fin
```

```bash
# correct — 'return 0' source fence (export unconditionally before fence)
my_function() {
  local -- name=$1
  echo "Hello, $name"
}
declare -fx my_function

# --- source fence ---
return 0 2>/dev/null ||:

# --- Script mode only ---
set -euo pipefail
shopt -s inherit_errexit
my_function "$@"
#fin
```

Use idempotent initialization with version guard:

```bash
[[ -v MY_LIB_VERSION ]] || {
  declare -rx MY_LIB_VERSION=1.0.0
  # other initialization
}
```

This is the canonical rule for dual-purpose script structure (function placement, source fence, strict-mode positioning) — cite BCS0406 for fence-structure violations. BCS0106 owns the file-extension requirements. The terms "source fence" and "source guard" refer to the same mechanism; this standard prefers "source fence".

## BCS0407 Library Patterns

**Tier:** core

Pure libraries must reject direct execution.

```bash
# correct — library pattern
[[ ${BASH_SOURCE[0]} != "$0" ]] || {
  >&2 echo "Error: ${0@Q} must be sourced"
  exit 1
}

declare -rx LIB_VALIDATION_VERSION=1.0.0

# Namespace all functions
myapp_init() { :; }
myapp_cleanup() { :; }
myapp_process() { :; }
declare -fx myapp_init myapp_cleanup myapp_process
```

Libraries should only define functions, not have side effects on source. Allow configuration override before sourcing: `: "${CONFIG_DIR:=/etc/myapp}"`.

Library functions signal failure with `return`, never `exit` or `die`: they run in the caller's shell, and `exit` there terminates the sourcing script or the user's interactive session. Whether to exit is the caller's decision.

```bash
# correct — the caller decides
myapp_load() { [[ -f $1 ]] || return 3; }

# wrong — exit inside a library function kills the sourcing shell
myapp_load() { [[ -f $1 ]] || exit 3; }
```

Source libraries with existence check:

```bash
[[ -f $lib_path ]] || die 3 "Missing library ${lib_path@Q}"
source -- "$lib_path" || die 1 "Failed to source ${lib_path@Q}"
```

Sourced as the left side of `||`, the library body runs with `set -e` suspended (BCS0601). That costs nothing when the library only defines functions, as above: the functions run later, under the caller's `set -e`. A syntax error still stops the source either way.

## BCS0408 Dependency Management

**Tier:** recommended

Use `command -v` for dependency checks, never `which`. POSIX/coreutils commands guaranteed on any Bash 5.2+ system (e.g., `sed`, `awk`, `grep`, `cat`, `date`, `tput`, `wc`, `stty`, `mkdir`, `rm`, `cp`, `mv`) do not require checks — only verify non-standard or separately packaged tools.

```bash
# correct — check non-standard tools
command -v curl >/dev/null || die 18 'curl required: apt install curl'

# correct — check multiple non-standard tools
for cmd in curl jq pandoc; do
  command -v "$cmd" >/dev/null || die 18 "Required: ${cmd@Q}"
done

# correct — optional dependency
declare -i HAS_JQ=0
command -v jq >/dev/null && HAS_JQ=1 ||:

# correct — check bash version (see BCS0409)
require_bash 5 2

# wrong — using which
which curl &>/dev/null

# wrong — checking coreutils commands
command -v sed >/dev/null || die 18 'sed required'
```

For expensive checks (network probes, slow tool startup), defer the check until first use with a guard variable instead of checking eagerly at startup:

```bash
# correct — lazy check: runs once, on first use
declare -i _CURL_OK=0
_ensure_curl() {
  ((_CURL_OK)) && return 0
  command -v curl >/dev/null || die 18 'curl required: apt install curl'
  _CURL_OK=1
}
```

## BCS0409 Bash Version Detection

**Tier:** core

**Scope.** A version guard is **optional**. BCS targets Bash 5.2+, and a script that runs only where that floor is assured (a managed fleet, a container, a CI image) needs no guard; its absence is **never** a finding. This rule governs how a version check is written and where it is placed **when a script has one**. Add a guard when the script may be run on hosts you do not control, or when it needs a floor above 5.2.

Compare `BASH_VERSINFO` elements per component with short-circuit on the first differing index. Compound expressions like `((BASH_VERSINFO[0] >= 5 && BASH_VERSINFO[1] >= 2))` are wrong: they reject Bash 6.0 (major=6 satisfies, but minor=0 does not) even though 6.0 is newer than 5.2.

Provide two predicates: a pure test (`bash_at_least`) and an exit-on-fail wrapper (`require_bash`).

```bash
# correct — per-component short-circuit, handles newer majors with lower minors
bash_at_least() {
  local -i major=${1:-0} minor=${2:-0} patch=${3:-0}
  (( BASH_VERSINFO[0] != major )) && return $(( BASH_VERSINFO[0] < major ))
  (( BASH_VERSINFO[1] != minor )) && return $(( BASH_VERSINFO[1] < minor ))
  (( BASH_VERSINFO[2] >= patch ))
}

# require_bash runs before the metadata, colours and messaging helpers exist, and on
# the old Bash it is meant to reject: it must be self-contained, with no die() and no
# syntax newer than Bash 3 (no ${var@Q})
require_bash() {
  bash_at_least "$@" && return 0
  >&2 printf '%s: requires Bash >= %s (have %s)\n' "${0##*/}" \
    "${1:-0}.${2:-0}.${3:-0}" "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}.${BASH_VERSINFO[2]}"
  exit 2
}
```

```bash
# wrong — compound && fails for newer major with lower minor
((BASH_VERSINFO[0] >= 5 && BASH_VERSINFO[1] >= 2)) || die 1 'Requires Bash 5.2+'
# On Bash 6.0: major=6>=5 (true) && minor=0>=2 (false) → dies, though 6.0 > 5.2

# wrong — string compare on BASH_VERSION is lexicographic
[[ $BASH_VERSION > "5.2" ]]   # "5.10" < "5.2" under string compare
```

A finding under this rule requires a version check to exist in the script. Violations: a compound `&&` comparison of `BASH_VERSINFO` components; a string comparison of `BASH_VERSION`; a guard placed after `shopt -s inherit_errexit` or other version-dependent code; a guard that depends on anything defined after it (`die()`, colour variables, `SCRIPT_NAME`) or on syntax newer than the Bash it rejects (`${var@Q}`), so that it fails before its message prints. Not a violation: having no guard.

`BASH_VERSINFO` indices: `[0]`=major, `[1]`=minor, `[2]`=patch, `[3]`=build, `[4]`=release status, `[5]`=machine type. Always compare integers per element; never compare `BASH_VERSION` as a string.

When a script has a guard, define `bash_at_least` and `require_bash` and call `require_bash` at script start, after `set -euo pipefail` (safe on any Bash) but before `shopt -s inherit_errexit` and any other version-dependent code:

```bash
#!/usr/bin/bash
set -euo pipefail
# bash_at_least() and require_bash() as above, defined here
require_bash 5 2
shopt -s inherit_errexit
```

**Placement is what this rule enforces: a guard, if present, must precede every version-dependent construct, including `shopt -s inherit_errexit` itself (which requires Bash 4.4+).** If `shopt -s inherit_errexit` runs before the version check on a Bash 3 host, the `shopt` line fails first with a cryptic `invalid shell option name`, `set -e` exits the script, and the helpful version message is never reached.

### Quick one-liner form

For scripts that need only a single hard floor (no graceful degradation, no shared helper to reuse, no library-style use), the predicate pair can be inlined as one statement. It sits in the same slot as `require_bash`: after `set -euo pipefail`, which is safe on any Bash, and before `shopt -s inherit_errexit` and every other version-dependent construct. That slot is the one exception BCS0101 makes to "shopt immediately after set"; nothing may run before `set -euo pipefail`. The `||` branch keeps a failed test from tripping `set -e` before the message prints:

```bash
#!/usr/bin/bash
set -euo pipefail
(( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 2) )) \
  || { >&2 echo "${0##*/}: requires Bash >= 5.2 (have ${BASH_VERSION:-unknown})"; exit 2; }
shopt -s inherit_errexit
```

The compound `>` / `&&` form is correct here — unlike the rejected `((BASH_VERSINFO[0] >= 5 && BASH_VERSINFO[1] >= 2))` antipattern — because the major-greater branch (`> 5`) accepts any newer major regardless of minor, and the equal-major branch (`== 5 && minor >= 2`) handles the boundary case explicitly. Bash 6.0 satisfies the first branch and is correctly accepted.

Suitable when:

- The script needs exactly one hard version floor (no `if bash_at_least` graceful fallbacks).
- The failure path is terminal — no shared error helper to reuse.
- Helper-function indirection would be inappropriate weight for a self-contained tool.

Prefer the `bash_at_least` / `require_bash` predicates when any of those conditions don't hold (multiple version checks, graceful degradation, library-style scripts).

Use `bash_at_least` as a predicate when a script can degrade gracefully:

```bash
if bash_at_least 5 2; then
  declare -A cache=()     # associative arrays
else
  declare -a cache=()     # fallback
fi
```

Omitted components default to 0: `bash_at_least 5` accepts any 5.x; `bash_at_least 5 2` accepts 5.2.0+; `bash_at_least 5 2 21` accepts 5.2.21+.

Placement of `require_bash` between `set -euo pipefail` and `shopt -s inherit_errexit` is an explicit, documented exception to BCS0101's "shopt immediately after set" ordering — see the exception note in BCS0101.

## BCS0410 Recursive Function State Discipline

**Tier:** core

Any variable assigned inside a recursive function must be declared `local`, **including for-loop variables**. Without `local`, a recursive call mutates the caller's variable -- producing silent corruption that depends on recursion depth and traversal order.

**Test:** if a function's body references its own name (direct recursion) or calls another function that calls back into it (mutual recursion), every variable assigned in its body -- including `for VAR in ...` loop variables -- must be declared `local`.

```bash
# correct — loop variable declared local; caller's f is preserved
walk() {
  local -- dir=$1
  local -- f
  for f in "$dir"/*; do
    [[ -d $f ]] && walk "$f" ||:           # recursive call
    echo "$f"                              # always the current iteration's $f
  done
}

# wrong — f leaks; after walk() returns, the caller's $f is whatever the
# deepest recursion happened to leave behind
walk() {
  local -- dir=$1
  for f in "$dir"/*; do                    # MISSING 'local -- f' above
    [[ -d $f ]] && walk "$f" ||:
    echo "$f"                              # may print a path from the wrong level
  done
}
```

Values passed via positional arguments (`$1`, `$2`, ...) are automatically per-call and do not need `local`.

**Exception:** variables declared at file scope (or with `declare -g`) and intentionally used as shared accumulators are exempt -- e.g. `declare -a RESULTS` at file scope with `RESULTS+=("$f")` inside the recursive walker.

LLM-based checkers should flag only assignments inside a recursive function that have neither a `local` declaration in the function nor a global declaration in the script -- including `for VAR in ...` which implicitly assigns `VAR`.

## BCS0411 Subshell Return-Value Patterns

**Tier:** recommended

When a computation runs in a subshell, choose one of four documented patterns to return data to the parent shell. Never rely on variable mutation across the subshell boundary -- the assignment is lost when the subshell exits.

This rule governs the **choice of pattern** for a subshell that is there on purpose. The lost-state defect itself -- a pipe into a loop whose body sets a variable the caller reads -- is owned at core severity by **BCS0504** (and BCS0903 for its exit status); cite those, not this rule, as BCS0906 does for the `find` spelling.

```bash
# not this rule — a pipe into a loop losing its state: cite BCS0504
grep -- '' "$file" | while read -r line; do count+=1; done
```

**Pattern 1 -- Command substitution** (single value or multiline text):

```bash
local -- content hash
content=$(< "$file")
hash=$(sha256sum -- "$file" | cut -d' ' -f1)
```

**Pattern 2 -- Process substitution with `readarray` or `while`** (array or streaming output, preserves parent scope):

```bash
readarray -t lines < <(grep -- pattern "$file")
while IFS= read -r line; do
  process "$line"
done < <(some_command)
```

**Pattern 3 -- Temp file** (large output, binary data, or output consumed by multiple later passes):

```bash
# global so the single-quoted trap (BCS0603) can expand it at EXIT time; a script that
# already has an EXIT trap adds this removal to its cleanup() instead (one trap per signal)
declare -g TEMP_FILE=''
trap '[[ -z $TEMP_FILE ]] || rm -f -- "$TEMP_FILE"' EXIT
TEMP_FILE=$(mktemp) || die 1 'mktemp failed'
expensive_command > "$TEMP_FILE"
first_pass  < "$TEMP_FILE"
second_pass < "$TEMP_FILE"
```

**Pattern 4 -- Explicit file descriptor** (long-running producer, interleaved reads):

```bash
exec 3< <(long_running_stream)
while IFS= read -r -u 3 line; do
  process "$line"
done
exec 3<&-
```

**Anti-patterns:**

```bash
# wrong — subshell variable lost
declare -i count=0
find . -name '*.log' | while read -r f; do
  count+=1                               # modified in subshell, invisible in parent
done
echo "$count"                            # always 0

# wrong — expecting a function called in a subshell to mutate globals
process_files() { global_count+=1; }
(process_files)                          # runs in subshell; global_count unchanged
```

Cross-references: BCS0504 (pipe-to-while subshells), BCS0903 (process substitution in file contexts), BCS0906 (`find` subshell pitfalls).
