#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# run-all-tests.sh - Master test runner for BCS test suite
set -euo pipefail
shopt -s inherit_errexit nullglob

#shellcheck disable=SC2155  # accepted: declare masks realpath's exit status (BCS0103)
declare -r SCRIPT_PATH=$(realpath -e -- "$0")
declare -r TEST_DIR=${SCRIPT_PATH%/*}

# Colors
if [[ -t 1 && -t 2 ]]; then
  declare -r RED=$'\033[0;31m' GREEN=$'\033[0;32m' BOLD=$'\033[1m' NC=$'\033[0m'
else
  declare -r RED='' GREEN='' BOLD='' NC=''
fi

declare -i total_suites=0 passed_suites=0 failed_suites=0

echo "${BOLD}BCS Test Suite${NC}"
echo '=============='
echo

# Run each test file
declare -- test_file basename_f test_name
for test_file in "$TEST_DIR"/test-*.sh; do
  basename_f=${test_file##*/}
  [[ "$basename_f" == test-helpers.sh ]] && continue

  test_name=${basename_f%.sh}
  echo "${BOLD}Running: $test_name${NC}"
  total_suites+=1

  if bash "$test_file"; then
    passed_suites+=1
  else
    failed_suites+=1
    echo "  ${RED}✗ Suite failed${NC}"
  fi
  echo
done

# Summary
echo '=============='
printf '%sTotal:%s %d suites, %s%d passed%s, ' \
  "$BOLD" "$NC" "$total_suites" "$GREEN" "$passed_suites" "$NC"
if ((failed_suites)); then
  printf '%s%d failed%s\n' "$RED" "$failed_suites" "$NC"
else
  printf '0 failed\n'
fi

((failed_suites == 0))
#fin
