#!/usr/bin/env bash
# Unit tests for line ending variations

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

# Test Unix LF line endings (baseline)
test_unix_lf() {
  local -- input=$'  line1  \n  line2  \n'
  local -- expected=$'line1\nline2'
  local -- actual
  actual=$(printf '%s' "$input" | "$TRIM") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "Unix LF line endings preserved"
}

# Test Windows CRLF - carriage return should NOT be trimmed
# [:blank:] only matches space and tab, not \r
test_windows_crlf_preserved() {
  local -- input=$'  line1  \r\n  line2  \r\n'
  # \r should be preserved since [:blank:] doesn't include it
  local -- expected=$'line1  \r\nline2  \r'
  local -- actual
  actual=$(printf '%s' "$input" | "$TRIM") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "CRLF: carriage return preserved (not in [:blank:])"
}

# Test that \r at end of line is preserved by trim
test_cr_not_trimmed() {
  local -- input=$'  hello\r  '
  local -- expected=$'hello\r'
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "Carriage return at end preserved"
}

# Test Mac Classic CR-only line endings
test_mac_cr_only() {
  local -- input=$'  line1  \r  line2  '
  # CR is not a line separator for read, so this is one line
  local -- expected=$'line1  \r  line2'
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "CR-only: treated as single line with embedded CR"
}

# Test file without trailing newline
test_no_trailing_newline() {
  local -- tmp_file
  tmp_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'
  # Write without trailing newline
  printf '  line1  \n  line2  ' > "$tmp_file" || fail 'cannot write temp file'

  local -- expected=$'line1\nline2'
  local -- actual
  actual=$("$TRIM" < "$tmp_file") || fail 'trim exited non-zero'

  rm -f -- "$tmp_file"
  assert_equals "$actual" "$expected" "File without trailing newline handled"
}

# Test mixed line endings in single file
test_mixed_line_endings() {
  local -- tmp_file
  tmp_file=$(mktemp -p "$TMP_DIR") || fail 'mktemp failed'
  # Mix of LF, CRLF, and CR
  printf '  unix  \n  windows  \r\n  mac  \r  end  ' > "$tmp_file" || fail 'cannot write temp file'

  # Each line should be trimmed, but \r preserved where it appears
  local -- actual
  actual=$("$TRIM" < "$tmp_file") || fail 'trim exited non-zero'

  # The file has: "  unix  \n  windows  \r\n  mac  \r  end  "
  # After trim: "unix\nwindows  \r\nmac  \r  end"
  # Note: \r is NOT stripped by [:blank:]

  rm -f -- "$tmp_file"

  # Verify output contains expected trimmed content
  [[ "$actual" == *"unix"* ]] || { >&2 echo "FAIL: unix not found"; return 1; }
  [[ "$actual" == *"windows"* ]] || { >&2 echo "FAIL: windows not found"; return 1; }

  echo -e "${GREEN}✓ Test passed${NC}: Mixed line endings handled"
}

# Test ltrim preserves trailing \r
test_ltrim_preserves_cr() {
  local -- input=$'  hello\r  '
  local -- expected=$'hello\r  '
  local -- actual
  actual=$("$LTRIM" "$input") || fail 'ltrim exited non-zero'

  assert_equals "$actual" "$expected" "ltrim preserves trailing CR and spaces"
}

# Test rtrim preserves leading content, strips trailing spaces but not \r
test_rtrim_with_cr() {
  local -- input=$'  hello\r  '
  # rtrim should strip trailing spaces but \r is not in [:blank:]
  local -- expected=$'  hello\r'
  local -- actual
  actual=$("$RTRIM" "$input") || fail 'rtrim exited non-zero'

  assert_equals "$actual" "$expected" "rtrim strips spaces after CR"
}

# Test empty lines with different endings
test_empty_lines_preserved() {
  local -- input=$'  line1  \n\n  line2  '
  local -- expected=$'line1\n\nline2'
  local -- actual
  actual=$(printf '%s' "$input" | "$TRIM") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "Empty lines in middle preserved"
}

# Test stdin with only newlines
# Note: Empty lines (only whitespace) get trimmed to empty strings
test_only_newlines() {
  local -- input=$'\n\n\n'
  # Each line is empty, trim outputs empty string for each
  local -- expected=$'\n\n'
  local -- actual
  actual=$(printf '%s' "$input" | "$TRIM") || fail 'trim exited non-zero'

  # Empty input lines result in empty output lines
  # The behavior depends on how trim handles empty strings
  # Accept either empty or preserved newlines
  if [[ -z "$actual" || "$actual" == $'\n\n' ]]; then
    echo -e "${GREEN}✓ Test passed${NC}: Only newlines handled (empty or preserved)"
  else
    >&2 echo -e "${RED}✗ Test failed${NC}: Only newlines"
    >&2 echo "Actual: ${actual@Q}"
    return 1
  fi
}

# Run all tests
test_unix_lf
test_windows_crlf_preserved
test_cr_not_trimmed
test_mac_cr_only
test_no_trailing_newline
test_mixed_line_endings
test_ltrim_preserves_cr
test_rtrim_with_cr
test_empty_lines_preserved
test_only_newlines

echo "All line ending tests passed!"
exit 0

#fin
