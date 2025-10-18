#!/usr/bin/env bash
# Test suite for workflows/compress-rules.sh

set -euo pipefail
shopt -s inherit_errexit shift_verbose

SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
PROJECT_DIR=$(realpath -- "$SCRIPT_DIR/..")
COMPRESS_SCRIPT="$PROJECT_DIR/workflows/compress-rules.sh"
readonly -- SCRIPT_PATH SCRIPT_DIR PROJECT_DIR COMPRESS_SCRIPT

# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

test_script_exists() {
  test_section "Script Existence"
  assert_file_exists "$COMPRESS_SCRIPT"
  assert_file_executable "$COMPRESS_SCRIPT"
}

test_help_option() {
  test_section "Help Option"
  local -- output
  output=$("$COMPRESS_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "Usage:" "Help shows usage"
}

test_preflight_checks() {
  test_section "Pre-flight Checks"
  local -- output
  output=$("$COMPRESS_SCRIPT" --dry-run 2>&1) || true
  if [[ "$output" =~ pre-flight|preflight|check ]]; then
    pass "Pre-flight checks mentioned"
  else
    warn "Pre-flight checks may not be documented"
  fi
}

test_context_levels() {
  test_section "Context Level Options"
  local -- output
  output=$("$COMPRESS_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "context" "Context levels documented"
}

test_regenerate_option() {
  test_section "Regenerate Option"
  local -- output
  output=$("$COMPRESS_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "regenerate" "Regenerate option documented"
}

test_dry_run_mode() {
  test_section "Dry-Run Mode"
  local -- output
  output=$("$COMPRESS_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "dry-run" "Dry-run option documented"
}

test_script_exists
test_help_option
test_preflight_checks
test_context_levels
test_regenerate_option
test_dry_run_mode

print_summary
#fin
