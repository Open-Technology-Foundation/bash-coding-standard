#!/usr/bin/env bash
# Test helper functions for bash-coding-standard test suite

# Test counters
declare -gi TESTS_RUN=0 TESTS_PASSED=0 TESTS_FAILED=0
declare -a FAILED_TESTS=()

# Colors for output
if [[ -t 1 ]]; then
  declare -gr GREEN=$'\033[0;32m' RED=$'\033[0;31m' YELLOW=$'\033[0;33m' NC=$'\033[0m'
else
  declare -gr GREEN='' RED='' YELLOW='' NC=''
fi

# Assert functions
assert_equals() {
  local -- expected="$1"
  local -- actual="$2"
  local -- test_name="${3:-Assertion}"

  TESTS_RUN+=1

  if [[ "$expected" == "$actual" ]]; then
    TESTS_PASSED+=1
    echo "${GREEN}✓${NC} $test_name"
    return 0
  else
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    echo "${RED}✗${NC} $test_name"
    echo "  Expected: '$expected'"
    echo "  Actual:   '$actual'"
    return 1
  fi
}

assert_contains() {
  local -- haystack="$1"
  local -- needle="$2"
  local -- test_name="${3:-Contains assertion}"

  TESTS_RUN+=1

  if [[ "$haystack" =~ $needle ]]; then
    TESTS_PASSED+=1
    echo "${GREEN}✓${NC} $test_name"
    return 0
  else
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    echo "${RED}✗${NC} $test_name"
    echo "  Expected to contain: '$needle'"
    echo "  Actual output: '$haystack'"
    return 1
  fi
}

assert_not_contains() {
  local -- haystack="$1"
  local -- needle="$2"
  local -- test_name="${3:-Not contains assertion}"

  TESTS_RUN+=1

  if [[ ! "$haystack" =~ $needle ]]; then
    TESTS_PASSED+=1
    echo "${GREEN}✓${NC} $test_name"
    return 0
  else
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    echo "${RED}✗${NC} $test_name"
    echo "  Expected NOT to contain: '$needle'"
    echo "  Actual output: '$haystack'"
    return 1
  fi
}

assert_exit_code() {
  local -i expected="$1"
  local -i actual="$2"
  local -- test_name="${3:-Exit code assertion}"

  TESTS_RUN+=1

  if ((expected == actual)); then
    TESTS_PASSED+=1
    echo "${GREEN}✓${NC} $test_name"
    return 0
  else
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    echo "${RED}✗${NC} $test_name"
    echo "  Expected exit code: $expected"
    echo "  Actual exit code: $actual"
    return 1
  fi
}

assert_file_exists() {
  local -- file="$1"
  local -- test_name="${2:-File exists: $file}"

  TESTS_RUN+=1

  if [[ -f "$file" ]]; then
    TESTS_PASSED+=1
    echo "${GREEN}✓${NC} $test_name"
    return 0
  else
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    echo "${RED}✗${NC} $test_name"
    echo "  File not found: $file"
    return 1
  fi
}

assert_success() {
  local -i exit_code="$1"
  local -- test_name="${2:-Command should succeed}"

  TESTS_RUN+=1

  if ((exit_code == 0)); then
    TESTS_PASSED+=1
    echo "${GREEN}✓${NC} $test_name"
    return 0
  else
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    echo "${RED}✗${NC} $test_name"
    echo "  Expected success (0), got exit code: $exit_code"
    return 1
  fi
}

assert_failure() {
  local -i exit_code="$1"
  local -- test_name="${2:-Command should fail}"

  TESTS_RUN+=1

  if ((exit_code != 0)); then
    TESTS_PASSED+=1
    echo "${GREEN}✓${NC} $test_name"
    return 0
  else
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    echo "${RED}✗${NC} $test_name"
    echo "  Expected failure (non-zero), got exit code: 0"
    return 1
  fi
}

# Simple pass/warn/fail helpers for conditional tests
pass() {
  local -- message="$*"
  TESTS_RUN+=1
  TESTS_PASSED+=1
  echo "${GREEN}✓${NC} $message"
  return 0
}

