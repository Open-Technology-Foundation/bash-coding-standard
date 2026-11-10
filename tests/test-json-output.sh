#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-json-output.sh - Offline unit tests for JSON output helpers
#
# Sources the bcs script to exercise _strip_json_fences and
# _render_json_output directly with canned LLM output. No backend needed.
set -euo pipefail
shopt -s inherit_errexit
# bcs is sourced below and leaves PATH to its caller (BCS1002), so the suite
# sets the value an executed bcs would.
declare -rx PATH=~/.local/bin:/usr/local/bin:/usr/bin:/bin

#shellcheck source-path=SCRIPTDIR source=test-helpers.sh
source "$(dirname "$0")"/test-helpers.sh
#shellcheck source=bcs
source "$BCS_CMD"   # source guard keeps main() from running

# Sourced from a suite, bcs takes SCRIPT_DIR from tests/, so its FHS search
# misses ./data and finds whatever standard is installed on the machine (or
# nothing, on CI). The severity assertions below read real tier data, so pin
# the lookup to the repo under test -- same reason as tests/check-harness.sh.
_find_data_dir() { echo "$DATA_DIR"; }

echo 'Testing: json-output helpers'

# ---- _strip_json_fences ---------------------------------------------------

begin_test 'strip fences: bare array unchanged'
input='[{"line":1,"level":"error","bcsCode":"BCS0101"}]'
assert_equal "$input" "$(_strip_json_fences "$input")"

begin_test 'strip fences: triple-backtick wrapper'
input=$'```\n[{"a":1}]\n```'
assert_equal '[{"a":1}]' "$(_strip_json_fences "$input")"

begin_test 'strip fences: ```json wrapper'
input=$'```json\n[{"a":1}]\n```'
assert_equal '[{"a":1}]' "$(_strip_json_fences "$input")"

begin_test 'strip fences: surrounding whitespace'
input=$'   \n\n[{"a":1}]\n  \n'
assert_equal '[{"a":1}]' "$(_strip_json_fences "$input")"

begin_test 'strip fences: combined json wrapper + whitespace'
input=$'\n\n```json\n[{"x":2}]\n```\n\n'
assert_equal '[{"x":2}]' "$(_strip_json_fences "$input")"

# ---- Tier filters are enforced here, not trusted to the model -------------
# -T/-M are put in the prompt to save output tokens, but a model that ignores
# one must not decide what `-T core` means: `bcs check -j -T core` in a CI gate
# exits on .comments[].level == "error", so a leaked style finding fails a
# build it should have passed. This answer ignores the filter entirely.
declare -r MIXED_TIERS='[{"line":1,"level":"error","bcsCode":"BCS0101","message":"core"},
 {"line":2,"level":"error","bcsCode":"BCS1203","message":"style"},
 {"line":3,"level":"error","bcsCode":"BCS0604","message":"core"},
 {"line":4,"level":"error","bcsCode":"BCS0201","message":"style"}]'

begin_test 'tier filter: -T core keeps only core findings'
out=$(_render_json_output "$MIXED_TIERS" /tmp/x.sh anthropic m low 0 1 core '')
assert_equal 'BCS0101 BCS0604' "$(jq -r '[.comments[].bcsCode] | join(" ")' <<< "$out")" \
  'the two style findings the model kept are dropped' ||:

begin_test 'tier filter: -M recommended drops style only'
out=$(_render_json_output "$MIXED_TIERS" /tmp/x.sh anthropic m low 0 1 '' recommended)
assert_equal 'BCS0101 BCS0604' "$(jq -r '[.comments[].bcsCode] | join(" ")' <<< "$out")" \
  'style dropped, core kept' ||:

begin_test 'tier filter: -M style keeps everything'
out=$(_render_json_output "$MIXED_TIERS" /tmp/x.sh anthropic m low 0 1 '' style)
assert_equal 4 "$(jq -r '.comments | length' <<< "$out")" 'no finding dropped' ||:

