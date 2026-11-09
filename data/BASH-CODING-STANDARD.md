<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Bash Coding Standard (BCS)

**Concise, actionable coding rules for BCS Bash 5.2+**

Designed by Okusi Associates for the Indonesian Open Technology Foundation (YaTTI).
Target audience: both human programmers and AI assistants.

[BCS Bash 5.2 Reference](../docs/BCS-bash/index.md) -- the `bash(1)` man page rewritten for BCS assumptions (`set -euo pipefail`, `[[ ]]` only, no POSIX compat, etc).

[Example exemplar BCS-compliant scripts directory](../examples/)

Templates for new scripts: [complete.sh.template](../examples/templates/complete.sh.template), [basic.sh.template](../examples/templates/basic.sh.template), [minimal.sh.template](../examples/templates/minimal.sh.template), [library.sh.template](../examples/templates/library.sh.template)

[Codebase examples](../examples/lib/index.md)

## Coding Principles
- K.I.S.S.
- "The best process is no process"
- "Everything should be made as simple as possible, but not any simpler."
- **Critical:** Do not over-engineer scripts; **remove unused functions and variables**

## Contents
01. Script Structure & Layout
02. Variables & Data Types
03. Strings & Quoting
04. Functions & Libraries
05. Control Flow
06. Error Handling
07. I/O & Messaging
08. Command-Line Arguments
09. File Operations
10. Security
11. Concurrency & Jobs
12. Style & Development

---

# Section 01: Script Structure & Layout

## BCS0100 Section Overview

Every BCS-compliant script follows a 13-step structure. Scripts must be self-contained, predictable, and safe. This section defines the canonical ordering and required elements.

## BCS0101 Strict Mode

**Tier:** core

`set -euo pipefail` is *mandatory* before script execution starts, and must be the first executable command after shebang, comments, and shellcheck directives. Exception: dual-purpose scripts place strict mode immediately after the source fence instead, because `set -euo pipefail` must never execute when sourced -- BCS0406 owns that layout and is the code to cite when strict mode sits above the fence; BCS0106 owns only the file-extension requirements. Exception: a Bash version guard (BCS0409) may sit between `set -euo pipefail` and `shopt -s inherit_errexit`, because the guard must run before any version-dependent construct (including `inherit_errexit` itself).

```bash
# correct
#!/usr/bin/bash
#shellcheck disable=SC???? # (optional)
# Brief description (recommended)
set -euo pipefail
shopt -s inherit_errexit

# wrong — strict mode after variable declarations
#!/usr/bin/bash
declare -r VERSION=1.0.0
set -euo pipefail
```

Add `shopt -s inherit_errexit` immediately after.

- `inherit_errexit`: makes `set -e` work in command substitutions (critical)

**When appropriate**, the following setting could also be added:

- `shift_verbose`: makes `shift` fail visibly when no args remain
- `extglob`: enables `@()`, `!()`, `+()` patterns
- `nullglob`: unmatched globs expand to nothing instead of literal string

Choose `failglob` instead of `nullglob` for strict scripts where unmatched globs should be errors.

## BCS0102 Shebang

**Tier:** core

First executable line of any script must be a shebang. Three acceptable forms:

```bash
#!/usr/bin/bash       # Preferred for Linux systems
#!/bin/bash           # Acceptable
#!/usr/bin/env bash   # Maximum portability
```

*Any* one of these shebangs are acceptable.

Follow with optional `#shellcheck` or `#bcscheck` directives, then a brief description comment.

```bash
#!/usr/bin/bash
#shellcheck disable=SC2015  # BCS idiom: ((cond)) && action ||:
# myscript - brief description of what this script does
set -euo pipefail
shopt -s inherit_errexit
```

## BCS0103 Script Metadata

**Tier:** recommended

Declare metadata immediately after `shopt`. Use `realpath` (not `readlink`) by default.

Standard metavars are VERSION, SCRIPT_PATH, SCRIPT_DIR, SCRIPT_NAME. Not all scripts need all four.

```bash
# correct — handles every install pattern, including symlinked wrappers
declare -r VERSION=1.0.0
#shellcheck disable=SC2155  # accepted: declare masks realpath's exit status (BCS0103)
declare -r SCRIPT_PATH=$(realpath -- "$0")
declare -r SCRIPT_DIR=${SCRIPT_PATH%/*} SCRIPT_NAME=${SCRIPT_PATH##*/}

# also correct — checked form: a plain assignment carries realpath's status, so errexit stops here
declare -- SCRIPT_PATH
SCRIPT_PATH=$(realpath -- "$0")
declare -r SCRIPT_PATH

# wrong — readlink where realpath is the standard
#shellcheck disable=SC2155  # accepted: declare masks readlink's exit status (BCS0103)
declare -r SCRIPT_PATH=$(readlink -f -- "$0")
```

Use `#shellcheck disable=SC2155` before the `SCRIPT_PATH` line, with its reason (BCS1206). The one-line form is an accepted trade, not a safe one. `declare` returns its own status, so when `realpath` fails the script does **not** stop: `set -e` and `inherit_errexit` see a successful `declare`, and `SCRIPT_PATH`, `SCRIPT_DIR` and `SCRIPT_NAME` are left readonly and empty. The trade is accepted because `realpath -- "$0"` fails only when `realpath` itself cannot be run or a directory named in `$0` no longer exists, and the usual cost is an empty name in messages. Use the checked form where an empty `SCRIPT_DIR` would do harm (it locates files to source, write or remove). Neither form is a finding.

## BCS0104 FHS Compliance

**Tier:** recommended

Search for resources in FHS order:

```bash
# correct — FHS search path
local -a search_paths=(
  "$SCRIPT_DIR"/data
  "$PREFIX"/share/myapp/data
  /usr/local/share/myapp/data
  /usr/share/myapp/data
)
for dir in "${search_paths[@]}"; do
  [[ -d $dir ]] && { DATA_DIR="$dir"; break; }
done
```

Locate companion files (libraries, data, configuration) relative to `$SCRIPT_DIR`, never relative to the current working directory: `source -- "$SCRIPT_DIR"/lib/common.sh`, not `source lib/common.sh` or `source ../lib/common.sh`, which break when the script is run from another directory. `SCRIPT_DIR=$PWD` is the same mistake.

Support `PREFIX` customization and XDG directories:

```bash
declare -- PREFIX=${PREFIX:-/usr/local}
declare -- BIN_DIR="$PREFIX"/bin
declare -- CONFIG_DIR=${XDG_CONFIG_HOME:-"$HOME"/.config}/myapp
```

## BCS0105 Global Variables and Colors

**Tier:** recommended

Declare all global variables up front with explicit types.

```bash
# correct
declare -i VERBOSE=1 DEBUG=0 DRY_RUN=0
declare -- OUTPUT_DIR=./output
declare -a FILES=()

# wrong — no type, scattered declarations
VERBOSE=1
# ... 50 lines later ...
DEBUG=0
```

Define colors conditionally on terminal detection:

```bash
if [[ -t 1 && -t 2 ]]; then
  declare -r RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  declare -r RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi
```

Always check BOTH stdout AND stderr: `[[ -t 1 && -t 2 ]]`.

## BCS0106 File Extensions and Dual-Purpose Scripts

**Tier:** core

Executables: `.sh` extension or no extension. Globally available executables via PATH must have no extension. Libraries must have `.sh` or `.bash` extension and should not be executable.

**Dual-purpose scripts** (can be sourced or executed) use a source fence to separate library functions from script mode. Either fence pattern is acceptable:

```bash
# correct — BASH_SOURCE fence (supports conditional actions in the guard)
[[ ${BASH_SOURCE[0]} == "$0" ]] || return 0

# correct — return 0 fence (single builtin, also valid in POSIX sh)
return 0 2>/dev/null ||:
```

Define functions above the fence, strict mode and mainline below:

```bash
# correct — dual-purpose script
my_function() {
  local -- name=$1
  echo "Hello, $name"
}
declare -fx my_function

# --- source fence ---
return 0 2>/dev/null ||:

# --- Script mode only below ---
set -euo pipefail
shopt -s inherit_errexit
my_function "$@"
#fin
```

Never apply `set -euo pipefail` when sourced — it alters the calling shell's environment.

This rule owns file-extension requirements. The full dual-purpose layout (function placement, fence ordering, strict-mode positioning) is owned by BCS0406 — cite BCS0406 for source-fence structure violations.

See also: [Source Guard Reference](../benchmarks/source-guard_reference.md) — full comparison of source fence (source guard) mechanisms with benchmark data.

## BCS0107 Function Organization

**Tier:** style

Organize functions bottom-up. The binding requirement is dependency order: every function is defined above the functions that call it, so a reader going top-down meets each primitive before its use and no call is a forward reference. The 7 layers are the conventional way to achieve that:

1. Messaging functions (lowest level)
2. Documentation functions (help, usage)
3. Helper/utility functions
4. Validation functions
5. Business logic functions
6. Orchestration/flow functions
7. `main()` function (highest level)

```bash
# correct — bottom-up, each function calls only previously defined functions
_msg() { :; }
info() { _msg "$@"; }

show_help() { cat <<HELP
...
HELP
}

validate_input() { :; }

process_file() { validate_input "$1"; }

main() { process_file "$@"; }

main "$@"
#fin
```

Never define `main()` at the top. Never define business logic before the utilities it calls. Layers with no dependency between them may appear in either order: helpers such as `noarg()` and `yn()` defined above `show_help()` is the order the BCS templates themselves use, and is not a finding. The finding is a function defined above something it calls, or `main()` anywhere but last. Nested function definitions are permitted only when the inner function is private to and only callable after the outer function runs (e.g. dynamically generated handlers); otherwise define all functions at top level.

## BCS0108 Main Function and Script Invocation

**Tier:** recommended

Generally, use `main()` for scripts over ~200 lines. Parse arguments within `main()`, then make configuration variables readonly after parsing.

```bash
# correct
main() {
  while (($#)); do case $1 in
    -n|--dry-run)     DRY_RUN=1 ;;
    -N|--not-dry-run) DRY_RUN=0 ;;
    -v|--verbose)     VERBOSE=1 ;;
    -q|--quiet)       VERBOSE=0 ;;
    -*)               die 22 "Invalid option ${1@Q}" ;;
  esac; shift; done
  readonly VERBOSE DRY_RUN

  # Business logic here
  : ...
}

main "$@"
#fin
```

Always quote `"$@"` to preserve the argument array. Scripts under 200 lines may run directly without `main()`.

This rule governs the structural placement of `main()` and its invocation (steps 11–12 of the script layout). The structure and content of `main()` itself — argument parsing, `main "$@"` vs bare `main`, readonly-after-parse — are owned by BCS0403; cite BCS0403 for main() content violations.

## BCS0109 End Marker

**Tier:** recommended

Every script must end with `#fin\n` as the mandatory final line.

```bash
# correct — last line of file
main "$@"
#fin
```

```bash
# wrong — missing end marker, or extra content after
main "$@"
```

The end marker simply confirms the file is complete and not truncated. (`#end`, accepted by earlier revisions of this rule, is deprecated — use `#fin`, which is what BCS0403 and the shipped templates mandate.) This rule is the sole owner of the `#fin` requirement — cite BCS0109 for a missing or malformed end marker.

## BCS0110 Cleanup and Traps

**Tier:** core

Scripts requiring cleanup must define the cleanup function and set the trap before any code that creates temporary resources.

```bash
# correct
declare -- TEMP_DIR
#...
cleanup() {
  local -i exitcode=${1:-$?}
  trap - SIGINT SIGTERM EXIT
  [[ -z ${TEMP_DIR:-} ]] || rm -rf -- "$TEMP_DIR"
  exit "$exitcode"
}
trap 'cleanup $?' SIGINT SIGTERM EXIT
#...
TEMP_DIR=$(mktemp -d) || die 1 'Failed to create temp dir'
```

Always disable traps inside the cleanup function to prevent recursion.

This rule governs structural placement: cleanup function and trap installed before any resource-creating code. A script that creates a temporary resource and installs no cleanup trap at all is cited here too, not as BCS1006, which owns only how the temporary name is made. The trap/cleanup pattern itself (quoting, signal lists, recursion guard) is owned by BCS0603 — cite BCS0603 for trap-content violations and BCS0110 for ordering violations.

## BCS0111 Configuration File Loading

**Tier:** recommended

Use `read_conf()` to cascade-source `.conf` files from a priority-ordered search path. System files load first, user files last, so user settings override system defaults key-by-key. Missing files are skipped silently.

```bash
# correct — standard read_conf() function (cascade mode)
read_conf() {
  local -- conf_file=''
  local -i loaded=0
  local -a search_paths=(
    /usr/lib/"$SCRIPT_NAME"/"$SCRIPT_NAME".conf
    /usr/share/"$SCRIPT_NAME"/"$SCRIPT_NAME".conf
    /usr/local/etc/"$SCRIPT_NAME"/"$SCRIPT_NAME".conf
    /etc/"$SCRIPT_NAME".conf
    /etc/"$SCRIPT_NAME"/"$SCRIPT_NAME".conf
    "${XDG_CONFIG_HOME:-$HOME/.config}"/"$SCRIPT_NAME"/"$SCRIPT_NAME".conf
  )

  for conf_file in "${search_paths[@]}"; do
    [[ -f $conf_file ]] || continue
    #shellcheck source=/dev/null
    source -- "$conf_file"
    loaded+=1
  done

  ((loaded))
}
```

