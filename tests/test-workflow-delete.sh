#!/usr/bin/env bash
# Test suite for workflows/delete-rule.sh

set -euo pipefail
shopt -s inherit_errexit shift_verbose

SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
PROJECT_DIR=$(realpath -- "$SCRIPT_DIR/..")
DELETE_RULE_SCRIPT="$PROJECT_DIR/workflows/delete-rule.sh"
readonly -- SCRIPT_PATH SCRIPT_DIR PROJECT_DIR DELETE_RULE_SCRIPT

# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

test_script_exists() {
  test_section "Script Existence"
  assert_file_exists "$DELETE_RULE_SCRIPT"
  assert_file_executable "$DELETE_RULE_SCRIPT"
}

test_help_option() {
  test_section "Help Option"
  local -- output
  output=$("$DELETE_RULE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "Usage:" "Help shows usage"
  assert_contains "$output" "delete-rule" "Script name shown"
}

test_dry_run_mode() {
  test_section "Dry-Run Mode"
  local -- output
  output=$("$DELETE_RULE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "dry-run" "Dry-run option documented"
}

test_force_option() {
  test_section "Force Option"
  local -- output
  output=$("$DELETE_RULE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "force" "Force option documented"
}

test_backup_options() {
  test_section "Backup Options"
  local -- output
  output=$("$DELETE_RULE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "backup\\|no-backup" "Backup options documented"
}

test_reference_checking() {
  test_section "Reference Checking"
  local -- output
  output=$("$DELETE_RULE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "check-ref\\|no-check-ref\\|reference" "Reference checking documented"
}

test_quiet_mode() {
  test_section "Quiet Mode"
  local -- output
  output=$("$DELETE_RULE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "quiet" "Quiet mode documented"
}

test_script_exists
test_help_option
test_dry_run_mode
test_force_option
test_backup_options
test_reference_checking
test_quiet_mode

print_summary
#fin
