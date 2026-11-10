#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# check-harness.sh - Shared harness for suites that drive cmd_check hermetically
#
# Source this AFTER test-helpers.sh. It sources bcs, sandboxes every path
# cmd_check writes to (cache, response dump, policy, config), and shadows
# `curl` and `claude` with shell functions that replay canned output. No
# backend is ever contacted and every API key is a dummy.
#
#   run_check BODY [cmd_check args...]   fills RC, OUT, ERR
#   MOCK_BODY         HTTP 200 body the curl mock replays (set by run_check)
#   MOCK_CLI_OUTPUT / MOCK_CLI_STDERR / MOCK_CLI_RC   what the claude mock does
#   PAYLOAD_FILE      request body of the last curl call
#   CURL_ARGV_FILE    argv of the last curl call, newline-separated; the -w
#                     argument itself holds a newline, the URL is the last line
#   CLI_ARGV_FILE     argv of the last claude call, one argument per line
#   TIMEOUT_ARGV_FILE argv of the last timeout call, one argument per line
#   CLI_STANDARD_FILE copy of the standard the last claude call was pointed at
#   CLI_SCRIPT_FILE   copy of the script the last claude call was pointed at
#   PRE_HOOK          command run inside the check subshell before cmd_check
#   CHECK_TARGET      script handed to cmd_check
[[ ${BASH_SOURCE[0]} != "$0" ]] || { >&2 echo "Error: ${0@Q} must be sourced"; exit 1; }

#shellcheck source=../bcs disable=SC1091
source "$BCS_CMD"

# Sourced from a suite, bcs takes SCRIPT_DIR from the suite's $0 (tests/), so
# its FHS search misses ./data and falls through to whatever copy is installed
# on the machine -- a stale standard here, exit 3 on a box with none (CI). Pin
# both lookups to the repo under test.
_find_bcs_md() { echo "$DATA_DIR"/BASH-CODING-STANDARD.md; }
_find_data_dir() { echo "$DATA_DIR"; }

declare -- SANDBOX='' OUT='' ERR='' PRE_HOOK=:
declare -i RC=0
declare -x MOCK_BODY='' MOCK_CLI_OUTPUT='' MOCK_CLI_STDERR=''
declare -ix MOCK_CLI_RC=0
declare -- CHECK_TARGET="$TEST_DIR"/fixtures/02-undeclared-local.sh

trap '[[ -z $SANDBOX ]] || rm -rf -- "$SANDBOX"' EXIT
SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}"/bcs-check.XXXXXX) \
  || die 1 'Failed to create sandbox directory'
declare -x XDG_CACHE_HOME="$SANDBOX"/cache XDG_STATE_HOME="$SANDBOX"/state \
           XDG_CONFIG_HOME="$SANDBOX"/config BCS_CONF_DIR="$SANDBOX"/conf
mkdir -p "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$XDG_CONFIG_HOME" "$BCS_CONF_DIR"
declare -rx PAYLOAD_FILE="$SANDBOX"/payload.json CLI_ARGV_FILE="$SANDBOX"/cli-argv.txt \
            CURL_ARGV_FILE="$SANDBOX"/curl-argv.txt \
            TIMEOUT_ARGV_FILE="$SANDBOX"/timeout-argv.txt \
            CLI_STANDARD_FILE="$SANDBOX"/cli-standard.md \
            CLI_SCRIPT_FILE="$SANDBOX"/cli-script.sh
unset BCS_MODEL BCS_EFFORT BCS_STRICT BCS_JSON BCS_CACHE BCS_TIER BCS_MIN_TIER \
      BCS_DEBUG BCS_RESPONSE_DUMP BCS_OLLAMA_NUM_CTX BCS_OLLAMA_KEEP_ALIVE

declare -x ANTHROPIC_API_KEY=test-anthropic OPENAI_API_KEY=test-openai \
           GOOGLE_API_KEY=test-google

# Read by the messaging helpers of the sourced script; not unused here.
# shellcheck disable=SC2034
VERBOSE=0

# Mock curl: keep argv and the request body (-d @-), replay $MOCK_BODY plus the HTTP
# code trailer that the backends split off.
curl() {
  printf '%s\n' "$@" > "$CURL_ARGV_FILE"
  cat > "$PAYLOAD_FILE" ||:
  printf '%s\n200\n' "$MOCK_BODY"
}

# Mock Claude Code CLI: keep argv and the @-referenced standard and script (the
# real files sit in a temp dir that is gone by the time the suite looks), then
# replay the canned answer.
claude() {
  local -- std_ref='' script_ref=''
  printf '%s\n' "$@" > "$CLI_ARGV_FILE"
  [[ "$*" =~ @([^[:space:]]*BASH-CODING-STANDARD\.md) ]] && std_ref=${BASH_REMATCH[1]} ||:
  [[ ! -r $std_ref ]] || cp -- "$std_ref" "$CLI_STANDARD_FILE"
  [[ "$*" =~ Analyze\ @([^[:space:]]+) ]] && script_ref=${BASH_REMATCH[1]} ||:
  [[ ! -r $script_ref ]] || cp -- "$script_ref" "$CLI_SCRIPT_FILE"
  [[ -z $MOCK_CLI_STDERR ]] || >&2 echo "$MOCK_CLI_STDERR"
  [[ -z $MOCK_CLI_OUTPUT ]] || echo "$MOCK_CLI_OUTPUT"
  return "$MOCK_CLI_RC"
}

# Mock timeout: bcs wraps the CLI in timeout(1), which execs a binary and so
# cannot run the claude function above -- on a machine with the CLI installed
# it would start the real one. Keep argv, skip the options and the duration,
# then run the command in-process. Expiry is simulated with MOCK_CLI_RC=124.
timeout() {
  printf '%s\n' "$@" > "$TIMEOUT_ARGV_FILE"
  while [[ ${1:-} == -* ]]; do shift; done
  shift
  "$@"
}
declare -fx curl claude timeout

# run_check BODY [cmd_check args...]
# cmd_check runs in a subshell because die() exits. The subshell is a
# background job so that errexit stays live inside it, as in production: a
# `( ... ) || RC=$?` list would switch errexit off for everything it runs.
# RC, OUT and ERR are read by the suites that source this file.
#shellcheck disable=SC2034
run_check() {
  local -i pid
  MOCK_BODY=$1; shift
  RC=0
  : > "$PAYLOAD_FILE"
  : > "$CURL_ARGV_FILE"
  : > "$CLI_ARGV_FILE"
  : > "$TIMEOUT_ARGV_FILE"
  : > "$CLI_STANDARD_FILE"
  : > "$CLI_SCRIPT_FILE"
  ( "$PRE_HOOK"; cmd_check --no-shellcheck "$@" "$CHECK_TARGET" ) \
    >"$SANDBOX"/out 2>"$SANDBOX"/err &
  pid=$!
  wait "$pid" || RC=$?
  OUT=$(< "$SANDBOX"/out)
  ERR=$(< "$SANDBOX"/err)
}

# openai_body TEXT -> a well-formed chat-completions body carrying TEXT
openai_body() {
  jq -n --arg text "$1" \
    '{choices: [{message: {content: $text}, finish_reason: "stop"}],
      usage: {prompt_tokens: 31000, completion_tokens: 20}}'
}

reset_cache() { rm -rf -- "$XDG_CACHE_HOME"/bcs; }
cache_count() { find "$XDG_CACHE_HOME" -type f | wc -l; }
#fin
