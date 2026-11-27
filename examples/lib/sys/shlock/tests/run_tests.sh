#!/bin/bash
# Test runner for shlock test suite
#
# Runs all test files and reports results

set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

# Directories
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly -- SCRIPT_DIR
readonly -- LOCK_SCRIPT="$SCRIPT_DIR/../shlock"

# Test state
declare -i TESTS_RUN=0
declare -i TESTS_PASSED=0
declare -i TESTS_FAILED=0
declare -a FAILED_TESTS=()

# Colors for output
readonly -- COLOR_GREEN='\033[0;32m'
readonly -- COLOR_RED='\033[0;31m'
readonly -- COLOR_YELLOW='\033[1;33m'
readonly -- COLOR_RESET='\033[0m'

# Messaging functions
info() { >&2 echo -e "${COLOR_GREEN}◉${COLOR_RESET} $*"; }
error() { >&2 echo -e "${COLOR_RED}✗${COLOR_RESET} $*"; }
warn() { >&2 echo -e "${COLOR_YELLOW}▲${COLOR_RESET} $*"; }
success() { >&2 echo -e "${COLOR_GREEN}✓${COLOR_RESET} $*"; }

# Verify shlock exists
if [[ ! -x "$LOCK_SCRIPT" ]]; then
  error "shlock not found or not executable at: $LOCK_SCRIPT"
  exit 1
fi

# Run a single test file
run_test_file() {
  local -- test_file=$1
  local -- test_name=${test_file##*/}
  test_name=${test_name%.sh}

  info "Running: $test_name"

  if bash -- "$test_file"; then
    TESTS_PASSED+=1
    success "$test_name passed"
  else
    TESTS_FAILED+=1
    FAILED_TESTS+=("$test_name")
    error "$test_name failed"
  fi

  TESTS_RUN+=1
}

# Main
main() {
  info "Starting lock.sh test suite"
  info "Lock script: $LOCK_SCRIPT"
  >&2 echo

  # Find and run all test files
  local -a test_files=()
  local -- file test_file test
  while IFS= read -r -d '' file; do
    test_files+=("$file")
  done < <(find "$SCRIPT_DIR" -maxdepth 1 -name 'test_*.sh' -type f -print0 | sort -z)

  if ((${#test_files[@]} == 0)); then
    warn "No test files found"
    exit 1
  fi

  # Run each test file
  for test_file in "${test_files[@]}"; do
    run_test_file "$test_file"
    >&2 echo
  done

  # Print summary (stderr, like every runner message: stdout carries only the
  # suites' own output)
  >&2 echo "================================================"
  >&2 echo "Test Summary"
  >&2 echo "================================================"
  >&2 echo "Total tests:  $TESTS_RUN"
  success "Passed:       $TESTS_PASSED"

  if ((TESTS_FAILED > 0)); then
    error "Failed:       $TESTS_FAILED"
    >&2 echo
    error "Failed tests:"
    for test in "${FAILED_TESTS[@]}"; do
      >&2 echo "  - $test"
    done
    exit 1
  fi

  >&2 echo
  success "All tests passed!"
  exit 0
}

main "$@"

#fin
