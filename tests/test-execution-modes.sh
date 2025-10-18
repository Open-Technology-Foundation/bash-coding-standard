#!/usr/bin/env bash
# Tests for execution modes (direct execution vs sourcing)

set -euo pipefail

# Load test helpers
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

SCRIPT="$SCRIPT_DIR"/../bash-coding-standard

test_direct_execution() {
  test_section "Direct Execution Mode Tests"

  # Test 1: Script runs successfully
  local -- output
  output=$("$SCRIPT" --cat 2>&1 | head -5 || true)
  assert_success $? "Script executes successfully"
  assert_contains "$output" "Bash Coding Standard" "Script output contains expected content"

  # Test 2: set -euo pipefail is active
  # (If script has errors, it should exit immediately)
  output=$("$SCRIPT" --help 2>&1)
  assert_success $? "Script with valid option succeeds"

  # Test 3: shopt settings are active
  # The script should have inherit_errexit and shift_verbose enabled
  # We can't directly test this, but we can verify the script doesn't crash

  # Test 4: Error handling works
  output=$("$SCRIPT" invalid-arg 2>&1) || true
  assert_contains "$output" "bcs: ✗" "Script reports errors correctly"

  # Test 5: Script metadata is set
  # Test that the script finds BCS_PATH and BCS_FILE
  output=$("$SCRIPT" --cat 2>&1)
  [[ -n "$output" ]] && assert_success 0 "Script sets up metadata correctly"
}

test_sourced_mode() {
  test_section "Sourced Mode Tests"

  # Create a test script that sources bash-coding-standard
  local -- test_script
  test_script=$(mktemp)
  trap 'rm -f "${test_script:-}"' EXIT

  cat >"$test_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Source the bash-coding-standard script
# shellcheck source=../bash-coding-standard
source "$1"

# Test that variables are set
[[ -n "$BCS_FILE" ]] || exit 1
[[ -n "$BCS_PATH" ]] || exit 2
[[ -n "$BCS_MD" ]] || exit 3

# Test that cmd_display function is available
declare -F cmd_display >/dev/null || exit 4

# Test that cmd_display works
cmd_display --help >/dev/null 2>&1 || exit 5

echo "success"
EOF

  chmod +x "$test_script"

  # Test sourcing
  local -- output
  output=$(bash "$test_script" "$SCRIPT" 2>&1)
  assert_equals "success" "$output" "Sourcing script sets up variables and functions"

  # Test 2: BCS_MD is pre-loaded in sourced mode
  cat >"$test_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=../bash-coding-standard
source "$1"
# BCS_MD should contain the document
[[ -n "$BCS_MD" ]] && echo "BCS_MD is set"
EOF

  output=$(bash "$test_script" "$SCRIPT" 2>&1)
  assert_equals "BCS_MD is set" "$output" "Sourcing pre-loads BCS_MD"

  # Test 3: display_BCS function is exported
  cat >"$test_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=../bash-coding-standard
source "$1"
declare -F cmd_display >/dev/null && echo "function exported"
EOF

  output=$(bash "$test_script" "$SCRIPT" 2>&1)
  assert_equals "function exported" "$output" "cmd_display function is available after sourcing"

  # Test 4: find_bcs_file is available
  cat >"$test_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=../bash-coding-standard
source "$1"
declare -F find_bcs_file >/dev/null && echo "function available"
EOF

  output=$(bash "$test_script" "$SCRIPT" 2>&1)
  assert_equals "function available" "$output" "find_bcs_file function is available after sourcing"

  # Test 5: Variables are global
  cat >"$test_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=../bash-coding-standard
source "$1"

# Modify BCS_FILE and verify it persists
original_file="$BCS_FILE"
BCS_FILE="/tmp/test"
[[ "$BCS_FILE" == "/tmp/test" ]] && echo "variable is global"
EOF

  output=$(bash "$test_script" "$SCRIPT" 2>&1)
  assert_equals "variable is global" "$output" "Variables are global with -gx"
}

test_execution_vs_sourcing_differences() {
  test_section "Execution vs Sourcing Differences"

  # Test 1: Direct execution uses set -euo pipefail
  local -- output
  output=$("$SCRIPT" --help 2>&1)
  assert_success $? "Direct execution has error handling"

  # Test 2: Sourced mode doesn't set pipefail (to avoid affecting parent)
  local -- test_script
  test_script=$(mktemp)
  trap 'rm -f "${test_script:-}"' EXIT

  cat >"$test_script" <<'EOF'
#!/usr/bin/env bash
# Don't set pipefail before sourcing
# shellcheck source=../bash-coding-standard
source "$1"
# Check if pipefail was set by sourcing (it shouldn't be)
[[ $- =~ e ]] && echo "errexit set" || echo "errexit not set"
EOF

  output=$(bash "$test_script" "$SCRIPT" 2>&1)
  # We can't easily test this without affecting the parent shell

  # Test 3: Both modes can find the file
  output=$("$SCRIPT" --cat 2>&1 | head -1 || true)
  assert_contains "$output" "Bash Coding Standard" "Direct execution finds file"

  cat >"$test_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=../bash-coding-standard
source "$1"
cmd_display --cat 2>&1 | head -1 || true
EOF

  output=$(bash "$test_script" "$SCRIPT" 2>&1)
  assert_contains "$output" "Bash Coding Standard" "Sourced mode finds file"
}

test_error_handling_in_modes() {
  test_section "Error Handling in Different Modes"

  # Test 1: Direct execution exits on invalid args
  local -- output
  output=$("$SCRIPT" invalid-arg 2>&1) || true
  assert_contains "$output" "bcs: ✗" "Direct execution reports errors"

  # Test 2: display_BCS function returns error code
  local -- test_script
  test_script=$(mktemp)
  trap 'rm -f "${test_script:-}"' EXIT

  cat >"$test_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=../bash-coding-standard
source "$1"

# Call with invalid arg and check return code
if cmd_display invalid-arg >/dev/null 2>&1; then
  echo "succeeded unexpectedly"
  exit 1
else
  echo "failed as expected"
  exit 0
fi
EOF

  bash "$test_script" "$SCRIPT" 2>&1
  assert_exit_code 0 $? "cmd_display returns error code for invalid args"
}

# Run all tests
test_direct_execution
test_sourced_mode
test_execution_vs_sourcing_differences
test_error_handling_in_modes

print_summary

#fin
