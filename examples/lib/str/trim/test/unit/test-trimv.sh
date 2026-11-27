#!/usr/bin/env bash
# Unit tests for trimv utility

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

# Source the trimv module (must be sourced for variable assignment to work)
[[ -f $ROOT_DIR/trimv.bash ]] || { >&2 echo "${0##*/}: ✗ missing trimv.bash"; exit 3; }
#shellcheck source=trimv.bash
source -- "$ROOT_DIR"/trimv.bash || { >&2 echo "${0##*/}: ✗ cannot source trimv.bash"; exit 1; }

# Test basic variable assignment
test_basic_variable_assignment() {
  # Use a unique variable name to avoid conflicts
  local test_var=""
  # Use the trimv utility to assign a trimmed value
  trimv -n test_var "  hello world  " || fail 'trimv exited non-zero'

  local expected="hello world"
  assert_equals "$test_var" "$expected" "Basic variable assignment"
}

# Test variable assignment with escape sequences
test_escape_sequence_assignment() {
  local test_var=""
  trimv -e -n test_var "  hello\tworld\n  " || fail 'trimv exited non-zero'
  
  local expected=$'hello\tworld\n'
  assert_equals "$test_var" "$expected" "Variable assignment with escape sequences"
}

# Test stdin assignment
test_stdin_assignment() {
  local test_var=""
  local input="  hello from stdin  "
  # Use process substitution instead of pipe to avoid subshell
  trimv -n test_var < <(echo "$input") || fail 'trimv exited non-zero'

  local expected="hello from stdin"
  assert_equals "$test_var" "$expected" "Variable assignment from stdin echo"
}

# Test multiline stdin assignment
test_multiline_stdin_assignment() {
  local test_var=""
  # Create a temporary multiline input
  local -- input_file
  input_file="$(create_temp_multiline_file << EOF
  line one  
  line two  
	line three with tab	
EOF
)" || fail 'cannot create temp input file'
  
  # Use trimv with stdin from file
  trimv -n test_var < "$input_file" || fail 'trimv exited non-zero'
  
  local expected="line one
line two
line three with tab"
  
  assert_equals "$test_var" "$expected" "Multiline variable assignment from stdin"
}

# Test file input assignment
test_file_input_assignment() {
  local test_var=""
  trimv -n test_var < "$FIXTURES_DIR/input/multiline.txt" || fail 'trimv exited non-zero'
  
  # Expected result should have leading and trailing whitespace removed from each line
  local expected="Line one with leading and trailing spaces
Line two with more leading spaces
Line three with no leading spaces
Line four with a tab

Line six after an empty line"
  
  assert_equals "$test_var" "$expected" "Variable assignment from file"
}

# Test default output (without -n)
test_default_output() {
  local input="  hello world  "
  local expected="hello world"
  local -- actual
  actual=$(trimv "$input") || fail 'trimv exited non-zero'
  
  assert_equals "$actual" "$expected" "Default output behavior"
}

# Test empty input
test_empty_input() {
  local test_var="previous value"
  trimv -n test_var "" || fail 'trimv exited non-zero'
  
  local expected=""
  assert_equals "$test_var" "$expected" "Empty string assignment"
  
  # Test with empty file
  test_var="previous value"
  trimv -n test_var < "$FIXTURES_DIR/input/empty.txt" || fail 'trimv exited non-zero'
  
  expected=""
  assert_equals "$test_var" "$expected" "Empty file assignment"
}

# Test whitespace-only input
test_whitespace_only() {
  local test_var="previous value"
  trimv -n test_var "    " || fail 'trimv exited non-zero'  # Only spaces, no tabs
  
  local expected=""
  assert_equals "$test_var" "$expected" "Whitespace-only string assignment"
}

# Test invalid variable name
# A trailing bare -n must take the TRIM default, not trim '-n' itself
test_bare_n_defaults_to_trim() {
  local TRIM='unset'
  trimv -n <<< "  hello  " || fail 'trimv exited non-zero'
  assert_equals "$TRIM" 'hello' 'Bare -n reads stdin into TRIM'

  TRIM='unset'
  trimv -e -n <<< "  hello  " || fail 'trimv exited non-zero'
  assert_equals "$TRIM" 'hello' 'Bare -e -n reads stdin into TRIM'

  TRIM='unset'
  trimv -n '' "  hello  " || fail 'trimv exited non-zero'
  assert_equals "$TRIM" 'hello' 'Empty -n name takes the TRIM default'
}

test_invalid_variable_name() {
  # This should return an error code
  if trimv -n "123invalid" "test" 2>/dev/null; then
    >&2 echo "Test failed: Expected error for invalid variable name"
    return 1
  else
    echo -e "${GREEN}✓ Test passed: Invalid variable name properly rejected${NC}"
    return 0
  fi
}

# Run all tests
test_basic_variable_assignment
test_escape_sequence_assignment
test_stdin_assignment
test_multiline_stdin_assignment
test_file_input_assignment
test_default_output
test_empty_input
test_whitespace_only
test_bare_n_defaults_to_trim
test_invalid_variable_name

echo "All trimv tests passed!"
exit 0

#fin