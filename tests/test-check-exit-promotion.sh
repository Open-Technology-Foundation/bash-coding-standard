#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-check-exit-promotion.sh - Only a finding tagged [ERROR] promotes exit to 1
#
# Text mode promotes the exit code to 1 when the answer holds an [ERROR]
# finding. The probe is anchored to a finding header, so a sentence that merely
# mentions the tag does not fail a clean script. tests/replay/ holds real
# checker answers saved during the September 2026 audit; the rc in each file
# name is the verdict the probe must reproduce. Before the probe runs, each
# finding header is relabelled from its rule's tier (_relabel_by_tier), so the
# model's own [ERROR]/[WARN] never decides the exit code.
set -euo pipefail
shopt -s inherit_errexit nullglob
# bcs is sourced below and leaves PATH to its caller (BCS1002), so the suite
# sets the value an executed bcs would.
declare -rx PATH=~/.local/bin:/usr/local/bin:/usr/bin:/bin

#shellcheck source-path=SCRIPTDIR source=test-helpers.sh
source "$(dirname "$0")"/test-helpers.sh
#shellcheck source-path=SCRIPTDIR source=check-harness.sh
source "$TEST_DIR"/check-harness.sh

echo 'Testing: text-mode exit promotion'

# probe TEXT -> 1 when TEXT holds an [ERROR] finding, else 0
probe() { _has_error_finding "$1" && echo 1 || echo 0; }

