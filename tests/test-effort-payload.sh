#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-effort-payload.sh - Verify effort -> API parameter wiring
#
# We source bcs (source guard keeps main() from running) and mock `curl` so
# every _llm_* call captures its outgoing JSON payload to a known file. We
# never actually contact a remote API, so this suite is hermetic and runs
# regardless of whether keys are set.
set -euo pipefail
shopt -s inherit_errexit
# bcs is sourced below and leaves PATH to its caller (BCS1002), so the suite
# sets the value an executed bcs would.
declare -rx PATH=~/.local/bin:/usr/local/bin:/usr/bin:/bin

#shellcheck source-path=SCRIPTDIR source=test-helpers.sh
source "$(dirname "$0")"/test-helpers.sh
#shellcheck source=../bcs disable=SC1091
source "$BCS_CMD"

echo 'Testing: effort -> API parameter wiring'

# ---------------------------------------------------------------------
# Mock curl: read stdin via -d @-, dump body to $PAYLOAD_FILE, then emit
# a minimal "successful" response that satisfies each backend's parser
# (jq -r '.content[0].text', '.choices[0].message.content',
# '.candidates[0].content.parts[0].text', '.message.content') plus a
# trailing HTTP code so the API-failure check passes.
# ---------------------------------------------------------------------
PAYLOAD_FILE=$(mktemp /tmp/bcs-payload.XXXXXX)
trap 'rm -f "$PAYLOAD_FILE"' EXIT

curl() {
  local -- arg body=''
  for arg in "$@"; do
    if [[ $body == '__pending__' ]]; then
      [[ $arg == '@-' ]] && body=$(cat) || body=$arg
      break
    fi
    [[ $arg == '-d' ]] && body='__pending__' ||:
  done
  printf '%s' "$body" > "$PAYLOAD_FILE"
  printf '%s\n200\n' '{"content":[{"text":"[]"}],
                       "choices":[{"message":{"content":"[]"}}],
                       "candidates":[{"content":{"parts":[{"text":"[]"}]}}],
                       "message":{"content":"[]"},
                       "usage":{"input_tokens":1,"output_tokens":1,
                                "prompt_tokens":1,"completion_tokens":1},
                       "usageMetadata":{"promptTokenCount":1,
                                        "candidatesTokenCount":1},
                       "prompt_eval_count":1,"eval_count":1}'
}
export -f curl

# Required env so _llm_* don't bail on key absence.
export ANTHROPIC_API_KEY=test-anthropic
export OPENAI_API_KEY=test-openai
export GOOGLE_API_KEY=test-google

# Suppress info noise from inner calls. Read by bcs's own messaging
# helpers via the sourced script; not unused here.
# shellcheck disable=SC2034
VERBOSE=0

# ---------------------------------------------------------------------
# Helpers: invoke a backend, then assert the captured payload matches a jq
# filter (truthy) or does NOT match (falsy).
# ---------------------------------------------------------------------
run_backend() {
  local -- backend=$1 model=$2 effort=$3
  : > "$PAYLOAD_FILE"
  case $backend in
    anthropic) _llm_anthropic "$model" "$effort" 'sys' 'usr' >/dev/null ;;
    openai)    _llm_openai    "$model" "$effort" 'sys' 'usr' >/dev/null ;;
    google)    _llm_google    "$model" "$effort" 'sys' 'usr' >/dev/null ;;
    ollama)    _llm_ollama    "$model" "$effort" 'sys' 'usr' >/dev/null ;;
  esac
}

# Pretty-print payload truncated to 400 chars on failure for debug.
_dump_payload() { head -c 400 "$PAYLOAD_FILE"; echo; }

assert_payload_match() {
  local -- backend=$1 model=$2 effort=$3 jq_filter=$4 msg=$5
  begin_test "$msg"
  run_backend "$backend" "$model" "$effort"
  if jq -e "$jq_filter" "$PAYLOAD_FILE" &>/dev/null; then
    printf '  %s✓%s %s\n' "$GREEN" "$NC" "$msg"
    TESTS_PASSED+=1
  else
    printf '  %s✗%s %s\n' "$RED" "$NC" "$msg"
    printf '    filter: %s\n' "$jq_filter"
    printf '    payload: '; _dump_payload
    TESTS_FAILED+=1
  fi
}

