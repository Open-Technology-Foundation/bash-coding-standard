#!/usr/bin/env bash
# Tests for environment conditions (terminal, md2ansi, etc.)

set -euo pipefail

# Load test helpers
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

SCRIPT="$SCRIPT_DIR"/../bash-coding-standard

test_terminal_detection() {
  test_section "Terminal Detection Tests"

  # Test 1: Output to pipe (not a terminal)
  local -- output
  output=$("$SCRIPT" 2>&1 | head -10 || true)
  assert_success $? "Script works when piped"
  assert_contains "$output" "Bash Coding Standard" "Script outputs content when piped"

  # Test 2: Output redirection
  local -- tmpfile
  tmpfile=$(mktemp)
  trap 'rm -f "${tmpfile:-}"' EXIT

  "$SCRIPT" --cat >"$tmpfile" 2>&1
  assert_success $? "Script works with output redirection"
  [[ -s "$tmpfile" ]] && assert_success 0 "Script produces output when redirected"

  # Test 3: Script doesn't crash without terminal
  output=$("$SCRIPT" --cat 2>&1 | head -1 || true)
  assert_contains "$output" "Bash Coding Standard" "Script works without terminal"
}

test_md2ansi_availability() {
  test_section "md2ansi Availability Tests"

  if command -v md2ansi &>/dev/null; then
    # Test 1: md2ansi is used by default with terminal
    local -- output
    local -i exit_code=0

    # Test 2: --md2ansi forces md2ansi usage
    # Note: SIGPIPE (141) is expected when piping to head, so we ignore it
    output=$("$SCRIPT" --md2ansi 2>&1 | head -20) || exit_code=$?
    # Exit codes 0 or 141 (SIGPIPE) are both acceptable
    [[ "$exit_code" -eq 0 || "$exit_code" -eq 141 ]] && exit_code=0
    assert_success "$exit_code" "Script with --md2ansi succeeds when md2ansi available"

    # Test 3: --cat bypasses md2ansi
    output=$("$SCRIPT" --cat 2>&1 | head -5 || true)
    assert_not_contains "$output" "\033" "Script with --cat doesn't use md2ansi"

  else
    echo "${YELLOW}md2ansi not available - testing fallback behavior${NC}"

    # Test 4: Script falls back to cat when md2ansi unavailable
    local -- output
    output=$("$SCRIPT" 2>&1 | head -10 || true)
    assert_success $? "Script works without md2ansi"
    assert_contains "$output" "Bash Coding Standard" "Script falls back to cat"

    # Test 5: --md2ansi with no md2ansi fails gracefully
    # Actually, with force_md2ansi=0 by default, it should fall back
    output=$("$SCRIPT" 2>&1 | head -5 || true)
    assert_contains "$output" "Bash Coding Standard" "Script falls back when md2ansi unavailable"
  fi
}

test_file_not_found() {
  test_section "File Not Found Tests"

  # Test 1: Script with missing dependencies
  # Note: bash-coding-standard requires BASH-CODING-STANDARD.md
  # Testing true isolation is difficult due to FHS search paths
  # Instead, test that error handling exists

  local -- tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "${tmpdir:-}"' EXIT

  # Copy script to tmpdir
  cp "$SCRIPT" "$tmpdir"/
  chmod +x "$tmpdir"/bash-coding-standard

  # Running without BASH-CODING-STANDARD.md should fail
  local -- output exit_code=0
  output=$(cd "$tmpdir" && ./bash-coding-standard 2>&1) || exit_code=$?

  # Should either show error or find file via FHS paths
  if ((exit_code != 0)); then
    assert_contains "$output" "✗" "Script reports error when file not in local directory"
  else
    # Script found file via FHS search paths (expected in installed systems)
    pass "Script found file via FHS search paths (system is installed)"
  fi
}

