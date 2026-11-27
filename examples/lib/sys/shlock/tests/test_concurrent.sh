#!/bin/bash
#shellcheck disable=SC2329  # cleanup() runs via the EXIT trap
#shellcheck disable=SC2016  # bash -c bodies are single-quoted on purpose: values arrive as "$1"
# Concurrent lock acquisition tests for shlock

set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

# Setup
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly -- SCRIPT_DIR
readonly -- LOCK_SCRIPT="$SCRIPT_DIR/../shlock"
declare -i TEST_COUNT=0
declare -i TEST_PASSED=0
declare -- TMP_DIR=''

# Cleanup function
cleanup() {
  # Kill any background processes
  jobs -p | xargs -r kill 2>/dev/null || true
  # Clean up any locks created during tests
  rm -f /run/lock/test_concurrent_*.lock /run/lock/test_concurrent_*.pid 2>/dev/null || true
  [[ -z $TMP_DIR ]] || rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT
TMP_DIR=$(mktemp -d) || { echo "✗ FATAL: cannot create temp dir" >&2; exit 1; }

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

# Reap jobs that ran at the same time. Each must exit 0; all are reaped before
# the suite aborts, so one failure cannot hide another's status (BCS1103).
reap_all() {
  local -i pid rc failed=0
  for pid in "$@"; do
    rc=0
    wait "$pid" 2>/dev/null || rc=$?
    ((rc)) || continue
    >&2 echo "  ✗ background job $pid exited $rc (expected 0)"
    failed+=1
  done
  ((failed == 0)) || exit 1
}

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

# Tests
echo "Test: Two processes cannot hold same lock simultaneously"
# Start first process with lock
"$LOCK_SCRIPT" test_concurrent_1 -- sleep 0.5 &
declare -i FIRST_PID=$!
sleep 0.1  # Give first process time to acquire lock

# Try to acquire same lock
TEST_COUNT+=1
declare -i EXIT_CODE=0
"$LOCK_SCRIPT" test_concurrent_1 -- echo "should fail" 2>/dev/null || EXIT_CODE=$?

if ((EXIT_CODE == 1)); then
  TEST_PASSED+=1
  echo "  ✓ Second process cannot acquire held lock"
else
  echo "  ✗ Second process should fail with exit code 1, got $EXIT_CODE"
fi

reap "$FIRST_PID" 0

echo
echo "Test: Lock is released after first process completes"
# First process acquires and releases
"$LOCK_SCRIPT" test_concurrent_2 -- echo "first" >/dev/null || setup_failed
# Second process should now succeed
assert_success "Lock can be acquired after first process releases" \
  "$LOCK_SCRIPT" test_concurrent_2 -- echo "second"

echo
echo "Test: Multiple sequential lock acquisitions"
declare -i i
for i in {1..5}; do
  TEST_COUNT+=1
  if "$LOCK_SCRIPT" test_concurrent_3 -- echo "iteration $i" >/dev/null; then
    TEST_PASSED+=1
  else
    echo "  ✗ Failed on iteration $i"
  fi
done
echo "  ✓ Five sequential lock acquisitions succeeded"

echo
echo "Test: Second process fails when lock is held (non-blocking)"
# Create a counter file
declare -- COUNTER_FILE="$TMP_DIR"/counter
echo "0" > "$COUNTER_FILE" || setup_failed

# Start first process holding lock for 1 second
"$LOCK_SCRIPT" test_concurrent_4 -- bash -c 'echo 1 > "$1"; sleep 1' _ "$COUNTER_FILE" &
FIRST_PID=$!

sleep 0.2  # Let first process acquire lock

# Try to acquire same lock (should fail immediately)
TEST_COUNT+=1
declare -i SECOND_EXIT=0
"$LOCK_SCRIPT" test_concurrent_4 -- bash -c 'echo 2 > "$1"' _ "$COUNTER_FILE" 2>/dev/null || SECOND_EXIT=$?

# Wait for first to complete
reap "$FIRST_PID" 0

# Check that second process failed to acquire lock
declare -- FINAL_VALUE=''
read -r FINAL_VALUE <"$COUNTER_FILE" || setup_failed
if ((SECOND_EXIT == 1)) && [[ "$FINAL_VALUE" == "1" ]]; then
  TEST_PASSED+=1
  echo "  ✓ Second process failed immediately when lock was held"
else
  echo "  ✗ Expected second process to fail with exit 1, got $SECOND_EXIT, counter=$FINAL_VALUE"
fi
rm -f -- "$COUNTER_FILE"

echo
echo "Test: Error message includes PID when lock is held"
"$LOCK_SCRIPT" test_concurrent_5 -- sleep 0.5 &
declare -i HOLDER_PID=$!
sleep 0.1

TEST_COUNT+=1
declare -- ERROR_OUTPUT
ERROR_OUTPUT=$("$LOCK_SCRIPT" test_concurrent_5 -- echo "test" 2>&1) ||:

if [[ "$ERROR_OUTPUT" =~ PID ]]; then
  TEST_PASSED+=1
  echo "  ✓ Error message includes PID information"
else
  echo "  ✗ Error message should mention PID: $ERROR_OUTPUT"
fi

reap "$HOLDER_PID" 0

echo
echo "Test: Rapid lock acquisition attempts"
# Test that lock mechanism is robust under rapid requests
declare -i SUCCESS_COUNT=0
for i in {1..10}; do
  if "$LOCK_SCRIPT" test_concurrent_6 -- echo "rapid $i" &>/dev/null; then
    SUCCESS_COUNT+=1
  fi
done

TEST_COUNT+=1
if ((SUCCESS_COUNT == 10)); then
  TEST_PASSED+=1
  echo "  ✓ All 10 rapid sequential acquisitions succeeded"
else
  echo "  ✗ Expected 10 successes, got $SUCCESS_COUNT"
fi

echo
echo "Test: Different locks do not interfere"
# Start processes with different lock names
"$LOCK_SCRIPT" test_concurrent_7a -- sleep 0.3 &
declare -i PID_A=$!
"$LOCK_SCRIPT" test_concurrent_7b -- sleep 0.3 &
declare -i PID_B=$!

sleep 0.1

# Both should be holding their respective locks
TEST_COUNT+=1
if [[ -f /run/lock/test_concurrent_7a.lock ]] && [[ -f /run/lock/test_concurrent_7b.lock ]]; then
  TEST_PASSED+=1
  echo "  ✓ Different locks can be held simultaneously"
else
  echo "  ✗ Both lock files should exist simultaneously"
fi

reap_all "$PID_A" "$PID_B"

echo
echo "Test: Lock survives during long-running command"
declare -- OUTPUT_FILE="$TMP_DIR"/output
"$LOCK_SCRIPT" test_concurrent_8 -- bash -c 'for i in {1..5}; do sleep 0.1; echo $i; done' > "$OUTPUT_FILE" &
declare -i LONG_PID=$!

# Verify lock exists throughout execution
sleep 0.2
TEST_COUNT+=1
if [[ -f /run/lock/test_concurrent_8.lock ]]; then
  TEST_PASSED+=1
  echo "  ✓ Lock persists during command execution"
else
  echo "  ✗ Lock file should exist during execution"
fi

reap "$LONG_PID" 0

# Verify command completed successfully
TEST_COUNT+=1
if (( $(wc -l < "$OUTPUT_FILE") == 5 )); then
  TEST_PASSED+=1
  echo "  ✓ Long-running command completed successfully"
else
  echo "  ✗ Command output incomplete"
fi
rm -f -- "$OUTPUT_FILE"

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