assert_payload_no_match() {
  local -- backend=$1 model=$2 effort=$3 jq_filter=$4 msg=$5
  begin_test "$msg"
  run_backend "$backend" "$model" "$effort"
  if jq -e "$jq_filter" "$PAYLOAD_FILE" &>/dev/null; then
    printf '  %s✗%s %s (filter unexpectedly matched)\n' "$RED" "$NC" "$msg"
    printf '    filter: %s\n' "$jq_filter"
    printf '    payload: '; _dump_payload
    TESTS_FAILED+=1
  else
    printf '  %s✓%s %s\n' "$GREEN" "$NC" "$msg"
    TESTS_PASSED+=1
  fi
}

# ---------------------------------------------------------------------
# Anthropic thinking comes in two incompatible shapes and each model takes
# exactly one. Probed live 2026-09-18, every row of this matrix verified
# against the API; a model sent the wrong shape answers HTTP 400.
#
#   enabled + budget_tokens : haiku-4-5, sonnet-4-5/4-6, opus-4-5/4-6
#   adaptive + output_config.effort : opus-4-7/4-8, and all of Claude 5
#
# opus-4-6 and sonnet-4-6 accept both; they keep the explicit budget so the
# -e scale stays comparable with the other backends.
# ---------------------------------------------------------------------
assert_payload_match anthropic claude-opus-4-6 high \
  '.thinking.type == "enabled" and .thinking.budget_tokens == 6000' \
  'opus-4-6 -e high -> thinking.budget_tokens=6000, type=enabled'

assert_payload_no_match anthropic claude-opus-4-6 low \
  '.thinking != null' \
  'opus-4-6 -e low -> thinking field omitted (budget=0)'

assert_payload_match anthropic claude-sonnet-4-6 medium \
  '.thinking.type == "enabled" and .thinking.budget_tokens == 2000' \
  'sonnet-4-6 -e medium -> thinking.budget_tokens=2000'

# haiku-4-5 accepts extended thinking; the old gate denied it one.
assert_payload_match anthropic claude-haiku-4-5 max \
  '.thinking.type == "enabled" and .thinking.budget_tokens == 16000' \
  'haiku-4-5 -e max -> thinking.budget_tokens=16000'

assert_payload_match anthropic claude-sonnet-4-5-20250929 medium \
  '.thinking.type == "enabled" and .thinking.budget_tokens == 2000' \
  'sonnet-4-5 -e medium -> thinking.budget_tokens=2000'

# Adaptive models: no budget, and the effort word goes out verbatim -- the
# API accepts exactly BCS's own five levels.
assert_payload_match anthropic claude-opus-4-8 medium \
  '.thinking.type == "adaptive" and .output_config.effort == "medium"' \
  'opus-4-8 (the opus alias) -e medium -> adaptive + effort=medium'

assert_payload_no_match anthropic claude-opus-4-8 medium \
  '.thinking.budget_tokens != null' \
  'opus-4-8 -> no budget_tokens (the API rejects enabled thinking)'

assert_payload_match anthropic claude-opus-4-7 xhigh \
  '.thinking.type == "adaptive" and .output_config.effort == "xhigh"' \
  'opus-4-7 -e xhigh -> adaptive + effort=xhigh'

assert_payload_match anthropic claude-opus-5 low \
  '.thinking.type == "adaptive" and .output_config.effort == "low"' \
  'opus-5 -e low -> adaptive + effort=low'

assert_payload_match anthropic claude-sonnet-5 max \
  '.thinking.type == "adaptive" and .output_config.effort == "max"' \
  'sonnet-5 -e max -> adaptive + effort=max'

assert_payload_match anthropic claude-fable-5-1 high \
  '.thinking.type == "adaptive" and .output_config.effort == "high"' \
  'fable-5-1 -e high -> adaptive + effort=high'

# The family-anchored pattern must not catch a 4.x whose minor is 5.
assert_payload_no_match anthropic claude-haiku-4-5 medium \
  '.thinking.type == "adaptive"' \
  'haiku-4-5 is not a Claude 5 model'

assert_payload_no_match anthropic claude-opus-4-5-20251101 medium \
  '.thinking.type == "adaptive"' \
  'opus-4-5 is not a Claude 5 model'

