#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-sniff-backend.sh - Unit tests for _sniff_backend()
#
# _sniff_backend is pure (no I/O), so we source the bcs script to access
# the function directly and exhaustively verify vendor-prefix routing.
# Case-ordering regressions (the load-bearing `claude-code*` before
# `claude-*` rule) are the primary thing this suite catches.

set -euo pipefail
shopt -s inherit_errexit
# bcs is sourced below and leaves PATH to its caller (BCS1002), so the suite
# sets the value an executed bcs would.
declare -rx PATH=~/.local/bin:/usr/local/bin:/usr/bin:/bin

#shellcheck source=tests/test-helpers.sh
source "$(dirname "$0")"/test-helpers.sh
#shellcheck source=bcs
source "$BCS_CMD"   # source guard keeps main() from running

echo 'Testing: _sniff_backend'

# --- claude-code sentinel routes to claude CLI --------------------------

begin_test 'claude-code bare -> claude'
assert_equal claude "$(_sniff_backend claude-code)"

begin_test 'claude-code: (empty suffix) -> claude'
assert_equal claude "$(_sniff_backend claude-code:)"

begin_test 'claude-code:opus -> claude'
assert_equal claude "$(_sniff_backend claude-code:opus)"

begin_test 'claude-code:haiku -> claude'
assert_equal claude "$(_sniff_backend claude-code:haiku)"

begin_test 'claude-code:claude-opus-4-7 -> claude'
assert_equal claude "$(_sniff_backend claude-code:claude-opus-4-7)"

# --- LOAD-BEARING ORDER: claude-code* must precede claude-* -------------

begin_test 'claude-code does NOT route to anthropic (ordering regression)'
result=$(_sniff_backend claude-code)
assert_equal claude "$result"
[[ $result != anthropic ]] || printf '  %sNOTE%s ordering regressed: claude-code leaked to anthropic\n' "$YELLOW" "$NC"

# Guard-rail assertions: explicitly pin the load-bearing case order in
# _sniff_backend. docs/CRITICAL-ANALYSIS.md flagged the comment-only
# safeguard at bcs:519-523 as a documentation smell; these assertions turn
# the invariant into test coverage.
begin_test 'claude-code sentinel pins to claude backend (load-bearing case order)'
assert_equal claude "$(_sniff_backend claude-code)" 'claude-code sentinel'

begin_test 'claude-sonnet routes to anthropic (not shadowed by claude-code pattern)'
assert_equal anthropic "$(_sniff_backend claude-sonnet-4-6)" 'claude-sonnet-4-6'

# --- Anthropic via claude-* ---------------------------------------------

begin_test 'claude-sonnet-4-6 -> anthropic'
assert_equal anthropic "$(_sniff_backend claude-sonnet-4-6)"

begin_test 'claude-opus-4-6 -> anthropic'
assert_equal anthropic "$(_sniff_backend claude-opus-4-6)"

begin_test 'claude-haiku-4-5 -> anthropic'
assert_equal anthropic "$(_sniff_backend claude-haiku-4-5)"

begin_test 'arbitrary claude-FOO -> anthropic'
assert_equal anthropic "$(_sniff_backend claude-foo-custom)"

# --- Google via gemini-* ------------------------------------------------

begin_test 'gemini-2.5-flash -> google'
assert_equal google "$(_sniff_backend gemini-2.5-flash)"

begin_test 'gemini-2.5-pro -> google'
assert_equal google "$(_sniff_backend gemini-2.5-pro)"

begin_test 'gemini-2.5-flash-lite -> google'
assert_equal google "$(_sniff_backend gemini-2.5-flash-lite)"

# --- OpenAI via gpt-* ---------------------------------------------------

begin_test 'gpt-5.4 -> openai'
assert_equal openai "$(_sniff_backend gpt-5.4)"

begin_test 'gpt-4.1-mini -> openai'
assert_equal openai "$(_sniff_backend gpt-4.1-mini)"

begin_test 'gpt-5.4-mini -> openai'
assert_equal openai "$(_sniff_backend gpt-5.4-mini)"

# --- OpenAI via o[0-9]* (o-series reasoning models) ---------------------

begin_test 'o3-mini -> openai'
assert_equal openai "$(_sniff_backend o3-mini)"

begin_test 'o1 -> openai'
assert_equal openai "$(_sniff_backend o1)"

begin_test 'o5 -> openai'
assert_equal openai "$(_sniff_backend o5)"

# --- Ollama fallback for anything unrecognised --------------------------

begin_test 'minimax-m2:cloud -> ollama'
assert_equal ollama "$(_sniff_backend minimax-m2:cloud)"

begin_test 'qwen3.5:14b -> ollama'
assert_equal ollama "$(_sniff_backend qwen3.5:14b)"

begin_test 'deepseek-v3.1:671b-cloud -> ollama'
assert_equal ollama "$(_sniff_backend deepseek-v3.1:671b-cloud)"

begin_test 'llama3:8b -> ollama'
assert_equal ollama "$(_sniff_backend llama3:8b)"

begin_test 'empty string -> ollama'
assert_equal ollama "$(_sniff_backend '')"

begin_test 'lowercase random -> ollama'
assert_equal ollama "$(_sniff_backend 'something-random')"

# --- Edge cases ---------------------------------------------------------

# oX where X is not a digit should NOT match the openai pattern.
begin_test 'old-model (o-but-not-digit) -> ollama'
assert_equal ollama "$(_sniff_backend old-model)"

# Documented limitation: local Ollama model named claude-* becomes unreachable.
begin_test 'claude-foo (any claude-*) -> anthropic (documented limitation)'
assert_equal anthropic "$(_sniff_backend claude-foo)"

print_summary 'sniff-backend'
#fin
