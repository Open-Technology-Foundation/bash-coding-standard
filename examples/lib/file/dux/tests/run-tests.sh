#!/usr/bin/env bash
# Run all dux tests
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

#shellcheck disable=SC2155
declare -r SCRIPT_PATH=$(realpath -- "$0")
declare -r SCRIPT_DIR=${SCRIPT_PATH%/*}

declare -r DUX="$SCRIPT_DIR"/../dir-sizes

declare -gi TOTAL_PASSED=0 TOTAL_FAILED=0 TOTAL_RUN=0 TOTAL_WARNED=0
declare -a FAILED_SUITES=()

# Colors (BCS0105: check both stdout and stderr)
if [[ -t 1 && -t 2 ]]; then
  declare -r GREEN=$'\033[0;32m' RED=$'\033[0;31m' YELLOW=$'\033[0;33m' BOLD=$'\033[1m' NC=$'\033[0m'
else
  declare -r GREEN='' RED='' YELLOW='' BOLD='' NC=''
fi

echo "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${BOLD}           dux Test Suite${NC}"
echo "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Verify dux exists
if [[ ! -x $DUX ]]; then
  echo "${RED}Error: dux not found or not executable at $DUX${NC}"
  exit 1
fi

echo "Testing: $DUX"
echo "Version: $("$DUX" --version)"
echo

# Run each test file
declare -- test_file test_name output passed failed run warned
declare -i exit_code
for test_file in "$SCRIPT_DIR"/test-*.sh; do
  [[ -f $test_file ]] || continue
  [[ ${test_file##*/} == test-helpers.sh ]] && continue

  test_name=${test_file##*/}
  echo "${YELLOW}▶${NC} Running: $test_name"

  # Run test and capture output
  set +e
  output=$(bash "$test_file" "$DUX" 2>&1)
  exit_code=$?
  set -e

  echo "$output"

  # Extract counts from output (look for summary line)
  if [[ $output =~ Passed:\ ([0-9]+) ]]; then
    passed=${BASH_REMATCH[1]}
    TOTAL_PASSED=$((TOTAL_PASSED + passed))
  fi
  if [[ $output =~ Failed:\ ([0-9]+) ]]; then
    failed=${BASH_REMATCH[1]}
    TOTAL_FAILED=$((TOTAL_FAILED + failed))
  fi
  if [[ $output =~ Total:\ +([0-9]+) ]]; then
    run=${BASH_REMATCH[1]}
    TOTAL_RUN=$((TOTAL_RUN + run))
  fi
  if [[ $output =~ Warnings:\ ([0-9]+) ]]; then
    warned=${BASH_REMATCH[1]}
    TOTAL_WARNED=$((TOTAL_WARNED + warned))
  fi

  ((exit_code == 0)) || FAILED_SUITES+=("$test_name")

  echo
done

# Final summary
echo "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${BOLD}           Overall Summary${NC}"
echo "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "  Total:  $TOTAL_RUN"
echo "  ${GREEN}Passed: $TOTAL_PASSED${NC}"
echo "  ${RED}Failed: $TOTAL_FAILED${NC}"
echo "  ${YELLOW}Warnings: $TOTAL_WARNED${NC}"

if ((${#FAILED_SUITES[@]})); then
  echo
  echo 'Failed test suites:'
  declare -- suite
  for suite in "${FAILED_SUITES[@]}"; do
    echo "  ${RED}✗${NC} $suite"
  done
fi

echo "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Exit with failure if any tests failed
((TOTAL_FAILED == 0))

#fin
