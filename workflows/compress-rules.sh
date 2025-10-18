#!/usr/bin/env bash
# Compress BCS rule files using Claude AI
# Enhanced wrapper around 'bcs compress' with pre-flight checks and progress reporting

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
declare -i VERBOSE=1 QUIET=0 DRY_RUN=0 REPORT_ONLY=1
declare -- TIER='both' CONTEXT_LEVEL='none' CLAUDE_CMD='claude'
declare -i SUMMARY_LIMIT=10000 ABSTRACT_LIMIT=1500

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

Compress BCS rule files using Claude AI with pre-flight checks and progress reporting.
Enhanced wrapper around 'bcs compress'.

MODES:
  --report-only        Report oversized files only (default)
  --regenerate         Delete and regenerate all compressed files

OPTIONS:
  -h, --help              Show this help message
  -q, --quiet             Quiet mode (errors only)
  -v, --verbose           Verbose mode (default)
  -n, --dry-run           Show what would be done without doing it
  --tier TIER             Process specific tier: summary or abstract (default: both)
  --context-level LEVEL   Context awareness level (default: none)
                          Options: none, toc, abstract, summary, complete
  --claude-cmd CMD        Claude CLI command path (default: claude)
  --summary-limit N       Summary file size limit in bytes (default: 10000)
  --abstract-limit N      Abstract file size limit in bytes (default: 1500)

CONTEXT LEVELS:
  none      - Each rule compressed in isolation (fastest)
  toc       - Includes table of contents (~5-10KB context)
  abstract  - Full abstract standard (~83KB) - RECOMMENDED
  summary   - Full summary standard (~310KB context)
  complete  - Full complete standard (~520KB context)

EXAMPLES:
  $SCRIPT_NAME                                    # Report oversized files
  $SCRIPT_NAME --regenerate                       # Regenerate with no context
  $SCRIPT_NAME --regenerate --context-level abstract  # RECOMMENDED
  $SCRIPT_NAME --regenerate --tier summary        # Only summary tier
  $SCRIPT_NAME --dry-run --regenerate             # Preview regeneration

PRE-FLIGHT CHECKS:
  1. Claude CLI availability
  2. Data directory validation
  3. BCS command accessibility
  4. Existing file permissions

EXIT CODES:
  0 - Success
  1 - Compression failed or oversized files found
  2 - Invalid arguments or setup failure

