#!/usr/bin/env bash
# Main test runner for bash-coding-standard test suite
# Runs all test files and reports overall results

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Script metadata
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Colors
if [[ -t 1 ]]; then
  declare -r GREEN=$'\033[0;32m' RED=$'\033[0;31m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  declare -r GREEN='' RED='' YELLOW='' CYAN='' NC=''
fi

# Test suite counters
declare -gi SUITES_RUN=0 SUITES_PASSED=0 SUITES_FAILED=0
declare -a FAILED_SUITES=()

# Run a single test suite
run_test_suite() {
  local -- test_file="$1"
  local -- test_name
  test_name=$(basename "$test_file" .sh)

  echo
  echo "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo "${CYAN}Running: $test_name${NC}"
  echo "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

  SUITES_RUN+=1

  if bash "$test_file"; then
    SUITES_PASSED+=1
    echo "${GREEN}✓ $test_name PASSED${NC}"
    return 0
  else
    SUITES_FAILED+=1
    FAILED_SUITES+=("$test_name")
    echo "${RED}✗ $test_name FAILED${NC}"
    return 1
  fi
}

# Main test runner
main() {
  echo
  echo "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
  echo "${CYAN}║     bash-coding-standard Test Suite                           ║${NC}"
  echo "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"

  # Find all test files
  local -a test_files=()
  while IFS= read -r -d '' file; do
    test_files+=("$file")
  done < <(find "$SCRIPT_DIR" -name 'test-*.sh' -type f -print0 | sort -z)

  if ((${#test_files[@]} == 0)); then
    echo "${RED}No test files found!${NC}"
    exit 1
  fi

  echo
  echo "Found ${#test_files[@]} test suite(s)"

  # Run each test suite
  local -- test_file
  local -i continue_on_failure=1

  for test_file in "${test_files[@]}"; do
    if ! run_test_suite "$test_file"; then
      # Continue running other tests even if one fails
      ((continue_on_failure)) || break
    fi
  done

  # Print overall summary
  echo
  echo "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo "${CYAN}Overall Test Summary${NC}"
  echo "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo "  Total Suites:  $SUITES_RUN"
  echo "  ${GREEN}Passed:        $SUITES_PASSED${NC}"
  echo "  ${RED}Failed:        $SUITES_FAILED${NC}"

  if ((SUITES_FAILED > 0)); then
    echo
    echo "${RED}Failed Test Suites:${NC}"
    local -- suite
    for suite in "${FAILED_SUITES[@]}"; do
      echo "  ${RED}✗${NC} $suite"
    done
    echo
    echo "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo "${RED}║  TEST SUITE FAILED                                            ║${NC}"
    echo "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    return 1
  else
    echo
    echo "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo "${GREEN}║  ALL TESTS PASSED                                             ║${NC}"
    echo "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    return 0
  fi
}

main "$@"

#fin
