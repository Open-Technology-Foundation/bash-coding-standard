#!/usr/bin/env bash
# Tests for bcs generate subcommand

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Load test helpers
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

SCRIPT="$SCRIPT_DIR"/../bash-coding-standard

test_generate_help() {
  test_section "Generate Help Tests"

  local -- output
  output=$("$SCRIPT" generate --help 2>&1)

  assert_contains "$output" "Usage:" "generate --help shows usage"
  assert_contains "$output" "bcs generate" "Help mentions generate command"
  assert_contains "$output" "-t" "Help shows -t option"
  assert_contains "$output" "-o" "Help shows -o option"
  assert_contains "$output" "stdout" "Help mentions stdout option"
}

test_generate_stdout_complete() {
  test_section "Generate Stdout Complete Tests"

  local -- output
  output=$("$SCRIPT" generate 2>&1 | head -20 || true)

  # Should produce markdown output
  assert_contains "$output" "# Bash Coding Standard" "Output contains title"
  assert_contains "$output" "## " "Output contains section headers"
}

test_generate_stdout_abstract() {
  test_section "Generate Stdout Abstract Tests"

  local -- output
  output=$("$SCRIPT" generate -t abstract 2>&1 | head -20 || true)

  # Should produce abstract markdown
  assert_contains "$output" "# Bash Coding Standard" "Abstract output contains title"

  # Abstract version should be shorter
  local -i complete_lines abstract_lines
  complete_lines=$("$SCRIPT" generate 2>&1 | wc -l)
  abstract_lines=$("$SCRIPT" generate -t abstract 2>&1 | wc -l)

  if ((abstract_lines < complete_lines)); then
    pass "Abstract version is shorter ($abstract_lines vs $complete_lines lines)"
  else
    fail "Abstract version is not shorter ($abstract_lines vs $complete_lines lines)"
  fi
}

test_generate_stdout_summary() {
  test_section "Generate Stdout Summary Tests"

  local -- output
  output=$("$SCRIPT" generate -t summary 2>&1 | head -20 || true)

  # Should produce summary markdown
  assert_contains "$output" "# Bash Coding Standard" "Summary output contains title"

  # Summary should be between abstract and complete
  local -i complete_lines summary_lines abstract_lines
  complete_lines=$("$SCRIPT" generate 2>&1 | wc -l)
  summary_lines=$("$SCRIPT" generate -t summary 2>&1 | wc -l)
  abstract_lines=$("$SCRIPT" generate -t abstract 2>&1 | wc -l)

  if ((summary_lines > abstract_lines && summary_lines < complete_lines)); then
    pass "Summary version is medium-sized ($summary_lines lines)"
  else
    warn "Summary size may not be between abstract and complete"
  fi
}

test_generate_output_file() {
  test_section "Generate Output File Tests"

  local -- tmpfile
  tmpfile=$(mktemp)
  trap 'rm -f "$tmpfile"' RETURN

  # Generate to file
  "$SCRIPT" generate -o "$tmpfile" 2>&1 >/dev/null

  # File should exist and have content
  if [[ -f "$tmpfile" && -s "$tmpfile" ]]; then
    pass "Output file created with content"

    # Check content
    local -- content
    content=$(head -5 "$tmpfile" || true)
    assert_contains "$content" "# Bash Coding Standard" "File contains title"
  else
    fail "Output file not created or empty"
  fi
}

test_generate_invalid_tier() {
  test_section "Generate Invalid Tier Tests"

  local -- output
  output=$("$SCRIPT" generate -t invalid 2>&1) || true

  # Should produce error message
  assert_contains "$output" "error" "Invalid tier produces error"
}

test_generate_alias() {
  test_section "Generate Alias Tests"

  # Test regen alias
  local -- output1 output2
  output1=$("$SCRIPT" generate 2>&1 | head -10 || true)
  output2=$("$SCRIPT" regen 2>&1 | head -10 || true)

  assert_equals "$output1" "$output2" "generate and regen produce same output"
}

# Run all tests
test_generate_help
test_generate_stdout_complete
test_generate_stdout_abstract
test_generate_stdout_summary
test_generate_output_file
test_generate_invalid_tier
test_generate_alias

print_summary

#fin
