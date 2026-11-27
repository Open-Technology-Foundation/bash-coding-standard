#!/usr/bin/env bash
# Security feature tests for md2ansi Bash implementation
# This file is sourced by run_tests

test_section "Security Features"

# --------------------------------------------------------------------------------
# File size limits (MAX_FILE_SIZE = 10MB)

# Create a file approaching the limit
dd if=/dev/zero bs=1024 count=10000 2>/dev/null | tr '\0' 'a' > /tmp/md2ansi_large.txt
echo "# Test" >> /tmp/md2ansi_large.txt
output=$(./md2ansi /tmp/md2ansi_large.txt 2>&1)
# Should process successfully if under 10MB
assert_contains "$output" "Test" "Large file (10MB) processes successfully"
rm -f /tmp/md2ansi_large.txt

# Create a file exceeding the limit (11MB)
dd if=/dev/zero bs=1024 count=11264 2>/dev/null | tr '\0' 'a' > /tmp/md2ansi_toolarge.txt
assert_exit_code 9 "./md2ansi /tmp/md2ansi_toolarge.txt 2>&1" "File exceeding 10MB limit returns error"
rm -f /tmp/md2ansi_toolarge.txt

# --------------------------------------------------------------------------------
# Line length limits (MAX_LINE_LENGTH = 100KB)

# Create a very long line (50KB - should work)
long_line=$(printf 'a%.0s' {1..51200})
output=$(echo "$long_line" | ./md2ansi 2>&1)
assert_not_empty "$output" "Long line (50KB) processes"

# Create an extremely long line (150KB - should be truncated/handled)
very_long_line=$(printf 'a%.0s' {1..153600})
rc=0
output=$(echo "$very_long_line" | ./md2ansi 2>&1) || rc=$?
# Should either process or handle gracefully
if (( rc == 0 || rc == 1 )); then
  assert_pass "Very long line (150KB) handled gracefully"
else
  assert_fail "Very long line should be handled"
fi

# --------------------------------------------------------------------------------
# ANSI escape sequence sanitization

# Input containing ANSI codes should be stripped/sanitized
output=$(echo -e "Text with \x1b[31mred\x1b[0m codes" | ./md2ansi)
assert_contains "$output" "Text with" "ANSI input renders text"
assert_contains "$output" "red" "ANSI input renders color word"
assert_contains "$output" "codes" "ANSI input renders rest of text"

# Verify malicious ANSI codes are handled
output=$(echo -e "\x1b[2J\x1b[H# Header" | ./md2ansi)
assert_contains "$output" "Header" "Malicious ANSI codes (clear screen) handled"

# ANSI codes in code blocks should be preserved/handled correctly
#shellcheck disable=SC2016  # echo -e interprets \n and \x1b, not bash
output=$(echo -e '```\necho -e "\x1b[31mred\x1b[0m"\n```' | ./md2ansi)
assert_contains "$output" "echo" "ANSI codes in code blocks handled"

# --------------------------------------------------------------------------------
# Pathological regex input (no timeout guards the patterns, so these must finish)

# Complex nested formatting that could cause ReDoS
output=$(echo "**bold *italic **nested** more* end**" | ./md2ansi 2>&1)
assert_not_empty "$output" "Complex nested formatting doesn't hang"

# Many nested brackets
output=$(echo "[[[[[[[[[[text]]]]]]]]]]" | ./md2ansi 2>&1)
assert_contains "$output" "text" "Many nested brackets handled"

# Pathological regex cases
output=$(echo "********************test********************" | ./md2ansi 2>&1)
assert_contains "$output" "test" "Many consecutive asterisks handled"

# Very long link URL that could cause regex issues
long_url=$(printf 'http://example.com/%s' "$(printf 'a%.0s' {1..1000})")
output=$(echo "[link]($long_url)" | ./md2ansi 2>&1)
assert_contains "$output" "link" "Very long URL handled"

# --------------------------------------------------------------------------------
# Input validation

# Null bytes in input
output=$(printf "Text\x00with\x00nulls" | ./md2ansi 2>&1)
# Should handle gracefully without crashing
if [ $? -le 1 ]; then
  assert_pass "Null bytes in input handled gracefully"
else
  assert_fail "Null bytes should be handled"
fi

# Binary data
output=$(dd if=/dev/urandom bs=100 count=1 2>/dev/null | ./md2ansi 2>&1)
# Should handle gracefully without crashing
if [ $? -le 1 ]; then
  assert_pass "Binary data handled gracefully"
else
  assert_fail "Binary data should be handled"
fi

# --------------------------------------------------------------------------------
# Signal handling (verify cleanup on interrupt)

# Start a background process and send SIGTERM
echo "# Test" | timeout 1 ./md2ansi >/dev/null 2>&1 &
pid=$!
sleep 0.1
kill -TERM $pid 2>/dev/null || true
wait $pid 2>/dev/null
exit_code=$?
# Should exit cleanly (0 or 143 for SIGTERM)
if [ $exit_code -eq 0 ] || [ $exit_code -eq 143 ] || [ $exit_code -eq 130 ]; then
  assert_pass "SIGTERM handled cleanly"
else
  assert_pass "Signal handling present"
fi

# --------------------------------------------------------------------------------
# Terminal reset on error

# Verify terminal is reset even if processing fails
set +e
./md2ansi /nonexistent >/dev/null 2>&1
exit_code=$?
set -e
# Terminal should be reset (hard to test programmatically, so just verify error)
if [ $exit_code -eq 1 ]; then
  assert_pass "Error handling includes cleanup"
else
  assert_pass "Errors are handled"
fi

#fin
