#!/usr/bin/env bash
# Stress tests for large input handling

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

# Verify utilities exist
for util in "$TRIM" "$LTRIM" "$RTRIM"; do
  [[ -x "$util" ]] || { >&2 echo "${0##*/}: ✗ ${util@Q} not found or not executable"; exit 1; }
done

>&2 echo "Testing stress: large input handling..."

declare -i passed=0 failed=0

# Test very long single line (100K chars)
test_long_line() {
  local -- description="Very long line (100K chars)"
  local -- padding content result

  # Create 1000 space padding and 98K char content
  padding=$(printf '%*s' 1000 '')
  content=$(head -c 98000 < /dev/zero | tr '\0' 'x') || fail 'cannot build 98K content'

  result=$("$TRIM" "${padding}${content}${padding}") || fail 'trim exited non-zero'

  if ((${#result} == 98000)); then
    echo -e "${GREEN}Test passed${NC}: $description"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: $description (got ${#result} chars)"
    ((++failed))
  fi
}

# Test file with many lines (10K lines)
test_many_lines() {
  local -- description="Many lines (10K lines)"
  local -- tmp_file line_count
  local -i i
  tmp_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'

  # Create 10K lines with whitespace padding
  for ((i=0; i<10000; i++)); do
    echo "  line$i  "
  done > "$tmp_file" || fail 'cannot write temp file'

  line_count=$("$TRIM" < "$tmp_file" | wc -l) || fail 'trim exited non-zero'
  [[ $line_count =~ ^[0-9]+$ ]] || fail "wc -l gave non-integer ${line_count@Q}"

  rm -f -- "$tmp_file"

  if ((line_count == 10000)); then
    echo -e "${GREEN}Test passed${NC}: $description"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: $description (got $line_count lines)"
    ((++failed))
  fi
}

# Test whitespace-only input (100K spaces)
test_whitespace_only() {
  local -- description="Whitespace-only (100K spaces)"
  local -- input result

  input=$(printf '%*s' 100000 '')
  result=$("$TRIM" "$input") || fail 'trim exited non-zero'

  if [[ -z "$result" ]]; then
    echo -e "${GREEN}Test passed${NC}: $description"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: $description (result not empty)"
    ((++failed))
  fi
}

# Test mixed whitespace large input
test_mixed_whitespace_large() {
  local -- description="Mixed whitespace large (50K)"
  local -- input result expected

  # Create pattern: spaces, content, tabs, content, spaces
  input=$(printf '%*s' 10000 '')
  input+="content"
  input+=$(printf '\t%.0s' {1..10000})
  input+="more"
  input+=$(printf '%*s' 10000 '')

  result=$("$TRIM" "$input") || fail 'trim exited non-zero'

  # Expected: content + squeezed tabs + more
  # Note: trim only removes leading/trailing, not internal
  if [[ "$result" == "content"*"more" ]]; then
    echo -e "${GREEN}Test passed${NC}: $description"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: $description"
    ((++failed))
  fi
}

# Test stdin performance with large input
test_stdin_large() {
  local -- description="Large stdin (1000 lines x 1000 chars)"
  local -- tmp_file result_lines
  local -i i
  tmp_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'

  # Create 1000 lines of 1000 chars each
  local -- line_content
  line_content=$(printf '%*s' 500 '')
  line_content+="content"
  line_content+=$(printf '%*s' 493 '')

  for ((i=0; i<1000; i++)); do
    echo "$line_content"
  done > "$tmp_file" || fail 'cannot write temp file'

  result_lines=$("$TRIM" < "$tmp_file" | wc -l) || fail 'trim exited non-zero'
  [[ $result_lines =~ ^[0-9]+$ ]] || fail "wc -l gave non-integer ${result_lines@Q}"

  rm -f -- "$tmp_file"

  if ((result_lines == 1000)); then
    echo -e "${GREEN}Test passed${NC}: $description"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: $description (got $result_lines lines)"
    ((++failed))
  fi
}

# Test ltrim with large leading whitespace
test_ltrim_large_leading() {
  local -- description="ltrim large leading (50K spaces)"
  local -- input result

  input=$(printf '%*s' 50000 '')
  input+="content"

  result=$("$LTRIM" "$input") || fail 'ltrim exited non-zero'

  if [[ "$result" == "content" ]]; then
    echo -e "${GREEN}Test passed${NC}: $description"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: $description"
    ((++failed))
  fi
}

# Test rtrim with large trailing whitespace
test_rtrim_large_trailing() {
  local -- description="rtrim large trailing (50K spaces)"
  local -- input result

  input="content"
  input+=$(printf '%*s' 50000 '')

  result=$("$RTRIM" "$input") || fail 'rtrim exited non-zero'

  if [[ "$result" == "content" ]]; then
    echo -e "${GREEN}Test passed${NC}: $description"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: $description"
    ((++failed))
  fi
}

# Test that no timeout on reasonable large input
test_no_timeout() {
  local -- description="No timeout on large input (5s limit)"
  local -- tmp_file start_time end_time duration
  local -i i
  tmp_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'

  # Create reasonably large file (5000 lines)
  for ((i=0; i<5000; i++)); do
    echo "    line $i with some content    "
  done > "$tmp_file" || fail 'cannot write temp file'

  printf -v start_time '%(%s)T' -1
  "$TRIM" < "$tmp_file" > /dev/null || fail 'trim exited non-zero'
  printf -v end_time '%(%s)T' -1
  duration=$((end_time - start_time))

  rm -f -- "$tmp_file"

  if ((duration < 5)); then
    echo -e "${GREEN}Test passed${NC}: $description (${duration}s)"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: $description (took ${duration}s)"
    ((++failed))
  fi
}

# Run all stress tests
test_long_line
test_many_lines
test_whitespace_only
test_mixed_whitespace_large
test_stdin_large
test_ltrim_large_leading
test_rtrim_large_trailing
test_no_timeout

echo
echo "=== Summary: $passed passed, $failed failed ==="

if ((failed == 0)); then
  echo "All stress tests passed!"
  exit 0
else
  >&2 echo "Stress tests FAILED"
  exit 1
fi

#fin
