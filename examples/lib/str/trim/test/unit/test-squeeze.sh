#!/usr/bin/env bash
# Unit tests for squeeze utility

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

# Path to the squeeze utility
SQUEEZE="$ROOT_DIR/squeeze.bash"

# Ensure the utility is available
if [[ ! -x "$SQUEEZE" ]]; then
  >&2 echo "${0##*/}: ✗ ${SQUEEZE@Q} not found or not executable"
  exit 1
fi

# Test basic squeeze
test_basic_squeeze() {
  local input="hello    world"
  local expected="hello world"
  local -- actual
  actual=$("$SQUEEZE" "$input") || fail 'squeeze exited non-zero (basic squeeze)'

  assert_equals "$actual" "$expected" "Basic squeeze of multiple spaces"
}

# Test squeeze with leading/trailing spaces preserved
test_preserve_edges() {
  local input="  hello    world  "
  local expected=" hello world "
  local -- actual
  actual=$("$SQUEEZE" "$input") || fail 'squeeze exited non-zero (edges)'

  assert_equals "$actual" "$expected" "Preserve leading/trailing spaces"
}

# Test squeeze with tabs
test_squeeze_tabs() {
  local input=$'\t  hello \t\t world \t  '
  local expected=" hello world "
  local -- actual
  actual=$("$SQUEEZE" "$input") || fail 'squeeze exited non-zero (tabs)'

  assert_equals "$actual" "$expected" "Squeeze tabs and spaces"
}

# Test squeeze with mixed whitespace
test_mixed_whitespace() {
  local input="word1    word2   word3"
  local expected="word1 word2 word3"
  local -- actual
  actual=$("$SQUEEZE" "$input") || fail 'squeeze exited non-zero (mixed spacing)'

  assert_equals "$actual" "$expected" "Squeeze various amounts of spaces"
}

# Test stdin processing
test_stdin_echo() {
  local input="hello    from    stdin"
  local expected="hello from stdin"
  local -- actual
  actual=$(echo "$input" | "$SQUEEZE") || fail 'squeeze exited non-zero (stdin)'

  assert_equals "$actual" "$expected" "Processing from stdin"
}

# Test multiline stdin
test_stdin_multiline() {
  local input=$'line1    with    spaces\nline2  more  spaces'
  local expected=$'line1 with spaces\nline2 more spaces'
  local -- actual
  actual=$(echo "$input" | "$SQUEEZE") || fail 'squeeze exited non-zero (multiline stdin)'

  assert_equals "$actual" "$expected" "Processing multiline stdin"
}

# Test empty input
test_empty_input() {
  local input=""
  local expected=""
  local -- actual
  actual=$("$SQUEEZE" "$input") || fail 'squeeze exited non-zero (empty string)'

  assert_equals "$actual" "$expected" "Squeeze empty string"
}

# Test single space (no change)
test_single_space() {
  local input="hello world"
  local expected="hello world"
  local -- actual
  actual=$("$SQUEEZE" "$input") || fail 'squeeze exited non-zero (single space)'

  assert_equals "$actual" "$expected" "Single space unchanged"
}

# Test whitespace-only input
test_whitespace_only() {
  local input="    "
  local expected=" "
  local -- actual
  actual=$("$SQUEEZE" "$input") || fail 'squeeze exited non-zero (whitespace-only string)'

  assert_equals "$actual" "$expected" "Squeeze whitespace-only string"
}

# Test escape sequences with -e flag
test_escape_sequences() {
  local input="hello    world"
  local expected="hello world"
  local -- actual
  actual=$("$SQUEEZE" "$input") || fail 'squeeze exited non-zero (without -e)'

  assert_equals "$actual" "$expected" "Basic squeeze without -e flag"

  # Test with -e flag processing escape sequences
  local input_e=$'hello\\t\\tworld'
  local expected_e="hello world"
  local -- actual_e
  actual_e=$("$SQUEEZE" -e "$input_e") || fail 'squeeze -e exited non-zero (escape sequences)'

  assert_equals "$actual_e" "$expected_e" "Processing escape sequences with -e flag"
}

# Run all tests
test_basic_squeeze
test_preserve_edges
test_squeeze_tabs
test_mixed_whitespace
test_stdin_echo
test_stdin_multiline
test_empty_input
test_single_space
test_whitespace_only
test_escape_sequences

echo "All squeeze tests passed!"
exit 0

#fin
