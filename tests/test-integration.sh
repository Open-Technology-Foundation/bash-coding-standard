#!/usr/bin/env bash
# Integration tests for bash-coding-standard
# Tests end-to-end workflows and multi-command interactions

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Load test helpers
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

SCRIPT="$SCRIPT_DIR"/../bash-coding-standard

test_workflow_template_to_execution() {
  test_section "Workflow: Template Generation → Execution"

  local -- tmpfile="/tmp/bcs-integ-test-$$.sh"
  trap 'rm -f "$tmpfile"' RETURN

  # Workflow: Generate template → Make executable → Run it
  "$SCRIPT" template -t minimal -o "$tmpfile" >/dev/null 2>&1

  # Verify file exists
  if [[ -f "$tmpfile" ]]; then
    pass "Generated template file created"

    # Make executable
    chmod +x "$tmpfile"

    if [[ -x "$tmpfile" ]]; then
      pass "Template made executable"

      # Try to execute it (with timeout and /dev/null stdin to prevent hanging)
      if timeout 2 bash "$tmpfile" </dev/null >/dev/null 2>&1; then
        pass "Generated template executes without errors"
      else
        local -i exec_exit=$?
        if [[ "$exec_exit" -eq 124 ]]; then
          fail "Generated template timed out (may be waiting for input)"
        else
          # Non-zero exit is acceptable - template may need args
          pass "Generated template runs (exit code: $exec_exit)"
        fi
      fi
    else
      fail "chmod +x failed"
    fi
  else
    fail "Template generation failed to create file"
  fi
}

test_workflow_search_decode_verify() {
  test_section "Workflow: Search → Decode → Verify Content"

  # Workflow: Search for keyword → Decode matching code → Verify content
  local -- search_output code_output

  # Search for "readonly"
  search_output=$("$SCRIPT" search "readonly" 2>&1 | head -50 || true)

  if [[ "$search_output" =~ BCS[0-9]+ ]]; then
    pass "Search found BCS codes"

    # Extract first BCS code
    local -- first_code
    first_code=$(echo "$search_output" | grep -oE 'BCS[0-9]+' | head -1)

    if [[ -n "$first_code" ]]; then
      pass "Extracted BCS code: $first_code"

      # Decode the code
      code_output=$("$SCRIPT" decode "$first_code" -p 2>&1 | head -20 || true)

      if [[ -n "$code_output" ]]; then
        pass "Successfully decoded $first_code"

        # Verify content contains the search term
        if [[ "$code_output" =~ readonly ]]; then
          pass "Decoded content contains search term 'readonly'"
        else
          warn "Decoded content may not contain search term (could be in different tier)"
        fi
      else
        fail "Decode produced no output"
      fi
    else
      fail "Could not extract BCS code from search results"
    fi
  else
    fail "Search did not produce BCS codes"
  fi
}

test_workflow_generate_search_verify() {
  test_section "Workflow: Generate Standard → Search → Verify"

  # Workflow: Generate standard → Search within it → Verify all sections present
  local -- generated_output search_result

  # Generate to temp file
  local -- tmpfile
  tmpfile=$(mktemp)
  trap 'rm -f "$tmpfile"' RETURN

  "$SCRIPT" generate -o "$tmpfile" 2>&1 >/dev/null

  if [[ -f "$tmpfile" && -s "$tmpfile" ]]; then
    pass "Generated standard file created"

    # Search for section marker
    if grep -q "## " "$tmpfile"; then
      pass "Generated file contains section headers"
    else
      fail "Generated file missing section headers"
    fi

    # Search for BCS code markers
    if grep -qE 'BCS[0-9]{2,}' "$tmpfile"; then
      pass "Generated file contains BCS codes"
    else
      warn "Generated file may not contain BCS code markers"
    fi

    # Verify substantial content
    local -i line_count
    line_count=$(wc -l < "$tmpfile")

    if [[ "$line_count" -gt 100 ]]; then
      pass "Generated file has substantial content ($line_count lines)"
    else
      fail "Generated file is too small ($line_count lines)"
    fi
  else
    fail "Failed to generate standard file"
  fi
}

