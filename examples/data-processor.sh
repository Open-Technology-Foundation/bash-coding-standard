#!/usr/bin/env bash
# Data processing script - demonstrates BCS array and file operation patterns
# Real-world example: Process CSV files with validation and reporting

set -euo pipefail
shopt -s inherit_errexit shift_verbose nullglob extglob

# Script metadata
declare -x VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Global variables
declare -i VERBOSE=1 DRY_RUN=0 SKIP_VALIDATION=0
declare -- OUTPUT_DIR='./processed'
declare -- FIELD_SEPARATOR=','

# Statistics
declare -i TOTAL_FILES=0 PROCESSED_FILES=0 FAILED_FILES=0 TOTAL_RECORDS=0

# Colors
if [[ -t 1 && -t 2 ]]; then
  declare -- RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m'
  declare -- CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  declare -- RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi
readonly -- RED GREEN YELLOW CYAN NC

# Messaging functions
_msg() {
  local -- prefix="$SCRIPT_NAME:"
  case ${FUNCNAME[1]} in
    info)    prefix+=" ${CYAN}◉${NC}" ;;
    warn)    prefix+=" ${YELLOW}⚡${NC}" ;;
    success) prefix+=" ${GREEN}✓${NC}" ;;
    error)   prefix+=" ${RED}✗${NC}" ;;
  esac
  printf '%s %s\n' "$prefix" "$1"
}

info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn() { >&2 _msg "$@"; }
success() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
error() { >&2 _msg "$@"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

# Validate CSV file
validate_csv() {
  local -- file=$1
  local -i line_num=0 errors=0

  [[ -f "$file" ]] || { error "File not found: $file"; return 1; }
  [[ -r "$file" ]] || { error "File not readable: $file"; return 1; }

  # Check header
  local -- header
  IFS= read -r header < "$file" || { error "Empty file: $file"; return 1; }

  # Validate format
  while IFS= read -r line; do
    ((line_num+=1))
    [[ -n "$line" ]] || continue

    local -i field_count
    IFS="$FIELD_SEPARATOR" read -ra fields <<< "$line"
    field_count=${#fields[@]}

    [[ "$field_count" -ge 3 ]] || {
      warn "Line $line_num: Insufficient fields ($field_count < 3)"
      ((errors+=1))
    }
  done < <(tail -n +2 "$file")

  [[ "$errors" -eq 0 ]] || { error "Validation found $errors error(s)"; return 1; }
  return 0
}

# Process single CSV file
process_csv_file() {
  local -- input_file=$1
  local -- output_file="$OUTPUT_DIR/$(basename "${input_file%.csv}")-processed.csv"
  local -i record_count=0

  info "Processing: $(basename "$input_file")"

  # Validate
  ((SKIP_VALIDATION)) || validate_csv "$input_file" || return 1

  if ((DRY_RUN)); then
    info "DRY-RUN: Would process to $output_file"
    return 0
  fi

  # Process (example: convert to uppercase, add timestamp)
  {
    # Header
    IFS= read -r header
    echo "${header},processed_at"

    # Data rows
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      echo "${line^^},$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      ((record_count+=1))
    done
  } < "$input_file" > "$output_file"

  ((TOTAL_RECORDS+=record_count))
  success "Processed $record_count records -> $(basename "$output_file")"
}

# Main
main() {
  local -a input_files=()

  # Parse arguments
  while (($# > 0)); do
    case $1 in
      -h|--help)
        cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] FILE [FILE ...]

Process CSV files with validation and reporting.

OPTIONS:
  -h, --help              Show this help
  -n, --dry-run           Dry run mode
  --skip-validation       Skip validation
  -o, --output DIR        Output directory (default: ./processed)

EXAMPLES:
  $SCRIPT_NAME data/*.csv
  $SCRIPT_NAME --dry-run file.csv
EOF
        exit 0
        ;;
      -n|--dry-run) DRY_RUN=1; shift ;;
      --skip-validation) SKIP_VALIDATION=1; shift ;;
      -o|--output)
        (($# > 1)) || die 2 "Missing value for --output"
        OUTPUT_DIR=$2
        shift 2
        ;;
      -*) die 2 "Unknown option: $1" ;;
      *) input_files+=("$1"); shift ;;
    esac
  done

  [[ "${#input_files[@]}" -gt 0 ]] || die 2 "No input files specified"

  info "Data Processor v$VERSION"
  ((DRY_RUN)) && warn "DRY-RUN MODE"
  echo ""

  # Create output directory
  [[ -d "$OUTPUT_DIR" ]] || mkdir -p "$OUTPUT_DIR"

  # Process files
  TOTAL_FILES=${#input_files[@]}
  for file in "${input_files[@]}"; do
    if process_csv_file "$file"; then
      ((PROCESSED_FILES+=1))
    else
      ((FAILED_FILES+=1))
    fi
  done

  # Summary
  echo ""
  info "Processing Summary:"
  echo "  Total files: $TOTAL_FILES"
  echo "  Processed: $PROCESSED_FILES"
  echo "  Failed: $FAILED_FILES"
  echo "  Total records: $TOTAL_RECORDS"

  [[ "$FAILED_FILES" -eq 0 ]] && exit 0 || exit 1
}

main "$@"
#fin