# An unprobed model gets no thinking field at all, never a guessed shape.
assert_payload_no_match anthropic claude-haiku-3-5 max \
  '.thinking != null or .output_config != null' \
  'unprobed model -> no thinking, no output_config'

# ---------------------------------------------------------------------
# OpenAI: reasoning_effort auto-enabled on gpt-5* and o[0-9]*; omitted
# on gpt-4*/gpt-4.1*/gpt-4o*.
# ---------------------------------------------------------------------
assert_payload_match openai gpt-5 high \
  '.reasoning_effort == "medium"' \
  'gpt-5 -e high -> reasoning_effort=medium'

assert_payload_match openai gpt-5 xhigh \
  '.reasoning_effort == "high"' \
  'gpt-5 -e xhigh -> reasoning_effort=high (saturates)'

assert_payload_match openai o3-mini max \
  '.reasoning_effort == "high"' \
  'o3-mini -e max -> reasoning_effort=high'

assert_payload_no_match openai gpt-4.1-mini high \
  '.reasoning_effort != null' \
  'gpt-4.1-mini -e high -> reasoning_effort omitted'

assert_payload_no_match openai gpt-4o-mini max \
  '.reasoning_effort != null' \
  'gpt-4o-mini -e max -> reasoning_effort omitted'

# OpenAI's json_object mode forbids the top-level array the prompt asks for.
# Left to improvise, the model spells the array as a bare finding, {}, or
# {"0": {...}}; the request therefore names the wrapper to use.
BCS_JSON_MODE=1 assert_payload_match openai gpt-5-mini low \
  '.messages[1].content | contains("{\"findings\": [")' \
  'openai JSON mode -> user prompt names the {"findings": [...]} wrapper'

assert_payload_no_match openai gpt-5-mini low \
  '.messages[1].content | contains("findings")' \
  'openai text mode -> no JSON wrapper instruction'

BCS_JSON_MODE=1 assert_payload_no_match google gemini-2.5-flash low \
  '.contents[0].parts[0].text | contains("findings")' \
  'google JSON mode -> prompt untouched (top-level arrays are allowed there)'

# ---------------------------------------------------------------------
# Google: thinkingConfig.thinkingBudget auto-enabled on *-2.5-* except
# flash-lite.
# ---------------------------------------------------------------------
assert_payload_match google gemini-2.5-pro high \
  '.generationConfig.thinkingConfig.thinkingBudget == 6000' \
  'gemini-2.5-pro -e high -> thinkingConfig.thinkingBudget=6000'

assert_payload_match google gemini-2.5-pro xhigh \
  '.generationConfig.thinkingConfig.thinkingBudget == 12000' \
  'gemini-2.5-pro -e xhigh -> thinkingConfig.thinkingBudget=12000'

assert_payload_no_match google gemini-2.5-flash-lite high \
  '.generationConfig.thinkingConfig != null' \
  'gemini-2.5-flash-lite -e high -> thinkingConfig omitted'

assert_payload_no_match google gemini-2.5-pro low \
  '.generationConfig.thinkingConfig != null' \
  'gemini-2.5-pro -e low -> thinkingConfig omitted (budget=0)'

# Gate follows what the API accepts (probed live 2026-09-17): gemini-3.5-flash
# and gemini-3.5-flash-lite take a positive budget; 3.5-flash-lite answers
# HTTP 400 to budget 0, which the zero-budget skip never sends. No quota to
# probe gemini-3.1-pro-preview, so its budget is omitted (always accepted).
assert_payload_match google gemini-3.5-flash-lite high \
  '.generationConfig.thinkingConfig.thinkingBudget == 6000' \
  'gemini-3.5-flash-lite -e high -> thinkingBudget=6000'

assert_payload_match google gemini-3.5-flash medium \
  '.generationConfig.thinkingConfig.thinkingBudget == 2000' \
  'gemini-3.5-flash -e medium -> thinkingBudget=2000'

assert_payload_no_match google gemini-3.5-flash-lite low \
  '.generationConfig.thinkingConfig != null' \
  'gemini-3.5-flash-lite -e low -> thinkingConfig omitted (budget 0 is HTTP 400)'

