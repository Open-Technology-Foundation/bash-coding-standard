#!/bin/bash
#shellcheck disable=SC2329  # cleanup() runs via the EXIT trap
#shellcheck disable=SC2324  # var+=1 is correct on declare -i globals per BCS0505
#shellcheck disable=SC2016  # bash -c bodies are single-quoted on purpose: values arrive as "$1"
# Lock stealing tests for shlock

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
  # Kill any background processes
  jobs -p | xargs -r kill 2>/dev/null || true
  # Clean up any locks created during tests
  rm -f /run/lock/test_steal_*.lock /run/lock/test_steal_*.pid 2>/dev/null || true
  rm -f /run/lock/echo.lock /run/lock/echo.pid 2>/dev/null || true
}
trap cleanup EXIT

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

assert_contains() {
  local -- msg=$1
  local -- pattern=$2
  shift 2
  TEST_COUNT+=1

  local -- output
  output=$("$@" 2>&1) ||:

  if [[ "$output" =~ $pattern ]]; then
    TEST_PASSED+=1
    echo "  ✓ $msg"
    return 0
  else
    echo "  ✗ $msg (pattern '$pattern' not found in output)"
    echo "     Output: $output"
    return 1
  fi
}

# Helper: create a fake lock with a specified PID
create_fake_lock() {
  local -- lockname=$1
  local -i pid=$2
  touch "/run/lock/${lockname}.lock" || setup_failed
  echo "$pid" > "/run/lock/${lockname}.pid" || setup_failed
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
echo "Test: Steal with no existing lock"
assert_exit_code "Steal with no lock proceeds normally" 0 \
  "$LOCK_SCRIPT" --steal test_steal_1 -- echo "test"

echo
echo "Test: Steal auto-removes dead process lock"
create_fake_lock test_steal_2 99999
assert_contains "Dead process lock removed with 'abandoned' message" "abandoned" \
  "$LOCK_SCRIPT" --steal test_steal_2 -- echo "test"

echo
echo "Test: Steal dead lock executes command"
create_fake_lock test_steal_3 99999
declare -- OUTPUT
declare -i EXIT_CODE=0
TEST_COUNT+=1
OUTPUT=$("$LOCK_SCRIPT" --steal test_steal_3 -- echo "stolen-ok" 2>&1) || EXIT_CODE=$?
if ((EXIT_CODE == 0)) && [[ "$OUTPUT" =~ stolen-ok ]]; then
  TEST_PASSED+=1
  echo "  ✓ Steal dead lock executes command and outputs result"
else
  echo "  ✗ Steal dead lock executes command (exit=$EXIT_CODE, output=$OUTPUT)"
fi

echo
echo "Test: Steal running process - user declines"
"$LOCK_SCRIPT" test_steal_4 -- sleep 5 &
declare -i HOLDER_PID=$!
sleep 0.3
assert_exit_code "Steal declined returns exit code 1" 1 \
  bash -c 'echo "n" | "$1" --steal test_steal_4 -- echo "test"' _ "$LOCK_SCRIPT"
kill "$HOLDER_PID" 2>/dev/null || true
reap "$HOLDER_PID" 0 143

echo
echo "Test: Steal running process - user confirms"
"$LOCK_SCRIPT" test_steal_5 -- sleep 5 &
declare -i HOLDER_PID=$!
sleep 0.3
assert_exit_code "Steal confirmed returns exit code 0" 0 \
  bash -c 'echo "y" | "$1" --steal test_steal_5 -- echo "test"' _ "$LOCK_SCRIPT"
kill "$HOLDER_PID" 2>/dev/null || true
reap "$HOLDER_PID" 0 143

echo
echo "Test: After steal, PID file recreated"
create_fake_lock test_steal_6 99999
"$LOCK_SCRIPT" --steal test_steal_6 -- sleep 1 &
declare -i LOCK_PID=$!
sleep 0.3
TEST_COUNT+=1
declare -- PID_CONTENT=''
# One read and no separate -f test: the file vanishes when the holder exits
if read -r PID_CONTENT 2>/dev/null </run/lock/test_steal_6.pid && [[ $PID_CONTENT =~ ^[0-9]+$ ]]; then
  TEST_PASSED+=1
  echo "  ✓ PID file recreated with valid numeric PID"
else
  echo "  ✗ PID file missing or invalid after steal: ${PID_CONTENT@Q}"
fi
reap "$LOCK_PID" 0

echo
echo "Test: Steal combined with --wait"
create_fake_lock test_steal_7 99999
assert_exit_code "Steal with --wait succeeds" 0 \
  "$LOCK_SCRIPT" --steal --wait test_steal_7 -- echo "test"

echo
echo "Test: Steal combined with --timeout"
create_fake_lock test_steal_8 99999
assert_exit_code "Steal with --timeout succeeds" 0 \
  "$LOCK_SCRIPT" --steal --timeout 5 test_steal_8 -- echo "test"

echo
echo "Test: Steal with auto-generated lockname"
create_fake_lock echo 99999
assert_exit_code "Steal with auto-generated lockname succeeds" 0 \
  "$LOCK_SCRIPT" --steal -- echo "test"

echo
echo "Test: Steal with malformed PID file — empty pidfile"
# read_holder_pid() returns 'unknown' for empty pidfile — steal must proceed
# without prompting (unknown holder is treated as dead).
touch /run/lock/test_steal_9.lock || setup_failed
: > /run/lock/test_steal_9.pid || setup_failed  # Empty (not stat-s, zero bytes)
assert_exit_code "Empty pidfile + --steal proceeds (exit 0)" 0 \
  "$LOCK_SCRIPT" --steal test_steal_9 -- echo "test"

echo
echo "Test: Steal with malformed PID file — non-numeric garbage"
touch /run/lock/test_steal_10.lock || setup_failed
echo "notapid" > /run/lock/test_steal_10.pid || setup_failed
assert_exit_code "Garbage pidfile + --steal proceeds (exit 0)" 0 \
  "$LOCK_SCRIPT" --steal test_steal_10 -- echo "test"

echo
echo "Test: Steal with missing PID file but lockfile present"
touch /run/lock/test_steal_11.lock || setup_failed
rm -f /run/lock/test_steal_11.pid || setup_failed    # Ensure pidfile missing
assert_exit_code "Missing pidfile + --steal proceeds (exit 0)" 0 \
  "$LOCK_SCRIPT" --steal test_steal_11 -- echo "test"

echo
echo "Test: Steal of age-stale lock whose holder is still running"
# Regression test: prior to the steal-before-stale-cleanup ordering fix, the
# stale-with-running-holder branch would die 1 before steal_lock ran, defeating
# the user's explicit --steal override. With the fix, steal proceeds normally
# (prompts because holder is alive; piped 'y' approves the steal).
sleep 60 &
declare -i H1_HOLDER_PID=$!
touch /run/lock/test_steal_h1.lock || setup_failed
echo "$H1_HOLDER_PID" > /run/lock/test_steal_h1.pid || setup_failed
# Backdate lockfile mtime past --max-age
backdate /run/lock/test_steal_h1.lock 90000
assert_exit_code "Steal of stale-but-alive-holder lock (confirmed) succeeds" 0 \
  bash -c 'echo "y" | "$1" --steal --max-age 1 test_steal_h1 -- echo "stolen-stale-alive"' _ "$LOCK_SCRIPT"
kill "$H1_HOLDER_PID" 2>/dev/null || true
reap "$H1_HOLDER_PID" 0 143

echo
echo "Test: Steal of age-stale lock with running holder — user declines"
# Companion to the previous test: same setup, but user pipes 'n' → exit 1
# from the cancel branch (NOT from the age-stale branch we used to die in).
sleep 60 &
declare -i H1B_HOLDER_PID=$!
touch /run/lock/test_steal_h1b.lock || setup_failed
echo "$H1B_HOLDER_PID" > /run/lock/test_steal_h1b.pid || setup_failed
backdate /run/lock/test_steal_h1b.lock 90000
assert_contains "Stale-alive steal declined says 'cancelled' (not 'running for')" "cancelled by user" \
  bash -c 'echo "n" | "$1" --steal --max-age 1 test_steal_h1b -- echo "should-not-run" 2>&1' _ "$LOCK_SCRIPT"
kill "$H1B_HOLDER_PID" 2>/dev/null || true
reap "$H1B_HOLDER_PID" 0 143
rm -f /run/lock/test_steal_h1.lock /run/lock/test_steal_h1.pid \
      /run/lock/test_steal_h1b.lock /run/lock/test_steal_h1b.pid

echo
echo "Test: Failed contender leaves the holder's PID file intact"
# Regression: cleanup() is armed before flock and used to remove \$PIDFILE
# unconditionally, so a contender that failed flock deleted the live holder's
# PID file; --steal then took the holder for dead and stole without a prompt.
"$LOCK_SCRIPT" test_steal_r1 -- sleep 3 &
declare -i R1_HOLDER_PID=$!
sleep 0.3
"$LOCK_SCRIPT" test_steal_r1 -- echo "should-not-run" &>/dev/null || true
declare -- R1_PID_CONTENT=''
read -r R1_PID_CONTENT 2>/dev/null </run/lock/test_steal_r1.pid || R1_PID_CONTENT=''  # missing: check fails
TEST_COUNT+=1
if [[ $R1_PID_CONTENT == "$R1_HOLDER_PID" ]]; then
  TEST_PASSED+=1
  echo "  ✓ PID file still records the holder after a failed contender"
else
  echo "  ✗ PID file should record holder $R1_HOLDER_PID (got '${R1_PID_CONTENT:-<missing>}')"
fi

echo
echo "Test: Steal after a failed contender still prompts (holder alive)"
assert_exit_code "Steal declined after contender bounce returns exit code 1" 1 \
  "$LOCK_SCRIPT" --steal test_steal_r1 -- echo "test" <<< n
kill "$R1_HOLDER_PID" 2>/dev/null || true
reap "$R1_HOLDER_PID" 0 143
rm -f /run/lock/test_steal_r1.lock /run/lock/test_steal_r1.pid

echo
echo "Test: Stolen-from holder exiting leaves the new holder's PID file"
# The original holder's cleanup() must not remove the PID file written by the
# process that stole the lock from it.
"$LOCK_SCRIPT" test_steal_r2 -- sleep 1 &
declare -i R2_OLD_PID=$!
sleep 0.3
"$LOCK_SCRIPT" --steal test_steal_r2 -- sleep 3 <<< y &>/dev/null &
declare -i R2_NEW_PID=$!
declare -i R2_OLD_RC=0
wait "$R2_OLD_PID" 2>/dev/null || R2_OLD_RC=$?
sleep 0.3
declare -- R2_PID_CONTENT=''
read -r R2_PID_CONTENT 2>/dev/null </run/lock/test_steal_r2.pid || R2_PID_CONTENT=''  # missing: check fails
TEST_COUNT+=1
if ((R2_OLD_RC == 0)) && [[ $R2_PID_CONTENT == "$R2_NEW_PID" ]]; then
  TEST_PASSED+=1
  echo "  ✓ New holder's PID file survives the old holder's exit"
else
  echo "  ✗ PID file should record new holder $R2_NEW_PID (got '${R2_PID_CONTENT:-<missing>}'; old holder exit $R2_OLD_RC)"
fi
kill "$R2_NEW_PID" 2>/dev/null || true
reap "$R2_NEW_PID" 0 143
rm -f /run/lock/test_steal_r2.lock /run/lock/test_steal_r2.pid

echo
echo "Test: Steal from a live holder whose PID file is missing prompts"
# Regression: steal_lock judged liveness from the PID file alone, so a holder
# without one counted as abandoned: its lock was removed with no prompt and a
# second process acquired it. A flock probe now finds the live holder.
"$LOCK_SCRIPT" test_steal_p1 -- sleep 3 &
HOLDER_PID=$!
sleep 0.3
rm -f /run/lock/test_steal_p1.pid || setup_failed
assert_contains "Missing-PID-file steal from a live holder prompts; 'n' cancels it" "cancelled by user" \
  "$LOCK_SCRIPT" --steal test_steal_p1 -- echo "should-not-run" <<< n
kill "$HOLDER_PID" 2>/dev/null || true
reap "$HOLDER_PID" 0 143
rm -f /run/lock/test_steal_p1.lock /run/lock/test_steal_p1.pid

echo
echo "Test: Steal from a live holder whose PID file names a dead process prompts"
"$LOCK_SCRIPT" test_steal_p2 -- sleep 3 &
HOLDER_PID=$!
sleep 0.3
echo 99999 > /run/lock/test_steal_p2.pid || setup_failed
assert_contains "Stale-PID-file steal from a live holder prompts; 'n' cancels it" "cancelled by user" \
  "$LOCK_SCRIPT" --steal test_steal_p2 -- echo "should-not-run" <<< n
kill "$HOLDER_PID" 2>/dev/null || true
reap "$HOLDER_PID" 0 143
rm -f /run/lock/test_steal_p2.lock /run/lock/test_steal_p2.pid

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
