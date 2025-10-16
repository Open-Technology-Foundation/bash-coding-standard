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
