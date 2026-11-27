#!/usr/bin/env bash
# Unit tests for locale sensitivity of [:blank:] character class

set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

declare -- TEST_DIR ROOT_DIR
TEST_DIR=$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")") \
  || { >&2 echo "${0##*/}: ✗ cannot resolve test directory"; exit 1; }
ROOT_DIR=${TEST_DIR%/*/*}  # test/<category> -> project root
[[ -f $ROOT_DIR/test/utils.sh ]] || { >&2 echo "${0##*/}: ✗ missing test/utils.sh"; exit 3; }
#shellcheck source=test/utils.sh
source -- "$ROOT_DIR"/test/utils.sh || { >&2 echo "${0##*/}: ✗ cannot source test/utils.sh"; exit 1; }
test_init || { >&2 echo "${0##*/}: ✗ test_init failed"; exit 1; }

# Source all utilities
declare -- lib
for lib in trim ltrim rtrim squeeze trimall; do
  [[ -f $ROOT_DIR/$lib.bash ]] || { >&2 echo "${0##*/}: ✗ missing $lib.bash"; exit 3; }
  #shellcheck disable=SC1090  # path is built from the loop variable; its existence is checked above
  source -- "$ROOT_DIR/$lib".bash || { >&2 echo "${0##*/}: ✗ cannot source $lib.bash"; exit 1; }
done

>&2 echo "Testing locale sensitivity..."

declare -i passed=0 failed=0

# Test trim under LC_ALL=C
test_trim_lc_c() {
  local -- result
  result=$(LC_ALL=C trim "  hello world  ") || fail 'trim exited non-zero'

  if [[ "$result" == "hello world" ]]; then
    echo -e "${GREEN}Test passed${NC}: trim under LC_ALL=C"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: trim under LC_ALL=C (got: ${result@Q})"
    ((++failed))
  fi
}

# Test trim under LC_ALL=en_US.UTF-8 (if available)
test_trim_lc_utf8() {
  if ! locale -a 2>/dev/null | grep -qi 'en_US.utf-\?8'; then
    echo -e "${YELLOW}Skipped${NC}: en_US.UTF-8 locale not available"
    ((++passed))
    return
  fi

  local -- result
  result=$(LC_ALL=en_US.UTF-8 trim "  hello world  ") || fail 'trim exited non-zero'

  if [[ "$result" == "hello world" ]]; then
    echo -e "${GREEN}Test passed${NC}: trim under LC_ALL=en_US.UTF-8"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: trim under LC_ALL=en_US.UTF-8 (got: ${result@Q})"
    ((++failed))
  fi
}

# Verify [:blank:] does NOT match non-breaking space in any locale
test_nbsp_not_trimmed() {
  local -- nbsp=$'\xc2\xa0'  # UTF-8 encoded U+00A0
  local -- input="${nbsp}hello${nbsp}"

  # Under C locale
  local -- result_c
  result_c=$(LC_ALL=C trim "$input") || fail 'trim exited non-zero'
  if [[ "$result_c" == "$input" ]]; then
    echo -e "${GREEN}Test passed${NC}: NBSP not trimmed under LC_ALL=C"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: NBSP trimmed under LC_ALL=C (got: ${result_c@Q})"
    ((++failed))
  fi

  # Under UTF-8 locale (if available)
  if locale -a 2>/dev/null | grep -qi 'en_US.utf-\?8'; then
    local -- result_utf8
    result_utf8=$(LC_ALL=en_US.UTF-8 trim "$input") || fail 'trim exited non-zero'
    if [[ "$result_utf8" == "$input" ]]; then
      echo -e "${GREEN}Test passed${NC}: NBSP not trimmed under LC_ALL=en_US.UTF-8"
      ((++passed))
    else
      >&2 echo -e "${RED}Test failed${NC}: NBSP trimmed under en_US.UTF-8 (got: ${result_utf8@Q})"
      ((++failed))
    fi
  fi
}

# Test consistency across locales: C vs UTF-8 produce same results
test_locale_consistency() {
  if ! locale -a 2>/dev/null | grep -qi 'en_US.utf-\?8'; then
    echo -e "${YELLOW}Skipped${NC}: en_US.UTF-8 locale not available"
    ((++passed))
    return
  fi

  local -- input=$'\t  mixed \t whitespace \t  '

  local -- result_c result_utf8
  result_c=$(LC_ALL=C trim "$input") || fail 'trim exited non-zero'
  result_utf8=$(LC_ALL=en_US.UTF-8 trim "$input") || fail 'trim exited non-zero'

  if [[ "$result_c" == "$result_utf8" ]]; then
    echo -e "${GREEN}Test passed${NC}: trim produces consistent results across locales"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: locale inconsistency (C: ${result_c@Q}, UTF-8: ${result_utf8@Q})"
    ((++failed))
  fi
}

# Test squeeze under different locales
test_squeeze_locale() {
  local -- input="hello    world"

  local -- result_c
  result_c=$(LC_ALL=C squeeze "$input") || fail 'squeeze exited non-zero'

  if [[ "$result_c" == "hello world" ]]; then
    echo -e "${GREEN}Test passed${NC}: squeeze under LC_ALL=C"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: squeeze under LC_ALL=C (got: ${result_c@Q})"
    ((++failed))
  fi
}

# Test trimall under different locales
test_trimall_locale() {
  local -- input="  hello    world  "

  local -- result_c
  result_c=$(LC_ALL=C trimall "$input") || fail 'trimall exited non-zero'

  if [[ "$result_c" == "hello world" ]]; then
    echo -e "${GREEN}Test passed${NC}: trimall under LC_ALL=C"
    ((++passed))
  else
    >&2 echo -e "${RED}Test failed${NC}: trimall under LC_ALL=C (got: ${result_c@Q})"
    ((++failed))
  fi
}

# Run all tests
test_trim_lc_c
test_trim_lc_utf8
test_nbsp_not_trimmed
test_locale_consistency
test_squeeze_locale
test_trimall_locale

echo
echo "=== Summary: $passed passed, $failed failed ==="

if ((failed == 0)); then
  echo "All locale tests passed!"
  exit 0
else
  >&2 echo "Locale tests FAILED"
  exit 1
fi

#fin