Cascade order (later entries override earlier):

1. `/usr/lib/name/name.conf` — library-provided defaults
2. `/usr/share/name/name.conf` — package-provided defaults
3. `/usr/local/etc/name/name.conf` — locally-installed defaults
4. `/etc/name.conf` — system config (flat file)
5. `/etc/name/name.conf` — system config (directory)
6. `$XDG_CONFIG_HOME/name/name.conf` — user config (XDG standard)

Because each file is sourced in the current shell, any variable assignments in a later file override earlier ones while unset keys inherit from earlier layers. This lets a user override one setting without re-declaring all defaults.

`read_conf` returns success when at least one file was loaded, failure when none matched. Call it early in `main()`, before argument parsing if config values set defaults, or after parsing if CLI options should override config:

```bash
# correct — config sets defaults, CLI overrides
main() {
  read_conf ||:
  while (($#)); do case $1 in
    # options override config values...
    : ...
  esac; shift; done
}
```

Configuration files are sourced as Bash — they execute in the calling shell's context. Only source config files from trusted locations with appropriate permissions. Cascading increases attack surface linearly in the number of search paths, so never add user-writable paths to scripts that may run with elevated privileges.

The cascade `source`-based pattern is the standard approach. Scripts that intentionally use alternative methods (e.g., first-match-wins semantics, `readarray` for line-delimited data, or restricted parsing for security) should document the deviation. Similarly, scripts may adjust the search path order (e.g., adding `/etc/default/name`) provided the help text documents the actual paths used.

---

# Section 02: Variables & Data Types

## BCS0200 Section Overview

**Variables should carry explicit type declarations (`declare`/`local` with `-i`/`-a`/`-A`/`--`).** This section covers declaration patterns, scoping, naming conventions, arrays, parameter expansion, and boolean flags.

## BCS0201 Type-Specific Declarations

**Tier:** style

Use explicit type declarations to make variable intent clear.

```bash
# correct
declare -i count=0           # integer
declare -- filename=''       # string (semantic; see note)
declare -a files=()          # indexed array
declare -A config=()         # associative array
declare -r VERSION=1.0.0     # readonly constant string
local -- path=$1             # local string
local -i retval=0            # local integer

# wrong — no type, no separator
count=0
local filename=$1

# not this rule — no declaration at all inside a function: cite BCS0202
process_file() { filename=$1; }
```

This rule governs the *type* of a declaration that exists. A function variable
with no `local` at all is **BCS0202's** finding, not this rule's: cite BCS0202
for the missing `local`, BCS0201 for the missing type separator, never both for
one variable.

The `--` separator for string variable types is **purely semantic** -- it signals a conscious variable type choice, completing the pattern alongside `-i`, `-a`, and `-A`.

## BCS0202 Variable Scoping

**Tier:** core

Always declare function-specific variables as `local`.

```bash
# correct
process_file() {
  local -- filename=$1
  local -i line_count=0
  # filename and line_count are scoped to this function
}

# wrong — pollutes global namespace
process_file() {
  filename=$1
  line_count=0
}

# wrong — loop and `read` variables are function variables too
collect() {
  local -- file=$1
  for item in a b c; do echo "$item"; done   # item: no declaration
  while IFS= read -r line; do                # line: no declaration
    echo "$line"
  done < "$file"
}

# correct — declare them with the rest
collect() {
  local -- file=$1 item line
  for item in a b c; do echo "$item"; done
  while IFS= read -r line; do echo "$line"; done < "$file"
}
```

This rule owns a function variable with **no declaration at all** -- a bare
assignment, or an undeclared `for`/`read` variable. Whether a declaration that
does exist carries its type separator is BCS0201's question; cite BCS0202 here.

Without `local`, variables become global, overwrite same-named variables, persist after function return, and break recursive calls.

## BCS0203 Naming Conventions

**Tier:** style

Constants and globals: UPPER_CASE. Locals and function names: lower_case with underscores. Private functions: leading underscore.

```bash
# correct
readonly MAX_RETRIES=3                # UPPER_CASE for constants/globals
declare -i VERBOSE=1                  # UPPER_CASE for global state

process_log_file() {                  # lower_case for functions
  local -- file_count=0               # lower_case for locals
}

_validate_input() { :; }              # underscore prefix for private functions

# wrong
processLogFile() { :; }               # camelCase
my-function() { :; }                  # dashes in names
declare -i verbose=1                  # lowercase for global
```

Avoid single-letter names, and never reuse special shell variable names such as `PATH`, `HOME`, `USER`, `IFS`.

## BCS0204 Constants and Environment Variables

**Tier:** recommended

Use `readonly` for values that never change. Use `declare -x` for variables needed by child processes.

```bash
# correct
readonly CONFIG_DIR=/etc/myapp
declare -x DATABASE_URL='postgres://localhost/mydb'
declare -rx BUILD_ENV=production     # readonly + exported

# wrong — exporting constants children don't need
export VERSION=1.0.0                 # children rarely need VERSION
```

Don't make user-configurable variables readonly prematurely (timing: see BCS0205).

## BCS0205 Readonly Patterns

**Tier:** recommended

For script metadata, use `declare -r` for immediate readonly:

```bash
declare -r VERSION=1.0.0
#shellcheck disable=SC2155  # accepted: declare masks realpath's exit status (BCS0103)
declare -r SCRIPT_PATH=$(realpath -- "$0")
```

For other variable groups, declare first, then make readonly in a batch:

```bash
# correct — declare, then batch readonly
declare -- PREFIX=/usr/local
declare -- BIN_DIR="$PREFIX"/bin
declare -- SHARE_DIR="$PREFIX"/share/myapp
readonly PREFIX BIN_DIR SHARE_DIR

# wrong — readonly before parsing complete
readonly VERBOSE=1    # can't change during arg parsing
```

Three-step workflow: (1) declare with defaults, (2) parse/modify/derive in main, (3) readonly only after all parsing and derivation is complete.

## BCS0206 Arrays

**Tier:** core

```bash
# correct
declare -a files=()
files+=("$1")                        # append
files+=("$arg1" "$arg2")             # append multiple
echo "${#files[@]}"                  # length

readarray -t lines < <(command)      # populate from command
mapfile -t data < "$file"            # populate from file

local -a cmd=(myapp --config "$file")
"${cmd[@]}"                          # execute safely

# wrong
array=($string)                      # word splitting creates array
for item in ${items[@]}; do          # unquoted expansion
files=file.txt                       # scalar to an array: replaces files[0], keeps the rest
```

Always quote array expansions: `"${array[@]}"`. Never use `${array[*]}` in iteration. Use `readarray -t` or `mapfile -t` instead of word-split assignment. Never assign a scalar to an array variable: `files=x` replaces element 0 and leaves the others in place; write `files=(x)` to replace the array, `files+=(x)` to append.

## BCS0207 Parameter Expansion

**Tier:** style

Use `"$var"` as the default form. Use braces only when syntactically necessary.

```bash
# correct — no braces needed
echo "$HOME"/bin
echo "$PREFIX/bin"
local -- name=$1

# correct — braces required
echo "${var##*/}"                    # parameter expansion
echo "${var:-default}"               # default value
echo "${array[@]}"                   # array access
echo "${10}"                         # positional > 9
echo "${file}_backup"                # literal name-chars follow the name

# optional — braces for readability only
echo "${var1}${var2}"                # adjacent variables; "$var1$var2" parses identically

# wrong — unnecessary braces
echo "${HOME}/bin"
echo "${PREFIX}/bin"
```

Common expansions: `${var:-default}` (default), `${var##*/}` (basename), `${var%/*}` (dirname), `${var//old/new}` (replace all), `${var^^}` (uppercase), `${var,,}` (lowercase).

## BCS0208 Boolean Flags

**Tier:** recommended

Use integer variables for boolean flags.

```bash
# correct
declare -i DRY_RUN=0
declare -i VERBOSE=1

((DRY_RUN)) && info 'Dry-run mode' ||:
((VERBOSE)) || return 0

# wrong
DRY_RUN=false                        # string boolean
if [[ "$DRY_RUN" == "true" ]]; then  # string comparison
```

Initialize to `0` (false) or `1` (true). Test with `((FLAG))` — non-zero is true, zero is false.

## BCS0209 Derived Variables

**Tier:** recommended

Derive paths from base variables to implement DRY.

```bash
# correct
declare -- PREFIX=/usr/local
declare -- BIN_DIR="$PREFIX"/bin
declare -- SHARE_DIR="$PREFIX"/share/myapp

# wrong — hardcoded, not derived
declare -- BIN_DIR=/usr/local/bin
declare -- SHARE_DIR=/usr/local/share/myapp

# correct — the base can change during parsing: derive once it is final
derive_paths() { BIN_DIR="$PREFIX"/bin; SHARE_DIR="$PREFIX"/share/myapp; }
# ... parse --prefix, then:
derive_paths
readonly PREFIX BIN_DIR SHARE_DIR
```

A derived variable is only as current as its base. When an option can change the base after derivation (`--prefix` replaces `PREFIX`), derive after parsing, or re-derive in one place once parsing is complete; a `BIN_DIR` computed at file scope from a `PREFIX` that `--prefix` later replaces is stale.

Readonly timing for derived variables: see BCS0205. Document hardcoded exceptions with comments.

## BCS0210 Nameref Indirection

**Tier:** recommended

Use `local -n` namerefs for eval-free indirection — pass variables or arrays by reference instead of building code with `eval` (see BCS1004).

```bash
# correct — nameref aliases the caller's variable (eval-free indirection)
set_to() {
  local -n ref=$1
  ref=$2
}
declare -- result=''
set_to result 'done'           # result is now 'done'

# correct — nameref lets a function grow the caller's array
append_item() {
  local -n arr=$1; shift
  arr+=("$@")
}
declare -a queue=()
append_item queue alpha beta   # queue is now (alpha beta)

# correct — nameref-backed dispatch table (no eval, no indirect ${!var})
run_action() {
  local -n table=$1
  "${table[$2]}"
}

# wrong — eval to assign through a variable name: quoting hell + injection risk
eval "$1=\$2"
```

Name the nameref distinctly from any caller variable; a nameref that resolves to its own name is a fatal circular reference. Namerefs require Bash 4.3+ (BCS targets 5.2).

---

# Section 03: Strings & Quoting

## BCS0300 Section Overview

Single quotes signal "literal text"; double quotes signal "shell processing needed." This semantic distinction clarifies intent for both developers and AI assistants.

## BCS0301 Quoting Fundamentals

**Tier:** style

Use single quotes for static strings. Use double quotes only when variable expansion is needed.

```bash
# correct
info 'Checking prerequisites...'
info "Processing $count files"
die 1 "Unknown option ${1@Q}"
EMAIL='user@domain.com'
VAR=''

# wrong — double quotes for static string
info "Checking prerequisites..."
EMAIL="user@domain.com"
VAR=""
```

One-word alphanumeric literals (`a-zA-Z0-9_-./`) may be unquoted: `STATUS=success`, `[[ $level == INFO ]]`. When in doubt, quote everything.

Quote variable portions separately from literal path components: write `"$PREFIX"/bin`. The combined form `"$PREFIX/bin"` is compliant and MUST NOT be flagged.

```bash
# preferred — clear boundaries
"$PREFIX"/bin
"$SCRIPT_DIR"/data/"$filename"

# compliant — do not flag
"$PREFIX/bin"
"$SCRIPT_DIR/data/$filename"
```

## BCS0302 Command Substitution

**Tier:** core

Write command substitution as `$(...)`, never with backticks. Use double quotes when strings include command substitution.

```bash
# correct
echo "Current time: $(printf '%(%T)T')"
result=$(git describe --tags)        # simple assignment, quotes optional
VERSION="$(git describe)".beta       # quotes optional in assignments, even with concatenation
echo "$result"                       # always quote when using

# correct — $(...) nests without escaping
owner=$(stat -c %U -- "$(realpath -- "$file")")

# wrong
echo Time: $(date)                   # unquoted substitution word-splits and globs
echo $result                         # unquoted use of substitution result

# wrong — backticks
now=`date +%s`
owner=`stat -c %U -- "\`realpath -- "$file"\`"`   # nesting needs escaped backticks
```

**Backticks are forbidden.** The backtick form is legacy syntax: it cannot nest without backslash-escaping the inner backticks, it treats backslashes differently from `$(...)`, and it is easily misread as a single quote. Every backtick command substitution is a finding under this rule, quoted or not. A `#shellcheck disable=SC2006` directive does not excuse it; only `#bcscheck disable=BCS0302` does. A literal backtick that is not a command substitution -- inside single quotes, a quoted heredoc, or a comment -- is not a finding.

This rule owns backtick substitution, and unquoted use of command substitutions and their results, at core severity. BCS0307 lists the unquoted pattern only as a catch-all summary and does not own the finding; BCS1205 (builtins over external commands) does not own backticks.

## BCS0303 Quoting in Conditionals

**Tier:** core

Inside `[[ ]]`, **no word splitting or pathname expansion occurs** — variables are safe unquoted in any position. Quoting only matters for the right-hand side of `==`/`!=` (where it controls pattern vs literal matching) and `=~` (where it disables regex).

