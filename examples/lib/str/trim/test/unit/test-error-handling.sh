#!/usr/bin/env bash
# Unit tests for error handling across all trim utilities
# Tests exit codes, invalid flags, stderr output, and error conditions

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

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Utilities to test
TRIM="$ROOT_DIR/trim.bash"
LTRIM="$ROOT_DIR/ltrim.bash"
RTRIM="$ROOT_DIR/rtrim.bash"
TRIMALL="$ROOT_DIR/trimall.bash"
SQUEEZE="$ROOT_DIR/squeeze.bash"

# Test helper: Assert exit code
assert_exit_code() {
  local actual=$1
  local expected=$2
  local message="${3:-}"

  if ((actual == expected)); then
    echo -e "${GREEN}✓ Exit code test passed${NC}${message:+: $message}"
    return 0
  else
    >&2 echo -e "${RED}✗ Exit code test failed${NC}${message:+: $message}"
    >&2 echo -e "Expected exit code: $expected"
    >&2 echo -e "Actual exit code:   $actual"
    return 1
  fi
}

# Test helper: Assert stderr is not empty
assert_stderr_not_empty() {
  local stderr="$1"
  local message="${2:-}"

  if [[ -n "$stderr" ]]; then
    echo -e "${GREEN}✓ Stderr test passed${NC}${message:+: $message}"
    return 0
  else
    >&2 echo -e "${RED}✗ Stderr test failed${NC}${message:+: $message}"
    >&2 echo -e "Expected: Non-empty stderr"
    >&2 echo -e "Actual:   Empty stderr"
    return 1
  fi
}

# Test: Invalid flag for trim
test_trim_invalid_flag() {
  local -- stderr_file
  local -i rc=0
  stderr_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'

  # Should fail with exit code 22 (EINVAL) or 1
  "$TRIM" --invalid-flag 2>"$stderr_file" >/dev/null || rc=$?

  # Exit code should be non-zero (either 22 or 1)
  if ((rc)); then
    echo -e "${GREEN}✓ Exit code test passed${NC}: trim rejects invalid flag"
  else
    >&2 echo -e "${RED}✗ Exit code test failed${NC}: trim should reject invalid flag"
    return 1
  fi

  # Should output error message to stderr
  assert_stderr_not_empty "$(cat -- "$stderr_file")" "Error message sent to stderr"
}

# Test: Invalid flag for ltrim
test_ltrim_invalid_flag() {
  local -- stderr_file
  local -i rc=0
  stderr_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'

  "$LTRIM" -x "test" 2>"$stderr_file" >/dev/null || rc=$?

  if ((rc)); then
    echo -e "${GREEN}✓ Exit code test passed${NC}: ltrim rejects invalid flag"
  else
    >&2 echo -e "${RED}✗ Exit code test failed${NC}: ltrim should reject invalid flag"
    return 1
  fi

  assert_stderr_not_empty "$(cat -- "$stderr_file")" "Error message sent to stderr"
}

# Test: Invalid flag for rtrim
test_rtrim_invalid_flag() {
  local -- stderr_file
  local -i rc=0
  stderr_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'

  "$RTRIM" --bad-option 2>"$stderr_file" >/dev/null || rc=$?

  if ((rc)); then
    echo -e "${GREEN}✓ Exit code test passed${NC}: rtrim rejects invalid flag"
  else
    >&2 echo -e "${RED}✗ Exit code test failed${NC}: rtrim should reject invalid flag"
    return 1
  fi

  assert_stderr_not_empty "$(cat -- "$stderr_file")" "Error message sent to stderr"
}

# Test: Invalid flag for trimall
test_trimall_invalid_flag() {
  local -- stderr_file
  local -i rc=0
  stderr_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'

  "$TRIMALL" -z 2>"$stderr_file" >/dev/null || rc=$?

  if ((rc)); then
    echo -e "${GREEN}✓ Exit code test passed${NC}: trimall rejects invalid flag"
  else
    >&2 echo -e "${RED}✗ Exit code test failed${NC}: trimall should reject invalid flag"
    return 1
  fi

  assert_stderr_not_empty "$(cat -- "$stderr_file")" "Error message sent to stderr"
}

