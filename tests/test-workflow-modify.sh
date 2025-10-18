#!/usr/bin/env bash
# Test suite for workflows/modify-rule.sh

set -euo pipefail
shopt -s inherit_errexit shift_verbose

SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
PROJECT_DIR=$(realpath -- "$SCRIPT_DIR/..")
MODIFY_RULE_SCRIPT="$PROJECT_DIR/workflows/modify-rule.sh"
readonly -- SCRIPT_PATH SCRIPT_DIR PROJECT_DIR MODIFY_RULE_SCRIPT

# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

test_script_exists() {
  test_section "Script Existence"
  assert_file_exists "$MODIFY_RULE_SCRIPT"
  assert_file_executable "$MODIFY_RULE_SCRIPT"
}

test_help_option() {
  test_section "Help Option"
  local -- output
  output=$("$MODIFY_RULE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "Usage:" "Help shows usage"
  assert_contains "$output" "modify-rule\\|CODE_OR_FILE" "Script name or argument shown"
}

test_editor_option() {
  test_section "Editor Option"
  local -- output
  output=$("$MODIFY_RULE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "editor\\|EDITOR" "Editor option documented"
}

test_backup_options() {
  test_section "Backup Options"
  local -- output
  output=$("$MODIFY_RULE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "backup\\|no-backup" "Backup options documented"
}

test_compress_option() {
  test_section "Compress Option"
  local -- output
  output=$("$MODIFY_RULE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "compress\\|no-compress" "Compress option documented"
}

test_validate_option() {
  test_section "Validate Option"
  local -- output
  output=$("$MODIFY_RULE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "validate" "Validate option documented"
}

test_script_exists
test_help_option
test_editor_option
test_backup_options
test_compress_option
test_validate_option

print_summary
#fin