```bash
# correct — all unquoted forms are safe inside [[ ]]
[[ -f $file ]]
[[ -d $dir && -r $dir ]]
[[ $name == "$expected" ]]           # quoted RHS: literal comparison
[[ $mode == production ]]            # static value, quotes optional

# correct — glob matching (right side unquoted)
[[ $filename == *.txt ]]

# correct — regex (right side unquoted)
[[ $email =~ ^[a-z]+@[a-z]+$ ]]

# wrong
[ -f $file ]                         # **never** use [ ]; it requires quoting (cite BCS0901: a file test)
[[ $input =~ "$pattern" ]]           # quoted regex disables matching
```

This rule owns the quoted-regex finding: a quoted right-hand side of `=~` is a quoting defect, cited as BCS0303. BCS0507 repeats the advice while describing `BASH_REMATCH` extraction and does not own the finding.

## BCS0304 Here Documents

**Tier:** recommended

Use quoted delimiter `<<'EOF'` for literal content. Use unquoted delimiter `<<EOF` for variable expansion. The delimiter should name the content (`VARS`, `SQL`, `USAGE`), not be a generic `EOF`/`EOT`.

This is the canonical code for here-document delimiter-quoting findings; BCS0904 covers heredocs in file-operation contexts and defers delimiter semantics here.

```bash
# correct — no expansion needed
cat <<'VARS'
Variables like $HOME are literal text.
VARS

# correct — expansion needed
cat <<GREETING
Hello $USER, your home is $HOME
GREETING

# correct — indented (strips leading tabs, not spaces)
if true; then
	cat <<-CONTENT
	indented content
	CONTENT
fi
```

Quote the delimiter for JSON, SQL, or any content where `$`, backticks, or backslashes must remain literal — the criterion is intended expansion, not mere presence of `$`.

## BCS0305 Printf Patterns

**Tier:** recommended

Use single quotes for format strings, double quotes for variable arguments.

```bash
# correct
printf '%s: %d files\n' "$name" "$count"
printf 'Line1\nLine2\n'

# wrong
echo -e "Line1\nLine2"              # inconsistent escape handling
```

Use `$'...'` syntax as an alternative for escape sequences: `echo $'Line1\nLine2'`.

### Exception: per-iteration constant prefix in reused format strings

`printf` reuses the format string once per cycle of consumed conversion specs. When a *constant* prefix (e.g. the script name) is meant to appear on every emitted line, it must be embedded in the format string — moving it to a `%s` positional argument breaks the iteration because the prefix would consume one slot per cycle, misaligning subsequent arguments.

```bash
# correct — $SCRIPT_NAME is a per-line constant; it MUST live in the format
die() {
  (($# < 2)) || >&2 printf "$SCRIPT_NAME: ✗ %s\n" "${@:2}"
  exit "${1:-0}"
}

# wrong — naive "fix" that breaks multi-arg output
die() {
  (($# < 2)) || >&2 printf '%s: ✗ %s\n' "$SCRIPT_NAME" "${@:2}"
  exit "${1:-0}"
}
# With ${@:2} = (msg1 msg2):
#   first cycle:  "$SCRIPT_NAME: ✗ msg1"
#   second cycle: "msg2: ✗ "          ← prefix lost, args shift
```

Do **not** flag `"$VAR: ... %s ..."` formats when:

1. The format is consumed multiple times (more positional args than `%`-specs in one cycle), AND
2. The embedded variable is a per-line constant the caller expects on every line.

This pattern is canonical for `die()`, `warn()`, `info()`, and similar diagnostic helpers across BCS-compliant scripts.

## BCS0306 Parameter Quoting with @Q

**Tier:** recommended

Use `${parameter@Q}` to safely display user input in error messages.

```bash
# correct
die 22 "Invalid option ${1@Q}"
error "File not found ${file@Q}"
info "[DRY-RUN] Would execute ${cmd@Q}"

# wrong — no safe quoting for display
die 22 "Invalid option $1"          # special chars break output
die 2 "Invalid argument '$1'"       # special chars break output
```

Never use `@Q` for normal variable expansion or comparisons.

## BCS0307 Anti-Patterns

**Tier:** recommended

Catch-all summary of quoting anti-patterns. Where an example below duplicates a more specific rule, report the violation under the owning code, not BCS0307.

```bash
# wrong — double quotes for static strings (owned by BCS0301)
info "Starting backup..."           # use single quotes
echo "${HOME}/bin"                  # unnecessary braces (owned by BCS0207)

# wrong — unquoted expansions (core: BCS0302 scalars, BCS0206 arrays)
echo $result
rm $temp_file
for item in ${items[@]}

# correct
info 'Starting backup...'
echo "$HOME"/bin
echo "$result"
rm -- "$temp_file"
for item in "${items[@]}"
```

The unquoted-expansion anti-patterns above (`rm $temp_file`, `for item in ${items[@]}`, `echo $result`) are genuine correctness bugs enforced at **core** severity under BCS0206 (array expansions) and BCS0302 (scalar and command-substitution results) — the [ERROR] belongs to those codes. BCS0307 itself remains a recommended-tier catch-all list and emits findings only for patterns with no more specific home.

Use braces only when required: `${var:-default}`, `${file##*/}`, `${array[@]}`, `${var1}${var2}`.

---

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

require_bash() {
  bash_at_least "$@" && return 0
  local -- want="${1:-0}.${2:-0}.${3:-0}"
  local -- have="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}.${BASH_VERSINFO[2]}"
  die 2 "requires Bash >= ${want@Q} (have ${have@Q})"
  # OR:
  # printf '%s: requires Bash >= %s (have %s)\n' "${FUNCNAME[0]}" "$want" "$have" >&2
  # exit 2
}
```

```bash
# wrong — compound && fails for newer major with lower minor
((BASH_VERSINFO[0] >= 5 && BASH_VERSINFO[1] >= 2)) || die 1 'Requires Bash 5.2+'
# On Bash 6.0: major=6>=5 (true) && minor=0>=2 (false) → dies, though 6.0 > 5.2

# wrong — string compare on BASH_VERSION is lexicographic
[[ $BASH_VERSION > "5.2" ]]   # "5.10" < "5.2" under string compare
```

A finding under this rule requires a version check to exist in the script. Violations: a compound `&&` comparison of `BASH_VERSINFO` components; a string comparison of `BASH_VERSION`; a guard placed after `shopt -s inherit_errexit` or other version-dependent code. Not a violation: having no guard.

`BASH_VERSINFO` indices: `[0]`=major, `[1]`=minor, `[2]`=patch, `[3]`=build, `[4]`=release status, `[5]`=machine type. Always compare integers per element; never compare `BASH_VERSION` as a string.

When a script has a guard, call `require_bash` at script start, after `set -euo pipefail` (safe on any Bash) but before `shopt -s inherit_errexit` and any other version-dependent code:

```bash
#!/usr/bin/bash
set -euo pipefail
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
# global so the single-quoted trap (BCS0603) can expand it at EXIT time
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
while read -r -u 3 line; do
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

---

# Section 05: Control Flow

## BCS0500 Section Overview

Use `[[ ]]` for string and file tests, `(())` for arithmetic. Never use `[ ]`. This section covers conditionals, case statements, loops, arithmetic, and floating-point operations.

## BCS0501 Conditionals

**Tier:** core

```bash
# correct — [[ ]] for strings/files, (()) for arithmetic
[[ -f $file ]]
[[ $name == "$expected" ]]
((count > 5))

# correct — arithmetic truthiness
((count))                            # true if non-zero
((VERBOSE)) || return 0

# correct — pattern matching
[[ $file == *.txt ]]                 # glob
[[ $input =~ ^[0-9]+$ ]]             # regex

# correct — short-circuit
[[ -f $file ]] && source -- "$file"
command -v curl >/dev/null || die 18 'curl required'

# wrong
[ "$name" = "$expected" ]            # never use [ ]
[ "$count" -gt 5 ]                   # never use [ ]; arithmetic belongs in (())

# style preference — prefer ((count)); see BCS0505. Not errors under this rule.
((count > 0))                        # prefer ((count))
((VERBOSE == 1))                     # prefer ((VERBOSE))
```

This is the canonical code for a `[ ]` or `test` conditional on strings or numbers. When what is tested is a file (`-f`, `-d`, `-r`, `-s`, `-nt`, ...), cite BCS0901 instead, in either spelling. BCS0303 and BCS1205 show `[ ]` only as an anti-pattern and own no `[ ]` finding.

## BCS0502 Case Statements

**Tier:** recommended

Use `case` for multi-way branching on a single variable.

```bash
# correct — no quotes on case expression or literal patterns
case ${1:-} in
  start)          start_service ;;
  stop)           stop_service ;;
  help|-h|--help) show_help ;;
  *.txt|*.md)     process_text "$1" ;;
  -*)             die 22 "Invalid option ${1@Q}" ;;
  *)              die 2 "Unknown command ${1@Q}" ;;
esac

# wrong
case "${1:-}" in                     # unnecessary quotes on expression
  "start")                           # unnecessary quotes on pattern
```

Always include default case `*)`  to handle unexpected values. Align actions consistently for readability. Enable `extglob` for advanced patterns: `@(start|stop)`, `!(*.tmp)`, `+([0-9])`.

## BCS0503 Loops

**Tier:** core

```bash
# correct — for with arrays and globs
for file in "${files[@]}"; do
  process "$file"
done
for f in ./*.txt; do
  echo "$f"
done

# correct — while for argument parsing
while (($#)); do case $1 in
  -v|--verbose) VERBOSE=1 ;;
esac; shift; done

# correct — while for reading input
while IFS= read -r line; do
  process "$line"
done < "$input_file"

# correct — C-style loop
for ((i=0; i<10; i+=1)); do
  echo "$i"
done

# wrong
for f in $(ls *.txt); do             # never parse ls
for ((i=0; i<10; i++)); do           # use i+=1 — increment policy: see BCS0505
while (($# > 0)); do                 # use (($#)) instead
while read line; do                  # IFS= read -r: -r keeps backslashes, IFS= keeps blanks
for f in *.log; do process "$f"; done   # without nullglob, processes the literal '*.log'
```

Read lines with `IFS= read -r`: without `-r` backslashes are mangled, without `IFS=` leading and trailing whitespace is stripped.

A loop over a glob must handle the no-match case: enable `nullglob` (or `failglob`) in the script's `shopt` line, or test the first match with `[[ -e $f ]]`; otherwise the unmatched pattern itself is processed as a filename.

Declare local variables before loops, not inside:

```bash
# correct
local -- file
for file in ./*.txt; do process "$file"; done

# wrong
for file in ./*.txt; do local -- file; done
```

Use `while ((1))` for infinite loops — it is pure arithmetic evaluation with no command lookup or dispatch, making it the fastest construct (~14% faster than `while :`, ~21% faster than `while true` at 1M iterations).

```bash
# correct — arithmetic evaluation, fastest
while ((1)); do
  process_item || break
done

# acceptable — special builtin, POSIX-compatible
while :; do
  process_item || break
done

# acceptable — regular builtin, widely used
while true; do
  process_item || break
done

# wrong — unquoted variable expansion as command (fragile, dangerous)
running=true
while $running; do
  running=false
done

# wrong — unnecessary string comparison on constants
while [[ 1 == 1 ]]; do
  break
done
```

The flag-variable pattern (`while $running`) executes the variable content as a command — if it contains anything other than `true` or `false`, arbitrary code runs. Use arithmetic flags instead:

```bash
# correct — arithmetic flag, safe
local -i running=1
while ((running)); do
  # ...
  running=0
done
```

Use `break N` for nested loops (`break 2` exits two enclosing levels).

See also: [While Loops Reference](../benchmarks/while-loops_reference.md) — full benchmark data and analysis of `while ((1))` vs `while :` vs `while true`.

## BCS0504 Process Substitution

**Tier:** core

Never pipe to while loops — pipes create subshells where variable modifications are lost. This is the canonical code for the pipe-to-while anti-pattern; BCS0903 covers process substitution in file-operation contexts.

```bash
# correct — process substitution preserves variables
declare -i count=0
while IFS= read -r line; do
  count+=1
done < <(grep -- '' "$file")

# correct — readarray for collecting lines
readarray -t lines < <(find . -name '*.txt')

# correct — null-delimited for special filenames
while IFS= read -r -d '' file; do
  process "$file"
done < <(find /data -type f -print0)

# wrong — subshell loses count
grep -- '' "$file" | while read -r line; do
  count+=1
done
# count is still 0 here!
```

This rule owns the **lost state**: a pipe into a loop whose body sets a
variable the caller needs. BCS0411 catalogues the four patterns for returning
data from a subshell and BCS0906 the `find`-specific pitfalls; both defer here,
so cite BCS0504 for the defect itself.

Use here-string `<<< "$var"` when input is already in a variable.

## BCS0505 Arithmetic Operations

**Tier:** style

Always declare integer variables with `declare -i` or `local -i` before arithmetic.

```bash
# correct
declare -i count=0
count+=1                             # increment

# correct — arithmetic conditional
((count > 10)) && warn 'High count'  # no $ needed inside (())

# correct — assignment via arithmetic expansion never affects exit status
result=$((x + y))

# wrong — NEVER use any form of ++
((count++))
((++count))
count++
((count+=1))                         # use plain count+=1
```

Use `i+=1` for ALL increments. A bare `((count++))` with count=0 evaluates to 0, returns status 1, and kills a `set -e` script — BCS0606 (core) owns that correctness hazard. Integer division truncates: `((10 / 3))` equals 3.

## BCS0506 Floating-Point Operations

**Tier:** recommended