# Test: Invalid flag for squeeze
test_squeeze_invalid_flag() {
  local -- stderr_file
  local -i rc=0
  stderr_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'

  "$SQUEEZE" --unknown 2>"$stderr_file" >/dev/null || rc=$?

  if ((rc)); then
    echo -e "${GREEN}✓ Exit code test passed${NC}: squeeze rejects invalid flag"
  else
    >&2 echo -e "${RED}✗ Exit code test failed${NC}: squeeze should reject invalid flag"
    return 1
  fi

  assert_stderr_not_empty "$(cat -- "$stderr_file")" "Error message sent to stderr"
}

# Test: trimv invalid variable name
test_trimv_invalid_varname() {
  [[ -f $ROOT_DIR/trimv.bash ]] || { >&2 echo "${0##*/}: ✗ missing trimv.bash"; exit 3; }
  #shellcheck source=trimv.bash
  source -- "$ROOT_DIR"/trimv.bash || { >&2 echo "${0##*/}: ✗ cannot source trimv.bash"; exit 1; }

  local -- stderr_file
  stderr_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'

  # Test various invalid names
  local invalid_names=(
    "123invalid"      # Starts with number
    "var-name"        # Contains dash
    "var.name"        # Contains dot
    "var name"        # Contains space
    "var\$name"       # Contains dollar sign
  )

  local -i passed=0
  local -i total=${#invalid_names[@]}
  local -- name

  for name in "${invalid_names[@]}"; do
    if trimv -n "$name" "test" 2>"$stderr_file" >/dev/null; then
      >&2 echo -e "${RED}✗ Test failed${NC}: Variable name '$name' should be rejected"
    else
      ((passed+=1))
    fi
  done

  if ((passed == total)); then
    echo -e "${GREEN}✓ Test passed${NC}: All invalid variable names rejected ($passed/$total)"
    return 0
  else
    >&2 echo -e "${RED}✗ Test failed${NC}: Some invalid names accepted ($passed/$total rejected)"
    return 1
  fi
}

# Test: trimv valid variable names that might seem invalid
test_trimv_valid_varnames() {
  [[ -f $ROOT_DIR/trimv.bash ]] || { >&2 echo "${0##*/}: ✗ missing trimv.bash"; exit 3; }
  #shellcheck source=trimv.bash
  source -- "$ROOT_DIR"/trimv.bash || { >&2 echo "${0##*/}: ✗ cannot source trimv.bash"; exit 1; }

  # These should all be VALID
  local valid_names=(
    "my_var"          # Underscores OK
    "_private"        # Leading underscore OK
    "var123"          # Numbers at end OK
    "var123name"      # Numbers in middle OK
    "UPPERCASE"       # All caps OK
    "if"              # Reserved word but valid var name
    "then"            # Reserved word but valid var name
  )

  local -i passed=0
  local -i total=${#valid_names[@]}
  local -- name

  for name in "${valid_names[@]}"; do
    if trimv -n "$name" "test" 2>/dev/null; then
      ((passed+=1))
    else
      >&2 echo -e "${RED}✗ Test failed${NC}: Variable name '$name' should be accepted"
    fi
  done

  if ((passed == total)); then
    echo -e "${GREEN}✓ Test passed${NC}: All valid variable names accepted ($passed/$total)"
    return 0
  else
    >&2 echo -e "${RED}✗ Test failed${NC}: Some valid names rejected ($passed/$total accepted)"
    return 1
  fi
}

# Test: Success exit code (0) for valid operations
test_success_exit_codes() {
  local -i rc
  # All these should exit with code 0
  rc=0
  "$TRIM" "test" >/dev/null || rc=$?
  assert_exit_code "$rc" 0 "trim with valid input"

  rc=0
  echo "test" | "$LTRIM" >/dev/null || rc=$?
  assert_exit_code "$rc" 0 "ltrim with stdin"

  rc=0
  "$RTRIM" "  test  " >/dev/null || rc=$?
  assert_exit_code "$rc" 0 "rtrim with valid input"

  rc=0
  "$TRIMALL" "  a  b  " >/dev/null || rc=$?
  assert_exit_code "$rc" 0 "trimall with valid input"

  rc=0
  "$SQUEEZE" "a    b" >/dev/null || rc=$?
  assert_exit_code "$rc" 0 "squeeze with valid input"
}

# Test: Empty input handling (should succeed with exit 0)
test_empty_input_exit_code() {
  local -i rc
  rc=0
  "$TRIM" "" >/dev/null || rc=$?
  assert_exit_code "$rc" 0 "trim with empty string"

  rc=0
  echo "" | "$LTRIM" >/dev/null || rc=$?
  assert_exit_code "$rc" 0 "ltrim with empty stdin"
}

# Test: Help flag returns exit code 0
test_help_exit_codes() {
  local -i rc
  rc=0
  "$TRIM" --help >/dev/null 2>&1 || rc=$?
  assert_exit_code "$rc" 0 "trim --help exits cleanly"

  rc=0
  "$TRIM" -h >/dev/null 2>&1 || rc=$?
  assert_exit_code "$rc" 0 "trim -h exits cleanly"

  rc=0
  "$LTRIM" --help >/dev/null 2>&1 || rc=$?
  assert_exit_code "$rc" 0 "ltrim --help exits cleanly"

  rc=0
  "$RTRIM" -h >/dev/null 2>&1 || rc=$?
  assert_exit_code "$rc" 0 "rtrim -h exits cleanly"
}

# Test: stderr vs stdout separation
test_stderr_stdout_separation() {
  local -- stdout_file stderr_file
  stdout_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'
  stderr_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'

  # Valid operation - should write to stdout only
  "$TRIM" "  test  " >"$stdout_file" 2>"$stderr_file" || fail 'trim exited non-zero on valid input'

  if [[ -s "$stdout_file" ]] && [[ ! -s "$stderr_file" ]]; then
    echo -e "${GREEN}✓ Test passed${NC}: Valid operation uses stdout only"
  else
    >&2 echo -e "${RED}✗ Test failed${NC}: Valid operation should not write to stderr"
    return 1
  fi

  # Invalid operation - should write to stderr only
  "$TRIM" --invalid >"$stdout_file" 2>"$stderr_file" || true

  if [[ -s "$stderr_file" ]]; then
    echo -e "${GREEN}✓ Test passed${NC}: Error messages go to stderr"
  else
    >&2 echo -e "${RED}✗ Test failed${NC}: Error messages should go to stderr"
    return 1
  fi
}

# Test: Multiple invalid flags
test_multiple_invalid_flags() {
  local -- stderr_file
  local -i rc=0
  stderr_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'

  "$TRIM" -x -y -z 2>"$stderr_file" >/dev/null || rc=$?

  if ((rc)); then
    echo -e "${GREEN}✓ Exit code test passed${NC}: Multiple invalid flags rejected"
  else
    >&2 echo -e "${RED}✗ Exit code test failed${NC}: Should reject multiple invalid flags"
    return 1
  fi
}

# Test: Flag after positional argument
test_flag_after_argument() {
  # Some utilities might accept this, but it's worth testing consistency
  local -- result1
  # Either outcome is accepted below; a failure is recorded as FAILED, not fatal
  result1=$("$TRIM" "test" -e 2>/dev/null || echo "FAILED")

  # This tests current behavior - document what happens
  if [[ "$result1" == "FAILED" ]]; then
    echo -e "${GREEN}✓ Test passed${NC}: Flags after arguments are rejected"
  else
    echo -e "${GREEN}✓ Test passed${NC}: Flags after arguments are accepted (result: '$result1')"
  fi
}

# Run all tests
>&2 echo "Testing error handling for all trim utilities..."
echo ""

test_trim_invalid_flag
test_ltrim_invalid_flag
test_rtrim_invalid_flag
test_trimall_invalid_flag
test_squeeze_invalid_flag
test_trimv_invalid_varname
test_trimv_valid_varnames
test_success_exit_codes
test_empty_input_exit_code
test_help_exit_codes
test_stderr_stdout_separation
test_multiple_invalid_flags
test_flag_after_argument

echo ""
echo "All error handling tests passed!"
exit 0

#fin
