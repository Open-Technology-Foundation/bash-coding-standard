#!/usr/bin/env bash
# Test suite for workflows/generate-canonical.sh

set -euo pipefail
shopt -s inherit_errexit shift_verbose

SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
PROJECT_DIR=$(realpath -- "$SCRIPT_DIR/..")
GENERATE_SCRIPT="$PROJECT_DIR/workflows/generate-canonical.sh"
readonly -- SCRIPT_PATH SCRIPT_DIR PROJECT_DIR GENERATE_SCRIPT

# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

test_script_exists() {
  test_section "Script Existence"
  assert_file_exists "$GENERATE_SCRIPT"
  assert_file_executable "$GENERATE_SCRIPT"
}

test_help_option() {
  test_section "Help Option"
  local -- output
  output=$("$GENERATE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "Usage:" "Help shows usage"
  assert_contains "$output" "generate-canonical" "Script name shown"
}

test_dry_run_mode() {
  test_section "Dry-Run Mode"
  local -- output
  output=$("$GENERATE_SCRIPT" --dry-run 2>&1) || true
  assert_contains "$output" "DRY-RUN\\|DRY RUN" "Dry-run mode indicated"
}

test_tier_options() {
  test_section "Tier Options"
  local -- output
  output=$("$GENERATE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "tier\\|complete\\|summary\\|abstract" "Tier options documented"
}

test_backup_option() {
  test_section "Backup Option"
  local -- output
  output=$("$GENERATE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "backup" "Backup option documented"
}

test_validate_option() {
  test_section "Validate Option"
  local -- output
  output=$("$GENERATE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "validate" "Validate option documented"
}

test_script_exists
test_help_option
test_dry_run_mode
test_tier_options
test_backup_option
test_validate_option

print_summary
#fin
