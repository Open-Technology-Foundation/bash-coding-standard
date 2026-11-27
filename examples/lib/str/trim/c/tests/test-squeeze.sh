#!/usr/bin/env bash
# Unit tests for squeeze utility (C reimplementation)

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$TEST_DIR/.." && pwd)"
source "$TEST_DIR/../../test/utils.sh"

SQUEEZE="${BIN_DIR:-$ROOT_DIR}/squeeze"

if [[ ! -x "$SQUEEZE" ]]; then
  echo "Error: squeeze utility not found or not executable at $SQUEEZE"
  exit 1
fi

test_basic_squeeze() {
  local input="hello    world"
  local expected="hello world"
  local actual="$("$SQUEEZE" "$input")"
  assert_equals "$actual" "$expected" "Basic squeeze of multiple spaces"
}

test_preserve_edges() {
  local input="  hello    world  "
  local expected=" hello world "
  local actual="$("$SQUEEZE" "$input")"
  assert_equals "$actual" "$expected" "Preserve leading/trailing spaces"
}

test_squeeze_tabs() {
  local input=$'\t  hello \t\t world \t  '
  local expected=" hello world "
  local actual="$("$SQUEEZE" "$input")"
  assert_equals "$actual" "$expected" "Squeeze tabs and spaces"
}

test_mixed_whitespace() {
  local input="word1    word2   word3"
  local expected="word1 word2 word3"
  local actual="$("$SQUEEZE" "$input")"
  assert_equals "$actual" "$expected" "Squeeze various amounts of spaces"
}

test_stdin_echo() {
  local input="hello    from    stdin"
  local expected="hello from stdin"
  local actual="$(echo "$input" | "$SQUEEZE")"
  assert_equals "$actual" "$expected" "Processing from stdin"
}

test_stdin_multiline() {
  local input=$'line1    with    spaces\nline2  more  spaces'
  local expected=$'line1 with spaces\nline2 more spaces'
  local actual="$(echo "$input" | "$SQUEEZE")"
  assert_equals "$actual" "$expected" "Processing multiline stdin"
}

test_empty_input() {
  local input=""
  local expected=""
  local actual="$("$SQUEEZE" "$input")"
  assert_equals "$actual" "$expected" "Squeeze empty string"
}

test_single_space() {
  local input="hello world"
  local expected="hello world"
  local actual="$("$SQUEEZE" "$input")"
  assert_equals "$actual" "$expected" "Single space unchanged"
}

test_whitespace_only() {
  local input="    "
  local expected=" "
  local actual="$("$SQUEEZE" "$input")"
  assert_equals "$actual" "$expected" "Squeeze whitespace-only string"
}

test_escape_sequences() {
  local input="hello    world"
  local expected="hello world"
  local actual="$("$SQUEEZE" "$input")"
  assert_equals "$actual" "$expected" "Basic squeeze without -e flag"

  local input_e=$'hello\\t\\tworld'
  local expected_e="hello world"
  local actual_e="$("$SQUEEZE" -e "$input_e")"
  assert_equals "$actual_e" "$expected_e" "Processing escape sequences with -e flag"
}

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