Bash only supports integer arithmetic. Use `bc -l` or `awk` for floating-point.

```bash
# correct
result=$(echo 'scale=2; 10 / 3' | bc -l)
result=$(awk -v a="$a" -v b="$b" 'BEGIN {printf "%.2f", a * b}')

# correct — float comparison
if (($(echo "$a > $b" | bc -l))); then
  echo 'a is greater'
fi

# wrong
[[ "$a" > "$b" ]]                    # string comparison, not numeric
```

## BCS0507 Regex Captures with BASH_REMATCH

**Tier:** recommended

Extract substrings with the `[[ $s =~ re ]]` operator and the `BASH_REMATCH` array instead of shelling out to `grep`/`sed` for simple parsing.

```bash
# correct — capture groups land in BASH_REMATCH; [0] is the whole match
declare -- date='2026-05-29'
if [[ $date =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})$ ]]; then
  declare -- year=${BASH_REMATCH[1]} month=${BASH_REMATCH[2]} day=${BASH_REMATCH[3]}
fi

# correct — copy captures out immediately; the next match overwrites BASH_REMATCH
declare -- ver=''
[[ $line =~ v([0-9]+\.[0-9]+) ]] && ver=${BASH_REMATCH[1]}

# wrong — quoting the pattern forces a literal match (no regex, no captures)
[[ $date =~ "^([0-9]{4})" ]]          # matches literal text; BASH_REMATCH empty

# wrong — external tool for a job the shell does in-process
year=$(echo "$date" | grep -oE '^[0-9]{4}')
month=$(echo "$date" | cut -d- -f2)              # ${date:5:2} does it
day=$(printf '%s' "$date" | sed -n 's/.*-//p')   # ${date##*-} does it
```

This rule owns **parsing a shell variable with an external tool** where
`[[ =~ ]]` and `BASH_REMATCH`, or a parameter expansion, would do it in
process: `grep -oE`, `cut -d`, `sed -n 's/../\1/p'`, `awk '{print $2}'`.
BCS1205 states the same preference for builtins generally and defers here: cite
BCS0507 for a parse, not both.

Keep the regex unquoted — quoting any part forces a literal match (cite BCS0303, which owns that finding). For complex patterns, assign to a variable and reference it unquoted: `[[ $s =~ $re ]]`. `BASH_REMATCH` is global and is overwritten by every successful `[[ =~ ]]`, so copy out captures before the next match. Character classes such as `[[:alpha:]]` are locale-sensitive.

---

# Section 06: Error Handling

## BCS0600 Section Overview

Error handling covers strict mode, exit codes, traps, return value checking, and error suppression patterns. Every script must fail safely and provide clear error context.

## BCS0601 Exit on Error

**Tier:** core

Scripts run under `set -euo pipefail` (BCS0101). Handle expected failures explicitly — `||:`, an `if` guard, or `|| die` — never by disabling strict mode with `set +e`.

`set -euo pipefail` provides three protections: `-e` exits on command failure, `-u` exits on undefined variables, `-o pipefail` fails pipeline if any command fails.

```bash
# correct — allow expected failures
command_that_might_fail ||:
if command_that_might_fail; then
  process_result
fi

# correct — handle undefined optional variables
val="${OPTIONAL_VAR:-default}"
echo "${OPTIONAL_VAR:-}"

# correct — capture failing command safely
if result=$(failing_command); then
  echo "$result"
fi
output=$(cmd) || die 1 'cmd failed'

# wrong
set +e                               # never disable broadly
command
set -e
```

## BCS0602 Exit Codes

**Tier:** recommended

**Scope.** This rule governs which exit code a script reports and that a failing exit says why. It does not decide whether a script defines `die()`: BCS0703 owns that. Where `die()` is defined it is the standard exit function: a failing exit below the definition that hand-rolls `echo ...; exit N` instead is a finding. Code that has no `die()` to call -- a short script that defines none, a wrapper, a version guard that runs above the definition (BCS0409) -- may report to stderr and `exit N` directly; that is **not** a finding.

```bash
die() { (($# < 2)) || error "${@:2}"; exit "${1:-0}"; }

# correct — die() is defined, so every failing exit goes through it
[[ -f $config ]] || die 3 "Config not found ${config@Q}"

# correct — no die() in this script: message to stderr, then a code from the table
((${#FIELDS[@]})) || { >&2 echo 'No fields given'; exit 2; }

# wrong — die() is defined above and bypassed
[[ -f $config ]] || { >&2 echo "Config not found ${config@Q}"; exit 3; }
```

Standard exit codes:

| Code | Use Case |
|------|----------|
| 0 | Success |
| 1 | General error |
| 2 | Usage / argument error |
| 3 | File/directory not found |
| 5 | I/O error |
| 8 | Required argument missing |
| 13 | Permission denied |
| 18 | Missing dependency |
| 19 | Configuration error |
| 22 | Invalid argument |
| 24 | Timeout |

Where the table names the failure exactly -- a missing file (3), a missing dependency (18), an invalid option or value (22) -- use that code, not 1. Anything else is a general error: whether a failed `mktemp` or `stat` counts as an "I/O error" is a judgement call, and choosing 1 there is **not** a finding.

When the failure concerns a particular value -- a path, an option, a setting -- the message names it. A failure with no such value needs no invented context.

```bash
# correct — the message names the value at fault
die 3 "Config not found ${config@Q}"
die 22 "Invalid option ${1@Q}"

# correct — there is no value to name
die 2 'No input files specified'
die 18 'curl required'

# wrong — a path was at fault and the message hides it
die 3 'File not found'

# correct — 1 for a failure the table does not name exactly
temp_dir=$(mktemp -d) || die 1 'Failed to create temp dir'
size=$(stat -c '%s' -- "$path") || die 1 "Cannot stat ${path@Q}"

# wrong — the table names this failure exactly: a missing file is 3
die 1 "Config not found ${config@Q}"
```

Reserved: 64-78 (sysexits), 126 (cannot execute), 127 (not found), 128+n (signals).

## BCS0603 Trap Handling

**Tier:** core

Install cleanup traps early, before creating any resources.

This is the canonical rule for the trap/cleanup pattern (quoting, signal lists, recursion guard) — cite BCS0603 for trap-content violations. BCS0110 owns the structural-placement requirement (trap installed before resource-creating code).

```bash
# correct
declare -- TEMP_FILE
#...
cleanup() {
  local -i exitcode=${1:-$?}
  trap - SIGINT SIGTERM EXIT         # prevent recursion
  [[ -z ${TEMP_FILE:-} ]] || rm -f -- "$TEMP_FILE"
  exit "$exitcode"
}
trap 'cleanup $?' SIGINT SIGTERM EXIT
#...
TEMP_FILE=$(mktemp) || die 1 'Failed to create temp file'
readonly TEMP_FILE
```

Use single quotes for trap commands to delay variable expansion. Use `||:` for cleanup operations that might fail.

```bash
# correct — single quotes delay expansion
trap 'rm -f -- "$temp_file"' EXIT

# correct — kill background processes in cleanup
((bg_pid)) && kill "$bg_pid" 2>/dev/null ||:

# wrong — double quotes expand immediately
trap "rm -f $temp_file" EXIT

# wrong — exit 0 in the trap reports success for a script that failed
trap 'rm -f -- "$temp_file"; exit 0' EXIT
```

The handler must propagate the script's exit status: pass `$?` in (`trap 'cleanup $?' ...`) and finish with `exit "$exitcode"`, as in the example above. A trap that ends in `exit 0`, or any fixed status, hides the failure from the caller.

Never combine multiple traps for the same signal (replaces previous). Use a single trap with a cleanup function.

## BCS0604 Checking Return Values

**Tier:** core

Always check return values of critical operations. Critical operations are state-changing commands whose failure needs a contextual message or cleanup -- file moves/copies/removals, command substitutions whose output is used later, network calls, and anything followed by dependent steps. For these operations, a bare command relying on `set -e` to abort with no context is a violation.

```bash
# correct
mv -- "$file" "$dest" || die 1 "Failed to move ${file@Q}"
output=$(command) || die 1 'Command failed'

# correct — command group with cleanup on failure
cp -- "$src" "$dst" || {
  rm -f -- "$dst"
  die 1 'Copy failed'
}

# correct — check PIPESTATUS for pipelines (condition context, see pitfalls)
if ! sort -- "$file" | uniq > "$output"; then
  ((PIPESTATUS[0] == 0)) || die 1 'Sort failed'
  die 1 'Pipeline failed'
fi

# correct — check $? immediately
cmd1
local -i result=$?

# wrong — a failure inside <( ) is invisible: diff silently compares against empty input
diff -- <(failing_command) "$file"

# correct — run and check first, then feed the output on
out=$(failing_command) || die 1 'Command failed'
diff -- <(printf '%s\n' "$out") "$file"

# correct — loop feed: an empty stream is an ordinary outcome, nothing to check
while IFS= read -r line; do process "$line"; done < <(grep -- 'pattern' "$file")
```

A command run only inside a process substitution (`<(cmd)`) has no exit status anyone checks: `set -e` and `pipefail` never see it, and the consumer reads empty input. This is a finding where an empty result would be taken for a real one: a `diff`, `cmp` or `comm` against `<(cmd)`, or a result captured for later use. Run such a command first and check it. The prescribed loop feed `while ... done < <(cmd)` (BCS0504, BCS0903), where an empty stream is an ordinary outcome, is not a finding.

**`PIPESTATUS` pitfalls:**

- `PIPESTATUS` is overwritten by the **very next command** -- including `echo`. Snapshot it immediately if you need it across statements: `local -a ps=("${PIPESTATUS[@]}")`.
- Under strict mode a failing pipeline aborts the script before any follow-up `PIPESTATUS` check can run. Inspect `PIPESTATUS` from a condition context (`if ! pipeline; then ...`), where it survives into the body. Appending `||:` does NOT work -- the `:` itself overwrites `PIPESTATUS`.
- Under `set -o pipefail` (part of BCS0101 strict mode), `$?` already reflects the rightmost non-zero exit. Inspect `PIPESTATUS` only when you need to distinguish *which* stage failed.
- `((PIPESTATUS[0]))` only tells you about the first command. For a multi-stage pipeline, iterate over a snapshot:

```bash
# correct — snapshot, then inspect each stage
if ! sort -- "$file" | uniq | wc -l > "$output"; then
  local -a ps=("${PIPESTATUS[@]}")
  for i in "${!ps[@]}"; do
    ((ps[i] == 0)) || error "Stage $i failed (exit ${ps[i]})"
  done
  die 1 'Pipeline failed'
fi

# wrong — echo clobbers PIPESTATUS before we read it
if ! sort -- "$file" | uniq | wc -l > "$output"; then
  echo 'Pipeline failed'
  ((PIPESTATUS[0] == 0)) || die 1 'Sort failed'   # PIPESTATUS is now echo's
fi
```

## BCS0605 Error Suppression

**Tier:** recommended

Only suppress errors when failure is expected, non-critical, and explicitly safe to ignore. A suppression is a decision: the comment beside or above it must say why the failure is safe to ignore.

```bash
# correct — safe to suppress, and the comment says why
command -v optional_tool &>/dev/null ||:   # optional: the builtin path is used instead
rm -f /tmp/optional_*                      # -f: nothing to remove is the normal case
rmdir -- "$maybe_empty" 2>/dev/null ||:    # still populated means another job owns it

# correct — suppress message but check return
if result=$(command 2>/dev/null); then
  process "$result"
fi

# wrong — suppressing critical operations
cp -- "$src" "$dst" 2>/dev/null || true
set +e                               # never disable broadly

# wrong — unexplained suppression
some_command 2>/dev/null || true

# wrong — a whole function silenced: every error in it is lost, not only the expected one
process_files() {
  cp -- "$src" "$dst"
  rmdir -- "$maybe_empty"
} 2>/dev/null
```

Suppress at the single command whose failure is expected, never on a whole function or compound command (`} 2>/dev/null`, `done 2>/dev/null`).

Verify system state after suppressed operations when possible.

## BCS0606 Conditional Declarations

**Tier:** core

Under `set -e`, a false arithmetic condition (e.g., `((DRY_RUN))` when `DRY_RUN=0`) returns exit code 1 and terminates the script. Any `&&` chain built on an arithmetic condition MUST end with `||:` to suppress this, unless the chain is expressed in inverted form with `||`.

**Mandatory (correctness):** the `&&`-chain form requires `||:`:

```bash
# correct — flag-guarded action, safely wrapped
((DRY_RUN)) && info 'Dry-run mode' ||:
((VERBOSE)) && echo "Processing $file" ||:
((DEBUG)) && set -x ||:
((VERBOSE < 3)) && VERBOSE+=1 ||:

# wrong — missing ||:, script exits when flag is 0
((DRY_RUN)) && info 'Dry-run mode'
```

The inverted form avoids the issue because the RHS returns 0:

```bash
# correct — no ||: needed (RHS is an assignment or command returning 0)
((width >= 20)) || width=20
((padding >= 0)) || padding=0
((color_count < 256)) || HAS_COLOR=1
command -v curl >/dev/null || die 18 'curl required'
```

The `||:` catches failure from **the entire chain**, including the arithmetic condition -- not just the final command. Use `:` over `true` (shorter, built-in, traditional shell idiom).

