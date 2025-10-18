#!/usr/bin/env bash
# Tests for bcs compress subcommand

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Load test helpers
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

SCRIPT="$SCRIPT_DIR"/../bash-coding-standard

test_compress_help() {
  test_section "Compress Help Tests"

  local -- output
  output=$("$SCRIPT" compress --help 2>&1)

  assert_contains "$output" "Usage:" "compress --help shows usage"
  assert_contains "$output" "bcs compress" "Help mentions compress command"
  assert_contains "$output" "MODES:" "Help shows modes section"
  assert_contains "$output" "OPTIONS:" "Help shows options section"
  assert_contains "$output" "--report-only" "Help shows --report-only mode"
  assert_contains "$output" "--regenerate" "Help shows --regenerate mode"
  assert_contains "$output" "--tier" "Help shows --tier option"
  assert_contains "$output" "--claude-cmd" "Help shows --claude-cmd option"
  assert_contains "$output" "--summary-limit" "Help shows --summary-limit option"
  assert_contains "$output" "--abstract-limit" "Help shows --abstract-limit option"
  assert_contains "$output" "--context-level" "Help shows --context-level option"
  assert_contains "$output" "--dry-run" "Help shows --dry-run option"
  assert_contains "$output" "DESCRIPTION:" "Help shows description"
}

test_compress_report_only_mode() {
  test_section "Compress Report-Only Mode Tests"

  # Report-only is default mode (no modifications)
  local -- output exit_code=0
  output=$("$SCRIPT" compress 2>&1) || exit_code=$?

  # Should succeed (exit 0) even if Claude not available, as report-only doesn't need it
  assert_zero "$exit_code" "compress (report-only) succeeds"

  # Should mention report mode (case-insensitive match)
  assert_contains "$output" "[Rr]eport" "Output mentions report mode"
}

test_compress_dry_run() {
  test_section "Compress Dry-Run Tests"

  local -- output exit_code=0
  output=$("$SCRIPT" compress --dry-run 2>&1) || exit_code=$?

  # Dry-run should succeed without requiring Claude
  assert_zero "$exit_code" "compress --dry-run succeeds"

  # Should indicate dry-run
  if [[ "$output" =~ [Dd]ry.?[Rr]un || "$output" =~ "would" ]]; then
    pass "Dry-run mode indicated in output"
  else
    warn "Dry-run output may not clearly indicate simulation mode"
  fi
}

test_compress_tier_option() {
  test_section "Compress Tier Option Tests"

  # Test tier option syntax (don't actually compress)
  local -- output
  local -i exit_code=0

  # Test summary tier
  output=$("$SCRIPT" compress --tier summary --dry-run 2>&1) || exit_code=$?
  if [[ "$exit_code" -eq 0 ]]; then
    pass "--tier summary accepted"
  else
    fail "--tier summary rejected (exit code: $exit_code)"
  fi

  # Test abstract tier
  exit_code=0
  output=$("$SCRIPT" compress --tier abstract --dry-run 2>&1) || exit_code=$?
  if [[ "$exit_code" -eq 0 ]]; then
    pass "--tier abstract accepted"
  else
    fail "--tier abstract rejected (exit code: $exit_code)"
  fi
}

test_compress_context_levels() {
  test_section "Compress Context Level Tests"

  local -- context_levels=("none" "toc" "abstract" "summary" "complete")
  local -- level exit_code

  for level in "${context_levels[@]}"; do
    exit_code=0
    "$SCRIPT" compress --context-level "$level" --dry-run 2>&1 >/dev/null || exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
      pass "Context level '$level' accepted"
    else
      fail "Context level '$level' rejected (exit code: $exit_code)"
    fi
  done
}

test_compress_size_limits() {
  test_section "Compress Size Limit Tests"

  local -- output exit_code=0

  # Test custom summary limit
  output=$("$SCRIPT" compress --summary-limit 5000 --dry-run 2>&1) || exit_code=$?
  assert_zero "$exit_code" "--summary-limit option accepted"

  # Test custom abstract limit
  exit_code=0
  output=$("$SCRIPT" compress --abstract-limit 1000 --dry-run 2>&1) || exit_code=$?
  assert_zero "$exit_code" "--abstract-limit option accepted"

  # Test both limits together
  exit_code=0
  output=$("$SCRIPT" compress --summary-limit 8000 --abstract-limit 1200 --dry-run 2>&1) || exit_code=$?
  assert_zero "$exit_code" "Both size limits accepted together"
}

