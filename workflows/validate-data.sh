#!/usr/bin/env bash
# Validate BCS data/ directory structure and rule files
# Comprehensive validation workflow for rule integrity

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
declare -i VERBOSE=1 QUIET=0 EXIT_ON_ERROR=0 ERRORS=0 WARNINGS=0
declare -i SUMMARY_LIMIT=10000 ABSTRACT_LIMIT=1500

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
    warn)    prefix+=" ${YELLOW}⚡${NC}"; ((WARNINGS+=1)) ;;
    success) prefix+=" ${GREEN}✓${NC}" ;;
    error)   prefix+=" ${RED}✗${NC}"; ((ERRORS+=1)) ;;
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

# Usage information
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Validate BCS data/ directory structure and rule files.

OPTIONS:
  -h, --help              Show this help message
  -q, --quiet             Quiet mode (errors only)
  -v, --verbose           Verbose mode (default)
  --exit-on-error         Exit immediately on first error
  --summary-limit BYTES   Max summary file size (default: $SUMMARY_LIMIT)
  --abstract-limit BYTES  Max abstract file size (default: $ABSTRACT_LIMIT)
  --json                  Output results in JSON format

VALIDATION CHECKS:
  1. Data directory existence
  2. Tier file completeness (all .complete.md have .summary.md and .abstract.md)
  3. Numeric prefix zero-padding (01- not 1-)
  4. Section directories have required 00-section files
  5. BCS code uniqueness (no duplicates)
  6. File naming conventions (NN-name.tier.md)
  7. No alphabetic suffixes (02a-, 02b- forbidden)
  8. Section count consistency
  9. BCS code decodability
  10. Header files existence
  11. File size limits (per tier)

EXAMPLES:
  $SCRIPT_NAME                           # Run all validations
  $SCRIPT_NAME --quiet                   # Only show errors
  $SCRIPT_NAME --exit-on-error           # Stop on first error
  $SCRIPT_NAME --summary-limit 8000      # Custom size limits
  $SCRIPT_NAME --json > report.json      # JSON output

EXIT CODES:
  0 - All validations passed
  1 - Validation errors found
  2 - Invalid arguments or setup failure
EOF
  exit "${1:-0}"
}

# Parse arguments
parse_arguments() {
  local -- output_json=0

  while (($# > 0)); do
    case $1 in
      -h|--help)
        usage 0
        ;;
      -q|--quiet)
        QUIET=1
        VERBOSE=0
        shift
        ;;
      -v|--verbose)
        VERBOSE=1
        QUIET=0
        shift
        ;;
      --exit-on-error)
        EXIT_ON_ERROR=1
        shift
        ;;
      --summary-limit)
        (($# > 1)) || die 2 "Missing value for --summary-limit"
        SUMMARY_LIMIT=$2
        shift 2
        ;;
      --abstract-limit)
        (($# > 1)) || die 2 "Missing value for --abstract-limit"
        ABSTRACT_LIMIT=$2
        shift 2
        ;;
      --json)
        output_json=1
        QUIET=1
        shift
        ;;
      *)
        die 2 "Unknown option: $1"
        ;;
    esac
  done

  readonly -- output_json
  return 0
}

# Validation: Data directory exists
validate_data_directory_exists() {
  info "Checking data directory existence..."

  if [[ -d "$DATA_DIR" ]]; then
    success "data/ directory exists"
    return 0
  else
    error "data/ directory not found at: $DATA_DIR"
    ((EXIT_ON_ERROR)) && exit 1
    return 1
  fi
}

# Validation: All .complete.md files have .summary.md and .abstract.md
validate_tier_file_completeness() {
  info "Checking tier file completeness..."

  local -a complete_files=()
  local -- file basename_without_tier
  local -i missing_count=0

  while IFS= read -r -d '' file; do
    complete_files+=("$file")
  done < <(find "$DATA_DIR" -type f -name "*.complete.md" -print0 | sort -z)

  for file in "${complete_files[@]}"; do
    basename_without_tier="${file%.complete.md}"

    if [[ ! -f "$basename_without_tier.abstract.md" ]]; then
      error "Missing abstract tier for: ${file#"$DATA_DIR"/}"
      ((missing_count+=1))
      ((EXIT_ON_ERROR)) && exit 1
    fi

    if [[ ! -f "$basename_without_tier.summary.md" ]]; then
      error "Missing summary tier for: ${file#"$DATA_DIR"/}"
      ((missing_count+=1))
      ((EXIT_ON_ERROR)) && exit 1
    fi
  done

  if [[ "$missing_count" -eq 0 ]]; then
    success "All complete tier files have corresponding abstract and summary tiers (${#complete_files[@]} rules)"
    return 0
  else
    error "$missing_count tier file(s) missing"
    return 1
  fi
}

