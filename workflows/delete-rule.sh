#!/usr/bin/env bash
# Delete BCS rule across all three tiers
# Safe deletion with backup and reference checking

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Script metadata
SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Project paths
PROJECT_DIR=$(realpath -- "$SCRIPT_DIR/..")
DATA_DIR="$PROJECT_DIR/data"
BCS_CMD="$PROJECT_DIR/bcs"
readonly -- PROJECT_DIR DATA_DIR BCS_CMD

# Global variables
declare -i VERBOSE=1 QUIET=0 DRY_RUN=0 FORCE=0 BACKUP=1 CHECK_REFS=1

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
Usage: $SCRIPT_NAME [OPTIONS] CODE

Delete BCS rule across all three tiers with safety checks.

ARGUMENTS:
  CODE                    BCS code to delete (e.g., BCS0206)

OPTIONS:
  -h, --help              Show this help message
  -n, --dry-run           Show what would be deleted without deleting
  --force                 Skip confirmation prompts
  --no-backup             Don't backup deleted files
  --no-check-refs         Don't check for references
  -q, --quiet             Quiet mode

EXAMPLES:
  $SCRIPT_NAME BCS0206                    # Delete with confirmation
  $SCRIPT_NAME BCS0206 --dry-run          # Preview deletion
  $SCRIPT_NAME BCS0206 --force --no-backup

WORKFLOW:
  1. Locate all three tier files
  2. Check for references in other rules (if enabled)
  3. Confirm deletion (unless --force)
  4. Backup files (if enabled)
  5. Delete all three tiers
  6. Display next steps

SAFETY:
  - Requires confirmation unless --force
  - Backups created by default
  - Checks for references by default
  - Supports dry-run mode
EOF
  exit "${1:-0}"
}

# Parse arguments
parse_arguments() {
  local -a codes=()

  while (($# > 0)); do
    case $1 in
      -h|--help) usage 0 ;;
      -q|--quiet) QUIET=1; VERBOSE=0; shift ;;
      -n|--dry-run) DRY_RUN=1; shift ;;
      --force) FORCE=1; shift ;;
      --no-backup) BACKUP=0; shift ;;
      --no-check-refs) CHECK_REFS=0; shift ;;
      -*) die 2 "Unknown option: $1" ;;
      *) codes+=("$1"); shift ;;
    esac
  done

  [[ "${#codes[@]}" -gt 0 ]] || die 2 "No BCS code specified"
  printf '%s\0' "${codes[@]}"
}

# Find all tier files for code
find_tier_files() {
  local -- code=$1
  local -a files=()

  [[ -x "$BCS_CMD" ]] || die 2 "bcs command not executable"

  # Get all three tiers
  for tier in complete summary abstract; do
    local -- file
    file=$("$BCS_CMD" decode "$code" "-${tier:0:1}" 2>/dev/null) || continue
    [[ -f "$file" ]] && files+=("$file")
  done

  [[ "${#files[@]}" -gt 0 ]] || die 1 "No files found for code: $code"

  printf '%s\0' "${files[@]}"
}

# Check for references
check_references() {
  local -- code=$1
  local -i ref_count=0

  info "Checking for references to $code..."

  while IFS= read -r -d '' match; do
    ((ref_count+=1))
    [[ "$ref_count" -le 5 ]] && warn "  Found in: ${match#"$DATA_DIR"/}"
  done < <(grep -r -l "$code" "$DATA_DIR" --include="*.md" -Z 2>/dev/null || true)

  if [[ "$ref_count" -gt 0 ]]; then
    warn "Found $ref_count reference(s) to $code"
    [[ "$ref_count" -gt 5 ]] && warn "  (showing first 5)"
    return 1
  else
    success "No references found"
    return 0
  fi
}

# Confirm deletion
confirm_deletion() {
  local -- code=$1
  local -a files
  mapfile -t -d '' files < <("$@")

  ((FORCE)) && return 0

  echo ""
  warn "${BOLD}WARNING: About to delete ${#files[@]} file(s) for $code${NC}"
  for file in "${files[@]}"; do
    echo "  - ${file#"$PROJECT_DIR"/}"
  done
  echo ""

  local -- reply
  read -r -p "Delete these files? [y/N] " reply
  [[ "${reply,,}" == "y" ]] || die 0 "Deletion cancelled by user"
}

# Delete rule
delete_rule() {
  local -- code=$1
  local -a files backup_dir
  mapfile -t -d '' files < <(find_tier_files "$code")

  info "Deleting rule: $code"
  echo ""

  # Check references
  if ((CHECK_REFS)); then
    if ! check_references "$code"; then
      if ((FORCE)); then
        warn "Proceeding despite references (--force)"
      else
        die 1 "References found - fix them first or use --force"
      fi
    fi
    echo ""
  fi

  # Confirm
  confirm_deletion "$code" "${files[@]}"
  echo ""

  # Backup
  if ((BACKUP)) && ! ((DRY_RUN)); then
    backup_dir="$PROJECT_DIR/.deleted-rules/$(date +%Y%m%d-%H%M%S)-$code"
    mkdir -p "$backup_dir"
    for file in "${files[@]}"; do
      cp -a "$file" "$backup_dir/"
    done
    success "Backed up to: ${backup_dir#"$PROJECT_DIR"/}"
  fi

  # Delete
  for file in "${files[@]}"; do
    if ((DRY_RUN)); then
      info "DRY-RUN: Would delete ${file#"$PROJECT_DIR"/}"
    else
      rm -f "$file"
      success "Deleted: ${file#"$PROJECT_DIR"/}"
    fi
  done

  echo ""
  success "Rule $code deleted (${#files[@]} files)"
}

main() {
  local -a codes
  mapfile -t -d '' codes < <(parse_arguments "$@")

  info "${BOLD}Delete BCS Rule${NC}"
  ((DRY_RUN)) && warn "${BOLD}DRY-RUN MODE${NC}"
  echo ""

  for code in "${codes[@]}"; do
    delete_rule "$code"
    echo ""
  done

  if ! ((DRY_RUN)); then
    info "Next steps:"
    echo "  - Regenerate canonical: bcs generate --canonical"
    echo "  - Validate: ./workflows/validate-data.sh"
    echo "  - Commit: git add -u && git commit"
    ((BACKUP)) && echo "  - Backups in: .deleted-rules/"
  fi
}

main "$@"
#fin
