#!/usr/bin/env bash
# Production deployment script - demonstrates BCS patterns
# Real-world example: Deploy application with validation, backup, and rollback

set -euo pipefail
shopt -s inherit_errexit shift_verbose nullglob

# Script metadata
declare -x VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Configuration
declare -- DEPLOY_DIR='/var/www/app'
declare -- BACKUP_DIR='/var/backups/app'
declare -- CONFIG_FILE='/etc/app/deploy.conf'
readonly -- DEPLOY_DIR BACKUP_DIR CONFIG_FILE

# Global variables
declare -i VERBOSE=1 DEBUG=0 DRY_RUN=0 FORCE=0
declare -i SKIP_BACKUP=0 SKIP_TESTS=0 SKIP_VALIDATION=0

# Colors (conditional on TTY)
if [[ -t 1 && -t 2 ]]; then
  declare -- RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m'
  declare -- CYAN=$'\033[0;36m' BOLD=$'\033[1m' NC=$'\033[0m'
else
  declare -- RED='' GREEN='' YELLOW='' CYAN='' BOLD='' NC=''
fi
readonly -- RED GREEN YELLOW CYAN BOLD NC

# Messaging functions
_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case ${FUNCNAME[1]} in
    vecho)   ;;
    info)    prefix+=" ${CYAN}◉${NC}" ;;
    warn)    prefix+=" ${YELLOW}⚡${NC}" ;;
    success) prefix+=" ${GREEN}✓${NC}" ;;
    error)   prefix+=" ${RED}✗${NC}" ;;
    debug)   prefix+=" ${BOLD}DEBUG:${NC}" ;;
    *)       ;;
  esac
  for msg in "$@"; do printf '%s %s\n' "$prefix" "$msg"; done
}

vecho() { ((VERBOSE)) || return 0; _msg "$@"; }
info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn() { >&2 _msg "$@"; }
success() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
error() { >&2 _msg "$@"; }
debug() { ((DEBUG)) || return 0; >&2 _msg "$@"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

# Usage
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] VERSION

Production deployment script with backup and rollback capabilities.

ARGUMENTS:
  VERSION                 Version to deploy (e.g., v2.1.0)

OPTIONS:
  -h, --help              Show this help message
  -v, --verbose           Verbose output (default)
  -q, --quiet             Quiet mode
  -d, --debug             Debug mode
  -n, --dry-run           Dry run mode (show what would be done)
  --force                 Force deployment (skip confirmations)
  --skip-backup           Skip backup step
  --skip-tests            Skip test suite
  --skip-validation       Skip pre-deployment validation
  -V, --version           Show script version

EXAMPLES:
  $SCRIPT_NAME v2.1.0                     # Deploy version 2.1.0
  $SCRIPT_NAME v2.1.0 --dry-run           # Preview deployment
  $SCRIPT_NAME v2.1.0 --skip-tests        # Deploy without running tests

DEPLOYMENT WORKFLOW:
  1. Pre-deployment validation
  2. Backup current version
  3. Download new version
  4. Run test suite
  5. Deploy new version
  6. Health check
  7. Cleanup old backups

ROLLBACK:
  Use --rollback flag with backup timestamp to revert deployment.

EXIT CODES:
  0 - Deployment successful
  1 - Deployment failed
  2 - Invalid arguments or validation failed
EOF
  exit "${1:-0}"
}

# Parse arguments
parse_arguments() {
  local -a positional=()

  while (($# > 0)); do
    case $1 in
      -h|--help) usage 0 ;;
      -v|--verbose) VERBOSE=1; shift ;;
      -q|--quiet) VERBOSE=0; shift ;;
      -d|--debug) DEBUG=1; shift ;;
      -n|--dry-run) DRY_RUN=1; shift ;;
      --force) FORCE=1; shift ;;
      --skip-backup) SKIP_BACKUP=1; shift ;;
      --skip-tests) SKIP_TESTS=1; shift ;;
      --skip-validation) SKIP_VALIDATION=1; shift ;;
      -V|--version) echo "$SCRIPT_NAME version $VERSION"; exit 0 ;;
      -*) die 2 "Unknown option: $1" ;;
      *) positional+=("$1"); shift ;;
    esac
  done

  [[ "${#positional[@]}" -ge 1 ]] || die 2 "No version specified"
  printf '%s\0' "${positional[@]}"
}