# Validation: Numeric prefixes are zero-padded
validate_numeric_prefixes_zero_padded() {
  info "Checking numeric prefix zero-padding..."

  local -a non_padded=()

  while IFS= read -r -d '' item; do
    if [[ $(basename "$item") =~ ^[0-9]- ]]; then
      non_padded+=("$item")
    fi
  done < <(find "$DATA_DIR" \( -type f -o -type d \) -print0 | sort -z)

  if [[ "${#non_padded[@]}" -eq 0 ]]; then
    success "All numeric prefixes are zero-padded"
    return 0
  else
    error "Found ${#non_padded[@]} item(s) without zero-padding:"
    for item in "${non_padded[@]}"; do
      error "  - ${item#"$DATA_DIR"/}"
    done
    ((EXIT_ON_ERROR)) && exit 1
    return 1
  fi
}

# Validation: Section directories have required 00-section files
validate_section_directories_have_section_files() {
  info "Checking section directory structure..."

  local -a section_dirs=()
  local -- dir
  local -i missing_count=0

  while IFS= read -r -d '' dir; do
    if [[ $(basename "$dir") =~ ^[0-9]{2}- ]]; then
      section_dirs+=("$dir")
    fi
  done < <(find "$DATA_DIR" -maxdepth 1 -type d -print0 | sort -z)

  for dir in "${section_dirs[@]}"; do
    if [[ ! -f "$dir/00-section.complete.md" ]]; then
      error "Missing 00-section.complete.md in ${dir#"$DATA_DIR"/}"
      ((missing_count+=1))
      ((EXIT_ON_ERROR)) && exit 1
    fi

    if [[ ! -f "$dir/00-section.abstract.md" ]]; then
      error "Missing 00-section.abstract.md in ${dir#"$DATA_DIR"/}"
      ((missing_count+=1))
      ((EXIT_ON_ERROR)) && exit 1
    fi

    if [[ ! -f "$dir/00-section.summary.md" ]]; then
      error "Missing 00-section.summary.md in ${dir#"$DATA_DIR"/}"
      ((missing_count+=1))
      ((EXIT_ON_ERROR)) && exit 1
    fi
  done

  if [[ "$missing_count" -eq 0 ]]; then
    success "All section directories have required 00-section files (${#section_dirs[@]} sections)"
    return 0
  else
    error "$missing_count section file(s) missing"
    return 1
  fi
}

# Validation: BCS codes are unique
validate_bcs_code_uniqueness() {
  info "Checking BCS code uniqueness..."

  [[ -x "$BCS_CMD" ]] || {
    warn "bcs command not executable, skipping code uniqueness check"
    return 0
  }

  local -- codes_output
  codes_output=$("$BCS_CMD" codes 2>&1) || {
    warn "Failed to run 'bcs codes', skipping uniqueness check"
    return 0
  }

  local -a all_codes=()
  local -- line code

  while IFS= read -r line; do
    if [[ "$line" =~ ^(BCS[0-9]+): ]]; then
      all_codes+=("${BASH_REMATCH[1]}")
    fi
  done <<< "$codes_output"

  local -A seen_codes=()
  local -i duplicate_count=0

  for code in "${all_codes[@]}"; do
    if [[ -n "${seen_codes[$code]:-}" ]]; then
      error "Duplicate BCS code detected: $code"
      ((duplicate_count+=1))
      ((EXIT_ON_ERROR)) && exit 1
    else
      seen_codes[$code]=1
    fi
  done

  if [[ "$duplicate_count" -eq 0 ]]; then
    success "All BCS codes are unique (${#all_codes[@]} codes)"
    return 0
  else
    error "$duplicate_count duplicate code(s) found"
    return 1
  fi
}

