#!/bin/bash
#shellcheck disable=SC2329  # cleanup() runs via the EXIT trap, helpers via "$@"
# Stale lock detection and cleanup tests for shlock

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
  rm -f /run/lock/test_stale_*.lock /run/lock/test_stale_*.pid 2>/dev/null || true
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

# Set a file's mtime N seconds in the past: `touch -t` first, Perl's utime()
# as fallback. Abort the suite when neither works -- stale-lock assertions
# against a fresh mtime would pass falsely and mask CI breakage.
backdate() {
  local -- file=$1 stamp
  local -i age=$2
  printf -v stamp '%(%Y%m%d%H%M.%S)T' "$((EPOCHSECONDS - age))"
  touch -t "$stamp" -- "$file" 2>/dev/null \
    || perl -e 'utime(time - $ARGV[0], time - $ARGV[0], $ARGV[1]) or exit 1' -- "$age" "$file" 2>/dev/null \
    || { echo "✗ FATAL: cannot backdate ${file@Q} (need coreutils touch or perl)" >&2; exit 1; }
}

# Create a stale lock file (holder PID 99999, assumed dead) aged N hours
create_stale_lock() {
  local -- lockname=$1
  local -i age_hours=${2:-25}  # Default 25 hours old

  local -- lockfile="/run/lock/${lockname}.lock"
  local -- pidfile="/run/lock/${lockname}.pid"

  touch -- "$lockfile" || setup_failed
  echo "99999" > "$pidfile" || setup_failed  # Non-existent PID
  backdate "$lockfile" "$((age_hours * 3600))"
}

# Tests
echo "Test: Stale lock detection (default 24 hour threshold)"
create_stale_lock test_stale_1 25
assert_success "Stale lock (25 hours old) is removed and lock acquired" \
  "$LOCK_SCRIPT" test_stale_1 -- echo "test"

echo
echo "Test: Non-stale lock is not removed"
# Actually hold the lock with a background process
"$LOCK_SCRIPT" test_stale_2 -- sleep 2 &
declare -i HOLDER_PID=$!
sleep 0.2
assert_failure "Recent lock held by active process prevents lock acquisition" \
  "$LOCK_SCRIPT" test_stale_2 -- echo "test"
reap "$HOLDER_PID" 0
rm -f /run/lock/test_stale_2.lock /run/lock/test_stale_2.pid

echo
echo "Test: Custom max-age threshold"
create_stale_lock test_stale_3 13
assert_success "Lock older than custom threshold (12 hours) is removed" \
  "$LOCK_SCRIPT" --max-age 12 test_stale_3 -- echo "test"

echo
echo "Test: Custom max-age threshold - lock not stale"
# Use an active lock instead of just a stale file
"$LOCK_SCRIPT" --max-age 12 test_stale_4 -- sleep 2 &
HOLDER_PID=$!
sleep 0.2
assert_failure "Active lock younger than custom threshold is preserved" \
  "$LOCK_SCRIPT" --max-age 12 test_stale_4 -- echo "test"
reap "$HOLDER_PID" 0
rm -f /run/lock/test_stale_4.lock /run/lock/test_stale_4.pid

echo
echo "Test: Stale lock with missing PID file"
touch /run/lock/test_stale_5.lock || setup_failed
backdate /run/lock/test_stale_5.lock 90000
# No PID file created
assert_success "Stale lock without PID file is removed" \
  "$LOCK_SCRIPT" test_stale_5 -- echo "test"

echo
echo "Test: Stale lock with running process (simulated)"
# Create a lock with our own PID (which is definitely running)
create_stale_lock test_stale_6 25
echo "$$" > /run/lock/test_stale_6.pid || setup_failed
assert_failure "Stale lock with running process is not removed" \
  "$LOCK_SCRIPT" test_stale_6 -- echo "test"
rm -f /run/lock/test_stale_6.lock /run/lock/test_stale_6.pid

echo
echo "Test: Invalid --max-age values"
declare -- OUTPUT
declare -i EXIT_CODE=0
TEST_COUNT+=1
OUTPUT=$("$LOCK_SCRIPT" --max-age abc test_stale_7 -- echo "test" 2>&1) || EXIT_CODE=$?
if ((EXIT_CODE == 22)) && [[ $OUTPUT =~ numeric ]]; then
  TEST_PASSED+=1
  echo "  ✓ Non-numeric max-age rejected"
