# Bash Coding Standard

This document defines a comprehensive Bash coding standard and presumes Bash 5.2 and higher; this is not a compatibility standard.

NOTE: Do not over-engineer scripts; functions and varaibles not required for the operation of the script should not be included and/or removed.

## Contents
1. [Script Structure](#script-structure)
2. [Variable Declarations](#variable-declarations)
3. [Functions](#functions)
4. [Error Handling](#error-handling)
5. [Control Flow](#control-flow)
6. [String Operations](#string-operations)
7. [Arrays](#arrays)
8. [Command-Line Arguments](#command-line-arguments)
9. [Output and Messaging](#output-and-messaging)
10. [File Operations](#file-operations)
11. [Calling Commands](#calling-commands)
12. [Security Considerations](#security-considerations)
13. [Best Practices](#best-practices)
14. [Summary](#summary)
15. [Advanced Topics](#advanced-topics)

## Script Structure

### Standard Script Layout
1. Shebang
2. Global shellcheck directives (where required)
3. Script description comment
4. `set -euo pipefail`
5. Script metadata (VERSION, SCRIPT_NAME, etc.)
6. Global variable declarations
7. Color definitions (if terminal output)
8. Utility functions
9. Business logic functions
10. `main()` function
11. Script invocation: `main "$@"`
12. End marker: `#fin`

### Shebang and Initial Setup
First lines of all scripts must include a `#!shebang`, global `#shellcheck` definitions (optional), a brief description of the script, and first command `set -euo pipefail`.

```bash
#!/bin/bash
#shellcheck disable=SC1090,SC1091
# Get directory sizes and report usage statistics
set -euo pipefail
```

Allowable shebangs are `#!/bin/bash`, `#!/usr/bin/bash` and `#!/usr/bin/env bash`.

### Script Metadata
```bash
VERSION='1.0.0'
SCRIPT_PATH=$(readlink -en -- "$0") # Full path to script
SCRIPT_DIR=${SCRIPT_PATH%/*}        # Script directory
SCRIPT_NAME=${SCRIPT_PATH##*/}      # Script basename
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME
```

#### shopt

**Recommended settings for most scripts:**

```bash
# STRONGLY RECOMMENDED - apply to all scripts
shopt -s inherit_errexit  # Critical: makes set -e work in subshells,
                          # command substitutions
shopt -s shift_verbose    # Catches shift errors when no arguments remain
shopt -s extglob          # Enables extended glob patterns like !(*.txt)

# CHOOSE ONE based on use case:
shopt -s nullglob   # For arrays/loops: unmatched globs → empty (no error)
                # OR
shopt -s failglob   # For strict scripts: unmatched globs → error

# OPTIONAL based on needs:
shopt -s globstar   # Enable ** for recursive matching (slow on deep trees)
```

Example for typical script:
```bash
shopt -s inherit_errexit shift_verbose extglob nullglob
```

### File Extensions
- Executables should have `.sh` extension or no extension
- Libraries must have `.sh` extension and should not be executable
- Libraries that can also be executed as scripts can have either `.sh` or no extension
- If the executable will be available globally via PATH, always use no extension

## Variable Declarations

### Type-Specific Declarations
```bash
declare -i VERBOSE=1        # Integer variables
declare -- STRING_VAR=''    # String variables
declare -a MY_ARRAY=()      # Indexed arrays
declare -A HASH_VAR=()      # Associative arrays
readonly -- CONSTANT='val'  # Read-only constants
```

### Variable Scoping
- Always declare function-specific variables as `local`
```bash
# Global variables - declare at top
declare -i VERBOSE=1 PROMPT=1

# Function variables - always use local
main() {
  local -a add_specs=()      # Local array
  local -i max_depth=3       # Local integer
  local -- path              # Local string
  local -- dir
  dir=$(dirname "$name")
  # ...
}
```

### Naming Conventions

| Constants | UPPER_CASE |
| Global variables | UPPER_CASE or CamelCase |
| Local variables | lower_case with underscores; CamelCase acceptable |
| | for important local variables |
| Internal/private functions | prefix with _ |
| Environment variables | UPPER_CASE with underscores |

### Constants and Environment Variables
```bash
# Constants
readonly -- PATH_TO_FILES='/some/path'

# Environment variables
declare -x ORACLE_SID='PROD'
```

### Boolean Flags Pattern

For boolean state tracking, use integer variables with `declare -i`:

```bash
# Boolean flags - declare as integers with explicit initialization
declare -i INSTALL_BUILTIN=0
declare -i BUILTIN_EXPLICITLY_REQUESTED=0
declare -i SKIP_BUILTIN=0
declare -i NON_INTERACTIVE=0
declare -i UNINSTALL=0
declare -i DRY_RUN=0

# Test flags in conditionals using (())
((DRY_RUN)) && info 'Dry-run mode enabled'

if ((INSTALL_BUILTIN)); then
  install_loadable_builtins
fi

# Toggle flags
((VERBOSE)) && VERBOSE=0 || VERBOSE=1

# Set flags from command-line parsing
--dry-run)    DRY_RUN=1 ;;
--skip-build) SKIP_BUILD=1 ;;
```

**Guidelines:**
- Use `declare -i` for integer-based boolean flags
- Name flags descriptively in ALL_CAPS (e.g., `DRY_RUN`, `INSTALL_BUILTIN`)
- Initialize explicitly to `0` (false) or `1` (true)
- Test with `((FLAG))` in conditionals (returns true for non-zero, false for zero)
- Avoid mixing boolean flags with integer counters - use separate variables

### Derived Variables

Variables computed from other variables should be grouped together with comments explaining their derivation:

```bash
# Default values
declare -- PREFIX=/usr/local
declare -- CONFIG_NAME=myapp

# Derived paths - computed from PREFIX
declare -- BIN_DIR="$PREFIX"/bin
declare -- LIB_DIR="$PREFIX"/lib
declare -- CONFIG_FILE="$HOME"/."$CONFIG_NAME"rc

# Special case: hardcoded for system-wide access
# PROFILE_DIR intentionally uses /etc regardless of PREFIX to ensure
# system-wide profile integration for all user sessions
declare -- PROFILE_DIR=/etc/profile.d

# Derived from environment with fallback
declare -- LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"/myapp
```

**Important:** When base variables can change during argument parsing, remember to update derived variables:

```bash
main() {
  # Parse arguments
  while (($#)); do
    case $1 in
      --prefix)     shift
                    PREFIX="$1"
                    # Update all derived paths when PREFIX changes
                    BIN_DIR="$PREFIX"/bin
                    LIB_DIR="$PREFIX"/lib
                    DOC_DIR="$PREFIX"/share/doc
                    ;;
    esac
    shift
  done

  # Rest of main logic
}
```

**Guidelines:**
- Group derived variables with section comment (e.g., `# Derived paths`)
- Document special cases or hardcoded values with inline comments
- Update derived variables when base variables change (especially in argument parsing)
- Declare derived variables immediately after their dependencies when practical

### Readonly After Group

When declaring multiple readonly variables, declare them first, then make them all readonly in a single statement:

```bash
# Script metadata
VERSION='1.0.0'
SCRIPT_PATH=$(readlink -en -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Color definitions
if [[ -t 1 && -t 2 ]]; then
  declare -- RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' NC=$'\033[0m'
else
  declare -- RED='' GREEN='' YELLOW='' NC=''
fi
readonly -- RED GREEN YELLOW NC
```

**Rationale:** This pattern improves readability by clearly separating the initialization phase from the protection phase. It makes the group of related constants visually distinct and easier to maintain.

**Anti-pattern:**
```bash
# ✗ Don't make each variable readonly individually
readonly VERSION='1.0.0'
readonly SCRIPT_PATH=$(readlink -en -- "$0")
readonly SCRIPT_DIR=${SCRIPT_PATH%/*}
readonly SCRIPT_NAME=${SCRIPT_PATH##*/}
```

## Functions

### Function Definition Pattern
```bash
# Single-line functions for simple operations
vecho() { ((VERBOSE)) || return 0; _msg "$@"; }

# Multi-line functions with local variables
main() {
  local -i exitcode=0
  local -- variable
  # Function body
  return "$exitcode"
}
```

### Function Names
- Use lowercase with underscores
```bash
# Good
my_function() {
  …
}

# Private functions use leading underscore
_my_private_function() {
  …
}
```

### Main Function
- Always include a `main()` function for scripts longer than ~40 lines
- Helps with organization and testing

```bash
main() {
  # Main logic here
  local -i rc=0
  # Process arguments, call functions
  return "$rc"
}

# Call main with all arguments
main "$@"
#fin
```

### Function Export
```bash
# Export functions when needed by subshells
grep() { /usr/bin/grep "$@"; }
find() { /usr/bin/find "$@"; }
declare -fx grep find
```

### Standard Utility Functions
```bash
# Messaging functions
_msg() { ... }           # Core message function
vecho() { ... }          # Verbose echo
success() { ... }        # Success messages
warn() { ... }           # Warning messages
info() { ... }           # Information messages
error() { ... }          # Error messages (to stderr)
die() { ... }            # Exit with error

# Helper functions
noarg() { ... }          # Validate argument presence
decp() { ... }           # Debug print variable declaration
trim() { ... }           # Trim whitespace
s() { ... }              # Pluralization helper
yn() { ... }             # Yes/no prompt
```

### Production Script Optimization
Once a script is mature and ready for production:
- Remove unused utility functions (e.g., if `yn()`, `decp()`, `trim()`, `s()` are not used)
- Remove unused global variables (e.g., `PROMPT`, `DEBUG` if not referenced)
- Remove unused messaging functions that your script doesn't call
- Keep only the functions and variables your script actually needs
- This reduces script size, improves clarity, and eliminates maintenance burden

Example: A simple script may only need `error()` and `die()`, not the full messaging suite.

### Function Organization

Organize functions in a logical order from lowest-level (messaging, utilities) to highest-level (main logic):

```bash
#!/bin/bash
set -euo pipefail

# 1. Messaging functions (lowest level - used by everything)
_msg() { ... }
success() { >&2 _msg "$@"; }
warn() { >&2 _msg "$@"; }
info() { >&2 _msg "$@"; }
error() { >&2 _msg "$@"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

# 2. Documentation functions (no dependencies)
show_help() { ... }

# 3. Helper/utility functions (used by validation and business logic)
yn() { ... }
noarg() { ... }

# 4. Validation functions (check prerequisites, dependencies)
check_root() { ... }
check_prerequisites() { ... }
check_builtin_support() { ... }

# 5. Business logic functions (domain-specific operations)
build_standalone() { ... }
build_builtin() { ... }
install_standalone() { ... }
install_builtin() { ... }
install_completions() { ... }
update_man_database() { ... }

# 6. Orchestration/flow functions
show_completion_message() { ... }
uninstall_files() { ... }

# 7. Main function (highest level - orchestrates everything)
main() {
  check_root
  check_prerequisites

  if ((UNINSTALL)); then
    uninstall_files
    return 0
  fi

  build_standalone
  ((INSTALL_BUILTIN)) && build_builtin

  install_standalone
  install_completions
  ((INSTALL_BUILTIN)) && install_builtin

  update_man_database
  show_completion_message
}

main "$@"
#fin
```

**Rationale:** This bottom-up organization means each function can safely call functions defined above it. Readers can understand low-level primitives first, then see how they're composed into higher-level operations.

**Guidelines:**
- Group related functions with section comments (e.g., `# Validation functions`)
- Within each group, order alphabetically or by logical dependency
- Keep `main()` last (before the invocation line)
- Dependencies flow downward: higher functions call lower functions, never upward

## Error Handling

### Exit on Error
```bash
set -euo pipefail
# -e: Exit on command failure
# -u: Exit on undefined variable
# -o pipefail: Exit on pipe failure
```

### Exit Codes
```bash
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }
die 0                    # Success (or use `exit 0`)
die 1                    # Exit 1 with no error message
die 1 'General error'    # General error
die 2 'Missing argument' # Missing argument
die 22 'Invalid option'  # Invalid argument
```

### Trap Handling
```bash
cleanup() {
  local -i exitcode=${1:-0}
  # Cleanup operations
  #...
  exit "$exitcode"
}
trap 'cleanup $?' SIGINT SIGTERM EXIT
```

### Error Suppression
```bash
# Suppress errors when appropriate
command 2>/dev/null || true
```

## Control Flow

### Conditionals
```bash
# Always use [[ ]] over [ ]
[[ -d "$path" ]] && echo 'Directory exists'

# Arithmetic conditionals use (())
((VERBOSE==0)) || echo 'Verbose mode'
((var > 5)) || return 1

# Complex conditionals
if [[ -n "$var" ]] && ((count > 0)); then
  process_data
fi

# Short-circuit evaluation
[[ -f "$file" ]] && source "$file"
((VERBOSE)) || return 0
```

### Case Statements

#### Compact Format
For simple, single-action cases:

```bash
while (($#)); do
  case "$1" in
    -v|--verbose) VERBOSE+=1 ;;
    -q|--quiet)   VERBOSE=0 ;;
    -h|--help)    show_help; exit 0 ;;
    -[vqh]*) #shellcheck disable=SC2046 #split up single options
                  set -- '' $(printf -- "-%c " $(grep -o . <<<"${1:1}")) "${@:2}" ;;
    -*)           die 22 "Invalid option '$1'" ;;
    *)            Paths+=("$1") ;;
  esac
  shift
done
```

#### Expanded Format
For multi-line actions or complex logic, use expanded format with column alignment:

```bash
while (($#)); do
  case $1 in
    --builtin)    INSTALL_BUILTIN=1
                  BUILTIN_EXPLICITLY_REQUESTED=1
                  ;;
    --no-builtin) SKIP_BUILTIN=1
                  ;;
    --prefix)     shift
                  PREFIX="$1"
                  BIN_DIR="$PREFIX"/bin
                  LOADABLE_DIR="$PREFIX"/lib/bash/loadables
                  # Comments within case branches allowed
                  ;;
    -V|--version) echo "$SCRIPT_NAME $VERSION"
                  exit 0
                  ;;
    -h|--help)    show_help
                  exit 0
                  ;;
    -[Vh]*) #shellcheck disable=SC2046
                  set -- '' $(printf -- '-%c ' $(grep -o . <<<"${1:1}")) "${@:2}"
                  ;;
    -*)           die 22 "Invalid option '$1'"
                  ;;
    *)            >&2 show_help
                  die 2 "Unknown option '$1'"
                  ;;
  esac
  shift
done
```

**Formatting guidelines:**
- Align actions at column 14-18 for readability
- Use blank lines between `;;` and next pattern for multi-line actions
- Comments within branches are acceptable
- Omit quotes on `$1` in `case $1 in` (one-word literal exception)
- Choose compact or expanded consistently within a script
```

### Loops
```bash
# For loops with arrays
for spec in "${Specs[@]}"; do
  find_expr+=(-name "$spec" -o)
done

# While loops for argument parsing
while (($#)); do
  case "$1" in
    # ... ;;
  esac
  shift
done

# Reading command output
readarray -t found_files < <(find ... 2>/dev/null || true)
```

### Pipes to While
Prefer process substitution or `readarray` instead of piping to while.

```bash
# Good - process substitution
while IFS= read -r line; do
  echo "$line"
done < <(my_command)

# Good - readarray
readarray -t my_array < <(my_command)

# Bad - creates subshell where variables don't persist
my_command | while read -r line; do
  echo "$line"
done
```

## String Operations

### Parameter Expansion
```bash
SCRIPT_NAME=${SCRIPT_PATH##*/} # Remove longest prefix pattern
SCRIPT_DIR=${SCRIPT_PATH%/*}   # Remove shortest suffix pattern
${var:-default}                # Default value
${var:0:1}                     # Substring
${#array[@]}                   # Array length
${var,,}                       # Lowercase conversion
"${@:2}"                       # All args starting from 2nd
```

### Variable Expansion Guidelines

**General Rule:** Always quote variables with `"$var"` as the default form. Only use braces `"${var}"` when syntactically necessary.

**Rationale:** Braces add visual noise without providing value when not required. Using them only when necessary makes code cleaner and the necessary cases stand out.

#### When Braces Are REQUIRED

1. **Parameter expansion operations:**
   ```bash
   "${var##*/}"      # Remove longest prefix pattern
   "${var%/*}"       # Remove shortest suffix pattern
   "${var:-default}" # Default value
   "${var:0:5}"      # Substring
   "${var//old/new}" # Pattern substitution
   "${var,,}"        # Case conversion
   ```

2. **Variable concatenation (no separator):**
   ```bash
   "${var1}${var2}${var3}"  # Multiple variables joined
   "${prefix}suffix"         # Variable immediately followed by alphanumeric
   ```

3. **Array access:**
   ```bash
   "${array[index]}"         # Array element access
   "${array[@]}"             # All array elements
   "${#array[@]}"            # Array length
   ```

4. **Special parameter expansion:**
   ```bash
   "${@:2}"                  # Positional parameters starting from 2nd
   "${10}"                   # Positional parameters beyond $9
   "${!var}"                 # Indirect expansion
   ```

#### When Braces Are NOT Required

**Default form for standalone variables:**
```bash
# Correct - use simple form
"$var"
"$HOME"
"$SCRIPT_DIR"
"$1" "$2" ... "$9"

# Wrong - unnecessary braces
"${var}"                    # ✗ Don't do this
"${HOME}"                   # ✗ Don't do this
"${SCRIPT_DIR}"             # ✗ Don't do this
```

**Path concatenation with separators:**
```bash
# Correct - quotes handle the concatenation
"$PREFIX"/bin               # When separate arguments
"$PREFIX/bin"               # When single string
"$SCRIPT_DIR"/build/lib/file.so

# Wrong - unnecessary braces
"${PREFIX}"/bin             # ✗ Unnecessary
"${PREFIX}/bin"             # ✗ Unnecessary
"${SCRIPT_DIR}"/build/lib   # ✗ Unnecessary
```

**Variable usage in strings:**
```bash
# Correct
echo "Installing to $PREFIX/bin"
info "Found $count files"
"$VAR/path" "in command arguments"

# Wrong - unnecessary braces
echo "Installing to ${PREFIX}/bin"  # ✗ Slash separates, braces not needed
info "Found ${count} files"         # ✗ Space separates, braces not needed
"${VAR}/path"                       # ✗ Slash separates, braces not needed
```

**In conditionals:**
```bash
# Correct
[[ -d "$path" ]]
[[ -f "$SCRIPT_DIR"/file ]]
if [[ "$var" == 'value' ]]; then

# Wrong
[[ -d "${path}" ]]          # ✗ Unnecessary
[[ -f "${SCRIPT_DIR}"/file ]] # ✗ Unnecessary
```

#### Edge Cases and Special Situations

**When next character is alphanumeric AND no separator:**
```bash
# Braces required - ambiguous without them
"${var}_suffix"             # ✓ Correct - prevents $var_suffix interpretation
"${prefix}123"              # ✓ Correct - prevents $prefix123 interpretation

# No braces needed - separator present
"$var-suffix"               # ✓ Correct - dash is separator
"$var.suffix"               # ✓ Correct - dot is separator
"$var/path"                 # ✓ Correct - slash is separator
```

**Multiple variables in echo/info commands:**
```bash
# Correct - no braces needed in strings
echo "Binary: $BIN_DIR/file"
echo "Version $VERSION installed to $PREFIX"
info "Processing $count items from $source_dir"

# Wrong - unnecessary braces
echo "Binary: ${BIN_DIR}/file"              # ✗ Unnecessary
echo "Version ${VERSION} installed to ${PREFIX}"  # ✗ Unnecessary
```

#### Summary Table

| Situation | Form | Example |
|-----------|------|---------|
| Standalone variable | `"$var"` | `"$HOME"` |
| Path with separator | `"$var"/path` or `"$var/path"` | `"$BIN_DIR"/file` |
| Parameter expansion | `"${var%pattern}"` | `"${path%/*}"` |
| Concatenation (no separator) | `"${var1}${var2}"` | `"${prefix}${suffix}"` |
| Array access | `"${array[i]}"` | `"${args[@]}"` |
| In echo/info strings | `"$var"` | `echo "File: $path"` |
| Conditionals | `"$var"` | `[[ -f "$file" ]]` |

**Key Principle:** Use `"$var"` by default. Only add braces when the shell requires them for correct parsing.

### Quoting Rules

**General Principle:** Use single quotes (`'...'`) for static string literals. Use double quotes (`"..."`) only when variable expansion, command substitution, or escape sequences are needed.

**Rationale:** Single quotes prevent any interpretation by the shell, making them safer and clearer for literal strings. Double quotes should signal "this string needs shell processing" to both programmers and AI assistants.

#### Static Strings and Constants

Always use single quotes for string literals that contain no variables:

```bash
# Message functions - single quotes for static strings
info 'Checking prerequisites...'
success 'Prerequisites check passed'
warn 'bash-builtins package not found'
error 'Failed to install package'

# Variable assignments
SCRIPT_DESC='Mail Tools Installation Script'
DEFAULT_PATH='/usr/local/bin'
MESSAGE='Operation completed successfully'

# Conditionals with static strings
[[ "$status" == 'success' ]]     # ✓ Correct
[[ "$status" == "success" ]]     # ✗ Unnecessary double quotes
```

#### Exception: One-Word Literals

Literal one-word values (containing only alphanumeric characters, underscores, hyphens, dots, or slashes—no spaces or special shell characters) may be left unquoted in variable assignments and simple conditionals:

```bash
# Variable assignments - one-word literals can be unquoted
ORGANIZATION=Okusi
LOG_LEVEL=INFO
DEFAULT_PATH=/usr/local/bin
FILE_EXT=.tmp

# Also correct with quotes (more defensive)
ORGANIZATION='Okusi'
LOG_LEVEL='INFO'

# Conditionals - one-word literals can be unquoted
[[ $ORGANIZATION == Okusi ]]
[[ $status == success ]]
[[ $ext == .txt ]]

# Also correct with quotes (recommended for consistency)
[[ $ORGANIZATION == 'Okusi' ]]
[[ $status == 'success' ]]

# Path construction with unquoted literals
tempfile="$PWD"/.foobar.tmp
config_dir="$HOME"/.config/myapp
backup="$filename".bak

# Multi-word or values with spaces MUST be quoted
MESSAGE='Hello world'              # ✓ Correct - contains space
[[ "$var" == 'hello world' ]]      # ✓ Correct - contains space
ERROR_MSG='File not found'         # ✓ Correct - contains spaces
```

**Recommendation:** While unquoted one-word literals are permitted and common, using quotes is more defensive and consistent. Choose based on your team's preference, but be consistent within a script.

#### Strings with Variables

Use double quotes when the string contains variables that need expansion:

```bash
# Message functions with variables
die 1 "Unknown option '$1'"
error "'$compiler' not found"
info "Installing to $PREFIX/bin"
success "Processed $count files"

# Echo statements with variables
echo "$SCRIPT_NAME $VERSION"
echo "Binary: $BIN_DIR/mailheader"
echo "Completion: $COMPLETION_DIR/mail-tools"

# Multi-line messages with variables
info '[DRY-RUN] Would install:' \
     "  $BIN_DIR/mailheader" \
     "  $BIN_DIR/mailmessage" \
     "  $LIB_DIR/mailheader.so"
```

#### Mixed Quoting

When a string contains both static text and variables, use double quotes with single quotes nested for literal protection:

```bash
# Protect literal quotes around variables
die 2 "Unknown option '$1'"              # Single quotes are literal
die 1 "'gcc' compiler not found."        # 'gcc' shows literally with quotes
warn "Cannot access '$file_path'"        # Path shown with quotes

# Complex messages
info "Would remove: '$old_file' → '$new_file'"
error "Permission denied for directory '$dir_path'"
```

#### Command Substitution in Strings

Use double quotes when including command substitution:

```bash
# Command substitution requires double quotes
echo "Current time: $(date +%T)"
info "Found $(wc -l < "$file") lines"
die 1 "Checksum failed: expected $expected, got $(sha256sum "$file")"

# Assign with command substitution
VERSION="$(git describe --tags 2>/dev/null || echo 'unknown')"
TIMESTAMP="$(date -Ins)"
```

#### Variables in Conditionals

Always quote variables in test expressions (regardless of single/double quote choice for static strings):

```bash
# Always quote variables in conditionals
[[ -d "$path" ]]                         # ✓ Correct
[[ -d $path ]]                           # ✗ Wrong - word splitting danger

# Static comparison values - multiple acceptable forms
[[ "$var" == 'value' ]]                  # ✓ Correct - var quoted, static value in single quotes
[[ "$var" == value ]]                    # ✓ Also correct - one-word literal unquoted
[[ "$var" == "value" ]]                  # ✗ Unnecessary - static value doesn't need double quotes
```

#### Array Expansions

Always quote array expansions with double quotes:

```bash
# Quote array expansions
"${array[@]}"                  # All elements as separate words
"${array[*]}"                  # All elements as single word (space-separated)

# Array iteration
for item in "${items[@]}"; do
  process "$item"
done

# Function arguments from array
my_function "${args[@]}"
```

#### Here Documents

Use appropriate quoting for here documents based on whether expansion is needed:

```bash
# No expansion - single quotes on delimiter
cat <<'EOF'
This text is literal.
$VAR is not expanded.
$(command) is not executed.
EOF

# With expansion - no quotes on delimiter
cat <<EOF
Script: $SCRIPT_NAME
Version: $VERSION
Time: $(date)
EOF

# With expansion - double quotes on delimiter (same as no quotes)
cat <<"EOF"     # Note: double quotes same as no quotes for here docs
Script: $SCRIPT_NAME
EOF
```

#### Echo and Printf Statements

```bash
# Static strings - single quotes
echo 'Installation complete'
printf '%s\n' 'Processing files'

# With variables - double quotes
echo "$SCRIPT_NAME $VERSION"
echo "Installing to $PREFIX/bin"
printf 'Found %d files in %s\n' "$count" "$dir"

# Mixed content
echo "  • Binary: $BIN_DIR/mailheader"
echo "  • Version: $VERSION (released $(date))"
```

#### Summary Reference

| Content Type | Quote Style | Example |
|--------------|-------------|---------|
| Static string | Single `'...'` | `info 'Starting process'` |
| One-word literal (assignment) | Optional quotes | `VAR=value` or `VAR='value'` |
| One-word literal (conditional) | Optional quotes | `[[ $x == value ]]` or `[[ $x == 'value' ]]` |
| String with variable | Double `"..."` | `info "Processing $file"` |
| Variable in string | Double `"..."` | `echo "Count: $count"` |
| Literal quotes in string | Double with nested single | `die 1 "Unknown '$1'"` |
| Command substitution | Double `"..."` | `echo "Time: $(date)"` |
| Variables in conditionals | Double `"$var"` | `[[ -f "$file" ]]` |
| Static in conditionals | Single `'...'` or unquoted | `[[ "$x" == 'value' ]]` or `[[ "$x" == value ]]` |
| Array expansion | Double `"${arr[@]}"` | `for i in "${arr[@]}"` |
| Here doc (no expansion) | Single on delimiter | `cat <<'EOF'` |
| Here doc (with expansion) | No quotes on delimiter | `cat <<EOF` |

#### Anti-Patterns (What NOT to Do)

```bash
# ✗ Don't use double quotes for static strings
info "Checking prerequisites..."        # Wrong - no variables, use single quotes
success "Operation completed"            # Wrong - use 'Operation completed'
ERROR_MSG="File not found"              # Wrong - use 'File not found'

# ✗ Don't forget to quote variables
[[ -f $file ]]                          # Wrong - word splitting danger
for path in ${paths[@]}; do             # Wrong - must quote array expansion
echo $VAR/path                          # Wrong - must quote variable

# ✗ Don't use unnecessary braces AND double quotes together
info "${PREFIX}/bin"                    # Wrong on two counts - use "$PREFIX/bin"
echo "File: ${filename}"                # Wrong - use "File: $filename"

# ✓ Correct versions
info 'Checking prerequisites...'
success 'Operation completed'
ERROR_MSG='File not found'
[[ -f "$file" ]]
for path in "${paths[@]}"; do
echo "$VAR/path"
info "$PREFIX/bin"
echo "File: $filename"
```

**Key Principle:** Single quotes mean "literal text", double quotes mean "process this". Use the simplest form that works correctly.

### String Trimming
```bash
trim() {
  local v="$*"
  v="${v#"${v%%[![:blank:]]*}"}"
  echo -n "${v%"${v##*[![:blank:]]}"}"
}
```

### Display Declared Variables
```bash
decp() { declare -p "$@" | sed 's/^declare -[a-zA-Z-]* //'; }
```

### Pluralisation Helper
```bash
s() { (( ${1:-1} == 1 )) || echo -n 's'; }
```

## Arrays

### Array Declaration and Usage
```bash
# Indexed arrays
declare -a DELETE_FILES=('*~' '~*' '.~*')
local -a Paths=()

# Adding elements
Paths+=("$1")
add_specs+=("$spec")

# Array iteration
for path in "${Paths[@]}"; do
  process "$path"
done

# Array length
((${#Paths[@]})) || Paths=('.')

# Reading into array
IFS=',' read -ra ADD_SPECS <<< "$1"
readarray -t found_files < <(command)

# Unset array element
unset 'find_expr[${#find_expr[@]}-1]'
```

### Arrays for Safe List Handling
Use arrays to store lists of elements safely, especially for command arguments.

```bash
# Declare arrays explicitly
declare -a Elements
declare -- element

# Initialize and iterate
Elements=(one two three)
for element in "${Elements[@]}"; do
  echo "$element"
done

# Arrays for command arguments - avoids quoting issues
declare -a cmd_args
cmd_args=( -o "$output" --verbose )
mycmd "${cmd_args[@]}"
```

## Command-Line Arguments

### Standard Argument Parsing Pattern
```bash
while (($#)); do case "$1" in
  -a|--add)       noarg "$@"; shift
                  process_argument "$1" ;;
  -m|--depth)     noarg "$@"; shift
                  max_depth="$1" ;;
  -L|--follow-symbolic)
                  symbolic='-L' ;;
  -p|--prompt)    PROMPT=1; VERBOSE=1 ;;
  -v|--verbose)   VERBOSE+=1 ;;
  -q|--quiet)     VERBOSE=0 ;;
  -V|--version)   echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
  -h|--help)      show_help; exit 0 ;;
  -[amLpvqVh]*) #shellcheck disable=SC2046 #split up single options
                  set -- '' $(printf -- "-%c " $(grep -o . <<<"${1:1}")) "${@:2}" ;;
  -*)             die 22 "Invalid option '$1'" ;;
  *)              Paths+=("$1") ;;
esac; shift; done
```

### Argument Validation
```bash
noarg() {
  if (($# < 2)) || [[ ${2:0:1} == '-' ]]; then
    die 2 "Missing argument for option '$1'"
  fi
  return 0
}
```

### Argument Parsing Location

**Recommendation:** Place argument parsing inside the `main()` function rather than at the top level.

**Benefits:**
- Better testability (can test `main()` with different arguments)
- Cleaner variable scoping (parsing vars are local to `main()`)
- Encapsulation (argument handling is part of main execution flow)
- Easier to mock/test in unit tests

```bash
# Recommended: Parsing inside main()
main() {
  # Parse command-line arguments
  while (($#)); do
    case $1 in
      --builtin)    INSTALL_BUILTIN=1
                    BUILTIN_EXPLICITLY_REQUESTED=1
                    ;;
      --no-builtin) SKIP_BUILTIN=1
                    ;;
      --prefix)     shift
                    PREFIX="$1"
                    # Update derived paths
                    BIN_DIR="$PREFIX"/bin
                    LOADABLE_DIR="$PREFIX"/lib/bash/loadables
                    ;;
      -h|--help)    show_help
                    exit 0
                    ;;
      -*)           die 22 "Invalid option '$1'"
                    ;;
      *)            >&2 show_help
                    die 2 "Unknown option '$1'"
                    ;;
    esac
    shift
  done

  # Proceed with main logic
  check_prerequisites
  build_components
  install_components
}

main "$@"
#fin
```

**Alternative:** For very simple scripts (< 40 lines) without a `main()` function, top-level parsing is acceptable:

```bash
#!/bin/bash
set -euo pipefail

# Simple scripts can parse at top level
while (($#)); do case "$1" in
  -v|--verbose) VERBOSE=1 ;;
  -h|--help)    show_help; exit 0 ;;
  -*)           die 22 "Invalid option '$1'" ;;
  *)            FILES+=("$1") ;;
esac; shift; done

# Rest of simple script logic
```

## Output and Messaging

### Standardized Messaging and Color Support
```bash
declare -i VERBOSE=1 PROMPT=1 DEBUG=0
# Standard colors
[[ -t 1 && -t 2 ]] && declare -- RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m' || declare -- RED='' GREEN='' YELLOW='' CYAN='' NC=''
readonly -- RED GREEN YELLOW CYAN NC
```

### STDOUT vs STDERR
- All error messages should go to `STDERR`
- Place `>&2` at the *beginning* commands for clarity

```bash
# Preferred format
somefunc() {
  >&2 echo "[$(date -Ins)]: $*"
}

# Also acceptable
somefunc() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}
```

### Core Message Functions
```bash
# Core message function using FUNCNAME for context
_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case "${FUNCNAME[1]}" in
    success) prefix+=" ${GREEN}✓${NC}" ;;
    warn)    prefix+=" ${YELLOW}⚡${NC}" ;;
    info)    prefix+=" ${CYAN}◉${NC}" ;;
    error)   prefix+=" ${RED}✗${NC}" ;;
    debug)   prefix+=" ${YELLOW}DEBUG${NC}:" ;;
    *)       ;;
  esac
  for msg in "$@"; do printf '%s %s\n' "$prefix" "$msg"; done
}
# Conditional output based on verbosity
vecho() { ((VERBOSE)) || return 0; _msg "$@"; }
success() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
debug() { ((DEBUG)) || return 0; >&2 _msg "$@"; }
# Unconditional output
error() { >&2 _msg "$@"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }
# yes/no
yn() {
  ((PROMPT)) || return 0
  local -- reply
  >&2 read -r -n 1 -p "$SCRIPT_NAME: ${YELLOW}$1${NC} y/n " reply
  >&2 echo
  [[ ${reply,,} == y ]]
}
```

### Usage Documentation
```bash
show_help() {
  cat <<EOT
$SCRIPT_NAME $VERSION - Brief description

Detailed description.

Usage: $SCRIPT_NAME [Options] [arguments]

Options:
  -h|--help         This help message
  -v|--verbose      Enable verbose output

Examples:
  # Example 1
  $SCRIPT_NAME -v file.txt
EOT
  return 0
}
```

### Echo vs Messaging Functions

Choose between plain `echo` and messaging functions based on the context and formatting requirements:

**Use messaging functions (`info`, `success`, `warn`, `error`) for:**
- Single-line status updates during script execution
- Progress indicators
- Error and warning messages
- Messages that should respect verbosity settings
- Messages that benefit from visual formatting (colors, icons)

```bash
info 'Checking prerequisites...'
success 'Installation complete'
warn 'bash-builtins package not found'
error 'Failed to build binary'

# Multi-line messaging with continuation
info '[DRY-RUN] Would install:' \
     "  $BIN_DIR/mailheader" \
     "  $BIN_DIR/mailmessage"
```

**Use plain `echo` for:**
- Multi-paragraph formatted output
- Help text and documentation
- Structured output intended for parsing
- Complex formatting with multiple echo statements
- Output that should always display regardless of verbosity

```bash
# Multi-paragraph completion message
show_completion_message() {
  echo
  success 'Installation complete!'
  echo
  echo 'Installed files:'
  echo "  • Standalone binaries: $BIN_DIR/mailheader"
  echo "  • Scripts:             $BIN_DIR/mailgetaddresses"
  echo "  • Manpages:            $MAN_DIR/mailheader.1"
  echo
  echo 'Verify installation:'
  echo '  which mailheader'
  echo '  man mailheader'
  echo
}
```

**Rationale:** Messaging functions provide consistent formatting, verbosity control, and visual indicators (colors, icons). Plain `echo` is better for structured multi-line output where you need precise control over formatting and spacing.

## File Operations

### Safe File Testing
```bash
[[ -d "$path" ]] || die 1 "Not a directory '$path'"
[[ -f "$file" ]] && source "$file"
[[ -r "$file" ]] || warn "Cannot read '$file'"
```

### Wildcard Expansion
Always use explicit path when doing wildcard expansion to avoid issues with filenames starting with `-`.

```bash
# Correct - explicit path prevents flag interpretation
rm -v ./*
for file in ./*.txt; do
  process "$file"
done

# ✗ Incorrect - filenames starting with - become flags
rm -v *
```

### Process Substitution
```bash
# Compare command outputs
diff <(sort file1) <(sort file2)

# Read command output into array
readarray -t array < <(command)

# Process lines from command
while IFS= read -r line; do
  process "$line"
done < <(command)
```

### Here Documents
Use for multi-line strings or input.

```bash
# No variable expansion (note single quotes)
cat <<'EOF'
This is a multi-line
string with no variable
expansion.
EOF

# With variable expansion
cat <<EOF
User: $USER
Home: $HOME
EOF
```

## Calling Commands

### Checking Return Values
Always check return values and give informative error messages.

```bash
# Explicit check with informative error
if ! mv "$file_list" "$dest_dir/"; then
  >&2 echo "Unable to move $file_list to $dest_dir"
  exit 1
fi

# Simple cases with ||
mv "$file_list" "$dest_dir/" || die 1 'Failed to move files'

# Group commands for error handling
mv "$file_list" "$dest_dir/" || {
  >&2 echo "Move failed: $file_list -> $dest_dir"
  cleanup
  exit 1
}
```

### Builtin Commands vs External Commands
Always prefer shell builtins over external commands for performance.

```bash
# Good - bash builtins
addition=$((x + y))
string=${var^^}  # uppercase
if [[ -f "$file" ]]; then

# Avoid - external commands
addition=$(expr "$x" + "$y")
string=$(echo "$var" | tr '[:lower:]' '[:upper:]')
if [ -f "$file" ]; then
```

### Readonly Declaration
Use `readonly` for constants to prevent accidental modification.

```bash
readonly -- SCRIPT_PATH="$(readlink -en -- "$0")"
readonly -a REQUIRED=(pandoc git md2ansi)
```

## Security Considerations

### SUID/SGID
- **Never** use SUID/SGID in Bash scripts
- Too many security vulnerabilities possible
- Use `sudo` to provide elevated access when needed

### PATH Security
Lock down PATH to prevent command injection and trojan attacks.

```bash
# Lock down PATH at script start
readonly PATH='/usr/local/bin:/usr/bin:/bin'
export PATH

# Or validate existing PATH
[[ "$PATH" =~ \. ]] && die 1 'PATH contains current directory'
[[ "$PATH" =~ ^: ]] && die 1 'PATH starts with empty element'
[[ "$PATH" =~ :: ]] && die 1 'PATH contains empty element'
[[ "$PATH" =~ :$ ]] && die 1 'PATH ends with empty element'
```

### IFS Manipulation Safety
When changing IFS, always save and restore it.

```bash
# Save and restore IFS
OLD_IFS="$IFS"
IFS=$'\n'
# ... operations requiring newline separator ...
IFS="$OLD_IFS"

# Or use subshell to isolate IFS changes
(
  IFS=','
  read -ra array <<< "$csv_data"
  # IFS change limited to subshell
)
```

### Eval Command
`eval` should be avoided wherever possible due to security risks.

```bash
# Dangerous - avoid
eval "$user_input"

# Safer alternatives
# Use indirect expansion for variable references
var_name=HOME
echo "${!var_name}"

# Use arrays for building commands
declare -a cmd=(ls -la "$dir")
"${cmd[@]}"
```

## Best Practices

### 1. Indentation
- !! Use 2 spaces for indentation (NOT tabs)
- Maintain consistent indentation throughout

### 2. Line Length
- Keep lines under 100 characters when practical
- Long file paths and URLs can exceed 100 chars when necessary
- Use line continuation with `\` for long commands

### 3. Comments

Focus comments on explaining **WHY** (rationale, business logic, non-obvious decisions) rather than **WHAT** (which the code already shows):

```bash
# Section separator (80 dashes)
# --------------------------------------------------------------------------------

# ✓ Good - explains WHY (rationale and special cases)
# PROFILE_DIR intentionally hardcoded to /etc/profile.d for system-wide bash profile
# integration, regardless of PREFIX. This ensures builtins are available in all
# user sessions. To override, modify this line or use a custom install method.
declare -- PROFILE_DIR=/etc/profile.d

((max_depth > 0)) || max_depth=255  # -1 means unlimited (WHY -1 is special)

# If user explicitly requested --builtin, try to install dependencies
if ((BUILTIN_EXPLICITLY_REQUESTED)); then
  warn 'bash-builtins package not found, attempting to install...'
fi

# ✗ Bad - restates WHAT the code already shows
# Set PROFILE_DIR to /etc/profile.d
declare -- PROFILE_DIR=/etc/profile.d

# Check if max_depth is greater than 0, otherwise set to 255
((max_depth > 0)) || max_depth=255

# If BUILTIN_EXPLICITLY_REQUESTED is non-zero
if ((BUILTIN_EXPLICITLY_REQUESTED)); then
  # Print warning message
  warn 'bash-builtins package not found, attempting to install...'
fi
```

**Good comment patterns:**
- Explain non-obvious business rules or edge cases
- Document intentional deviations from normal patterns
- Clarify complex logic that isn't immediately apparent
- Note why a specific approach was chosen over alternatives
- Warn about subtle gotchas or side effects

**Avoid commenting:**
- Simple variable assignments
- Obvious conditionals
- Standard patterns already documented in this style guide
- Code that is self-explanatory through good naming
```

### 3a. Blank Line Usage

Use blank lines strategically to improve readability by creating visual separation between logical blocks:

```bash
#!/bin/bash
set -euo pipefail

# Script metadata
VERSION='1.0.0'
SCRIPT_PATH=$(readlink -en -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR
                                          # ← Blank line after metadata group

# Default values                          # ← Blank line before section comment
declare -- PREFIX=/usr/local
declare -i DRY_RUN=0
                                          # ← Blank line after variable group

# Derived paths
declare -- BIN_DIR="$PREFIX"/bin
declare -- LIB_DIR="$PREFIX"/lib
                                          # ← Blank line before function
check_prerequisites() {
  info 'Checking prerequisites...'

  # Check for gcc                         # ← Blank line after info call
  if ! command -v gcc &> /dev/null; then
    die 1 "'gcc' compiler not found."
  fi

  success 'Prerequisites check passed'    # ← Blank line between checks
}
                                          # ← Blank line between functions
main() {
  check_prerequisites
  install_files
}

main "$@"
#fin
```

**Guidelines:**
- One blank line between functions
- One blank line between logical sections within functions
- One blank line after section comments
- One blank line between groups of related variables
- Blank lines before and after multi-line conditional or loop blocks
- Avoid multiple consecutive blank lines (one is sufficient)
- No blank line needed between short, related statements

### 3b. Section Comments

Use lightweight section comments to organize code into logical groups. These are simpler than full 80-dash separators and provide just enough context:

```bash
# Default values
declare -- PREFIX=/usr/local
declare -i VERBOSE=1
declare -i DRY_RUN=0

# Derived paths
declare -- BIN_DIR="$PREFIX"/bin
declare -- LIB_DIR="$PREFIX"/lib
declare -- DOC_DIR="$PREFIX"/share/doc

# Core message function
_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  # ...
}

# Conditional messaging functions
vecho() { ((VERBOSE)) || return 0; _msg "$@"; }
success() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }

# Unconditional messaging functions
error() { >&2 _msg "$@"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }
```

**Guidelines:**
- Use simple `# Description` format (no dashes, no box drawing)
- Keep section comments short and descriptive (2-4 words typically)
- Place section comment immediately before the group it describes
- Follow with a blank line after the group (before next section)
- Use for grouping related variables, functions, or logical blocks
- Reserve 80-dash separators for major script divisions only

**Common section comment patterns:**
- `# Default values` / `# Configuration`
- `# Derived paths` / `# Computed variables`
- `# Core message function`
- `# Conditional messaging functions` / `# Unconditional messaging functions`
- `# Helper functions` / `# Utility functions`
- `# Business logic` / `# Main logic`
- `# Validation functions` / `# Installation functions`

### 4. Arithmetic Operations
```bash
# Always declare integer variables explicitly
declare -i i j result

# Increment operations - avoid ++ due to return value issues
i+=1              # **Preferred** for declared integers
((i+=1))          # Always returns 0 (success)
((++i))           # Returns value AFTER increment (safe)
((i++))           # DANGEROUS: Returns value BEFORE increment
                  # If i=0, returns 0 (falsey), triggers set -e
                  # Example: i=0; ((i++)) && echo "never prints"

# Arithmetic expressions
((result = x * y + z))
j=$((i * 2 + 5))

# Arithmetic conditionals
if ((i < j)); then
  echo 'i is less than j'
fi

# Short-form evaluation
((x > y)) && echo 'x is greater'
```

### 5. Command Substitution
```bash
# Always use $() instead of backticks
var=$(command)       # Correct
var=`command`        # ✗ Wrong!
```

### 6. ShellCheck Compliance
ShellCheck is **compulsory** for all scripts. Use `#shellcheck disable=...` only for documented exceptions.

```bash
# Document intentional violations with reason
#shellcheck disable=SC2046  # Intentional word splitting for flag expansion
set -- '' $(printf -- "-%c " $(grep -o . <<<"${1:1}")) "${@:2}"

# Run shellcheck as part of development
shellcheck -x myscript.sh
```

### 7. Script Termination
```bash
# Always end scripts with #fin marker
main "$@"
#fin

```

### 8. Defensive Programming
```bash
# Default values for critical variables
: "${VERBOSE:=0}"
: "${DEBUG:=0}"

# Validate inputs early
[[ -n "$1" ]] || die 1 'Argument required'

# Guard against unset variables
set -u
```

### 9. Performance Considerations
```bash
# Minimize subshells
# Use built-in string operations over external commands
# Batch operations when possible
# Use process substitution over temp files
```

### 10. Testing Support
```bash
# Make functions testable
# Use dependency injection for external commands
# Support verbose/debug modes
# Return meaningful exit codes
```

## Summary

This coding style emphasizes:
- **Robustness**: Strict error handling, proper quoting, defensive programming
- **Readability**: Clear structure, consistent naming, good documentation
- **Maintainability**: Modular functions, proper scoping, standardized patterns
- **Performance**: Efficient constructs, minimal subshells, built-in operations

Follow these guidelines to ensure consistent, robust, reliable, and maintainable Bash scripts.

## Advanced Topics

### Debugging and Development

Enable debugging features for development and troubleshooting.

```bash
# Debug mode implementation
declare -i DEBUG="${DEBUG:-0}"

# Enable trace mode when DEBUG is set
((DEBUG)) && set -x

# Enhanced PS4 for better trace output
export PS4='+ ${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:+${FUNCNAME[0]}():} '

# Conditional debug output function
debug() {
  ((DEBUG)) || return 0
  >&2 _msg "$@"
}

# Usage
DEBUG=1 ./script.sh  # Run with debug output
```

### Dry-Run Pattern

Implement preview mode for operations that modify system state, allowing users to see what would happen without making actual changes.

```bash
# Declare dry-run flag
declare -i DRY_RUN=0

# Parse from command-line
--dry-run|--preview) DRY_RUN=1 ;;

# Pattern: Check flag, show preview message, return early
build_standalone() {
  if ((DRY_RUN)); then
    info '[DRY-RUN] Would build standalone binaries'
    return 0
  fi

  # Actual build operations
  make standalone || die 1 'Build failed'
}

install_standalone() {
  if ((DRY_RUN)); then
    info '[DRY-RUN] Would install:' \
         "  $BIN_DIR/mailheader" \
         "  $BIN_DIR/mailmessage" \
         "  $BIN_DIR/mailheaderclean"
    return 0
  fi

  # Actual installation operations
  install -m 755 build/bin/mailheader "$BIN_DIR/"
  install -m 755 build/bin/mailmessage "$BIN_DIR/"
  install -m 755 build/bin/mailheaderclean "$BIN_DIR/"
}

update_man_database() {
  if ((DRY_RUN)); then
    info '[DRY-RUN] Would update man database'
    return 0
  fi

  # Actual man database update
  mandb -q 2>/dev/null || true
}
```

**Pattern structure:**
1. Check `((DRY_RUN))` at the start of functions that modify state
2. Display preview message with `[DRY-RUN]` prefix using `info`
3. Return early (exit code 0) without performing actual operations
4. Proceed with real operations only when dry-run is disabled

**Benefits:**
- Safe preview of destructive operations
- Users can verify paths, files, and commands before execution
- Useful for debugging installation scripts and system modifications
- Maintains identical control flow (same function calls, same logic paths)

**Rationale:** This pattern separates decision logic from action. The script flows through the same functions whether in dry-run mode or not, making it easy to verify logic without side effects.

### Temporary File Handling

Safe creation and cleanup of temporary files and directories.

```bash
# Safe temporary file creation
TMPFILE=$(mktemp) || die 1 'Failed to create temp file'
trap 'rm -f "$TMPFILE"' EXIT

# Temporary file with custom template
TMPFILE=$(mktemp /tmp/script.XXXXXX) || die 1 'Failed to create temp file'

# Temporary directory
TMPDIR=$(mktemp -d) || die 1 'Failed to create temp directory'
trap 'rm -rf "$TMPDIR"' EXIT

# Multiple temp files with cleanup function
declare -a TEMP_FILES=()
cleanup_temps() {
  local -- file
  for file in "${TEMP_FILES[@]}"; do
    [[ -f "$file" ]] && rm -f "$file"
  done
}
trap cleanup_temps EXIT

# Add temp files to cleanup list
TEMP_FILES+=("$(mktemp)")
```

### Input Sanitization

Validate and sanitize user input to prevent security issues.

```bash
# Validate filename - no directory traversal
sanitize_filename() {
  local -- name="$1"
  # Remove directory traversal attempts
  name="${name//\.\./}"
  name="${name//\//}"
  # Allow only safe characters
  if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    die 1 'Invalid filename: contains unsafe characters'
  fi
  echo "$name"
}

# Validate numeric input
validate_number() {
  local -- input="$1"
  if [[ ! "$input" =~ ^-?[0-9]+$ ]]; then
    die 1 "Invalid number: '$input'"
  fi
  echo "$input"
}

# Validate email format
validate_email() {
  local -- email="$1"
  local -- regex='^[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}$'
  [[ "$email" =~ $regex ]] || die 1 'Invalid email format'
  echo "$email"
}

# Escape special characters for safe display
escape_html() {
  local -- text="$1"
  text="${text//&/&amp;}"
  text="${text//</&lt;}"
  text="${text//>/&gt;}"
  text="${text//\"/&quot;}"
  text="${text//\'/&#39;}"
  echo "$text"
}
```

### Environment Variable Best Practices

Proper handling of environment variables.

```bash
# Required environment validation (script exits if not set)
: "${REQUIRED_VAR:?Environment variable REQUIRED_VAR not set}"
: "${DATABASE_URL:?DATABASE_URL must be set}"

# Optional with defaults
: "${OPTIONAL_VAR:=default_value}"
: "${LOG_LEVEL:=INFO}"

# Export with validation
export DATABASE_URL="${DATABASE_URL:-localhost:5432}"
export API_KEY="${API_KEY:?API_KEY environment variable required}"

# Check multiple required variables
check_required_env() {
  local -a required=(DATABASE_URL API_KEY SECRET_TOKEN)
  local -- var
  for var in "${required[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      die 1 "Required environment variable '$var' not set"
    fi
  done
}
```

### Regular Expression Guidelines

Best practices for using regular expressions in Bash.

```bash
# Use POSIX character classes for portability
[[ "$var" =~ ^[[:alnum:]]+$ ]]      # Alphanumeric only
[[ "$var" =~ [[:space:]] ]]         # Contains whitespace
[[ "$var" =~ ^[[:digit:]]+$ ]]      # Digits only
[[ "$var" =~ ^[[:xdigit:]]+$ ]]     # Hexadecimal

# Store complex patterns in readonly variables
readonly EMAIL_REGEX='^[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}$'
readonly IPV4_REGEX='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
readonly UUID_REGEX='^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$'

# Usage
[[ "$email" =~ $EMAIL_REGEX ]] || die 1 'Invalid email format'

# Capture groups
if [[ "$version" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  major="${BASH_REMATCH[1]}"
  minor="${BASH_REMATCH[2]}"
  patch="${BASH_REMATCH[3]}"
fi
```

### Background Job Management

Managing background processes and jobs.

```bash
# Start background job and track PID
long_running_command &
PID=$!

# Check if process is still running
if kill -0 "$PID" 2>/dev/null; then
  info "Process $PID is still running"
fi

# Wait with timeout
if timeout 10 wait "$PID"; then
  success 'Process completed successfully'
else
  warn 'Process timed out or failed'
  kill "$PID" 2>/dev/null || true
fi

# Multiple background jobs
declare -a PIDS=()
for file in *.txt; do
  process_file "$file" &
  PIDS+=($!)
done

# Wait for all background jobs
for pid in "${PIDS[@]}"; do
  wait "$pid"
done

# Job control with error handling
run_with_timeout() {
  local -i timeout="$1"; shift
  local -- command="$*"

  timeout "$timeout" bash -c "$command" &
  local -i pid=$!

  if wait "$pid"; then
    return 0
  else
    local -i exit_code=$?
    if ((exit_code == 124)); then
      error "Command timed out after ${timeout}s"
    fi
    return "$exit_code"
  fi
}
```

### Logging Best Practices

Structured logging for production scripts.

```bash
# Simple file logging
readonly LOG_FILE="${LOG_FILE:-/var/log/${SCRIPT_NAME}.log}"
readonly LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Ensure log directory exists
[[ -d "${LOG_FILE%/*}" ]] || mkdir -p "${LOG_FILE%/*}"

# Log levels as integers for comparison
declare -A LOG_LEVELS=(
  [DEBUG]=0
  [INFO]=1
  [WARN]=2
  [ERROR]=3
  [FATAL]=4
)

# Structured logging function
log() {
  local -- level="$1"
  local -- message="${*:2}"
  local -i level_int="${LOG_LEVELS[$level]:-1}"
  local -i current_level="${LOG_LEVELS[$LOG_LEVEL]:-1}"

  # Skip if below current log level
  ((level_int >= current_level)) || return 0

  # Format: ISO8601 timestamp, script name, level, message
  printf '[%s] [%s] [%-5s] %s\n' \
    "$(date -Ins)" \
    "$SCRIPT_NAME" \
    "$level" \
    "$message" >> "$LOG_FILE"
}

# Convenience functions
log_debug() { log DEBUG "$@"; }
log_info()  { log INFO "$@"; }
log_warn()  { log WARN "$@"; }
log_error() { log ERROR "$@"; }
log_fatal() { log FATAL "$@"; die 1; }

# Log rotation check
check_log_rotation() {
  local -i max_size=$((10 * 1024 * 1024))  # 10MB
  if [[ -f "$LOG_FILE" ]] && (( $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) > max_size )); then
    mv "$LOG_FILE" "${LOG_FILE}.old"
    log_info 'Log rotated'
  fi
}
```

### Performance Profiling

Simple performance measurement patterns.

```bash
# Using SECONDS builtin
profile_operation() {
  local -- operation="$1"
  SECONDS=0

  # Run operation
  eval "$operation"

  info "Operation completed in ${SECONDS}s"
}

# High-precision timing with EPOCHREALTIME
timer() {
  local -- start end runtime
  start=$EPOCHREALTIME

  "$@"

  end=$EPOCHREALTIME
  runtime=$(awk "BEGIN {print $end - $start}")
  info "Execution time: ${runtime}s"
}

# Memory usage tracking
check_memory() {
  local -i pid="${1:-$$}"
  local -i mem_kb

  if [[ -f "/proc/$pid/status" ]]; then
    mem_kb=$(grep VmRSS "/proc/$pid/status" | awk '{print $2}')
    info "Memory usage: $((mem_kb / 1024))MB"
  fi
}

# Benchmark comparisons
benchmark() {
  local -- name="$1"
  local -i iterations="${2:-100}"
  shift 2

  local -- start end
  start=$EPOCHREALTIME

  for ((i=0; i<iterations; i+=1)); do
    "$@" >/dev/null 2>&1
  done

  end=$EPOCHREALTIME
  local -- total_time=$(awk "BEGIN {print $end - $start}")
  local -- avg_time=$(awk "BEGIN {print $total_time / $iterations}")

  printf '%s: %d iterations, %.3fs total, %.6fs average\n' \
    "$name" "$iterations" "$total_time" "$avg_time"
}
```

### Testing Support Patterns

Patterns for making scripts testable.

```bash
# Dependency injection for testing
declare -f FIND_CMD >/dev/null || FIND_CMD() { find "$@"; }
declare -f DATE_CMD >/dev/null || DATE_CMD() { date "$@"; }
declare -f CURL_CMD >/dev/null || CURL_CMD() { curl "$@"; }

# In production
find_files() {
  FIND_CMD "$@"
}

# In tests, override:
FIND_CMD() { echo 'mocked_file1.txt mocked_file2.txt'; }

# Test mode flag
declare -i TEST_MODE="${TEST_MODE:-0}"

# Conditional behavior for testing
if ((TEST_MODE)); then
  # Use test data directory
  DATA_DIR='./test_data'
  # Disable destructive operations
  RM_CMD() { echo "TEST: Would remove $*"; }
else
  DATA_DIR='/var/lib/app'
  RM_CMD() { rm "$@"; }
fi

# Assert function for tests
assert() {
  local -- expected="$1"
  local -- actual="$2"
  local -- message="${3:-Assertion failed}"

  if [[ "$expected" != "$actual" ]]; then
    >&2 echo "ASSERT FAIL: $message"
    >&2 echo "  Expected: '$expected'"
    >&2 echo "  Actual:   '$actual'"
    return 1
  fi
  return 0
}

# Test runner pattern
run_tests() {
  local -i passed=0 failed=0
  local -- test_func

  # Find all functions starting with test_
  for test_func in $(declare -F | awk '$3 ~ /^test_/ {print $3}'); do
    if "$test_func"; then
      passed+=1
      echo "✓ $test_func"
    else
      failed+=1
      echo "✗ $test_func"
    fi
  done

  echo "Tests: $passed passed, $failed failed"
  ((failed == 0))
}
```

### Progressive State Management

Manage script state by modifying boolean flags based on runtime conditions, separating decision logic from execution.

```bash
# Initial flag declarations
declare -i INSTALL_BUILTIN=0
declare -i BUILTIN_EXPLICITLY_REQUESTED=0
declare -i SKIP_BUILTIN=0

# Parse command-line arguments
main() {
  while (($#)); do
    case $1 in
      --builtin)    INSTALL_BUILTIN=1
                    BUILTIN_EXPLICITLY_REQUESTED=1
                    ;;
      --no-builtin) SKIP_BUILTIN=1
                    ;;
    esac
    shift
  done

  # Progressive state management: adjust flags based on runtime conditions

  # If user explicitly requested to skip, disable installation
  if ((SKIP_BUILTIN)); then
    INSTALL_BUILTIN=0
  fi

  # Check if prerequisites are met, adjust flags accordingly
  if ! check_builtin_support; then
    # If user explicitly requested builtins, try to install dependencies
    if ((BUILTIN_EXPLICITLY_REQUESTED)); then
      warn 'bash-builtins package not found, attempting to install...'
      install_bash_builtins || {
        error 'Failed to install bash-builtins package'
        INSTALL_BUILTIN=0  # Disable builtin installation
      }
    else
      # User didn't explicitly request, just skip
      info 'bash-builtins not found, skipping builtin installation'
      INSTALL_BUILTIN=0
    fi
  fi

  # Build phase: disable on failure
  if ((INSTALL_BUILTIN)); then
    if ! build_builtin; then
      error 'Builtin build failed, disabling builtin installation'
      INSTALL_BUILTIN=0
    fi
  fi

  # Execution phase: actions based on final flag state
  install_standalone
  ((INSTALL_BUILTIN)) && install_builtin  # Only runs if still enabled

  show_completion_message
}
```

**Pattern structure:**
1. Declare all boolean flags at the top with initial values
2. Parse command-line arguments, setting flags based on user input
3. Progressively adjust flags based on runtime conditions:
   - Dependency checks (disable if prerequisites missing)
   - Build/operation failures (disable dependent features)
   - User preferences override system defaults
4. Execute actions based on final flag state

**Real-world example - conditional builtin installation:**
```bash
# Initial state (defaults)
declare -i INSTALL_BUILTIN=0
declare -i BUILTIN_EXPLICITLY_REQUESTED=0
declare -i SKIP_BUILTIN=0

# State progression through script lifecycle:

# 1. User input (--builtin flag)
INSTALL_BUILTIN=1
BUILTIN_EXPLICITLY_REQUESTED=1

# 2. Override check (--no-builtin takes precedence)
((SKIP_BUILTIN)) && INSTALL_BUILTIN=0

# 3. Dependency check (no bash-builtins package)
if ! check_builtin_support; then
  if ((BUILTIN_EXPLICITLY_REQUESTED)); then
    # Try to install, disable on failure
    install_bash_builtins || INSTALL_BUILTIN=0
  else
    # User didn't ask, just disable
    INSTALL_BUILTIN=0
  fi
fi

# 4. Build check (compilation failed)
((INSTALL_BUILTIN)) && ! build_builtin && INSTALL_BUILTIN=0

# 5. Final execution (only runs if INSTALL_BUILTIN=1)
((INSTALL_BUILTIN)) && install_builtin
```

**Benefits:**
- Clean separation between decision logic and action
- Easy to trace how flags change throughout execution
- Fail-safe behavior (disable features when prerequisites fail)
- User intent preserved (`BUILTIN_EXPLICITLY_REQUESTED` tracks original request)
- Idempotent (same input → same state → same output)

**Guidelines:**
- Group related flags together (e.g., `INSTALL_*`, `SKIP_*`)
- Use separate flags for user intent vs. runtime state
- Document state transitions with comments
- Apply state changes in logical order (parse → validate → execute)
- Never modify flags during execution phase (only in setup/validation)

**Rationale:** This pattern allows scripts to adapt to runtime conditions while maintaining clarity about why decisions were made. It's especially useful for installation scripts where features may need to be disabled based on system capabilities or build failures.

#fin
