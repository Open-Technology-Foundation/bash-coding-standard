#!/usr/bin/env bash
# Check script compliance against BASH-CODING-STANDARD
# Wrapper around 'bcs check' with batch processing and reporting

set -euo pipefail
shopt -s inherit_errexit shift_verbose nullglob

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
declare -i VERBOSE=1 QUIET=0 STRICT_MODE=0
declare -- OUTPUT_FORMAT='text' REPORT_FILE=''

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
Usage: $SCRIPT_NAME [OPTIONS] SCRIPT [SCRIPT ...]

Check script compliance against BASH-CODING-STANDARD using 'bcs check'.
Supports batch processing and multiple output formats.

ARGUMENTS:
  SCRIPT                  Path to script file(s) to check
                          Use glob patterns for batch: *.sh, scripts/**/*.sh

OPTIONS:
  -h, --help              Show this help message
  -q, --quiet             Quiet mode (errors only)
  -v, --verbose           Verbose mode (default)
  --strict                Strict mode: exit non-zero on any violation
  --format FORMAT         Output format: text (default), json, markdown
  --report FILE           Save report to file
  --batch                 Batch mode: check multiple scripts, summarize results

EXAMPLES:
  $SCRIPT_NAME script.sh                     # Check single script
  $SCRIPT_NAME *.sh                          # Check all .sh files
  $SCRIPT_NAME --strict deploy.sh            # Strict mode for CI/CD
  $SCRIPT_NAME --format json script.sh       # JSON output
  $SCRIPT_NAME --batch --report report.md *.sh  # Batch with markdown report

NOTES:
  - Requires 'bcs check' subcommand (Claude CLI required)
  - In batch mode, individual failures don't stop processing
  - Strict mode is recommended for CI/CD pipelines
  - JSON format is ideal for programmatic analysis

SEE ALSO:
  bcs check SCRIPT        - Direct compliance checking
EOF
  exit "${1:-0}"
}

# Parse arguments
parse_arguments() {
  local -a scripts=()
  local -i batch_mode=0

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
      --strict)
        STRICT_MODE=1
        shift
        ;;
      --format)
        (($# > 1)) || die 2 "Missing value for --format"
        OUTPUT_FORMAT=$2
        [[ "$OUTPUT_FORMAT" =~ ^(text|json|markdown)$ ]] || \
          die 2 "Invalid format: $OUTPUT_FORMAT"
        shift 2
        ;;
      --report)
        (($# > 1)) || die 2 "Missing value for --report"
        REPORT_FILE=$2
        shift 2
        ;;
      --batch)
        batch_mode=1
        shift
        ;;
      -*)
        die 2 "Unknown option: $1"
        ;;
      *)
        scripts+=("$1")
        shift
        ;;
    esac
  done

  [[ "${#scripts[@]}" -gt 0 ]] || die 2 "No scripts specified"

  # Export for main
  printf '%d\0' "$batch_mode"
  printf '%s\0' "${scripts[@]}"
}

# Check single script
check_single_script() {
  local -- script=$1
  local -- format_opt

  [[ -f "$script" ]] || {
    error "File not found: $script"
    return 1
  }

  [[ -x "$BCS_CMD" ]] || die 2 "'bcs' command not found or not executable"

  info "Checking: $script"

  # Build bcs check command
  local -a cmd=("$BCS_CMD" "check")
  [[ "$OUTPUT_FORMAT" != "text" ]] && cmd+=(--format "$OUTPUT_FORMAT")
  ((STRICT_MODE)) && cmd+=(--strict)
  cmd+=("$script")

  # Execute check
  if "${cmd[@]}"; then
    success "Compliance check passed: $script"
    return 0
  else
    local -i exit_code=$?
    error "Compliance check failed: $script (exit code: $exit_code)"
    return "$exit_code"
  fi
}