# Pre-deployment validation
validate_environment() {
  info "Validating deployment environment..."

  # Check deploy directory exists
  [[ -d "$DEPLOY_DIR" ]] || die 2 "Deploy directory not found: $DEPLOY_DIR"

  # Check backup directory exists or create
  if [[ ! -d "$BACKUP_DIR" ]]; then
    if ((DRY_RUN)); then
      info "DRY-RUN: Would create backup directory: $BACKUP_DIR"
    else
      mkdir -p "$BACKUP_DIR"
      success "Created backup directory: $BACKUP_DIR"
    fi
  fi

  # Check required commands
  local -a required_cmds=(rsync tar curl)
  local -- cmd
  for cmd in "${required_cmds[@]}"; do
    command -v "$cmd" >/dev/null || die 2 "Required command not found: $cmd"
  done

  success "Environment validation passed"
}

# Backup current version
backup_current_version() {
  local -- backup_timestamp
  backup_timestamp=$(date +%Y%m%d-%H%M%S)
  local -- backup_path="$BACKUP_DIR/backup-$backup_timestamp.tar.gz"

  info "Backing up current version..."

  if ((DRY_RUN)); then
    info "DRY-RUN: Would create backup: $backup_path"
    return 0
  fi

  tar -czf "$backup_path" -C "$DEPLOY_DIR" . || die 1 "Backup failed"
  success "Backup created: $backup_path"

  # Cleanup old backups (keep last 5)
  local -a old_backups
  mapfile -t old_backups < <(find "$BACKUP_DIR" -name "backup-*.tar.gz" -type f | sort -r | tail -n +6)

  if [[ "${#old_backups[@]}" -gt 0 ]]; then
    info "Cleaning up ${#old_backups[@]} old backup(s)..."
    for backup in "${old_backups[@]}"; do
      rm -f "$backup"
      debug "Removed old backup: $(basename "$backup")"
    done
  fi
}

# Deploy new version
deploy_version() {
  local -- version=$1
  local -- download_url="https://releases.example.com/app-${version}.tar.gz"
  local -- temp_dir

  info "Deploying version: $version"

  if ((DRY_RUN)); then
    info "DRY-RUN: Would download from: $download_url"
    info "DRY-RUN: Would extract to: $DEPLOY_DIR"
    return 0
  fi

  # Download to temp directory
  temp_dir=$(mktemp -d)
  trap 'rm -rf "$temp_dir"' RETURN

  info "Downloading release..."
  curl -fsSL "$download_url" -o "$temp_dir/release.tar.gz" || die 1 "Download failed"

  info "Extracting release..."
  tar -xzf "$temp_dir/release.tar.gz" -C "$DEPLOY_DIR" || die 1 "Extraction failed"

  success "Deployment complete"
}

# Run tests
run_tests() {
  ((SKIP_TESTS)) && { info "Skipping tests (--skip-tests)"; return 0; }

  info "Running test suite..."

  if ((DRY_RUN)); then
    info "DRY-RUN: Would run tests"
    return 0
  fi

  # Simulate test execution
  if [[ -x "$DEPLOY_DIR/run-tests.sh" ]]; then
    "$DEPLOY_DIR/run-tests.sh" || {
      error "Tests failed"
      return 1
    }
    success "All tests passed"
  else
    warn "Test script not found, skipping"
  fi
}

# Health check
health_check() {
  info "Running health check..."

  if ((DRY_RUN)); then
    info "DRY-RUN: Would perform health check"
    return 0
  fi

  # Simulate health check
  local -- health_url="http://localhost:8080/health"
  if curl -fsSL "$health_url" >/dev/null 2>&1; then
    success "Health check passed"
  else
    warn "Health check failed (service may need restart)"
  fi
}

# Main deployment workflow
main() {
  local -a args
  local -- deploy_version

  # Parse arguments
  mapfile -t -d '' args < <(parse_arguments "$@")
  deploy_version=${args[0]}

  info "${BOLD}Production Deployment${NC}"
  info "Version: $deploy_version"
  ((DRY_RUN)) && warn "${BOLD}DRY-RUN MODE${NC}"
  echo ""

  # Validation
  ((SKIP_VALIDATION)) || validate_environment
  echo ""

  # Confirmation
  if ! ((FORCE || DRY_RUN)); then
    local -- reply
    read -r -p "Deploy version $deploy_version to production? [y/N] " reply
    [[ "${reply,,}" == "y" ]] || die 0 "Deployment cancelled by user"
    echo ""
  fi

  # Backup
  ((SKIP_BACKUP)) || backup_current_version
  echo ""

  # Deploy
  deploy_version "$deploy_version"
  echo ""

  # Tests
  run_tests
  echo ""

  # Health check
  health_check
  echo ""

  success "${BOLD}Deployment successful: $deploy_version${NC}"
  echo ""
  info "Next steps:"
  echo "  - Monitor logs: tail -f /var/log/app/app.log"
  echo "  - Check metrics: http://localhost:8080/metrics"
  echo "  - Rollback if needed: Use backup in $BACKUP_DIR"
}

main "$@"
#fin
