#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-check-empty-content.sh - An empty LLM completion is an anomaly, never a pass
#
# A backend that answers HTTP 200 with no text (output budget spent on
# reasoning, safety block, refusal) must end in exit 5 and must not be cached.
# We source bcs and shadow `curl` with a shell function that replays a canned
# body, so every backend code path runs without contacting anything. The API
# keys below are dummies.
set -euo pipefail
shopt -s inherit_errexit
# bcs is sourced below and leaves PATH to its caller (BCS1002), so the suite
# sets the value an executed bcs would.
declare -rx PATH=~/.local/bin:/usr/local/bin:/usr/bin:/bin

#shellcheck source-path=SCRIPTDIR source=test-helpers.sh
source "$(dirname "$0")"/test-helpers.sh
#shellcheck source-path=SCRIPTDIR source=check-harness.sh
source "$TEST_DIR"/check-harness.sh

echo 'Testing: empty LLM completion handling'

# Canned bodies: HTTP 200, well-formed, no text.
declare -r OPENAI_EMPTY='{"choices":[{"message":{"role":"assistant"},"finish_reason":"length"}],
  "usage":{"prompt_tokens":31000,"completion_tokens":0}}'
declare -r GOOGLE_EMPTY='{"candidates":[{"content":{"role":"model"},"finishReason":"SAFETY"}],
  "usageMetadata":{"promptTokenCount":31000,"candidatesTokenCount":0}}'
declare -r ANTHROPIC_EMPTY='{"content":[{"type":"thinking","thinking":"..."}],
  "usage":{"input_tokens":31000,"output_tokens":5}}'
declare -r OLLAMA_EMPTY='{"message":{"role":"assistant","content":""},
  "prompt_eval_count":31000,"eval_count":0}'
declare -r FINDING='[WARN] BCS0202 line 8: variable not declared local'
declare -r OPENAI_OK='{"choices":[{"message":{"content":"[WARN] BCS0202 line 8: variable not declared local"},
  "finish_reason":"stop"}],"usage":{"prompt_tokens":31000,"completion_tokens":20}}'
declare -r GOOGLE_MULTIPART='{"candidates":[{"content":{"parts":[
  {"text":"[WARN] BCS0202 line 8: "},{"text":"variable not declared local"}]},
  "finishReason":"STOP"}],
  "usageMetadata":{"promptTokenCount":31000,"candidatesTokenCount":20}}'

# Replaces the OpenAI backend with one that emits only the token sentinel.
stub_openai_orphan() {
  # Invoked indirectly, by cmd_check's backend dispatch.
  #shellcheck disable=SC2329
  _llm_openai() { echo '___TOKENS___ in=1 out=0'; }
}

# 1. OpenAI: no message.content (reasoning consumed the output budget)
begin_test 'openai empty completion'
reset_cache
run_check "$OPENAI_EMPTY" -m gpt-5
assert_equal 5 "$RC" 'openai empty -> exit 5' ||:
assert_not_contains "$OUT" '___TOKENS___' 'openai empty -> no sentinel on stdout' ||:
assert_equal 0 "$(cache_count)" 'openai empty -> nothing cached' ||:
assert_contains "$ERR" 'finish_reason=length' 'openai empty -> finish reason reported' ||:

# 2. Google: candidate without parts (safety block)
begin_test 'google empty completion'
reset_cache
run_check "$GOOGLE_EMPTY" -m gemini-2.5-flash
assert_equal 5 "$RC" 'google empty -> exit 5' ||:
assert_not_contains "$OUT" '___TOKENS___' 'google empty -> no sentinel on stdout' ||:
assert_equal 0 "$(cache_count)" 'google empty -> nothing cached' ||:
assert_contains "$ERR" 'SAFETY' 'google empty -> finish reason reported' ||:

# 3. A second identical run must not be served a poisoned cache entry
begin_test 'openai empty completion, second run'
reset_cache
run_check "$OPENAI_EMPTY" -m gpt-5
run_check "$OPENAI_EMPTY" -m gpt-5
assert_equal 5 "$RC" 'openai empty, second run -> still exit 5' ||:

# 4. JSON mode: exit 5 with a parseable empty envelope
begin_test 'openai empty completion, JSON mode'
reset_cache
run_check "$OPENAI_EMPTY" -m gpt-5 -j
assert_equal 5 "$RC" 'openai empty -j -> exit 5' ||:
assert_equal '0' "$(jq -r '.comments | length' <<< "$OUT" 2>/dev/null ||:)" \
  'openai empty -j -> parseable empty envelope' ||:
assert_equal 0 "$(cache_count)" 'openai empty -j -> nothing cached' ||:

# 5. Consumer side on its own: a backend that emits only the sentinel
begin_test 'orphan token sentinel'
reset_cache
PRE_HOOK=stub_openai_orphan
run_check '' -m gpt-5
PRE_HOOK=:
assert_equal 5 "$RC" 'orphan sentinel -> exit 5' ||:
assert_not_contains "$OUT" '___TOKENS___' 'orphan sentinel -> not printed' ||:
assert_equal 0 "$(cache_count)" 'orphan sentinel -> nothing cached' ||:

# 6. Normal completions still pass through, sentinel stripped, cached once
begin_test 'openai normal completion'
reset_cache
run_check "$OPENAI_OK" -m gpt-5
assert_equal 0 "$RC" 'openai normal -> exit 0' ||:
assert_equal "$FINDING" "$OUT" 'openai normal -> text only on stdout' ||:
assert_equal 1 "$(cache_count)" 'openai normal -> one cache entry' ||:

begin_test 'google multi-part completion'
reset_cache
run_check "$GOOGLE_MULTIPART" -m gemini-2.5-flash
assert_equal 0 "$RC" 'google multi-part -> exit 0' ||:
assert_equal "$FINDING" "$OUT" 'google multi-part -> all text parts joined' ||:

# 7. Parity guard: Anthropic and Ollama already end in exit 5 (mock only)
begin_test 'anthropic and ollama parity'
reset_cache
run_check "$ANTHROPIC_EMPTY" -m claude-sonnet-4-6
assert_equal 5 "$RC" 'anthropic thinking-only -> exit 5' ||:
assert_equal 0 "$(cache_count)" 'anthropic thinking-only -> nothing cached' ||:
reset_cache
run_check "$OLLAMA_EMPTY" -m qwen3.5:9b
assert_equal 5 "$RC" 'ollama empty -> exit 5' ||:
assert_equal 0 "$(cache_count)" 'ollama empty -> nothing cached' ||:

# 8. A body that is not JSON (a proxy's error page served with HTTP 200) is a
#    parse failure with a message, on Ollama as on the other three backends.
begin_test 'ollama unparseable body'
reset_cache
run_check '<html>502 Bad Gateway</html>' -m qwen3.5:9b
assert_equal 5 "$RC" 'ollama non-JSON body -> exit 5' ||:
assert_contains "$ERR" 'Failed to parse Ollama response' 'the parse failure is named' ||:
assert_equal 0 "$(cache_count)" 'ollama non-JSON body -> nothing cached' ||:

print_summary 'check-empty-content'
#fin
