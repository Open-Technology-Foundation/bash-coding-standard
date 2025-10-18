#!/usr/bin/env bash
# Tests for bcs search subcommand

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Load test helpers
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

SCRIPT="$SCRIPT_DIR"/../bash-coding-standard

test_search_help() {
  test_section "Search Help Tests"

  local -- output
  output=$("$SCRIPT" search --help 2>&1)

  assert_contains "$output" "Usage:" "search --help shows usage"
  assert_contains "$output" "bcs search" "Help mentions search command"
  assert_contains "$output" "-i" "Help shows -i option"
  assert_contains "$output" "-C" "Help shows -C option"
}

test_search_basic() {
  test_section "Basic Search Tests"

  local -- output
  output=$("$SCRIPT" search "readonly" 2>&1)

  # Should find matches
  assert_contains "$output" "readonly" "Search finds 'readonly'"

  # Should show line numbers (from grep -n)
  assert_contains "$output" "[0-9]+:" "Output includes line numbers"
}

test_search_case_insensitive() {
  test_section "Case-Insensitive Search Tests"

  local -- output
  output=$("$SCRIPT" search -i "SET -E" 2>&1)

  # Should find matches with different case
  assert_contains "$output" "set -e" "Case-insensitive search works"
}

test_search_with_context() {
  test_section "Search Context Tests"

  local -- output
  output=$("$SCRIPT" search -C 5 "declare -fx" 2>&1)

  # Should include context lines
  # Context is indicated by -- separators in grep output
  if [[ "$output" =~ -- ]]; then
    pass "Search output includes context separator"
  fi

  assert_contains "$output" "declare -fx" "Search finds pattern with context"
}

test_search_no_matches() {
  test_section "Search No Matches Tests"

  local -- output
  local -i exit_code=0
  output=$("$SCRIPT" search "NONEXISTENT_PATTERN_12345" 2>&1) || exit_code=$?

  # Should return non-zero exit code
  assert_not_zero "$exit_code" "No matches returns non-zero exit code"

  # Should have message about no matches
  assert_contains "$output" "No matches" "Message about no matches"
}

test_search_multiword() {
  test_section "Search Multi-word Pattern Tests"

  local -- output
  output=$("$SCRIPT" search "set -e" 2>&1)

  # Should find multi-word patterns
  assert_contains "$output" "set -e" "Can search for multi-word patterns"
}

test_search_regex_pattern() {
  test_section "Search Regex Pattern Tests"

  local -- output
  output=$("$SCRIPT" search "declare -[ia]" 2>&1)

  # Should find declare -i or declare -a
  if [[ "$output" =~ declare\ -[ia] ]]; then
    pass "Regex pattern search works"
  else
    fail "Regex pattern search failed"
  fi
}

test_search_alias() {
  test_section "Search Alias Tests"

  # Test grep alias
  local -- output1 output2
  output1=$("$SCRIPT" search "readonly" 2>&1 | head -5 || true)
  output2=$("$SCRIPT" grep "readonly" 2>&1 | head -5 || true)

  assert_equals "$output1" "$output2" "search and grep produce same output"
}

test_search_missing_pattern() {
  test_section "Search Error Handling Tests"

  local -- output
  local -i exit_code=0
  output=$("$SCRIPT" search 2>&1) || exit_code=$?

  # Should produce error when no pattern specified
  assert_not_zero "$exit_code" "Missing pattern returns error"
  assert_contains "$output" "✗" "Error message when pattern missing"
}

# Run all tests
test_search_help
test_search_basic
test_search_case_insensitive
test_search_with_context
test_search_no_matches
test_search_multiword
test_search_regex_pattern
test_search_missing_pattern

print_summary

#fin
