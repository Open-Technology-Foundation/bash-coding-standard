#!/usr/bin/env bash
# Complete BCS-compliant script demonstrating all patterns
set -euo pipefail
shopt -s inherit_errexit shift_verbose nullglob

# Script metadata
declare -x VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Global variables
declare -i VERBOSE=1 DEBUG=0 DRY_RUN=0
declare -- CONFIG_FILE=''

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

# Usage information
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] FILE [FILE ...]

Complete BCS-compliant script example.

ARGUMENTS:
  FILE                    Files to process

OPTIONS:
  -h, --help              Show this help message
  -v, --verbose           Verbose output (default)
  -q, --quiet             Quiet mode
  -d, --debug             Debug mode
  -n, --dry-run           Dry run mode
  -c, --config FILE       Configuration file
  -V, --version           Show version

EXAMPLES:
  $SCRIPT_NAME file1.txt
  $SCRIPT_NAME -n file1.txt file2.txt
  $SCRIPT_NAME -c config.ini *.txt

EOF
  exit "${1:-0}"
}

# Parse command-line arguments
parse_arguments() {
  local -a files=()

  while (($# > 0)); do
    case $1 in
      -h|--help)
        usage 0
        ;;
      -v|--verbose)
        VERBOSE=1
        shift
        ;;
      -q|--quiet)
        VERBOSE=0
        shift
        ;;
      -d|--debug)
        DEBUG=1
        shift
        ;;
      -n|--dry-run)
        DRY_RUN=1
        shift
        ;;
      -c|--config)
        (($# > 1)) || die 2 "Missing value for --config"
        CONFIG_FILE=$2
        shift 2
        ;;
      -V|--version)
        echo "$SCRIPT_NAME version $VERSION"
        exit 0
        ;;
      -*)
        die 2 "Unknown option: $1"
        ;;
      *)
        files+=("$1")
        shift
        ;;
    esac
  done

  [[ "${#files[@]}" -gt 0 ]] || die 2 "No files specified"

  # Export files via stdout for main
  printf '%s\0' "${files[@]}"
}

# Validate file exists and is readable
validate_file() {
  local -- file=$1

  [[ -f "$file" ]] || {
    error "File not found: $file"
    return 1
  }

  [[ -r "$file" ]] || {
    error "File not readable: $file"
    return 1
  }

  debug "Validated file: $file"
  return 0
}

# Process a single file
process_file() {
  local -- file=$1
  local -i line_count

  validate_file "$file" || return 1

  if ((DRY_RUN)); then
    info "DRY-RUN: Would process $file"
    return 0
  fi

  line_count=$(wc -l < "$file")
  success "Processed $file ($line_count lines)"
  return 0
}

# Main function
main() {
  local -a files
  local -- file
  local -i processed=0 failed=0

  # Parse arguments
  mapfile -t -d '' files < <(parse_arguments "$@")

  [[ "${#files[@]}" -gt 0 ]] || die 2 "No files to process"

  ((DRY_RUN)) && warn "DRY-RUN mode enabled"

  # Process each file
  for file in "${files[@]}"; do
    if process_file "$file"; then
      ((processed+=1))
    else
      ((failed+=1))
    fi
  done

  # Summary
  info "Processed: $processed, Failed: $failed"

  [[ "$failed" -eq 0 ]] || exit 1
  exit 0
}

main "$@"
#fin