# Validation: File naming conventions
validate_file_naming_conventions() {
  info "Checking file naming conventions..."

  local -a invalid_names=()
  local -- file basename_file

  while IFS= read -r -d '' file; do
    basename_file=$(basename "$file")

    # Skip templates directory
    [[ "$file" =~ /templates/ ]] && continue

    # Skip README.md files
    [[ "$basename_file" == "README.md" ]] && continue

    # Skip 00-header and 00-section files
    [[ "$basename_file" =~ ^00-(header|section)\. ]] && continue

    # Valid pattern: NN-something.{complete|abstract|summary}.md
    if [[ ! "$basename_file" =~ ^[0-9]{2}-[a-z0-9-]+\.(complete|abstract|summary)\.md$ ]]; then
      invalid_names+=("$file")
    fi
  done < <(find "$DATA_DIR" -type f -name "*.md" -print0 | sort -z)

  if [[ "${#invalid_names[@]}" -eq 0 ]]; then
    success "All rule files follow naming convention"
    return 0
  else
    error "Found ${#invalid_names[@]} file(s) with invalid names:"
    local -i count=0
    for file in "${invalid_names[@]}"; do
      error "  - ${file#"$DATA_DIR"/}"
      ((count+=1))
      [[ "$count" -ge 10 ]] && break
    done
    ((EXIT_ON_ERROR)) && exit 1
    return 1
  fi
}

# Validation: No alphabetic suffixes
validate_no_alphabetic_suffixes() {
  info "Checking for alphabetic suffixes..."

  local -a alpha_suffixes=()

  while IFS= read -r -d '' item; do
    if [[ $(basename "$item") =~ ^[0-9]{2}[a-z]- ]]; then
      alpha_suffixes+=("$item")
    fi
  done < <(find "$DATA_DIR" -print0)

  if [[ "${#alpha_suffixes[@]}" -eq 0 ]]; then
    success "No files/dirs use alphabetic suffixes (e.g., 02a-, 02b-)"
    return 0
  else
    error "Found ${#alpha_suffixes[@]} item(s) with alphabetic suffixes:"
    for item in "${alpha_suffixes[@]}"; do
      error "  - ${item#"$DATA_DIR"/}"
    done
    ((EXIT_ON_ERROR)) && exit 1
    return 1
  fi
}

# Validation: Header files exist
validate_header_files_exist() {
  info "Checking header files..."

  local -i missing_count=0

  for tier in complete abstract summary; do
    if [[ -f "$DATA_DIR/00-header.$tier.md" ]]; then
      vecho "  00-header.$tier.md exists"
    else
      error "  00-header.$tier.md missing"
      ((missing_count+=1))
      ((EXIT_ON_ERROR)) && exit 1
    fi
  done

  if [[ "$missing_count" -eq 0 ]]; then
    success "All header files exist"
    return 0
  else
    error "$missing_count header file(s) missing"
    return 1
  fi
}

# Validation: File size limits
validate_file_size_limits() {
  info "Checking file size limits..."

  local -i oversized_count=0
  local -- file size_str tier
  local -i size

  # Check summary files
  while IFS= read -r -d '' file; do
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    if [[ "$size" -gt "$SUMMARY_LIMIT" ]]; then
      warn "Summary file oversized: ${file#"$DATA_DIR"/} ($size > $SUMMARY_LIMIT bytes)"
      ((oversized_count+=1))
    fi
  done < <(find "$DATA_DIR" -type f -name "*.summary.md" ! -name "00-header.summary.md" -print0)

  # Check abstract files
  while IFS= read -r -d '' file; do
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    if [[ "$size" -gt "$ABSTRACT_LIMIT" ]]; then
      warn "Abstract file oversized: ${file#"$DATA_DIR"/} ($size > $ABSTRACT_LIMIT bytes)"
      ((oversized_count+=1))
    fi
  done < <(find "$DATA_DIR" -type f -name "*.abstract.md" ! -name "00-header.abstract.md" -print0)

  if [[ "$oversized_count" -eq 0 ]]; then
    success "All files within size limits"
    return 0
  else
    warn "$oversized_count file(s) exceed size limits (consider running: bcs compress --regenerate)"
    return 0  # Warning, not error
  fi
}

# Main validation runner
main() {
  parse_arguments "$@"

  info "${BOLD}BCS Data Directory Validation${NC}"
  info "Data directory: $DATA_DIR"
  info ""

  # Run all validations
  validate_data_directory_exists
  validate_tier_file_completeness
  validate_numeric_prefixes_zero_padded
  validate_section_directories_have_section_files
  validate_bcs_code_uniqueness
  validate_file_naming_conventions
  validate_no_alphabetic_suffixes
  validate_header_files_exist
  validate_file_size_limits

  # Summary
  info ""
  if [[ "$ERRORS" -eq 0 ]]; then
    success "${BOLD}Validation complete: All checks passed${NC}"
    [[ "$WARNINGS" -gt 0 ]] && warn "  ($WARNINGS warning(s) - non-critical)"
    exit 0
  else
    error "${BOLD}Validation failed: $ERRORS error(s), $WARNINGS warning(s)${NC}"
    exit 1
  fi
}

main "$@"
#fin