**Style (preference only):** when `||:` is present, both the `&&...||:` form and the inverted `||` form are correct. Pick whichever reads more naturally -- short guard clauses favour inversion; flag-guarded actions often favour `&&...||:`. **Neither form alone is a violation.** LLM-based checkers MUST NOT report a rule violation for form choice when `||:` is properly present.

**Never:** never use `||:` for critical operations that must succeed -- it masks real failures.

---

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

# correct — echo for data and help
echo "$result"                       # data output
echo "$SCRIPT_NAME $VERSION"         # version output
# help text
cat <<HELP
...
HELP

# correct — functions returning data use echo
get_value() {
  echo "$result"                     # stdout for callers to capture
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

# correct — hide cursor during TUI, restore on exit
if [[ -t 1 ]]; then
  printf '\033[?25l'                   # hide cursor
  trap 'printf "\033[?25h"' EXIT       # restore on exit
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
cols=$(tput cols 2>/dev/null || echo 80)

# correct — check Unicode support (guarded; bare [[ ]] would trip errexit)
declare -i UNICODE=0
[[ ${LC_ALL:-${LC_CTYPE:-${LANG:-}}} == *UTF-8* ]] && UNICODE=1 ||:
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

A confirmation must be suppressible, so the script can run unattended: either `yn()` returns success when `PROMPT` is 0 (declared in BCS0701, cleared by `-N`/`--no-prompt`, BCS0806), as above, or every call is guarded by `((PROMPT))`. A guard in either place satisfies this rule; a confirmation that cannot be switched off is a violation.

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

---

# Section 08: Command-Line Arguments

## BCS0800 Section Overview

Use `while (($#)); do case $1 in ... esac; shift; done` as the standard argument parsing pattern. This section covers parsing, standard options, option bundling, validation, and version output.

## BCS0801 Standard Parsing Pattern

**Tier:** core

**Scope.** This rule governs the form of an option-parsing loop where one exists. A script that takes no options has no loop to govern, and a script that answers a single flag may test it directly; in neither case is the absence of the loop a finding. The loop becomes mandatory once a script handles more than one option or any option that takes an argument: chaining `if`/`elif` tests over several options is a finding, because that is the pattern this loop replaces.

```bash
# correct — one flag, tested directly; no parsing loop is needed or expected
main() {
  if [[ ${1:-} == --version ]]; then
    printf '%s %s\n' "$SCRIPT_NAME" "$VERSION"
    return 0
  fi
  process "$@"
}

# correct — more than one option: the standard loop
while (($#)); do case $1 in
  -v|--verbose) VERBOSE=1 ;;
  -q|--quiet)   VERBOSE=0 ;;
  -n|--dry-run) DRY_RUN=1 ;;
  -o|--output)  noarg "$@"; shift; OUTPUT=$1 ;;
  -V|--version) printf '%s %s\n' "$SCRIPT_NAME" "$VERSION"; exit 0 ;;
  -h|--help)    show_help; exit 0 ;;
  --)           shift; FILES+=("$@"); break ;;
  -[vqnoVh]?*)  set -- "${1:0:2}" "-${1:2}" "${@:2}"; continue ;;
  -*)           die 22 "Invalid option ${1@Q}" ;;
  *)            FILES+=("$1") ;;
esac; shift; done

# wrong — missing the trailing shift: $1 is never consumed, infinite loop
while (($#)); do case $1 in
  -v|--verbose) VERBOSE=1 ;;
  -*)           die 22 "Invalid option ${1@Q}" ;;
  *)            FILES+=("$1") ;;
esac; done

# wrong — several options handled by an if/elif chain instead of the loop
if [[ $1 == -v || $1 == --verbose ]]; then
  VERBOSE=1
elif [[ $1 == -o || $1 == --output ]]; then
  OUTPUT=$2
fi
```

Key rules:
- Use `(($#))` as the loop condition, not `[[ $# -gt 0 ]]` (house style; functionally equivalent)
- The mandatory `shift` at loop end is critical — omitting it causes infinite loops
- For options with arguments: `noarg "$@"; shift; variable=$1`
- For boolean flags: just set, no extra shift needed
- For exit options (`--help`, `--version`): use `exit 0`, no shift needed
- Use `continue` after option disaggregation to re-process expanded options

See also: [Argument Processing Reference](../benchmarks/args-processing_reference.md) — comparison of BCS while/case, getopts, GNU getopt, and simple while/case with benchmark data.

## BCS0802 Version Output

**Tier:** style

Format: `scriptname X.Y.Z` without the word "version".

```bash
# correct
echo "$SCRIPT_NAME $VERSION"
# output: myscript 1.0.0

# wrong
echo "$SCRIPT_NAME version $VERSION"
echo "Version: $VERSION"
```

## BCS0803 Argument Validation

**Tier:** core

Validate option arguments exist before capturing them.

```bash
# correct — noarg checks $2 exists
noarg() { (($# > 1)) || die 22 "Option ${1@Q} requires an argument"; }

# usage
-o|--output) noarg "$@"; shift; OUTPUT=$1 ;;

# wrong — no validation
-o|--output) shift; OUTPUT=$1 ;;     # --output as the last word: $1 is unbound, set -u aborts
```

Always call validators BEFORE `shift` — they must inspect `$2`. `noarg` checks that a value follows; it does not reject a value that begins with `-`, because `-` (stdin) and negative numbers are legitimate values. When the option needs a particular form, validate the value itself (BCS1005).

Validate required arguments after parsing:

```bash
((${#FILES[@]})) || die 2 'No input files specified'
[[ $mode =~ ^(normal|fast|safe)$ ]] || die 22 "Invalid mode ${mode@Q}"
```

## BCS0804 Parsing Location

**Tier:** recommended

Place argument parsing inside `main()` for better testability.

```bash
# correct
main() {
  while (($#)); do case $1 in
    # ...
  esac; shift; done
  readonly VERBOSE DRY_RUN OUTPUT

  process_files
}

# acceptable for simple scripts under 200 lines
while (($#)); do case $1 in
  # ...
esac; shift; done
```

Make variables readonly after parsing completes.

## BCS0805 Short Option Bundling

**Tier:** recommended

Support bundled short options like `-vvn` expanding to `-v -v -n`.

```bash
# correct — recommended disaggregation pattern (list valid short options explicitly)
-[vqnoVh]?*) set -- "${1:0:2}" "-${1:2}" "${@:2}"; continue ;;

# correct — alternative: single-pass disaggregation (avoids re-entering the case loop per character;
# see ../benchmarks/args-processing_reference.md); only worth it for very hot argument loops
-[vqnoVh]?*)
  local -- opt=${1:1}
  local -a new_args=()
  while ((${#opt})); do
    new_args+=("-${opt:0:1}")
    opt=${opt:1}
  done
  set -- '' "${new_args[@]}" "${@:2}"
  ;;
```

Place bundling case before `-*)` invalid option handler and after all explicit option cases. List only valid short options in the pattern to prevent incorrect expansion.

Include arg-taking options in the character class. They work correctly when last in the bundle — the disaggregation peels them off as a separate `-X` flag, and `shift` in their case handler picks up the argument normally. Example: `-vno output.txt` disaggregates to `-v -n -o`, then `-o` consumes `output.txt` via `shift`. The user must place arg-taking options last; `-von file` would incorrectly disaggregate to `-v -o -n`.

▲ Attached option-arguments (`-oFILE`) are NOT supported by this pattern — the disaggregator prepends `-` to the remainder, so `-ooutput.txt` becomes `-o -output.txt` and the handler silently captures `-output.txt` (`noarg` cannot catch it). Option arguments must be separate words: `-o FILE`.

## BCS0806 Standard Options

**Tier:** recommended

Use consistent option letters and variable names across all BCS-compliant scripts. Avoid reassigning a standard letter to a different purpose.

**Scope.** This rule is a registry of what each letter means, not a checklist of options a script must offer. A script chooses its own option set, and the absence of any option listed below is **never** a finding: a script that answers only `--version`, offers no `-h`, or provides `-n` without `-N` violates nothing here. The finding is *reassignment* — a listed letter or variable name put to a different purpose (`-v` for version, `-d` for debug, `-n` for anything but dry-run). The groupings below say how strongly each option is recommended to authors; they do not make its absence reportable.

**Strongly Recommended** — for any script with an option-parsing loop (BCS0801):

| Short | Long | Variable | Default | Purpose |
|-------|------|----------|---------|---------|
| `-V` | `--version` | — | — | Print version and exit |
| `-h` | `--help` | — | — | Print help and exit |

**Recommended** — include when the script produces output or performs actions:

| Short | Long | Variable | Default | Purpose |
|-------|------|----------|---------|---------|
| `-v` | `--verbose` | `VERBOSE` | `1` | Enable verbose output |
| `-q` | `--quiet` | `VERBOSE` | `0` | Suppress informational output |

**Optional** — use when the script needs these capabilities:

| Short | Long | Variable | Default | Purpose |
|-------|------|----------|---------|---------|
| `-n` | `--dry-run` | `DRY_RUN` | `0` or `1` | Preview without changes |
| `-N` | `--not-dry-run` | `DRY_RUN` | `0` | Execute changes (cancels dry-run) |
| `-f` | `--force` | `FORCE` | `0` | Skip confirmation prompts |
| `-D` | `--debug` | `DEBUG` | `0` | Enable debug output |
| `-p` | `--port` | `PORT` | varies | Network port |
| `-P` | `--prefix` | `PREFIX` | varies | Installation prefix |

Key rules:
- **Avoid reassigning** a standard letter to a different purpose — `-v` is always verbose, never version
- **Toggle pairs:** `-n`/`-N` and `-v`/`-q` are complementary toggles sharing a variable; a script that offers both halves spells them this way, but offering one half alone is not a finding
- **DRY_RUN=1 default** for destructive scripts — require `-N` to execute; use `DRY_RUN=0` for non-destructive scripts
- **Use `declare -i`** for all flag variables: `declare -i VERBOSE=1 DRY_RUN=0 DEBUG=0 FORCE=0`

```bash
# correct — standard options with consistent letters and variables
declare -i VERBOSE=1 DRY_RUN=0 DEBUG=0 FORCE=0

while (($#)); do case $1 in
  -v|--verbose)     VERBOSE=1 ;;
  -q|--quiet)       VERBOSE=0 ;;
  -n|--dry-run)     DRY_RUN=1 ;;
  -N|--not-dry-run) DRY_RUN=0 ;;
  -f|--force)       FORCE=1 ;;
  -D|--debug)       DEBUG=1 ;;
  -V|--version)     echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
  -h|--help)        show_help; exit 0 ;;
  --)               shift; FILES+=("$@"); break ;;
  -[vqnNfDVh]?*)    set -- "${1:0:2}" "-${1:2}" "${@:2}"; continue ;;
  -*)               die 22 "Invalid option ${1@Q}" ;;
  *)                FILES+=("$1") ;;
esac; shift; done

# wrong — reassigned letters
-d|--debug)         # -d is not standard for debug; use -D
-v|--version)       # -v is verbose, never version; use -V

# not a finding — a small option set; nothing listed is mandatory
-V|--version)       echo "$SCRIPT_NAME $VERSION"; exit 0 ;;   # no -h, -v, -q: fine
```

See also: BCS0701 (message control flags), BCS0802 (version output format), BCS1207 (verbose pattern), BCS1208 (dry-run pattern).

---

# Section 09: File Operations

## BCS0900 Section Overview

Safe file testing, wildcard expansion, process substitution, here documents, and input redirection patterns to prevent common shell scripting pitfalls.

## BCS0901 Safe File Testing

**Tier:** core

Use `[[ ]]` for all file tests. Always include filenames in error messages for debugging.

```bash
# correct
[[ -f $file ]] || die 3 "Not found ${file@Q}"
[[ -f $file && -r $file ]] || die 5 "Cannot read ${file@Q}"
[[ -d $dir ]] || mkdir -p -- "$dir" || die 1 "Cannot create ${dir@Q}"
[[ -s $logfile ]] || warn 'Log file is empty'
[[ $source -nt $destination ]] && cp -- "$source" "$destination" ||:

# wrong
[ -f "$file" ]                       # old test syntax
test -r "$file"                      # same defect, spelled with the test builtin
```

This rule owns every file test not written with `[[ ]]` — `[ -f "$file" ]` and `test -f "$file"` alike. Cite BCS0901 for them, not BCS0501, which owns `[ ]` and `test` on strings and numbers.

## BCS0902 Wildcard Expansion

**Tier:** core

Always use explicit path prefix to prevent filenames starting with `-` from being interpreted as flags.

```bash
# correct
rm -v ./*
for file in ./*.txt; do
  process "$file"
done

# wrong — dangerous
rm -v *                              # file named -rf would be catastrophic
for file in *.txt; do                # less safe
```

## BCS0903 Process Substitution in File Operations

**Tier:** core

Use process substitution (`<(command)`, `>(command)`) for file-operation idioms that would otherwise need temp files or lossy pipes: feeding while loops with `< <(command)`, populating arrays with `readarray`, comparing outputs with `diff <(...) <(...)`, parallel output with `tee >(...)`, and null-delimited filename handling. See BCS0504 for the pipe-to-while prohibition — cite BCS0504, not this rule, for `command | while read` violations. An unchecked failure inside `<( )` where the result is compared or captured is owned by BCS0604 -- cite BCS0604, not this rule; a loop fed by `< <(cmd)` is not a finding under either.

```bash
# correct — variables preserved in current shell
declare -i count=0
while IFS= read -r line; do
  count+=1
done < <(grep -- 'pattern' "$file")

# correct — populate arrays
readarray -t lines < <(find . -name '*.txt')

# correct — compare outputs without temp files
diff <(sort -- "$file1") <(sort -- "$file2")

# correct — null-delimited for special filenames
while IFS= read -r -d '' file; do
  process "$file"
done < <(find /data -type f -print0)

# correct — tee for parallel output
tee >(grep ERROR > errors.txt) >(grep WARN > warnings.txt) < logfile

# wrong — pipe loses variables (cite BCS0504)
command | while read -r line; do count+=1; done
```

## BCS0904 Here Documents

**Tier:** recommended

Quote the here-document delimiter (`<<'NOTES'`) whenever the body must be literal; leave it unquoted only when expansion is intended. An unquoted delimiter over a body containing literal `$` or `` ` `` characters is a violation.

Delimiter quoting semantics are owned by BCS0304 (the canonical code for delimiter-quoting findings, including descriptive delimiter names and `<<-`); this rule covers heredocs in file-operation contexts.

```bash
# correct — no expansion (quoted delimiter)
cat <<'NOTES'
Variables like $HOME are not expanded.
NOTES

# correct — with expansion (unquoted delimiter)
cat <<GREETING
Hello $USER, home is $HOME
GREETING

# wrong — body needs literal $HOME but delimiter is unquoted, so it expands
cat <<MSG
Set your home directory with: export HOME=$HOME
MSG
```

## BCS0905 Input Redirection

**Tier:** style

Use `$(< file)` instead of `$(cat file)` — 107x faster (zero process fork).

```bash
# correct
content=$(< "$file")
grep pattern < "$file"

# wrong — unnecessary cat
content=$(cat -- "$file")
cat -- "$file" | grep pattern
```

Use `cat` only when concatenating multiple files or using cat-specific options (`-n`, `-A`, `-b`).

## BCS0906 find Subshell Pitfalls

**Tier:** recommended

Piping `find` into a loop (`find ... | while read`) creates a subshell -- any variable set in the loop body is invisible to the parent. That lost-state defect is owned at core severity by BCS0504/BCS0903 -- cite those codes for it. This rule covers the find-specific pitfalls and performance guidance: use process substitution when state must escape the loop; use `-exec ... +` or built-in actions when no state is needed.

**Stateful iteration -- process substitution + null-delimited input:**

```bash
# correct — state persists; filenames with spaces/newlines handled safely
declare -i count=0
declare -a paths=()
while IFS= read -r -d '' f; do
  count+=1
  paths+=("$f")
done < <(find . -type f -print0)
info "Found $count files"
```

**Stateless batching -- `-exec ... +`** (one fork for N matches):

```bash
# correct — batches arguments; efficient
find . -name '*.log' -exec gzip {} +
find /tmp -type f -mtime +7 -exec rm -- {} +
```

**Stateless built-in actions** (preferred over `-exec` when available):

```bash
find . -name '*.tmp' -delete
find . -type d -empty -delete
```

**Anti-patterns:**

```bash
# wrong — subshell loses count (core violation: cite BCS0504/BCS0903)
declare -i count=0
find . -name '*.log' | while read -r f; do
  count+=1
done
echo "$count"                            # always 0

# wrong — filenames with spaces/newlines break plain read
find . -type f | while read f; do        # should be -print0 + read -r -d ''
  process "$f"
done

# wrong — -exec ... \; forks once per match (slow, cannot aggregate)
find . -name '*.log' -exec gzip {} \;    # use + instead of \; when possible
```

Always pair `find -print0` with `read -r -d ''` so filenames containing spaces, tabs, or newlines are handled correctly.

Cross-references: BCS0411 (subshell return patterns), BCS0504 (process substitution in while loops), BCS0903 (process substitution generally).

---

# Section 10: Security

## BCS1000 Section Overview

Seven essential security areas: SUID/SGID prohibition, PATH security, IFS safety, eval avoidance, input sanitization, temporary file handling, and environment scrubbing before exec. These prevent privilege escalation, command injection, and path traversal attacks.

## BCS1001 SUID/SGID Prohibition

**Tier:** core

Never use SUID or SGID bits on Bash scripts. No exceptions.

```bash
# wrong — catastrophically dangerous
chmod u+s script.sh

# correct — use sudo instead
sudo /usr/local/bin/myscript.sh
# or configure /etc/sudoers.d/myapp for specific commands
```

For elevated privileges, use sudo, capabilities (`setcap`), compiled wrappers, PolicyKit, or systemd services.

## BCS1002 PATH Security

**Tier:** core

**Scope.** A script that runs any external command must set PATH itself, at script start (after `set` and `shopt`, before the first external command), so that an inherited PATH cannot substitute a trojan for `grep` or `rm`. A script that uses only builtins has nothing to protect and needs no PATH line: a missing PATH is a finding only when an external command is run. The rest of this rule governs what the value may contain.

**Placement: before the script metadata block.** The usual first external command in a BCS script is the one that populates the metadata -- `SCRIPT_PATH=$(realpath -- "$0")` and the `SCRIPT_DIR`/`SCRIPT_NAME` derived from it. PATH must therefore be set *above* the metadata declarations, not after them; a PATH line that follows `SCRIPT_PATH` has already let one external command run under the caller's PATH, which is the whole defect. The order is: `set` -> `shopt` -> `PATH` -> metadata.

**Sourced libraries are exempt.** A library does not set PATH: it runs inside a caller's process and assigning PATH there would silently replace the caller's, which is both surprising and a defect of its own. A missing PATH line in a file meant to be sourced is therefore not a finding, even where the library runs external commands. The obligation belongs to the executable that sources it, which must harden PATH before the `source`. A library that sets PATH anyway *is* a finding under this rule.

Secure PATH at script start to prevent command hijacking.

```bash
# correct — non-privileged interactive/user tooling only
declare -rx PATH=~/.local/bin:/usr/local/bin:/usr/bin:/bin

# correct — for production/security-critical scripts
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

# correct — PATH is set before the metadata that shells out to realpath
set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/bin:/usr/bin:/bin
#shellcheck disable=SC2155  # accepted: declare masks realpath's exit status (BCS0103)
declare -r SCRIPT_PATH=$(realpath -- "$0")

# wrong — external commands run with whatever PATH the environment supplied
set -euo pipefail
shopt -s inherit_errexit
grep -c '^' /etc/hosts               # no PATH line above: whichever grep the caller chose

# wrong — PATH set, but one external command already ran under the caller's
declare -r SCRIPT_PATH=$(realpath -- "$0")
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

# wrong — includes dangerous elements
PATH=.:$PATH                         # current directory
PATH="/tmp:$PATH"                    # world-writable directory
```

Set PATH above the metadata block, and never in a sourced library. Never include `.`, empty elements (`::`, leading/trailing `:`), or `/tmp` in PATH. User-writable directories such as `~/.local/bin` are permitted only in non-privileged user tooling; production, security-critical, or privilege-elevated (sudo/SUID-adjacent) scripts must use the system-directories-only form. Place PATH setting early, before any commands that depend on it.

## BCS1003 IFS Safety

**Tier:** recommended

Never trust inherited IFS values.

```bash
# correct — one-line IFS for single command
IFS=',' read -ra fields <<< "$csv_data"

# correct — subshell isolation (results must be used inside the subshell)
( IFS=','; read -ra fields <<< "$data"; printf '%s\n' "${fields[@]}" )

# correct — local scoping in functions
parse_csv() {
  local -- IFS=','
  read -ra fields <<< "$1"
}

# correct — null-delimited input
while IFS= read -r -d '' file; do
  process "$file"
done < <(find . -print0)

# wrong — modifying global IFS without restore
IFS=','
```

## BCS1004 Eval Avoidance

**Tier:** core

Never use `eval` with untrusted input. Almost every use case has a safer alternative. When `eval` cannot be avoided, the comment above it must say why, and its operand must be validated against a strict pattern first; an unexplained or unvalidated `eval` is a violation even on data believed to be trusted.

```bash
# correct — arrays for dynamic commands
local -a cmd=(find -- "$path" -name "$pattern")
"${cmd[@]}"

# correct — indirect expansion
echo "${!var_name}"

# correct — printf -v for dynamic assignment
printf -v "$var_name" '%s' "$value"

# correct — associative arrays for dynamic data
declare -A data
data["$key"]="$value"

# correct — case for dispatch
case $action in
  start) start_fn ;;
  stop)  stop_fn ;;
