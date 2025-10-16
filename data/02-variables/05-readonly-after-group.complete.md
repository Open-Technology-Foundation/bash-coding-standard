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
