#!/usr/bin/env bash
# Unit tests for binary/non-printable character handling
# These tests document expected behavior with edge-case inputs

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

[[ -x "$TRIM" ]] || { >&2 echo "${0##*/}: ✗ ${TRIM@Q} not found or not executable"; exit 1; }

>&2 echo "Testing binary safety and non-printable characters..."

declare -i passed=0 failed=0

# Test non-printable ASCII (bell, backspace, etc.)
test_non_printable_ascii() {
  local -- input result
  # Bell (0x07) and backspace (0x08) in content
  input=$'  \x07hello\x08  '
  result=$("$TRIM" "$input") || fail "trim exited non-zero on ${input@Q}"

  # Non-printables should be preserved (not stripped as whitespace)
  if [[ "$result" == $'\x07hello\x08' ]]; then
    echo -e "${GREEN}Test passed${NC}: Non-printable ASCII preserved"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: Non-printable ASCII handling"
    ((++failed))
  fi
}

# Test vertical tab and form feed (not in [:blank:])
test_vt_ff_preserved() {
  local -- input result
  # Vertical tab (0x0B) and form feed (0x0C) are NOT in [:blank:]
  input=$'  \x0Bhello\x0C  '
  result=$("$TRIM" "$input") || fail "trim exited non-zero on ${input@Q}"

  # These should be preserved as they're not spaces/tabs
  if [[ "$result" == $'\x0Bhello\x0C' ]]; then
    echo -e "${GREEN}Test passed${NC}: Vertical tab and form feed preserved"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: VT/FF handling (got: ${result@Q})"
    ((++failed))
  fi
}

# Test escape character
test_escape_char() {
  local -- input result
  input=$'  \x1Bhello  '
  result=$("$TRIM" "$input") || fail "trim exited non-zero on ${input@Q}"

  if [[ "$result" == $'\x1Bhello' ]]; then
    echo -e "${GREEN}Test passed${NC}: Escape character preserved"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: Escape character handling"
    ((++failed))
  fi
}

# Test high ASCII (extended ASCII range)
test_high_ascii() {
  local -- input result
  # Characters in 128-255 range
  input=$'  \x80\xFF  '
  result=$("$TRIM" "$input") || fail "trim exited non-zero on ${input@Q}"

  if [[ "$result" == $'\x80\xFF' ]]; then
    echo -e "${GREEN}Test passed${NC}: High ASCII bytes preserved"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: High ASCII handling"
    ((++failed))
  fi
}

# Test that only space (0x20) and tab (0x09) are trimmed
test_only_blank_trimmed() {
  local -- input result
  # All control chars except space/tab should be preserved
  input=$' \t\x01\x02content\x03\x04 \t'
  result=$("$TRIM" "$input") || fail "trim exited non-zero on ${input@Q}"

  if [[ "$result" == $'\x01\x02content\x03\x04' ]]; then
    echo -e "${GREEN}Test passed${NC}: Only space/tab trimmed"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: Blank trimming (got: ${result@Q})"
    ((++failed))
  fi
}

# Run all tests
test_non_printable_ascii
test_vt_ff_preserved
test_escape_char
test_high_ascii
test_only_blank_trimmed

echo
echo "=== Summary: $passed passed, $failed failed ==="

if ((failed == 0)); then
  echo "All binary safety tests passed!"
  exit 0
else
  >&2 echo "Binary safety tests FAILED"
  exit 1
fi

#fin
