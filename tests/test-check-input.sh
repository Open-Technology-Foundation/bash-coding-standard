#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-check-input.sh - What cmd_check accepts from the environment and argv
#
# A flag that arrives through a BCS_* variable lands in an integer variable,
# and an integer assignment evaluates its value as arithmetic: `true` is an
# unbound variable, and a subscript such as 'a[$(cmd)]' runs cmd. The values
# must be validated first. Operands after `--` are counted, never scanned up
# to the first empty one. A tier filter that names no tier matches no finding,
# so it must be refused, never applied. curl is mocked by check-harness.sh, so
# nothing is contacted.
set -euo pipefail
shopt -s inherit_errexit
# bcs is sourced below and leaves PATH to its caller (BCS1002), so the suite
# sets the value an executed bcs would.
declare -rx PATH=~/.local/bin:/usr/local/bin:/usr/bin:/bin

#shellcheck source-path=SCRIPTDIR source=test-helpers.sh
source -- "$(dirname -- "$0")"/test-helpers.sh
#shellcheck source-path=SCRIPTDIR source=check-harness.sh
source -- "$TEST_DIR"/check-harness.sh

echo 'Testing: cmd_check input validation'

declare -- CLEAN CORE_FINDING var
CLEAN=$(openai_body 'No BCS violations found.')
# BCS0202 is a core rule, so this answer means exit 1 unless a filter drops it.
CORE_FINDING=$(openai_body '[ERROR] BCS0202 line 8: variable not declared local')
readonly CLEAN CORE_FINDING
declare -r MARKER="$SANDBOX"/injected

# ---- Environment flags ----

begin_test 'flag variables are validated'
for var in BCS_STRICT BCS_DEBUG BCS_JSON BCS_SHELLCHECK BCS_CACHE; do
  reset_cache
  export "$var"=true
  run_check "$CLEAN" -m gpt-5
  unset "$var"
  assert_equal 22 "$RC" "$var=true -> invalid argument (22)" ||:
  assert_contains "$ERR" "$var" "$var=true -> the message names the variable" ||:
done

begin_test 'flag variables are never evaluated'
reset_cache
# The array must exist: under set -u an unset name aborts before its subscript runs.
export BCS_STRICT="BASH_VERSINFO[\$(touch -- ${MARKER@Q})]"
run_check "$CLEAN" -m gpt-5
unset BCS_STRICT
assert_equal 22 "$RC" 'subscript payload -> invalid argument (22)' ||:
assert_equal absent "$([[ -e $MARKER ]] && echo created || echo absent)" \
  'subscript payload -> its command never runs' ||:

begin_test 'valid flag values still work'
reset_cache
export BCS_JSON=1 BCS_CACHE=0
run_check "$(openai_body '{"findings": []}')" -m gpt-5
unset BCS_JSON BCS_CACHE
assert_equal 0 "$RC" 'BCS_JSON=1 BCS_CACHE=0 -> exit 0' ||:
# 2>/dev/null ||: output that is not JSON yields '', which fails the comparison
assert_equal bcs "$(jq -r '.source' <<< "$OUT" 2>/dev/null ||:)" 'BCS_JSON=1 -> JSON envelope' ||:
assert_equal 0 "$(cache_count)" 'BCS_CACHE=0 -> nothing cached' ||:

# ---- Tier filters ----

# An unknown tier equals no finding's tier. Applied as a filter it removed
# every finding, and a script with a core violation was reported clean, exit 0.
begin_test 'invalid tier filters are refused'
for var in BCS_TIER BCS_MIN_TIER; do
  reset_cache
  export "$var"=bogus
  run_check "$CORE_FINDING" -m gpt-5
  unset "$var"
  assert_equal 22 "$RC" "$var=bogus -> invalid argument (22)" ||:
  assert_contains "$ERR" 'Invalid tier' "$var=bogus -> the message says why" ||:
  assert_not_contains "$OUT" 'No BCS violations found.' "$var=bogus -> never the clean line" ||:
done
reset_cache
export BCS_TIER=Core
run_check "$CORE_FINDING" -m gpt-5
unset BCS_TIER
assert_equal 22 "$RC" 'BCS_TIER=Core (wrong case) -> invalid argument (22)' ||:
for var in -T -M; do
  reset_cache
  run_check "$CORE_FINDING" -m gpt-5 "$var" 'core recommended'
  assert_equal 22 "$RC" "$var 'core recommended' -> invalid argument (22)" ||:
  assert_not_contains "$OUT" 'No BCS violations found.' "$var 'core recommended' -> never the clean line" ||:
done
reset_cache
export BCS_TIER=bogus
run_check "$CORE_FINDING" -m gpt-5 -j
unset BCS_TIER
assert_equal 22 "$RC" 'BCS_TIER=bogus, JSON mode -> invalid argument (22)' ||:

begin_test 'valid tier filters still filter'
reset_cache
export BCS_TIER=core
run_check "$CORE_FINDING" -m gpt-5
unset BCS_TIER
assert_equal 1 "$RC" 'BCS_TIER=core keeps a core finding -> exit 1' ||:
reset_cache
run_check "$CORE_FINDING" -m gpt-5 -M recommended
assert_equal 1 "$RC" '-M recommended keeps a core finding -> exit 1' ||:
reset_cache
run_check "$CORE_FINDING" -m gpt-5 -T style
assert_equal 0 "$RC" '-T style drops a core finding -> exit 0' ||:
assert_equal 'No BCS violations found.' "$OUT" '-T style -> the clean line, legitimately' ||:
reset_cache
export BCS_TIER=''
run_check "$CORE_FINDING" -m gpt-5
unset BCS_TIER
assert_equal 1 "$RC" 'an empty BCS_TIER is no filter -> exit 1' ||:

# ---- Operands after -- ----

# run_check appends $CHECK_TARGET, so these calls end "... -- <args> TARGET".
begin_test 'operands after --'
reset_cache
run_check "$CLEAN" -m gpt-5 --
assert_equal 0 "$RC" 'one operand after -- -> exit 0' ||:
reset_cache
run_check "$CLEAN" -m gpt-5 -- "$CHECK_TARGET" ''
assert_equal 2 "$RC" 'an empty operand does not hide the ones after it' ||:
assert_contains "$ERR" 'Only one script file allowed' 'second operand rejected by name' ||:

# ---- Partial cache key ----

begin_test 'unreadable input skips the cache'
# cat fails for the key's own call (`cat -- SCRIPT STANDARD`) and nowhere else
#shellcheck disable=SC2329  # the inner cat is called by bcs, inside the check subshell
break_key_cat() { cat() { [[ $# -ne 3 || $1 != -- ]] || return 1; command cat "$@"; }; }
PRE_HOOK=break_key_cat
reset_cache
run_check "$CLEAN" -m gpt-5
PRE_HOOK=:
assert_equal 0 "$RC" 'check still runs' ||:
assert_equal 0 "$(cache_count)" 'no entry written under a partial key' ||:

print_summary 'check-input'
#fin