assert_payload_no_match google gemini-3.1-pro-preview high \
  '.generationConfig.thinkingConfig != null' \
  'gemini-3.1-pro-preview -e high -> thinkingConfig omitted (unverified)'

# ---------------------------------------------------------------------
# Ollama: options.num_ctx and keep_alive reach both payload branches.
# Without num_ctx the server truncates the prompt to its 4096 default and
# the model never sees the standard.
# ---------------------------------------------------------------------
unset BCS_OLLAMA_NUM_CTX BCS_OLLAMA_KEEP_ALIVE

assert_payload_match ollama qwen3.5:9b medium \
  '.options.num_ctx == 40960 and .options.num_predict == 8000' \
  'ollama text mode -> options.num_ctx=40960 beside num_predict'

assert_payload_match ollama qwen3.5:9b medium \
  '.keep_alive == "30m"' \
  'ollama text mode -> keep_alive=30m'

BCS_JSON_MODE=1 assert_payload_match ollama qwen3.5:9b medium \
  '.format == "json" and .options.num_ctx == 40960 and .keep_alive == "30m"' \
  'ollama JSON mode -> num_ctx and keep_alive present'

BCS_OLLAMA_NUM_CTX=65536 assert_payload_match ollama qwen3.5:9b medium \
  '.options.num_ctx == 65536' \
  'BCS_OLLAMA_NUM_CTX=65536 honoured'

BCS_OLLAMA_KEEP_ALIVE=1h assert_payload_match ollama qwen3.5:9b medium \
  '.keep_alive == "1h"' \
  'BCS_OLLAMA_KEEP_ALIVE=1h honoured (duration string)'

BCS_OLLAMA_KEEP_ALIVE=-1 assert_payload_match ollama qwen3.5:9b medium \
  '.keep_alive == -1' \
  'BCS_OLLAMA_KEEP_ALIVE=-1 sent as a JSON number (seconds)'

begin_test 'invalid BCS_OLLAMA_NUM_CTX rejected'
declare -i NUM_CTX_RC=0
( BCS_OLLAMA_NUM_CTX=lots _llm_ollama qwen3.5:9b medium sys usr ) &>/dev/null || NUM_CTX_RC=$?
assert_equal 22 "$NUM_CTX_RC" 'BCS_OLLAMA_NUM_CTX=lots -> exit 22'

begin_test 'certain prompt truncation is announced'
declare -- BIG_PROMPT='' TRUNCATION_ERR=''
printf -v BIG_PROMPT '%*s' 8000 ''
TRUNCATION_ERR=$(BCS_OLLAMA_NUM_CTX=1024 _llm_ollama qwen3.5:9b medium "$BIG_PROMPT" usr 2>&1 >/dev/null)
assert_contains "$TRUNCATION_ERR" 'BCS_OLLAMA_NUM_CTX' 'prompt larger than num_ctx -> warning names the knob'

# ---------------------------------------------------------------------
# Token budgets (max output) reach every payload regardless of model.
# ---------------------------------------------------------------------
assert_payload_match anthropic claude-haiku-4-5 medium \
  '.max_tokens == 8000' \
  'anthropic max_tokens follows EFFORT_TOKENS[medium]=8000'

assert_payload_match openai gpt-4o medium \
  '.max_completion_tokens == 8000' \
  'openai max_completion_tokens follows EFFORT_TOKENS[medium]=8000'

assert_payload_match google gemini-2.5-flash-lite high \
  '.generationConfig.maxOutputTokens == 24000' \
  'google maxOutputTokens follows EFFORT_TOKENS[high]=24000'

assert_payload_match google gemini-2.5-flash-lite xhigh \
  '.generationConfig.maxOutputTokens == 40000' \
  'google maxOutputTokens follows EFFORT_TOKENS[xhigh]=40000'

assert_payload_match anthropic claude-haiku-4-5 xhigh \
  '.max_tokens == 40000' \
  'anthropic max_tokens follows EFFORT_TOKENS[xhigh]=40000'

assert_payload_match openai gpt-4o xhigh \
  '.max_completion_tokens == 40000' \
  'openai max_completion_tokens follows EFFORT_TOKENS[xhigh]=40000'

print_summary 'effort-payload'
#fin
