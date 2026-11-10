#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-check-input.sh - What cmd_check accepts from the environment and argv
#
# A flag that arrives through a BCS_* variable lands in an integer variable,
# and an integer assignment evaluates its value as arithmetic: `true` is an
# unbound variable, and a subscript such as 'a[$(cmd)]' runs cmd. The values
# must be validated first. Operands after `--` are counted, never scanned up
# to the first empty one. A -T filter that names no tier matches no finding,
# and an unknown -M used to be ignored, so both are refused, never applied.
# curl is mocked by check-harness.sh, so nothing is contacted.
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

declare -- CLEAN CORE_FINDING OLLAMA_CLEAN var
declare -a entries=()
CLEAN=$(openai_body 'No BCS violations found.')
# BCS0202 is a core rule, so this answer means exit 1 unless a filter drops it.
CORE_FINDING=$(openai_body '[ERROR] BCS0202 line 8: variable not declared local')
OLLAMA_CLEAN='{"message":{"role":"assistant","content":"No BCS violations found."},
  "prompt_eval_count":10,"eval_count":5}'
readonly CLEAN CORE_FINDING OLLAMA_CLEAN
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

# An unknown -T value equals no finding's tier. Applied as a filter it removed
# every finding, and a script with a core violation was reported clean, exit 0.
# An unknown -M value ranked zero and was ignored. Both are refused; only the
# -T form could ever print the clean line, so only it is checked for that.
begin_test 'invalid tier filters are refused'
for var in BCS_TIER BCS_MIN_TIER; do
  reset_cache
  export "$var"=bogus
  run_check "$CORE_FINDING" -m gpt-5
  unset "$var"
  assert_equal 22 "$RC" "$var=bogus -> invalid argument (22)" ||:
  assert_contains "$ERR" 'Invalid tier' "$var=bogus -> the message says why" ||:
  [[ $var != BCS_TIER ]] \
    || assert_not_contains "$OUT" 'No BCS violations found.' "$var=bogus -> never the clean line" ||:
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
  [[ $var != -T ]] \
    || assert_not_contains "$OUT" 'No BCS violations found.' "$var 'core recommended' -> never the clean line" ||:
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
assert_contains "$OUT" 'BCS0202' 'BCS_TIER=core -> the finding is printed' ||:
reset_cache
run_check "$CORE_FINDING" -m gpt-5 -M recommended
assert_equal 1 "$RC" '-M recommended keeps a core finding -> exit 1' ||:
assert_contains "$OUT" 'BCS0202' '-M recommended -> the finding is printed' ||:
reset_cache
run_check "$CORE_FINDING" -m gpt-5 -T style
assert_equal 0 "$RC" '-T style drops a core finding -> exit 0' ||:
assert_equal 'No BCS violations found.' "$OUT" '-T style -> the clean line, legitimately' ||:
reset_cache
export BCS_TIER=''
run_check "$CORE_FINDING" -m gpt-5
unset BCS_TIER
assert_equal 1 "$RC" 'an empty BCS_TIER is no filter -> exit 1' ||:
assert_contains "$OUT" 'BCS0202' 'an empty BCS_TIER -> the finding is printed' ||:

# ---- Missing tier data ----

# With no data directory there are no tiers to filter by. The documented
# outcome is that every line is kept, not that the check dies without a word.
# -T style on a core finding tells the two apart: with tier data the finding
# is dropped (the test above), without it the finding stays.
begin_test 'tier filter without tier data keeps the findings'
#shellcheck disable=SC2329  # the inner function is called by bcs, inside the check subshell
no_data_dir() { _find_data_dir() { return 1; }; }
PRE_HOOK=no_data_dir
reset_cache
run_check "$CORE_FINDING" -m gpt-5 -T style
PRE_HOOK=:
assert_contains "$OUT" 'BCS0202' 'the finding is printed' ||:
assert_equal 1 "$RC" 'an ERROR finding still means exit 1' ||:

# ---- Model and effort ----

