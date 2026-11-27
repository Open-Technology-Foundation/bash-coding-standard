#!/usr/bin/env bash
# Unit tests for rtrim utility (C reimplementation)

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$TEST_DIR/.." && pwd)"
source "$TEST_DIR/../../test/utils.sh"

RTRIM="${BIN_DIR:-$ROOT_DIR}/rtrim"

if [[ ! -x "$RTRIM" ]]; then
  echo "Error: rtrim utility not found or not executable at $RTRIM"
  exit 1
fi

test_basic_rtrim() {
  local input="  hello world  "
  local expected="  hello world"
  local actual="$("$RTRIM" "$input")"
  assert_equals "$actual" "$expected" "Basic right trimming"
}

test_leading_spaces() {
  local input="   hello world"
  local expected="   hello world"
  local actual="$("$RTRIM" "$input")"
  assert_equals "$actual" "$expected" "Input with only leading spaces"
}

test_trailing_spaces() {
  local input="hello world   "
  local expected="hello world"
  local actual="$("$RTRIM" "$input")"
  assert_equals "$actual" "$expected" "Trimming only trailing spaces"
}

test_mixed_whitespace() {
  local input=$'\t  hello \t world \t  '
  local expected=$'\t  hello \t world'
  local actual="$("$RTRIM" "$input")"
  assert_equals "$actual" "$expected" "Trimming mixed trailing whitespace"
}

test_stdin_echo() {
  local input="  hello from stdin  "
  local expected="  hello from stdin"
  local actual="$(echo "$input" | "$RTRIM")"
  assert_equals "$actual" "$expected" "Processing from stdin with echo"
}

test_stdin_file() {
  local input_file="$FIXTURES_DIR/input/multiline.txt"
  local expected_file="$FIXTURES_DIR/expected/multiline_rtrim.txt"
  local output_file="$TMP_DIR/rtrim_c_output.txt"
  "$RTRIM" < "$input_file" > "$output_file"
  assert_file_equals "$output_file" "$expected_file" "Processing from stdin with a file"
}

test_empty_input() {
  local input=""
  local expected=""
  local actual="$("$RTRIM" "$input")"
  assert_equals "$actual" "$expected" "Right trimming empty string"

  local input_file="$FIXTURES_DIR/input/empty.txt"
  local expected_file="$FIXTURES_DIR/expected/empty_trim.txt"
  local output_file="$TMP_DIR/empty_rtrim_c_output.txt"
  "$RTRIM" < "$input_file" > "$output_file"
  assert_file_equals "$output_file" "$expected_file" "Processing empty file"
}

test_whitespace_only() {
  local input="    "
  local expected=""
  local actual="$("$RTRIM" "$input")"
  assert_equals "$actual" "$expected" "Right trimming whitespace-only string"
}

test_escape_sequences() {
  local input="  hello world  "
  local expected="  hello world"
  local actual="$("$RTRIM" "$input")"
  assert_equals "$actual" "$expected" "Basic rtrim without escape sequences"

  printf -v input_e "hello world  \t  "
  printf -v expected_e "hello world"
  local actual_e="$("$RTRIM" -e "$input_e")"
  assert_equals "$actual_e" "$expected_e" "Processing escape sequences with -e flag"
}

test_basic_rtrim
test_leading_spaces
test_trailing_spaces
test_mixed_whitespace
test_stdin_echo
test_stdin_file
test_empty_input
test_whitespace_only
test_escape_sequences

echo "All rtrim tests passed!"
exit 0
#fin
