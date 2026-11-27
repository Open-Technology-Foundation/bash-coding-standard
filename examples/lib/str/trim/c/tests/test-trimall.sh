#!/usr/bin/env bash
# Unit tests for trimall utility (C reimplementation)

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$TEST_DIR/.." && pwd)"
source "$TEST_DIR/../../test/utils.sh"

TRIMALL="${BIN_DIR:-$ROOT_DIR}/trimall"

if [[ ! -x "$TRIMALL" ]]; then
  echo "Error: trimall utility not found or not executable at $TRIMALL"
  exit 1
fi

test_basic_trimall() {
  local input="  hello    world  "
  local expected="hello world"
  local actual="$("$TRIMALL" "$input")"
  assert_equals "$actual" "$expected" "Basic whitespace normalization"
}

test_mixed_whitespace() {
  local input=$'\t  hello \t world \t  '
  local expected="hello world"
  local actual="$("$TRIMALL" "$input")"
  assert_equals "$actual" "$expected" "Normalizing mixed whitespace"
}

test_multiple_spaces() {
  local input="multiple     consecutive    spaces"
  local expected="multiple consecutive spaces"
  local actual="$("$TRIMALL" "$input")"
  assert_equals "$actual" "$expected" "Collapsing multiple spaces"
}

test_stdin_echo() {
  local input="  hello    from    stdin  "
  local expected="hello from stdin"
  local actual="$(echo "$input" | "$TRIMALL")"
  assert_equals "$actual" "$expected" "Processing from stdin with echo"
}

test_stdin_file() {
  local input_file="$FIXTURES_DIR/input/multiline.txt"
  local expected_file="$FIXTURES_DIR/expected/multiline_trimall.txt"
  local output_file="$TMP_DIR/trimall_c_output.txt"
  "$TRIMALL" < "$input_file" > "$output_file"
  assert_file_equals "$output_file" "$expected_file" "Processing from stdin with a file"
}

test_empty_input() {
  local input=""
  local expected=""
  local actual="$("$TRIMALL" "$input")"
  assert_equals "$actual" "$expected" "Normalizing empty string"
}

test_whitespace_only() {
  local input="    "
  local expected=""
  local actual="$("$TRIMALL" "$input")"
  assert_equals "$actual" "$expected" "Normalizing whitespace-only string"
}

test_escape_sequences() {
  local input=$'  \\t  hello \\n  world  '
  local expected=$'\\t hello \\n world'
  local actual="$("$TRIMALL" "$input")"
  assert_equals "$actual" "$expected" "Default behavior with escape sequences"

  local input_e=$'  \\t  hello \\n  world  '
  local expected_e="hello world"
  local actual_e="$("$TRIMALL" -e "$input_e")"
  assert_equals "$actual_e" "$expected_e" "Processing escape sequences with -e flag"
}

test_basic_trimall
test_mixed_whitespace
test_multiple_spaces
test_stdin_echo
test_stdin_file
test_empty_input
test_whitespace_only
test_escape_sequences

echo "All trimall tests passed!"
exit 0
#fin
