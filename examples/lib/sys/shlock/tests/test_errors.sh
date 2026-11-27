#!/bin/bash
#shellcheck disable=SC2329  # cleanup() runs via the EXIT trap
#shellcheck disable=SC2016  # bash -c bodies are single-quoted on purpose: values arrive as "$1"
# Error handling and edge case tests for shlock

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
  [[ -z $TMP_DIR ]] || rm -rf -- "$TMP_DIR"
  # Kill any background processes
  jobs -p | xargs -r kill 2>/dev/null || true
  # Clean up any locks created during tests
  rm -f /run/lock/test_error_*.lock /run/lock/test_error_*.pid 2>/dev/null || true
  rm -f /run/lock/test-error*.lock /run/lock/test-error*.pid 2>/dev/null || true
  rm -f /run/lock/test.error*.lock /run/lock/test.error*.pid 2>/dev/null || true
  rm -f /run/lock/.hidden.lock /run/lock/.hidden.pid 2>/dev/null || true
  rm -f /run/lock/12345.lock /run/lock/12345.pid 2>/dev/null || true
  # PID file write-failure test creates a directory at $PIDFILE — clean it up if leaked
  rmdir /run/lock/test_error_pidfail.pid 2>/dev/null || true
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
echo "Test: Command failure propagation"
assert_exit_code "Wrapped 'exit 42' propagates code 42" 42 \
  "$LOCK_SCRIPT" test_error_1 -- bash -c 'exit 42'

assert_exit_code "Wrapped 'exit 1' propagates code 1" 1 \
  "$LOCK_SCRIPT" test_error_2 -- bash -c 'exit 1'

echo
echo "Test: Missing arguments"
assert_exit_code "No arguments returns exit code 2 (usage)" 2 \
  "$LOCK_SCRIPT"

assert_exit_code "Only lockname without separator returns exit code 2 (usage)" 2 \
  "$LOCK_SCRIPT" test_error_3

assert_exit_code "Lockname and separator but no command returns exit code 2 (usage)" 2 \
  "$LOCK_SCRIPT" test_error_4 --

assert_exit_code "Empty lockname auto-generates from command" 0 \
  "$LOCK_SCRIPT" "" -- echo "test"

echo
echo "Test: Invalid options"
assert_exit_code "Unknown option returns exit code 22" 22 \
  "$LOCK_SCRIPT" --unknown test_error_5 -- echo "test"

assert_exit_code "Invalid short option returns exit code 22" 22 \
  "$LOCK_SCRIPT" -x test_error_6 -- echo "test"

echo
echo "Test: Invalid --max-age values"
assert_exit_code "Non-numeric max-age returns exit code 22" 22 \
  "$LOCK_SCRIPT" --max-age abc test_error_7 -- echo "test"

assert_exit_code "Empty max-age returns exit code 22" 22 \
  "$LOCK_SCRIPT" --max-age "" test_error_8 -- echo "test"

assert_exit_code "Negative max-age returns exit code 22" 22 \
  "$LOCK_SCRIPT" --max-age -5 test_error_9 -- echo "test"

assert_exit_code "Floating point max-age returns exit code 22" 22 \
  "$LOCK_SCRIPT" --max-age 12.5 test_error_10 -- echo "test"

echo
echo "Test: Lock already held"
# Start a process holding the lock
"$LOCK_SCRIPT" test_error_11 -- sleep 1 &
declare -i HOLDER_PID=$!
sleep 0.1

assert_exit_code "Attempting to acquire held lock returns exit code 1" 1 \
  "$LOCK_SCRIPT" test_error_11 -- echo "test"

reap "$HOLDER_PID" 0

echo
echo "Test: Error messages are informative"
"$LOCK_SCRIPT" test_error_12 -- sleep 0.5 &
HOLDER_PID=$!
sleep 0.1
assert_contains "Lock held error mentions lock name" "test_error_12" \
  "$LOCK_SCRIPT" test_error_12 -- echo "test"
reap "$HOLDER_PID" 0

assert_exit_code "Auto-generated lockname succeeds" 0 \
  "$LOCK_SCRIPT" -- echo "test"

assert_contains "Missing command error is clear" "COMMAND" \
  "$LOCK_SCRIPT" test_error_13 --

assert_contains "Invalid max-age error is clear" "numeric" \
  "$LOCK_SCRIPT" --max-age xyz test_error_14 -- echo "test"

echo
echo "Test: Command not found"
assert_exit_code "Non-existent command propagates exit code 127" 127 \
  "$LOCK_SCRIPT" test_error_15 -- /nonexistent/command

