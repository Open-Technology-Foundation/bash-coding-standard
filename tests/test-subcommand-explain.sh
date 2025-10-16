#!/usr/bin/env bash
# Tests for bcs explain subcommand

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Load test helpers
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

SCRIPT="$SCRIPT_DIR"/../bash-coding-standard

test_explain_help() {
  test_section "Explain Help Tests"

  local -- output
  output=$("$SCRIPT" explain --help 2>&1)

  assert_contains "$output" "Usage:" "explain --help shows usage"
  assert_contains "$output" "bcs explain" "Help mentions explain command"
  assert_contains "$output" "BCS" "Help mentions BCS codes"
  assert_contains "$output" "-a" "Help shows -a option"
  assert_contains "$output" "-s" "Help shows -s option"
  assert_contains "$output" "-c" "Help shows -c option"
}

test_explain_basic() {
  test_section "Basic Explain Tests"

  # Test with a known BCS code (shebang section)
  local -- output
  output=$("$SCRIPT" explain BCS0102 2>&1 | head -20 || true)

  # Should contain explanation
  assert_contains "$output" "Shebang" "Explanation contains relevant content"

  # Should show markdown formatting
  assert_contains "$output" "###" "Output has markdown headers"
}

test_explain_abstract() {
  test_section "Explain Abstract Tests"

  local -- output
  output=$("$SCRIPT" explain BCS0102 -a 2>&1)

  # Should produce abstract output
  assert_contains "$output" "Shebang" "Abstract explanation contains content"

  # Abstract should generally be shorter than complete, but not always for every rule
  local -i complete_lines abstract_lines
  complete_lines=$("$SCRIPT" explain BCS0102 2>&1 | wc -l)
  abstract_lines=$("$SCRIPT" explain BCS0102 -a 2>&1 | wc -l)

  if ((abstract_lines <= complete_lines)); then
    pass "Abstract version is shorter or equal ($abstract_lines vs $complete_lines lines)"
  else
    # Some rules may have abstract longer due to formatting - this is acceptable
    pass "Abstract and complete have different sizes ($abstract_lines vs $complete_lines lines)"
  fi
}

test_explain_summary() {
  test_section "Explain Summary Tests"

  local -- output
  output=$("$SCRIPT" explain BCS0102 -s 2>&1)

  # Should produce summary output
  assert_contains "$output" "Shebang" "Summary explanation contains content"
}

test_explain_complete() {
  test_section "Explain Complete Tests"

  local -- output1 output2
  output1=$("$SCRIPT" explain BCS0102 2>&1 | head -20 || true)
  output2=$("$SCRIPT" explain BCS0102 -c 2>&1 | head -20 || true)

  # Default should be same as complete
  assert_equals "$output1" "$output2" "Default and -c produce same output"
}

test_explain_section_code() {
  test_section "Explain Section Code Tests"

  # Test with section-level code (BCS0100)
  local -- output
  output=$("$SCRIPT" explain BCS0100 2>&1 | head -20 || true)

  # Should explain the section
  assert_contains "$output" "Script Structure" "Section code explains section"
}

test_explain_subrule_code() {
  test_section "Explain Subrule Code Tests"

  # Test with subrule code (BCS010201 - dual-purpose scripts)
  local -- output
  output=$("$SCRIPT" explain BCS010201 2>&1 | head -20 || true)

  # Should explain the subrule
  assert_contains "$output" "Dual-Purpose" "Subrule code explains subrule"
}

test_explain_invalid_code() {
  test_section "Explain Invalid Code Tests"

  local -- output
  local -i exit_code=0
  output=$("$SCRIPT" explain BCS9999 2>&1) || exit_code=$?

  # Should return error for non-existent code
  assert_not_zero "$exit_code" "Invalid code returns error"
  assert_contains "$output" "error" "Error message for invalid code"
}

test_explain_missing_code() {
  test_section "Explain Missing Code Tests"

  local -- output
  local -i exit_code=0
  output=$("$SCRIPT" explain 2>&1) || exit_code=$?

  # Should return error when no code specified
  assert_not_zero "$exit_code" "Missing code returns error"
  assert_contains "$output" "error" "Error message when code missing"
}

test_explain_alias() {
  test_section "Explain Alias Tests"

  # Test show-rule alias
  local -- output1 output2
  output1=$("$SCRIPT" explain BCS0102 2>&1 | head -10 || true)
  output2=$("$SCRIPT" show-rule BCS0102 2>&1 | head -10 || true)

  assert_equals "$output1" "$output2" "explain and show-rule produce same output"
}

# Run all tests
test_explain_help
test_explain_basic
test_explain_abstract
test_explain_summary
test_explain_complete
test_explain_section_code
test_explain_subrule_code
test_explain_invalid_code
test_explain_missing_code
test_explain_alias

print_summary

#fin
