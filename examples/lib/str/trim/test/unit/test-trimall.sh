#!/usr/bin/env bash
# Unit tests for trimall utility

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

# Path to the trimall utility
TRIMALL="$ROOT_DIR/trimall.bash"

# Ensure the utility is available
if [[ ! -x "$TRIMALL" ]]; then
  >&2 echo "${0##*/}: ✗ ${TRIMALL@Q} not found or not executable"
  exit 1
fi

# Test basic whitespace normalization
test_basic_trimall() {
  local input="  hello    world  "
  local expected="hello world"
  local -- actual
  actual=$("$TRIMALL" "$input") || fail 'trimall exited non-zero'
  
  assert_equals "$actual" "$expected" "Basic whitespace normalization"
}

# Test with mixed whitespace characters
test_mixed_whitespace() {
  local input=$'\t  hello \t world \t  '
  local expected="hello world"
  local -- actual
  actual=$("$TRIMALL" "$input") || fail 'trimall exited non-zero'
  
  assert_equals "$actual" "$expected" "Normalizing mixed whitespace"
}

# Test with multiple consecutive spaces
test_multiple_spaces() {
  local input="multiple     consecutive    spaces"
  local expected="multiple consecutive spaces"
  local -- actual
  actual=$("$TRIMALL" "$input") || fail 'trimall exited non-zero'
  
  assert_equals "$actual" "$expected" "Collapsing multiple spaces"
}

# Test stdin processing with echo 
# (this should work with our improved version from earlier)
test_stdin_echo() {
  local input="  hello    from    stdin  "
  local expected="hello from stdin"
  local -- actual
  actual=$(echo "$input" | "$TRIMALL") || fail 'trimall exited non-zero'
  
  assert_equals "$actual" "$expected" "Processing from stdin with echo"
}

# Test stdin processing with a file
# (this should work with our improved version from earlier)
test_stdin_file() {
  local input_file="$FIXTURES_DIR/input/multiline.txt"
  local expected_file="$FIXTURES_DIR/expected/multiline_trimall.txt"
  local -- output_file
  output_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'
  
  "$TRIMALL" < "$input_file" > "$output_file" || fail 'trimall exited non-zero'
  
  assert_file_equals "$output_file" "$expected_file" "Processing from stdin with a file"
}

# Test empty input
test_empty_input() {
  local input=""
  local expected=""
  local -- actual
  actual=$("$TRIMALL" "$input") || fail 'trimall exited non-zero'
  
  assert_equals "$actual" "$expected" "Normalizing empty string"
}

# Test whitespace-only input
test_whitespace_only() {
  local input="    "  # Only spaces, no tabs
  local expected=""
  local -- actual
  actual=$("$TRIMALL" "$input") || fail 'trimall exited non-zero'
  
  assert_equals "$actual" "$expected" "Normalizing whitespace-only string"
}

# Test with escape sequences
test_escape_sequences() {
  local input=$'  \\t  hello \\n  world  '
  local expected=$'\\t hello \\n world'
  local -- actual
  actual=$("$TRIMALL" "$input") || fail 'trimall exited non-zero'
  
  assert_equals "$actual" "$expected" "Default behavior with escape sequences"
  
  # Test with -e flag
  # When -e processes escape sequences, tabs and newlines become actual whitespace
  # trimall then normalizes ALL whitespace (including tabs/newlines) to single spaces
  local input_e=$'  \\t  hello \\n  world  '
  local expected_e="hello world"
  local -- actual_e
  actual_e=$("$TRIMALL" -e "$input_e") || fail 'trimall -e exited non-zero'

  assert_equals "$actual_e" "$expected_e" "Processing escape sequences with -e flag"
}

# Run all tests
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