# ---- Replay: every saved answer keeps its verdict ----
declare -- REPLAY_FILE='' WANT=''
declare -a REPLAY_FILES=("$TEST_DIR"/replay/*.rc[01].txt)
begin_test 'replay corpus present'
assert_gt "${#REPLAY_FILES[@]}" 9 "replay corpus has ${#REPLAY_FILES[@]} saved answers" ||:
for REPLAY_FILE in "${REPLAY_FILES[@]}"; do
  begin_test "replay ${REPLAY_FILE##*/}"
  WANT=${REPLAY_FILE%.txt}; WANT=${WANT##*.rc}
  assert_equal "$WANT" "$(probe "$(< "$REPLAY_FILE")")" "replay ${REPLAY_FILE##*/}" ||:
done

# ---- Tier filters are enforced here, not trusted to the model ----
# Same reason as JSON mode: the promotion below reads the text, so a style
# finding the model leaked past `-T core` would turn exit 0 into exit 1.
declare -r MIXED=$'[ERROR] BCS0101 line 1: core rule\n[WARN] BCS1203 line 2: style rule\n[ERROR] BCS0604 line 3: core rule'

begin_test 'tier filter: -T core drops the style finding'
FILTERED=$(_filter_by_tier "$MIXED" core '')
assert_contains "$FILTERED" 'BCS0101' 'core finding kept' ||:
assert_contains "$FILTERED" 'BCS0604' 'second core finding kept' ||:
assert_not_contains "$FILTERED" 'BCS1203' 'style finding the model leaked is dropped' ||:

begin_test 'tier filter: -M recommended drops style only'
assert_not_contains "$(_filter_by_tier "$MIXED" '' recommended)" 'BCS1203' 'style dropped' ||:
assert_contains "$(_filter_by_tier "$MIXED" '' recommended)" 'BCS0101' 'core kept' ||:

begin_test 'tier filter: no filter is a pass-through'
assert_equal "$MIXED" "$(_filter_by_tier "$MIXED" '' '')" 'text unchanged' ||:

begin_test 'tier filter: lines naming no code survive'
assert_equal 'No BCS violations found.' \
  "$(_filter_by_tier 'No BCS violations found.' core '')" 'the clean line is never dropped' ||:

begin_test 'tier filter: an unclassifiable code survives'
assert_contains "$(_filter_by_tier '[ERROR] BCS9999 line 1: invented' core '')" 'BCS9999' \
  'a code with no tier is shown, not hidden' ||:

begin_test 'tier filter: filtering away the ERROR clears the promotion'
assert_equal 0 "$(probe "$(_filter_by_tier $'[ERROR] BCS1203 line 2: style rule' core '')")" \
  'a style-only answer under -T core no longer promotes to exit 1' ||:

# ---- Severity comes from the tier, not from the model's label ----
# JSON mode has derived `level` locally since 2026-09-18; text mode trusted the
# label until 2026-11-26, when a core BCS0406 printed [WARN] exited 0.
begin_test 'relabel: a core finding printed [WARN] becomes [ERROR]'
assert_equal '[ERROR] BCS0406 line 104: strict mode inside the fence block' \
  "$(_relabel_by_tier '[WARN] BCS0406 line 104: strict mode inside the fence block' 0)" \
  'core -> [ERROR]' ||:

begin_test 'relabel: recommended and style findings printed [ERROR] become [WARN]'
assert_equal '[WARN] BCS0109 line 111: end marker' \
  "$(_relabel_by_tier '[ERROR] BCS0109 line 111: end marker' 0)" 'recommended -> [WARN]' ||:
assert_equal '[WARN] BCS0201 line 11: no type separator' \
  "$(_relabel_by_tier '[ERROR] BCS0201 line 11: no type separator' 0)" 'style -> [WARN]' ||:

begin_test 'relabel: --strict makes every tiered finding [ERROR]'
assert_equal '[ERROR] BCS0109 line 111: end marker' \
  "$(_relabel_by_tier '[WARN] BCS0109 line 111: end marker' 1)" 'recommended under --strict' ||:

begin_test 'relabel: the header layouts the backends produce'
assert_equal '- [ERROR] BCS0406 line 3: list item' \
  "$(_relabel_by_tier '- [WARN] BCS0406 line 3: list item' 0)" 'list bullet' ||:
assert_equal '**BCS1005** (Tier: core) — **[ERROR]** — Line 215' \
  "$(_relabel_by_tier '**BCS1005** (Tier: core) — **[WARN]** — Line 215' 0)" 'bold, code first' ||:
assert_equal $'[WARN] BCS0109 line 1: a\n[ERROR] BCS0406 line 2: b' \
  "$(_relabel_by_tier $'[ERROR] BCS0109 line 1: a\n[WARN] BCS0406 line 2: b' 0)" \
  'each line by its own code' ||:

begin_test 'relabel: only the header label is rewritten'
declare -r MENTION='[WARN] BCS0301 line 4: double quotes (would be [ERROR] under --strict)'
assert_equal "$MENTION" "$(_relabel_by_tier "$MENTION" 0)" \
  'style header kept, the later mention left alone' ||:

begin_test 'relabel: no tier, no rewrite'
assert_equal '[WARN] BCS9999 line 1: invented' \
  "$(_relabel_by_tier '[WARN] BCS9999 line 1: invented' 0)" 'an unclassifiable code keeps the label' ||:
assert_equal '[ERROR] line 7: no code at all' \
  "$(_relabel_by_tier '[ERROR] line 7: no code at all' 0)" 'a header naming no code keeps the label' ||:
assert_equal 'No BCS violations found.' "$(_relabel_by_tier 'No BCS violations found.' 0)" \
  'the clean line passes through' ||:
assert_equal 'There are no [ERROR] findings in this script.' \
  "$(_relabel_by_tier 'There are no [ERROR] findings in this script.' 0)" \
  'a sentence that mentions a label is not a header' ||:

begin_test 'relabel: a rule policy.conf disables is dropped'
# check-harness.sh points XDG_CONFIG_HOME into its sandbox, so this is the user
# policy file of the cascade; clear the load-once latch around it.
declare -r POLICY_FILE="$XDG_CONFIG_HOME"/bcs/policy.conf
mkdir -p -- "${POLICY_FILE%/*}" \
  || { >&2 echo "Failed to create ${POLICY_FILE%/*}"; exit 1; }
printf 'BCS0109 = disabled\n' > "$POLICY_FILE" \
  || { >&2 echo "Failed to write ${POLICY_FILE@Q}"; exit 1; }
BCS_POLICY=(); _POLICY_LOADED=0
RELABELLED=$(_relabel_by_tier $'[ERROR] BCS0109 line 111: end marker\n[WARN] BCS0406 line 104: fence' 0)
assert_not_contains "$RELABELLED" 'BCS0109' 'disabled finding dropped' ||:
assert_contains "$RELABELLED" '[ERROR] BCS0406' 'the other finding relabelled' ||:
rm -f -- "$POLICY_FILE" || { >&2 echo "Failed to remove ${POLICY_FILE@Q}"; exit 1; }
BCS_POLICY=(); _POLICY_LOADED=0

# ---- Genuine finding headers, in every layout the backends have produced ----
begin_test 'genuine findings'
assert_equal 1 "$(probe '[ERROR] BCS0101 line 3: strict mode missing')" 'contract format' ||:
assert_equal 1 "$(probe '  [ERROR] BCS0101 line 3: indented')" 'indented' ||:
assert_equal 1 "$(probe '- [ERROR] BCS0101 line 3: list item')" 'list bullet' ||:
assert_equal 1 "$(probe '3. [ERROR] BCS0101 line 3: numbered')" 'numbered list' ||:
assert_equal 1 "$(probe '### [ERROR] BCS0101 line 3')" 'heading' ||:
assert_equal 1 "$(probe '**[ERROR] BCS0102** (Tier: core) — Line 6')" 'bold tag first' ||:
assert_equal 1 "$(probe '**BCS1005** (Tier: core) — **[ERROR]** — Line 215')" 'bold code first' ||:
assert_equal 1 "$(probe '**BCS0409** — Tier: core — [ERROR] — Line 8')" 'code first, plain tag' ||:
assert_equal 1 "$(probe $'[WARN] BCS0301 line 2: quotes\n\n[ERROR] BCS0202 line 8: not local')" \
  'ERROR after other findings' ||:

# ---- Sentences that merely mention the tag ----
begin_test 'prose mentions'
assert_equal 0 "$(probe 'No BCS violations found.')" 'clean line' ||:
assert_equal 0 "$(probe 'There are no [ERROR] findings in this script.')" 'mid-sentence mention' ||:
assert_equal 0 "$(probe 'Severity mapping: core violations are labelled [ERROR].')" 'prompt echo' ||:
assert_equal 0 "$(probe '[WARN] BCS0301 line 4: double quotes (would be [ERROR] under --strict)')" \
  'WARN finding that mentions the tag' ||:
assert_equal 0 "$(probe 'BCS0704 is style tier, so [WARN] applies here, never [ERROR].')" \
  'code-first sentence about a WARN' ||:

# ---- Wiring through cmd_check (curl mocked, OpenAI path) ----
begin_test 'cmd_check wiring'
reset_cache
run_check "$(openai_body 'No BCS violations found.')" -m gpt-5
assert_equal 0 "$RC" 'clean line -> exit 0' ||:
assert_equal 'No BCS violations found.' "$OUT" 'clean line -> printed as the result' ||:
reset_cache
run_check "$(openai_body 'There are no [ERROR] findings in this script.')" -m gpt-5
assert_equal 0 "$RC" 'prose mention -> exit 0' ||:
reset_cache
run_check "$(openai_body '[ERROR] BCS0202 line 8: variable not declared local')" -m gpt-5
assert_equal 1 "$RC" 'genuine ERROR -> exit 1' ||:
run_check '' -m gpt-5
assert_equal 1 "$RC" 'genuine ERROR served from cache -> still exit 1' ||:

begin_test 'cmd_check wiring: severity from the tier'
reset_cache
run_check "$(openai_body '[WARN] BCS0406 line 3: strict mode inside the fence block')" -m gpt-5
assert_equal 1 "$RC" 'core finding printed [WARN] -> exit 1' ||:
assert_contains "$OUT" '[ERROR] BCS0406 line 3' 'and it is shown as [ERROR]' ||:
reset_cache
run_check "$(openai_body '[ERROR] BCS0109 line 1: end marker')" -m gpt-5
assert_equal 0 "$RC" 'recommended finding printed [ERROR] -> exit 0' ||:
assert_contains "$OUT" '[WARN] BCS0109 line 1' 'and it is shown as [WARN]' ||:
run_check '' -m gpt-5
assert_equal 0 "$RC" 'served from cache -> relabelled again, still exit 0' ||:
reset_cache
run_check "$(openai_body '[WARN] BCS0109 line 1: end marker')" -m gpt-5 --strict
assert_equal 1 "$RC" '--strict: a recommended finding -> exit 1' ||:

# ---- Both text-mode prompt builders ask for the clean line ----
begin_test 'clean line in prompts'
reset_cache
run_check "$(openai_body 'No BCS violations found.')" -m gpt-5
assert_contains "$(jq -r '.messages[1].content' "$PAYLOAD_FILE")" \
  'output exactly one line: No BCS violations found.' 'API text prompt asks for the clean line' ||:
reset_cache
MOCK_CLI_OUTPUT='No BCS violations found.'
run_check '' -m claude-code:haiku
assert_equal 0 "$RC" 'CLI backend clean line -> exit 0' ||:
assert_contains "$(< "$CLI_ARGV_FILE")" \
  'output exactly one line: No BCS violations found.' 'CLI text prompt asks for the clean line' ||:
reset_cache
run_check "$(openai_body '[]')" -m gpt-5 -j
assert_not_contains "$(jq -r '.messages[1].content' "$PAYLOAD_FILE")" \
  'No BCS violations found.' 'JSON prompt keeps its own empty-array contract' ||:

# ---- Failure diagnostics: Elapsed once when verbose, still once under -q ----
begin_test 'diagnostics printed once'
elapsed_count() { grep -c 'Elapsed:' <<< "$ERR" ||:; }
#shellcheck disable=SC2034  # read by the messaging helpers of the sourced bcs
verbose_on() { VERBOSE=1; }
reset_cache
PRE_HOOK=verbose_on
run_check "$(openai_body '[ERROR] BCS0202 line 8: variable not declared local')" -m gpt-5
assert_equal 1 "$RC" 'verbose ERROR run -> exit 1' ||:
assert_equal 1 "$(elapsed_count)" 'verbose, exit 1 -> Elapsed printed once' ||:
assert_contains "$ERR" 'Exit: 1' 'verbose, exit 1 -> Exit line present' ||:
reset_cache
run_check "$(openai_body 'No BCS violations found.')" -m gpt-5 --debug
assert_equal 1 "$(elapsed_count)" 'verbose, --debug, exit 0 -> Elapsed printed once' ||:
PRE_HOOK=:
reset_cache
run_check "$(openai_body '[ERROR] BCS0202 line 8: variable not declared local')" -m gpt-5
assert_equal 1 "$(elapsed_count)" 'quiet, exit 1 -> Elapsed still surfaced once' ||:

print_summary 'check-exit-promotion'
#fin