esac

# wrong
eval "echo \$$var_name"
eval "$var_name='$value'"
eval "${action}_function"
```

## BCS1005 Input Sanitization

**Tier:** core

Validate and sanitize all user input. Use whitelist over blacklist. Pass `--` before any pathname operand that originates from variables or user input (`rm -- "$f"`, `cp -- "$src" "$dst"`) to prevent option injection via filenames beginning with `-`.

**Scope of `--`.** Every command that takes a pathname operand, read-only ones and builtins included: `cat`, `head`, `sort`, `grep`, `wc`, `stat`, `diff`, `source` and `cd` parse a leading dash exactly as `rm` does, and "read-only" is no defence — a file named `-o/etc/cron.d/job` turns `sort "$f"` into a write. The `--` is owed when an operand **begins with an expansion** (`"$f"`, `"$dir"/x`, `"${files[@]}"`, `"$(cmd)"/x`). It is **not** owed, and its absence is never a finding, when the operand begins with literal text (`./"$f"`, `/etc/"$name"`: it cannot start with a dash), when the variable is an option's argument (`sort -o "$out"`, `grep -f "$patterns"`), for a redirection (`< "$file"`), inside `[[ ]]`, or for a command that takes no pathname (`echo`, `printf`, `tr`). Place it before the first operand, which is not always the pathname: `grep -- "$pattern" "$file"`, `chmod -- 644 "$f"`, `awk -- 'prog' "$f"` (after the program, `awk` reads `--` as a filename).

```bash
# correct — validate integer
[[ $input =~ ^-?[0-9]+$ ]] || die 22 "Invalid integer: ${input@Q}"

