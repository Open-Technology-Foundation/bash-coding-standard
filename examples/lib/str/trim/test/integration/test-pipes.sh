#!/usr/bin/env bash
# Integration tests for piping between trim utilities

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

# Paths to utilities
TRIM="$ROOT_DIR/trim.bash"
LTRIM="$ROOT_DIR/ltrim.bash"
RTRIM="$ROOT_DIR/rtrim.bash"
TRIMALL="$ROOT_DIR/trimall.bash"
SQUEEZE="$ROOT_DIR/squeeze.bash"

# Ensure all utilities are available
for util in "$TRIM" "$LTRIM" "$RTRIM" "$TRIMALL" "$SQUEEZE"; do
  if [[ ! -x "$util" ]]; then
    >&2 echo "${0##*/}: ✗ ${util@Q} not found or not executable"
    exit 1
  fi
done

# Test piping ltrim to rtrim (equivalent to trim)
test_ltrim_to_rtrim() {
  local input="  hello world  "
  local expected="hello world"
  local -- actual trim_actual
  actual=$(echo "$input" | "$LTRIM" | "$RTRIM") || fail 'ltrim | rtrim pipeline exited non-zero'
  trim_actual=$(echo "$input" | "$TRIM") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "Piping ltrim to rtrim"
  assert_equals "$actual" "$trim_actual" "ltrim | rtrim equals trim"
}

# Test piping with trimall
test_trimall_pipeline() {
  local input="  multiple    spaces   here  "
  local expected="multiple spaces here"
  local -- actual
  actual=$(echo "$input" | "$TRIMALL") || fail 'trimall exited non-zero'

  assert_equals "$actual" "$expected" "Using trimall in a pipeline"

  # Compare with trim for leading/trailing spaces
  local -- trim_actual
  trim_actual=$(echo "$input" | "$TRIM") || fail 'trim exited non-zero'
  local expected_trim="multiple    spaces   here"

  assert_equals "$trim_actual" "$expected_trim" "trim versus trimall behavior"
}

# Test complex pipeline with all utilities
test_complex_pipeline() {
  local input="  complex     pipeline   test  "

  # Test different pipelines and compare results
  local -- trim_result ltrim_rtrim_result trimall_result
  trim_result=$(echo "$input" | "$TRIM") || fail 'trim exited non-zero'
  ltrim_rtrim_result=$(echo "$input" | "$LTRIM" | "$RTRIM") || fail 'ltrim | rtrim pipeline exited non-zero'
  trimall_result=$(echo "$input" | "$TRIMALL") || fail 'trimall exited non-zero'

  assert_equals "$trim_result" "$ltrim_rtrim_result" "trim equals ltrim | rtrim"
  assert_equals "$trimall_result" "complex pipeline test" "trimall normalizes all spaces"
}

# Test piping to squeeze
test_pipe_to_squeeze() {
  local input="  hello    from    pipeline  "

  # Use squeeze to collapse multiple spaces while preserving edges
  local -- actual
  actual=$(echo "$input" | "$SQUEEZE") || fail 'squeeze exited non-zero'
  local expected=" hello from pipeline "

  assert_equals "$actual" "$expected" "Piping to squeeze"
}

# Test piping between multiple utilities with a file
test_file_pipeline() {
  local input_file="$FIXTURES_DIR/input/multiline.txt"
  local -- output_file
  output_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'

  # Process with a pipeline of different utilities
  cat -- "$input_file" | "$LTRIM" | "$RTRIM" > "$output_file" \
    || fail 'cat | ltrim | rtrim pipeline exited non-zero'

  local expected_file="$FIXTURES_DIR/expected/multiline_trim.txt"

  assert_file_equals "$output_file" "$expected_file" "Complex pipeline processing with a file"
}

# Run all tests
test_ltrim_to_rtrim
test_trimall_pipeline
test_complex_pipeline
test_pipe_to_squeeze
test_file_pipeline

echo "All pipe integration tests passed!"
exit 0

#fin
