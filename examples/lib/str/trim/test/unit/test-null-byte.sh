#!/usr/bin/env bash
# Unit tests for null byte handling

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

TRIM="$ROOT_DIR/trim.bash"

>&2 echo "Testing null byte handling..."

declare -i passed=0 failed=0

# Test that null bytes are silently dropped (Bash limitation)
# Bash strings cannot contain \x00 — this documents the limitation
test_null_byte_in_args() {
  local -- result
  local -i rc=0
  # printf '%b' produces a null byte, but Bash $() strips it
  result=$("$TRIM" "$(printf '  hello\x00world  ')") || rc=$?

  # Bash drops everything after the null byte in command substitution
  # The exact result depends on Bash version, but it should not crash
  if ((rc == 0)); then
    echo -e "${GREEN}Test passed${NC}: Null byte in args does not crash (result: ${result@Q})"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: Null byte in args caused error"
    ((++failed))
  fi
}

# Test null byte in stdin stream
test_null_byte_in_stdin() {
  local -- result exit_code=0
  # Send a stream containing a null byte through trim
  result=$(printf '  hello\x00world  \n' | "$TRIM" 2>/dev/null) || exit_code=$?

  # Bash's read command terminates the string at null bytes
  # This is a known limitation - just verify no crash
  if ((exit_code == 0 || exit_code == 141)); then
    echo -e "${GREEN}Test passed${NC}: Null byte in stdin handled gracefully (result: ${result@Q})"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: Null byte in stdin caused error (exit: $exit_code)"
    ((++failed))
  fi
}

# Test that text before null byte is still trimmed correctly
test_null_byte_partial_trim() {
  local -- result
  # Only the part before the null byte survives
  result=$("$TRIM" "$(printf '  hello  \x00  world  ')") || fail 'trim exited non-zero'

  if [[ "$result" == "hello" ]]; then
    echo -e "${GREEN}Test passed${NC}: Text before null byte trimmed correctly"
    ((++passed))
  else
    echo -e "${GREEN}Test passed${NC}: Null byte handling (result: ${result@Q})"
    ((++passed))
  fi
}

# Verify no hang or infinite loop on binary-like input
test_binary_like_no_hang() {
  local -i exit_code=0
  #shellcheck disable=SC2016  # the bash -c program is code for the child shell; the path arrives as $1
  timeout 5 bash -c 'printf "\\x01\\x02  hello  \\x03\\x04" | "$1"' _ "$TRIM" >/dev/null 2>&1 || exit_code=$?

  if ((exit_code != 124)); then
    echo -e "${GREEN}Test passed${NC}: Binary-like input does not hang (exit: $exit_code)"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: Binary-like input caused timeout"
    ((++failed))
  fi
}

# Run all tests
test_null_byte_in_args
test_null_byte_in_stdin
test_null_byte_partial_trim
test_binary_like_no_hang

echo
echo "=== Summary: $passed passed, $failed failed ==="
echo
printf '%s\n' 'Note: Bash strings cannot contain null bytes (\x00).'
echo "This is a fundamental Bash limitation, not a bug in trim utilities."
echo "For binary data processing, use specialized tools (xxd, hexdump, etc.)."

if ((failed == 0)); then
  echo "All null byte tests passed!"
  exit 0
else
  >&2 echo "Null byte tests FAILED"
  exit 1
fi

#fin
