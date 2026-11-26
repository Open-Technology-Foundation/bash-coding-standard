#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-subcommand-check.sh - Tests for bcs check subcommand
set -euo pipefail
shopt -s inherit_errexit
#shellcheck source-path=SCRIPTDIR source=test-helpers.sh
source "$(dirname "$0")"/test-helpers.sh

echo 'Testing: check subcommand'

# Test: check requires a file argument
begin_test 'check requires file argument'
assert_fails 'no file argument' "$BCS_CMD" check || true

# Test: check rejects nonexistent file
begin_test 'check rejects nonexistent file'
assert_fails 'nonexistent file' "$BCS_CMD" check /nonexistent/file.sh || true

# Test: check help
begin_test 'check -h shows help'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_contains "$output" 'bcs check' 'help has command name' || true

# Test: check rejects multiple files
begin_test 'check rejects multiple files'
temp1=$(mktemp --suffix=.sh)
temp2=$(mktemp --suffix=.sh)
echo '#!/bin/bash' > "$temp1"
echo '#!/bin/bash' > "$temp2"
assert_fails 'multiple files rejected' "$BCS_CMD" check "$temp1" "$temp2" || true
rm -f "$temp1" "$temp2"

# Test: check help includes --model
begin_test 'check help includes --model'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_contains "$output" '--model' 'help mentions --model' || true

# Test: check help includes --effort
begin_test 'check help includes --effort'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_contains "$output" '--effort' 'help mentions --effort' || true

# Test: check --model requires argument
begin_test 'check --model requires argument'
assert_fails 'model needs arg' "$BCS_CMD" check --model || true

# Test: check --effort requires argument
begin_test 'check --effort requires argument'
assert_fails 'effort needs arg' "$BCS_CMD" check --effort || true

# Test: check rejects invalid effort level
begin_test 'check rejects invalid effort level'
temp=$(mktemp --suffix=.sh)
echo '#!/bin/bash' > "$temp"
assert_fails 'invalid effort rejected' "$BCS_CMD" check --effort bogus "$temp" || true
rm -f "$temp"

# Test: check accepts xhigh effort level
begin_test 'check accepts xhigh effort'
assert_success 'xhigh accepted' \
  "$BCS_CMD" check -e xhigh -h || true

# Test: check accepts min as alias for low
begin_test 'check accepts min as alias for low'
assert_success 'min accepted' \
  "$BCS_CMD" check -e min -h || true

# Test: check accepts arbitrary --model pass-through
# Use -h to short-circuit before any backend call; we only exercise the parser.
# A direct model name must NOT error at the argparse stage.
begin_test 'accepts arbitrary --model pass-through'
assert_success 'direct model name accepted' \
  "$BCS_CMD" check -m claude-opus-4-7 -h || true

# Test: built-in aliases parse at argparse stage
begin_test 'sonnet alias accepted'
assert_success 'sonnet alias accepted' \
  "$BCS_CMD" check -m sonnet -h || true

begin_test 'opus alias accepted'
assert_success 'opus alias accepted' \
  "$BCS_CMD" check -m opus -h || true

begin_test 'gpt5 alias accepted'
assert_success 'gpt5 alias accepted' \
  "$BCS_CMD" check -m gpt5 -h || true

# Test: legacy tier keywords are rejected with a migration hint
begin_test 'legacy tier keyword fast rejected'
temp=$(mktemp --suffix=.sh)
echo '#!/bin/bash' > "$temp"
err=$("$BCS_CMD" check -m fast "$temp" 2>&1 || true)
assert_contains "$err" 'no longer supported' 'fast rejected with migration hint' || true
rm -f "$temp"

begin_test 'legacy tier keyword balanced rejected'
temp=$(mktemp --suffix=.sh)
echo '#!/bin/bash' > "$temp"
err=$("$BCS_CMD" check -m balanced "$temp" 2>&1 || true)
assert_contains "$err" 'no longer supported' 'balanced rejected with migration hint' || true
rm -f "$temp"

begin_test 'legacy tier keyword thorough rejected'
temp=$(mktemp --suffix=.sh)
echo '#!/bin/bash' > "$temp"
err=$("$BCS_CMD" check -m thorough "$temp" 2>&1 || true)
assert_contains "$err" 'no longer supported' 'thorough rejected with migration hint' || true
rm -f "$temp"

# Test: check help includes --strict
begin_test 'check help includes --strict'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_contains "$output" '--strict' 'help mentions --strict' || true

