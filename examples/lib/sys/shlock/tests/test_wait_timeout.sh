#!/bin/bash
#shellcheck disable=SC2329  # cleanup() runs via the EXIT trap
#shellcheck disable=SC2016  # bash -c bodies are single-quoted on purpose: values arrive as "$1"
#shellcheck disable=SC2324  # var+=1 is correct on declare -i globals per BCS0505
# Wait and timeout feature tests for shlock

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
  rm -f /run/lock/test_wait_*.lock /run/lock/test_wait_*.pid 2>/dev/null || true
  [[ -z $TMP_DIR ]] || rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT
TMP_DIR=$(mktemp -d) || { echo "✗ FATAL: cannot create temp dir" >&2; exit 1; }

# Test helpers
assert_exit_code() {
  local -- msg=$1
  local -i expected=$2
  shift 2
  TEST_COUNT+=1

  local -i actual=0
  "$@" &>/dev/null || actual=$?

  if ((actual == expected)); then
    TEST_PASSED+=1
    echo "  ✓ $msg (exit code: $actual)"
    return 0
  else
    echo "  ✗ $msg (expected exit code $expected, got $actual)"
    return 1
  fi
}

# assert_duration MSG EXPECTED_RC MIN_SECONDS MAX_SECONDS COMMAND...
# The exit code is checked too: a command that fails at once would otherwise
# satisfy any window that starts at 0 seconds.
assert_duration() {
  local -- msg=$1
  local -i expected=$2 min_seconds=$3 max_seconds=$4
  shift 4

  TEST_COUNT+=1

  local -i start_time end_time duration actual=0
  start_time=$EPOCHSECONDS
  "$@" &>/dev/null || actual=$?
  end_time=$EPOCHSECONDS
  duration=$((end_time - start_time))

  if ((actual == expected && duration >= min_seconds && duration <= max_seconds)); then
    TEST_PASSED+=1
    echo "  ✓ $msg (took ${duration}s, expected ${min_seconds}-${max_seconds}s)"
    return 0
  else
    echo "  ✗ $msg (took ${duration}s, exit $actual; expected ${min_seconds}-${max_seconds}s, exit $expected)"
    return 1
  fi
}

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

# Set a file's mtime N seconds in the past. Abort when that is impossible:
# stale-lock assertions against a fresh mtime would pass falsely.
backdate() {
  local -- file=$1 stamp
  local -i age=$2
  printf -v stamp '%(%Y%m%d%H%M.%S)T' "$((EPOCHSECONDS - age))"
  touch -t "$stamp" -- "$file" 2>/dev/null \
    || perl -e 'utime(time - $ARGV[0], time - $ARGV[0], $ARGV[1]) or exit 1' -- "$age" "$file" 2>/dev/null \
    || { echo "✗ FATAL: cannot backdate ${file@Q} (need coreutils touch or perl)" >&2; exit 1; }
}

# Tests
echo "Test: Basic --wait functionality"
# Start a process holding lock for 2 seconds
"$LOCK_SCRIPT" test_wait_1 -- sleep 2 &
declare -i HOLDER_PID=$!
sleep 0.2

# Try to acquire with --wait (should succeed after ~2 seconds)
declare -i START_TIME END_TIME DURATION
START_TIME=$EPOCHSECONDS
"$LOCK_SCRIPT" --wait test_wait_1 -- echo "acquired" >/dev/null &
declare -i WAITER_PID=$!

# Holder and waiter ran at the same time: reap both before any verdict
reap_all "$HOLDER_PID" "$WAITER_PID"
END_TIME=$EPOCHSECONDS
DURATION=$((END_TIME - START_TIME))

TEST_COUNT+=1
if ((DURATION >= 1 && DURATION <= 4)); then
  TEST_PASSED+=1
  echo "  ✓ --wait blocks and acquires lock after holder releases (${DURATION}s)"
else
  echo "  ✗ Expected duration 1-4s, got ${DURATION}s"
fi

echo
echo "Test: --timeout with available lock"
assert_exit_code "--timeout succeeds when lock is available" 0 \
  "$LOCK_SCRIPT" --wait --timeout 5 test_wait_2 -- echo "test"

echo
echo "Test: --timeout expires when waiting"
# Start a process holding lock for 10 seconds
"$LOCK_SCRIPT" test_wait_3 -- sleep 10 &
HOLDER_PID=$!
sleep 0.2

# Try to acquire with 2 second timeout (should fail)
assert_duration "--timeout 2 fails after ~2 seconds" 24 1 4 \
  "$LOCK_SCRIPT" --wait --timeout 2 test_wait_3 -- echo "should timeout"

assert_exit_code "--timeout returns exit code 24 on timeout" 24 \
  "$LOCK_SCRIPT" --wait --timeout 1 test_wait_3 -- echo "should timeout"

kill -TERM "$HOLDER_PID" 2>/dev/null || true
reap "$HOLDER_PID" 0 143

