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

#fin
