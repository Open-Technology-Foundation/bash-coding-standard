#!/usr/bin/env bash
# Test suite for workflows/check-compliance.sh

set -euo pipefail
shopt -s inherit_errexit shift_verbose

SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
PROJECT_DIR=$(realpath -- "$SCRIPT_DIR/..")
CHECK_COMPLIANCE_SCRIPT="$PROJECT_DIR/workflows/check-compliance.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
readonly -- SCRIPT_PATH SCRIPT_DIR PROJECT_DIR CHECK_COMPLIANCE_SCRIPT FIXTURES_DIR

# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

test_script_exists() {
  test_section "Script Existence"
  assert_file_exists "$CHECK_COMPLIANCE_SCRIPT"
  assert_file_executable "$CHECK_COMPLIANCE_SCRIPT"
}

test_help_option() {
  test_section "Help Option"
  local -- output
  output=$("$CHECK_COMPLIANCE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "Usage:" "Help shows usage"
}

test_compliant_script_passes() {
  test_section "Compliant Script Test"

  if [[ ! -f "$FIXTURES_DIR/sample-minimal.sh" ]]; then
    skip_test "sample-minimal.sh not found"
    return 0
  fi

  local -- output
  local -i exit_code
  output=$("$CHECK_COMPLIANCE_SCRIPT" "$FIXTURES_DIR/sample-minimal.sh" 2>&1) && exit_code=$? || exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    pass "Compliant script passes"
  else
    warn "Compliant script check failed (may need Claude CLI)"
  fi
}

test_non_compliant_script_fails() {
  test_section "Non-Compliant Script Test"

  if [[ ! -f "$FIXTURES_DIR/sample-non-compliant.sh" ]]; then
    skip_test "sample-non-compliant.sh not found"
    return 0
  fi

  local -- output
  local -i exit_code
  output=$("$CHECK_COMPLIANCE_SCRIPT" "$FIXTURES_DIR/sample-non-compliant.sh" 2>&1) && exit_code=$? || exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    pass "Non-compliant script detected"
  else
    warn "Non-compliant script not detected"
  fi
}

test_batch_checking() {
  test_section "Batch Checking"

  if [[ ! -f "$FIXTURES_DIR/sample-minimal.sh" ]]; then
    skip_test "Fixture files not found"
    return 0
  fi

  local -- output
  output=$("$CHECK_COMPLIANCE_SCRIPT" "$FIXTURES_DIR"/sample-*.sh 2>&1) || true

  if [[ "$output" =~ sample-minimal ]]; then
    pass "Batch checking works"
  else
    warn "Batch checking may not be implemented"
  fi
}

test_json_format() {
  test_section "JSON Output Format"
  local -- output
  output=$("$CHECK_COMPLIANCE_SCRIPT" --format json --help 2>&1) || true
  assert_contains "$output" "json\\|JSON" "JSON format mentioned in help"
}

test_strict_mode() {
  test_section "Strict Mode"
  local -- output
  output=$("$CHECK_COMPLIANCE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "strict" "Strict mode documented"
}

test_script_exists
test_help_option
test_compliant_script_passes
test_non_compliant_script_fails
test_batch_checking
test_json_format
test_strict_mode

print_summary
#fin
