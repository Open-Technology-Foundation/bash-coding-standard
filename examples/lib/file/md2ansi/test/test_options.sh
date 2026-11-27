#!/usr/bin/env bash
# Command-line option tests for md2ansi Bash implementation
# This file is sourced by run_tests

test_section "Command-Line Options"

# --------------------------------------------------------------------------------
# --width option

output=$(echo "This is a very long line that should definitely wrap when we set a narrow width parameter" | ./md2ansi --width 40)
assert_not_empty "$output" "Width 40 produces output"

output=$(echo "Test" | ./md2ansi --width 20)
assert_contains "$output" "Test" "Width 20 (minimum) works"

output=$(echo "Test" | ./md2ansi --width 500)
assert_contains "$output" "Test" "Width 500 (maximum) works"

# Invalid width values should fail (exit code 22 for invalid arguments, 2 for missing arg)
assert_exit_code 22 "./md2ansi --width abc </dev/null 2>&1" "Width 'abc' returns error"
assert_exit_code 22 "./md2ansi --width 10 </dev/null 2>&1" "Width 10 (below minimum) returns error"
assert_exit_code 22 "./md2ansi --width 600 </dev/null 2>&1" "Width 600 (above maximum) returns error"
assert_exit_code 8 "./md2ansi --width -5 </dev/null 2>&1" "Negative width returns exit 8 (noarg catches leading dash)"

# A leading 0 is decimal, as in the Python version (Bash arithmetic would
# reject 08 and read 040 as octal 32)
output=$(echo "Test" | ./md2ansi -D --width 040 2>&1 >/dev/null)
assert_contains "$output" "Terminal width: 40" "Width 040 is read as decimal 40, not octal"
output=$(./md2ansi --width 08 </dev/null 2>&1) ||:
assert_contains "$output" "Width '08' must be between 20 and 500" "Width 08 is decimal 8, below the minimum"
assert_exit_code 22 "./md2ansi --width 08 </dev/null 2>&1" "Width 08 returns exit 22, not a Bash error"
# 2^64+100 would wrap to 100 in Bash arithmetic and pass the range check
assert_exit_code 22 "./md2ansi --width 18446744073709551716 </dev/null 2>&1" "Width that overflows is rejected"

# Attached values, as the Python version (argparse) accepts
output=$(echo "Test" | ./md2ansi -D -w120 2>&1 >/dev/null)
assert_contains "$output" "Terminal width: 120" "-w120 (attached value) sets the width"
output=$(echo "Test" | ./md2ansi -D --width=120 2>&1 >/dev/null)
assert_contains "$output" "Terminal width: 120" "--width=120 sets the width"
output=$(echo "Test" | ./md2ansi -Dw120 2>&1 >/dev/null)
assert_contains "$output" "Terminal width: 120" "-Dw120 (bundled, attached value) sets the width"
assert_exit_code 22 "./md2ansi --width=08 </dev/null 2>&1" "--width=08 is validated like --width 08"
assert_exit_code 22 "./md2ansi --width= </dev/null 2>&1" "--width= (empty value) returns error"
assert_exit_code 22 "./md2ansi --width=-5 </dev/null 2>&1" "--width=-5 is an invalid width, not a missing one"

# --------------------------------------------------------------------------------
# --plain option (disables all formatting features; colors remain)

output=$(echo "# Header **bold** *italic* \`code\`" | ./md2ansi --plain)
assert_contains "$output" "Header" "Plain mode renders text"
assert_contains "$output" "bold" "Plain mode renders bold text"
assert_contains "$output" "italic" "Plain mode renders italic text"
assert_contains "$output" "code" "Plain mode renders code text"

# Note: --plain disables advanced features (footnotes, syntax highlighting, tables, etc.)
# but does not disable basic ANSI color codes. Full no-color mode would require
# detecting non-TTY output or using NO_COLOR environment variable.
# This test verifies --plain at least renders the content correctly.
output=$(echo "# Header **bold**" | ./md2ansi --plain)
assert_contains "$output" "Header" "Plain mode renders header text"
assert_contains "$output" "bold" "Plain mode renders bold text"

# --------------------------------------------------------------------------------
# --no-footnotes option

output=$(echo -e "Text[^1]\n\n[^1]: Footnote" | ./md2ansi --no-footnotes)
assert_contains "$output" "Text" "No-footnotes mode renders text"

# --------------------------------------------------------------------------------
# --no-images option

output=$(echo "![Alt text](image.png)" | ./md2ansi --no-images)
# Should still render but differently when images disabled
assert_not_empty "$output" "No-images mode produces output"

# --------------------------------------------------------------------------------
# --no-links option

output=$(echo "[Link text](http://example.com)" | ./md2ansi --no-links)
assert_contains "$output" "Link text" "No-links mode renders link text"

# --------------------------------------------------------------------------------
# --no-task-lists option

output=$(echo "- [ ] Todo" | ./md2ansi --no-task-lists)
assert_contains "$output" "Todo" "No-task-lists mode renders text"

# --------------------------------------------------------------------------------
# --debug option (debug output goes to stderr)

output=$(echo "# Test" | ./md2ansi --debug 2>&1)
assert_contains "$output" "Test" "Debug mode renders content"

# Check that debug output contains timestamp markers (format: [HH:MM:SS.mmm])
stderr=$(echo "# Test" | ./md2ansi --debug 2>&1 1>/dev/null)
if echo "$stderr" | grep -qE "\[[0-9]{2}:[0-9]{2}:[0-9]{2}"; then
  assert_pass "Debug mode outputs timestamps to stderr"
else
  assert_fail "Debug mode should output timestamps"
fi

# --------------------------------------------------------------------------------
# Combined options

output=$(echo "**bold**" | ./md2ansi --plain --width 80)
assert_contains "$output" "bold" "Combined --plain and --width works"

output=$(echo "- [ ] Task" | ./md2ansi --no-task-lists --no-images)
assert_contains "$output" "Task" "Multiple --no-* flags work together"

# --------------------------------------------------------------------------------
# Invalid/unrecognized options

assert_exit_code 22 "./md2ansi --invalid-option </dev/null 2>&1" "Invalid option returns error"
assert_exit_code 22 "./md2ansi --unknown </dev/null 2>&1" "Unknown option returns error"

#fin