begin_test 'empty model is refused'
reset_cache
run_check "$CLEAN" -m ''
assert_equal 22 "$RC" "-m '' -> invalid argument (22)" ||:
assert_contains "$ERR" 'Model' 'the message names the option' ||:

begin_test 'effort must be one level'
reset_cache
run_check "$CLEAN" -m gpt-5 -e 'low medium'
assert_equal 22 "$RC" "-e 'low medium' -> invalid argument (22)" ||:
reset_cache
export BCS_EFFORT='medium high'
run_check "$CLEAN" -m gpt-5
unset BCS_EFFORT
assert_equal 22 "$RC" "BCS_EFFORT='medium high' -> invalid argument (22)" ||:

# ---- Ollama host ----

# OLLAMA_HOST is host:port, or a base URL with its scheme. curl is mocked: the
# suite only reads the URL it was handed.
begin_test 'OLLAMA_HOST with and without a scheme'
called_url() { tail -n 1 -- "$CURL_ARGV_FILE"; }
for var in ollama.test:11434 http://ollama.test:11434 http://ollama.test:11434/; do
  reset_cache
  export OLLAMA_HOST=$var
  run_check "$OLLAMA_CLEAN" -m qwen3.5:9b
  unset OLLAMA_HOST
  assert_equal http://ollama.test:11434/api/chat "$(called_url)" "OLLAMA_HOST=$var" ||:
done
reset_cache
export OLLAMA_HOST=https://ollama.test
run_check "$OLLAMA_CLEAN" -m qwen3.5:9b
unset OLLAMA_HOST
assert_equal https://ollama.test/api/chat "$(called_url)" 'an https scheme is kept' ||:
assert_equal 0 "$RC" 'the check itself succeeds' ||:

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

# ---- Unreadable cache entry ----

# An entry that exists but cannot be read is no hit. Root reads anything, so
# the fallback itself can only be observed as an ordinary user.
begin_test 'unreadable cache entry falls back to a fresh call'
reset_cache
run_check "$CLEAN" -m gpt-5
entries=("$XDG_CACHE_HOME"/bcs/*)
assert_equal 1 "${#entries[@]}" 'one entry stored' ||:
# Nothing stored means nothing to make unreadable: the assertion above has
# already failed, and an empty array must not abort the suite under set -u.
if ((${#entries[@]} == 1)); then
  chmod -- 000 "${entries[0]}"
  run_check "$CLEAN" -m gpt-5
  chmod -- 600 "${entries[0]}"
  assert_equal 0 "$RC" 'check succeeds' ||:
  assert_equal 'No BCS violations found.' "$OUT" 'the answer is printed' ||:
  if ((EUID)); then
    assert_equal request "$([[ -s $PAYLOAD_FILE ]] && echo request || echo none)" \
      'a fresh request was made' ||:
  fi
fi

# A directory where an entry should be is no hit either. bcs never creates
# one, but reading it yields nothing, and a "hit" skips the write that would
# repair it, so the check would fail the same way on every run.
begin_test 'a directory in place of a cache entry is a miss'
reset_cache
mkdir -p -- "$XDG_CACHE_HOME"/bcs
run_check "$CLEAN" -m gpt-5
entries=("$XDG_CACHE_HOME"/bcs/*)
if ((${#entries[@]} == 1)); then
  rm -f -- "${entries[0]}"
  mkdir -- "${entries[0]}"
  run_check "$CLEAN" -m gpt-5
  assert_equal 0 "$RC" 'check succeeds' ||:
  assert_equal 'No BCS violations found.' "$OUT" 'the answer is printed' ||:
  # The cache write must not move its temp file into that directory.
  entries=("${entries[0]}"/* "${entries[0]}"/.[!.]*)
  assert_equal 0 "${#entries[@]}" 'nothing is written into the directory' ||:
  reset_cache
else
  assert_equal 1 "${#entries[@]}" 'one entry stored' ||:
fi

print_summary 'check-input'
#fin