# Batch check multiple scripts
batch_check_scripts() {
  local -a scripts=("$@")
  local -- script
  local -i total=0 passed=0 failed=0 not_found=0

  info "Batch compliance checking ${#scripts[@]} script(s)..."
  echo ""

  local -a failed_scripts=() passed_scripts=()

  for script in "${scripts[@]}"; do
    ((total+=1))

    if [[ ! -f "$script" ]]; then
      warn "File not found: $script"
      ((not_found+=1))
      continue
    fi

    if check_single_script "$script" 2>&1; then
      ((passed+=1))
      passed_scripts+=("$script")
    else
      ((failed+=1))
      failed_scripts+=("$script")
    fi
    echo ""
  done

  # Summary
  echo "${BOLD}Batch Compliance Summary:${NC}"
  echo "  Total scripts: $total"
  echo "  ${GREEN}Passed: $passed${NC}"
  echo "  ${RED}Failed: $failed${NC}"
  [[ "$not_found" -gt 0 ]] && echo "  ${YELLOW}Not found: $not_found${NC}"
  echo ""

  if [[ "$failed" -gt 0 ]]; then
    echo "${RED}Failed scripts:${NC}"
    for script in "${failed_scripts[@]}"; do
      echo "  - $script"
    done
    echo ""
  fi

  # Generate report if requested
  if [[ -n "$REPORT_FILE" ]]; then
    generate_report "$total" "$passed" "$failed" "$not_found" passed_scripts failed_scripts
  fi

  # Exit code logic
  if ((STRICT_MODE && failed > 0)); then
    return 1
  else
    return 0
  fi
}

# Generate compliance report
generate_report() {
  local -i total=$1 passed=$2 failed=$3 not_found=$4
  local -n passed_ref=$5 failed_ref=$6

  info "Generating report: $REPORT_FILE"

  {
    if [[ "$OUTPUT_FORMAT" == "markdown" ]]; then
      cat <<EOF
# BCS Compliance Report

Generated: $(date '+%Y-%m-%d %H:%M:%S')

## Summary

- **Total scripts:** $total
- **Passed:** $passed
- **Failed:** $failed
- **Not found:** $not_found

## Results

### Passed Scripts

EOF
      for script in "${passed_ref[@]}"; do
        echo "- ✓ \`$script\`"
      done

      if [[ "$failed" -gt 0 ]]; then
        cat <<EOF

### Failed Scripts

EOF
        for script in "${failed_ref[@]}"; do
          echo "- ✗ \`$script\`"
        done
      fi
    elif [[ "$OUTPUT_FORMAT" == "json" ]]; then
      cat <<EOF
{
  "generated": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "summary": {
    "total": $total,
    "passed": $passed,
    "failed": $failed,
    "not_found": $not_found
  },
  "passed_scripts": [
EOF
      local -i count=0
      for script in "${passed_ref[@]}"; do
        ((count > 0)) && echo ","
        echo -n "    \"$script\""
        ((count+=1))
      done
      echo ""
      echo "  ],"
      echo "  \"failed_scripts\": ["
      count=0
      for script in "${failed_ref[@]}"; do
        ((count > 0)) && echo ","
        echo -n "    \"$script\""
        ((count+=1))
      done
      echo ""
      echo "  ]"
      echo "}"
    else
      # Text format
      cat <<EOF
BCS Compliance Report
Generated: $(date '+%Y-%m-%d %H:%M:%S')

Summary:
  Total scripts: $total
  Passed: $passed
  Failed: $failed
  Not found: $not_found

Passed Scripts:
EOF
      for script in "${passed_ref[@]}"; do
        echo "  ✓ $script"
      done

      if [[ "$failed" -gt 0 ]]; then
        echo ""
        echo "Failed Scripts:"
        for script in "${failed_ref[@]}"; do
          echo "  ✗ $script"
        done
      fi
    fi
  } > "$REPORT_FILE"

  success "Report saved to: $REPORT_FILE"
}

# Main function
main() {
  local -i batch_mode
  local -a scripts

  # Parse arguments
  {
    read -r -d '' batch_mode || true
    mapfile -t -d '' scripts
  } < <(parse_arguments "$@")

  [[ "${#scripts[@]}" -gt 0 ]] || die 2 "No scripts to check"

  # Check mode
  if ((batch_mode || ${#scripts[@]} > 1)); then
    batch_check_scripts "${scripts[@]}"
  else
    check_single_script "${scripts[0]}"
  fi
}

main "$@"
#fin
