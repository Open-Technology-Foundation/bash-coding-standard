#!/usr/bin/env bash
# Modify existing BCS rule safely
# Edit .complete.md and optionally recompress other tiers

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Script metadata
SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Project paths
PROJECT_DIR=$(realpath -- "$SCRIPT_DIR/..")
BCS_CMD="$PROJECT_DIR/bcs"
readonly -- PROJECT_DIR BCS_CMD

# Global variables
declare -i VERBOSE=1 QUIET=0 AUTO_COMPRESS=1 AUTO_VALIDATE=0 BACKUP=1
declare -- EDITOR_CMD="${EDITOR:-vi}"

# Colors
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
    *)       ;;
  esac
  for msg in "$@"; do printf '%s %s\n' "$prefix" "$msg"; done
}

vecho() { ((VERBOSE && !QUIET)) || return 0; _msg "$@"; }
info() { ((VERBOSE && !QUIET)) || return 0; >&2 _msg "$@"; }
warn() { ((QUIET)) || >&2 _msg "$@"; }
success() { ((VERBOSE && !QUIET)) || return 0; >&2 _msg "$@"; }
error() { >&2 _msg "$@"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] CODE_OR_FILE

Modify existing BCS rule - edit .complete.md and optionally recompress.

ARGUMENTS:
  CODE_OR_FILE            BCS code (e.g., BCS0206) or file path to .complete.md

OPTIONS:
  -h, --help              Show this help message
  --editor EDITOR         Editor to use (default: \$EDITOR or vi)
  --no-compress           Don't auto-compress after edit
  --validate              Validate after modification
  --no-backup             Don't backup original file
  -q, --quiet             Quiet mode

EXAMPLES:
  $SCRIPT_NAME BCS0206                    # Modify rule by BCS code
  $SCRIPT_NAME data/02-variables/06-special-vars.complete.md
  $SCRIPT_NAME BCS0206 --no-compress      # Don't recompress
  $SCRIPT_NAME BCS0206 --validate         # Validate after edit

WORKFLOW:
  1. Locate .complete.md file
  2. Backup original (if enabled)
  3. Open in editor
  4. Recompress to .summary.md and .abstract.md (if enabled)
  5. Validate (if enabled)
EOF
  exit "${1:-0}"
}

# Parse arguments
parse_arguments() {
  local -a codes_or_files=()

  while (($# > 0)); do
    case $1 in
      -h|--help) usage 0 ;;
      -q|--quiet) QUIET=1; VERBOSE=0; shift ;;
      --editor)
        (($# > 1)) || die 2 "Missing value for --editor"
        EDITOR_CMD=$2
        shift 2
        ;;
      --no-compress) AUTO_COMPRESS=0; shift ;;
      --validate) AUTO_VALIDATE=1; shift ;;
      --no-backup) BACKUP=0; shift ;;
      -*) die 2 "Unknown option: $1" ;;
      *) codes_or_files+=("$1"); shift ;;
    esac
  done

  [[ "${#codes_or_files[@]}" -gt 0 ]] || die 2 "No BCS code or file specified"
  printf '%s\0' "${codes_or_files[@]}"
}

# Find .complete.md file
find_complete_file() {
  local -- input=$1
  local -- file_path

  # If it's already a file path
  if [[ -f "$input" ]]; then
    echo "$input"
    return 0
  fi

  # If it's a BCS code, decode it
  if [[ "$input" =~ ^BCS[0-9]+$ ]]; then
    [[ -x "$BCS_CMD" ]] || die 2 "bcs command not executable"
    file_path=$("$BCS_CMD" decode "$input" -c 2>/dev/null) || die 1 "Failed to decode $input"
    [[ -f "$file_path" ]] || die 1 "File not found: $file_path"
    echo "$file_path"
    return 0
  fi

  die 1 "Invalid code or file: $input"
}

# Modify rule
modify_rule() {
  local -- input=$1
  local -- complete_file backup_file base_path

  complete_file=$(find_complete_file "$input")
  info "Modifying: $complete_file"

  # Backup
  if ((BACKUP)); then
    backup_file="${complete_file}.backup-$(date +%Y%m%d-%H%M%S)"
    cp -a "$complete_file" "$backup_file"
    success "Backed up to: $(basename "$backup_file")"
  fi

  # Edit
  "$EDITOR_CMD" "$complete_file" || die 1 "Editor failed"

  # Recompress
  if ((AUTO_COMPRESS)); then
    info "Recompressing to summary and abstract tiers..."
    if [[ -x "$BCS_CMD" ]]; then
      "$BCS_CMD" compress --regenerate --context-level abstract -q 2>&1 || warn "Compression failed"
    else
      warn "bcs command not available, skipping compression"
    fi
  fi

  # Validate
  if ((AUTO_VALIDATE)); then
    info "Running validation..."
    if [[ -x "$PROJECT_DIR/workflows/validate-data.sh" ]]; then
      "$PROJECT_DIR/workflows/validate-data.sh" -q || warn "Validation found issues"
    fi
  fi

  success "Modification complete"
}

main() {
  local -a inputs
  mapfile -t -d '' inputs < <(parse_arguments "$@")

  info "${BOLD}Modify BCS Rule${NC}"
  echo ""

  for input in "${inputs[@]}"; do
    modify_rule "$input"
    echo ""
  done

  info "Next steps:"
  echo "  - Review changes: git diff"
  echo "  - Regenerate canonical: bcs generate --canonical"
  echo "  - Commit: git add -p && git commit"
}

main "$@"
#fin