# Test: check help includes --quiet
begin_test 'check help includes --quiet'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_contains "$output" '--quiet' 'help mentions --quiet' || true

# Test: check rejects unreadable file
begin_test 'check rejects unreadable file'
unreadable=$(mktemp --suffix=.sh)
echo '#!/bin/bash' > "$unreadable"
chmod 000 "$unreadable"
assert_fails 'unreadable file' "$BCS_CMD" check "$unreadable" || true
rm -f "$unreadable"

# Test: option bundling -se
begin_test 'option bundling -se parsed'
# -se should not error on option parsing (will fail on missing effort arg, not option)
err=$("$BCS_CMD" check -se 2>&1 || true)
assert_not_contains "$err" 'Invalid option' '-se bundling parsed correctly' || true

# Test: -- separator works
begin_test '-- separator works'
assert_fails '-- then nonexistent' "$BCS_CMD" check -- /nonexistent/file.sh || true

# Test: operands after -- still honour the one-file rule (T-25)
begin_test 'two operands after -- rejected'
assert_fails 'check -- a b' "$BCS_CMD" check -- /etc/hostname /etc/hosts || true

begin_test 'operand before and after -- rejected'
assert_fails 'check x -- y' "$BCS_CMD" check /etc/hostname -- /etc/hosts || true

# Test: BCS_EFFORT from the environment is validated (T-26). test-helpers
# forces a hermetic BCS_CONF_DIR, so no real bcs.conf masks the env value.
begin_test 'invalid BCS_EFFORT from env rejected'
temp_eff=$(mktemp --suffix=.sh)
echo '#!/bin/bash' > "$temp_eff"
assert_fails 'BCS_EFFORT=bogus rejected' \
  env BCS_EFFORT=bogus "$BCS_CMD" check "$temp_eff" || true
rm -f "$temp_eff"

# Test: -b/--backend is gone — accepting it must error
begin_test '-b/--backend removed from parser'
temp=$(mktemp --suffix=.sh)
echo '#!/bin/bash' > "$temp"
err=$("$BCS_CMD" check -b anthropic "$temp" 2>&1 || true)
assert_contains "$err" 'Invalid option' '-b rejected as invalid option' || true
rm -f "$temp"

# Test: --backend is gone from help
begin_test '--backend absent from help'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_not_contains "$output" '--backend' 'help omits --backend' || true

# Test: claude-code sentinel parses
begin_test 'claude-code sentinel parses'
assert_success 'claude-code accepted' \
  "$BCS_CMD" check -m claude-code -h || true

# Test: claude-code:<model> variant parses
begin_test 'claude-code:MODEL variant parses'
assert_success 'claude-code:claude-opus-4-7 accepted' \
  "$BCS_CMD" check -m claude-code:claude-opus-4-7 -h || true

# Test: claude-code:<alias> variant parses (sentinel + alias compose)
begin_test 'claude-code:opus alias variant parses'
assert_success 'claude-code:opus accepted' \
  "$BCS_CMD" check -m claude-code:opus -h || true

begin_test 'claude-code:haiku alias variant parses'
assert_success 'claude-code:haiku accepted' \
  "$BCS_CMD" check -m claude-code:haiku -h || true

# Test: help mentions claude-code sentinel
begin_test 'check help mentions claude-code'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_contains "$output" 'claude-code' 'help mentions claude-code' || true

# Test: help still mentions ollama in model grammar
begin_test 'check help mentions ollama'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_contains "$output" 'ollama' 'help mentions ollama' || true

# Test: help still mentions anthropic in model grammar
begin_test 'check help mentions anthropic'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_contains "$output" 'anthropic' 'help mentions anthropic' || true

# Test: help still mentions openai in model grammar
begin_test 'check help mentions openai'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_contains "$output" 'openai' 'help mentions openai' || true

# Test: check help shows ANTHROPIC_API_KEY env var
begin_test 'check help mentions ANTHROPIC_API_KEY'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_contains "$output" 'ANTHROPIC_API_KEY' 'help mentions ANTHROPIC_API_KEY' || true

# Test: check help mentions MODEL_ALIASES (replaces removed BCS_<BACKEND>_MODEL vars)
begin_test 'check help mentions MODEL_ALIASES'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_contains "$output" 'MODEL_ALIASES' 'help mentions MODEL_ALIASES' || true

# Test: BCS_<BACKEND>_MODEL variables removed from help
begin_test 'check help no longer mentions BCS_ANTHROPIC_MODEL'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_not_contains "$output" 'BCS_ANTHROPIC_MODEL' 'BCS_ANTHROPIC_MODEL gone' || true