begin_test 'tier filter: no filter keeps everything'
out=$(_render_json_output "$MIXED_TIERS" /tmp/x.sh anthropic m low 0 1 '' '')
assert_equal 4 "$(jq -r '.comments | length' <<< "$out")" 'unfiltered by default' ||:

begin_test 'tier filter: a code with no tier survives the filter'
# An invented or section-overview code cannot be classified. Dropping it would
# hide the model misbehaving; the level rule keeps such findings as received,
# and so does this.
out=$(_render_json_output '[{"line":1,"level":"error","bcsCode":"BCS9999","message":"?"}]' \
        /tmp/x.sh anthropic m low 0 1 core '')
assert_equal 'BCS9999' "$(jq -r '[.comments[].bcsCode] | join(" ")' <<< "$out")" \
  'unclassifiable finding is shown, not hidden' ||:

# ---- _render_json_output: happy path -------------------------------------

begin_test 'render: valid bare array wrapped in envelope'
arr='[{"line":4,"endLine":4,"level":"error","code":101,"bcsCode":"BCS0101","tier":"core","message":"m","fixSuggestion":"f"}]'
out=$(_render_json_output "$arr" /tmp/x.sh anthropic claude-haiku-4-5 low 0 12)
if [[ -n $out ]]; then
  assert_equal 'bcs' "$(jq -r '.source' <<< "$out")" 'source=bcs'
  assert_equal '12' "$(jq -r '.meta.elapsed_s' <<< "$out")" 'elapsed_s=12'
  assert_equal 'anthropic' "$(jq -r '.meta.backend' <<< "$out")" 'backend=anthropic'
  assert_equal 'BCS0101' "$(jq -r '.comments[0].bcsCode' <<< "$out")" 'bcsCode=BCS0101'
  assert_equal '/tmp/x.sh' "$(jq -r '.comments[0].file' <<< "$out")" 'file populated'
  assert_equal 'null' "$(jq -r '.comments[0].fix' <<< "$out")" 'fix=null'
  assert_equal '1' "$(jq -r '.comments[0].column' <<< "$out")" 'default column=1'
else
  printf '  %s✗%s render produced no output\n' "$RED" "$NC"
  TESTS_FAILED+=1
fi

begin_test 'render: empty array produces envelope with zero comments'
out=$(_render_json_output '[]' /tmp/x.sh ollama qwen3.5:9b medium 1 7)
if [[ -n $out ]]; then
  assert_equal '0' "$(jq -r '.comments | length' <<< "$out")" 'no comments'
  assert_equal 'true' "$(jq -r '.meta.strict' <<< "$out")" 'strict bool preserved'
else
  printf '  %s✗%s render produced no output\n' "$RED" "$NC"
  TESTS_FAILED+=1
fi

begin_test 'render: fence-wrapped array still works'
fenced=$'```json\n[{"line":1,"level":"warning","bcsCode":"BCS0202","tier":"recommended","message":"x","fixSuggestion":"y"}]\n```'
out=$(_render_json_output "$fenced" /tmp/x.sh google gemini-2.5-flash low 0 5)
if [[ -n $out ]]; then
  assert_equal 'BCS0202' "$(jq -r '.comments[0].bcsCode' <<< "$out")" 'fenced bare array normalized'
else
  printf '  %s✗%s render produced no output\n' "$RED" "$NC"
  TESTS_FAILED+=1
fi

begin_test 'render: object wrapper with findings key is unwrapped'
wrapped='{"findings":[{"line":9,"level":"error","bcsCode":"BCS0303","tier":"core","message":"m","fixSuggestion":"f"}]}'
out=$(_render_json_output "$wrapped" /tmp/x.sh openai gpt-4.1-mini low 0 3)
if [[ -n $out ]]; then
  assert_equal 'BCS0303' "$(jq -r '.comments[0].bcsCode' <<< "$out")" 'findings unwrapped'
else
  printf '  %s✗%s render produced no output\n' "$RED" "$NC"
  TESTS_FAILED+=1
fi

