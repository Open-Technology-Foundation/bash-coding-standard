#!/usr/bin/env bash
# Comprehensive test suite for bash-coding-standard script
# Tests both original and fixed versions

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Test metadata
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
PROJECT_DIR=${SCRIPT_DIR%/*}
readonly -- SCRIPT_PATH SCRIPT_DIR PROJECT_DIR

# Test configuration
declare -i TESTS_RUN=0 TESTS_PASSED=0 TESTS_FAILED=0
declare -a FAILED_TESTS=()

# Test the main script
declare -a TEST_SCRIPTS=(
  "$PROJECT_DIR/bash-coding-standard"
)

# Colors for output
if [[ -t 1 ]]; then
  readonly GREEN=$'\033[0;32m' RED=$'\033[0;31m' YELLOW=$'\033[0;33m' NC=$'\033[0m'
else
  readonly GREEN='' RED='' YELLOW='' NC=''
fi

# Test result tracking
pass() {
  TESTS_PASSED+=1
  echo "${GREEN}✓${NC} ${*:-}"
}

fail() {
  TESTS_FAILED+=1
  FAILED_TESTS+=("${*:-}")
  echo "${RED}✗${NC} ${*:-}"
}

info() {
  echo "${YELLOW}◉${NC} ${*:-}"
}

# Test helper functions
assert_equals() {
  local -- expected="$1" actual="$2" test_name="$3"
  TESTS_RUN+=1
  if [[ "$expected" == "$actual" ]]; then
    pass "$test_name"
    return 0
  else
    fail "$test_name"
    echo "  Expected: '$expected'"
    echo "  Actual:   '$actual'"
    return 1
  fi
}

assert_contains() {
  local -- pattern="$1" actual="$2" test_name="$3"
  TESTS_RUN+=1
  if [[ "$actual" =~ $pattern ]]; then
    pass "$test_name"
    return 0
  else
    fail "$test_name"
    echo "  Pattern: '$pattern'"
    echo "  Actual:  '$actual'"
    return 1
  fi
}

assert_exit_code() {
  local -i expected=$1
  local -- test_name="$2"
  shift 2
  local -i actual
  TESTS_RUN+=1

  set +eu
  "$@" &>/dev/null
  actual=$?
  set -eu

  if ((expected == actual)); then
    pass "$test_name"
    return 0
  else
    fail "$test_name"
    echo "  Expected exit code: $expected"
    echo "  Actual exit code:   $actual"
    return 1
  fi
}

assert_file_readable() {
  local -- file="$1" test_name="$2"
  TESTS_RUN+=1
  if [[ -r "$file" ]]; then
    pass "$test_name"
    return 0
  else
    fail "$test_name"
    echo "  File not readable: $file"
    return 1
  fi
}

# Test functions
test_help_output() {
  local -- script="$1"
  local -- output

  info "Testing --help output for $(basename "$script")"

  output=$("$script" --help)
  assert_contains "bcs - Bash Coding Standard toolkit" \
                  "$output" \
                  "Help contains title"

  assert_contains "Usage:" "$output" "Help contains usage"
  assert_contains "Options:" "$output" "Help contains options"
  assert_contains "Examples:" "$output" "Help contains examples"
}

test_version_output() {
  local -- script="$1"
  local -- output

  info "Testing --version output for $(basename "$script")"

  # Check if script supports --version
  if "$script" --help 2>&1 | grep -q -- '--version'; then
    output=$("$script" --version)
    assert_contains "bcs" "$output" "Version output contains script name"
    assert_contains "[0-9]+\.[0-9]+\.[0-9]+" "$output" "Version output contains version number"
  else
    info "  Skipping --version test (not supported in this version)"
  fi
}

test_cat_output() {
  local -- script="$1"
  local -- output

  info "Testing -c/--cat output for $(basename "$script")"

  output=$("$script" -c | head -5 || true)
  assert_contains "# Bash Coding Standard" "$output" "Cat output contains title"

  # Test both short and long forms
  local -- output_short output_long
  output_short=$("$script" -c | head -10 || true)
  output_long=$("$script" --cat | head -10 || true)
  assert_equals "$output_short" "$output_long" "Short and long cat forms produce same output"
}

test_json_output() {
  local -- script="$1"
  local -- output

  info "Testing -j/--json output for $(basename "$script")"

  output=$("$script" -j 2>/dev/null)

  # Validate JSON structure
  assert_contains '"bcs"' "$output" "JSON contains key"
  assert_contains '# Bash Coding Standard' "$output" "JSON contains content"

  # Test with jq if available
  if command -v jq &>/dev/null; then
    if echo "$output" | jq -e . &>/dev/null; then
      pass "JSON is valid (jq validation)"
      TESTS_RUN+=1
    else
      fail "JSON is invalid (jq validation failed)"
      TESTS_RUN+=1
    fi
  fi
}

test_bash_export() {
  local -- script="$1"
  local -- output

  info "Testing -b/--bash export for $(basename "$script")"

  output=$("$script" -b)
  assert_contains 'declare' "$output" "Bash export contains declare statement"
  assert_contains 'BCS_MD=' "$output" "Bash export contains BCS_MD variable"
  assert_contains '# Bash Coding Standard' "$output" "Bash export contains content"
}

test_sourcing() {
  local -- script="$1"
  local -- test_name="Sourcing $(basename "$script")"

  info "Testing sourcing for $test_name"

  TESTS_RUN+=1
  if bash -c "source '$script' && declare -p BCS_FILE BCS_MD &>/dev/null"; then
    pass "$test_name - variables initialized"
  else
    fail "$test_name - variables not initialized"
  fi

  TESTS_RUN+=1
  if bash -c "source '$script' && [[ -n \$BCS_MD ]]"; then
    pass "$test_name - BCS_MD populated"
  else
    fail "$test_name - BCS_MD not populated"
  fi
}

test_readonly_variables() {
  local -- script="$1"

  info "Testing readonly variables for $(basename "$script")"

  # Test in executed mode
  TESTS_RUN+=1
  local -- var_output
  var_output=$(bash -c "'$script' --help &>/dev/null; declare -p BCS_PATH BCS_FILE 2>/dev/null || echo 'not_set'")

  if [[ "$var_output" == "not_set" ]]; then
    info "  Skipping executed mode readonly test (variables not in global scope)"
  else
    if [[ "$var_output" =~ declare[[:space:]]+-[^[:space:]]*r ]]; then
      pass "Variables are readonly in executed mode"
    else
      fail "Variables are not readonly in executed mode"
    fi
  fi

  # Test in sourced mode
  TESTS_RUN+=1
  var_output=$(bash -c "source '$script' 2>/dev/null && declare -p BCS_PATH BCS_FILE BCS_MD")

  if [[ "$var_output" =~ declare[[:space:]]+-[^[:space:]]*r ]]; then
    pass "Variables are readonly in sourced mode"
  else
    fail "Variables are not readonly in sourced mode"
  fi
}

test_blank_line_preservation() {
  local -- script="$1"
  local -- output

  info "Testing blank line preservation for $(basename "$script")"

  # Find a section with intentional blank lines (e.g., around line 1560-1570)
  output=$("$script" -c | sed -n '1560,1570p')

  # Count blank lines in output
  local -i blank_count
  blank_count=$(echo "$output" | grep -c '^[[:space:]]*$' || true)

  TESTS_RUN+=1
  if ((blank_count >= 1)); then
    pass "Blank lines preserved (found $blank_count blank lines)"
  else
    fail "Blank lines may be squeezed (found only $blank_count blank lines)"
  fi
}

test_squeeze_option() {
  local -- script="$1"

  info "Testing -s/--squeeze option for $(basename "$script")"

  # Check if script supports --squeeze
  if "$script" --help 2>&1 | grep -q -- '--squeeze'; then
    # Create temp file with multiple consecutive blank lines
    local -- tmpfile
    tmpfile=$(mktemp)
    trap 'rm -f "$tmpfile"' RETURN

    printf 'Line 1\n\n\n\nLine 2\n' > "$tmpfile"

    # Test that squeeze option works
    local -- squeezed_count unsqueezed_count

    # This test would need the script to accept a file argument, which it doesn't
    # So we skip this test for now
    info "  Skipping squeeze test (requires file input support)"
  else
    info "  Skipping --squeeze test (not supported in this version)"
  fi
}

test_short_option_expansion() {
  local -- script="$1"

  info "Testing short option expansion for $(basename "$script")"

  # Test combined short options like -hc should work
  TESTS_RUN+=1
  if "$script" -h &>/dev/null; then
    pass "Short option -h works"
  else
    fail "Short option -h failed"
  fi
}

test_error_messages() {
  local -- script="$1"

  info "Testing error messages for $(basename "$script")"

  # Test with invalid option
  local -- error_output
  error_output=$("$script" --invalid-option 2>&1 || true)

  TESTS_RUN+=1
  if [[ -n "$error_output" ]]; then
    pass "Error message produced for invalid option"
  else
    fail "No error message for invalid option"
  fi

  # Unknown commands return exit code 1, not 2
  assert_exit_code 1 "Invalid option returns exit code 1" "$script" --invalid-option
}

test_missing_bcs_file() {
  local -- script="$1"

  info "Testing missing BASH-CODING-STANDARD.md handling for $(basename "$script")"

  # This test would need to temporarily move the file, which is destructive
  # So we skip it
  info "  Skipping missing file test (destructive)"
}

test_function_export() {
  local -- script="$1"

  info "Testing function export for $(basename "$script")"

  TESTS_RUN+=1
  if bash -c "source '$script' && declare -F cmd_display &>/dev/null"; then
    pass "cmd_display function is available after sourcing"
  else
    fail "cmd_display function not available after sourcing"
  fi

  TESTS_RUN+=1
  if bash -c "source '$script' && declare -Fx | grep -q cmd_display"; then
    pass "cmd_display function is exported"
  else
    fail "cmd_display function is not exported"
  fi
}

# Main test runner
main() {
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║  Bash Coding Standard Script Test Suite                       ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo

  for script in "${TEST_SCRIPTS[@]}"; do
    if [[ ! -f "$script" ]]; then
      echo "${YELLOW}⚠${NC} Skipping $(basename "$script") (not found)"
      continue
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Testing: $(basename "$script")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    # Run all test functions (continue even if one fails)
    test_help_output "$script" || true
    test_version_output "$script" || true
    test_cat_output "$script" || true
    test_json_output "$script" || true
    test_bash_export "$script" || true
    test_sourcing "$script" || true
    test_readonly_variables "$script" || true
    test_blank_line_preservation "$script" || true
    test_squeeze_option "$script" || true
    test_short_option_expansion "$script" || true
    test_error_messages "$script" || true
    test_function_export "$script" || true

    echo
  done

  # Summary
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║  Test Summary                                                  ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo
  echo "Tests run:    $TESTS_RUN"
  echo "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
  echo "Tests failed: ${RED}$TESTS_FAILED${NC}"
  echo

  if ((TESTS_FAILED > 0)); then
    echo "${RED}Failed tests:${NC}"
    for test in "${FAILED_TESTS[@]}"; do
      echo "  • $test"
    done
    echo
    exit 1
  else
    echo "${GREEN}✓ All tests passed!${NC}"
    exit 0
  fi
}

main "$@"

#fin
