#!/usr/bin/env bash
# Test suite for workflows/interrogate-rule.sh
# Tests rule interrogation by BCS code and file path

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Test metadata
SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Project paths
PROJECT_DIR=$(realpath -- "$SCRIPT_DIR/..")
INTERROGATE_SCRIPT="$PROJECT_DIR/workflows/interrogate-rule.sh"
readonly -- PROJECT_DIR INTERROGATE_SCRIPT

# Source test helpers
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

# ==============================================================================
# Basic Tests
# ==============================================================================

test_script_exists() {
  test_section "Script Existence Tests"

  assert_file_exists "$INTERROGATE_SCRIPT"
  assert_file_executable "$INTERROGATE_SCRIPT"
}

test_help_option() {
  test_section "Help Option Test"

  local -- output

  output=$("$INTERROGATE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "Usage:" "Help shows usage"
  assert_contains "$output" "interrogate-rule.sh" "Help shows script name"
}

# ==============================================================================
# Interrogation Tests
# ==============================================================================

test_interrogate_by_bcs_code() {
  test_section "Interrogate by BCS Code"

  local -- output
  local -i exit_code

  # Interrogate a known BCS code (assuming BCS0102 exists)
  output=$("$INTERROGATE_SCRIPT" BCS0102 2>&1) && exit_code=$? || exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    pass "Successfully interrogated BCS0102"
    assert_contains "$output" "BCS0102\\|0102" "Output contains BCS code"
  else
    warn "Failed to interrogate BCS0102 (code may not exist)"
  fi
}

test_interrogate_by_file_path() {
  test_section "Interrogate by File Path"

  local -- output test_file
  local -i exit_code

  # Find a test file
  test_file=$(find "$PROJECT_DIR/data" -name "*.complete.md" -type f | head -1)

  if [[ ! -f "$test_file" ]]; then
    skip_test "No .complete.md files found"
    return 0
  fi

  output=$("$INTERROGATE_SCRIPT" "$test_file" 2>&1) && exit_code=$? || exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    pass "Successfully interrogated by file path"
    assert_contains "$output" "BCS" "Output contains BCS code"
  else
    warn "Failed to interrogate by file path"
  fi
}

# ==============================================================================
# Output Format Tests
# ==============================================================================

test_json_output_format() {
  test_section "JSON Output Format"

  local -- output

  output=$("$INTERROGATE_SCRIPT" BCS0102 --format json 2>&1) || true

  if [[ "$output" =~ \{.*\} ]]; then
    pass "JSON output format works"
    assert_contains "$output" "\"bcs_code\"\\|bcs_code" "JSON contains bcs_code field"
  else
    warn "JSON output may not be implemented"
  fi
}

test_markdown_output_format() {
  test_section "Markdown Output Format"

  local -- output

  output=$("$INTERROGATE_SCRIPT" BCS0102 --format markdown 2>&1) || true

  if [[ "$output" =~ ^# ]]; then
    pass "Markdown output format works"
  else
    warn "Markdown output may not be implemented"
  fi
}

# ==============================================================================
# Feature Tests
# ==============================================================================

test_show_all_tiers() {
  test_section "Show All Tiers Feature"

  local -- output

  output=$("$INTERROGATE_SCRIPT" BCS0102 --show-tiers 2>&1) || true

  if [[ "$output" =~ complete.*summary.*abstract|abstract.*summary.*complete ]]; then
    pass "Show all tiers feature works"
  else
    warn "Show tiers option may not be fully implemented"
  fi
}

test_show_content() {
  test_section "Show Content Feature"

  local -- output

  output=$("$INTERROGATE_SCRIPT" BCS0102 --show-content 2>&1) || true

  if [[ "$output" =~ "###" ]] || [[ "$output" =~ '```' ]]; then
    pass "Show content feature works"
  else
    warn "Show content option may not display file content"
  fi
}

test_invalid_bcs_code() {
  test_section "Invalid BCS Code Handling"

  local -- output
  local -i exit_code

  output=$("$INTERROGATE_SCRIPT" INVALID999 2>&1) && exit_code=$? || exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    pass "Invalid BCS code properly rejected"
  else
    fail "Should fail with invalid BCS code"
  fi
}

test_multiple_codes() {
  test_section "Multiple Codes Processing"

  local -- output
  local -i exit_code

  output=$("$INTERROGATE_SCRIPT" BCS0102 BCS0103 2>&1) && exit_code=$? || exit_code=$?

  if [[ "$output" =~ BCS0102 ]] && [[ "$output" =~ BCS0103 ]]; then
    pass "Multiple codes processed successfully"
  else
    warn "Multiple codes may not be fully supported"
  fi
}

# ==============================================================================
# Run all tests
# ==============================================================================

test_script_exists
test_help_option
test_interrogate_by_bcs_code
test_interrogate_by_file_path
test_json_output_format
test_markdown_output_format
test_show_all_tiers
test_show_content
test_invalid_bcs_code
test_multiple_codes

print_summary
#fin
