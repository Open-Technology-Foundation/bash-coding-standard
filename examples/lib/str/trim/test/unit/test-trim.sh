#!/usr/bin/env bash
# Unit tests for trim utility

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

# Path to the trim utility
TRIM="$ROOT_DIR/trim.bash"

# Ensure the utility is available
if [[ ! -x "$TRIM" ]]; then
  >&2 echo "${0##*/}: ✗ ${TRIM@Q} not found or not executable"
  exit 1
fi

# Test basic string trimming
test_basic_trim() {
  local input="  hello world  "
  local expected="hello world"
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero (basic string)'

  assert_equals "$actual" "$expected" "Basic string trimming"
}

# Test trimming with only leading spaces
test_leading_spaces() {
  local input="   hello world"
  local expected="hello world"
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero (leading spaces)'

  assert_equals "$actual" "$expected" "Trimming leading spaces"
}

# Test trimming with only trailing spaces
test_trailing_spaces() {
  local input="hello world   "
  local expected="hello world"
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero (trailing spaces)'

  assert_equals "$actual" "$expected" "Trimming trailing spaces"
}

# Test trimming with various whitespace characters
test_mixed_whitespace() {
  local input=$'\t  hello \t world \t  '
  local expected=$'hello \t world'
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero (mixed whitespace)'

  assert_equals "$actual" "$expected" "Trimming mixed whitespace"
}

# Test stdin processing with echo
test_stdin_echo() {
  local input="  hello from stdin  "
  local expected="hello from stdin"
  local -- actual
  actual=$(echo "$input" | "$TRIM") || fail 'trim exited non-zero (stdin)'

  assert_equals "$actual" "$expected" "Processing from stdin with echo"
}

# Test stdin processing with a file
test_stdin_file() {
  local input_file="$FIXTURES_DIR/input/multiline.txt"
  local expected_file="$FIXTURES_DIR/expected/multiline_trim.txt"
  local -- output_file
  output_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'

  "$TRIM" < "$input_file" > "$output_file" || fail 'trim exited non-zero (multiline file)'

  assert_file_equals "$output_file" "$expected_file" "Processing from stdin with a file"
}

# Test empty input
test_empty_input() {
  local input=""
  local expected=""
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero (empty string)'

  assert_equals "$actual" "$expected" "Trimming empty string"

  # Test with empty file
  local input_file="$FIXTURES_DIR/input/empty.txt"
  local expected_file="$FIXTURES_DIR/expected/empty_trim.txt"
  local -- output_file
  output_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'

  "$TRIM" < "$input_file" > "$output_file" || fail 'trim exited non-zero (empty file)'

  assert_file_equals "$output_file" "$expected_file" "Processing empty file"
}

# Test whitespace-only input
test_whitespace_only() {
  local input="    "  # Only spaces, no tabs
  local expected=""
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero (whitespace-only string)'

  assert_equals "$actual" "$expected" "Trimming whitespace-only string"

  # Test with whitespace-only file
  local input_file="$FIXTURES_DIR/input/whitespace.txt"
  local expected_file="$FIXTURES_DIR/expected/whitespace_trim.txt"
  local -- output_file
  output_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'

  "$TRIM" < "$input_file" > "$output_file" || fail 'trim exited non-zero (whitespace-only file)'

  assert_file_equals "$output_file" "$expected_file" "Processing whitespace-only file"
}

# Test escape sequence processing
test_escape_sequences() {
  local input=$'  \\t\\n  hello  \\t\\n  '
  local expected=$'\\t\\n  hello  \\t\\n'
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero (escape sequences)'

  assert_equals "$actual" "$expected" "Default behavior with escape sequences"

  # Test with -e flag
  local input_e=$'  \\t\\n  hello  \\t\\n  '
  local expected_e=$'\n  hello  \t'
  local -- actual_e
  actual_e=$("$TRIM" -e "$input_e") || fail 'trim -e exited non-zero (escape sequences)'

  assert_equals "$actual_e" "$expected_e" "Processing escape sequences with -e flag"
}

# Run all tests
test_basic_trim
test_leading_spaces
test_trailing_spaces
test_mixed_whitespace
test_stdin_echo
test_stdin_file
test_empty_input
test_whitespace_only
test_escape_sequences

echo "All trim tests passed!"
exit 0

#fin
