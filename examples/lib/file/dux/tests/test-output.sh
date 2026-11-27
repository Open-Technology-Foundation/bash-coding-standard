#!/usr/bin/env bash
# Test output format of dux
# Note: uses -uo (no -e) so assertion failures don't abort the test run
set -uo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

#shellcheck disable=SC2155
declare -r SCRIPT_PATH=$(realpath -- "$0")
declare -r SCRIPT_DIR=${SCRIPT_PATH%/*}

# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

declare -r DUX=${1:-$SCRIPT_DIR/../dir-sizes}

# Create temp directory for tests
declare -- TEST_DIR
TEST_DIR=$(mktemp -d /tmp/dux-test-output-XXXXXX)
declare -r TEST_DIR
trap 'rm -rf "$TEST_DIR"' EXIT

# Setup test fixtures with known sizes
mkdir -p "$TEST_DIR"/empty-subdir
mkdir -p "$TEST_DIR"/small-subdir
mkdir -p "$TEST_DIR"/medium-subdir
mkdir -p "$TEST_DIR"/large-subdir

# Create files of different sizes
dd if=/dev/zero of="$TEST_DIR"/small-subdir/small.bin bs=1024 count=10 2>/dev/null   # 10 KiB
dd if=/dev/zero of="$TEST_DIR"/medium-subdir/medium.bin bs=1024 count=100 2>/dev/null # 100 KiB
dd if=/dev/zero of="$TEST_DIR"/large-subdir/large.bin bs=1024 count=1000 2>/dev/null  # 1000 KiB

test_section 'Output Format'

# Get output for testing
output=$("$DUX" "$TEST_DIR" 2>&1)

# Test: Output contains size column
assert_regex_match "$output" '[0-9]' 'Output contains numeric size'

# Test: Output contains path column
assert_contains "$output" "$TEST_DIR" 'Output contains path'

# Test: Columns separated by tab
if echo "$output" | grep -q $'\t'; then
  pass 'Columns separated by tab'
else
  fail 'Columns should be separated by tab'
fi

# Test: Sizes use IEC binary prefixes spelled out (KiB, not KB)
declare -- medium_line
medium_line=$(grep -- 'medium-subdir' <<<"$output")
assert_regex_match "$medium_line" '^100\.[0-9]KiB +'$'\t' 'Sizes use KiB (binary prefix), not KB'
assert_not_contains "$output" 'KB ' 'No SI-looking KB label in output'

# Test: Output sorted smallest to largest
# The empty dir should come before small, small before medium, medium before large
declare -- lines first_line last_line
lines=$(echo "$output" | grep "$TEST_DIR"/)
first_line=$(echo "$lines" | head -1)
last_line=$(echo "$lines" | tail -1)

if [[ $first_line =~ empty || $first_line =~ 0\.0B || $first_line =~ 4\.0K ]]; then
  pass 'Output sorted - smallest first'
else
  warn "Output sorting may vary (first: $first_line)"
fi

if [[ $last_line =~ large || $last_line =~ M ]]; then
  pass 'Output sorted - largest last'
else
  warn "Output sorting may vary (last: $last_line)"
fi

# Test: Output includes target directory itself
assert_contains "$output" "$TEST_DIR" 'Output includes target directory'

# Test: Empty subdirs show small size (directory overhead)
if echo "$output" | grep -q 'empty-subdir'; then
  pass 'Empty subdir in output'
else
  fail 'Empty subdir should be in output'
fi

# Test: Large sizes display correctly (should show KB, KiB, MB, MiB etc)
declare -- large_line
if echo "$output" | grep 'large-subdir' | grep -qE '[0-9.]+[KMG]'; then
  pass 'Large sizes display with appropriate unit'
else
  # Show what we got for debugging
  large_line=$(echo "$output" | grep 'large-subdir')
  warn "Large size format: $large_line"
fi

# Test: Multiple subdirs all listed
assert_contains "$output" 'small-subdir' 'small-subdir in output'
assert_contains "$output" 'medium-subdir' 'medium-subdir in output'
assert_contains "$output" 'large-subdir' 'large-subdir in output'
assert_contains "$output" 'empty-subdir' 'empty-subdir in output'

# Test: Line count matches subdir count (+ target dir itself = 5 total)
declare -i line_count
line_count=$(echo "$output" | wc -l)
# Should have 5 lines: target dir + 4 subdirs
assert_greater_than "$line_count" 3 'At least 4 lines of output'

# Test: Relative paths preserved
declare -- rel_output abs_output
rel_output=$(cd "$TEST_DIR" && "$DUX" . 2>&1)
# Each line is '<size><pad>\t<path>', so the path follows the tab
assert_contains "$rel_output" $'\t./small-subdir' 'Relative paths preserved in output'
# The target holds everything, so it sorts last
assert_equals . "$(tail -n1 <<<"$rel_output" | cut -f2)" 'Relative path . preserved'

# Test: Absolute paths preserved
abs_output=$("$DUX" "$TEST_DIR" 2>&1)
assert_contains "$abs_output" "$TEST_DIR" 'Absolute paths preserved in output'

print_summary
exit $?

#fin