SEE ALSO:
  bcs compress            - Direct compression command
  bcs compress --help     - Detailed compression options
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
      -n|--dry-run)
        DRY_RUN=1
        shift
        ;;
      --report-only)
        REPORT_ONLY=1
        shift
        ;;
      --regenerate)
        REPORT_ONLY=0
        shift
        ;;
      --tier)
        (($# > 1)) || die 2 "Missing value for --tier"
        TIER=$2
        [[ "$TIER" =~ ^(summary|abstract|both)$ ]] || \
          die 2 "Invalid tier: $TIER (must be summary, abstract, or both)"
        shift 2
        ;;
      --context-level)
        (($# > 1)) || die 2 "Missing value for --context-level"
        CONTEXT_LEVEL=$2
        [[ "$CONTEXT_LEVEL" =~ ^(none|toc|abstract|summary|complete)$ ]] || \
          die 2 "Invalid context level: $CONTEXT_LEVEL"
        shift 2
        ;;
      --claude-cmd)
        (($# > 1)) || die 2 "Missing value for --claude-cmd"
        CLAUDE_CMD=$2
        shift 2
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
      -*)
        die 2 "Unknown option: $1"
        ;;
      *)
        die 2 "Unexpected argument: $1"
        ;;
    esac
  done
}

# Pre-flight check: Claude CLI
check_claude_cli() {
  info "Checking Claude CLI availability..."

  if command -v "$CLAUDE_CMD" >/dev/null 2>&1; then
    success "Claude CLI found: $CLAUDE_CMD"
    return 0
  else
    error "Claude CLI not found: $CLAUDE_CMD"
    error "Install from: https://claude.ai/code"
    return 1
  fi
}

# Pre-flight check: Data directory
check_data_directory() {
  info "Checking data directory..."

  [[ -d "$DATA_DIR" ]] || {
    error "Data directory not found: $DATA_DIR"
    return 1
  }

  # Count .complete.md files
  local -i complete_count
  complete_count=$(find "$DATA_DIR" -type f -name "*.complete.md" | wc -l)

  if [[ "$complete_count" -gt 0 ]]; then
    success "Found $complete_count .complete.md files"
    return 0
  else
    error "No .complete.md files found in $DATA_DIR"
    return 1
  fi
}

# Pre-flight check: BCS command
check_bcs_command() {
  info "Checking BCS command..."

  [[ -x "$BCS_CMD" ]] || {
    error "BCS command not executable: $BCS_CMD"
    return 1
  }

  # Verify compress subcommand exists
  if "$BCS_CMD" help compress >/dev/null 2>&1; then
    success "BCS compress subcommand available"
    return 0
  else
    error "BCS compress subcommand not available"
    return 1
  fi
}

# Run all pre-flight checks
run_preflight_checks() {
  info "${BOLD}Pre-flight Checks${NC}"
  echo ""

  local -i failed=0

  check_claude_cli || ((failed+=1))
  check_data_directory || ((failed+=1))
  check_bcs_command || ((failed+=1))

  echo ""

  if [[ "$failed" -gt 0 ]]; then
    error "Pre-flight checks failed: $failed check(s)"
    return 1
  else
    success "All pre-flight checks passed"
    return 0
  fi
}

# Report mode: list oversized files
report_oversized_files() {
  info "${BOLD}Checking File Sizes${NC}"
  echo ""

  local -i oversized_summary=0 oversized_abstract=0
  local -- file size_str
  local -i size

  # Check summary files
  if [[ "$TIER" == "both" || "$TIER" == "summary" ]]; then
    info "Checking summary files (limit: $SUMMARY_LIMIT bytes)..."
    while IFS= read -r -d '' file; do
      size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
      if [[ "$size" -gt "$SUMMARY_LIMIT" ]]; then
        warn "  Oversized: ${file#"$DATA_DIR"/} ($size bytes)"
        ((oversized_summary+=1))
      fi
    done < <(find "$DATA_DIR" -type f -name "*.summary.md" ! -name "00-header.summary.md" -print0 | sort -z)

    if [[ "$oversized_summary" -eq 0 ]]; then
      success "All summary files within limit"
    fi
    echo ""
  fi

  # Check abstract files
  if [[ "$TIER" == "both" || "$TIER" == "abstract" ]]; then
    info "Checking abstract files (limit: $ABSTRACT_LIMIT bytes)..."
    while IFS= read -r -d '' file; do
      size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
      if [[ "$size" -gt "$ABSTRACT_LIMIT" ]]; then
        warn "  Oversized: ${file#"$DATA_DIR"/} ($size bytes)"
        ((oversized_abstract+=1))
      fi
    done < <(find "$DATA_DIR" -type f -name "*.abstract.md" ! -name "00-header.abstract.md" -print0 | sort -z)

    if [[ "$oversized_abstract" -eq 0 ]]; then
      success "All abstract files within limit"
    fi
    echo ""
  fi

  # Summary
  local -i total_oversized=$((oversized_summary + oversized_abstract))
  if [[ "$total_oversized" -gt 0 ]]; then
    warn "${BOLD}Summary:${NC} $total_oversized oversized file(s) found"
    warn "Run with --regenerate to compress files"
    return 1
  else
    success "${BOLD}Summary:${NC} All files within size limits"
    return 0
  fi
}

# Regenerate mode: compress all files
regenerate_compressed_files() {
  info "${BOLD}Regenerating Compressed Files${NC}"
  echo ""

  ((DRY_RUN)) && warn "DRY-RUN mode: No files will be modified"

  # Build bcs compress command
  local -a cmd=("$BCS_CMD" "compress" "--regenerate")
  [[ "$TIER" != "both" ]] && cmd+=(--tier "$TIER")
  cmd+=(--context-level "$CONTEXT_LEVEL")
  cmd+=(--claude-cmd "$CLAUDE_CMD")
  cmd+=(--summary-limit "$SUMMARY_LIMIT")
  cmd+=(--abstract-limit "$ABSTRACT_LIMIT")
  ((QUIET)) && cmd+=(--quiet)
  ((VERBOSE)) && cmd+=(--verbose)

  info "Command: ${cmd[*]}"
  echo ""

  if ((DRY_RUN)); then
    info "DRY-RUN: Would execute compression"
    return 0
  fi

  # Execute compression
  if "${cmd[@]}"; then
    success "Compression completed successfully"
    return 0
  else
    local -i exit_code=$?
    error "Compression failed with exit code: $exit_code"
    return "$exit_code"
  fi
}

# Display compression statistics
show_compression_stats() {
  info "${BOLD}Compression Statistics${NC}"

  # Count files by tier
  local -i complete_count summary_count abstract_count
  complete_count=$(find "$DATA_DIR" -type f -name "*.complete.md" ! -name "00-header.complete.md" | wc -l)
  summary_count=$(find "$DATA_DIR" -type f -name "*.summary.md" ! -name "00-header.summary.md" | wc -l)
  abstract_count=$(find "$DATA_DIR" -type f -name "*.abstract.md" ! -name "00-header.abstract.md" | wc -l)

  echo "  Complete tier: $complete_count files"
  echo "  Summary tier:  $summary_count files"
  echo "  Abstract tier: $abstract_count files"
  echo ""

  # Average sizes
  local -i total_size avg_size
  if [[ "$summary_count" -gt 0 ]]; then
    total_size=$(find "$DATA_DIR" -type f -name "*.summary.md" ! -name "00-header.summary.md" -exec stat -c%s {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
    avg_size=$((total_size / summary_count))
    echo "  Average summary size: $avg_size bytes (limit: $SUMMARY_LIMIT)"
  fi

  if [[ "$abstract_count" -gt 0 ]]; then
    total_size=$(find "$DATA_DIR" -type f -name "*.abstract.md" ! -name "00-header.abstract.md" -exec stat -c%s {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
    avg_size=$((total_size / abstract_count))
    echo "  Average abstract size: $avg_size bytes (limit: $ABSTRACT_LIMIT)"
  fi
}

# Main function
main() {
  parse_arguments "$@"

  info "${BOLD}BCS Rule Compression Workflow${NC}"
  info "Data directory: $DATA_DIR"
  info "Mode: $([[ "$REPORT_ONLY" -eq 1 ]] && echo "Report only" || echo "Regenerate")"
  [[ "$TIER" != "both" ]] && info "Tier: $TIER"
  info "Context level: $CONTEXT_LEVEL"
  echo ""

  # Pre-flight checks (only for regenerate mode)
  if [[ "$REPORT_ONLY" -eq 0 ]]; then
    run_preflight_checks || die 2 "Pre-flight checks failed"
    echo ""
  fi

  # Execute mode
  if [[ "$REPORT_ONLY" -eq 1 ]]; then
    # Report mode
    if report_oversized_files; then
      exit 0
    else
      exit 1
    fi
  else
    # Regenerate mode
    if regenerate_compressed_files; then
      echo ""
      show_compression_stats
      echo ""
      success "${BOLD}Regeneration completed successfully${NC}"
      exit 0
    else
      error "${BOLD}Regeneration failed${NC}"
      exit 1
    fi
  fi
}

main "$@"
#fin
