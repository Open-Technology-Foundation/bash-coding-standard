#!/usr/bin/env bash
# Main test runner for trim utilities

set -euo pipefail
shopt -s inherit_errexit nullglob
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

# Script directory
declare -- SCRIPT_DIR
SCRIPT_DIR=$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")") \
  || { >&2 echo "${0##*/}: ✗ cannot resolve test directory"; exit 1; }
TEST_DIR="$SCRIPT_DIR"
UNIT_DIR="$TEST_DIR/unit"
INTEGRATION_DIR="$TEST_DIR/integration"
SECURITY_DIR="$TEST_DIR/security"
STRESS_DIR="$TEST_DIR/stress"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test counters
declare -i total_tests=0
declare -i passed_tests=0
declare -i failed_tests=0

# Function to run a test script
run_test() {
  local -- test_script="$1"
  local -- test_name=${test_script##*/}
  test_name=${test_name%.sh}

  >&2 echo -e "${YELLOW}Running $test_name...${NC}"

  # Run the test script and capture output and exit code
  if "$test_script"; then
    ((++passed_tests))
    echo -e "${GREEN}✓ $test_name passed${NC}"
  else
    ((++failed_tests))
    >&2 echo -e "${RED}✗ $test_name failed${NC}"
  fi

  ((++total_tests))
  echo ""
}

# Run all unit tests
run_unit_tests() {
  >&2 echo -e "${YELLOW}Running unit tests...${NC}"
  local -- test
  for test in "$UNIT_DIR"/test-*.sh; do
    if [[ -x "$test" ]]; then
      run_test "$test"
    else
      >&2 echo -e "${YELLOW}Warning: $test is not executable, skipping${NC}"
    fi
  done
}

# Run all integration tests
run_integration_tests() {
  >&2 echo -e "${YELLOW}Running integration tests...${NC}"
  local -- test
  for test in "$INTEGRATION_DIR"/test-*.sh; do
    if [[ -x "$test" ]]; then
      run_test "$test"
    else
      >&2 echo -e "${YELLOW}Warning: $test is not executable, skipping${NC}"
    fi
  done
}

# Run all security tests
run_security_tests() {
  if [[ -d "$SECURITY_DIR" ]]; then
    >&2 echo -e "${YELLOW}Running security tests...${NC}"
    local -- test
    for test in "$SECURITY_DIR"/test-*.sh; do
      if [[ -x "$test" ]]; then
        run_test "$test"
      else
        >&2 echo -e "${YELLOW}Warning: $test is not executable, skipping${NC}"
      fi
    done
  fi
}

# Run all stress tests
run_stress_tests() {
  if [[ -d "$STRESS_DIR" ]]; then
    >&2 echo -e "${YELLOW}Running stress tests...${NC}"
    local -- test
    for test in "$STRESS_DIR"/test-*.sh; do
      if [[ -x "$test" ]]; then
        run_test "$test"
      else
        >&2 echo -e "${YELLOW}Warning: $test is not executable, skipping${NC}"
      fi
    done
  fi
}

# Run all tests
run_all_tests() {
  run_unit_tests
  run_integration_tests
  run_security_tests
  run_stress_tests
}

# Print test summary
print_summary() {
  echo -e "${YELLOW}Test Summary:${NC}"
  echo -e "Total tests: $total_tests"
  echo -e "${GREEN}Passed: $passed_tests${NC}"
  if ((failed_tests > 0)); then
    echo -e "${RED}Failed: $failed_tests${NC}"
    exit 1
  else
    echo -e "All tests passed!"
    exit 0
  fi
}

# Process command line arguments
if (($# == 0)); then
  run_all_tests
else
  case "$1" in
    unit)
      run_unit_tests
      ;;
    integration)
      run_integration_tests
      ;;
    security)
      run_security_tests
      ;;
    stress)
      run_stress_tests
      ;;
    *)
      >&2 echo "${0##*/}: ✗ Unknown test category ${1@Q}"
      >&2 echo "Usage: ${0##*/} [unit|integration|security|stress]"
      exit 22
      ;;
  esac
fi

# Print test summary
print_summary

#fin