#!/bin/bash
# Comprehensive functional test suite for stopwords
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

# Script metadata (error() is not defined yet, so the failure message is inline)
declare -- SCRIPT_PATH
SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}") \
  || { >&2 echo 'functional_tests.sh: cannot resolve script path'; exit 1; }
readonly SCRIPT_PATH
declare -r SCRIPT_NAME=${SCRIPT_PATH##*/} SCRIPT_DIR=${SCRIPT_PATH%/*}
declare -r LIB_DIR=${SCRIPT_DIR%/*}
declare -r STOPWORDS_BIN="$LIB_DIR/stopwords"

# Colour only when both streams are terminals (BCS0105), so redirected
# output never carries escape codes
if [[ -t 1 && -t 2 ]]; then
  declare -r RED=$'\033[0;31m' GREEN=$'\033[0;32m' BLUE=$'\033[0;34m' NC=$'\033[0m'
else
  declare -r RED='' GREEN='' BLUE='' NC=''
fi

declare -i TESTS_RUN=0
declare -i TESTS_PASSED=0
declare -i TESTS_FAILED=0

# Stdout of the last run_bin call
declare -- ACTUAL=''

# Scratch files for tests that need them. cleanup() reads a global because a
# test function's locals are gone by the time the EXIT trap fires
declare -- TEMP_DIR=''
cleanup() {
  local -i exitcode=${1:-$?}
  trap - EXIT
  [[ -z $TEMP_DIR ]] || rm -rf -- "$TEMP_DIR"
  exit "$exitcode"
}
trap 'cleanup $?' EXIT

error() {
  local -- msg
  for msg in "$@"; do
    >&2 printf '%s: %s\n' "$SCRIPT_NAME" "$msg"
  done
}

print_header() {
  printf '%s%s%s\n' "$BLUE" "$1" "$NC"
}

print_success() {
  printf '%s✓ %s%s\n' "$GREEN" "$1" "$NC"
}

print_failure() {
  printf '%s✗ %s%s\n' "$RED" "$1" "$NC"
}

assert_equals() {
  local -- expected=$1
  local -- actual=$2
  local -- test_name=$3

  TESTS_RUN+=1

  if [[ $actual == "$expected" ]]; then
    print_success "$test_name"
    TESTS_PASSED+=1
    return 0
  else
    print_failure "$test_name"
    error "  Expected: ${expected@Q}"
    error "  Actual:   ${actual@Q}"
    TESTS_FAILED+=1
    return 1
  fi
}

assert_contains() {
  local -- haystack=$1
  local -- needle=$2
  local -- test_name=$3

  TESTS_RUN+=1

  if [[ $haystack == *"$needle"* ]]; then
    print_success "$test_name"
    TESTS_PASSED+=1
    return 0
  else
    print_failure "$test_name"
    error "  Haystack: ${haystack@Q}"
    error "  Needle:   ${needle@Q}"
    TESTS_FAILED+=1
    return 1
  fi
}

assert_exit_code() {
  local -i expected=$1
  local -i actual=$2
  local -- test_name=$3

  TESTS_RUN+=1

  if ((actual == expected)); then
    print_success "$test_name"
    TESTS_PASSED+=1
    return 0
  else
    print_failure "$test_name"
    error "  Expected exit code: $expected"
    error "  Actual exit code:   $actual"
    TESTS_FAILED+=1
    return 1
  fi
}

# Record a pass or a failure for a check that is not an assert_* call
pass() {
  print_success "$1"
  TESTS_RUN+=1
  TESTS_PASSED+=1
}

fail() {
  print_failure "$1"
  shift
  error "$@"
  TESTS_RUN+=1
  TESTS_FAILED+=1
  return 1
}

# Run the binary under test, capturing stdout in ACTUAL. A non-zero exit is
# recorded as a failed test of its own, so a crash cannot pass a test that
# only checks for the absence of something
run_bin() {
  local -i rc=0
  ACTUAL=$("$STOPWORDS_BIN" "$@") || rc=$?
  ((rc)) || return 0
  TESTS_RUN+=1
  TESTS_FAILED+=1
  print_failure "stopwords ${*@Q} exited with status $rc"
  return 1
}

test_basic_filtering() {
  print_header 'Testing basic filtering'

  local -- input='the quick brown fox jumps over the lazy dog'
  local -- expected='quick brown fox jumps lazy dog'
  run_bin "$input" || return 1

  assert_equals "$expected" "$ACTUAL" 'Basic English stopword filtering'
}

test_stdin_input() {
  print_header 'Testing stdin input'

  local -- input='the quick brown fox'
  local -- expected='quick brown fox'
  run_bin <<< "$input" || return 1

  assert_equals "$expected" "$ACTUAL" 'Stdin input'
}

test_punctuation() {
  print_header 'Testing punctuation handling'

  local -- input='Hello, world! How are you?'
  local -- expected='hello world'
  run_bin "$input" || return 1
  assert_equals "$expected" "$ACTUAL" 'Default punctuation removal' ||:

  # With -p, punctuation stays attached, so 'you?' doesn't match stopword 'you'
  expected='hello, world! you?'
  run_bin -p "$input" || return 1
  assert_equals "$expected" "$ACTUAL" 'Keep punctuation with -p flag'
}

test_list_output() {
  print_header 'Testing list output (-w flag)'

  local -- input='the quick brown fox'
  local -- expected=$'quick\nbrown\nfox'
  run_bin -w "$input" || return 1

  assert_equals "$expected" "$ACTUAL" 'List output format'
}

test_word_counting() {
  print_header 'Testing word counting (-c flag)'

  local -- input='quick brown fox quick brown quick'
  run_bin -c "$input" || return 1

  assert_contains "$ACTUAL" '3 quick' "Count for 'quick'" ||:
  assert_contains "$ACTUAL" '2 brown' "Count for 'brown'" ||:
  assert_contains "$ACTUAL" '1 fox' "Count for 'fox'"
}

test_language_selection() {
  print_header 'Testing language selection (-l flag)'

  local -- input='el rápido zorro marrón'
  run_bin -l spanish "$input" || return 1

  # 'el' is a Spanish stopword, not an English one
  [[ $ACTUAL != *el* ]] \
    || { fail 'Spanish stopword filtering' "  'el' should have been filtered"; return 1; }
  pass 'Spanish stopword filtering'
}

test_indonesian_language() {
  print_header 'Testing Indonesian language'

  local -- input='yang ini adalah contoh teks dalam bahasa indonesia'
  local -- expected='contoh teks bahasa indonesia'
  run_bin -l indonesian "$input" || return 1

  assert_equals "$expected" "$ACTUAL" 'Indonesian stopword filtering'
}

test_empty_input() {
  print_header 'Testing empty input'

  local -- actual
  local -i exit_code=0

  actual=$(echo '' | "$STOPWORDS_BIN") || exit_code=$?

  assert_equals '' "$actual" 'Empty input produces empty output' ||:
  assert_exit_code 0 "$exit_code" 'Empty input exits with 0'
}

test_version_flag() {
  print_header 'Testing version flag'

  run_bin -V || return 1

  assert_contains "$ACTUAL" '1.2.0' 'Version output contains version number'
}

test_help_flag() {
  print_header 'Testing help flag'

  run_bin -h || return 1

  assert_contains "$ACTUAL" 'Usage:' 'Help output contains usage' ||:
  assert_contains "$ACTUAL" 'Examples:' 'Help output contains examples'
}

test_combined_flags() {
  print_header 'Testing combined short flags'

  local -- input='the quick brown fox'
  local -- expected=$'quick\nbrown\nfox'

  # -wp: list output and keep punctuation, given as one bundled argument
  run_bin -wp "$input" || return 1
  assert_equals "$expected" "$ACTUAL" 'Combined flags work correctly'
}

test_case_insensitivity() {
  print_header 'Testing case insensitivity'

  local -- input='The QUICK Brown FOX'
  local -- expected='quick brown fox'
  run_bin "$input" || return 1

  assert_equals "$expected" "$ACTUAL" 'Case insensitive processing'
}

test_possessive_handling() {
  print_header 'Testing possessive handling'

  local -- input="John's car is fast"
  run_bin "$input" || return 1

  assert_contains "$ACTUAL" 'john' "Possessive 's handled" ||:
  assert_contains "$ACTUAL" 'car' 'Word after possessive preserved' ||:
  assert_contains "$ACTUAL" 'fast' 'Remaining words preserved'
}

test_special_characters() {
  print_header 'Testing special characters'

  local -- input='data@processing #algorithm'
  run_bin "$input" || return 1

  # Punctuation is removed by default
  [[ $ACTUAL != *@* ]] \
    || { fail 'Special character removal' "  '@' should have been removed"; return 1; }
  pass 'Special character removal'
}

test_invalid_language() {
  print_header 'Testing invalid language fallback'

  local -- input='the quick brown fox'

  # A warning on stderr, then English filtering
  run_bin -l nonexistent "$input" 2>/dev/null || return 1

  [[ -n $ACTUAL ]] \
    || { fail 'Invalid language fallback' '  Should fall back to English'; return 1; }
  pass 'Invalid language fallback to English'
}

test_multiline_input() {
  print_header 'Testing multiline input'

  local -- input=$'the quick brown fox\njumps over the lazy dog'
  local -- expected='quick brown fox jumps lazy dog'
  run_bin "$input" || return 1

  assert_equals "$expected" "$ACTUAL" 'Multiline input processing'
}

test_multiple_spaces() {
  print_header 'Testing multiple spaces'

  local -- input='the    quick     brown    fox'
  local -- expected='quick brown fox'
  run_bin "$input" || return 1

  assert_equals "$expected" "$ACTUAL" 'Multiple spaces handled correctly'
}

# Build an NLTK data directory whose english list makes 'quick' a stopword.
# Called as `make_nltk_decoy || ...`, where set -e is off, so every step
# is checked
make_nltk_decoy() {
  TEMP_DIR=$(mktemp -d) || return
  mkdir -p -- "$TEMP_DIR"/corpora/stopwords || return
  printf '%s\n' the quick > "$TEMP_DIR"/corpora/stopwords/english
}

test_bundled_data_first() {
  print_header 'Testing bundled data takes precedence over NLTK data'

  make_nltk_decoy \
    || { fail 'Bundled data first' '  Cannot build the decoy NLTK data'; return 1; }

  # Were the decoy used, 'quick' would be filtered out
  NLTK_DATA=$TEMP_DIR run_bin 'the quick brown fox' || return 1
  assert_equals 'quick brown fox' "$ACTUAL" 'Bundled data takes precedence over NLTK_DATA'
}

test_binary_exists() {
  print_header 'Testing stopwords binary exists'

  if [[ -x $STOPWORDS_BIN ]]; then
    pass 'Stopwords binary exists and is executable'
  else
    fail 'Stopwords binary not found or not executable' "  Expected at: $STOPWORDS_BIN"
  fi
}

main() {
  print_header 'Stopwords Functional Test Suite'
  echo

  # A failing test returns 1; carry on so the summary reports every
  # failure, and let TESTS_FAILED decide the exit status
  local -- test_fn
  for test_fn in test_binary_exists test_basic_filtering test_stdin_input \
                 test_punctuation test_list_output test_word_counting \
                 test_language_selection test_indonesian_language test_empty_input \
                 test_version_flag test_help_flag test_combined_flags \
                 test_case_insensitivity test_possessive_handling \
                 test_special_characters test_invalid_language \
                 test_multiline_input test_multiple_spaces \
                 test_bundled_data_first; do
    "$test_fn" ||:
  done

  echo
  print_header 'Test Summary'
  printf '  Total tests:  %d\n' "$TESTS_RUN"
  printf '  %sPassed:       %d%s\n' "$GREEN" "$TESTS_PASSED" "$NC"
  printf '  %sFailed:       %d%s\n' "$RED" "$TESTS_FAILED" "$NC"

  echo
  if ((TESTS_FAILED == 0)); then
    print_success 'All tests passed!'
    return 0
  else
    print_failure 'Some tests failed!'
    return 1
  fi
}

main "$@"

#fin
