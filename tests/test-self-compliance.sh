#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-self-compliance.sh - Verify bcs script follows its own standard
set -euo pipefail
shopt -s inherit_errexit
#shellcheck source-path=SCRIPTDIR source=test-helpers.sh
source "$(dirname "$0")"/test-helpers.sh

echo 'Testing: self-compliance'

# Test: shellcheck passes
begin_test 'bcs passes shellcheck'
if shellcheck -x "$BCS_CMD" 2>/dev/null; then
  printf '  %s✓%s shellcheck clean\n' "$GREEN" "$NC"
  TESTS_PASSED+=1
else
  printf '  %s✗%s shellcheck has findings\n' "$RED" "$NC"
  TESTS_FAILED+=1
fi

# Test: bcscheck passes shellcheck
begin_test 'bcscheck passes shellcheck'
if shellcheck -x "$PROJECT_DIR"/bcscheck 2>/dev/null; then
  printf '  %s✓%s bcscheck shellcheck clean\n' "$GREEN" "$NC"
  TESTS_PASSED+=1
else
  printf '  %s✗%s bcscheck shellcheck has findings\n' "$RED" "$NC"
  TESTS_FAILED+=1
fi

# Test: bcs has shebang (any of 3 BCS0102-valid forms)
begin_test 'bcs has proper shebang'
declare -- first_line
IFS= read -r first_line < "$BCS_CMD"
assert_matches "$first_line" '^#!(/usr)?/bin/(env )?bash$' 'BCS0102-valid shebang' || true

# Test: bcs has set -euo pipefail
begin_test 'bcs has strict mode'
declare -- strict_mode
strict_mode=$(grep -c 'set -euo pipefail' "$BCS_CMD" || true)
assert_gt "$strict_mode" 0 'has set -euo pipefail' || true

# Test: bcs has shopt
begin_test 'bcs has shopt settings'
declare -- shopt_line
shopt_line=$(grep -c 'shopt -s inherit_errexit' "$BCS_CMD" || true)
assert_gt "$shopt_line" 0 'has inherit_errexit' || true

# Test: bcs has VERSION
begin_test 'bcs has VERSION declaration'
declare -- version_line
version_line=$(grep -c 'VERSION=' "$BCS_CMD" || true)
assert_gt "$version_line" 0 'has VERSION' || true

# Test: bcs has SCRIPT_PATH
begin_test 'bcs has SCRIPT_PATH'
declare -- path_line
path_line=$(grep -c 'SCRIPT_PATH=' "$BCS_CMD" || true)
assert_gt "$path_line" 0 'has SCRIPT_PATH equivalent' || true

# Test: bcs ends with #fin
begin_test 'bcs ends with #fin'
declare -- last_line
last_line=$(tail -1 "$BCS_CMD")
assert_equal '#fin' "$last_line" 'ends with #fin' || true

# Test: bcs has main function
begin_test 'bcs has main function'
declare -- main_fn
main_fn=$(grep -c '^main()' "$BCS_CMD" || true)
assert_gt "$main_fn" 0 'has main() function' || true

# Test: bcs invokes main "$@"
begin_test 'bcs invokes main "$@"'
declare -- main_call
main_call=$(grep -c 'main "$@"' "$BCS_CMD" || true)
assert_gt "$main_call" 0 'has main "$@" invocation' || true

# Test: bcs has color definitions
begin_test 'bcs has color definitions'
declare -- color_count
color_count=$(grep -c 'RED=\|GREEN=\|NC=' "$BCS_CMD" || true)
assert_gt "$color_count" 1 'has color definitions' || true

# Test: bcs uses messaging functions
begin_test 'bcs has messaging functions'
declare -- msg_count
msg_count=$(grep -c '_msg\|info()\|error()\|die()' "$BCS_CMD" || true)
assert_gt "$msg_count" 3 'has messaging functions' || true

# Test: BCS_SEARCH_PATHS shared array exists
begin_test 'bcs has BCS_SEARCH_PATHS array'
declare -- paths_count
paths_count=$(grep -c 'BCS_SEARCH_PATHS' "$BCS_CMD" || true)
assert_gt "$paths_count" 2 'BCS_SEARCH_PATHS declared and referenced' || true

# Test: cmd_check has cleanup trap
begin_test 'cmd_check has cleanup trap'
declare -- trap_count
trap_count=$(grep -c 'trap.*RETURN' "$BCS_CMD" || true)
assert_gt "$trap_count" 0 'has trap RETURN for cleanup' || true

# Test: noarg() function exists
begin_test 'bcs has noarg function'
declare -- noarg_count
noarg_count=$(grep -c 'noarg()' "$BCS_CMD" || true)
assert_gt "$noarg_count" 0 'has noarg() function' || true

# Test: parsed flags are frozen once the parse loop is done (BCS0403)
begin_test 'bcs freezes its parsed flags'
declare -- readonly_count
readonly_count=$(grep -c -E '^  readonly [A-Za-z_ ]+$' "$BCS_CMD" || true)
assert_gt "$readonly_count" 4 'a readonly line follows each subcommand parse loop' || true

# Test: a sourcing suite keeps its own PATH (BCS1002: only the executable sets it)
begin_test 'sourcing bcs leaves the caller PATH alone'
declare -- path_state
#shellcheck disable=SC2016  # $PATH and $1 are for the inner bash, not this shell
path_state=$(bash -c 'before=$PATH; source "$1"; [[ $PATH == "$before" ]] && PATH=$PATH && echo untouched' \
  _ "$BCS_CMD" 2>/dev/null || echo changed)
assert_equal untouched "$path_state" 'PATH neither replaced nor made readonly' || true

# Test: line count is reasonable
begin_test 'bcs line count is reasonable'
declare -i bcs_lines
bcs_lines=$(wc -l < "$BCS_CMD")
if ((bcs_lines >= 400 && bcs_lines <= 2400)); then
  printf '  %s✓%s line count %d in range [400-2400]\n' "$GREEN" "$NC" "$bcs_lines"
  TESTS_PASSED+=1
else
  printf '  %s✗%s line count %d outside range [400-2400]\n' "$RED" "$NC" "$bcs_lines"
  TESTS_FAILED+=1
fi

print_summary 'self-compliance'
#fin
