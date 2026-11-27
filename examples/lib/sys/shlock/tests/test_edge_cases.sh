#!/bin/bash
#shellcheck disable=SC2329  # cleanup() runs via the EXIT trap
#shellcheck disable=SC2016  # bash -c bodies are single-quoted on purpose: values arrive as "$1"
#shellcheck disable=SC2324  # var+=1 is correct on declare -i globals per BCS0505
# Edge case and stress tests for shlock

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
  rm -f /run/lock/test_edge_*.lock /run/lock/test_edge_*.pid 2>/dev/null || true
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
echo "Test: Zero-duration command"
assert_exit_code "Command that completes instantly" 0 \
  "$LOCK_SCRIPT" test_edge_1 -- true

echo
echo "Test: Command that produces no output"
assert_exit_code "Silent command succeeds" 0 \
  "$LOCK_SCRIPT" test_edge_2 -- bash -c ':'

echo
echo "Test: Command that produces large output"
assert_exit_code "Command with large output succeeds" 0 \
  "$LOCK_SCRIPT" test_edge_3 -- bash -c 'for i in {1..1000}; do echo "line $i"; done'

echo
echo "Test: Command with stderr output"
declare -- OUTPUT_FILE="$TMP_DIR"/stderr
declare -i EXIT_CODE=0
"$LOCK_SCRIPT" test_edge_4 -- bash -c 'echo "error" >&2; exit 0' 2>"$OUTPUT_FILE" || EXIT_CODE=$?

TEST_COUNT+=1
if ((EXIT_CODE == 0)) && grep -q -- "error" "$OUTPUT_FILE"; then
  TEST_PASSED+=1
  echo "  ✓ Command stderr is preserved"
else
  echo "  ✗ Command stderr should be preserved"
fi
rm -f -- "$OUTPUT_FILE"

echo
echo "Test: Command with both stdout and stderr"
assert_exit_code "Command with mixed output succeeds" 0 \
  "$LOCK_SCRIPT" test_edge_5 -- bash -c 'echo "out"; echo "err" >&2'

echo
echo "Test: Command that creates files"
declare -- TEST_FILE="$TMP_DIR"/file
assert_exit_code "Command can create files" 0 \
  "$LOCK_SCRIPT" test_edge_6 -- bash -c 'echo content > "$1"' _ "$TEST_FILE"

TEST_COUNT+=1
if [[ -f $TEST_FILE && $(<"$TEST_FILE") == content ]]; then
  TEST_PASSED+=1
  echo "  ✓ Created file has expected content"
else
  echo "  ✗ File should be created with correct content"
fi
rm -f -- "$TEST_FILE"

echo
echo "Test: Command that reads from stdin"
assert_exit_code "Command with stdin input" 0 \
  bash -c 'echo "test input" | "$1" test_edge_7 -- grep -q "test"' _ "$LOCK_SCRIPT"

echo
echo "Test: Command with pipe"
assert_exit_code "Command in pipeline" 0 \
  "$LOCK_SCRIPT" test_edge_8 -- bash -c 'echo "hello world" | grep -q world'

echo
echo "Test: Command with redirection"
declare -- REDIR_FILE="$TMP_DIR"/redir
assert_exit_code "Command with output redirection" 0 \
  "$LOCK_SCRIPT" test_edge_9 -- bash -c 'echo redirected > "$1"' _ "$REDIR_FILE"

TEST_COUNT+=1
if [[ -f $REDIR_FILE && $(<"$REDIR_FILE") == redirected ]]; then
  TEST_PASSED+=1
  echo "  ✓ Redirected output written correctly"
else
  echo "  ✗ Redirection should work correctly"
fi
rm -f -- "$REDIR_FILE"

echo
echo "Test: Nested lock attempts (should fail)"
declare -- NESTED_SCRIPT="$TMP_DIR"/nested
cat > "$NESTED_SCRIPT" <<'EOF' || setup_failed
#!/bin/bash
LOCK_SCRIPT="$1"
# Try to acquire the same lock within a locked command
"$LOCK_SCRIPT" test_edge_nested -- echo "inner"
EOF
chmod -- +x "$NESTED_SCRIPT" || setup_failed

assert_exit_code "Nested lock attempt fails (propagates inner shlock's exit 1)" 1 \
  "$LOCK_SCRIPT" test_edge_nested -- "$NESTED_SCRIPT" "$LOCK_SCRIPT"

rm -f -- "$NESTED_SCRIPT"

echo
echo "Test: Lock with max-age of 1 hour"
assert_exit_code "Custom max-age (1 hour) works" 0 \
  "$LOCK_SCRIPT" --max-age 1 test_edge_10 -- echo "test"

echo
echo "Test: Lock with max-age of 168 hours (1 week)"
assert_exit_code "Large max-age (168 hours) works" 0 \
  "$LOCK_SCRIPT" --max-age 168 test_edge_11 -- echo "test"

echo
echo "Test: Command that changes directory"
declare -- ORIG_DIR
ORIG_DIR=$(pwd)
assert_exit_code "Command that changes directory" 0 \
  "$LOCK_SCRIPT" test_edge_12 -- bash -c 'cd /tmp && pwd'

