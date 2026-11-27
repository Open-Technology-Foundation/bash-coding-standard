#!/usr/bin/env bash
# Integration tests for sourced trimming functions

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

# Source the module files
declare -- lib
for lib in trim ltrim rtrim trimall trimv; do
  [[ -f $ROOT_DIR/$lib.bash ]] || { >&2 echo "${0##*/}: ✗ missing $lib.bash"; exit 3; }
  #shellcheck disable=SC1090  # path is built from the loop variable; its existence is checked above
  source -- "$ROOT_DIR/$lib".bash || { >&2 echo "${0##*/}: ✗ cannot source $lib.bash"; exit 1; }
done

# Test using sourced trim function
test_sourced_trim() {
  local input="  hello world  "
  local expected="hello world"
  local -- actual
  actual=$(trim "$input") || fail 'trim exited non-zero'
  
  assert_equals "$actual" "$expected" "Using sourced trim function"
}

# Test using sourced ltrim function
test_sourced_ltrim() {
  local input="  hello world  "
  local expected="hello world  "
  local -- actual
  actual=$(ltrim "$input") || fail 'ltrim exited non-zero'
  
  assert_equals "$actual" "$expected" "Using sourced ltrim function"
}

# Test using sourced rtrim function
test_sourced_rtrim() {
  local input="  hello world  "
  local expected="  hello world"
  local -- actual
  actual=$(rtrim "$input") || fail 'rtrim exited non-zero'
  
  assert_equals "$actual" "$expected" "Using sourced rtrim function"
}

# Test using sourced trimall function
test_sourced_trimall() {
  local input="  multiple    spaces   here  "
  local expected="multiple spaces here"
  local -- actual
  actual=$(trimall "$input") || fail 'trimall exited non-zero'
  
  assert_equals "$actual" "$expected" "Using sourced trimall function"
}

# Test using sourced trimv function
test_sourced_trimv() {
  local test_var=""
  
  # Direct function call
  trimv -n test_var "  hello world  " || fail 'trimv exited non-zero'
  
  local expected="hello world"
  assert_equals "$test_var" "$expected" "Using sourced trimv function"
}

# Test using multiple sourced functions together
test_sourced_combination() {
  local input="  hello    world  "
  
  # Compare different function results
  local -- trim_result ltrim_part ltrim_rtrim_result trimall_result
  trim_result=$(trim "$input") || fail 'trim exited non-zero'
  ltrim_part=$(ltrim "$input") || fail 'ltrim exited non-zero'
  ltrim_rtrim_result=$(rtrim "$ltrim_part") || fail 'rtrim exited non-zero'
  trimall_result=$(trimall "$input") || fail 'trimall exited non-zero'
  
  assert_equals "$trim_result" "hello    world" "trim preserves internal spaces"
  assert_equals "$ltrim_rtrim_result" "$trim_result" "ltrim + rtrim equals trim"
  assert_equals "$trimall_result" "hello world" "trimall normalizes internal spaces"
}

# Test using sourced functions with stdin
test_sourced_stdin() {
  local input="  hello from stdin  "
  
  # Test each function with stdin
  local -- trim_result ltrim_result rtrim_result
  trim_result=$(echo "$input" | trim) || fail 'trim exited non-zero'
  ltrim_result=$(echo "$input" | ltrim) || fail 'ltrim exited non-zero'
  rtrim_result=$(echo "$input" | rtrim) || fail 'rtrim exited non-zero'
  
  assert_equals "$trim_result" "hello from stdin" "sourced trim with stdin"
  assert_equals "$ltrim_result" "hello from stdin  " "sourced ltrim with stdin"
  assert_equals "$rtrim_result" "  hello from stdin" "sourced rtrim with stdin"
}

# Test using sourced trimv with stdin
test_sourced_trimv_stdin() {
  local test_var=""
  local input="  hello from stdin  "

  # Use process substitution to avoid subshell (pipelines don't work with -n)
  trimv -n test_var < <(echo "$input") || fail 'trimv exited non-zero'

  local expected="hello from stdin"
  assert_equals "$test_var" "$expected" "sourced trimv with stdin"
}

# Run all tests
test_sourced_trim
test_sourced_ltrim
test_sourced_rtrim
test_sourced_trimall
test_sourced_trimv
test_sourced_combination
test_sourced_stdin
test_sourced_trimv_stdin

echo "All sourced function tests passed!"
exit 0

#fin