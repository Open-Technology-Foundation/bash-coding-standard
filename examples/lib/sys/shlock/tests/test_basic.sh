#!/bin/bash
#shellcheck disable=SC2329  # cleanup() runs via the EXIT trap, helpers via "$@"
# Basic functionality tests for shlock

set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

# Setup
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly -- SCRIPT_DIR
readonly -- LOCK_SCRIPT="$SCRIPT_DIR/../shlock"
declare -i TEST_COUNT=0
declare -i TEST_PASSED=0

# Cleanup function
cleanup() {
  # Clean up any locks created during tests
  rm -f /run/lock/test_*.lock /run/lock/test_*.pid 2>/dev/null || true
}
trap cleanup EXIT

# Test helpers
assert_success() {
  local -- msg=$1
  shift
  TEST_COUNT+=1
  if "$@"; then
    TEST_PASSED+=1
    echo "  ✓ $msg"
    return 0
  else
    echo "  ✗ $msg (expected success, got failure)"
    return 1
  fi
}

assert_failure() {
  local -- msg=$1
  shift
  TEST_COUNT+=1
  if "$@"; then
    echo "  ✗ $msg (expected failure, got success)"
    return 1
  else
    TEST_PASSED+=1
    echo "  ✓ $msg"
    return 0
  fi
}

assert_exit_code() {
  local -- msg=$1
  local -i expected=$2
  shift 2
  TEST_COUNT+=1

  local -i actual=0
  "$@" || actual=$?

  if ((actual == expected)); then
    TEST_PASSED+=1
    echo "  ✓ $msg (exit code: $actual)"
    return 0
  else
    echo "  ✗ $msg (expected exit code $expected, got $actual)"
    return 1
  fi
}

file_exists() { [[ -f $1 ]]; }

# Reap a background job; abort unless its status is one of the allowed codes
# (143 = killed by the test's own TERM). Never discards a wait status.
reap() {
  local -i pid=$1 rc=0
  shift
  wait "$pid" 2>/dev/null || rc=$?
  [[ " $* " == *" $rc "* ]] && return 0
  >&2 echo "  ✗ background job $pid exited $rc (allowed: $*)"
  exit 1
}

# Abort when fixture setup fails: the assertions that follow would test the wrong state.
setup_failed() { >&2 echo "  ✗ FATAL: fixture setup failed (line ${BASH_LINENO[0]})"; exit 1; }

# Tests
echo "Test: Basic command execution"
assert_success "Execute simple command with lock" \
  "$LOCK_SCRIPT" test_basic_1 -- echo "test"

echo
echo "Test: Command with arguments"
assert_success "Execute command with multiple arguments" \
  "$LOCK_SCRIPT" test_basic_2 -- bash -c 'echo "arg1 arg2"'

echo
echo "Test: Lock file creation"
"$LOCK_SCRIPT" test_basic_3 -- sleep 0.1 &
declare -i LOCK_PID=$!
sleep 0.05
assert_success "Lock file exists while command runs" \
  file_exists /run/lock/test_basic_3.lock
assert_success "PID file exists while command runs" \
  file_exists /run/lock/test_basic_3.pid
reap "$LOCK_PID" 0

echo
echo "Test: Lock file cleanup after command completes"
"$LOCK_SCRIPT" test_basic_4 -- echo "test" >/dev/null || setup_failed
assert_success "Lock file persists after command completes (flock behavior)" \
  file_exists /run/lock/test_basic_4.lock
assert_failure "PID file removed after command completes" \
  file_exists /run/lock/test_basic_4.pid

echo
echo "Test: Exit code propagation"
assert_exit_code "Exit code 0 from successful command" 0 \
  "$LOCK_SCRIPT" test_basic_5 -- true
assert_exit_code "Wrapped 'false' propagates exit code 1" 1 \
  "$LOCK_SCRIPT" test_basic_6 -- false
assert_exit_code "Wrapped command exit 42 propagates unchanged" 42 \
  "$LOCK_SCRIPT" test_basic_6b -- bash -c 'exit 42'

echo
echo "Test: Help option"
assert_exit_code "Help with -h" 0 \
  "$LOCK_SCRIPT" -h
assert_exit_code "Help with --help" 0 \
  "$LOCK_SCRIPT" --help

echo
echo "Test: Invalid arguments"
assert_exit_code "Auto-generated lockname from command" 0 \
  "$LOCK_SCRIPT" -- echo "test"
assert_exit_code "Missing command" 2 \
  "$LOCK_SCRIPT" test_basic_7 --
assert_exit_code "Missing -- separator" 2 \
  "$LOCK_SCRIPT" test_basic_8 echo "test"
assert_exit_code "Unknown option" 22 \
  "$LOCK_SCRIPT" --invalid-option test_basic_9 -- echo "test"

echo
echo "Test: Short option bundling (BCS0805)"
assert_exit_code "Bundled -wt (wait + timeout)" 0 \
  "$LOCK_SCRIPT" -wt 5 test_basic_bundle_1 -- echo "test"

assert_exit_code "Bundled -ws (wait + steal)" 0 \
  "$LOCK_SCRIPT" -ws test_basic_bundle_2 -- echo "test"

assert_exit_code "Bundled -sm (steal + max-age)" 0 \
  "$LOCK_SCRIPT" -sm 12 test_basic_bundle_3 -- echo "test"

assert_exit_code "Triple bundle -swt (steal + wait + timeout)" 0 \
  "$LOCK_SCRIPT" -swt 5 test_basic_bundle_4 -- echo "test"

assert_exit_code "Invalid bundle -wz (unknown -z)" 22 \
  "$LOCK_SCRIPT" -wz test_basic_bundle_5 -- echo "test"

echo
echo "Test: PID file contents"
"$LOCK_SCRIPT" test_basic_10 -- sleep 1 &
LOCK_PID=$!
sleep 0.3
# One read and no separate -f test: the file vanishes when the holder exits
TEST_COUNT+=1
declare -- PID_CONTENT=''
if read -r PID_CONTENT 2>/dev/null </run/lock/test_basic_10.pid && [[ $PID_CONTENT =~ ^[0-9]+$ ]]; then
  TEST_PASSED+=1
  echo "  ✓ PID file contains valid PID"
else
  echo "  ✗ PID file missing or invalid: ${PID_CONTENT@Q}"
fi
reap "$LOCK_PID" 0

# Summary
echo
echo "================================================"
echo "Passed: $TEST_PASSED / $TEST_COUNT tests"
echo "================================================"

if ((TEST_PASSED == TEST_COUNT)); then
  exit 0
else
  exit 1
fi

#fin
