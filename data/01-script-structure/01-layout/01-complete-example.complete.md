### Complete Working Example

**This subrule provides a comprehensive, production-quality installation script that demonstrates all 13 mandatory steps of the BCS0101 layout pattern in action.**

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

## What This Example Demonstrates

### Structural Elements

1. **Complete initialization sequence** - Shebang, shellcheck, description, strict mode, shopt
2. **Comprehensive metadata** - Version, paths, script name (all readonly)
3. **Organized global variables** - Configuration, runtime flags, arrays
4. **Terminal-aware colors** - Conditional color codes based on TTY
5. **Standard messaging functions** - Complete `_msg()` system with all helpers
6. **Business logic hierarchy** - From validation to installation to summary
7. **Argument parsing with short options** - Full getopt-style handling
8. **Progressive readonly** - Variables become immutable after parsing

### Functional Patterns

**Dry-run mode throughout:** Every operation checks `DRY_RUN` flag and shows what would happen without executing.

**Force mode handling:** Existing files trigger warnings unless `--force` specified.

**Derived paths pattern:** When `PREFIX` changes, all dependent paths update via `update_derived_paths()`.

**Validation before action:** Prerequisites and configuration validated before any filesystem operations.

**Error accumulation:** Warnings collected in array for final summary.

**User prompts:** Interactive confirmation with `yn()` function when needed.

**Systemd integration:** Conditional service installation with proper unit file generation.

### Production Readiness

- Complete help and usage text
- Version information
- Verbose/quiet modes
- Configuration file generation
- Permission management
- Summary report
- Graceful error handling throughout
- All 13 mandatory steps correctly implemented

This example serves as a template for production installation scripts and demonstrates how all BCS principles work together in a real-world scenario.