warn() {
  local -- message="$*"
  TESTS_RUN+=1
  TESTS_PASSED+=1  # Count as passed with warning
  echo "${YELLOW}⚠${NC} $message"
  return 0
}

fail() {
  local -- message="$*"
  TESTS_RUN+=1
  TESTS_FAILED+=1
  FAILED_TESTS+=("$message")
  echo "${RED}✗${NC} $message"
  return 1
}

# Convenience aliases for assert_exit_code
assert_zero() {
  assert_exit_code 0 "$1" "${2:-Exit code should be 0}"
}

assert_not_zero() {
  local -i exit_code="$1"
  local -- test_name="${2:-Exit code should be non-zero}"

  TESTS_RUN+=1

  if ((exit_code != 0)); then
    TESTS_PASSED+=1
    echo "${GREEN}✓${NC} $test_name"
    return 0
  else
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    echo "${RED}✗${NC} $test_name"
    echo "  Expected non-zero exit code, got: 0"
    return 1
  fi
}

# Assert not empty
assert_not_empty() {
  local -- value="$1"
  local -- test_name="${2:-Value should not be empty}"

  TESTS_RUN+=1

  if [[ -n "$value" ]]; then
    TESTS_PASSED+=1
    echo "${GREEN}✓${NC} $test_name"
    return 0
  else
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    echo "${RED}✗${NC} $test_name"
    echo "  Expected non-empty value"
    return 1
  fi
}

# Test section header
test_section() {
  echo
  echo "${YELLOW}━━━ $* ━━━${NC}"
  echo
}

# Print test summary
print_summary() {
  echo
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Test Summary:"
  echo "  Total:  $TESTS_RUN"
  echo "  ${GREEN}Passed: $TESTS_PASSED${NC}"
  echo "  ${RED}Failed: $TESTS_FAILED${NC}"

  if ((TESTS_FAILED > 0)); then
    echo
    echo "Failed tests:"
    local -- test
    for test in "${FAILED_TESTS[@]}"; do
      echo "  ${RED}✗${NC} $test"
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    return 1
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  return 0
}

# Alias for backward compatibility
test_summary() {
  print_summary "$@"
}

# Enhanced assertions (added in test suite revamp)

# Assert file contains specific text
assert_file_contains() {
  local -- file="$1"
  local -- text="$2"
  local -- test_name="${3:-File $file should contain: $text}"

  TESTS_RUN+=1

  if [[ ! -f "$file" ]]; then
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    echo "${RED}✗${NC} $test_name"
    echo "  File not found: $file"
    return 1
  fi

  if grep -qF "$text" "$file"; then
    TESTS_PASSED+=1
    echo "${GREEN}✓${NC} $test_name"
    return 0
  else
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    echo "${RED}✗${NC} $test_name"
    echo "  File does not contain: $text"
    return 1
  fi
}

# Assert regex match
assert_regex_match() {
  local -- text="$1"
  local -- pattern="$2"
  local -- test_name="${3:-Text should match pattern: $pattern}"

  TESTS_RUN+=1

  if [[ "$text" =~ $pattern ]]; then
    TESTS_PASSED+=1
    echo "${GREEN}✓${NC} $test_name"
    return 0
  else
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    echo "${RED}✗${NC} $test_name"
    echo "  Pattern: $pattern"
    echo "  Text: $text"
    return 1
  fi
}

# Assert line count between range
assert_lines_between() {
  local -- text="$1"
  local -i min="$2"
  local -i max="$3"
  local -- test_name="${4:-Line count should be between $min and $max}"

  TESTS_RUN+=1

  local -i actual_lines
  actual_lines=$(echo "$text" | wc -l)

  if ((actual_lines >= min && actual_lines <= max)); then
    TESTS_PASSED+=1
    echo "${GREEN}✓${NC} $test_name (actual: $actual_lines)"
    return 0
  else
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    echo "${RED}✗${NC} $test_name"
    echo "  Expected: $min-$max lines"
    echo "  Actual: $actual_lines lines"
    return 1
  fi
}

# Skip a test with reason
skip_test() {
  local -- reason="$*"
  TESTS_RUN+=1
  TESTS_PASSED+=1
  echo "${YELLOW}⊘${NC} SKIPPED: $reason"
  return 0
}

