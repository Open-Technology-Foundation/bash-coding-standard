#!/usr/bin/env bash
# Security tests for command injection prevention

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

# Source trimv for function testing
[[ -f $ROOT_DIR/trimv.bash ]] || { >&2 echo "${0##*/}: ✗ missing trimv.bash"; exit 3; }
#shellcheck source=trimv.bash
source -- "$ROOT_DIR"/trimv.bash || { >&2 echo "${0##*/}: ✗ cannot source trimv.bash"; exit 1; }
# Without trimv defined, every call fails 'command not found' and each rejection test passes falsely
declare -F trimv >/dev/null || { >&2 echo "${0##*/}: ✗ trimv.bash did not define trimv"; exit 1; }

>&2 echo "Testing security: command injection prevention..."

# Track test results
declare -i passed=0 failed=0

# Test that a variable name is rejected
run_rejected_test() {
  local -- varname="$1"
  local -- description="$2"

  if trimv -n "$varname" "test" 2>/dev/null; then
    >&2 echo -e "${RED}✗ SECURITY FAIL${NC}: $description"
    ((++failed))
  else
    echo -e "${GREEN}✓ Test passed${NC}: $description"
    ((++passed))
  fi
}

# Test that a variable name is accepted
run_accepted_test() {
  local -- varname="$1"
  local -- description="$2"

  if trimv -n "$varname" "  test  " 2>/dev/null; then
    echo -e "${GREEN}✓ Test passed${NC}: $description"
    ((++passed))
  else
    >&2 echo -e "${RED}✗ Test failed${NC}: $description"
    ((++failed))
  fi
}

echo "--- Injection Prevention ---"

# Command injection patterns that must be rejected
run_rejected_test 'var; echo x' "Semicolon injection"
run_rejected_test 'var|cat' "Pipe injection"
run_rejected_test 'var&' "Background operator"
run_rejected_test 'var>' "Redirect >"
run_rejected_test 'var<' "Redirect <"
run_rejected_test 'var name' "Space in name"
run_rejected_test '../path' "Path traversal"
run_rejected_test '/path' "Absolute path"
run_rejected_test 'var*' "Glob asterisk"
run_rejected_test 'var?' "Glob question"
run_rejected_test '123var' "Starts with number"
run_rejected_test '-var' "Starts with dash"
# Note: Empty name '' defaults to 'TRIM' via ${2:-TRIM}, which is safe behavior

echo "--- Valid Names ---"

# Valid variable names
run_accepted_test 'myvar' "Simple lowercase"
run_accepted_test 'MYVAR' "Simple uppercase"
run_accepted_test 'my_var' "With underscore"
run_accepted_test '_private' "Leading underscore"
run_accepted_test 'var123' "With numbers"
run_accepted_test '_' "Single underscore"
run_accepted_test 'a' "Single char"

echo "--- Input Content ---"

# Test malicious content in input (should be treated as literal)
#shellcheck disable=SC2016  # the literal $(...) is the attack payload; it must not expand
local_result=$(trimv '  $(echo hacked)  ') || fail 'trimv exited non-zero on the command-substitution payload'
#shellcheck disable=SC2016  # the literal $(...) is the expected output; it must not expand
if [[ "$local_result" == '$(echo hacked)' ]]; then
  echo -e "${GREEN}✓ Test passed${NC}: Command substitution literal"
  ((++passed))
else
  >&2 echo -e "${RED}✗ Test failed${NC}: Command substitution"
  ((++failed))
fi

echo
echo "=== Summary: $passed passed, $failed failed ==="

if ((failed == 0)); then
  echo "All security tests passed!"
  exit 0
else
  >&2 echo "Security tests FAILED"
  exit 1
fi

#fin
