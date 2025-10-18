#!/usr/bin/env bash
# Test suite for workflows/add-rule.sh

set -euo pipefail
shopt -s inherit_errexit shift_verbose

SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
PROJECT_DIR=$(realpath -- "$SCRIPT_DIR/..")
ADD_RULE_SCRIPT="$PROJECT_DIR/workflows/add-rule.sh"
readonly -- SCRIPT_PATH SCRIPT_DIR PROJECT_DIR ADD_RULE_SCRIPT

# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

test_script_exists() {
  test_section "Script Existence"
  assert_file_exists "$ADD_RULE_SCRIPT"
  assert_file_executable "$ADD_RULE_SCRIPT"
}

test_help_option() {
  test_section "Help Option"
  local -- output
  output=$("$ADD_RULE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "Usage:" "Help shows usage"
  assert_contains "$output" "add-rule" "Script name shown"
}

test_section_option() {
  test_section "Section Option"
  local -- output
  output=$("$ADD_RULE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "section" "Section option documented"
}

test_number_option() {
  test_section "Number Option"
  local -- output
  output=$("$ADD_RULE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "number" "Number option documented"
}

test_name_option() {
  test_section "Name Option"
  local -- output
  output=$("$ADD_RULE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "name" "Name option documented"
}

test_template_options() {
  test_section "Template Options"
  local -- output
  output=$("$ADD_RULE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "template" "Template option documented"
}

test_no_interactive_mode() {
  test_section "Non-Interactive Mode"
  local -- output
  output=$("$ADD_RULE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "no-interactive" "Non-interactive mode documented"
}

test_script_exists
test_help_option
test_section_option
test_number_option
test_name_option
test_template_options
test_no_interactive_mode

print_summary
#fin
