## General Layouts for Standard Script

**All Bash scripts should ideally follow a specific 13-step structural layout that ensures consistency, maintainability, and correctness. This bottom-up organizational pattern places low-level utilities before high-level orchestration, allowing each component to safely call previously defined functions. The structure is mandatory for all scripts and ensures that error handling, metadata, dependencies, and execution flow are properly established before any business logic runs.**

For detailed examples, anti-patterns, and edge cases, see:
- **BCS010101** - Complete working example (462-line installation script)
- **BCS010102** - Common anti-patterns and corrections
- **BCS010103** - Edge cases and variations

---

## Rationale

**Why enforce a strict 13-step layout?**

1. **Predictability** - Developers (and AI assistants) know exactly where to find specific components in any script. Metadata is always in step 6, utilities in step 9, business logic in step 10, orchestration in step 11.

2. **Safe Initialization** - The ordering ensures that critical infrastructure is established before it's needed: error handling (`set -euo pipefail`) is configured before any commands run, metadata is available before any function executes, and global variables are declared before any code references them.

3. **Bottom-Up Dependency Resolution** - Lower-level components are defined before higher-level ones that depend on them. Messaging functions come before business logic that calls them, business logic comes before `main()` that orchestrates it. Each function can safely call any function defined above it.

4. **Testing and Maintenance** - Consistent structure makes scripts easier to test, debug, and maintain. You can source a script to test individual functions, extract utilities for reuse, or understand unfamiliar code quickly because the structure is standardized.

5. **Error Prevention** - The strict ordering prevents entire classes of errors: using undefined functions, referencing uninitialized variables, or running business logic before error handling is configured. Many subtle bugs are prevented by structure alone.

6. **Documentation Through Structure** - The layout itself documents the script's organization. The progression from infrastructure (steps 1-8) through implementation (steps 9-10) to orchestration (steps 11-12) tells the story of how the script works.

7. **Production Readiness** - The structure includes all elements needed for production scripts: version tracking, proper error handling, terminal detection for output, argument validation, and clear execution flow. Nothing is left to chance.

---
## The 13 Mandatory Steps

### Step 1: Shebang

**First line of every script - specifies the interpreter.**

```bash
#!/bin/bash
```

**Alternatives:**
```bash
#!/usr/bin/bash
```

```bash
#!/usr/bin/env bash
```

Within a module+script program -- one that can be either sourced or executed -- the shebang can be used again to semantically indicate the beginning of the executable part of the file.

**Rationale for `env` approach:**
- Portable across systems where bash may be in different locations
- Respects user's PATH settings
- Standard on modern systems

### Step 2: ShellCheck Directives (if needed)

**Global directives that apply to the entire script.**

```bash
#shellcheck disable=SC2034  # Unused variables OK (sourced by other scripts)
#shellcheck disable=SC1091  # Don't follow sourced files
```

**Always include explanatory comments** for disabled checks.

Only use when necessary - don't disable checks without good reason.

### Step 3: Brief Description Comment

**One-line purpose statement immediately after shebang/directives.**

```bash
# Comprehensive installation script with configurable paths and dry-run mode
```

**Not a full header block** - just a concise description.

### Step 4: `set -euo pipefail`

**Mandatory strict error handling configuration.**

```bash
set -euo pipefail
```

**What this enables:**
- `set -e` - Exit on any command failure
- `set -u` - Exit on undefined variable reference
- `set -o pipefail` - Pipelines fail if any command fails (not just the last)

**This MUST come before any commands** (except shebang/comments/shellcheck).

**Optional Bash >= 5 test**

If a Bash version check is *really* necessary, insert it immediately after `set -euo pipefail`:

```bash
#!/bin/bash
#shellcheck disable=1090
# Backup program for sql databases
set -euo pipefail
((${BASH_VERSINFO[0]:-0} > 4)) || { >&2 echo 'error: Require Bash version >= 5'; exit 95; } # check bash version >= 5

```

Always assume you are working in a Bash 5 environment.

### Step 5: `shopt` Settings