echo
echo "Test: Command with insufficient permissions"
# Create a non-executable file
declare -- TEST_SCRIPT="$TMP_DIR"/noexec
echo "#!/bin/bash" > "$TEST_SCRIPT" || setup_failed
echo "echo 'test'" >> "$TEST_SCRIPT" || setup_failed
chmod -- a-x "$TEST_SCRIPT" || setup_failed

assert_exit_code "Non-executable command propagates exit code 126" 126 \
  "$LOCK_SCRIPT" test_error_16 -- "$TEST_SCRIPT"

rm -f -- "$TEST_SCRIPT"

echo
echo "Test: Special characters in lock names"
# These should work
assert_exit_code "Lock name with underscore works" 0 \
  "$LOCK_SCRIPT" test_error_with_underscore -- echo "test"

assert_exit_code "Lock name with dash works" 0 \
  "$LOCK_SCRIPT" test-error-with-dash -- echo "test"

assert_exit_code "Lock name with dots works" 0 \
  "$LOCK_SCRIPT" test.error.dots -- echo "test"

echo
echo "Test: Very long lock name"
declare -- LONG_NAME
LONG_NAME="test_error_$(printf 'a%.0s' {1..200})"
assert_exit_code "Very long lock name works" 0 \
  "$LOCK_SCRIPT" "$LONG_NAME" -- echo "test"
rm -f "/run/lock/${LONG_NAME}.lock" "/run/lock/${LONG_NAME}.pid"

echo
echo "Test: LOCKNAME sanitization (invalid names rejected)"
assert_exit_code "Path traversal '../evil' rejected" 22 \
  "$LOCK_SCRIPT" '../evil' -- echo "test"

assert_exit_code "Slash in lockname 'foo/bar' rejected" 22 \
  "$LOCK_SCRIPT" 'foo/bar' -- echo "test"

assert_exit_code "Space in lockname 'foo bar' rejected" 22 \
  "$LOCK_SCRIPT" 'foo bar' -- echo "test"

assert_exit_code "At-sign in lockname 'foo@bar' rejected" 22 \
  "$LOCK_SCRIPT" 'foo@bar' -- echo "test"

assert_exit_code "Single dot '.' rejected (creates hidden files)" 22 \
  "$LOCK_SCRIPT" '.' -- echo "test"

assert_exit_code "Double dot '..' rejected (creates hidden files)" 22 \
  "$LOCK_SCRIPT" '..' -- echo "test"

assert_exit_code "Triple dot '...' rejected (creates hidden files)" 22 \
  "$LOCK_SCRIPT" '...' -- echo "test"

echo
echo "Test: LOCKNAME sanitization (valid names accepted)"
assert_exit_code "Dotfile lockname '.hidden' accepted" 0 \
  "$LOCK_SCRIPT" '.hidden' -- echo "test"

assert_exit_code "Numeric lockname '12345' accepted" 0 \
  "$LOCK_SCRIPT" '12345' -- echo "test"

echo
echo "Test: Command with complex arguments"
assert_exit_code "Command with quotes and spaces works" 0 \
  "$LOCK_SCRIPT" test_error_17 -- bash -c 'echo "test with spaces"'

assert_exit_code "Command with multiple arguments works" 0 \
  "$LOCK_SCRIPT" test_error_18 -- bash -c 'test "$1" = "arg1" && test "$2" = "arg2"' _ arg1 arg2

echo
echo "Test: Signal handling during lock hold"
# Start a process with lock
"$LOCK_SCRIPT" test_error_19 -- sleep 10 &
declare -i VICTIM_PID=$!
sleep 0.3

# Send SIGTERM and wait for it to die
kill -TERM "$VICTIM_PID" 2>/dev/null || true
reap "$VICTIM_PID" 143  # must die by the TERM, not finish or fail
sleep 0.3

# Clean up orphaned files - flock releases but files may remain
rm -f /run/lock/test_error_19.pid /run/lock/test_error_19.lock 2>/dev/null || true

# Lock should be acquirable after cleanup
assert_exit_code "Lock is acquirable after killed process cleanup" 0 \
  "$LOCK_SCRIPT" test_error_19 -- echo "test"

echo
echo "Test: Empty command"
assert_exit_code "Empty string as command propagates exit code 127" 127 \
  "$LOCK_SCRIPT" test_error_20 -- ""

