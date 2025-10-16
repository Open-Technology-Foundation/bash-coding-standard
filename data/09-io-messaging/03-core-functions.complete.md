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
