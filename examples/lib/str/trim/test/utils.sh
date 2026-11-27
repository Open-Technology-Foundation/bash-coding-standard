#!/usr/bin/env bash
#shellcheck disable=SC2034  # colours, FIXTURES_DIR and TMP_DIR are read by the test scripts that source this
# Test helpers for the trim utilities; source it, then call test_init
[[ ${BASH_SOURCE[0]} != "$0" ]] || { >&2 echo "${0##*/}: ✗ must be sourced, not run"; exit 1; }

# Colors for output
declare -- GREEN='\033[0;32m'
declare -- RED='\033[0;31m'
declare -- YELLOW='\033[0;33m'
declare -- NC='\033[0m' # No Color

declare -- FIXTURES_DIR='' TMP_DIR=''

# Set fixture paths and a private temp dir removed on exit; returns 1 on failure
test_init() {
  FIXTURES_DIR=${BASH_SOURCE[0]%/*}/fixtures
  trap cleanup_temp_files EXIT
  TMP_DIR=$(mktemp -d --tmpdir trim-test.XXXXXX) || return 1
}

# Report a failed test step on stderr and return 1, e.g. out=$(cmd) || fail 'cmd failed'
fail() {
  >&2 echo -e "${RED}✗ Test failed${NC}: $*"
  return 1
}

# Function to assert equality
assert_equals() {
  local -- actual=$1 expected=$2 message=${3:-}

  if [[ $actual == "$expected" ]]; then
    echo -e "${GREEN}✓ Test passed${NC}${message:+: $message}"
    return 0
  else
    >&2 echo -e "${RED}✗ Test failed${NC}${message:+: $message}"
    >&2 echo -e "Expected: '$expected'"
    >&2 echo -e "Actual:   '$actual'"
    return 1
  fi
}

# Function to assert file equality
assert_file_equals() {
  local -- actual_file=$1 expected_file=$2 message=${3:-}

  if diff -q -- "$actual_file" "$expected_file" > /dev/null; then
    echo -e "${GREEN}✓ File test passed${NC}${message:+: $message}"
    return 0
  else
    >&2 echo -e "${RED}✗ File test failed${NC}${message:+: $message}"
    >&2 echo "Files differ:"
    # diff exits 1 here by definition; the result is reported by return 1
    >&2 diff -- "$expected_file" "$actual_file" ||:
    return 1
  fi
}

# Function to create a temporary file with content
create_temp_file() {
  local -- content=$1 temp_file
  temp_file=$(mktemp -p "$TMP_DIR") || return 1
  printf '%s' "$content" > "$temp_file" || return 1
  echo "$temp_file"
}

# Function to create a temporary multiline file from stdin
create_temp_multiline_file() {
  local -- temp_file
  temp_file=$(mktemp -p "$TMP_DIR") || return 1
  cat > "$temp_file" || return 1
  echo "$temp_file"
}

# Remove the per-run temp dir (the EXIT trap set by test_init)
cleanup_temp_files() {
  [[ -z ${TMP_DIR:-} ]] || rm -rf -- "$TMP_DIR"
}

#fin