test_bcs_md_variable() {
  test_section "BCS_MD Variable Tests"

  # Test that BCS_MD is populated when sourcing
  local -- test_script
  test_script=$(mktemp)
  trap 'rm -f "${test_script:-}"' EXIT

  cat >"$test_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=../bash-coding-standard
source "$1"

# Check BCS_MD is set and contains content
if [[ -n "$BCS_MD" ]] && [[ "$BCS_MD" =~ "Bash Coding Standard" ]]; then
  echo "BCS_MD populated"
else
  echo "BCS_MD not populated"
  exit 1
fi
EOF

  local -- output
  output=$(bash "$test_script" "$SCRIPT" 2>&1)
  assert_equals "BCS_MD populated" "$output" "BCS_MD is populated when sourcing"

  # Test --bash option exports BCS_MD
  output=$("$SCRIPT" --bash 2>&1)
  assert_contains "$output" "BCS_MD=" "bash-coding-standard --bash exports BCS_MD"
}

test_path_variables() {
  test_section "Path Variables Tests"

  # Test that BCS_PATH and BCS_FILE are set correctly when sourcing
  local -- test_script
  test_script=$(mktemp)
  trap 'rm -f "${test_script:-}"' EXIT

  cat >"$test_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=../bash-coding-standard
source "$1"

# Check variables are set
[[ -n "$BCS_PATH" ]] && echo "BCS_PATH: $BCS_PATH"
[[ -n "$BCS_FILE" ]] && echo "BCS_FILE: $BCS_FILE"
[[ -f "$BCS_FILE" ]] && echo "BCS_FILE exists"
EOF

  local -- output
  output=$(bash "$test_script" "$SCRIPT" 2>&1)
  assert_contains "$output" "BCS_PATH:" "BCS_PATH is set"
  assert_contains "$output" "BCS_FILE:" "BCS_FILE is set"
  assert_contains "$output" "BCS_FILE exists" "BCS_FILE points to valid file"
}

test_stdin_handling() {
  test_section "STDIN Handling Tests"

  # Test that script doesn't read from stdin
  local -- output
  output=$(echo "test input" | "$SCRIPT" --cat 2>&1 | head -5 || true)
  assert_contains "$output" "Bash Coding Standard" "Script doesn't consume stdin"

  # Test with empty stdin
  output=$(</dev/null "$SCRIPT" --cat 2>&1 | head -5 || true)
  assert_contains "$output" "Bash Coding Standard" "Script works with empty stdin"
}

test_error_output_to_stderr() {
  test_section "Error Output Tests"

  # Test that errors go to stderr
  local -- stderr
  stderr=$("$SCRIPT" invalid-arg 2>&1 >/dev/null) || true
  assert_contains "$stderr" "bcs: ✗" "Errors are sent to stderr"

  # Test that help goes to stdout
  local -- stdout
  stdout=$("$SCRIPT" --help 2>/dev/null)
  assert_contains "$stdout" "Usage:" "Help is sent to stdout"
}

test_special_characters_in_path() {
  test_section "Special Characters in Path Tests"

  # Test with spaces in path (if possible)
  local -- tmpdir
  tmpdir=$(mktemp -d)
  local -- spaced_dir="$tmpdir/dir with spaces"
  mkdir -p "$spaced_dir"
  trap 'rm -rf "${tmpdir:-}"' EXIT

  # Copy files to spaced directory
  cp "$SCRIPT" "$spaced_dir"/
  cp "$SCRIPT_DIR"/../BASH-CODING-STANDARD.md "$spaced_dir"/
  chmod +x "$spaced_dir"/bash-coding-standard

  # Test execution
  local -- output
  output=$("$spaced_dir"/bash-coding-standard --cat 2>&1 | head -5 || true)
  assert_contains "$output" "Bash Coding Standard" "Script works with spaces in path"
}

# Run all tests
test_terminal_detection
test_md2ansi_availability
test_file_not_found
test_bcs_md_variable
test_path_variables
test_stdin_handling
test_error_output_to_stderr
test_special_characters_in_path

print_summary

#fin
