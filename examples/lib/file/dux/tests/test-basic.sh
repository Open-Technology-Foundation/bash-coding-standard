#!/usr/bin/env bash
# Test basic functionality of dux
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
TEST_DIR=$(mktemp -d /tmp/dux-test-basic-XXXXXX)
declare -r TEST_DIR
trap 'rm -rf "$TEST_DIR"' EXIT

test_section 'Basic Functionality'

# Test: --help displays help and exits 0
output=$("$DUX" --help 2>&1); ec=$?
assert_exit_code 0 "$ec" '--help exits 0'
assert_contains "$output" 'Quick directory size overview' '--help shows description'
assert_contains "$output" '--one-file-system' '--help documents -x/--one-file-system'
assert_contains "$output" 'apparent size' '--help says sizes are apparent sizes'

# Test: -h displays help and exits 0
output=$("$DUX" -h 2>&1); ec=$?
assert_exit_code 0 "$ec" '-h exits 0'
assert_contains "$output" 'USAGE' '-h shows usage section'

# Test: --version displays version and exits 0
output=$("$DUX" --version 2>&1); ec=$?
assert_exit_code 0 "$ec" '--version exits 0'
assert_contains "$output" 'dir-sizes' '--version shows script name'

# Test: -V displays version and exits 0
output=$("$DUX" -V 2>&1); ec=$?
assert_exit_code 0 "$ec" '-V exits 0'

# Test: Version string matches expected format
assert_regex_match "$output" '^dir-sizes [0-9]+\.[0-9]+\.[0-9]+$' 'Version format is correct'

# Test: Help contains repository URL
output=$("$DUX" --help 2>&1); ec=$?
assert_contains "$output" 'github.com/Open-Technology-Foundation/dux' 'Help contains repo URL'

# Test: No arguments uses current directory
mkdir -p "$TEST_DIR"/subdir1 "$TEST_DIR"/subdir2
output=$(cd "$TEST_DIR" && "$DUX" 2>&1); ec=$?
assert_exit_code 0 "$ec" 'No arguments exits 0'
assert_contains "$output" 'subdir1' 'Output includes subdir1'
assert_contains "$output" 'subdir2' 'Output includes subdir2'

# Test: Single directory argument works
output=$("$DUX" "$TEST_DIR" 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Single directory argument exits 0'
assert_contains "$output" "$TEST_DIR" 'Output includes target directory'

print_summary
exit $?

#fin
