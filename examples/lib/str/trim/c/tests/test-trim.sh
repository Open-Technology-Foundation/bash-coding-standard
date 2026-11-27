#!/usr/bin/env bash
# Unit tests for trim utility (C reimplementation)

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$TEST_DIR/.." && pwd)"
source "$TEST_DIR/../../test/utils.sh"

TRIM="${BIN_DIR:-$ROOT_DIR}/trim"

if [[ ! -x "$TRIM" ]]; then
  echo "Error: trim utility not found or not executable at $TRIM"
  exit 1
fi

test_basic_trim() {
  local input="  hello world  "
  local expected="hello world"
  local actual="$("$TRIM" "$input")"
  assert_equals "$actual" "$expected" "Basic string trimming"
}

test_leading_spaces() {
  local input="   hello world"
  local expected="hello world"
  local actual="$("$TRIM" "$input")"
  assert_equals "$actual" "$expected" "Trimming leading spaces"
}

test_trailing_spaces() {
  local input="hello world   "
  local expected="hello world"
  local actual="$("$TRIM" "$input")"
  assert_equals "$actual" "$expected" "Trimming trailing spaces"
}

test_mixed_whitespace() {
  local input=$'\t  hello \t world \t  '
  local expected=$'hello \t world'
  local actual="$("$TRIM" "$input")"
  assert_equals "$actual" "$expected" "Trimming mixed whitespace"
}

test_stdin_echo() {
  local input="  hello from stdin  "
  local expected="hello from stdin"
  local actual="$(echo "$input" | "$TRIM")"
  assert_equals "$actual" "$expected" "Processing from stdin with echo"
}

test_stdin_file() {
  local input_file="$FIXTURES_DIR/input/multiline.txt"
  local expected_file="$FIXTURES_DIR/expected/multiline_trim.txt"
  local output_file="$TMP_DIR/trim_c_output.txt"
  "$TRIM" < "$input_file" > "$output_file"
  assert_file_equals "$output_file" "$expected_file" "Processing from stdin with a file"
}

test_empty_input() {
  local input=""
  local expected=""
  local actual="$("$TRIM" "$input")"
  assert_equals "$actual" "$expected" "Trimming empty string"

  local input_file="$FIXTURES_DIR/input/empty.txt"
  local expected_file="$FIXTURES_DIR/expected/empty_trim.txt"
  local output_file="$TMP_DIR/empty_trim_c_output.txt"
  "$TRIM" < "$input_file" > "$output_file"
  assert_file_equals "$output_file" "$expected_file" "Processing empty file"
}

test_whitespace_only() {
  local input="    "
  local expected=""
  local actual="$("$TRIM" "$input")"
  assert_equals "$actual" "$expected" "Trimming whitespace-only string"

  local input_file="$FIXTURES_DIR/input/whitespace.txt"
  local expected_file="$FIXTURES_DIR/expected/whitespace_trim.txt"
  local output_file="$TMP_DIR/whitespace_trim_c_output.txt"
  "$TRIM" < "$input_file" > "$output_file"
  assert_file_equals "$output_file" "$expected_file" "Processing whitespace-only file"
}

test_escape_sequences() {
  local input=$'  \\t\\n  hello  \\t\\n  '
  local expected=$'\\t\\n  hello  \\t\\n'
  local actual="$("$TRIM" "$input")"
  assert_equals "$actual" "$expected" "Default behavior with escape sequences"

  local input_e=$'  \\t\\n  hello  \\t\\n  '
  local expected_e=$'\n  hello  \t'
  local actual_e="$("$TRIM" -e "$input_e")"
  assert_equals "$actual_e" "$expected_e" "Processing escape sequences with -e flag"
}

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
