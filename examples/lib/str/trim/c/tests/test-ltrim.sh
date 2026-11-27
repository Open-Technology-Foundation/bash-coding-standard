#!/usr/bin/env bash
# Unit tests for ltrim utility (C reimplementation)

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$TEST_DIR/.." && pwd)"
source "$TEST_DIR/../../test/utils.sh"

LTRIM="${BIN_DIR:-$ROOT_DIR}/ltrim"

if [[ ! -x "$LTRIM" ]]; then
  echo "Error: ltrim utility not found or not executable at $LTRIM"
  exit 1
fi

test_basic_ltrim() {
  local input="  hello world  "
  local expected="hello world  "
  local actual="$("$LTRIM" "$input")"
  assert_equals "$actual" "$expected" "Basic left trimming"
}

test_leading_spaces() {
  local input="   hello world"
  local expected="hello world"
  local actual="$("$LTRIM" "$input")"
  assert_equals "$actual" "$expected" "Trimming only leading spaces"
}

test_trailing_spaces() {
  local input="hello world   "
  local expected="hello world   "
  local actual="$("$LTRIM" "$input")"
  assert_equals "$actual" "$expected" "Input with only trailing spaces"
}

test_mixed_whitespace() {
  local input=$'\t  hello \t world \t  '
  local expected=$'hello \t world \t  '
  local actual="$("$LTRIM" "$input")"
  assert_equals "$actual" "$expected" "Trimming mixed leading whitespace"
}

test_stdin_echo() {
  local input="  hello from stdin  "
  local expected="hello from stdin  "
  local actual="$(echo "$input" | "$LTRIM")"
  assert_equals "$actual" "$expected" "Processing from stdin with echo"
}

test_stdin_file() {
  local input_file="$FIXTURES_DIR/input/multiline.txt"
  local expected_file="$FIXTURES_DIR/expected/multiline_ltrim.txt"
  local output_file="$TMP_DIR/ltrim_c_output.txt"
  "$LTRIM" < "$input_file" > "$output_file"
  assert_file_equals "$output_file" "$expected_file" "Processing from stdin with a file"
}

test_empty_input() {
  local input=""
  local expected=""
  local actual="$("$LTRIM" "$input")"
  assert_equals "$actual" "$expected" "Left trimming empty string"

  local input_file="$FIXTURES_DIR/input/empty.txt"
  local expected_file="$FIXTURES_DIR/expected/empty_trim.txt"
  local output_file="$TMP_DIR/empty_ltrim_c_output.txt"
  "$LTRIM" < "$input_file" > "$output_file"
  assert_file_equals "$output_file" "$expected_file" "Processing empty file"
}

test_whitespace_only() {
  local input="    "
  local expected=""
  local actual="$("$LTRIM" "$input")"
  assert_equals "$actual" "$expected" "Left trimming whitespace-only string"
}

test_escape_sequences() {
  local input="  hello world  "
  local expected="hello world  "
  local actual="$("$LTRIM" "$input")"
  assert_equals "$actual" "$expected" "Basic ltrim without escape sequences"

  printf -v input_e "  \t  hello world"
  printf -v expected_e "hello world"
  local actual_e="$("$LTRIM" -e "$input_e")"
  assert_equals "$actual_e" "$expected_e" "Processing escape sequences with -e flag"
}

test_basic_ltrim
test_leading_spaces
test_trailing_spaces
test_mixed_whitespace
test_stdin_echo
test_stdin_file
test_empty_input
test_whitespace_only
test_escape_sequences

echo "All ltrim tests passed!"
exit 0
#fin
