#!/usr/bin/env bash
# Tests for bcs decode subcommand

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Load test helpers
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

SCRIPT="$SCRIPT_DIR"/../bash-coding-standard

test_decode_help() {
  test_section "Decode Help Tests"

  local -- output
  output=$("$SCRIPT" decode --help 2>&1)

  assert_contains "$output" "Usage:" "decode --help shows usage"
  assert_contains "$output" "bcs decode" "Help mentions decode command"
  assert_contains "$output" "BCS" "Help mentions BCS codes"
  assert_contains "$output" "-a" "Help shows -a option"
  assert_contains "$output" "-s" "Help shows -s option"
  assert_contains "$output" "-c" "Help shows -c option"
  assert_contains "$output" "--all" "Help shows --all option"
  assert_contains "$output" "--relative" "Help shows --relative option"
  assert_contains "$output" "--basename" "Help shows --basename option"
  assert_contains "$output" "--exists" "Help shows --exists option"
}

test_decode_basic() {
  test_section "Basic Decode Tests"

  # Test with a known BCS code (dual-purpose scripts - BCS010201)
  local -- output
  output=$("$SCRIPT" decode BCS010201 2>&1)

  # Should return a file path (default tier determined by BASH-CODING-STANDARD.md symlink)
  assert_contains "$output" "data/" "Output contains data/ directory"
  assert_contains "$output" ".abstract.md" "Output contains abstract tier file (default from symlink)"
  assert_contains "$output" "01-script-structure" "Output contains correct section"
  assert_contains "$output" "02-shebang" "Output contains correct rule"
  assert_contains "$output" "01-dual-purpose" "Output contains correct subrule"
}

test_decode_without_prefix() {
  test_section "Decode Without BCS Prefix Tests"

  # Test without BCS prefix
  local -- output1 output2
  output1=$("$SCRIPT" decode BCS010201 2>&1)
  output2=$("$SCRIPT" decode 010201 2>&1)

  # Should produce same result
  assert_equals "$output1" "$output2" "decode works with or without BCS prefix"
}

test_decode_tiers() {
  test_section "Decode Tier Tests"

  # Test different tiers
  local -- output_complete output_abstract output_summary

  output_complete=$("$SCRIPT" decode BCS0102 -c 2>&1)
  output_abstract=$("$SCRIPT" decode BCS0102 -a 2>&1)
  output_summary=$("$SCRIPT" decode BCS0102 -s 2>&1)

  # All should contain valid paths but different tiers
  assert_contains "$output_complete" ".complete.md" "Complete tier has .complete.md"
  assert_contains "$output_abstract" ".abstract.md" "Abstract tier has .abstract.md"
  assert_contains "$output_summary" ".summary.md" "Summary tier has .summary.md"

  # All should have same base path structure
  assert_contains "$output_complete" "02-shebang.complete.md" "Complete has correct filename"
  assert_contains "$output_abstract" "02-shebang.abstract.md" "Abstract has correct filename"
  assert_contains "$output_summary" "02-shebang.summary.md" "Summary has correct filename"
}

test_decode_all_tiers() {
  test_section "Decode All Tiers Tests"

  local -- output
  output=$("$SCRIPT" decode BCS0102 --all 2>&1)

  # Should show all three tiers
  assert_contains "$output" "Complete" "Shows complete tier label"
  assert_contains "$output" "Abstract" "Shows abstract tier label"
  assert_contains "$output" "Summary" "Shows summary tier label"

  # Should contain all three file extensions
  assert_contains "$output" ".complete.md" "Shows complete file"
  assert_contains "$output" ".abstract.md" "Shows abstract file"
  assert_contains "$output" ".summary.md" "Shows summary file"

  # Count output lines (should be 3 for three tiers)
  local -i line_count
  line_count=$(echo "$output" | wc -l)
  if ((line_count == 3)); then
    pass "All three tiers shown (3 lines)"
  else
    fail "Expected 3 lines for three tiers, got $line_count"
  fi
}

test_decode_relative() {
  test_section "Decode Relative Path Tests"

  local -- output
  output=$("$SCRIPT" decode BCS0102 --relative 2>&1)

  # Should start with data/ (relative to repo root)
  assert_contains "$output" "data/" "Relative path contains data/"

  # Should NOT contain absolute path marker
  if [[ "$output" =~ ^/ ]]; then
    fail "Relative path should not start with /"
  else
    pass "Relative path does not start with /"
  fi
}

