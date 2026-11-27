#!/usr/bin/env bash
# Unit tests for concurrent usage of trimv

set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

declare -- TEST_DIR ROOT_DIR
TEST_DIR=$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")") \
  || { >&2 echo "${0##*/}: ✗ cannot resolve test directory"; exit 1; }
ROOT_DIR=${TEST_DIR%/*/*}  # test/<category> -> project root
[[ -f $ROOT_DIR/test/utils.sh ]] || { >&2 echo "${0##*/}: ✗ missing test/utils.sh"; exit 3; }
#shellcheck source=test/utils.sh
source -- "$ROOT_DIR"/test/utils.sh || { >&2 echo "${0##*/}: ✗ cannot source test/utils.sh"; exit 1; }
test_init || { >&2 echo "${0##*/}: ✗ test_init failed"; exit 1; }

# Source trimv for function testing
[[ -f $ROOT_DIR/trimv.bash ]] || { >&2 echo "${0##*/}: ✗ missing trimv.bash"; exit 3; }
#shellcheck source=trimv.bash
source -- "$ROOT_DIR"/trimv.bash || { >&2 echo "${0##*/}: ✗ cannot source trimv.bash"; exit 1; }

>&2 echo "Testing concurrent trimv usage..."

declare -i passed=0 failed=0

# Test parallel trimv invocations with -n flag
test_parallel_trimv() {
  #shellcheck disable=SC2034  # each is assigned by name through trimv -n in a background job
  local -- result1='' result2='' result3=''

  # Run three trimv calls that assign to different variables
  trimv -n result1 "  first value  " &
  local -i pid1=$!
  trimv -n result2 "  second value  " &
  local -i pid2=$!
  trimv -n result3 "  third value  " &
  local -i pid3=$!

  local -i errors=0
  wait "$pid1" || errors+=1
  wait "$pid2" || errors+=1
  wait "$pid3" || errors+=1
  ((errors == 0)) || fail "$errors of 3 parallel trimv -n jobs exited non-zero"

  # In background subshells, -n assignments don't propagate back.
  # This test verifies no crashes or hangs occur during concurrent execution.
  echo -e "${GREEN}Test passed${NC}: Parallel trimv invocations complete without errors"
  ((++passed))
}

# Test concurrent stdin processing (no -n flag, output mode)
test_concurrent_stdout() {
  local -- tmp1 tmp2 tmp3
  tmp1=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'
  tmp2=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'
  tmp3=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'

  echo "  concurrent one  " | trimv > "$tmp1" &
  local -i pid1=$!
  echo "  concurrent two  " | trimv > "$tmp2" &
  local -i pid2=$!
  echo "  concurrent three  " | trimv > "$tmp3" &
  local -i pid3=$!

  local -i errors=0
  wait "$pid1" || errors+=1
  wait "$pid2" || errors+=1
  wait "$pid3" || errors+=1
  ((errors == 0)) || fail "$errors of 3 concurrent stdout trimv jobs exited non-zero"

  local -- r1 r2 r3
  r1=$(<"$tmp1") || fail "cannot read ${tmp1@Q}"
  r2=$(<"$tmp2") || fail "cannot read ${tmp2@Q}"
  r3=$(<"$tmp3") || fail "cannot read ${tmp3@Q}"

  rm -f -- "$tmp1" "$tmp2" "$tmp3"

  if [[ "$r1" == "concurrent one" && "$r2" == "concurrent two" && "$r3" == "concurrent three" ]]; then
    echo -e "${GREEN}Test passed${NC}: Concurrent stdout trimv produces correct results"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: Concurrent stdout (got: ${r1@Q}, ${r2@Q}, ${r3@Q})"
    ((++failed))
  fi
}

# Test rapid sequential trimv calls (race condition check)
test_rapid_sequential() {
  local -i i errors=0
  local -- var

  for ((i = 0; i < 100; i++)); do
    var=''
    trimv -n var "  iteration $i  " || fail "trimv -n exited non-zero on iteration $i"
    if [[ "$var" != "iteration $i" ]]; then
      ((++errors))
    fi
  done

  if ((errors == 0)); then
    echo -e "${GREEN}Test passed${NC}: 100 rapid sequential trimv calls correct"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: $errors errors in 100 sequential calls"
    ((++failed))
  fi
}

# Test concurrent stdin processing with larger data
test_concurrent_large_stdin() {
  local -- tmp1 tmp2
  tmp1=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'
  tmp2=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'

  # Generate 500 lines for each concurrent process
  seq 1 500 | sed 's/.*/ line & /' | trimv > "$tmp1" &
  local -i pid1=$!
  seq 501 1000 | sed 's/.*/ line & /' | trimv > "$tmp2" &
  local -i pid2=$!

  local -i errors=0
  wait "$pid1" || errors+=1
  wait "$pid2" || errors+=1
  ((errors == 0)) || fail "$errors of 2 concurrent large-stdin trimv jobs exited non-zero"

  local -- count1 count2
  count1=$(wc -l < "$tmp1") || fail "cannot count lines in ${tmp1@Q}"
  count2=$(wc -l < "$tmp2") || fail "cannot count lines in ${tmp2@Q}"
  [[ $count1 =~ ^[0-9]+$ && $count2 =~ ^[0-9]+$ ]] || fail "wc -l gave non-integer ${count1@Q} ${count2@Q}"

  rm -f -- "$tmp1" "$tmp2"

  if ((count1 == 500 && count2 == 500)); then
    echo -e "${GREEN}Test passed${NC}: Concurrent large stdin (500+500 lines)"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: Concurrent large stdin (got: $count1, $count2 lines)"
    ((++failed))
  fi
}

# Run all tests
test_parallel_trimv
test_concurrent_stdout
test_rapid_sequential
test_concurrent_large_stdin

echo
echo "=== Summary: $passed passed, $failed failed ==="

if ((failed == 0)); then
  echo "All concurrent tests passed!"
  exit 0
else
  >&2 echo "Concurrent tests FAILED"
  exit 1
fi

#fin
