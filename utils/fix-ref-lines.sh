#!/usr/bin/env bash
# One-time fix: Replace verbose Ref lines with concise BCS code references
# Preserves timestamp synchronization with .complete.md files
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Script metadata
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
PROJECT_DIR=${SCRIPT_DIR%/utils*}
DATAPATH="$PROJECT_DIR/data"
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME PROJECT_DIR DATAPATH

# Source bash-coding-standard to get get_bcs_code() function
# shellcheck source=../../bash-coding-standard
source "$PROJECT_DIR/bash-coding-standard" || {
  echo "$SCRIPT_NAME: ERROR: Cannot source bash-coding-standard" >&2
  exit 1
}

# Runtime flags
declare -i DRY_RUN=0
declare -i VERBOSE=1

# Statistics
declare -i files_processed=0
declare -i files_changed=0
declare -i files_skipped=0

# Colors
if [[ -t 1 && -t 2 ]]; then
  readonly -- RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  readonly -- RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

# Messaging functions
_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case ${FUNCNAME[1]} in
    vecho)   : ;;
    info)    prefix+=" ${CYAN}◉${NC}" ;;
    warn)    prefix+=" ${YELLOW}⚡${NC}" ;;
    success) prefix+=" ${GREEN}✓${NC}" ;;
    error)   prefix+=" ${RED}✗${NC}" ;;
    *)       ;;
  esac
  for msg in "$@"; do printf '%s %s\n' "$prefix" "$msg"; done
}

vecho() { ((VERBOSE)) || return 0; _msg "$@"; }
info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
success() { ((VERBOSE)) || return 0; >&2 _msg "$@" || return 0; }
error() { >&2 _msg "$@"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

One-time fix to replace verbose Ref lines with concise BCS code references.
Preserves timestamp synchronization with .complete.md files.

OPTIONS:
  -n, --dry-run          Show what would be done without doing it
  -q, --quiet            Quiet mode (less verbose output)
  -v, --verbose          Verbose mode (default)
  -h, --help             Display this help message
  -V, --version          Display version information

EXAMPLES:
  $SCRIPT_NAME                    # Fix all files
  $SCRIPT_NAME --dry-run          # Preview changes
  $SCRIPT_NAME --quiet            # Silent mode

EOF
}

fix_ref_line() {
  local -- file="$1"
  local -- bcs_code tier complete_file
  local -i changed=0

  files_processed+=1

  # Get BCS code for this file
  bcs_code=$(get_bcs_code "$file") || {
    warn "Cannot determine BCS code for '$file'"
    files_skipped+=1
    return 1
  }

  # Determine complete file for timestamp reference
  # Extract tier from filename: data/01-layout.abstract.md → abstract
  local -- basename="${file##*/}"
  basename="${basename%.md}"  # Remove .md extension
  tier="${basename##*.}"        # Extract last component after dot
  complete_file="${file%.$tier.md}.complete.md"

  if [[ ! -f "$complete_file" ]]; then
    warn "Complete file not found for '$file'"
    files_skipped+=1
    return 1
  fi

  # Check if file has verbose Ref line
  if ! grep -q '^\*\*Ref:\*\* ' "$file"; then
    vecho "  ⊙ No Ref line: ${file#$DATAPATH/}"
    files_skipped+=1
    return 0
  fi

  # Check if already has correct format
  if grep -q "^\*\*Ref:\*\* $bcs_code\$" "$file"; then
    vecho "  ⊙ Already correct: ${file#$DATAPATH/}"
    files_skipped+=1
    return 0
  fi

  # Perform replacement
  if ((DRY_RUN)); then
    info "  [DRY-RUN] Would fix: ${file#$DATAPATH/} → Ref: $bcs_code"
    files_changed+=1
    return 0
  fi

  # Create temporary file
  local -- temp_file
  temp_file=$(mktemp) || die 1 'Failed to create temporary file'

  # Replace Ref line
  sed "s|^\*\*Ref:\*\* .*\$|**Ref:** $bcs_code|" "$file" > "$temp_file" || {
    rm -f "$temp_file"
    error "  ✗ Failed to process: ${file#$DATAPATH/}"
    files_skipped+=1
    return 1
  }

  # Verify change was made
  if ! grep -q "^\*\*Ref:\*\* $bcs_code\$" "$temp_file"; then
    rm -f "$temp_file"
    warn "  ⚠ Ref line not changed: ${file#$DATAPATH/}"
    files_skipped+=1
    return 1
  fi

  # Atomic replace
  mv "$temp_file" "$file" || {
    rm -f "$temp_file"
    error "  ✗ Failed to write: ${file#$DATAPATH/}"
    files_skipped+=1
    return 1
  }

  # Preserve timestamp from complete file
  touch --reference="$complete_file" "$file" || {
    warn "  ⚠ Failed to sync timestamp for: ${file#$DATAPATH/}"
  }

  success "  ✓ Fixed: ${file#$DATAPATH/} → Ref: $bcs_code"
  files_changed+=1
  return 0
}

process_all_files() {
  # Find all abstract and summary files
  local -a files=()
  readarray -t files < <(find "$DATAPATH" -type f \( -name '*.abstract.md' -o -name '*.summary.md' \) | sort)

  local -i file_count=${#files[@]}

  if ((file_count == 0)); then
    warn 'No .abstract.md or .summary.md files found'
    return 0
  fi

  info "Found $file_count files to process"
  echo

  # Process each file
  local -- file
  for file in "${files[@]}"; do
    fix_ref_line "$file" || true
  done
}

show_statistics() {
  cat <<EOF

${GREEN}Fix Statistics${NC}
$(printf '=%.0s' {1..50})

Files processed: $files_processed
Files changed:   ${GREEN}$files_changed${NC}
Files skipped:   ${YELLOW}$files_skipped${NC}

EOF

  if ((files_changed > 0)); then
    if ((DRY_RUN)); then
      info 'Dry-run complete - run without --dry-run to apply changes'
    else
      success 'All Ref lines fixed!'
      echo
      info 'Next steps:'
      info '  1. Review changes with: git diff'
      info '  2. Regenerate standard: ./bcs generate --canonical'
      info '  3. Commit changes'
    fi
  fi
}

main() {
  # Verify data directory exists
  [[ -d "$DATAPATH" ]] || die 2 "Data directory not found: $DATAPATH"

  # Parse command-line arguments
  while (($#)); do
    case $1 in
      -n|--dry-run)      DRY_RUN=1 ;;
      -v|--verbose)      VERBOSE=1 ;;
      -q|--quiet)        VERBOSE=0 ;;

      -h|--help)         usage
                         exit 0
                         ;;

      -V|--version)      echo "$SCRIPT_NAME $VERSION"
                         exit 0
                         ;;

      -[nvqhV]*)         #shellcheck disable=SC2046
                         set -- '' $(printf -- "-%c " $(grep -o . <<<"${1:1}")) "${@:2}"
                         ;;

      -*)                die 22 "Invalid option: $1 (use --help for usage)" ;;
      *)                 die 2  "Unexpected argument: $1" ;;
    esac
    shift
  done

  ((DRY_RUN)) && info 'DRY-RUN mode enabled - no changes will be made'

  process_all_files
  show_statistics
}

main "$@"

#fin