begin_test 'render: default endLine derived from line'
arr='[{"line":7,"level":"warning","bcsCode":"BCS0505","tier":"style","message":"m","fixSuggestion":"f"}]'
out=$(_render_json_output "$arr" /tmp/x.sh ollama qwen low 0 1)
if [[ -n $out ]]; then
  assert_equal '7' "$(jq -r '.comments[0].endLine' <<< "$out")" 'endLine defaults to line'
fi

# ---- _render_json_output: failure cases ----------------------------------

begin_test 'render: invalid JSON returns non-zero'
if _render_json_output 'not json at all' /tmp/x.sh ollama m low 0 1 >/dev/null 2>&1; then
  printf '  %s✗%s expected failure on invalid JSON\n' "$RED" "$NC"
  TESTS_FAILED+=1
else
  printf '  %s✓%s invalid JSON rejected\n' "$GREEN" "$NC"
  TESTS_PASSED+=1
fi

begin_test 'render: empty input returns non-zero'
if _render_json_output '' /tmp/x.sh ollama m low 0 1 >/dev/null 2>&1; then
  printf '  %s✗%s expected failure on empty input\n' "$RED" "$NC"
  TESTS_FAILED+=1
else
  printf '  %s✓%s empty input rejected\n' "$GREEN" "$NC"
  TESTS_PASSED+=1
fi

begin_test 'render: array of objects missing required keys returns non-zero'
bad='[{"line":1,"message":"no bcsCode"}]'
if _render_json_output "$bad" /tmp/x.sh ollama m low 0 1 >/dev/null 2>&1; then
  printf '  %s✗%s expected failure on missing keys\n' "$RED" "$NC"
  TESTS_FAILED+=1
else
  printf '  %s✓%s schema-incomplete array rejected\n' "$GREEN" "$NC"
  TESTS_PASSED+=1
fi

begin_test 'render: object without array field returns non-zero'
bad='{"nothing_useful":"here"}'
if _render_json_output "$bad" /tmp/x.sh ollama m low 0 1 >/dev/null 2>&1; then
  printf '  %s✗%s expected failure on array-less object\n' "$RED" "$NC"
  TESTS_FAILED+=1
else
  printf '  %s✓%s array-less object rejected\n' "$GREEN" "$NC"
  TESTS_PASSED+=1
fi

# OpenAI's json_object mode forbids a top-level array, so the model answers
# with one bare finding object, or with {} when it has nothing to report.
begin_test 'render: bare finding object wrapped into a one-element array'
obj='{"line":8,"endLine":9,"level":"error","code":202,"bcsCode":"BCS0202","tier":"core","message":"m","fixSuggestion":"f"}'
out=$(_render_json_output "$obj" /tmp/x.sh openai gpt-5-mini low 0 3) ||:
assert_equal '1' "$(jq -r '.comments | length' <<< "$out" 2>/dev/null ||:)" 'bare object -> one comment' ||:
assert_equal 'BCS0202' "$(jq -r '.comments[0].bcsCode' <<< "$out" 2>/dev/null ||:)" 'bare object -> bcsCode kept' ||:

begin_test 'render: empty object is an empty findings list'
out=$(_render_json_output '{}' /tmp/x.sh openai gpt-5-mini low 0 3) ||:
assert_equal '0' "$(jq -r '.comments | length' <<< "$out" 2>/dev/null ||:)" '{} -> zero comments' ||:
assert_equal 'bcs' "$(jq -r '.source' <<< "$out" 2>/dev/null ||:)" '{} -> valid envelope' ||:

begin_test 'render: wrapper with an empty array is an empty findings list'
out=$(_render_json_output '{"findings":[]}' /tmp/x.sh openai gpt-5-mini low 0 3) ||:
assert_equal '0' "$(jq -r '.comments | length' <<< "$out" 2>/dev/null ||:)" '{"findings":[]} -> zero comments' ||:

