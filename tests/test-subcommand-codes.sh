#!/usr/bin/env bash
# Tests for bcs codes subcommand

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Load test helpers
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

SCRIPT="$SCRIPT_DIR"/../bash-coding-standard

test_codes_basic_output() {
  test_section "Basic Codes Output Tests"

  local -- output
  output=$("$SCRIPT" codes 2>&1)

  # Should have content
  assert_not_empty "$output" "bcs codes produces output"

  # Should contain BCS codes
  assert_contains "$output" "BCS[0-9]" "Output contains BCS codes"

  # Should have colon-separated format
  assert_contains "$output" ":" "Output has colon-separated format"
}

test_codes_format() {
  test_section "Codes Format Tests"

  local -- output
  output=$("$SCRIPT" codes 2>&1 | head -5 || true)

  # Check format: BCS{code}:{shortname}:{title}
  local -- line
  while IFS= read -r line; do
    if [[ "$line" =~ ^BCS[0-9]+:[^:]+:.+ ]]; then
      pass "Line has correct format: ${line:0:50}..."
      break
    fi
  done <<< "$output"
}

test_codes_count() {
  test_section "Codes Count Tests"

  local -i count
  count=$("$SCRIPT" codes 2>&1 | wc -l)

  # Should have approximately 99 codes (allow some variance)
  if ((count >= 95 && count <= 105)); then
    pass "Code count is reasonable: $count codes"
  else
    fail "Code count seems wrong: $count codes (expected ~99)"
  fi
}

test_codes_sorting() {
  test_section "Codes Sorting Tests"

  local -- output
  output=$("$SCRIPT" codes 2>&1)

  # First few codes should start with BCS00, BCS01, etc.
  local -- first_line
  first_line=$(echo "$output" | head -1 || true)

  assert_contains "$first_line" "BCS00" "First code starts with BCS00"
}

test_codes_help() {
  test_section "Codes Help Tests"

  local -- output
  output=$("$SCRIPT" codes --help 2>&1)

  assert_contains "$output" "Usage:" "codes --help shows usage"
  assert_contains "$output" "bcs codes" "Help mentions codes command"
  assert_contains "$output" "BCS" "Help explains BCS codes"
}

test_codes_alias() {
  test_section "Codes Alias Tests"

  # Test list-codes alias
  local -- output1 output2
  output1=$("$SCRIPT" codes 2>&1)
  output2=$("$SCRIPT" list-codes 2>&1)

  assert_equals "$output1" "$output2" "codes and list-codes produce same output"
}

test_codes_with_missing_data() {
  test_section "Codes Error Handling Tests"

  # Test behavior when data directory doesn't exist
  # This test requires either mocking or is  skipped for now
  echo "Skipping missing data directory test (would require setup)"
}

# Run all tests
test_codes_basic_output
test_codes_format
test_codes_count
test_codes_sorting
test_codes_help
test_codes_alias
test_codes_with_missing_data

print_summary

#fin
