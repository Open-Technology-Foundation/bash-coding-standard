#!/usr/bin/env bash
# Tests for get_default_tier() function

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Load test helpers
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

SCRIPT="$SCRIPT_DIR"/../bash-coding-standard

test_get_default_tier_function_exists() {
  test_section "Get Default Tier Function Existence"

  # Source the script to access get_default_tier
  # shellcheck disable=SC1090
  source "$SCRIPT"

  if declare -F get_default_tier &>/dev/null; then
    pass "get_default_tier function exists"
  else
    fail "get_default_tier function not found"
    return 1
  fi
}

test_get_default_tier_returns_valid_tier() {
  test_section "Get Default Tier Returns Valid Tier"

  # Source the script
  # shellcheck disable=SC1090
  source "$SCRIPT"

  local -- tier
  tier=$(get_default_tier)

  # Should be one of: abstract, summary, complete
  if [[ "$tier" =~ ^(abstract|summary|complete)$ ]]; then
    pass "Returns valid tier: $tier"
  else
    fail "Invalid tier returned: $tier"
  fi
}

test_get_default_tier_matches_symlink() {
  test_section "Get Default Tier Matches Symlink"

  # Check symlink target
  local -- script_dir symlink_target expected_tier
  script_dir=$(dirname "$SCRIPT")

  if [[ ! -L "$script_dir"/BASH-CODING-STANDARD.md ]]; then
    skip_test "BASH-CODING-STANDARD.md is not a symlink"
    return 0
  fi

  symlink_target=$(readlink "$script_dir"/BASH-CODING-STANDARD.md)

  # Extract tier from symlink target
  if [[ "$symlink_target" =~ \.complete\.md$ ]]; then
    expected_tier='complete'
  elif [[ "$symlink_target" =~ \.summary\.md$ ]]; then
    expected_tier='summary'
  elif [[ "$symlink_target" =~ \.abstract\.md$ ]]; then
    expected_tier='abstract'
  else
    skip_test "Cannot determine tier from symlink target: $symlink_target"
    return 0
  fi

  # Source script and get tier
  # shellcheck disable=SC1090
  source "$SCRIPT"
  local -- tier
  tier=$(get_default_tier)

  assert_equals "$expected_tier" "$tier" "Tier matches symlink target"
}

test_get_default_tier_fallback() {
  test_section "Get Default Tier Fallback Behavior"

  # Test that function falls back to 'abstract' when symlink not found
  # This requires testing in isolation, which is complex without mocking
  # For now, just verify it returns successfully

  # shellcheck disable=SC1090
  source "$SCRIPT"

  local -- tier
  tier=$(get_default_tier) || {
    fail "get_default_tier failed to execute"
    return 1
  }

  pass "get_default_tier executes successfully (returned: $tier)"
}

test_get_default_tier_is_readonly_function() {
  test_section "Get Default Tier is Read-Only"

  # Source script
  # shellcheck disable=SC1090
  source "$SCRIPT"

  # Call function multiple times - should return same result
  local -- tier1 tier2 tier3
  tier1=$(get_default_tier)
  tier2=$(get_default_tier)
  tier3=$(get_default_tier)

  if [[ "$tier1" == "$tier2" && "$tier2" == "$tier3" ]]; then
    pass "Function is pure/read-only (consistent results)"
  else
    fail "Function results are inconsistent: $tier1, $tier2, $tier3"
  fi
}

# Run all tests
test_get_default_tier_function_exists
test_get_default_tier_returns_valid_tier
test_get_default_tier_matches_symlink
test_get_default_tier_fallback
test_get_default_tier_is_readonly_function

print_summary

#fin