**Strongly recommended shell option settings.**
```bash
shopt -s inherit_errexit shift_verbose extglob nullglob
```

    shopt -s inherit_errexit  # Subshells inherit set -e
    shopt -s shift_verbose    # Warn on shift with no arguments
    shopt -s extglob          # Enable extended pattern matching
    shopt -s nullglob         # Empty globs expand to nothing (not literal string)


**Why these specific options:**
- `inherit_errexit` - Prevents subshells from silently continuing after errors
- `shift_verbose` - Catches argument parsing bugs
- `extglob` - Enables powerful pattern matching: `@(pattern)`, `!(pattern)`, etc.
- `nullglob` - Makes empty globs safe (critical for `for file in *.txt` patterns)

### Step 6: Script Metadata

**Standard metadata variables - make readonly together after declaration.**

```bash
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME
```

**Why these specific variables:**
- `VERSION` - For `--version` flag, logging, compatibility checks
- `SCRIPT_PATH` - Absolute canonical path to script (resolves symlinks)
- `SCRIPT_DIR` - Directory containing script (for relative file access)
- `SCRIPT_NAME` - Script basename (for messages, logging, temp files)

**Why readonly together:** More efficient than individual readonly statements, documents that these are immutable constants.

**Acceptable alternative forms**
```bash
declare -r VERSION='1.0.0'
#shellcheck disable=SC2155
declare -r SCRIPT_PATH=$(realpath -- "$0")
declare -r SCRIPT_DIR=${SCRIPT_PATH%/*} SCRIPT_NAME=${SCRIPT_PATH##*/}
```

```bash
declare -r VERSION='1.0.0'
#shellcheck disable=SC2155
declare -r SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
declare -r SCRIPT_DIR=${SCRIPT_PATH%/*} SCRIPT_NAME=${SCRIPT_PATH##*/}
```

```bash
# parent program location locking, for a specific application with unique namespace
[[ -v ALX_VERSION ]] || {
  declare -xr ALX_VERSION='1.0.0'
  #shellcheck disable=SC2155
  declare -xr ALX_PATH=$(realpath -- "${BASH_SOURCE[0]}")
  declare -xr ALX_DIR=${ALX_PATH%/*} ALX_NAME=${ALX_PATH##*/}
}
```