test_decode_basename() {
  test_section "Decode Basename Tests"

  local -- output
  output=$("$SCRIPT" decode BCS0102 --basename 2>&1)

  # Should only contain filename, no directory path
  if [[ "$output" =~ / ]]; then
    fail "Basename should not contain directory separator"
  else
    pass "Basename contains no directory separator"
  fi

  # Should still have the correct filename (default tier determined by symlink)
  assert_equals "$output" "02-shebang.abstract.md" "Basename shows correct filename (abstract tier from symlink)"
}

test_decode_exists() {
  test_section "Decode Exists Tests"

  local -i exit_code=0
  local -- output

  # Test with valid code (should succeed silently)
  output=$("$SCRIPT" decode BCS0102 --exists 2>&1) || exit_code=$?
  assert_zero "$exit_code" "Valid code with --exists returns 0"
  assert_equals "$output" "" "No output with --exists for valid code"

  # Test with invalid code (should fail silently)
  exit_code=0
  output=$("$SCRIPT" decode BCS9999 --exists 2>&1) || exit_code=$?
  assert_not_zero "$exit_code" "Invalid code with --exists returns non-zero"
  assert_equals "$output" "" "No output with --exists for invalid code"
}

test_decode_exists_all() {
  test_section "Decode Exists All Tiers Tests"

  local -i exit_code=0

  # Test --all with --exists (should succeed if any tier exists)
  "$SCRIPT" decode BCS0102 --all --exists 2>&1 || exit_code=$?
  assert_zero "$exit_code" "Valid code with --all --exists returns 0"

  # Test invalid code with --all --exists
  exit_code=0
  "$SCRIPT" decode BCS9999 --all --exists 2>&1 || exit_code=$?
  assert_not_zero "$exit_code" "Invalid code with --all --exists returns non-zero"
}

test_decode_section_code() {
  test_section "Decode Section Code Tests"

  # Test with section-level code (BCS0100)
  local -- output
  output=$("$SCRIPT" decode BCS0100 2>&1)

  # Should decode to section file (default tier determined by symlink)
  assert_contains "$output" "00-section.abstract.md" "Section code decodes to section file (abstract tier from symlink)"
  assert_contains "$output" "01-script-structure" "Contains correct section directory"
}

test_decode_subrule_code() {
  test_section "Decode Subrule Code Tests"

  # Test with subrule code (BCS010201 - dual-purpose scripts)
  local -- output
  output=$("$SCRIPT" decode BCS010201 2>&1)

  # Should decode to subrule file (default tier determined by symlink)
  assert_contains "$output" "01-dual-purpose.abstract.md" "Subrule code decodes to subrule file (abstract tier from symlink)"
  assert_contains "$output" "02-shebang" "Contains rule directory"
}

test_decode_invalid_code() {
  test_section "Decode Invalid Code Tests"

  local -- output
  local -i exit_code=0
  output=$("$SCRIPT" decode BCS9999 2>&1) || exit_code=$?

  # Should return error for non-existent code
  assert_not_zero "$exit_code" "Invalid code returns error"
  assert_contains "$output" "✗" "Error message for invalid code"
  assert_contains "$output" "not found" "Error indicates code not found"
}

test_decode_missing_code() {
  test_section "Decode Missing Code Tests"

  local -- output
  local -i exit_code=0
  output=$("$SCRIPT" decode 2>&1) || exit_code=$?

  # Should return error when no code specified
  assert_not_zero "$exit_code" "Missing code returns error"
  assert_contains "$output" "✗" "Error message when code missing"
}


test_decode_combination_all_relative() {
  test_section "Decode Combination Tests: --all --relative"

  local -- output
  output=$("$SCRIPT" decode BCS0102 --all --relative 2>&1)

  # Should show all three tiers with relative paths
  assert_contains "$output" "Complete" "Shows complete tier label"
  assert_contains "$output" "Abstract" "Shows abstract tier label"
  assert_contains "$output" "Summary" "Shows summary tier label"

  # All paths should be relative (start with data/)
  local -i relative_count
  relative_count=$(echo "$output" | grep -c "data/" || true)
  if ((relative_count == 3)); then
    pass "All three paths are relative (contain data/)"
  else
    fail "Expected 3 relative paths, got $relative_count"
  fi
}

test_decode_combination_all_basename() {
  test_section "Decode Combination Tests: --all --basename"

  local -- output
  output=$("$SCRIPT" decode BCS0102 --all --basename 2>&1)

  # Should show all three tiers with basenames only
  assert_contains "$output" "Complete" "Shows complete tier label"
  assert_contains "$output" "02-shebang.complete.md" "Shows complete basename"
  assert_contains "$output" "02-shebang.abstract.md" "Shows abstract basename"
  assert_contains "$output" "02-shebang.summary.md" "Shows summary basename"
}