else
  echo "  ✗ Non-numeric max-age should be rejected with exit code 22 (got $EXIT_CODE)"
fi

TEST_COUNT+=1
EXIT_CODE=0  # reset: a stale 22 from the block above would pass this one falsely
OUTPUT=$("$LOCK_SCRIPT" --max-age -- test_stale_8 -- echo "test" 2>&1) || EXIT_CODE=$?
if ((EXIT_CODE == 22)); then
  TEST_PASSED+=1
  echo "  ✓ Missing max-age value rejected"
else
  echo "  ✗ Missing max-age value should be rejected with exit code 22 (got $EXIT_CODE)"
fi

echo
echo "Test: Zero max-age"
create_stale_lock test_stale_9 0
sleep 1
assert_success "Lock with 0 max-age threshold removes any existing lock" \
  "$LOCK_SCRIPT" --max-age 0 test_stale_9 -- echo "test"

echo
echo "Test: Stale lock cleanup removes PID file"
create_stale_lock test_stale_10 30
"$LOCK_SCRIPT" test_stale_10 -- echo "test" &>/dev/null || setup_failed
# Lock file persists (recreated after stale cleanup, then kept for reuse)
assert_success "Lock file persists after acquisition" \
  file_exists /run/lock/test_stale_10.lock
# But PID file should be cleaned up
assert_failure "Stale PID file is removed" \
  file_exists /run/lock/test_stale_10.pid

echo
echo "Test: Age-stale lock with live holder still refused after a failed contender"
# Regression: a contender that failed flock used to delete the holder's PID
# file, so once the lock aged past --max-age the next run saw no live holder,
# removed the lock and ran concurrently with the original holder.
"$LOCK_SCRIPT" test_stale_11 -- sleep 3 &
HOLDER_PID=$!
sleep 0.3
"$LOCK_SCRIPT" test_stale_11 -- echo "should-not-run" &>/dev/null || true
backdate /run/lock/test_stale_11.lock 90000
assert_failure "Stale lock with live holder is not removed after contender bounce" \
  "$LOCK_SCRIPT" test_stale_11 -- echo "test"
kill "$HOLDER_PID" 2>/dev/null || true
reap "$HOLDER_PID" 0 143
rm -f /run/lock/test_stale_11.lock /run/lock/test_stale_11.pid

echo
echo "Test: Age-stale lock whose live holder lost its PID file is refused"
# Regression: liveness came from the PID file alone, so an age-stale lock with
# no usable PID file was cleaned while its holder ran, and a second process
# acquired it. A flock probe now finds the live holder.
"$LOCK_SCRIPT" test_stale_12 -- sleep 3 &
HOLDER_PID=$!
sleep 0.3
rm -f /run/lock/test_stale_12.pid || setup_failed
backdate /run/lock/test_stale_12.lock 90000
assert_failure "Age-stale lock with a live holder and no PID file is not removed" \
  "$LOCK_SCRIPT" test_stale_12 -- echo "test"
kill "$HOLDER_PID" 2>/dev/null || true
reap "$HOLDER_PID" 0 143
rm -f /run/lock/test_stale_12.lock /run/lock/test_stale_12.pid

echo
echo "Test: Held lock whose PID file names a dead process is not reclaimed"
# Regression: a dead PID in the PID file meant "reclaim" even while another
# process held the flock. The held flock now wins: the contender reports the
# lock as held and does not name the dead PID as its holder.
"$LOCK_SCRIPT" test_stale_13 -- sleep 3 &
HOLDER_PID=$!
sleep 0.3
echo 99999 > /run/lock/test_stale_13.pid || setup_failed
EXIT_CODE=0
OUTPUT=$("$LOCK_SCRIPT" test_stale_13 -- echo "should-not-run" 2>&1) || EXIT_CODE=$?
TEST_COUNT+=1
if ((EXIT_CODE == 1)) && [[ $OUTPUT == *'currently held'* && $OUTPUT != *99999* ]]; then
  TEST_PASSED+=1
  echo "  ✓ Held lock with a stale PID file is reported as held, without the dead PID"
else
  echo "  ✗ Expected exit 1 and 'currently held' without PID 99999 (exit $EXIT_CODE: $OUTPUT)"
fi
kill "$HOLDER_PID" 2>/dev/null || true
reap "$HOLDER_PID" 0 143
rm -f /run/lock/test_stale_13.lock /run/lock/test_stale_13.pid

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