Note:
  - `shellcheck` SC2155 warnings (declare and assign separately...), can be safely ignored when using `realpath` or `readlink`. (If you've got problems with `realpath`, then you have much greater problems elsewhere.)
  - On some BCS compliant systems `realpath` is set up as a builtin, which is 10x faster than using an executable.

### Step 7: Global Variable Declarations

**All global variables declared up front with types.**

```bash
# Configuration variables
declare -- PREFIX='/usr/local'
declare -- CONFIG_FILE=''
declare -- LOG_FILE=''

# Runtime state
declare -i VERBOSE=0
declare -i DRY_RUN=0
declare -i FORCE=0

# Arrays for accumulation
declare -a INPUT_FILES=()
declare -a WARNINGS=()
```

**Type declarations:**

Always:

- `declare -i` for integers (enables arithmetic context)
- `declare --` for strings (explicit string type)
- `declare -a` for indexed arrays
- `declare -A` for associative arrays

**Why up front:** Makes all globals visible in one place, prevents accidental creation of globals in functions, documents script's state.

### Step 8: Color Definitions (if terminal output)

**Terminal detection and color code definitions.**

Preferred:

```bash
if [[ -t 1 && -t 2 ]]; then
  readonly -- RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  readonly -- RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi
```

OR:

```bash
if [[ -t 2 ]]; then
  declare -r RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' BOLD=$'\033[1m' NC=$'\033[0m'
else
  declare -r RED='' GREEN='' YELLOW='' CYAN='' BOLD='' NC=''
fi
```

Acceptable:

```bash
# Detect terminal capabilities
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4)
  BOLD=$(tput bold)
  RESET=$(tput sgr0)
  readonly -- RED GREEN YELLOW BLUE BOLD RESET
else
  # Not a terminal or tput unavailable - no colors
  declare -r RED='' GREEN='' YELLOW='' BLUE='' BOLD='' RESET=''
fi
```

**Why conditional:** Colors only work on terminals - don't use them when output is piped or redirected.

**Skip this step** if your script doesn't use colored output.

### Step 9: Utility Functions

**Messaging and helper functions - lowest level, used by everything else.**

Users should comment out or remove elements that are not required.

```bash
declare -i VERBOSE=1
#declare -i DEBUG=0 PROMPT=1

# _Core messaging function using FUNCNAME
_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case ${FUNCNAME[1]} in
    vecho)   : ;;
    info)    prefix+=" ${CYAN}◉${NC}" ;;
    warn)    prefix+=" ${YELLOW}⚡${NC}" ;;
#    debug)   prefix+=" ${CYAN}DEBUG${NC}" ;;
    success) prefix+=" ${GREEN}✓${NC}" ;;
    error)   prefix+=" ${RED}✗${NC}" ;;
    *)       ;;
  esac
  for msg in "$@"; do printf '%s %s\n' "$prefix" "$msg"; done
}

# Verbose output (respects VERBOSE flag)
vecho() { ((VERBOSE)) || return 0; _msg "$@"; }
# Info messages
info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
# Warnings (non-fatal)
warn() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
# Debug output (respects DEBUG flag)
#debug() { ((DEBUG)) || return 0; >&2 _msg "$@"; }
# Success messages
success() { ((VERBOSE)) || return 0; >&2 _msg "$@" || return 0; }
# Error output (unconditional)
error() { >&2 _msg "$@"; }
# Exit with error
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }
# Yes/no prompt
yn() {
  #((PROMPT)) || return 0
  local -- reply
  >&2 read -r -n 1 -p "$(2>&1 warn "${1:-} y/n ")" reply
  >&2 echo
  [[ ${reply,,} == y ]]
}
```

For very simple programs with no need for color or verbosity control, user may simplify the standard messaging functions like this:

```bash
info() { >&2 echo "${FUNCNAME[0]}: $*"; }
debug() { >&2 echo "${FUNCNAME[0]}: $*"; }
success() { >&2 echo "${FUNCNAME[0]}: $*"; }
error() { >&2 echo "${FUNCNAME[0]}: $*"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }
```

User is strongly encouraged to use these function names for logging output, for both consistency, and for when that quick-and-dirty test script of yours evolves into a Magnum Opus, and now you need proper coloured and verbosity controlled message functions, like you should have used straight from the beginning. You're welcome.

**Why these come first:** Business logic needs messaging, validation, and error handling. These utilities must exist before anything calls them.

**Production optimization:** Remove unused functions after script is mature (see Section 6 of main standard).

### Step 10: Business Logic Functions

**Core functionality - the actual work of the script.**

```bash
# Check if all required commands are available
check_prerequisites() {
  # This function requires message functions error(), die(), and success()
  local -i missing=0
  local -- cmd

  for cmd in git make gcc; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      error "Required command not found '$cmd'"
      missing+=1
    fi
  done

  ((missing==0)) || die 1 "Missing $missing required commands"
  success 'All prerequisites satisfied'
}

# Validate configuration
validate_config() {
  # This function requires global var PREFIX, and message functions die() and success()
  [[ -n "$PREFIX" ]] || die 22 'PREFIX cannot be empty'
  [[ -d "$PREFIX" ]] || die 2 "PREFIX directory does not exist '$PREFIX'"

  success 'Configuration validated'
}

# Install files to target directory
install_files() {
  # This function requires global var DRY_RUN, and message functions info() and success()
  local -- source_dir=$1
  local -- target_dir=$2

  if ((DRY_RUN)); then
    info "[DRY-RUN] Would install files from '$source_dir' to '$target_dir'"
    return 0
  fi

  [[ -d "$source_dir" ]] || die 2 "Source directory not found '$source_dir'"
  mkdir -p "$target_dir" || die 1 "Failed to create target directory '$target_dir'"

  cp -r "$source_dir"/* "$target_dir"/ || die 1 'Installation failed'
  success "Installed files to '$target_dir'"
}

# Generate configuration file
generate_config() {
  # This function requires global vars DRY_RUN, PREFIX, and VERSION; and message functions info() and success()
  local -- config_file=$1

  ((DRY_RUN==0)) || {
    info "[DRY-RUN] Would generate config '$config_file'"
    return 0
  }

  cat > "$config_file" <<EOF
# Generated configuration
PREFIX=$PREFIX
VERSION=$VERSION
INSTALL_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

  success "Generated config '$config_file'"
}
```

**Organize bottom-up within business logic:**
- Lower-level functions first (validation, file operations)
- Higher-level functions later (orchestration)
- Each function can call functions defined above it

### Step 11: `main()` Function and Options/Argument Parsing

**Required for scripts over ~200 lines - orchestrates everything.**

```bash
main() {
  # Parse arguments
  while (($#)); do
    case $1 in
      -p|--prefix)   noarg "$@"; shift
                     PREFIX="$1" ;;

      -v|--verbose)  VERBOSE+=1 ;;
      -q|--quiet)    VERBOSE=0 ;;
      -n|--dry-run)  DRY_RUN=1 ;;
      -f|--force)    FORCE=1 ;;

      -V|--version)  echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
      -h|--help)     usage; exit 0 ;;

      -[pvqnfVh]*) #shellcheck disable=SC2046 #split up single options
                     set -- '' $(printf -- "-%c " $(grep -o . <<<"${1:1}")) "${@:2}" ;;
      -*)            die 22 "Invalid option: $1" ;;
      *)             INPUT_FILES+=("$1") ;;
    esac
    shift
  done

  # Make configuration readonly after parsing
  readonly -- PREFIX CONFIG_FILE LOG_FILE
  readonly -i VERBOSE DRY_RUN FORCE

  # Execute workflow
  ((DRY_RUN==0)) || info 'DRY-RUN mode enabled'

  check_prerequisites
  validate_config
  install_files "$SCRIPT_DIR"/data "$PREFIX"/share
  generate_config "$PREFIX"/etc/myapp.conf

  success 'Installation complete'
}
```

**Why main() is required:**
- **Testing** - Can source script and test `main()` with specific arguments
- **Organization** - Single entry point makes execution flow clear
- **Scoping** - Argument parsing can use local variables in main()
- **Debugging** - Easy to add debug hooks before/after main()

**Exception:** Scripts under 100 lines can skip `main()` and run directly.

### Step 12: Script Invocation

**Execute main with all arguments.**

```bash
main "$@"
```

**ALWAYS quote `"$@"`** to preserve argument array properly.

**For small scripts without main():** Just write business logic directly here.

### Step 13: End Marker

**Mandatory final line.**

```bash
#fin
```

OR:

```bash
#end
```

**Why mandatory:**
- Visual confirmation script is complete (not truncated)
- Some editors/tools look for end-of-file marker
- Consistency across all scripts


---

## Complete Example

**For a comprehensive, production-quality installation script demonstrating all 13 steps in action, see BCS010101 (Complete Working Example).**

The example includes:
- All 13 mandatory steps correctly implemented
- Full working code (462 lines)
- Dry-run mode, force mode, argument parsing
- Systemd integration, configuration generation
- Professional help text and error handling

---

## Anti-Patterns

**For common violations of the 13-step layout and their corrections, see BCS010102 (Common Anti-Patterns).**

Covers eight critical anti-patterns:
1. Missing `set -euo pipefail`
2. Variables used before declaration
3. Business logic before utilities
4. No `main()` in large scripts
5. Missing end marker
6. Premature `readonly`
7. Scattered declarations
8. Unprotected sourcing

---

## Edge Cases and Variations

**For special scenarios where the layout may be modified, see BCS010103 (Edge Cases and Variations).**

Covers five edge cases:
1. Tiny scripts (<40 lines) - May skip `main()`
2. Sourced libraries - Skip `set -e`, `main()`, invocation
3. External configuration - Add config sourcing
4. Platform-specific code - Add platform detection
5. Cleanup traps - Add trap handlers

---
## Recommended General Structure of Bash Scripts

Man=Mandatory Opt=Optional Rec=Recommended

### Executable Scripts

| Order | Status | Step | Comments |
|  0 | Man | '^#!shebang' ||
|  1 | Opt | '^#shellcheck' ||
|  2 | Opt | '^# ' | Multi-line Comments. Ends at first non-'^# ' line. Should usually have at least one short description line.|
|  3 | Man | 'set -euo pipefail' | MANDATORY first command before any other commands are executed|
|  4 | Opt | Bash 5 version test | (very rarely needed) |
|  5 | Rec | 'shopt'|standard 'shopt' settings|
|  6 | Rec | Script Metadata||
|  7 | Rec | Global Variable Declarations||
|  8 | Rec | Color Definitions | (if terminal output) |
|  9 | Rec | Utility Functions | (including Messaging) |
| 10 | Rec | Business Logic Functions||
| 11 | Rec | 'main()' | Function and Full Options/Argument Parsing|
| 12 | Rec | 'main "$@"'| Script Invocation|
| 13 | Man | '#end' Marker||

### Module/Library Scripts

| Order | Status | Step
|  0 | Man | '^#!shebang' |
|  1 | Opt | '^#shellcheck' |
|  2 | Opt | '^# ' |
|  4 | Opt | Bash 5 version test |
|  6 | Opt | Script Metadata|
|  7 | Opt | Global Variable Declarations|
|  8 | Opt | Color Definitions |
|  9 | Opt | Utility Functions |
| 10 | Rec | Business Logic Functions|
| 13 | Man | '#end' Marker|

### Combined Module/Library-Executable Scripts

| Order | Status | Step
|  0 | Man | '^#!shebang' |
|  1 | Opt | '^#shellcheck' |
|  2 | Opt | '^# ' |
|  3 | Opt | 'set -euo pipefail' |
|  4 | Opt | Bash 5 version test |
|  5 | Opt | 'shopt'|
|  6 | Opt | Script Metadata|
|  7 | Opt | Global Variable Declarations|
|  8 | Opt | Color Definitions |
|  9 | Opt | Utility Functions |
| 10 | Man | Business Logic Functions|
| 14    | Man | `[[ "${BASH_SOURCE[0]}" == "$0" ]] || return 0` |
| 14.0  | Man | '^#!shebang' ||
| 14.1  | Opt | '^#shellcheck' ||
| 14.2  | Opt | '^# ' | Multi-line Comments. Ends at first non-'^# ' line. Should usually have at least one short description line.|
| 14.3  | Man | 'set -euo pipefail' | MANDATORY first command before any other commands are executed|
| 14.4  | Opt | Bash 5 version test | (very rarely needed) |
| 14.5  | Rec | 'shopt'|standard 'shopt' settings|
| 14.6  | Rec | Script Metadata||
| 14.7  | Rec | Global Variable Declarations||
| 14.8  | Rec | Color Definitions | (if terminal output) |
| 14.9  | Rec | Utility Functions | (including Messaging) |
| 14.10 | Rec | Business Logic Functions||
| 14.11 | Rec | 'main()' | Function and Full Options/Argument Parsing|
| 14.12 | Rec | 'main "$@"'| Script Invocation|
| 14.13 | Man | '#end' Marker||

---

## Summary

**The 13-step layout is strongly recommended** - it's the foundation of all scripts in this coding standard. This structure:

1. **Guarantees safety** - Error handling comes first, nothing runs without it
2. **Ensures consistency** - Every script follows the same pattern
3. **Enables testing** - `main()` function allows sourcing for tests
4. **Prevents errors** - Bottom-up organization means dependencies are always defined before use
5. **Documents intent** - Structure itself tells you what the script does and how it works
6. **Simplifies maintenance** - Know where everything goes, no guessing

**For scripts over 100 lines**, all 13 steps should be done. **For smaller scripts**, steps 11-12 (main function) can be skipped, but all other steps remain required.

**When in doubt**, follow the complete 13-step structure - the benefits far outweigh the minor overhead. Every production script should follow this pattern exactly.

This layout is the result of years of experience and represents best practices for Bash scripting. Deviations from this structure should be rare and well-justified.