begin_test 'render: array spelled as an object with numeric keys'
num='{"0":{"line":9,"level":"error","bcsCode":"BCS0501"},"1":{"line":12,"level":"warning","bcsCode":"BCS0301"}}'
out=$(_render_json_output "$num" /tmp/x.sh openai gpt-5-mini low 0 3) ||:
assert_equal 'BCS0501 BCS0301' "$(jq -r '[.comments[].bcsCode] | join(" ")' <<< "$out" 2>/dev/null ||:)" \
  '{"0":{..},"1":{..}} -> two comments, in order' ||:
out=$(_render_json_output '{"0":[]}' /tmp/x.sh openai gpt-5-mini low 0 3) ||:
assert_equal '0' "$(jq -r '.comments | length' <<< "$out" 2>/dev/null ||:)" '{"0":[]} -> zero comments' ||:

begin_test 'render: half a finding object is still rejected'
assert_fails 'object with line but no level/bcsCode rejected' \
  _render_json_output '{"line":8,"message":"m"}' /tmp/x.sh openai gpt-5-mini low 0 3 ||:

# ---- envelope shape assertions (shellcheck json1 compatibility) ----------

begin_test 'envelope: top level has source, meta, comments'
arr='[{"line":1,"level":"error","bcsCode":"BCS0101","tier":"core","message":"m","fixSuggestion":"f"}]'
out=$(_render_json_output "$arr" /tmp/x.sh ollama m low 0 1)
keys=$(jq -r 'keys_unsorted | sort | join(",")' <<< "$out")
assert_equal 'comments,meta,source' "$keys" 'envelope keys'

begin_test 'envelope: meta has all expected fields'
arr='[{"line":1,"level":"error","bcsCode":"BCS0101","tier":"core","message":"m","fixSuggestion":"f"}]'
out=$(_render_json_output "$arr" /tmp/x.sh anthropic claude-haiku-4-5 medium 1 42)
meta_keys=$(jq -r '.meta | keys_unsorted | sort | join(",")' <<< "$out")
assert_equal 'backend,effort,elapsed_s,file,model,strict,tool,version' "$meta_keys" 'meta keys'

# ---- severity derived from the tier, not from the model ------------------
# The model is asked to map tier -> level and gets it wrong often enough to
# matter (core findings carried "error" in 32 of 44 sampled). The exit code
# reads .level, so a mislabelled core finding is a silent exit 0. Both fields
# are therefore recomputed locally from the section sources.

begin_test 'severity: core finding mislabelled warning is corrected to error'
arr='[{"line":4,"level":"warning","bcsCode":"BCS0101","tier":"style","message":"m","fixSuggestion":"f"}]'
out=$(_render_json_output "$arr" /tmp/x.sh openai gpt-5-mini medium 0 3)
assert_equal 'error' "$(jq -r '.comments[0].level' <<< "$out")" 'level corrected'
assert_equal 'core' "$(jq -r '.comments[0].tier' <<< "$out")" 'tier corrected'

begin_test 'severity: style finding inflated to error is corrected to warning'
arr='[{"line":9,"level":"error","bcsCode":"BCS1203","tier":"core","message":"m","fixSuggestion":"f"}]'
out=$(_render_json_output "$arr" /tmp/x.sh openai gpt-5-mini medium 0 3)
assert_equal 'warning' "$(jq -r '.comments[0].level' <<< "$out")" 'level corrected'
assert_equal 'style' "$(jq -r '.comments[0].tier' <<< "$out")" 'tier corrected'

begin_test 'severity: recommended stays warning outside strict mode'
arr='[{"line":2,"level":"error","bcsCode":"BCS0605","tier":"core","message":"m","fixSuggestion":"f"}]'
out=$(_render_json_output "$arr" /tmp/x.sh openai gpt-5-mini medium 0 3)
assert_equal 'warning' "$(jq -r '.comments[0].level' <<< "$out")" 'level=warning'
assert_equal 'recommended' "$(jq -r '.comments[0].tier' <<< "$out")" 'tier=recommended'

begin_test 'severity: strict mode raises recommended and style to error'
arr='[{"line":2,"level":"warning","bcsCode":"BCS0605","tier":"recommended","message":"m","fixSuggestion":"f"},
      {"line":9,"level":"warning","bcsCode":"BCS1203","tier":"style","message":"m","fixSuggestion":"f"}]'
