#!/usr/bin/env bash
# Generate canonical BCS files from data/ directory
# Comprehensive wrapper around 'bcs generate' with validation and statistics

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
declare -i VERBOSE=1 QUIET=0 VALIDATE_AFTER=0 BACKUP_BEFORE=0 UPDATE_SYMLINK=0 FORCE=0
declare -- TIER='all'

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

# Usage information
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Generate canonical BCS files from data/ directory with validation and statistics.

OPTIONS:
  -h, --help              Show this help message
  -q, --quiet             Quiet mode (errors only)
  -v, --verbose           Verbose mode (default)
  --all                   Generate all three tiers (default)
  --tier TIER             Generate specific tier: complete, summary, or abstract
  --validate              Validate after generation
  --backup                Backup existing files before generation
  --update-symlink        Update BASH-CODING-STANDARD.md symlink
  --force                 Force regeneration (ignore timestamps)

TIERS:
  complete    - Full standard with all examples (~21K lines)
  summary     - Medium detail with key examples (~12K lines)
  abstract    - Minimal rules and patterns only (~3.8K lines)
  all         - Generate all three tiers (default)

EXAMPLES:
  $SCRIPT_NAME                              # Generate all tiers
  $SCRIPT_NAME --validate                   # Generate with validation
  $SCRIPT_NAME --backup --update-symlink    # Full regeneration
  $SCRIPT_NAME --tier abstract              # Generate abstract only
  $SCRIPT_NAME --force --all                # Force regeneration

WORKFLOW:
  1. Optional: Backup existing files
  2. Run 'bcs generate' for specified tier(s)
  3. Collect statistics (lines, size)
  4. Optional: Validate generated files
  5. Optional: Update BASH-CODING-STANDARD.md symlink
  6. Display summary

EXIT CODES:
  0 - Success
  1 - Generation or validation failed
  2 - Invalid arguments or setup failure

SEE ALSO:
  bcs generate            - Direct generation command
  bcs generate --canonical - Generate all tiers + rebuild BCS/ index
EOF
  exit "${1:-0}"
}

# Parse arguments
parse_arguments() {
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
        shift
        ;;
      --all)
        TIER='all'
        shift
        ;;
      --tier)
        (($# > 1)) || die 2 "Missing value for --tier"
        TIER=$2
        [[ "$TIER" =~ ^(complete|summary|abstract)$ ]] || \
          die 2 "Invalid tier: $TIER (must be complete, summary, or abstract)"
        shift 2
        ;;
      --validate)
        VALIDATE_AFTER=1
        shift
        ;;
      --backup)
        BACKUP_BEFORE=1
        shift
        ;;
      --update-symlink)
        UPDATE_SYMLINK=1
        shift
        ;;
      --force)
        FORCE=1
        shift
        ;;
      -*)
        die 2 "Unknown option: $1"
        ;;
      *)
        die 2 "Unexpected argument: $1"
        ;;
    esac
  done
}

# Get file statistics
get_file_stats() {
  local -- file=$1
  local -i size lines

  [[ -f "$file" ]] || return 1

  size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
  lines=$(wc -l < "$file" 2>/dev/null || echo "0")

  printf '%d:%d' "$size" "$lines"
}

# Backup file
backup_file() {
  local -- file=$1
  local -- backup_file

  [[ -f "$file" ]] || return 0

  backup_file="${file}.backup-$(date +%Y%m%d-%H%M%S)"
  cp -a "$file" "$backup_file"
  success "Backed up: $(basename "$file") -> $(basename "$backup_file")"
}

# Generate single tier
generate_tier() {
  local -- tier=$1
  local -- output_file="$PROJECT_DIR/BASH-CODING-STANDARD.$tier.md"
  local -- stats_before stats_after
  local -i size_before lines_before size_after lines_after

  info "Generating $tier tier..."

  # Backup if requested
  if ((BACKUP_BEFORE)) && [[ -f "$output_file" ]]; then
    backup_file "$output_file"
  fi

  # Get stats before
  if [[ -f "$output_file" ]]; then
    stats_before=$(get_file_stats "$output_file")
    IFS=':' read -r size_before lines_before <<< "$stats_before"
    vecho "  Before: $lines_before lines, $size_before bytes"
  else
    size_before=0
    lines_before=0
  fi

  # Generate
  [[ -x "$BCS_CMD" ]] || die 2 "'bcs' command not found or not executable"

  local -a cmd=("$BCS_CMD" "generate" "-t" "$tier" "-o" "$output_file")
  ((FORCE)) && cmd+=(--force)

  if "${cmd[@]}" 2>&1; then
    success "Generated: $tier tier"
  else
    error "Failed to generate $tier tier"
    return 1
  fi

  # Get stats after
  if [[ -f "$output_file" ]]; then
    stats_after=$(get_file_stats "$output_file")
    IFS=':' read -r size_after lines_after <<< "$stats_after"
    vecho "  After:  $lines_after lines, $size_after bytes"

    # Show delta
    if [[ "$size_before" -gt 0 ]]; then
      local -i delta_lines=$((lines_after - lines_before))
      local -i delta_size=$((size_after - size_before))
      local -- delta_sign_lines delta_sign_size

      delta_sign_lines=$([[ "$delta_lines" -ge 0 ]] && echo "+" || echo "")
      delta_sign_size=$([[ "$delta_size" -ge 0 ]] && echo "+" || echo "")

      vecho "  Delta:  ${delta_sign_lines}$delta_lines lines, ${delta_sign_size}$delta_size bytes"
    fi
  else
    error "Generated file not found: $output_file"
    return 1
  fi

  return 0
}

