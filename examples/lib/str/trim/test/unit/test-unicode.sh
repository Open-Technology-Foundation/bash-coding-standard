#!/usr/bin/env bash
# Unit tests for Unicode and special character handling
# Tests UTF-8, emoji, RTL text, zero-width chars, and special whitespace

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

# Utilities
TRIM="$ROOT_DIR/trim.bash"

# Test: Basic emoji preservation
test_emoji_preservation() {
  local input="  👋 Hello 🌍  "
  local expected="👋 Hello 🌍"
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "Emoji characters preserved"
}

# Test: Multi-byte UTF-8 characters
test_multibyte_utf8() {
  # Chinese characters
  local input="  你好世界  "
  local expected="你好世界"
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'
  assert_equals "$actual" "$expected" "Chinese characters preserved"

  # Arabic characters
  input="  مرحبا بالعالم  "
  expected="مرحبا بالعالم"
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'
  assert_equals "$actual" "$expected" "Arabic characters preserved"

  # Japanese characters
  input="  こんにちは世界  "
  expected="こんにちは世界"
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'
  assert_equals "$actual" "$expected" "Japanese characters preserved"
}

# Test: Mixed emoji and text
test_mixed_emoji_text() {
  local input=$'  🎉 Celebration time! 🎊 \t '
  local expected=$'🎉 Celebration time! 🎊'
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "Mixed emoji and text"
}

# Test: Zero-width characters (current behavior)
test_zero_width_chars() {
  # Zero-width space (U+200B)
  local input=$'hello\u200Bworld'
  local expected=$'hello\u200Bworld'
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "Zero-width space preserved (not trimmed)"

  # Note: [:blank:] only matches space and tab, not Unicode whitespace
}

# Test: Non-breaking space (current behavior)
test_non_breaking_space() {
  # Non-breaking space (U+00A0)
  local input=$'\u00A0hello\u00A0'
  local expected=$'\u00A0hello\u00A0'
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'

  # Current behavior: [:blank:] doesn't match non-breaking space
  assert_equals "$actual" "$expected" "Non-breaking space preserved (not trimmed by [:blank:])"
}

# Test: Combining characters
test_combining_characters() {
  # é (e + combining acute accent)
  local input="  e\u0301  "
  local expected="e\u0301"
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "Combining characters preserved"
}

# Test: Emoji with skin tone modifiers
test_emoji_modifiers() {
  # Thumbs up with skin tone modifier
  local input=$'  👍🏽  '
  local expected=$'👍🏽'
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "Emoji with skin tone modifiers"
}

# Test: Right-to-left text
test_rtl_text() {
  # Hebrew
  local input="  שלום עולם  "
  local expected="שלום עולם"
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "Hebrew (RTL) text preserved"
}

# Test: Mixed LTR and RTL
test_mixed_ltr_rtl() {
  local input="  Hello שלום World  "
  local expected="Hello שלום World"
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "Mixed LTR/RTL text"
}

# Test: Unicode mathematical symbols
test_mathematical_symbols() {
  local input="  ∑ ∫ ∂ ∇  "
  local expected="∑ ∫ ∂ ∇"
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "Mathematical symbols preserved"
}

# Test: Box-drawing characters
test_box_drawing() {
  local input="  ┌─┐ │ │ └─┘  "
  local expected="┌─┐ │ │ └─┘"
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "Box-drawing characters"
}

# Test: Emoji sequences (multi-codepoint emoji)
test_emoji_sequences() {
  # Family emoji (multiple codepoints)
  local input=$'  👨‍👩‍👧‍👦  '
  local expected=$'👨‍👩‍👧‍👦'
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "Multi-codepoint emoji sequences"
}

# Test: Special punctuation
test_special_punctuation() {
  local input="  Hello 'World'  "
  local expected="Hello 'World'"
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "Unicode quotation marks"
}

# Test: Currency symbols
#shellcheck disable=SC2016  # $100 is literal currency test data, not an expansion
test_currency_symbols() {
  local input='  $100 €50 ¥1000 £75  '
  local expected='$100 €50 ¥1000 £75'
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "Currency symbols preserved"
}

# Test: Diacritics
test_diacritics() {
  local input="  café naïve résumé  "
  local expected="café naïve résumé"
  local -- actual
  actual=$("$TRIM" "$input") || fail 'trim exited non-zero'

  assert_equals "$actual" "$expected" "Diacritical marks preserved"
}

# Run all tests
>&2 echo "Testing Unicode and special character handling..."
echo ""

test_emoji_preservation
test_multibyte_utf8
test_mixed_emoji_text
test_zero_width_chars
test_non_breaking_space
test_combining_characters
test_emoji_modifiers
test_rtl_text
test_mixed_ltr_rtl
test_mathematical_symbols
test_box_drawing
test_emoji_sequences
test_special_punctuation
test_currency_symbols
test_diacritics

echo ""
echo "All Unicode tests passed!"
echo ""
echo "Note: Current implementation uses [:blank:] which only matches ASCII space/tab."
echo "Unicode whitespace characters (like U+00A0, U+2000-U+200A) are not trimmed."
echo "This is expected behavior for ASCII-focused trimming."
exit 0

#fin
