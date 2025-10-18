#!/usr/bin/env bash
# Tests for bcs subcommand dispatcher and command routing

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Load test helpers
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

SCRIPT="$SCRIPT_DIR"/../bash-coding-standard

test_dispatcher_help() {
  test_section "Dispatcher Help Tests"

  local -- output
  output=$("$SCRIPT" help 2>&1)

  assert_contains "$output" "Commands:" "help shows available commands"
  assert_contains "$output" "display" "help lists display command"
  assert_contains "$output" "codes" "help lists codes command"
  assert_contains "$output" "generate" "help lists generate command"
  assert_contains "$output" "search" "help lists search command"
  assert_contains "$output" "decode" "help lists decode command"
  assert_contains "$output" "sections" "help lists sections command"
  assert_contains "$output" "compress" "help lists compress command"
}

test_dispatcher_no_args_defaults_to_display() {
  test_section "No Args Defaults to Display Tests"

  local -- output
  output=$("$SCRIPT" 2>&1 | head -10 || true)

  # Should display the standard (like display command)
  assert_contains "$output" "# Bash Coding Standard" "No args displays the standard"
}

test_dispatcher_backward_compat_dash_options() {
  test_section "Backward Compatibility Tests"

  # Test that -c still works (legacy cat option)
  local -- output1 output2
  output1=$("$SCRIPT" -c 2>&1 | head -5 || true)
  output2=$("$SCRIPT" display -c 2>&1 | head -5 || true)

  assert_equals "$output1" "$output2" "-c works (backward compatible)"

  # Test that --json still works
  output1=$("$SCRIPT" --json 2>&1 | head -3 || true)
  output2=$("$SCRIPT" display --json 2>&1 | head -3 || true)

  assert_equals "$output1" "$output2" "--json works (backward compatible)"
}

test_dispatcher_subcommand_routing() {
  test_section "Subcommand Routing Tests"

  # Test that each subcommand routes correctly
  local -- output

  # Test display
  output=$("$SCRIPT" display 2>&1 | head -5 || true)
  assert_contains "$output" "# Bash Coding Standard" "display command works"

  # Test codes
  output=$("$SCRIPT" codes 2>&1 | head -1 || true)
  assert_contains "$output" "BCS" "codes command works"

  # Test sections
  output=$("$SCRIPT" sections 2>&1 | head -1 || true)
  assert_contains "$output" "[0-9]+\." "sections command works"
}

test_dispatcher_unknown_command() {
  test_section "Unknown Command Tests"

  local -- output
  local -i exit_code=0
  output=$("$SCRIPT" nonexistent-command 2>&1) || exit_code=$?

  # Should return error
  assert_not_zero "$exit_code" "Unknown command returns error"

  # Should have error message
  assert_contains "$output" "Unknown command" "Error message for unknown command"
}

test_dispatcher_help_delegation() {
  test_section "Help Delegation Tests"

  # Test help for specific subcommands
  local -- output

  # help display should show display help
  output=$("$SCRIPT" help display 2>&1)
  assert_contains "$output" "display" "help display shows display help"

  # help codes should show codes help
  output=$("$SCRIPT" help codes 2>&1)
  assert_contains "$output" "codes" "help codes shows codes help"

  # help search should show search help
  output=$("$SCRIPT" help search 2>&1)
  assert_contains "$output" "search" "help search shows search help"
}

test_dispatcher_global_options() {
  test_section "Global Options Tests"

  # Test --version (global option)
  local -- output
  output=$("$SCRIPT" --version 2>&1)
  assert_contains "$output" "bcs" "Global --version works"
  assert_contains "$output" "[0-9]\.[0-9]" "Version has version number"

  # Test --help (global option)
  output=$("$SCRIPT" --help 2>&1)
  assert_contains "$output" "Usage:" "Global --help works"
  assert_contains "$output" "Commands:" "Global --help lists commands"
}

test_dispatcher_option_before_subcommand() {
  test_section "Option Before Subcommand Tests"

  # Test that options starting with dash before subcommand go to display
  local -- output
  output=$("$SCRIPT" -c 2>&1 | head -5 || true)

  # Should work like display -c
  assert_contains "$output" "# Bash Coding Standard" "-c before subcommand works"
}

# Run all tests
test_dispatcher_help
test_dispatcher_no_args_defaults_to_display
test_dispatcher_backward_compat_dash_options
test_dispatcher_subcommand_routing
test_dispatcher_unknown_command
test_dispatcher_help_delegation
test_dispatcher_global_options
test_dispatcher_option_before_subcommand

print_summary

#fin
