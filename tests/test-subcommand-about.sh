#!/usr/bin/env bash
# Tests for bcs about subcommand

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Load test helpers
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

SCRIPT="$SCRIPT_DIR"/../bash-coding-standard

test_about_help() {
  test_section "About Help Tests"

  local -- output
  output=$("$SCRIPT" about --help 2>&1)

  assert_contains "$output" "Usage:" "about --help shows usage"
  assert_contains "$output" "bcs about" "Help mentions about command"
  assert_contains "$output" "--stats" "Help shows --stats option"
  assert_contains "$output" "--links" "Help shows --links option"
  assert_contains "$output" "--verbose" "Help shows --verbose option"
  assert_contains "$output" "--json" "Help shows --json option"
}

test_about_basic() {
  test_section "Basic About Output Tests"

  local -- output
  output=$("$SCRIPT" about 2>&1)

  # Should contain key elements
  assert_contains "$output" "Bash Coding Standard" "Output contains title"
  assert_contains "$output" "BCS" "Output contains abbreviation"
  assert_contains "$output" "v1.0.0" "Output contains version"
  assert_contains "$output" "Biksu Okusi" "Output contains author"
  assert_contains "$output" "philosophy" "Output contains philosophy"
  assert_contains "$output" "K.I.S.S." "Output contains coding principles"
  assert_contains "$output" "Okusi Associates" "Output contains developer"
  assert_contains "$output" "YaTTI" "Output contains adopter"
}

test_about_stats() {
  test_section "About Statistics Tests"

  local -- output
  output=$("$SCRIPT" about --stats 2>&1)

  # Should contain statistics
  assert_contains "$output" "Statistics" "Stats output has header"
  assert_contains "$output" "Sections:" "Stats shows sections"
  assert_contains "$output" "Rules:" "Stats shows rules"
  assert_contains "$output" "Standard size:" "Stats shows file size"
  assert_contains "$output" "Test files:" "Stats shows test count"
  assert_contains "$output" "ShellCheck:" "Stats mentions ShellCheck"

  # Check reasonable values
  if [[ "$output" =~ Sections:[[:space:]]*([0-9]+) ]]; then
    local -i sections=${BASH_REMATCH[1]}
    if ((sections >= 10 && sections <= 20)); then
      pass "Section count is reasonable: $sections"
    else
      warn "Section count may be unexpected: $sections"
    fi
  else
    fail "Could not parse section count"
  fi
}

test_about_links() {
  test_section "About Links Tests"

  local -- output
  output=$("$SCRIPT" about --links 2>&1)

  # Should contain links
  assert_contains "$output" "Links" "Links output has header"
  assert_contains "$output" "github.com" "Links include repository"
  assert_contains "$output" "okusiassociates.com" "Links include Okusi"
  assert_contains "$output" "yatti.id" "Links include YaTTI"
  assert_contains "$output" "shellcheck.net" "Links include ShellCheck"
  assert_contains "$output" "google.github.io" "Links include Google Style"
  assert_contains "$output" "CC BY-SA 4.0" "Links include license"
}

test_about_quote() {
  test_section "About Quote Tests"

  local -- output
  output=$("$SCRIPT" about --quote 2>&1)

  # Should contain philosophy and principles
  assert_contains "$output" "philosophy" "Quote output contains philosophy"
  assert_contains "$output" "Biksu Okusi" "Quote output contains author"
  assert_contains "$output" "K.I.S.S." "Quote output contains principles"
  assert_contains "$output" "best process is no process" "Quote contains principle 2"
  assert_contains "$output" "over-engineer" "Quote contains K.I.S.S. note"
}

test_about_json() {
  test_section "About JSON Tests"

  local -- output
  output=$("$SCRIPT" about --json 2>&1)

  # Validate JSON structure
  assert_contains "$output" '"name"' "JSON has name field"
  assert_contains "$output" '"version"' "JSON has version field"
  assert_contains "$output" '"abbreviation"' "JSON has abbreviation field"
  assert_contains "$output" '"BCS"' "JSON contains BCS"
  assert_contains "$output" '"philosophy"' "JSON has philosophy field"
  assert_contains "$output" '"statistics"' "JSON has statistics object"
  assert_contains "$output" '"organizations"' "JSON has organizations object"
  assert_contains "$output" '"repository"' "JSON has repository field"

  # Test if valid JSON (if jq available)
  if command -v jq &>/dev/null; then
    if echo "$output" | jq . >/dev/null 2>&1; then
      pass "JSON output is valid"
    else
      fail "JSON output is invalid"
    fi

    # Extract and validate version
    local -- json_version
    json_version=$(echo "$output" | jq -r '.version')
    if [[ "$json_version" == "1.0.0" ]]; then
      pass "JSON version is correct: $json_version"
    else
      fail "JSON version unexpected: $json_version"
    fi
  else
    warn "jq not available, skipping JSON validation"
  fi
}

test_about_verbose() {
  test_section "About Verbose Tests"

  local -- output
  output=$("$SCRIPT" about --verbose 2>&1)

  # Verbose should include default + stats + links
  assert_contains "$output" "Bash Coding Standard" "Verbose has default content"
  assert_contains "$output" "Statistics" "Verbose includes stats"
  assert_contains "$output" "Links" "Verbose includes links"
  assert_contains "$output" "Sections:" "Verbose has section count"
  assert_contains "$output" "github.com" "Verbose has repository link"

  # Should be longer than default
  local -i default_lines verbose_lines
  default_lines=$("$SCRIPT" about 2>&1 | wc -l)
  verbose_lines=$(echo "$output" | wc -l)

  if ((verbose_lines > default_lines)); then
    pass "Verbose output is longer ($verbose_lines vs $default_lines lines)"
  else
    fail "Verbose output is not longer than default"
  fi
}

test_about_exit_code() {
  test_section "About Exit Code Tests"

  local -i exit_code=0
  "$SCRIPT" about >/dev/null 2>&1 || exit_code=$?

  assert_zero "$exit_code" "about command exits with 0"

  # Test invalid option
  exit_code=0
  "$SCRIPT" about --invalid-option >/dev/null 2>&1 || exit_code=$?
  assert_not_zero "$exit_code" "Invalid option returns non-zero"
}

# Run all tests
test_about_help
test_about_basic
test_about_stats
test_about_links
test_about_quote
test_about_json
test_about_verbose
test_about_exit_code

print_summary

#fin