# Validate generated file
validate_generated_file() {
  local -- file=$1
  local -i errors=0

  info "Validating: $(basename "$file")"

  # Check file exists
  [[ -f "$file" ]] || {
    error "  File not found"
    return 1
  }

  # Check file is not empty
  [[ -s "$file" ]] || {
    error "  File is empty"
    ((errors+=1))
  }

  # Check starts with #
  if ! head -1 "$file" | grep -q '^#'; then
    warn "  Does not start with # (expected markdown heading)"
    ((errors+=1))
  fi

  # Check ends with #fin
  if ! tail -1 "$file" | grep -q '^#fin$'; then
    warn "  Does not end with #fin marker"
    ((errors+=1))
  fi

  # Check for basic sections
  local -i section_count
  section_count=$(grep -c '^## ' "$file" || true)
  if [[ "$section_count" -lt 5 ]]; then
    warn "  Only $section_count sections found (expected at least 5)"
    ((errors+=1))
  else
    success "  Found $section_count sections"
  fi

  if [[ "$errors" -eq 0 ]]; then
    success "  Validation passed"
    return 0
  else
    error "  Validation found $errors issue(s)"
    return 1
  fi
}

# Update symlink
update_symlink() {
  local -- target_tier=${1:-abstract}
  local -- symlink="$PROJECT_DIR/BASH-CODING-STANDARD.md"
  local -- target="BASH-CODING-STANDARD.$target_tier.md"

  info "Updating symlink to $target_tier tier..."

  # Check target exists
  [[ -f "$PROJECT_DIR/$target" ]] || {
    error "Target file not found: $target"
    return 1
  }

  # Remove existing symlink if present
  [[ -L "$symlink" ]] && rm -f "$symlink"

  # Create new symlink
  ln -sf "$target" "$symlink" || {
    error "Failed to create symlink"
    return 1
  }

  success "Symlink updated: BASH-CODING-STANDARD.md -> $target"
}

# Main function
main() {
  parse_arguments "$@"

  info "${BOLD}BCS Canonical File Generation${NC}"
  info "Project directory: $PROJECT_DIR"
  info ""

  local -i total_generated=0 total_failed=0

  # Generate tier(s)
  if [[ "$TIER" == "all" ]]; then
    info "Generating all three tiers..."
    echo ""

    for tier in complete summary abstract; do
      if generate_tier "$tier"; then
        ((total_generated+=1))
      else
        ((total_failed+=1))
      fi
      echo ""
    done

    # Rebuild BCS/ index if all succeeded
    if [[ "$total_failed" -eq 0 ]]; then
      info "Rebuilding BCS/ index..."
      if "$BCS_CMD" generate --canonical 2>&1 | grep -q "regenerat"; then
        success "BCS/ index rebuilt"
      fi
    fi
  else
    if generate_tier "$TIER"; then
      ((total_generated+=1))
    else
      ((total_failed+=1))
    fi
    echo ""
  fi

  # Validation
  if ((VALIDATE_AFTER && total_generated > 0)); then
    info "Validating generated files..."
    echo ""

    local -a files_to_validate=()
    if [[ "$TIER" == "all" ]]; then
      files_to_validate=(
        "$PROJECT_DIR/BASH-CODING-STANDARD.complete.md"
        "$PROJECT_DIR/BASH-CODING-STANDARD.summary.md"
        "$PROJECT_DIR/BASH-CODING-STANDARD.abstract.md"
      )
    else
      files_to_validate=("$PROJECT_DIR/BASH-CODING-STANDARD.$TIER.md")
    fi

    local -i validation_failed=0
    for file in "${files_to_validate[@]}"; do
      if ! validate_generated_file "$file"; then
        ((validation_failed+=1))
      fi
      echo ""
    done

    if [[ "$validation_failed" -gt 0 ]]; then
      error "Validation failed for $validation_failed file(s)"
      exit 1
    fi
  fi

  # Update symlink
  if ((UPDATE_SYMLINK)); then
    # Default to abstract tier
    local -- symlink_target="abstract"
    [[ "$TIER" != "all" ]] && symlink_target="$TIER"

    update_symlink "$symlink_target"
    echo ""
  fi

  # Summary
  info "${BOLD}Generation Summary:${NC}"
  echo "  Generated: $total_generated"
  [[ "$total_failed" -gt 0 ]] && echo "  Failed: $total_failed"
  echo ""

  if [[ "$total_failed" -eq 0 ]]; then
    success "${BOLD}Generation completed successfully${NC}"
    exit 0
  else
    error "${BOLD}Generation failed for $total_failed tier(s)${NC}"
    exit 1
  fi
}

main "$@"
#fin
