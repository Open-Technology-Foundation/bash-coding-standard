#!/usr/bin/env bash
# Basic markdown feature tests for md2ansi Bash implementation
# This file is sourced by run_tests

test_section "Basic Markdown Features"

# --------------------------------------------------------------------------------
# Headers

output=$(echo "# Header 1" | ./md2ansi)
assert_contains "$output" "Header 1" "H1 header renders"

output=$(echo "## Header 2" | ./md2ansi)
assert_contains "$output" "Header 2" "H2 header renders"

output=$(echo "###### Header 6" | ./md2ansi)
assert_contains "$output" "Header 6" "H6 header renders"

# --------------------------------------------------------------------------------
# Inline formatting

output=$(echo "This is **bold** text" | ./md2ansi)
assert_contains "$output" "bold" "Bold text renders"

output=$(echo "This is *italic* text" | ./md2ansi)
assert_contains "$output" "italic" "Italic text renders"

output=$(echo "This is \`code\` text" | ./md2ansi)
assert_contains "$output" "code" "Inline code renders"

output=$(echo "This is ~~strikethrough~~" | ./md2ansi)
assert_contains "$output" "strikethrough" "Strikethrough renders"

# --------------------------------------------------------------------------------
# Lists

output=$(echo -e "- Item 1\n- Item 2" | ./md2ansi)
assert_contains "$output" "Item 1" "Unordered list item 1"
assert_contains "$output" "Item 2" "Unordered list item 2"

output=$(echo -e "1. First\n2. Second" | ./md2ansi)
assert_contains "$output" "First" "Ordered list item 1"
assert_contains "$output" "Second" "Ordered list item 2"

# --------------------------------------------------------------------------------
# Task lists

output=$(echo "- [ ] Todo item" | ./md2ansi)
assert_contains "$output" "Todo item" "Task list unchecked"

output=$(echo "- [x] Done item" | ./md2ansi)
assert_contains "$output" "Done item" "Task list checked"

# --------------------------------------------------------------------------------
# Links and images

output=$(echo "[Link text](http://example.com)" | ./md2ansi)
assert_contains "$output" "Link text" "Link renders"

output=$(echo "![Alt text](image.png)" | ./md2ansi)
assert_contains "$output" "Alt text" "Image alt text renders"

# --------------------------------------------------------------------------------
# Blockquotes

output=$(echo "> This is a quote" | ./md2ansi)
assert_contains "$output" "This is a quote" "Blockquote renders"

# --------------------------------------------------------------------------------
# Horizontal rules

output=$(echo "---" | ./md2ansi)
assert_not_empty "$output" "Horizontal rule renders"

# --------------------------------------------------------------------------------
# Empty lines and paragraphs

output=$(echo -e "Line 1\n\nLine 2" | ./md2ansi)
assert_contains "$output" "Line 1" "First paragraph"
assert_contains "$output" "Line 2" "Second paragraph"

# --------------------------------------------------------------------------------
# Command-line options

assert_exit_code 0 "./md2ansi --version" "Version flag works"
assert_exit_code 0 "./md2ansi --help" "Help flag works"

output=$(./md2ansi --version)
assert_contains "$output" "1.0.2" "Version string correct"

# --------------------------------------------------------------------------------
# File processing

echo "# Test" > /tmp/md2ansi_test.md
output=$(./md2ansi /tmp/md2ansi_test.md)
assert_contains "$output" "Test" "File processing works"
rm -f /tmp/md2ansi_test.md

# --------------------------------------------------------------------------------
# Nested formatting

output=$(echo "**_bold and italic_**" | ./md2ansi)
assert_contains "$output" "bold and italic" "Bold and italic combined"

output=$(echo "*__italic and bold__*" | ./md2ansi)
assert_contains "$output" "italic and bold" "Italic and bold combined (alt syntax)"

output=$(echo "**bold with *nested italic* inside**" | ./md2ansi)
assert_contains "$output" "nested italic" "Italic nested in bold"

output=$(echo "*italic with **nested bold** inside*" | ./md2ansi)
assert_contains "$output" "nested bold" "Bold nested in italic"

output=$(echo "**bold [link](url) text**" | ./md2ansi)
assert_contains "$output" "link" "Link inside bold"

output=$(echo "*italic \`code\` text*" | ./md2ansi)
assert_contains "$output" "code" "Code inside italic"

output=$(echo "**bold ~~strike~~ text**" | ./md2ansi)
assert_contains "$output" "strike" "Strikethrough inside bold"

# --------------------------------------------------------------------------------
# Error handling

assert_exit_code 3 "./md2ansi /nonexistent/file.md 2>&1" "Non-existent file returns exit 3 (not found)"

#fin