test_workflow_codes_decode_all() {
  test_section "Workflow: List Codes → Decode All → Verify"

  # Workflow: Get all codes → Decode each → Verify all exist
  local -- codes_output
  codes_output=$("$SCRIPT" codes 2>&1)

  if [[ -n "$codes_output" ]]; then
    pass "Codes command produces output"

    # Count codes
    local -i code_count
    code_count=$(echo "$codes_output" | grep -cE '^BCS[0-9]+' || true)

    if [[ "$code_count" -gt 50 ]]; then
      pass "Found substantial number of codes ($code_count codes)"

      # Test decoding a sample (not all - too slow)
      local -- sample_codes
      sample_codes=$(echo "$codes_output" | grep -oE '^BCS[0-9]+' | head -5)

      local -- code success_count=0
      for code in $sample_codes; do
        if "$SCRIPT" decode "$code" --exists 2>&1 >/dev/null; then
          ((success_count+=1))
        fi
      done

      if [[ "$success_count" -eq 5 ]]; then
        pass "All sampled codes ($success_count/5) decode successfully"
      else
        fail "Some codes failed to decode ($success_count/5 succeeded)"
      fi
    else
      fail "Too few codes found ($code_count)"
    fi
  else
    fail "Codes command produced no output"
  fi
}

test_workflow_template_shellcheck() {
  test_section "Workflow: Template → ShellCheck Validation"

  # Only run if shellcheck is available
  if ! command -v shellcheck &>/dev/null; then
    warn "ShellCheck not available - skipping test"
    return 0
  fi

  local -- tmpfile
  tmpfile=$(mktemp --suffix=.sh)
  trap 'rm -f "$tmpfile"' RETURN

  # Generate each template type and validate with shellcheck
  local -- template_types=("minimal" "basic" "complete" "library")
  local -- ttype sc_output

  for ttype in "${template_types[@]}"; do
    "$SCRIPT" template -t "$ttype" -o "$tmpfile" -f >/dev/null 2>&1

    # Exclude SC2034 (unused variables) and SC2015 (A && B || C pattern)
    # These are acceptable in templates as they're starting points for customization
    if shellcheck -e SC2034,SC2015 "$tmpfile" >/dev/null 2>&1; then
      pass "Template '$ttype' passes shellcheck"
    else
      fail "Template '$ttype' has shellcheck violations"
    fi
  done
}

test_workflow_about_consistency() {
  test_section "Workflow: About Info → Verify Consistency"

  # Workflow: Get about info → Cross-check with other commands
  local -- about_output codes_count sections_count

  about_output=$("$SCRIPT" about 2>&1)

  if [[ "$about_output" =~ ([0-9]+)[[:space:]]+(sections|Sections) ]]; then
    sections_count="${BASH_REMATCH[1]}"
    pass "About reports $sections_count sections"

    # Verify with sections command
    local -i actual_sections
    actual_sections=$("$SCRIPT" sections 2>&1 | grep -cE '^[0-9]+\.' || true)

    if [[ "$actual_sections" -eq "$sections_count" ]]; then
      pass "Section count matches between 'about' and 'sections' commands"
    else
      warn "Section count mismatch (about: $sections_count, sections: $actual_sections)"
    fi
  else
    warn "Could not extract section count from about output"
  fi
}