out=$(_render_json_output "$arr" /tmp/x.sh openai gpt-5-mini medium 1 3)
assert_equal 'error' "$(jq -r '.comments[0].level' <<< "$out")" 'recommended -> error'
assert_equal 'error' "$(jq -r '.comments[1].level' <<< "$out")" 'style -> error'
assert_equal 'recommended' "$(jq -r '.comments[0].tier' <<< "$out")" 'tier untouched by strict'

begin_test 'severity: unknown code keeps whatever the model said'
arr='[{"line":1,"level":"error","bcsCode":"BCS9999","tier":"core","message":"m","fixSuggestion":"f"}]'
out=$(_render_json_output "$arr" /tmp/x.sh openai gpt-5-mini medium 0 3)
assert_equal 'error' "$(jq -r '.comments[0].level' <<< "$out")" 'level preserved'
assert_equal 'core' "$(jq -r '.comments[0].tier' <<< "$out")" 'tier preserved'

begin_test 'severity: a finding with no tier key gains one'
arr='[{"line":4,"level":"warning","bcsCode":"BCS0101","message":"m","fixSuggestion":"f"}]'
out=$(_render_json_output "$arr" /tmp/x.sh openai gpt-5-mini medium 0 3)
assert_equal 'core' "$(jq -r '.comments[0].tier' <<< "$out")" 'tier added'

begin_test 'severity: a policy-disabled rule is dropped from the output'
# _load_policy reads a cascade of files; _policy_search_paths exists so a test
# can replace it. Point it at a scratch policy and clear the load-once latch.
declare -- POLICY_DIR=''
trap '[[ -z $POLICY_DIR ]] || rm -rf -- "$POLICY_DIR"' EXIT
POLICY_DIR=$(mktemp -d "${TMPDIR:-/tmp}"/bcs-policy.XXXXXX) \
  || die 1 'Failed to create policy sandbox'
printf 'BCS1203 = disabled\n' > "$POLICY_DIR"/policy.conf
_policy_search_paths() { printf '%s\n' "$POLICY_DIR"/policy.conf; }
BCS_POLICY=(); _POLICY_LOADED=0
arr='[{"line":9,"level":"error","bcsCode":"BCS1203","tier":"core","message":"m","fixSuggestion":"f"},
      {"line":4,"level":"warning","bcsCode":"BCS0101","tier":"style","message":"m","fixSuggestion":"f"}]'
out=$(_render_json_output "$arr" /tmp/x.sh openai gpt-5-mini medium 0 3)
assert_equal '1' "$(jq -r '.comments | length' <<< "$out")" 'disabled finding dropped'
assert_equal 'BCS0101' "$(jq -r '.comments[0].bcsCode' <<< "$out")" 'the other one survives'
BCS_POLICY=(); _POLICY_LOADED=0

# ---- _extract_anthropic_text (thinking-block regression, T-01) ------------

begin_test 'extract: thinking block at content[0] is skipped, text returned'
body='{"content":[{"type":"thinking","thinking":"reasoning..."},{"type":"text","text":"[]"}]}'
assert_equal '[]' "$(_extract_anthropic_text <<< "$body")"

begin_test 'extract: multiple text blocks are concatenated in order'
body='{"content":[{"type":"text","text":"foo"},{"type":"text","text":"bar"}]}'
assert_equal 'foobar' "$(_extract_anthropic_text <<< "$body")"

begin_test 'extract: typeless block with .text still extracted (mock-compat)'
body='{"content":[{"text":"hi"}]}'
assert_equal 'hi' "$(_extract_anthropic_text <<< "$body")"

begin_test 'extract: thinking-only body yields empty (guarded as error upstream)'
body='{"content":[{"type":"thinking","thinking":"only thinking"}]}'
assert_equal '' "$(_extract_anthropic_text <<< "$body")"

print_summary 'json-output'
#fin