# Setup test environment (create temp dir, set traps)
setup_test_env() {
  local -- test_name="${1:-test}"

  # Create temp directory
  local -- temp_dir
  temp_dir=$(mktemp -d "/tmp/bcs-test-${test_name}-XXXXXX")

  # Set cleanup trap
  trap "rm -rf '$temp_dir'" RETURN EXIT

  echo "$temp_dir"
}

# Cleanup test environment
cleanup_test_env() {
  local -- temp_dir="$1"

  if [[ -d "$temp_dir" ]]; then
    rm -rf "$temp_dir"
  fi
}

# Mock a command (create fake command in temp PATH)
mock_command() {
  local -- cmd_name="$1"
  local -- mock_output="$2"
  local -i mock_exit_code="${3:-0}"

  # Create mock directory if not exists
  if [[ ! -d "/tmp/bcs-mocks" ]]; then
    mkdir -p /tmp/bcs-mocks
  fi

  # Create mock script
  cat > "/tmp/bcs-mocks/$cmd_name" <<MOCK_SCRIPT
#!/usr/bin/env bash
cat <<'MOCK_OUTPUT'
$mock_output
MOCK_OUTPUT
exit $mock_exit_code
MOCK_SCRIPT

  chmod +x "/tmp/bcs-mocks/$cmd_name"

  # Add to PATH
  export PATH="/tmp/bcs-mocks:$PATH"

  echo "Mocked: $cmd_name"
}

# Unmock command (remove from mock directory)
unmock_command() {
  local -- cmd_name="$1"

  if [[ -f "/tmp/bcs-mocks/$cmd_name" ]]; then
    rm -f "/tmp/bcs-mocks/$cmd_name"
  fi
}

# Create test BCS rule file
create_test_bcs_rule() {
  local -- output_file="$1"
  local -- rule_code="${2:-BCS9999}"
  local -- rule_title="${3:-Test Rule}"

  cat > "$output_file" <<TEST_RULE
**Rule: $rule_code**

### $rule_title

This is a test rule for testing purposes.

---

## Example

\`\`\`bash
echo "Test example"
\`\`\`

---

## Summary

This is a test rule summary.
TEST_RULE

  echo "Created test rule: $output_file"
}

# Assert directory exists
assert_dir_exists() {
  local -- dir="$1"
  local -- test_name="${2:-Directory exists: $dir}"

  TESTS_RUN+=1

  if [[ -d "$dir" ]]; then
    TESTS_PASSED+=1
    echo "${GREEN}✓${NC} $test_name"
    return 0
  else
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    echo "${RED}✗${NC} $test_name"
    echo "  Directory not found: $dir"
    return 1
  fi
}

# Assert file is executable
assert_file_executable() {
  local -- file="$1"
  local -- test_name="${2:-File is executable: $file}"

  TESTS_RUN+=1

  if [[ -x "$file" ]]; then
    TESTS_PASSED+=1
    echo "${GREEN}✓${NC} $test_name"
    return 0
  else
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    echo "${RED}✗${NC} $test_name"
    echo "  File is not executable: $file"
    return 1
  fi
}

# Assert greater than
assert_greater_than() {
  local -i actual="$1"
  local -i threshold="$2"
  local -- test_name="${3:-Value should be > $threshold}"

  TESTS_RUN+=1

  if ((actual > threshold)); then
    TESTS_PASSED+=1
    echo "${GREEN}✓${NC} $test_name (actual: $actual)"
    return 0
  else
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    echo "${RED}✗${NC} $test_name"
    echo "  Expected: > $threshold"
    echo "  Actual: $actual"
    return 1
  fi
}

# Assert less than
assert_less_than() {
  local -i actual="$1"
  local -i threshold="$2"
  local -- test_name="${3:-Value should be < $threshold}"

  TESTS_RUN+=1

  if ((actual < threshold)); then
    TESTS_PASSED+=1
    echo "${GREEN}✓${NC} $test_name (actual: $actual)"
    return 0
  else
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    echo "${RED}✗${NC} $test_name"
    echo "  Expected: < $threshold"
    echo "  Actual: $actual"
    return 1
  fi
}

#fin