echo
echo "Test: --timeout works independently"
assert_exit_code "--timeout without --wait succeeds" 0 \
  "$LOCK_SCRIPT" --timeout 10 test_wait_4 -- echo "test"

echo
echo "Test: --timeout with invalid value"
assert_exit_code "Non-numeric timeout rejected" 22 \
  "$LOCK_SCRIPT" --wait --timeout abc test_wait_5 -- echo "test"

assert_exit_code "Empty timeout rejected" 22 \
  "$LOCK_SCRIPT" --wait --timeout "" test_wait_6 -- echo "test"

echo
echo "Test: --wait without timeout (indefinite wait)"
# Start holder for 1 second
"$LOCK_SCRIPT" test_wait_7 -- sleep 1 &
HOLDER_PID=$!
sleep 0.2

# Wait indefinitely (should succeed within 2 seconds)
assert_duration "--wait without timeout waits indefinitely" 0 0 3 \
  "$LOCK_SCRIPT" --wait test_wait_7 -- echo "acquired"

reap "$HOLDER_PID" 0

echo
echo "Test: Multiple waiters in sequence"
declare -- COUNTER_FILE="$TMP_DIR"/counter
echo "0" > "$COUNTER_FILE" || setup_failed

# Start first holder
"$LOCK_SCRIPT" test_wait_8 -- bash -c 'echo 1 > "$1"; sleep 1' _ "$COUNTER_FILE" &
declare -i PID1=$!
sleep 0.2

# Start second waiter
"$LOCK_SCRIPT" --wait test_wait_8 -- bash -c 'echo 2 > "$1"; sleep 0.5' _ "$COUNTER_FILE" &
declare -i PID2=$!
sleep 0.1

# Start third waiter
"$LOCK_SCRIPT" --wait test_wait_8 -- bash -c 'echo 3 > "$1"' _ "$COUNTER_FILE" &
declare -i PID3=$!

# Wait for all to complete
reap_all "$PID1" "$PID2" "$PID3"

declare -- FINAL_VALUE=''
read -r FINAL_VALUE <"$COUNTER_FILE" || setup_failed
TEST_COUNT+=1
if [[ "$FINAL_VALUE" == "3" ]]; then
  TEST_PASSED+=1
  echo "  ✓ Multiple waiters execute in sequence"
else
  echo "  ✗ Expected final value 3, got $FINAL_VALUE"
fi
rm -f -- "$COUNTER_FILE"

echo
echo "Test: --wait with stale lock"
# Create a stale lock
touch /run/lock/test_wait_9.lock || setup_failed
echo "99999" > /run/lock/test_wait_9.pid || setup_failed
backdate /run/lock/test_wait_9.lock 90000

# Should acquire immediately after removing stale lock
assert_duration "--wait with stale lock doesn't actually wait" 0 0 2 \
  "$LOCK_SCRIPT" --wait test_wait_9 -- echo "acquired"

echo
echo "Test: Zero timeout precise semantics"
# --timeout 0 with lock free: succeeds immediately (flock -w 0 tries once)
assert_exit_code "--timeout 0 with free lock succeeds (exit 0)" 0 \
  "$LOCK_SCRIPT" --timeout 0 test_wait_10a -- echo "test"

# --timeout 0 with lock held: fails with timeout exit code 24 (not exit 1)
"$LOCK_SCRIPT" test_wait_10 -- sleep 2 &
HOLDER_PID=$!
sleep 0.2

assert_exit_code "--timeout 0 with held lock returns exit 24 (not 1)" 24 \
  "$LOCK_SCRIPT" --timeout 0 test_wait_10 -- echo "test"

assert_duration "--timeout 0 returns quickly even when held" 24 0 2 \
  "$LOCK_SCRIPT" --wait --timeout 0 test_wait_10 -- echo "test"

kill -TERM "$HOLDER_PID" 2>/dev/null || true
reap "$HOLDER_PID" 0 143

echo
echo "Test: Large timeout value"
assert_exit_code "Large timeout (999999) accepted" 0 \
  "$LOCK_SCRIPT" --wait --timeout 999999 test_wait_11 -- echo "test"

echo
echo "Test: --wait mode error messages"
"$LOCK_SCRIPT" test_wait_12 -- sleep 2 &
HOLDER_PID=$!
sleep 0.2

TEST_COUNT+=1
declare -- OUTPUT
OUTPUT=$("$LOCK_SCRIPT" --wait --timeout 1 test_wait_12 -- echo "test" 2>&1) ||:

if [[ $OUTPUT =~ Timeout ]]; then
  TEST_PASSED+=1
  echo "  ✓ Timeout error message is informative"
else
  echo "  ✗ Expected timeout message in: $OUTPUT"
fi

kill -TERM "$HOLDER_PID" 2>/dev/null || true
reap "$HOLDER_PID" 0 143

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
