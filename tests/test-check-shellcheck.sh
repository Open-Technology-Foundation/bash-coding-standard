#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-check-shellcheck.sh - Unit tests for shellcheck static-analysis context
#
# Verifies the _run_shellcheck and _render_shellcheck_block helpers and
# that cmd_check's --shellcheck / --no-shellcheck flags parse cleanly.
#
# NOTE: PATH is readonly here (set below, to the value an executed bcs uses),
# so we cannot test the "binary missing" path by manipulating PATH.
# Instead we override the `command` and `shellcheck` builtins as functions,
# following the pattern in test-detect-backend.sh.

set -euo pipefail
shopt -s inherit_errexit
# bcs is sourced below and leaves PATH to its caller (BCS1002), so the suite
# sets the value an executed bcs would.
declare -rx PATH=~/.local/bin:/usr/local/bin:/usr/bin:/bin

#shellcheck source=tests/test-helpers.sh
source "$(dirname "$0")"/test-helpers.sh
#shellcheck source=bcs
source "$BCS_CMD"   # source guard keeps main() from running

echo 'Testing: shellcheck static-analysis context'

# Mocks: intercept `command -v shellcheck` and the `shellcheck` invocation.
shellcheck_absent() {
  # SC2329: command() is invoked indirectly when cmd_check runs `command -v shellcheck`.
  #shellcheck disable=SC2329
  command() { [[ $1 == -v && $2 == shellcheck ]] && return 1; builtin command "$@"; }
}
shellcheck_present_findings() {
  #shellcheck disable=SC2329  # invoked indirectly, through the mocked command lookup
  command() { [[ $1 == -v && $2 == shellcheck ]] && { echo /fake/shellcheck; return 0; }; builtin command "$@"; }
  shellcheck() {
    echo '[{"file":"s.sh","line":1,"column":1,"level":"warning","code":2086,"message":"stub"}]'
    return 1
  }
}
shellcheck_present_parse_error() {
  #shellcheck disable=SC2329  # invoked indirectly, through the mocked command lookup
  command() { [[ $1 == -v && $2 == shellcheck ]] && { echo /fake/shellcheck; return 0; }; builtin command "$@"; }
  shellcheck() { echo 'parse error' >&2; return 2; }
}
shellcheck_real() { unset -f command shellcheck 2>/dev/null ||:; }

# --- _render_shellcheck_block: empty inputs ---------------------------------

begin_test '_render_shellcheck_block returns empty for empty JSON'
block=$(_render_shellcheck_block '' || true)
assert_equal '' "$block"

begin_test '_render_shellcheck_block returns empty for [] JSON'
block=$(_render_shellcheck_block '[]' || true)
assert_equal '' "$block"

# --- _render_shellcheck_block: non-empty JSON --------------------------------

begin_test '_render_shellcheck_block renders heading for non-empty JSON'
sample='[{"file":"x.sh","line":4,"column":8,"level":"warning","code":2086,"message":"Double quote to prevent globbing"}]'
block=$(_render_shellcheck_block "$sample")
assert_contains "$block" '## Static analysis context'
assert_contains "$block" 'do not re-emit them as'
assert_contains "$block" '```json'
assert_contains "$block" '2086'

# --- _run_shellcheck: missing binary -----------------------------------------

begin_test '_run_shellcheck returns empty when shellcheck missing'
shellcheck_absent
sample_script=$(mktemp --suffix=.sh)
echo '#!/bin/bash' > "$sample_script"
# VERBOSE=0 silences the info() call so stderr stays out of output capture.
output=$(VERBOSE=0 _run_shellcheck "$sample_script" 2>/dev/null)
assert_equal '' "$output"
rm -f "$sample_script"
shellcheck_real

# --- _run_shellcheck: stub binary returning findings (exit 1) ----------------

begin_test '_run_shellcheck captures stub JSON with exit 1'
shellcheck_present_findings
sample_script=$(mktemp --suffix=.sh)
echo '#!/bin/bash' > "$sample_script"
output=$(_run_shellcheck "$sample_script" 2>/dev/null)
assert_contains "$output" '2086'
assert_contains "$output" 'stub'
rm -f "$sample_script"
shellcheck_real

# --- _run_shellcheck: stub binary failing (exit >= 2) ------------------------

begin_test '_run_shellcheck returns empty on shellcheck parse failure (exit 2)'
shellcheck_present_parse_error
sample_script=$(mktemp --suffix=.sh)
echo '#!/bin/bash' > "$sample_script"
output=$(_run_shellcheck "$sample_script" 2>/dev/null)
assert_equal '' "$output"
rm -f "$sample_script"
shellcheck_real

# --- CLI flag plumbing (parser smoke tests) ----------------------------------

begin_test '--shellcheck flag accepted at argparse stage'
assert_success '--shellcheck accepted' "$BCS_CMD" check --shellcheck -h

begin_test '--no-shellcheck flag accepted at argparse stage'
assert_success '--no-shellcheck accepted' "$BCS_CMD" check --no-shellcheck -h

begin_test 'check help mentions --shellcheck'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_contains "$output" '--shellcheck' 'help mentions --shellcheck'

begin_test 'check help mentions --no-shellcheck'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_contains "$output" '--no-shellcheck' 'help mentions --no-shellcheck'

begin_test 'check help mentions BCS_SHELLCHECK env var'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_contains "$output" 'BCS_SHELLCHECK' 'help mentions BCS_SHELLCHECK'

print_summary 'check-shellcheck'
#fin
