#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-resolver.sh - Unit tests for _expand_alias() + _sniff_backend()
#
# Replaces test-detect-backend.sh: the legacy tier-keyword probe is gone, so
# `-m` resolution is now alias expansion + name-prefix sniffing. We source bcs
# (source guard keeps main() from running) and call the helpers directly.

set -euo pipefail
shopt -s inherit_errexit
# bcs is sourced below and leaves PATH to its caller (BCS1002), so the suite
# sets the value an executed bcs would.
declare -rx PATH=~/.local/bin:/usr/local/bin:/usr/bin:/bin

#shellcheck source-path=SCRIPTDIR source=test-helpers.sh
source "$(dirname "$0")"/test-helpers.sh
#shellcheck source=../bcs disable=SC1091
source "$BCS_CMD"

echo 'Testing: _expand_alias + _sniff_backend'

# --- _expand_alias built-ins ------------------------------------------

declare -a builtins=(
  'opus|claude-opus-4-8'
  'sonnet|claude-sonnet-4-6'
  'haiku|claude-haiku-4-5'
  'flash|gemini-2.5-flash'
  'pro|gemini-3.1-pro-preview'
  'flash-lite|gemini-3.5-flash-lite'
  'gpt5|gpt-5'
  'gpt5-mini|gpt-5-mini'
  'qwen|qwen3.5:14b'
  'qwen-small|qwen3.5:9b'
)

declare -- pair name expected
for pair in "${builtins[@]}"; do
  name=${pair%%|*}
  expected=${pair##*|}
  begin_test "alias '$name' expands to '$expected'"
  assert_equal "$expected" "$(_expand_alias "$name")"
done

# --- _expand_alias unknown name passes through ------------------------

begin_test 'unknown name passes through unchanged'
assert_equal 'totally-unknown-name' "$(_expand_alias totally-unknown-name)"

begin_test 'canonical claude-* name passes through'
assert_equal 'claude-sonnet-4-6' "$(_expand_alias claude-sonnet-4-6)"

# --- _expand_alias user override --------------------------------------

begin_test 'user-defined alias overrides + adds entries'
# shellcheck disable=SC2154  # mytest is an associative-array key, not a var
MODEL_ALIASES['mytest']=claude-haiku-4-5
assert_equal 'claude-haiku-4-5' "$(_expand_alias mytest)"
unset 'MODEL_ALIASES[mytest]'

# Existing alias can be redefined.
declare -- previous=${MODEL_ALIASES[sonnet]}
MODEL_ALIASES['sonnet']=claude-sonnet-4-7
begin_test 'user redefinition of built-in alias takes effect'
assert_equal 'claude-sonnet-4-7' "$(_expand_alias sonnet)"
MODEL_ALIASES['sonnet']=$previous

# --- _sniff_backend by vendor prefix ----------------------------------

declare -a sniffs=(
  'claude-sonnet-4-6|anthropic'
  'claude-opus-4-7|anthropic'
  'claude-haiku-4-5|anthropic'
  'gemini-2.5-pro|google'
  'gemini-2.5-flash|google'
  'gemini-2.5-flash-lite|google'
  'gpt-5|openai'
  'gpt-5-mini|openai'
  'gpt-4.1-mini|openai'
  'o3-mini|openai'
  'o1|openai'
  'minimax-m2:cloud|ollama'
  'qwen3.5:14b|ollama'
  'claude-code|claude'
  'claude-code:opus|claude'
  'claude-code:claude-sonnet-4-6|claude'
)

declare -- backend
for pair in "${sniffs[@]}"; do
  name=${pair%|*}
  expected=${pair#*|}
  begin_test "_sniff_backend '$name' -> '$expected'"
  backend=$(_sniff_backend "$name")
  assert_equal "$expected" "$backend"
done

# Load-bearing ordering: claude-code* MUST match before claude-*.
begin_test 'claude-code matched before claude-*  (load-bearing order)'
assert_equal 'claude' "$(_sniff_backend claude-code)"

print_summary 'resolver'
#fin
