#!/usr/bin/env bash
# Test exit codes of dux
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
TEST_DIR=$(mktemp -d /tmp/dux-test-exit-XXXXXX)
declare -r TEST_DIR
trap 'rm -rf "$TEST_DIR"' EXIT

# Setup test fixtures
mkdir -p "$TEST_DIR"/with-subdirs/sub1 "$TEST_DIR"/with-subdirs/sub2
mkdir -p "$TEST_DIR"/empty-dir
touch "$TEST_DIR"/regular-file.txt

test_section 'Exit Codes'

# Test: Exit 0 on success
output=$("$DUX" "$TEST_DIR"/with-subdirs 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Exit 0 on success'

# Test: Exit 0 on --help
"$DUX" --help >/dev/null 2>&1; ec=$?
assert_exit_code 0 "$ec" 'Exit 0 on --help'

# Test: Exit 0 on --version
"$DUX" --version >/dev/null 2>&1; ec=$?
assert_exit_code 0 "$ec" 'Exit 0 on --version'

# Test: Exit 3 on non-existent directory
output=$("$DUX" /nonexistent/path/that/does/not/exist 2>&1); ec=$?
assert_exit_code 3 "$ec" 'Exit 3 on non-existent directory'
assert_contains "$output" 'Not a directory' "Shows 'not a directory' error"

# Test: Exit 3 on file (not directory)
output=$("$DUX" "$TEST_DIR"/regular-file.txt 2>&1); ec=$?
assert_exit_code 3 "$ec" 'Exit 3 when path is a file'
assert_contains "$output" 'Not a directory' "Shows 'not a directory' for file"

# Test: Exit 2 on too many arguments
output=$("$DUX" "$TEST_DIR" "$TEST_DIR" 2>&1); ec=$?
assert_exit_code 2 "$ec" 'Exit 2 on too many arguments'

# Test: Exit 2 when -- has extra operands
output=$("$DUX" -- "$TEST_DIR" "$TEST_DIR"/with-subdirs 2>&1); ec=$?
assert_exit_code 2 "$ec" 'Exit 2 on extra operands after --'

# Test: Exit 0 when -- has no operand
output=$(cd "$TEST_DIR" && "$DUX" -- 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Exit 0 on -- with no operand'

# Test: An empty operand is a bad path, not "no operand" (like ls '')
output=$(cd -- "$TEST_DIR" && "$DUX" '' 2>&1); ec=$?
assert_exit_code 3 "$ec" "Exit 3 on empty operand ''"
assert_contains "$output" "Not a directory ''" 'Empty operand reported as not a directory'
output=$(cd -- "$TEST_DIR" && "$DUX" -- '' 2>&1); ec=$?
assert_exit_code 3 "$ec" "Exit 3 on empty operand after --"

# Test: Empty operands still count towards the one-operand limit
#bcscheck disable=BCS1005 # operands before any '--' are the subject under test
output=$("$DUX" '' '' "$TEST_DIR" 2>&1); ec=$?
assert_exit_code 2 "$ec" 'Exit 2 when empty operands precede a directory'
output=$("$DUX" '' -- "$TEST_DIR" 2>&1); ec=$?
assert_exit_code 2 "$ec" 'Exit 2 on empty operand plus operand after --'

# Test: Exit 22 on invalid option
output=$("$DUX" --invalid-option 2>&1); ec=$?
assert_exit_code 22 "$ec" 'Exit 22 on invalid option'

# Test: Empty directory shows itself (find returns the dir itself)
# Note: dux always finds at least the target directory, so empty dirs don't error
output=$("$DUX" "$TEST_DIR"/empty-dir 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Empty directory exits 0 (returns itself)'
assert_contains "$output" 'empty-dir' 'Empty dir shows in output'

print_summary
exit $?

#fin
