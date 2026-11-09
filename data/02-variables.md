<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
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