# correct — validate path within allowed directory
# allowed_dir must be canonical (realpath output) with no trailing slash
real_path=$(realpath -e -- "$path")
[[ $real_path == "$allowed_dir"/* || $real_path == "$allowed_dir" ]] || die 13 'Path traversal blocked'

# correct — sanitize a bare filename: no separator, no traversal, not hidden
# (an allowed-character class alone admits '..' and '.hidden')
[[ $name =~ ^[a-zA-Z0-9_][a-zA-Z0-9._-]*$ ]] || die 22 "Invalid filename ${name@Q}"

# correct — -- before pathname operands from variables or input
rm -- "$user_file"
cp -- "$source" "$dest"

# correct — read-only commands and builtins owe it too
sort -- "$file" | head -n 5
grep -c -- 'pattern' "$file"
source -- "$lib_path"
cd -- "$target_dir"

# wrong — a file named '-o/etc/cron.d/job' makes sort write; '-r' makes head fail
sort "$file"
head -n 5 "$file"
cat "$dir"/"$name"

# correct — no -- owed: literal-leading operand, option-argument, redirection
cat ./"$name"
wc -l /var/log/"$SCRIPT_NAME".log
sort -o "$output" -- "$input"
content=$(< "$file")
```

Validate early, fail securely with clear errors, run with minimum necessary permissions.

## BCS1006 Temporary File Handling

**Tier:** core

Always use `mktemp`. Never hardcode temp file paths.

This rule owns how a temporary name is made: a hardcoded or predictable path is cited here. The cleanup trap belongs to BCS0110 -- a temporary resource with no cleanup trap, or a trap installed after `mktemp`, is cited as BCS0110, not as this rule. The examples below show the trap only because a correct example must obey BCS0110.

```bash
# correct — temp file: trap first (BCS0110), guarded while the name is still empty
declare -- temp_file=''
trap '[[ -z $temp_file ]] || rm -f -- "$temp_file"' EXIT
temp_file=$(mktemp) || die 1 'Failed to create temp file'

# correct — temp dir (alternative; a second EXIT trap would overwrite the first)
declare -- temp_dir=''
trap '[[ -z $temp_dir ]] || rm -rf -- "$temp_dir"' EXIT
temp_dir=$(mktemp -d) || die 1 'Failed to create temp dir'

# correct — both resources: single cleanup function, one EXIT trap, set before either mktemp
cleanup() {
  [[ -z $temp_file ]] || rm -f -- "$temp_file"
  [[ -z $temp_dir ]] || rm -rf -- "$temp_dir"
}
trap cleanup EXIT

# correct — custom template
mktemp /tmp/"$SCRIPT_NAME".XXXXXX

# wrong
echo data > /tmp/myapp_temp.txt      # predictable path
echo data > "/tmp/app_$$"            # PID-based (predictable)
```

Default `mktemp` permissions are secure (0600 files, 0700 directories). Multiple trap statements for the same signal overwrite each other — use a single cleanup function.

## BCS1007 Environment Scrubbing Before exec

**Tier:** recommended

Scripts that hand control to another program in a **privileged or delegating context** must sanitise the inherited environment before `exec`. Inherited variables like `LD_PRELOAD`, `LD_LIBRARY_PATH`, or `PYTHONPATH` can silently hijack the child process.

**Privileged or delegating contexts include:**

- Scripts invoked via `sudo` that then `exec` a helper
- `su`-style or wrapper scripts that elevate privilege
- PAM or systemd service scripts that `exec` user-supplied commands
- SSH `ForceCommand` wrappers and other shell-dispatch gatekeepers
- Scripts that `exec` an interpreter (python, perl, ruby, node) against a fixed script path

Scripts that merely run a pipeline of well-known commands (`grep`, `awk`, `curl`) in their own unprivileged context do not need this scrubbing.

**Minimum unset list** (loaders, interpreter search paths, shell startup files):

```bash
# correct — explicit scrubbing before exec in a privileged wrapper
unset LD_PRELOAD LD_LIBRARY_PATH LD_AUDIT \
      PYTHONPATH PERL5LIB RUBYLIB NODE_PATH \
      BASH_ENV ENV SHELLOPTS
exec /usr/libexec/myapp/helper "$@"
```

**Stronger -- `env -i` for a fully-reset environment** (PATH must be set explicitly):

```bash
# correct — full environment reset
exec env -i \
  HOME="$HOME" \
  PATH=/usr/local/bin:/usr/bin:/bin \
  /usr/libexec/myapp/helper "$@"
```

**Anti-patterns:**

```bash
# wrong — sudoed wrapper exec's helper without scrubbing LD_PRELOAD
#!/usr/bin/bash
# invoked via: sudo /usr/local/bin/deploy-wrapper
set -euo pipefail
exec /usr/local/libexec/deploy "$@"      # LD_PRELOAD would hijack deploy

# wrong — partial scrub missing the -AUDIT variant
unset LD_PRELOAD LD_LIBRARY_PATH
exec /usr/libexec/helper "$@"            # LD_AUDIT still inherited
```

LLM-based checkers should flag `exec /path/to/binary "$@"` (or comparable direct-exec patterns) when the script shows markers of a privileged/delegating context -- a top-of-file comment documenting sudo/systemd/PAM invocation, a `ForceCommand` hint, or an explicit privilege handoff -- and no preceding `unset` of the minimum list. Benign scripts without such markers should NOT be flagged.

Cross-references: BCS1001 (SUID prohibition on bash itself), BCS1002 (PATH hardening).

---

# Section 11: Concurrency & Jobs

## BCS1100 Section Overview

Background job management, parallel execution, wait patterns, timeouts, and retry logic. Never leave background jobs unmanaged.

## BCS1101 Background Job Management

**Tier:** core

Always track PIDs when starting background jobs.

```bash
# correct
command &
pid=$!

# correct — multiple PIDs
declare -a pids=()
command1 &
pids+=($!)
command2 &
pids+=($!)

# correct — check if process is running
kill -0 "$pid" 2>/dev/null           # signal 0 = existence check

# correct — cleanup in trap
cleanup() {
  local -i exitcode=${1:-$?}
  trap - SIGINT SIGTERM EXIT
  for pid in "${pids[@]}"; do
    kill "$pid" 2>/dev/null ||:
  done
  exit "$exitcode"
}
trap 'cleanup $?' SIGINT SIGTERM EXIT

# wrong
command &                            # untracked background job

# wrong — a loop of untracked jobs: nothing can wait on any of them
for f in ./*.in; do process_one "$f" & done
```

This rule owns the **untracked** job -- one whose `$!` is never captured, so
nothing can wait on it. What becomes of the exit code of a `wait` that does run
is BCS1103's finding; a script that starts jobs and never waits at all is cited
here alone.

Use `$!` for the last background PID. Never use `$$` (that's the parent PID).

## BCS1102 Parallel Execution

**Tier:** recommended

For ordered output, write results to temp files then display in order.

```bash
# correct — parallel with ordered output
declare -- temp_dir=''
trap '[[ -z $temp_dir ]] || rm -rf -- "$temp_dir"' EXIT
temp_dir=$(mktemp -d) || die 1 'Failed to create temp dir'
declare -a pids=()
declare -i errors=0

for server in "${servers[@]}"; do
  check_server "$server" &> "$temp_dir"/"$server".out &
  pids+=($!)
done

# Wait and display in order; accumulate failures (BCS1103)
for server in "${servers[@]}"; do
  wait "${pids[0]}" || errors+=1
  pids=("${pids[@]:1}")
  cat -- "$temp_dir"/"$server".out
done
((errors == 0)) || die 1 "$errors job(s) failed"
```

Implement concurrency limits by checking `${#pids[@]}` against `max_jobs` and using `wait -n` to wait for slots.

Never modify variables in background subshells expecting parent visibility — use temp files for results.

## BCS1103 Wait Patterns

**Tier:** core

Never discard the exit code of `wait`. Accumulate failures into a counter and fail the script once at the end if any background job failed. An unsuppressed `wait` under `set -e` terminates the script on the first failure -- losing information about other in-flight jobs.

```bash
# correct — accumulator pattern over a fixed list of pids
declare -i errors=0
for pid in "${pids[@]}"; do
  wait "$pid" || errors+=1
done
((errors == 0)) || die 1 "$errors job(s) failed"

# correct — process-as-completed (Bash 4.3+ wait -n)
declare -i errors=0
while ((${#pids[@]})); do
  wait -n || errors+=1
  pids=("${pids[@]:1}")
done
((errors == 0)) || die 1 "$errors job(s) failed"

# wrong — exit code discarded; failures silent
wait "$pid" ||:

# wrong — no accumulator; first failure kills script under set -e
for pid in "${pids[@]}"; do
  wait "$pid"
done

# not this rule — nothing was tracked and nothing waits: cite BCS1101
command &
```

This rule governs a `wait` that runs. Where no PID was captured and the script
never waits at all, the finding is BCS1101's (untracked job), not this rule's.

## BCS1104 Timeout Handling

**Tier:** core

Wrap network and remote operations (`ssh`, `curl`, `wget`, `nc`) with `timeout` or tool-native timeout flags. Bounding other operations that can block indefinitely — interactive `read` (use `read -t`), long-running local commands — is recommended but not required by this rule.

```bash
# correct
timeout 300 ssh -o ConnectTimeout=10 "$server" 'command'
timeout --signal=TERM --kill-after=10 60 long_command

# correct — capture the exit code first; a bare command under set -e aborts
# before any `case $?` could run, so guard with `|| rc=$?`
declare -i rc=0
timeout 300 ssh -o ConnectTimeout=10 "$server" 'command' || rc=$?
case $rc in
  0)   success 'Command completed' ;;
  124) error 'Command timed out' ;;
  125) error 'Timeout itself failed' ;;
  *)   error 'Command failed' ;;
esac

# correct — user input timeout with default
read -r -t 10 -p 'Enter value: ' value || value='default'

# correct — SSH and curl timeouts
# ConnectTimeout bounds connection only — wrap in `timeout` to bound total runtime
timeout 300 ssh -o ConnectTimeout=10 -o BatchMode=yes "$host" 'command'
curl --connect-timeout 10 --max-time 60 "$url"
```

## BCS1105 Exponential Backoff

**Tier:** recommended

Use exponential backoff for retries. Never use fixed delays.

```bash
# correct
declare -i attempt=1 max_attempts=5 delay max_delay=60 jitter
declare -- out=''
trap '[[ -z $out ]] || rm -f -- "$out"' EXIT
out=$(mktemp) || die 1 'Failed to create temp file'

while ((attempt <= max_attempts)); do
  # Success requires both exit code 0 and non-empty output
  if try_operation > "$out" && [[ -s "$out" ]]; then
    break
  fi

  delay=$((2 ** attempt))
  ((delay > max_delay)) && delay=$max_delay ||:

  # Add jitter to prevent thundering herd
  jitter=$((RANDOM % delay))
  sleep $((delay + jitter))

  attempt+=1
done
((attempt <= max_attempts)) || die 1 "operation failed after $max_attempts attempts"

# wrong — tight retry loop
while ! curl "$url"; do :; done      # floods failing services
```

Validate success conditions beyond exit code — the example treats empty output as failure via `[[ -s "$out" ]]`.

---

# Section 12: Style & Development

## BCS1200 Section Overview

Code formatting, comments, development practices, debugging, dry-run patterns, and testing support. These conventions ensure consistent, maintainable scripts.

## BCS1201 Code Formatting

**Tier:** style

- 2 spaces for indentation (never tabs)
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
((fnd == 1)) && [[ -z ${found_files[0]} ]] && fnd=0

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
- One blank line after section comments
- Blank lines before and after multi-line blocks
- Never multiple consecutive blank lines
- No blank lines between short, related statements

## BCS1204 Section Comments

**Tier:** style

Section comments mark logical divisions within a script. They must be:

- A single line
- 2-4 words
- Prefixed with a single `#` (no box-drawing characters, no ASCII art frames)
- Followed by a blank line before the first marked statement

```bash
# correct — single #, 2-4 words, blank line follows
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
[[ condition ]]                     # not [ condition ] or test
var=$(command)                      # not var=`command`
{1..10}                             # not $(seq 1 10)

# not this rule — parsing a variable with an external tool: cite BCS0507
minor=$(echo "$tag" | cut -d. -f2)
```

Parsing a shell variable with an external tool (`grep -oE`, `cut -d`, `sed -n`,
`awk '{print $N}'`) is **BCS0507's** finding, not this rule's. This rule covers
the remaining builtin substitutions listed above.

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

Gate debug output on an integer `DEBUG` variable (`declare -i DEBUG=${DEBUG:-0}`), send it to stderr, and never ship an unconditional `set -x`.

```bash
# correct
declare -i DEBUG=${DEBUG:-0}
((DEBUG)) && set -x ||:

# enhanced trace output
export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:+${FUNCNAME[0]}():} '

# debug function
debug() { ((DEBUG)) || return 0; >&2 _msg "$@"; }

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
declare -f FIND_CMD >/dev/null || FIND_CMD() { find "$@"; }
# override in tests: FIND_CMD() { echo 'mocked_file.txt'; }

# correct — test mode flag
declare -i TEST_MODE=${TEST_MODE:-0}

# correct — assert function
assert() {
  local -- expected=$1 actual=$2 msg=${3:-assertion}
  [[ $expected == "$actual" ]] || {
    error "FAIL: $msg: expected ${expected@Q}, got ${actual@Q}"
    return 1
  }
}

# correct — test runner
run_tests() {
  local -i passed=0 failed=0
  local -- fn
  while read -r _ _ fn; do
    if "$fn"; then
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
trim() { local -- v="$*"; v=${v#"${v%%[![:blank:]]*}"}; echo -n "${v%"${v##*[![:blank:]]}"}" ; }

# Debug variable display
decp() { declare -p "$@" 2>/dev/null | sed 's/^declare -[a-zA-Z-]* //'; }

# Pluralization
s() { (( ${1:-1} == 1 )) || echo -n 's'; }
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
COMPDIR ?= /etc/bash_completion.d
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
COMPDIR ?= /etc/bash_completion.d
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
	@# Bash completion (if present, skip if dir missing)
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
	cd tests && ./run_all_tests.sh

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

---

# Section 13: Environment Configuration

This section is the canonical reference for environment variables read by the `bcs` toolchain itself. Unlike sections 01–12, it documents the toolkit's runtime configuration surface — not coding rules — and contributes no `BCS####` codes to `bcs codes`. For the same reason `bcs check` leaves this section out of the copy of the standard it shows the checker; `bcs display` and `bcs generate` keep it.

Variables fall into six families:

1. **User configuration** — defaults for `bcs check` flags, overridable per-call
2. **Model aliases** — the `MODEL_ALIASES` map: short names that expand to canonical model IDs
3. **Backend selection** — `OLLAMA_HOST`, `BCS_OLLAMA_NUM_CTX` and `BCS_OLLAMA_KEEP_ALIVE` configure the local Ollama backend
4. **Credentials** — API keys consumed by the cloud backends
5. **Search paths** — XDG locations for config and state files, plus the `BCS_CONF_DIR` test override
6. **Internal / advanced** — runtime flags exported by `bcs` itself; documented for source-readers

Values are resolved in this precedence (highest wins):

1. CLI flag (e.g. `-m`, `-e`, `--strict`)
2. Configuration file (`bcs.conf` cascade, see §13.5)
3. Environment variable
4. Hardcoded default in `bcs`

The `bcs.conf.sample` file in the source tree is a quick-start template. This section is the authoritative reference.

## 13.1 User Configuration

Default values for the `bcs check` subcommand. All have CLI flag equivalents that override them.

### `BCS_MODEL`

- **Default:** `sonnet` (alias for `claude-sonnet-4-6`)
- **Values:** a `MODEL_ALIASES` short name (e.g. `sonnet`, `opus`, `haiku`, `flash`, `gpt5`, `qwen`), `claude-code[:alias|:model]`, or any concrete model name routed by `_sniff_backend()` (`claude-*` → Anthropic, `gemini-*` → Google, `gpt-*`/`o[0-9]*` → OpenAI, anything else → Ollama)
- **Override flag:** `-m`, `--model`
- **Consumed:** `cmd_check()` initialiser

The backend is resolved entirely from the (alias-expanded) model name — there is no probe and no separate backend flag. The legacy tier keywords (`fast`, `balanced`, `thorough`) are rejected with exit 22 and a migration hint pointing at the alias map.

### `BCS_EFFORT`

- **Default:** `medium`
- **Values:** `low` (or `min`), `medium`, `high`, `xhigh`, `max`
- **Override flag:** `-e`, `--effort`
- **Consumed:** `cmd_check()` initialiser

Effort controls both prompt guidance and the output token budget (`EFFORT_TOKENS` array: `low=4000`, `medium=8000`, `high=24000`, `xhigh=40000`, `max=64000`). `min` is normalised to `low` at parse time. `max` should be avoided for Ollama cloud models (hallucination risk). `medium` is the default on evidence: `low` sends no thinking budget (`reasoning_effort=minimal` on OpenAI), which is fast and accurate on short scripts but raised false `[ERROR]` findings on a compliant real-size script in every measured run. Do not gate a build on `low`. Effort has no effect on the Claude Code CLI backend, which always runs at the CLI's lowest native effort: the CLI turns its own effort level into a thinking budget, and `medium` there cost 8-12 times the wall time of an API backend for no measured gain.

### `BCS_STRICT`

- **Default:** `0`
- **Values:** `0` or `1`
- **Override flag:** `-s` / `-S`, `--strict` / `--no-strict`
- **Consumed:** `cmd_check()` initialiser

When `1`, warnings are reported as violations and contribute to a non-zero exit code.

### `BCS_DEBUG`

- **Default:** `0`
- **Values:** `0` or `1`
- **Override flag:** `-D`, `--debug`
- **Consumed:** `cmd_check()` initialiser

When `1`, the raw-response dump path is announced on success (it is always announced on failure).

### `BCS_JSON`

- **Default:** `0`
- **Values:** `0` or `1`
- **Override flag:** `-j`, `--json`
- **Consumed:** `cmd_check()` initialiser

When `1`, stdout is a single JSON object shaped like `shellcheck --format=json1` (`{source, meta, comments[]}`). Info messages still go to stderr when verbose.

### `BCS_SHELLCHECK`

- **Default:** `1` (enabled)
- **Values:** `0` or `1`
- **Override flag:** `--shellcheck`, `--no-shellcheck`
- **Consumed:** `cmd_check()` initialiser

When `1`, `shellcheck --format=json -x` runs over the target script and the JSON report is prepended to the LLM user prompt as static-analysis context. Auto-skipped when `shellcheck` is not on `PATH`.

### `BCS_TIER`

- **Default:** unset (no tier filter)
- **Values:** `core`, `recommended`, or `style`
- **Override flag:** `-T`, `--tier`
- **Consumed:** `cmd_check()` initialiser

Restricts findings to a single tier. Useful in CI: `BCS_TIER=core` reports only correctness/safety bugs.

### `BCS_MIN_TIER`

- **Default:** unset (no minimum)
- **Values:** `core`, `recommended`, or `style`
- **Override flag:** `-M`, `--min-tier`
- **Consumed:** `cmd_check()` initialiser

Reports findings at the named tier or higher severity. `BCS_MIN_TIER=recommended` skips style findings during development.

### `BCS_RESPONSE_DUMP`

- **Default:** `${XDG_STATE_HOME:-$HOME/.local/state}/bcs/last-response.txt`, or `mktemp /tmp/bcs-last-response.XXXXXX` if the state directory cannot be created
- **Values:** any writable file path
- **Override flag:** none (set externally to redirect)
- **Consumed:** `cmd_check()` always exports this; `_dump_response()` writes raw HTTP bodies; the path is announced on failure or with `--debug`

Set externally to direct raw API responses to a known location for inspection. The Claude Code CLI backend returns text, not JSON, so for that backend the file holds the CLI's standard error: an authentication or quota failure is diagnosed from here.

## 13.2 Model Aliases

The four legacy per-backend overrides (`BCS_ANTHROPIC_MODEL`, `BCS_OPENAI_MODEL`, `BCS_GOOGLE_MODEL`, `BCS_OLLAMA_MODEL`) and the tier-keyword arrays (`*_MODELS`) are gone. The single mechanism for naming models is the `MODEL_ALIASES` associative array.

### `MODEL_ALIASES`

- **Default:** built-in map in `bcs` (`opus`, `sonnet`, `haiku`, `flash`, `pro`, `flash-lite`, `gpt5`, `gpt5-mini`, `qwen`, `qwen-small`)
- **Values:** `MODEL_ALIASES[name]=canonical-id` entries, set in `bcs.conf` (it is a Bash associative array, so it can only be extended from a sourced config file — not from the environment)
- **Consumed:** `_expand_alias()` before `_sniff_backend()` routing

Extend or override in `bcs.conf`:

```bash
MODEL_ALIASES[mymodel]=qwen3.5:14b
MODEL_ALIASES[sonnet]=claude-sonnet-4-7   # repoint a built-in alias
```

Unknown names pass through `_expand_alias()` unchanged, so canonical model IDs need no alias entry. To pin a model across sessions, set `BCS_MODEL` to an alias or canonical ID in `bcs.conf`.

## 13.3 Backend Selection (Ollama)

### `OLLAMA_HOST`

- **Default:** `localhost:11434`
- **Values:** `host:port` or `protocol://host:port`
- **Consumed:** `_llm_ollama()`

Direct the local Ollama backend at a non-default endpoint (e.g. `OLLAMA_HOST=ollama.lan:11434`).

### `BCS_OLLAMA_NUM_CTX`

- **Default:** `40960`
- **Values:** a positive integer (tokens); anything else is exit 22
- **Consumed:** `_llm_ollama()` → `options.num_ctx`

Ollama truncates the prompt to the server default (4096 tokens) unless the request carries `options.num_ctx`. The standard alone is about 33k tokens, so without this field the model never sees the rules and returns nothing useful. The value must hold the standard plus the script plus the reply: raise it for long scripts or `-e high` and above, at the cost of VRAM. `bcs check` warns when the prompt is certain to exceed the configured window.

### `BCS_OLLAMA_KEEP_ALIVE`

- **Default:** `30m`
- **Values:** a duration string (`30m`, `1h`) or seconds as an integer (`-1` = keep forever, `0` = unload at once); integers are sent as JSON numbers
- **Consumed:** `_llm_ollama()` → top-level `keep_alive`

Keeps the model loaded between checks so a batch run does not pay the model load on every file.

## 13.4 Credentials

API keys for the cloud backends. There is no key probe: the backend (and therefore which key is needed) is determined solely by the alias-expanded model name. All keys are passed to `curl` via a `--config` file descriptor, never on the command line, so they are not visible in `ps`.

### `ANTHROPIC_API_KEY`

- **Required for:** Anthropic API backend (`claude-*` models). The `claude-code` sentinel requires the Claude Code CLI binary instead (missing CLI is exit 18, not an API fallback) and unsets `ANTHROPIC_API_KEY` for the CLI invocation so it authenticates via OAuth.
- **Consumed:** `_llm_anthropic()` `x-api-key` header

### `OPENAI_API_KEY`

- **Required for:** OpenAI API backend (`gpt-*`, `o[0-9]*` models)
- **Consumed:** `_llm_openai()` `Authorization: Bearer` header

### `GOOGLE_API_KEY`

- **Required for:** Google Gemini API backend (`gemini-*` models)
- **Consumed:** `_llm_google()` `x-goog-api-key` header

### `GEMINI_API_KEY`

- **Alias for:** `GOOGLE_API_KEY` (Google's two SDK families use different names for the same key)
- **Precedence:** `GOOGLE_API_KEY` wins. If both are set, `bcs` unsets `GEMINI_API_KEY` before invoking the backend so downstream tooling sees a single canonical name.

## 13.5 Search Paths

XDG Base Directory variables that locate `bcs.conf` and the response dump. Standard XDG semantics apply (defaults used when unset).

### `XDG_CONFIG_HOME`

- **Default:** `$HOME/.config`
- **Affects:** `bcs.conf` and `policy.conf` cascade — `$XDG_CONFIG_HOME/bcs/bcs.conf` is the user-level config layer (overrides `/etc/bcs.conf`, `/etc/bcs/bcs.conf`, `/usr/local/etc/bcs/bcs.conf`)
- **Consumed:** `_conf_search_paths()`; policy resolution in `_load_policy()`

### `XDG_STATE_HOME`

- **Default:** `$HOME/.local/state`
- **Affects:** default `BCS_RESPONSE_DUMP` location (`$XDG_STATE_HOME/bcs/last-response.txt`)
- **Consumed:** `cmd_check()` state-dir setup

### `BCS_CONF_DIR`

- **Default:** unset (full cascade in effect)
- **Values:** a directory path; when set, `$BCS_CONF_DIR/bcs.conf` becomes the **only** config file considered, replacing the entire cascade
- **Consumed:** `_conf_search_paths()`

Intended for hermetic testing — it prevents a real `/etc/bcs.conf` or `~/.config/bcs/bcs.conf` from leaking into a test run. The test harness (`tests/test-helpers.sh`) sets it to an empty directory by default.

The data directory containing `BASH-CODING-STANDARD.md` and `data/*.md` section files is **not** XDG-resolved. It uses a four-step FHS search (development tree → relative `share/yatti/BCS/data` → `/usr/local/share/yatti/BCS/data` → `/usr/share/yatti/BCS/data`) defined in `_find_data_dir()`. There is no environment override for the data directory.

## 13.6 Internal / Advanced

These variables are set by `bcs` itself at runtime. They are documented here so power users reading the source — or wrapping the `_llm_*` backend functions — understand the runtime contract. **Users should not set them directly**; the corresponding CLI flag is the supported interface.

### `BCS_JSON_MODE`

- **Set by:** `cmd_check()` exports this from `--json` / `BCS_JSON`
- **Values:** `0` or `1`
- **Consumed:** all four `_llm_*` backend bodies

When `1`, each backend flips its native JSON-output knob:

- Ollama → `"format": "json"` at payload top level
- OpenAI → `"response_format": {"type": "json_object"}`
- Google → `"response_mime_type": "application/json"` under `generationConfig`
- Anthropic / Claude CLI → no native flag; rely on prompt discipline plus `_strip_json_fences()` fallback

Override the flag via `-j`/`--json` or `BCS_JSON=1` rather than setting `BCS_JSON_MODE` directly. Setting it externally without taking the rest of the JSON-rendering path (envelope wrap, schema validation in `_render_json_output()`) produces inconsistent output.

---

# Compliance Checking Reference

This section summarises key rules that are frequently misapplied during automated compliance checking. It does not introduce new rules — it reinforces existing ones.

## Severity

- **VIOLATION**: Code is incorrect, unsafe, or clearly breaks a mandatory (MUST/SHALL) rule.
- **WARNING**: Style deviation, SHOULD/RECOMMENDED level, or intentional design choice that deviates from a reference pattern.

When a rule says "prefer X over Y", using Y is a WARNING at most — not a VIOLATION.

A finding's severity comes from the rule's **Tier:** line and from nothing else: a `core` rule yields a VIOLATION, reported as `[ERROR]`; a `recommended` or `style` rule yields a WARNING, reported as `[WARN]`. Words such as "must" or "mandatory" inside a recommended- or style-tier rule say how to satisfy that rule; they do not raise its findings to `[ERROR]`.

## Production Optimization Takes Precedence (BCS0405)

Reference implementations in BCS0703, BCS0706, and BCS0701 show the full messaging suite, color set, and flag set. These are templates — not mandatory checklists. Per BCS0405:

- Do NOT flag missing functions (`success()`, `debug()`, `vecho()`) the script never calls
- Do NOT flag missing colors (`GREEN`) the script never references
- Do NOT flag missing flags (`DEBUG`) the script never tests
- Do NOT add unused code to satisfy a template

A script that defines only the functions, colors, and flags it actually uses is **more** compliant than one that carries dead code from a template.

## Conditional Safety — `||:` Present Means Safe (BCS0606)

```bash
# acceptable — ||: catches failure from the ENTIRE chain
((VERBOSE)) && echo 'verbose' ||:
((cond)) && action1 && action2 ||:
```

Missing `||:` on a `&&` chain under `set -e` is a VIOLATION. Using `&&...||:` instead of the inverted `||` form is a style preference — both are correct.

## Suppression Directives

`#bcscheck disable=BCSxxxx` follows ShellCheck conventions — it suppresses the **next command**, which may be a single line or a brace/block group. A suppressed finding is not a finding. Do not report it, discuss it, or note it "for completeness."

## Reference Patterns Are Not Mandates

Rules like BCS0709 (`yn()`), BCS0111 (`read_conf()`), and BCS1211 (utility functions) show reference implementations. Functionally equivalent alternatives are acceptable. Intentional deviations documented in comments or help text are not violations.

## Inline IFS Is Already Scoped

```bash
# correct — IFS is scoped to this single read command (no global side-effect)
IFS=',' read -ra fields <<< "$csv_data"
IFS='|' read -ra cells <<< "$line"
IFS=$'\037' read -ra parts <<< "$row"
```

The `IFS=value command` form modifies IFS only for the duration of that command. This is NOT an unlocalized IFS modification and does NOT require `local -- IFS` or subshell isolation. Do not flag this pattern as a violation.

## Common Non-Issues

- `SCRIPT_DIR` omitted when unused (BCS0103: "Not all scripts need all four" script metadata variables)
- `return 0` from `main()` instead of `exit 0` — functionally equivalent for non-sourced scripts (WARNING at most, not VIOLATION)
- Config search paths adjusted from the BCS0111 reference order — acceptable when documented in help text
- `local` declarations between logical sections within a function — permitted by BCS0401 ("Declarations may appear mid-body... between logical sections"), only prohibited inside loops
- Option bundling includes arg-taking options — BCS0805 documents that the user must place arg-taking options last in a bundle; this is the user's responsibility, not a script defect
