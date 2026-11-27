#!/usr/bin/env bash
#shellcheck disable=SC2016  # the bash -c programs are code for the child shell; the path arrives as $1
# Unit tests for SIGPIPE handling
# Verifies trim utilities don't hang when downstream closes the pipe early.

set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/bin:/usr/bin:/bin
trap '' PIPE  # Ignore SIGPIPE in the test harness itself

declare -- TEST_DIR ROOT_DIR
TEST_DIR=$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")") \
  || { >&2 echo "${0##*/}: ✗ cannot resolve test directory"; exit 1; }
ROOT_DIR=${TEST_DIR%/*/*}  # test/<category> -> project root
[[ -f $ROOT_DIR/test/utils.sh ]] || { >&2 echo "${0##*/}: ✗ missing test/utils.sh"; exit 3; }
#shellcheck source=test/utils.sh
source -- "$ROOT_DIR"/test/utils.sh || { >&2 echo "${0##*/}: ✗ cannot source test/utils.sh"; exit 1; }
test_init || { >&2 echo "${0##*/}: ✗ test_init failed"; exit 1; }

TRIM="$ROOT_DIR/trim.bash"
LTRIM="$ROOT_DIR/ltrim.bash"
SQUEEZE="$ROOT_DIR/squeeze.bash"

>&2 echo "Testing SIGPIPE handling..."

declare -i passed=0 failed=0

# Test that trim doesn't hang when downstream closes the pipe
test_sigpipe_trim() {
  local -i exit_code=0
  local -- result
  result=$(timeout 5 bash -c 'seq 1 10000 | sed "s/.*/ & /" | "$1" | head -1' _ "$TRIM" 2>/dev/null) || exit_code=$?

  if ((exit_code != 124)) && [[ "$result" == "1" ]]; then
    echo -e "${GREEN}Test passed${NC}: trim handles SIGPIPE (head -1)"
    ((++passed))
  elif ((exit_code == 124)); then
    >&2 echo -e "${RED}Test failed${NC}: trim hung on SIGPIPE (timeout)"
    ((++failed))
  else
    # Exit 141 (SIGPIPE) is acceptable — means process was killed cleanly
    echo -e "${GREEN}Test passed${NC}: trim exits on SIGPIPE (exit: $exit_code)"
    ((++passed))
  fi
}

# Test ltrim with SIGPIPE
test_sigpipe_ltrim() {
  local -i exit_code=0
  local -- result
  result=$(timeout 5 bash -c 'seq 1 10000 | sed "s/.*/ & /" | "$1" | head -1' _ "$LTRIM" 2>/dev/null) || exit_code=$?

  if ((exit_code == 124)); then
    >&2 echo -e "${RED}Test failed${NC}: ltrim hung on SIGPIPE (timeout)"
    ((++failed))
  else
    echo -e "${GREEN}Test passed${NC}: ltrim handles SIGPIPE (exit: $exit_code)"
    ((++passed))
  fi
}

# Test squeeze with SIGPIPE
test_sigpipe_squeeze() {
  local -i exit_code=0
  local -- result
  result=$(timeout 5 bash -c 'seq 1 10000 | sed "s/.*/ &  & /" | "$1" | head -1' _ "$SQUEEZE" 2>/dev/null) || exit_code=$?

  if ((exit_code == 124)); then
    >&2 echo -e "${RED}Test failed${NC}: squeeze hung on SIGPIPE (timeout)"
    ((++failed))
  else
    echo -e "${GREEN}Test passed${NC}: squeeze handles SIGPIPE (exit: $exit_code)"
    ((++passed))
  fi
}

# Test with larger input to ensure no hang
test_sigpipe_large_no_hang() {
  local -i exit_code=0
  timeout 5 bash -c 'seq 1 50000 | sed "s/.*/ & /" | "$1" | head -1' _ "$TRIM" >/dev/null 2>&1 || exit_code=$?

  if ((exit_code == 124)); then
    >&2 echo -e "${RED}Test failed${NC}: trim hung on large SIGPIPE input (timeout)"
    ((++failed))
  else
    # 0 = clean exit, 141 = SIGPIPE (128 + 13) — both acceptable
    echo -e "${GREEN}Test passed${NC}: trim does not hang on SIGPIPE (exit: $exit_code)"
    ((++passed))
  fi
}

# Run all tests
test_sigpipe_trim
test_sigpipe_ltrim
test_sigpipe_squeeze
test_sigpipe_large_no_hang

echo
echo "=== Summary: $passed passed, $failed failed ==="

if ((failed == 0)); then
  echo "All SIGPIPE tests passed!"
  exit 0
else
  >&2 echo "SIGPIPE tests FAILED"
  exit 1
fi

#fin