test_workflow_decode_tiers_consistency() {
  test_section "Workflow: Decode Tiers → Verify Consistency"

  # Workflow: Decode same code in all tiers → Verify all exist and differ
  local -- test_code="BCS0102"
  local -- complete_out abstract_out summary_out

  complete_out=$("$SCRIPT" decode "$test_code" -c 2>&1)
  abstract_out=$("$SCRIPT" decode "$test_code" -a 2>&1)
  summary_out=$("$SCRIPT" decode "$test_code" -s 2>&1)

  if [[ -n "$complete_out" && -n "$abstract_out" && -n "$summary_out" ]]; then
    pass "All three tiers produce output for $test_code"

    # Verify they point to different files
    if [[ "$complete_out" != "$abstract_out" && "$complete_out" != "$summary_out" ]]; then
      pass "Tiers point to different files"
    else
      fail "Tier outputs are identical (should differ)"
    fi

    # Verify all files exist
    if [[ -f "$complete_out" && -f "$abstract_out" && -f "$summary_out" ]]; then
      pass "All tier files exist on filesystem"
    else
      fail "Some tier files do not exist"
    fi
  else
    fail "Failed to decode all tiers"
  fi
}

test_workflow_template_customization() {
  test_section "Workflow: Template Customization → Verification"

  # Workflow: Generate with custom values → Verify substitutions
  local -- tmpfile
  tmpfile=$(mktemp)
  trap 'rm -f "$tmpfile"' RETURN

  local -- test_name="myapp"
  local -- test_desc="Test Application"
  local -- test_version="2.5.0"

  "$SCRIPT" template -n "$test_name" -d "$test_desc" -v "$test_version" -o "$tmpfile" 2>&1 >/dev/null

  if [[ -f "$tmpfile" ]]; then
    local -- content
    content=$(cat "$tmpfile")

    # Verify all substitutions
    if [[ "$content" =~ $test_name ]]; then
      pass "NAME placeholder substituted"
    else
      fail "NAME placeholder not substituted"
    fi

    if [[ "$content" =~ $test_desc ]]; then
      pass "DESCRIPTION placeholder substituted"
    else
      fail "DESCRIPTION placeholder not substituted"
    fi

    if [[ "$content" =~ $test_version ]]; then
      pass "VERSION placeholder substituted"
    else
      fail "VERSION placeholder not substituted"
    fi
  else
    fail "Template file not created"
  fi
}

test_workflow_multiple_commands_sequence() {
  test_section "Workflow: Multiple Commands in Sequence"

  # Workflow: Run multiple commands and verify state doesn't interfere
  local -- out1 out2 out3 out4

  out1=$("$SCRIPT" sections 2>&1 | wc -l)
  out2=$("$SCRIPT" codes 2>&1 | wc -l)
  out3=$("$SCRIPT" about 2>&1 | wc -l)
  out4=$("$SCRIPT" sections 2>&1 | wc -l)

  # First and last sections output should be identical
  if [[ "$out1" -eq "$out4" ]]; then
    pass "Multiple command executions produce consistent results"
  else
    fail "Command output changed between runs (state interference?)"
  fi

  # All commands should produce output
  if [[ "$out1" -gt 0 && "$out2" -gt 0 && "$out3" -gt 0 ]]; then
    pass "All commands in sequence produced output"
  else
    fail "Some commands produced no output"
  fi
}

test_workflow_search_no_results() {
  test_section "Workflow: Search With No Results → Error Handling"

  # Workflow: Search for nonexistent pattern → Verify graceful handling
  local -- search_output exit_code=0

  search_output=$("$SCRIPT" search "xyzabc123nonexistent" 2>&1) || exit_code=$?

  # Should not crash (exit code should be defined)
  if [[ "$exit_code" -eq 0 || "$exit_code" -eq 1 ]]; then
    pass "Search with no results handles gracefully"
  else
    fail "Search crashed or returned unexpected exit code: $exit_code"
  fi

  # Should communicate no results
  if [[ "$search_output" =~ (no|not|found|matches) ]]; then
    pass "No-results message communicated"
  else
    warn "No-results may not be clearly communicated"
  fi
}

# Run all integration tests
test_workflow_template_to_execution
test_workflow_search_decode_verify
test_workflow_generate_search_verify
test_workflow_codes_decode_all
test_workflow_template_shellcheck
test_workflow_about_consistency
test_workflow_decode_tiers_consistency
test_workflow_template_customization
test_workflow_multiple_commands_sequence
test_workflow_search_no_results

print_summary

#fin