# Test: alias keys appear in help
begin_test 'check help lists built-in aliases'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_contains "$output" 'sonnet' 'sonnet alias listed' || true

# Test: check help mentions -j / --json
begin_test 'check help mentions --json'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_contains "$output" '--json' 'help mentions --json' || true

# Test: check help mentions JSON Output section
begin_test 'check help mentions JSON Output section'
output=$("$BCS_CMD" check -h 2>/dev/null)
assert_contains "$output" 'JSON Output' 'help has JSON Output section' || true

# Test: -j accepted at argparse stage (short-circuit on -h)
begin_test '-j accepted at argparse stage'
assert_success '-j accepted' \
  "$BCS_CMD" check -j -h || true

# Test: --json accepted at argparse stage
begin_test '--json accepted at argparse stage'
assert_success '--json accepted' \
  "$BCS_CMD" check --json -h || true

# Test: -jq bundling parses (json + quiet) — neither should error
begin_test '-jq bundling parsed correctly'
err=$("$BCS_CMD" check -jq 2>&1 || true)
assert_not_contains "$err" 'Invalid option' '-jq bundling parsed' || true

# Test: -js bundling parses (json + strict)
begin_test '-js bundling parsed correctly'
err=$("$BCS_CMD" check -js 2>&1 || true)
assert_not_contains "$err" 'Invalid option' '-js bundling parsed' || true

# Test: --shellcheck accepted at argparse stage
begin_test '--shellcheck accepted at argparse stage'
assert_success '--shellcheck accepted' \
  "$BCS_CMD" check --shellcheck -h || true

# Test: --no-shellcheck accepted at argparse stage
begin_test '--no-shellcheck accepted at argparse stage'
assert_success '--no-shellcheck accepted' \
  "$BCS_CMD" check --no-shellcheck -h || true

# --- claude-code sentinel resolution (cycle-breaker) ---
# Stub `claude` on PATH so _llm_claude_cli short-circuits without making a real
# API call. info() prints the resolution message to stderr before the LLM call,
# so capturing combined output reveals the resolved canonical model.
# Isolate HOME/XDG_CONFIG_HOME so the user's bcs.conf cannot override BCS_MODEL.
sentinel_dir=$(mktemp -d)
cat > "$sentinel_dir"/claude <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$sentinel_dir"/claude
sentinel_home=$(mktemp -d)
sentinel_script=$(mktemp --suffix=.sh)
printf '%s\n' '#!/bin/bash' 'echo hi' > "$sentinel_script"

begin_test 'BCS_MODEL=claude-code on bare sentinel resolves to sonnet'
out=$(PATH="$sentinel_dir:$PATH" HOME="$sentinel_home" XDG_CONFIG_HOME="$sentinel_home" \
  BCS_CONF_DIR="$sentinel_home" \
  BCS_MODEL=claude-code \
  "$BCS_CMD" check -m claude-code -- "$sentinel_script" 2>&1 || true)
assert_contains "$out" "resolved from model 'claude-sonnet-5-5'" \
  'cycle broken; resolves to sonnet alias' || true

begin_test 'claude-code:claude-code suffix resolves to sonnet'
out=$(PATH="$sentinel_dir:$PATH" HOME="$sentinel_home" XDG_CONFIG_HOME="$sentinel_home" \
  BCS_CONF_DIR="$sentinel_home" \
  "$BCS_CMD" check -m claude-code:claude-code -- "$sentinel_script" 2>&1 || true)
assert_contains "$out" "resolved from model 'claude-sonnet-5-5'" \
  'literal-suffix cycle broken' || true

begin_test 'BCS_MODEL=opus on bare sentinel still resolves to claude-opus-4-8'
out=$(PATH="$sentinel_dir:$PATH" HOME="$sentinel_home" XDG_CONFIG_HOME="$sentinel_home" \
  BCS_CONF_DIR="$sentinel_home" \
  BCS_MODEL=opus \
  "$BCS_CMD" check -m claude-code -- "$sentinel_script" 2>&1 || true)
assert_contains "$out" "resolved from model 'claude-opus-4-8'" \
  'documented BCS_MODEL fallback still honoured' || true

rm -rf "$sentinel_dir" "$sentinel_home" "$sentinel_script"

# Skip actual LLM invocation tests (requires running backend)
echo '  (skipping live LLM tests - requires running backend)'

print_summary 'check'
#fin
