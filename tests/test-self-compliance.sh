#!/usr/bin/env bash
# Self-compliance tests: Verify bcs script follows BCS standards

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Load test helpers
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

BCS_SCRIPT="$SCRIPT_DIR"/../bash-coding-standard

test_shebang() {
  test_section "Shebang Tests"

  local -- first_line
  first_line=$(head -1 "$BCS_SCRIPT")

  if [[ "$first_line" =~ ^#!/(usr/)?bin/(env[[:space:]]+)?bash ]]; then
    pass "Has valid BCS-compliant shebang"
  else
    fail "Invalid or missing shebang: $first_line"
  fi
}

test_set_options() {
  test_section "Set Options Tests"

  # Check for set -euo pipefail (critical for BCS0101)
  if grep -q '^set -euo pipefail' "$BCS_SCRIPT"; then
    pass "Has 'set -euo pipefail'"
  else
    fail "Missing 'set -euo pipefail'"
  fi

  # Check for shopt settings
  if grep -q '^shopt -s' "$BCS_SCRIPT"; then
    pass "Has shopt settings"
  else
    warn "Missing shopt settings (recommended)"
  fi
}

test_metadata_variables() {
  test_section "Metadata Variable Tests"

  # Check for VERSION
  if grep -qE '^[[:space:]]*(declare[[:space:]]+-[a-z]+[[:space:]]+)?VERSION=' "$BCS_SCRIPT"; then
    pass "Has VERSION variable"
  else
    warn "Missing VERSION variable (recommended)"
  fi

  # Check for script path variables
  if grep -qE '(SCRIPT_PATH|BCS_PATH)=' "$BCS_SCRIPT"; then
    pass "Has script path variables"
  else
    fail "Missing script path variables"
  fi
}

test_readonly_declarations() {
  test_section "Readonly Declaration Tests"

  # Check for readonly declarations
  if grep -q '^[[:space:]]*readonly' "$BCS_SCRIPT"; then
    pass "Uses readonly declarations"
  else
    warn "No readonly declarations found (recommended for constants)"
  fi
}

test_function_definitions() {
  test_section "Function Definition Tests"

  # Count function definitions
  local -i func_count
  func_count=$(grep -cE '^[a-z_][a-z0-9_]*\(\)[[:space:]]*\{' "$BCS_SCRIPT" || true)

  if [[ "$func_count" -gt 10 ]]; then
    pass "Has substantial functions ($func_count functions)"
  else
    warn "Few functions found ($func_count)"
  fi

  # Check for main function (required for scripts >40 lines)
  local -i line_count
  line_count=$(wc -l < "$BCS_SCRIPT")

  if [[ "$line_count" -gt 40 ]]; then
    if grep -q '^main()' "$BCS_SCRIPT"; then
      pass "Has main() function (required for scripts >40 lines)"
    else
      fail "Missing main() function (script has $line_count lines, requires main)"
    fi
  fi
}

test_fin_marker() {
  test_section "Fin Marker Tests"

  # Check for #fin at end
  if tail -5 "$BCS_SCRIPT" | grep -q '^#fin'; then
    pass "Has #fin end marker"
  else
    fail "Missing #fin end marker (BCS0101 requirement)"
  fi
}

test_shellcheck_compliance() {
  test_section "ShellCheck Compliance Tests"

  if ! command -v shellcheck &>/dev/null; then
    warn "ShellCheck not available - skipping test"
    return 0
  fi

  # Run shellcheck
  local -- shellcheck_output exit_code=0
  shellcheck_output=$(shellcheck -x "$BCS_SCRIPT" 2>&1) || exit_code=$?

  if [[ "$exit_code" -eq 0 ]]; then
    pass "Passes shellcheck with no violations"
  else
    # Count only warnings and errors (not info messages)
    local -i violation_count
    violation_count=$(echo "$shellcheck_output" | grep -cE '(warning|error):' || true)

    if [[ "$violation_count" -gt 0 ]]; then
      fail "Has $violation_count shellcheck violations"
      >&2 echo "First 10 violations:"
      >&2 echo "$shellcheck_output" | head -20
    else
      # Only info messages - acceptable
      pass "Passes shellcheck (info messages only, no warnings or errors)"
    fi
  fi
}

test_error_handling_functions() {
  test_section "Error Handling Function Tests"

  # Check for error() function
  if grep -q '^error()' "$BCS_SCRIPT"; then
    pass "Has error() function"
  else
    warn "Missing error() function (recommended)"
  fi

  # Check for die() function
  if grep -q '^die()' "$BCS_SCRIPT"; then
    pass "Has die() function"
  else
    warn "Missing die() function (recommended)"
  fi
}

test_command_substitution_style() {
  test_section "Command Substitution Style Tests"

  # BCS prefers $() over backticks
  local -i backtick_count dollar_count

  backtick_count=$(grep -c '`' "$BCS_SCRIPT" || true)
  dollar_count=$(grep -cE '\$\(' "$BCS_SCRIPT" || true)

  if [[ "$backtick_count" -eq 0 ]]; then
    pass "No backtick command substitutions (uses \$() style)"
  else
    warn "Found $backtick_count backtick substitutions (prefer \$())"
  fi

  if [[ "$dollar_count" -gt 10 ]]; then
    pass "Uses modern \$() command substitution ($dollar_count occurrences)"
  else
    warn "Few command substitutions found"
  fi
}

test_variable_quoting() {
  test_section "Variable Quoting Tests"

  # This is a heuristic test - count quoted vs unquoted variable references
  local -i quoted_vars unquoted_vars

  quoted_vars=$(grep -oE '"\$[a-zA-Z_][a-zA-Z0-9_]*"' "$BCS_SCRIPT" | wc -l || true)
  unquoted_vars=$(grep -oE '[^"](\$[a-zA-Z_][a-zA-Z0-9_]*)[^"]' "$BCS_SCRIPT" | wc -l || true)

  if [[ "$quoted_vars" -gt "$unquoted_vars" ]]; then
    pass "Most variables are quoted (quoted: $quoted_vars, unquoted: $unquoted_vars)"
  else
    warn "Many unquoted variables detected (may be intentional)"
  fi
}

test_dual_purpose_pattern() {
  test_section "Dual-Purpose Script Pattern Tests"

  # Check for dual-purpose pattern (BASH_SOURCE check)
  if grep -q 'BASH_SOURCE\[0\]' "$BCS_SCRIPT"; then
    pass "Uses dual-purpose script pattern (BASH_SOURCE check)"
  else
    warn "No dual-purpose pattern detected"
  fi

  # Check for function exports (declare -fx)
  if grep -q 'declare -fx' "$BCS_SCRIPT"; then
    pass "Exports functions for sourcing (declare -fx)"
  else
    warn "No function exports found"
  fi
}

test_help_documentation() {
  test_section "Help Documentation Tests"

  # Test that --help works
  local -- help_output exit_code=0
  help_output=$("$BCS_SCRIPT" --help 2>&1) || exit_code=$?

  assert_zero "$exit_code" "--help returns exit code 0"

  # Check help content
  if [[ "$help_output" =~ Usage: ]]; then
    pass "Help output contains usage information"
  else
    fail "Help output missing usage information"
  fi

  # Check for examples
  if [[ "$help_output" =~ Example ]]; then
    pass "Help output contains examples"
  else
    warn "Help output missing examples"
  fi
}

test_version_information() {
  test_section "Version Information Tests"

  # Test that --version works
  local -- version_output exit_code=0
  version_output=$("$BCS_SCRIPT" --version 2>&1) || exit_code=$?

  assert_zero "$exit_code" "--version returns exit code 0"

  # Check for version number
  if [[ "$version_output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
    pass "Version output contains semantic version number"
  else
    fail "Version output missing version number"
  fi
}

# Run all self-compliance tests
test_shebang
test_set_options
test_metadata_variables
test_readonly_declarations
test_function_definitions
test_fin_marker
test_shellcheck_compliance
test_error_handling_functions
test_command_substitution_style
test_variable_quoting
test_dual_purpose_pattern
test_help_documentation
test_version_information

print_summary

#fin
