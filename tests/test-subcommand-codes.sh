#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-subcommand-codes.sh - Tests for bcs codes subcommand
set -euo pipefail
shopt -s inherit_errexit
#shellcheck source-path=SCRIPTDIR source=test-helpers.sh
source "$(dirname "$0")"/test-helpers.sh

echo 'Testing: codes subcommand'

# Test: codes produces output
begin_test 'codes produces output'
output=$("$BCS_CMD" codes 2>/dev/null)
assert_not_empty "$output" 'codes produces output' || true

# Test: codes output format
begin_test 'codes output format is BCS#### Title'
first_line=$(echo "$output" | head -1)
assert_matches "$first_line" '^BCS[0-9]+ .+' 'first line matches format' || true

# Test: codes count is reasonable (should be ~100)
begin_test 'codes count is reasonable'
code_count=$(echo "$output" | wc -l)
assert_gt "$code_count" 80 'at least 80 codes' || true

# Test: key codes present
begin_test 'BCS0101 present'
assert_contains "$output" 'BCS0101' 'BCS0101 found' || true

begin_test 'BCS0505 present'
assert_contains "$output" 'BCS0505' 'BCS0505 found' || true

begin_test 'BCS1206 present'
assert_contains "$output" 'BCS1206' 'BCS1206 found' || true

# Test: all 12 sections represented
begin_test 'all 12 sections represented'
declare -i sections_found=0
for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
  if [[ "$output" == *"BCS${i}"* ]]; then
    sections_found+=1
  fi
done
assert_equal 12 "$sections_found" 'all 12 sections have codes' || true

# Test: exact code count is 112 (12 section overviews + 100 substantive rules)
begin_test 'exactly 112 BCS codes'
assert_equal 112 "$code_count" "exactly 112 codes (got $code_count)" || true

# Test: -T tier filter yields the documented tier distribution (34/44/22).
# Section overviews carry no tier, so the three filters partition the 100 rules.
begin_test 'codes -T tier counts are 34/44/22'
core_n=$("$BCS_CMD" codes -T core 2>/dev/null | grep -c '^BCS' || true)
recm_n=$("$BCS_CMD" codes -T recommended 2>/dev/null | grep -c '^BCS' || true)
styl_n=$("$BCS_CMD" codes -T style 2>/dev/null | grep -c '^BCS' || true)
assert_equal 34 "$core_n" "core tier count (got $core_n)" || true
assert_equal 44 "$recm_n" "recommended tier count (got $recm_n)" || true
assert_equal 22 "$styl_n" "style tier count (got $styl_n)" || true

# Test: codes are in ascending order
begin_test 'codes are in ascending order'
sorted_output=$(echo "$output" | sort -t' ' -k1,1)
if [[ "$output" == "$sorted_output" ]]; then
  printf '  %s✓%s codes are sorted ascending\n' "$GREEN" "$NC"
  TESTS_PASSED+=1
else
  printf '  %s✗%s codes are not sorted\n' "$RED" "$NC"
  TESTS_FAILED+=1
fi

# Test: codes help
begin_test 'codes -h shows help'
help_output=$("$BCS_CMD" codes -h 2>/dev/null)
assert_contains "$help_output" 'bcs codes' 'help has command name' || true

# Test: codes rejects invalid options
# A tier filter must name exactly one tier. 'core recommended' is a run of two
# adjacent valid names; it used to pass validation and then match nothing.
begin_test 'codes -T rejects a value that is not one tier'
assert_fails "rejects -T 'core recommended'" "$BCS_CMD" codes -T 'core recommended' || true
assert_fails 'rejects -T bogus' "$BCS_CMD" codes -T bogus || true
assert_success 'accepts -T disabled' "$BCS_CMD" codes -T disabled || true

begin_test 'codes rejects invalid options'
assert_fails 'rejects --bogus' "$BCS_CMD" codes --bogus || true

# Tests: --json structured export (requires jq; skip cleanly if jq absent)
if command -v jq &>/dev/null; then
  json_output=$("$BCS_CMD" codes --json 2>/dev/null)

  begin_test 'codes --json is a valid JSON array'
  if jq -e 'type == "array"' <<<"$json_output" &>/dev/null; then
    printf '  %s✓%s --json parses as a JSON array\n' "$GREEN" "$NC"
    TESTS_PASSED+=1
  else
    printf '  %s✗%s --json did not parse as a JSON array\n' "$RED" "$NC"
    TESTS_FAILED+=1
  fi

  begin_test 'codes --json length equals text-mode count'
  json_count=$(jq 'length' <<<"$json_output")
  assert_equal "$code_count" "$json_count" "json length == text count ($code_count)" || true

  begin_test 'codes --json objects have required keys'
  if jq -e 'all(.[]; has("code") and has("title") and has("tier")
                     and has("section") and has("disabled"))' \
       <<<"$json_output" &>/dev/null; then
    printf '  %s✓%s every object has code/title/tier/section/disabled\n' "$GREEN" "$NC"
    TESTS_PASSED+=1
  else
    printf '  %s✗%s an object is missing a required key\n' "$RED" "$NC"
    TESTS_FAILED+=1
  fi

  begin_test 'codes --json tiers are all legal values'
  if jq -e 'all(.[]; .tier == null
                     or (.tier | IN("core","recommended","style","disabled")))' \
       <<<"$json_output" &>/dev/null; then
    printf '  %s✓%s all tiers legal (or null for overviews)\n' "$GREEN" "$NC"
    TESTS_PASSED+=1
  else
    printf '  %s✗%s found an illegal tier value\n' "$RED" "$NC"
    TESTS_FAILED+=1
  fi

  begin_test 'codes --json codes match text mode'
  text_codes=$("$BCS_CMD" codes -p 2>/dev/null | awk '{print $1}')
  json_codes=$(jq -r '.[].code' <<<"$json_output")
  assert_equal "$text_codes" "$json_codes" 'json codes identical to text-mode codes' || true
else
  printf '  %s◉%s jq not found — skipping codes --json tests\n' "$CYAN" "$NC"
fi

print_summary 'codes'
#fin
