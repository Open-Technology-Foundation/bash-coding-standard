#!/usr/bin/env bash
# Tests for bcs sections subcommand

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Load test helpers
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

SCRIPT="$SCRIPT_DIR"/../bash-coding-standard

test_sections_help() {
  test_section "Sections Help Tests"

  local -- output
  output=$("$SCRIPT" sections --help 2>&1)

  assert_contains "$output" "Usage:" "sections --help shows usage"
  assert_contains "$output" "bcs sections" "Help mentions sections command"
}

test_sections_basic_output() {
  test_section "Basic Sections Output Tests"

  local -- output
  output=$("$SCRIPT" sections 2>&1)

  # Should have content
  assert_not_empty "$output" "bcs sections produces output"

  # Should contain numbered items
  assert_contains "$output" "[0-9]+\." "Output contains numbered items"
}

test_sections_count() {
  test_section "Sections Count Tests"

  local -i count
  count=$("$SCRIPT" sections 2>&1 | wc -l)

  # Should have approximately 16 sections
  if ((count >= 14 && count <= 18)); then
    pass "Section count is reasonable: $count sections"
  else
    warn "Section count may be unexpected: $count sections (expected ~16)"
  fi
}

test_sections_content() {
  test_section "Sections Content Tests"

  local -- output
  output=$("$SCRIPT" sections 2>&1)

  # Should contain known section names
  assert_contains "$output" "Script Structure" "Contains Script Structure section"
  assert_contains "$output" "Variable" "Contains Variable section"
  assert_contains "$output" "Functions" "Contains Functions section"
  assert_contains "$output" "Error Handling" "Contains Error Handling section"
  assert_contains "$output" "Advanced Patterns" "Contains Advanced Patterns section"
}

test_sections_numbering() {
  test_section "Sections Numbering Tests"

  local -- output
  output=$("$SCRIPT" sections 2>&1)

  # First line should start with 1.
  local -- first_line
  first_line=$(echo "$output" | head -1 || true)

  if [[ "$first_line" =~ ^1\. ]]; then
    pass "First section starts with 1."
  else
    fail "First section doesn't start with 1. (got: $first_line)"
  fi

  # Should have sequential numbering
  if [[ "$output" =~ 2\. ]] && [[ "$output" =~ 3\. ]]; then
    pass "Sections are numbered sequentially"
  else
    fail "Sequential numbering not found"
  fi
}

test_sections_alias() {
  test_section "Sections Alias Tests"

  # Test toc alias
  local -- output1 output2
  output1=$("$SCRIPT" sections 2>&1)
  output2=$("$SCRIPT" toc 2>&1)

  assert_equals "$output1" "$output2" "sections and toc produce same output"
}

test_sections_exit_code() {
  test_section "Sections Exit Code Tests"

  local -i exit_code=0
  "$SCRIPT" sections >/dev/null 2>&1 || exit_code=$?

  assert_zero "$exit_code" "sections command exits with 0"
}

# Run all tests
test_sections_help
test_sections_basic_output
test_sections_count
test_sections_content
test_sections_numbering
test_sections_alias
test_sections_exit_code

print_summary

#fin
