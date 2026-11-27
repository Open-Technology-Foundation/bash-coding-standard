#!/usr/bin/env bash
# Test argument parsing of dux
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
TEST_DIR=$(mktemp -d /tmp/dux-test-args-XXXXXX)
declare -r TEST_DIR
trap 'rm -rf "$TEST_DIR"' EXIT

# Setup test fixtures
mkdir -p "$TEST_DIR"/subdir1 "$TEST_DIR"/subdir2
mkdir -p "$TEST_DIR/path with spaces/nested"
mkdir -p "$TEST_DIR/path'with'quotes"

test_section 'Argument Parsing'

# Test: Combined -hV shows help (first wins)
output=$("$DUX" -hV 2>&1); ec=$?
assert_exit_code 0 "$ec" '-hV exits 0'
assert_contains "$output" 'USAGE' '-hV shows help (first option wins)'

# Test: Combined -Vh shows version (first wins)
output=$("$DUX" -Vh 2>&1); ec=$?
assert_exit_code 0 "$ec" '-Vh exits 0'
assert_contains "$output" "${DUX##*/}" '-Vh shows version (first option wins)'

# Test: Invalid option -z exits 22
output=$("$DUX" -z 2>&1); ec=$?
assert_exit_code 22 "$ec" 'Invalid option -z exits 22'
assert_contains "$output" 'Invalid option' '-z shows error message'

# Test: Invalid long option --invalid exits 22
output=$("$DUX" --invalid 2>&1); ec=$?
assert_exit_code 22 "$ec" 'Invalid option --invalid exits 22'

# Test: Invalid combined option -Lz exits 22
output=$("$DUX" -Lz 2>&1); ec=$?
assert_exit_code 22 "$ec" 'Invalid combined option -Lz exits 22'
assert_contains "$output" 'Invalid option' '-Lz shows error message'

# Test: -L option accepted
output=$("$DUX" -L "$TEST_DIR" 2>&1); ec=$?
assert_exit_code 0 "$ec" '-L option accepted'

# Test: -q option accepted
output=$("$DUX" -q "$TEST_DIR" 2>&1); ec=$?
assert_exit_code 0 "$ec" '-q option accepted'

# Test: --quiet option accepted
output=$("$DUX" --quiet "$TEST_DIR" 2>&1); ec=$?
assert_exit_code 0 "$ec" '--quiet option accepted'

# Test: Combined -Lq works
output=$("$DUX" -Lq "$TEST_DIR" 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Combined -Lq works'

# Test: Combined -qL works
output=$("$DUX" -qL "$TEST_DIR" 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Combined -qL works'

# Test: Too many arguments exits 2
output=$("$DUX" "$TEST_DIR" "$TEST_DIR" 2>&1); ec=$?
assert_exit_code 2 "$ec" 'Too many arguments exits 2'
assert_contains "$output" 'Too many arguments' "Shows 'too many arguments' error"

# Test: -- with no operand defaults to current directory
output=$(cd "$TEST_DIR" && "$DUX" -- 2>&1); ec=$?
assert_exit_code 0 "$ec" '-- with no operand exits 0'
assert_contains "$output" './' '-- with no operand uses current directory'

# Test: -- accepts exactly one operand
output=$("$DUX" -- "$TEST_DIR" 2>&1); ec=$?
assert_exit_code 0 "$ec" '-- with one operand exits 0'
assert_contains "$output" "$TEST_DIR" '-- with one operand uses provided directory'

# Test: -- rejects extra operands
output=$("$DUX" -- "$TEST_DIR" "$TEST_DIR/subdir1" 2>&1); ec=$?
assert_exit_code 2 "$ec" '-- rejects extra operands with exit 2'
assert_contains "$output" 'Too many arguments' '-- with extra operands shows error'

# Test: Relative path argument works
output=$(cd "$TEST_DIR" && "$DUX" ./subdir1 2>&1); ec=$?
# subdir1 has no subdirs, so it finds only itself
assert_success "$ec" 'Relative path ./subdir1 handled'

# Test: Absolute path argument works
output=$("$DUX" "$TEST_DIR" 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Absolute path exits 0'
assert_contains "$output" "$TEST_DIR" 'Absolute path in output'

# Test: Path with spaces works
output=$("$DUX" "$TEST_DIR/path with spaces" 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Path with spaces exits 0'
assert_contains "$output" 'path with spaces' 'Path with spaces in output'

# Test: Path with quotes works
output=$("$DUX" "$TEST_DIR/path'with'quotes" 2>&1); ec=$?
# This directory has no subdirs beyond itself, but find returns the dir itself
assert_success "$ec" 'Path with quotes handled'

# Test: Current directory . works
output=$(cd "$TEST_DIR" && "$DUX" . 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Current directory . exits 0'

# Test: Parent directory .. works
output=$(cd "$TEST_DIR"/subdir1 && "$DUX" .. 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Parent directory .. exits 0'

print_summary
exit $?

#fin
