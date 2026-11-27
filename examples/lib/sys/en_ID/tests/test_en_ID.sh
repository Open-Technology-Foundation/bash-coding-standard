#!/usr/bin/env bash
# Test suite for the en_ID locale.
# Tests the compiled build in ../build by default. Set EN_ID_TEST_INSTALLED=1
# to test the locale installed on this system instead.
# Usage: test_en_ID.sh [CATEGORY|all]
set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

declare -- SCRIPT_PATH
SCRIPT_PATH=$(realpath -- "$0")
declare -r SCRIPT_PATH
declare -r SCRIPT_NAME=${SCRIPT_PATH##*/} TESTS_DIR=${SCRIPT_PATH%/*}
declare -r BUILD_DIR=${TESTS_DIR%/*}/build

declare -ra CATEGORIES=(
  LC_MONETARY LC_NUMERIC LC_TIME LC_TIME_EXT LC_MESSAGES
  LC_PAPER LC_TELEPHONE LC_ADDRESS LC_NAME LC_MEASUREMENT
  LC_CTYPE LC_COLLATE
)

if [[ -t 1 && -t 2 ]]; then
  declare -r RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[1;33m' NC=$'\033[0m'
else
  declare -r RED='' GREEN='' YELLOW='' NC=''
fi

# Every test command runs under this environment; build mode adds LOCPATH.
declare -a LOCALE_ENV=(LC_ALL=en_ID.UTF-8)
declare -i TESTS_PASSED=0 TESTS_FAILED=0

die() {
  local -i code=$1
  local -- msg
  shift
  for msg in "$@"; do >&2 printf '%s: %s\n' "$SCRIPT_NAME" "$msg"; done
  exit "$code"
}

[[ ${EN_ID_TEST_INSTALLED:-0} == [01] ]] \
  || die 22 "EN_ID_TEST_INSTALLED must be 0 or 1, not ${EN_ID_TEST_INSTALLED@Q}"
declare -ri TEST_INSTALLED=${EN_ID_TEST_INSTALLED:-0}

# run_test DESCRIPTION EXPECTED COMMAND [ARG...]
# Runs COMMAND under the locale being tested; standard input reaches COMMAND.
run_test() {
  local -- description=$1 expected=$2 actual
  shift 2
  # stderr is captured so a failing command shows its reason under "Actual:"
  actual=$(env "${LOCALE_ENV[@]}" "$@" 2>&1) ||:
  if [[ $actual == "$expected" ]]; then
    printf 'Testing %s... %sPASSED%s\n' "$description" "$GREEN" "$NC"
    TESTS_PASSED+=1
  else
    printf 'Testing %s... %sFAILED%s\n' "$description" "$RED" "$NC"
    printf '  Expected: %s\n  Actual:   %s\n' "$expected" "$actual"
    TESTS_FAILED+=1
  fi
}

heading() { printf '\n%sTesting %s%s\n' "$YELLOW" "$1" "$NC"; }

test_monetary() {
  heading LC_MONETARY
  run_test 'currency symbol' Rp locale currency_symbol
  run_test int_curr_symbol 'IDR ' locale int_curr_symbol
  run_test mon_decimal_point . locale mon_decimal_point
  run_test mon_thousands_sep , locale mon_thousands_sep
  run_test p_cs_precedes 1 locale p_cs_precedes
  run_test n_cs_precedes 1 locale n_cs_precedes
  run_test n_sign_posn 1 locale n_sign_posn
  run_test frac_digits 2 locale frac_digits
  run_test int_frac_digits 2 locale int_frac_digits
  run_test mon_grouping 3 locale mon_grouping
  run_test p_sign_posn 1 locale p_sign_posn
  run_test p_sep_by_space 0 locale p_sep_by_space
  run_test n_sep_by_space 0 locale n_sep_by_space
  run_test negative_sign - locale negative_sign
}

test_numeric() {
  heading LC_NUMERIC
  run_test decimal_point . locale decimal_point
  run_test thousands_sep , locale thousands_sep
  run_test 'number format' 1,234,567 printf "%'d" 1234567
}

test_time() {
  heading LC_TIME
  run_test 'date format' 2024-01-15 date -d 2024-01-15 +%x
  run_test 'time format' 14:30:45 date -d '2024-01-15 14:30:45' +%X
  run_test 'abbreviated Sunday' Sun date -d 2024-01-07 +%a
  run_test 'abbreviated Monday' Mon date -d 2024-01-08 +%a
  run_test 'full Sunday' Sunday date -d 2024-01-07 +%A
  run_test 'full Monday' Monday date -d 2024-01-08 +%A
  run_test 'abbreviated January' Jan date -d 2024-01-15 +%b
  run_test 'full January' January date -d 2024-01-15 +%B
}

test_time_extended() {
  heading 'LC_TIME Extended'
  run_test first_weekday 2 locale first_weekday
  run_test am_pm 'AM;PM' locale am_pm
  run_test t_fmt_ampm '%I:%M:%S %p' locale t_fmt_ampm
  run_test 'datetime format' 'Mon 2024-01-15 14:30:45' date -d '2024-01-15 14:30:45' +%c
  # ISO 8601 weeks: 7 days, Monday start, week 1 holds the first Thursday
  run_test week-ndays 7 locale week-ndays
  run_test week-1stday 19971130 locale week-1stday
  run_test week-1stweek 4 locale week-1stweek
  run_test date_fmt '%a %Y-%m-%d %T %Z' locale date_fmt
  run_test '12-hour time' '02:30:45 PM' date -d '2024-01-15 14:30:45' +%r
}

test_messages() {
  heading LC_MESSAGES
  run_test yesexpr '^[+1yY]' locale yesexpr
  run_test noexpr '^[-0nN]' locale noexpr
  run_test yesstr yes locale yesstr
  run_test nostr no locale nostr
}

test_paper() {
  heading LC_PAPER
  run_test 'paper height' 297 locale height
  run_test 'paper width' 210 locale width
}

test_telephone() {
  heading LC_TELEPHONE
  run_test tel_int_fmt '+%c %a %l' locale tel_int_fmt
  # Domestic numbers carry the trunk prefix 0
  run_test tel_dom_fmt '(0%a) %l' locale tel_dom_fmt
  run_test int_prefix 62 locale int_prefix
  # Indonesia has no single international prefix; these are the operators' codes
  run_test int_select '001,008,007,009' locale int_select
}

test_address() {
  heading LC_ADDRESS
  run_test country_ab2 ID locale country_ab2
  run_test country_ab3 IDN locale country_ab3
  run_test country_num 360 locale country_num
  run_test country_name Indonesia locale country_name
  run_test country_car RI locale country_car
  run_test lang_name English locale lang_name
  run_test lang_ab en locale lang_ab
  run_test lang_term eng locale lang_term
  run_test lang_lib eng locale lang_lib
  run_test postal_fmt '%f%N%a%N%d%N%b%N%s %h %e %r%N%z %T%N%c%N' locale postal_fmt
}

test_name() {
  heading LC_NAME
  run_test name_fmt '%d%t%g%t%m%t%f' locale name_fmt
}

test_measurement() {
  heading LC_MEASUREMENT
  # 1 is metric
  run_test measurement 1 locale measurement
}

test_ctype() {
  heading LC_CTYPE
  run_test charmap UTF-8 locale charmap
  run_test 'UTF-8 letter class' 1 grep -c '[[:alpha:]]' <<<'é'
}

test_collate() {
  heading LC_COLLATE
  run_test 'collation order' $'a\nA\nb\nB' sort <<<$'B\nb\nA\na'
}

run_category() {
  case $1 in
    LC_MONETARY)    test_monetary ;;
    LC_NUMERIC)     test_numeric ;;
    LC_TIME)        test_time ;;
    LC_TIME_EXT)    test_time_extended ;;
    LC_MESSAGES)    test_messages ;;
    LC_PAPER)       test_paper ;;
    LC_TELEPHONE)   test_telephone ;;
    LC_ADDRESS)     test_address ;;
    LC_NAME)        test_name ;;
    LC_MEASUREMENT) test_measurement ;;
    LC_CTYPE)       test_ctype ;;
    LC_COLLATE)     test_collate ;;
    *)              die 22 "Unknown category ${1@Q}" ;;
  esac
}

main() {
  local -- category=${1:-all} all

  [[ " ${CATEGORIES[*]} all " == *" $category "* ]] \
    || die 22 "Unknown category ${category@Q}" \
              "Usage: $SCRIPT_NAME [CATEGORY|all]" \
              "Categories: ${CATEGORIES[*]}"

  if ((TEST_INSTALLED)); then
    all=$(locale -a) || die 1 'locale -a failed, so installation cannot be checked'
    [[ $all == *en_ID* ]] || die 3 'en_ID is not installed on this system'
    printf 'Testing installed locale en_ID.UTF-8\n'
  else
    [[ -d $BUILD_DIR/en_ID.UTF-8 ]] || die 3 "No build in ${BUILD_DIR@Q}; run 'make compile'"
    LOCALE_ENV+=(LOCPATH="$BUILD_DIR")
    printf 'Testing build %s\n' "$BUILD_DIR/en_ID.UTF-8"
  fi

  if [[ $category == all ]]; then
    for category in "${CATEGORIES[@]}"; do run_category "$category"; done
  else
    run_category "$category"
  fi

  printf '\nPassed: %s%d%s\n' "$GREEN" "$TESTS_PASSED" "$NC"
  printf 'Failed: %s%d%s\n' "$RED" "$TESTS_FAILED" "$NC"
  ((TESTS_FAILED == 0)) || exit 1
}

main "$@"
#fin