echo
echo "Test: PID file write failure returns exit code 5 (post-acquisition I/O)"
# Pre-create PIDFILE as a directory so 'echo $$ > $PIDFILE' fails after flock succeeds.
# This exercises the BCS0604 exit-5 path added in v2.0.1 (the PID write in main()).
mkdir /run/lock/test_error_pidfail.pid 2>/dev/null || true
if [[ -d /run/lock/test_error_pidfail.pid ]]; then
  assert_exit_code "PID file write failure returns exit code 5" 5 \
    "$LOCK_SCRIPT" test_error_pidfail -- echo "should not execute"
  assert_contains "Exit-5 error message mentions PID file" "PID file" \
    "$LOCK_SCRIPT" test_error_pidfail -- echo "should not execute"
  rmdir /run/lock/test_error_pidfail.pid 2>/dev/null || true
  rm -f /run/lock/test_error_pidfail.lock 2>/dev/null || true
else
  echo "  ⊘ SKIPPED: cannot create test PIDFILE directory in /run/lock"
fi

echo
echo "Test: Permission denied when no writable lock dir (bwrap sandbox)"
# Use bwrap to shadow /run/lock and /tmp with read-only binds so
# determine_lock_dir() exhausts all three fallbacks.
# /var/lock is a symlink to /run/lock on systemd hosts — shadowed transitively.
# Probe that bwrap can actually build a sandbox: hosts with
# kernel.apparmor_restrict_unprivileged_userns=1 have bwrap installed but it
# fails with exit 1, which would be misread as shlock's exit code.
if command -v bwrap &>/dev/null && bwrap --bind / / -- true &>/dev/null; then
  assert_exit_code "No writable lock dir returns exit code 13" 13 \
    bwrap --bind / / --dev /dev \
      --ro-bind /usr/lib /run/lock \
      --ro-bind /usr/lib /tmp \
      -- "$LOCK_SCRIPT" test_error_21 -- echo test

  assert_contains "Permission denied error mentions lock directory" "lock directory" \
    bwrap --bind / / --dev /dev \
      --ro-bind /usr/lib /run/lock \
      --ro-bind /usr/lib /tmp \
      -- "$LOCK_SCRIPT" test_error_22 -- echo test
else
  echo "  ⊘ SKIPPED: bwrap not installed or cannot create a sandbox (unprivileged userns restricted?)"
fi

echo
echo "Test: Unopenable lock file returns exit code 13"
# 'exec 200>>' fails on a lock file the caller cannot write. Root bypasses
# file modes, so this only means something for an unprivileged user.
if ((EUID)); then
  touch /run/lock/test_error_23.lock || setup_failed
  chmod 444 /run/lock/test_error_23.lock || setup_failed
  assert_exit_code "Read-only lock file returns exit code 13" 13 \
    "$LOCK_SCRIPT" test_error_23 -- echo "should not execute"
  assert_contains "Exit-13 message names the lock file" "Cannot open lock file" \
    "$LOCK_SCRIPT" test_error_23 -- echo "should not execute"
  rm -f /run/lock/test_error_23.lock /run/lock/test_error_23.pid
else
  echo "  ⊘ SKIPPED: running as root (file modes do not apply)"
fi

echo
echo "Test: Unreadable PID file is reported by shlock, not by bash"
# Regression: read_holder_pid used $(<file), and a failed $(<file) aborts under
# set -e even before ||, so a holder's unreadable PID file killed the contender
# with a raw 'line N: Permission denied'. Root reads mode-000 files.
if ((EUID)); then
  "$LOCK_SCRIPT" test_error_26 -- sleep 3 &
  HOLDER_PID=$!
  sleep 0.3
  chmod 000 /run/lock/test_error_26.pid || setup_failed
  assert_contains "Unreadable PID file gives shlock's own 'currently held' message" "is currently held" \
    "$LOCK_SCRIPT" test_error_26 -- echo "should not execute"
  chmod 600 /run/lock/test_error_26.pid || setup_failed
  kill "$HOLDER_PID" 2>/dev/null || true
  reap "$HOLDER_PID" 0 143
  rm -f /run/lock/test_error_26.lock /run/lock/test_error_26.pid
else
  echo "  ⊘ SKIPPED: running as root (file modes do not apply)"
fi

echo
echo "Test: Numeric options with leading zeros are decimal"
# Regression: \$((08)) is an invalid octal literal and aborted with exit 1
assert_exit_code "--max-age 08 accepted" 0 \
  "$LOCK_SCRIPT" --max-age 08 test_error_24 -- echo "test"
assert_exit_code "--timeout 09 accepted" 0 \
  "$LOCK_SCRIPT" --timeout 09 test_error_25 -- echo "test"

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