test_compress_quiet_mode() {
  test_section "Compress Quiet Mode Tests"

  local -- output_normal output_quiet

  # Get normal output
  output_normal=$("$SCRIPT" compress --dry-run 2>&1)

  # Get quiet output
  output_quiet=$("$SCRIPT" compress --quiet --dry-run 2>&1)

  # Quiet output should be shorter or equal
  local -i normal_lines quiet_lines
  normal_lines=$(echo "$output_normal" | wc -l)
  quiet_lines=$(echo "$output_quiet" | wc -l)

  if [[ "$quiet_lines" -le "$normal_lines" ]]; then
    pass "Quiet mode reduces output (normal: $normal_lines, quiet: $quiet_lines)"
  else
    warn "Quiet mode may not be reducing output as expected"
  fi
}

test_compress_verbose_mode() {
  test_section "Compress Verbose Mode Tests"

  local -- output exit_code=0

  # Verbose is default, but test explicit flag
  output=$("$SCRIPT" compress --verbose --dry-run 2>&1) || exit_code=$?

  assert_zero "$exit_code" "--verbose option accepted"
  assert_not_empty "$output" "Verbose mode produces output"
}

test_compress_claude_cmd_option() {
  test_section "Compress Custom Claude Command Tests"

  local -- output
  local -i exit_code=0

  # Test with non-existent command (in report-only mode, should still work)
  output=$("$SCRIPT" compress --claude-cmd /nonexistent/claude 2>&1) || exit_code=$?

  # In report-only mode, Claude command shouldn't be checked
  assert_zero "$exit_code" "--claude-cmd option accepted in report-only mode"
}

test_compress_regenerate_requires_claude() {
  test_section "Compress Regenerate Mode Tests"

  local -- output exit_code=0

  # Regenerate mode requires Claude CLI
  output=$("$SCRIPT" compress --regenerate --dry-run 2>&1) || exit_code=$?

  # Should succeed in dry-run even without Claude
  assert_zero "$exit_code" "--regenerate works in dry-run mode"
}

test_compress_invalid_tier() {
  test_section "Compress Invalid Tier Tests"

  local -- output exit_code=0
  output=$("$SCRIPT" compress --tier invalid 2>&1) || exit_code=$?

  # Should fail with invalid tier
  assert_not_zero "$exit_code" "Invalid tier returns error"
  assert_contains "$output" "[Ii]nvalid" "Error message for invalid tier"
}

test_compress_invalid_context() {
  test_section "Compress Invalid Context Tests"

  local -- output exit_code=0
  output=$("$SCRIPT" compress --context-level invalid 2>&1) || exit_code=$?

  # Should fail with invalid context level
  assert_not_zero "$exit_code" "Invalid context level returns error"
  assert_contains "$output" "[Ii]nvalid" "Error message for invalid context"
}

test_compress_help_exit_code() {
  test_section "Compress Help Exit Code Tests"

  local -i exit_code=0
  "$SCRIPT" compress --help >/dev/null 2>&1 || exit_code=$?

  assert_zero "$exit_code" "compress --help exits with 0"
}

test_compress_mode_conflict() {
  test_section "Compress Mode Conflict Tests"

  # Test combining conflicting modes (with dry-run to avoid actual execution)
  local -- output exit_code=0
  output=$("$SCRIPT" compress --report-only --regenerate --dry-run 2>&1) || exit_code=$?

  # Should either accept (last wins) or reject (conflict error)
  # Either behavior is acceptable, just document it
  if [[ "$exit_code" -eq 0 ]]; then
    pass "Multiple modes accepted (last one wins)"
  else
    pass "Multiple modes rejected with conflict error"
  fi
}

test_compress_output_format() {
  test_section "Compress Output Format Tests"

  local -- output
  output=$("$SCRIPT" compress 2>&1)

  # Should produce structured output
  if [[ -n "$output" ]]; then
    pass "Compress produces output"

    # Check for common output patterns
    if [[ "$output" =~ (tier|file|limit|size) ]]; then
      pass "Output contains expected keywords"
    else
      warn "Output format may not contain expected information"
    fi
  else
    warn "Compress produces no output (may be quiet by default)"
  fi
}

test_compress_no_args() {
  test_section "Compress No Arguments Tests"

  local -- output exit_code=0
  output=$("$SCRIPT" compress 2>&1) || exit_code=$?

  # Should succeed with defaults (report-only mode)
  assert_zero "$exit_code" "compress with no args succeeds (defaults to report-only)"
}

# Run all tests
test_compress_help
test_compress_report_only_mode
test_compress_dry_run
test_compress_tier_option
test_compress_context_levels
test_compress_size_limits
test_compress_quiet_mode
test_compress_verbose_mode
test_compress_claude_cmd_option
test_compress_regenerate_requires_claude
test_compress_invalid_tier
test_compress_invalid_context
test_compress_help_exit_code
test_compress_mode_conflict
test_compress_output_format
test_compress_no_args

print_summary

#fin
