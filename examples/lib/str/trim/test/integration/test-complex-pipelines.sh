#!/usr/bin/env bash
# Integration tests for complex pipeline scenarios

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

TRIM="$ROOT_DIR/trim.bash"
LTRIM="$ROOT_DIR/ltrim.bash"
RTRIM="$ROOT_DIR/rtrim.bash"
SQUEEZE="$ROOT_DIR/squeeze.bash"

# Verify utilities exist
for util in "$TRIM" "$LTRIM" "$RTRIM" "$SQUEEZE"; do
  [[ -x "$util" ]] || { >&2 echo "${0##*/}: ✗ ${util@Q} not found or not executable"; exit 1; }
done

>&2 echo "Testing complex pipeline scenarios..."

declare -i passed=0 failed=0

# Test 4-stage pipeline
test_four_stage_pipeline() {
  local -- input result expected
  input=$'  c  \n  a  \n  b  \n  a  '
  expected=$'a\nb\nc'

  result=$(echo "$input" | "$TRIM" | sort | uniq) || fail 'trim|sort|uniq pipeline exited non-zero'

  if [[ "$result" == "$expected" ]]; then
    echo -e "${GREEN}Test passed${NC}: 4-stage pipeline (trim|sort|uniq)"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: 4-stage pipeline"
    ((++failed))
  fi
}

# Test here-string with trim
test_here_string() {
  local -- result
  result=$("$TRIM" <<< "  hello world  ") || fail 'trim exited non-zero on here-string input'

  if [[ "$result" == "hello world" ]]; then
    echo -e "${GREEN}Test passed${NC}: Here-string input"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: Here-string input (got: $result)"
    ((++failed))
  fi
}

# Test here-doc with trim
test_here_doc() {
  local -- result expected
  expected=$'line1\nline2\nline3'

  result=$("$TRIM" <<EOF
  line1
  line2
  line3
EOF
) || fail 'trim exited non-zero on here-doc input'

  if [[ "$result" == "$expected" ]]; then
    echo -e "${GREEN}Test passed${NC}: Here-doc input"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: Here-doc input"
    ((++failed))
  fi
}

# Test process substitution
test_process_substitution() {
  local -- result
  result=$(cat <("$TRIM" "  process sub  "); wait "$!") || fail 'trim in a process substitution exited non-zero'

  if [[ "$result" == "process sub" ]]; then
    echo -e "${GREEN}Test passed${NC}: Process substitution"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: Process substitution (got: $result)"
    ((++failed))
  fi
}

# Test nested command substitution
test_nested_substitution() {
  local -- result
  result=$("$TRIM" "$("$TRIM" "    nested    ")") || fail 'nested trim exited non-zero'

  if [[ "$result" == "nested" ]]; then
    echo -e "${GREEN}Test passed${NC}: Nested command substitution"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: Nested command substitution (got: $result)"
    ((++failed))
  fi
}

# Test chained trim operations
test_chained_trims() {
  local -- result
  result=$(echo "  chained  " | "$LTRIM" | "$RTRIM") || fail 'ltrim|rtrim pipeline exited non-zero'

  if [[ "$result" == "chained" ]]; then
    echo -e "${GREEN}Test passed${NC}: Chained ltrim|rtrim"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: Chained ltrim|rtrim (got: $result)"
    ((++failed))
  fi
}

# Test with external tools (grep)
test_with_grep() {
  local -- input result expected
  input=$'  keep  \n  remove  \n  keep  '
  expected=$'keep\nkeep'

  result=$(echo "$input" | "$TRIM" | grep "keep") || fail 'trim|grep pipeline exited non-zero'

  if [[ "$result" == "$expected" ]]; then
    echo -e "${GREEN}Test passed${NC}: Pipeline with grep"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: Pipeline with grep"
    ((++failed))
  fi
}

# Test with wc (word count)
test_with_wc() {
  local -- input line_count
  input=$'  one  \n  two  \n  three  '

  line_count=$(echo "$input" | "$TRIM" | wc -l) || fail 'trim|wc pipeline exited non-zero'
  [[ $line_count =~ ^[0-9]+$ ]] || fail "wc -l gave non-integer ${line_count@Q}"

  if ((line_count == 3)); then
    echo -e "${GREEN}Test passed${NC}: Pipeline with wc"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: Pipeline with wc (got: $line_count lines)"
    ((++failed))
  fi
}

# Test squeeze then trim
test_squeeze_then_trim() {
  local -- result
  result=$(echo "  multiple    spaces  " | "$SQUEEZE" | "$TRIM") || fail 'squeeze|trim pipeline exited non-zero'

  if [[ "$result" == "multiple spaces" ]]; then
    echo -e "${GREEN}Test passed${NC}: squeeze|trim pipeline"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: squeeze|trim (got: $result)"
    ((++failed))
  fi
}

# Test subshell preservation
test_subshell() {
  local -- result
  result=$( (echo "  subshell  " | "$TRIM") ) || fail 'trim in a subshell exited non-zero'

  if [[ "$result" == "subshell" ]]; then
    echo -e "${GREEN}Test passed${NC}: Subshell execution"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: Subshell execution (got: $result)"
    ((++failed))
  fi
}

# Run all tests
test_four_stage_pipeline
test_here_string
test_here_doc
test_process_substitution
test_nested_substitution
test_chained_trims
test_with_grep
test_with_wc
test_squeeze_then_trim
test_subshell

echo
echo "=== Summary: $passed passed, $failed failed ==="

if ((failed == 0)); then
  echo "All complex pipeline tests passed!"
  exit 0
else
  >&2 echo "Complex pipeline tests FAILED"
  exit 1
fi

#fin