test_decode_print_basic() {
  test_section "Decode Print Basic Tests"

  local -- output
  output=$("$SCRIPT" decode BCS0102 -p 2>&1)

  # Should contain actual file content, not file path
  assert_contains "$output" "Shebang" "Print output contains rule content"
  assert_contains "$output" "#!/bin/bash" "Print output contains code examples"
  assert_contains "$output" "set -euo pipefail" "Print output contains bash commands"

  # Should NOT contain file path
  if [[ "$output" =~ data/ ]]; then
    fail "Print mode should not output file path"
  else
    pass "Print mode outputs content, not path"
  fi
}

test_decode_print_tiers() {
  test_section "Decode Print Tier Tests"

  # Test different tiers
  local -- output_complete output_abstract output_summary

  output_complete=$("$SCRIPT" decode BCS0102 -c -p 2>&1)
  output_abstract=$("$SCRIPT" decode BCS0102 -a -p 2>&1)
  output_summary=$("$SCRIPT" decode BCS0102 -s -p 2>&1)

  # All should contain content (not paths)
  assert_contains "$output_complete" "Shebang" "Complete tier print contains content"
  assert_contains "$output_abstract" "Shebang" "Abstract tier print contains content"
  assert_contains "$output_summary" "Shebang" "Summary tier print contains content"

  # All tiers should have substantial content
  local -i complete_lines abstract_lines summary_lines
  complete_lines=$(echo "$output_complete" | wc -l)
  abstract_lines=$(echo "$output_abstract" | wc -l)
  summary_lines=$(echo "$output_summary" | wc -l)

  if ((complete_lines > 10 && abstract_lines > 10 && summary_lines > 10)); then
    pass "All tiers contain substantial content (>10 lines each)"
  else
    fail "Expected all tiers to have >10 lines (complete:$complete_lines, abstract:$abstract_lines, summary:$summary_lines)"
  fi
}

test_decode_print_all() {
  test_section "Decode Print All Tiers Tests"

  local -- output
  output=$("$SCRIPT" decode BCS0102 --all -p 2>&1)

  # Should contain tier headers
  assert_contains "$output" "Complete tier" "Shows complete tier header"
  assert_contains "$output" "Abstract tier" "Shows abstract tier header"
  assert_contains "$output" "Summary tier" "Shows summary tier header"

  # Should contain separators between tiers
  assert_contains "$output" "---" "Contains tier separators"

  # Should contain actual content
  assert_contains "$output" "Shebang" "Contains rule content"
  assert_contains "$output" "#!/bin/bash" "Contains code examples"

  # Count tier headers (should be 3)
  local -i tier_count
  tier_count=$(echo "$output" | grep -c "tier (BCS" || true)
  if ((tier_count == 3)); then
    pass "All three tier headers present"
  else
    fail "Expected 3 tier headers, got $tier_count"
  fi
}

test_decode_print_subrule() {
  test_section "Decode Print Subrule Tests"

  local -- output
  output=$("$SCRIPT" decode BCS010201 --print 2>&1)

  # Should contain subrule-specific content
  assert_contains "$output" "Dual-Purpose" "Print contains subrule title"
  assert_contains "$output" "sourced" "Print contains subrule content"
}

test_decode_print_with_pipe() {
  test_section "Decode Print Pipe Tests"

  # Test that print output can be piped
  local -- output
  output=$("$SCRIPT" decode BCS0102 -p 2>&1 | head -5)

  # Should still contain content
  assert_contains "$output" "Shebang" "Piped print output works"

  # Test word count works
  local -i word_count
  word_count=$("$SCRIPT" decode BCS0102 -p 2>&1 | wc -w)

  if ((word_count > 50)); then
    pass "Print output contains substantial content ($word_count words)"
  else
    fail "Expected >50 words, got $word_count"
  fi
}

# Run all tests
test_decode_help
test_decode_basic
test_decode_without_prefix
test_decode_tiers
test_decode_all_tiers
test_decode_relative
test_decode_basename
test_decode_exists
test_decode_exists_all
test_decode_section_code
test_decode_subrule_code
test_decode_invalid_code
test_decode_missing_code
test_decode_combination_all_relative
test_decode_combination_all_basename
test_decode_print_basic
test_decode_print_tiers
test_decode_print_all
test_decode_print_subrule
test_decode_print_with_pipe

print_summary

#fin