TEST_COUNT+=1
if [[ "$(pwd)" == "$ORIG_DIR" ]]; then
  TEST_PASSED+=1
  echo "  ✓ Directory change in command doesn't affect caller"
else
  echo "  ✗ Directory should be unchanged after command"
fi

echo
echo "Test: Command with environment variables"
assert_exit_code "Command with custom environment variable" 0 \
  "$LOCK_SCRIPT" test_edge_13 -- bash -c 'export TEST_VAR=value && test "$TEST_VAR" = "value"'

echo
echo "Test: Command that spawns background process"
declare -- BG_FILE="$TMP_DIR"/bg
"$LOCK_SCRIPT" test_edge_14 -- bash -c '(sleep 0.2 && echo bg > "$1") &' _ "$BG_FILE" &>/dev/null \
  || setup_failed
sleep 0.3

TEST_COUNT+=1
if [[ -f $BG_FILE && $(<"$BG_FILE") == bg ]]; then
  TEST_PASSED+=1
  echo "  ✓ Background process spawned by command completes"
else
  echo "  ✗ Background process should complete"
fi
rm -f -- "$BG_FILE"

echo
echo "Test: Rapid sequential acquisitions (stress test)"
declare -i STRESS_COUNT=20
declare -i STRESS_SUCCESS=0
declare -i i
for ((i=1; i<=STRESS_COUNT; i+=1)); do
  if "$LOCK_SCRIPT" test_edge_15 -- echo "iteration $i" &>/dev/null; then
    STRESS_SUCCESS+=1
  fi
done

TEST_COUNT+=1
if ((STRESS_SUCCESS == STRESS_COUNT)); then
  TEST_PASSED+=1
  echo "  ✓ $STRESS_COUNT rapid sequential acquisitions succeeded"
else
  echo "  ✗ Expected $STRESS_COUNT successes, got $STRESS_SUCCESS"
fi

echo
echo "Test: PID file accuracy"
"$LOCK_SCRIPT" test_edge_16 -- sleep 1 &
declare -i LOCK_HOLDER=$!
sleep 0.3

# One read and no separate -f test: the file vanishes when the holder exits.
# (A failed $(<file) aborts the suite under set -e even inside a condition.)
TEST_COUNT+=1
declare -- PID_FROM_FILE=''
if read -r PID_FROM_FILE 2>/dev/null </run/lock/test_edge_16.pid && ps -p "$PID_FROM_FILE" &>/dev/null; then
  TEST_PASSED+=1
  echo "  ✓ PID in pidfile is valid and running"
else
  echo "  ✗ PID in pidfile should be running"
fi

reap "$LOCK_HOLDER" 0

echo
echo "Test: Lock name with numeric prefix"
assert_exit_code "Lock name starting with number" 0 \
  "$LOCK_SCRIPT" 123test_edge -- echo "test"

echo
echo "Test: Lock cleanup on normal exit"
"$LOCK_SCRIPT" test_edge_17 -- echo "test" >/dev/null || setup_failed
sleep 0.1

TEST_COUNT+=1
if [[ -f /run/lock/test_edge_17.lock ]] && [[ ! -f /run/lock/test_edge_17.pid ]]; then
  TEST_PASSED+=1
  echo "  ✓ Lock file persists but PID file cleaned up after exit"
else
  echo "  ✗ Lock file should persist but PID file should be removed"
fi

echo
echo "Test: Command with exit trap"
assert_exit_code "Command with its own exit trap" 0 \
  "$LOCK_SCRIPT" test_edge_18 -- bash -c 'trap "echo trapped" EXIT; true'

echo
echo "Test: Command that uses file descriptor 200"
# This tests that our lock mechanism doesn't break if command uses same FD
assert_exit_code "Command using FD 200" 0 \
  "$LOCK_SCRIPT" test_edge_19 -- bash -c 'exec 200>/dev/null; echo "test" >&200'

echo
echo "Test: Lock directory fallback chain (primary selection)"
# Confirm determine_lock_dir() picks /run/lock when it is writable,
# and does NOT create /tmp/locks as a side effect.
declare -i TMP_LOCKS_PRE_EXISTED=0
[[ -d /tmp/locks ]] && TMP_LOCKS_PRE_EXISTED=1

"$LOCK_SCRIPT" test_edge_lockdir_1 -- echo "lockdir test" >/dev/null || setup_failed

TEST_COUNT+=1
if [[ -f /run/lock/test_edge_lockdir_1.lock ]]; then
  TEST_PASSED+=1
  echo "  ✓ Lock lands in primary dir /run/lock when writable"
else
  echo "  ✗ Expected /run/lock/test_edge_lockdir_1.lock, not found"
fi

TEST_COUNT+=1
if ((TMP_LOCKS_PRE_EXISTED)) || [[ ! -d /tmp/locks ]]; then
  TEST_PASSED+=1
  echo "  ✓ /tmp/locks not created when /run/lock is writable"
else
  echo "  ✗ /tmp/locks was created despite /run/lock being writable"
fi
rm -f /run/lock/test_edge_lockdir_1.lock /run/lock/test_edge_lockdir_1.pid

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
