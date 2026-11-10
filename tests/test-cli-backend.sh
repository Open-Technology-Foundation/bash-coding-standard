#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-cli-backend.sh - How bcs check drives the Claude Code CLI backend
#
# `claude` is a shell function from check-harness.sh that records its argv and
# replays a canned answer, so the real CLI never runs.
set -euo pipefail
shopt -s inherit_errexit
# bcs is sourced below and leaves PATH to its caller (BCS1002), so the suite
# sets the value an executed bcs would.
declare -rx PATH=~/.local/bin:/usr/local/bin:/usr/bin:/bin

#shellcheck source-path=SCRIPTDIR source=test-helpers.sh
source "$(dirname "$0")"/test-helpers.sh
#shellcheck source-path=SCRIPTDIR source=check-harness.sh
source "$TEST_DIR"/check-harness.sh

echo 'Testing: Claude Code CLI backend'

# arg_after FLAG -> the argv element that followed FLAG in the last CLI call
arg_after() { grep -x -A1 -- "$1" "$CLI_ARGV_FILE" | sed -n 2p; }

declare -r DUMP="$XDG_STATE_HOME"/bcs/last-response.txt
declare -r FAKE_HOME="$SANDBOX"/home CWD_RECORD="$SANDBOX"/cli-cwd
# dump_text -> contents of the response dump, empty when it was never written
dump_text() { [[ ! -f $DUMP ]] || echo "$(< "$DUMP")"; }

# ---- Invocation ----
begin_test 'CLI arguments'
reset_cache
MOCK_CLI_OUTPUT='No BCS violations found.' MOCK_CLI_STDERR='' MOCK_CLI_RC=0
run_check '' -m claude-code:haiku -e high
assert_equal 0 "$RC" 'clean answer -> exit 0' ||:
assert_equal low "$(arg_after --effort)" '-e high still runs the CLI at its lowest native effort' ||:
assert_equal 1 "$(grep -c -x -- '--strict-mcp-config' "$CLI_ARGV_FILE" ||:)" \
  '--strict-mcp-config keeps user MCP servers out of the session' ||:
assert_equal 'Read,Grep,Glob' "$(arg_after --tools)" 'read-only toolset kept' ||:
assert_equal bypassPermissions "$(arg_after --permission-mode)" 'permission mode kept' ||:
assert_equal claude-haiku-4-5 "$(arg_after --model)" 'model alias expanded' ||:
reset_cache
run_check '' -m claude-code:haiku -e low
assert_equal low "$(arg_after --effort)" '-e low -> native effort low' ||:

# ---- A failing CLI is a backend failure, not "violations found" ----
begin_test 'CLI failure'
reset_cache
MOCK_CLI_OUTPUT='' MOCK_CLI_STDERR='Invalid API key · Please run /login' MOCK_CLI_RC=1
run_check '' -m claude-code:haiku
assert_equal 5 "$RC" 'CLI exit 1 -> bcs exit 5, never the "ERROR findings" code 1' ||:
assert_contains "$ERR" 'Please run /login' 'CLI stderr reaches the user' ||:
assert_contains "$(dump_text)" 'Please run /login' 'CLI stderr kept in the response dump' ||:
assert_contains "$ERR" "$DUMP" 'dump path announced on failure' ||:
assert_equal 0 "$(cache_count)" 'failed CLI run is not cached' ||:

# ---- stderr noise on a good run stays out of the result ----
begin_test 'CLI stderr on success'
reset_cache
MOCK_CLI_OUTPUT='[WARN] BCS0301 line 4: static string in double quotes'
MOCK_CLI_STDERR='deprecation notice' MOCK_CLI_RC=0
run_check '' -m claude-code:haiku
assert_equal 0 "$RC" 'WARN only -> exit 0' ||:
assert_equal "$MOCK_CLI_OUTPUT" "$OUT" 'stdout is the answer alone' ||:
assert_contains "$(dump_text)" 'deprecation notice' 'stderr noise lands in the dump' ||:

# ---- CLI timeout ----

# The CLI call is bounded (BCS1104), as --max-time bounds every curl backend.
begin_test 'CLI timeout'
reset_cache
MOCK_CLI_OUTPUT='No BCS violations found.' MOCK_CLI_STDERR='' MOCK_CLI_RC=0
run_check '' -m claude-code:haiku
assert_equal 0 "$RC" 'bounded CLI run -> exit 0' ||:
assert_matches "$(grep -x -B1 -- claude "$TIMEOUT_ARGV_FILE" | head -n 1)" '^[1-9][0-9]*$' \
  'the CLI runs under timeout, duration first' ||:
assert_equal 1 "$(grep -c -x -- '--foreground' "$TIMEOUT_ARGV_FILE" ||:)" \
  '--foreground keeps a terminal Ctrl-C reaching the CLI' ||:
reset_cache
MOCK_CLI_OUTPUT='' MOCK_CLI_RC=124
run_check '' -m claude-code:haiku
assert_equal 5 "$RC" 'expired CLI -> backend failure (5)' ||:
assert_contains "$ERR" 'timed out' 'expiry is named as the cause' ||:
assert_equal 0 "$(cache_count)" 'timed-out run is not cached' ||:

# ---- jq dependency ----

# --json renders through jq on this backend too.
begin_test 'jq required for CLI JSON mode'
# command -v jq fails; everything else goes to the builtin
#shellcheck disable=SC2329  # the inner command is called by bcs, inside the check subshell
hide_jq() { command() { [[ $* != '-v jq' ]] || return 1; builtin command "$@"; }; }
PRE_HOOK=hide_jq
reset_cache
MOCK_CLI_OUTPUT='[]' MOCK_CLI_RC=0
run_check '' -m claude-code:haiku -j
assert_equal 18 "$RC" 'JSON mode without jq -> missing dependency (18)' ||:
assert_contains "$ERR" 'jq' 'the missing tool is named' ||:
reset_cache
MOCK_CLI_OUTPUT='No BCS violations found.'
run_check '' -m claude-code:haiku
assert_equal 0 "$RC" 'text mode on the CLI backend needs no jq' ||:
PRE_HOOK=:

# ---- Interrupted run ----

# An interrupted run leaves no working directory behind, and exits with the
# signal's own status. A real process this time. bcs puts $HOME/.local/bin first on PATH, so a fake
# `claude` under a sandbox HOME stands in for the CLI: it records the directory
# it was started in, then hangs. The signal goes to the whole process group, as
# a terminal Ctrl-C does. A background job starts with SIGINT ignored, hence
# env --default-signal; and the harness exports its mock functions, which a
# child bash would import ahead of any binary, hence the three -u.
begin_test 'CLI working directory removed on signal'
mkdir -p -- "$FAKE_HOME"/.local/bin
cat > "$FAKE_HOME"/.local/bin/claude <<'FAKE_CLI'
#!/usr/bin/env bash
pwd > "$BCS_TEST_CWD_RECORD"
sleep 30
FAKE_CLI
chmod -- +x "$FAKE_HOME"/.local/bin/claude

# interrupted_run SIGNAL -> removed:RC | leaked:RC | not-started | setup-failed
# RC is the exit status of the interrupted bcs. Called inside $(...) ||:, where
# errexit is off, so each step that the verdict depends on is checked by hand.
interrupted_run() {
  local -- sig=$1 dir='' tmp_root=${TMPDIR:-/tmp}
  local -i pid=0 i=0 rc=0
  # a stale record would make this run report the previous run's directory
  rm -f -- "$CWD_RECORD" || { echo setup-failed; return 0; }
  HOME=$FAKE_HOME BCS_TEST_CWD_RECORD=$CWD_RECORD \
    setsid env -u 'BASH_FUNC_claude%%' -u 'BASH_FUNC_curl%%' -u 'BASH_FUNC_timeout%%' \
      --default-signal=INT,TERM "$BCS_CMD" check -q --no-cache --no-shellcheck \
      -m claude-code:haiku -- "$CHECK_TARGET" &>/dev/null &
  pid=$!
  for ((i=0; i<100; i+=1)); do
    [[ ! -s $CWD_RECORD ]] || break
    sleep 0.1
  done
  if [[ ! -s $CWD_RECORD ]]; then
    kill -KILL -- -"$pid" 2>/dev/null ||:   # nothing to clean up if it never started
    echo not-started
    return 0
  fi
  dir=$(< "$CWD_RECORD")
  kill -"$sig" -- -"$pid" || { echo setup-failed; return 0; }
  wait "$pid" || rc=$?
  if [[ -d $dir ]]; then
    # The path came from a file. Remove it only if it is a bcs working
    # directory directly under the temp root, never anything else.
    [[ $dir != "$tmp_root"/bcs-* || ${dir#"$tmp_root"/} == */* ]] || rm -rf -- "$dir"
    echo leaked:"$rc"
  else
    echo removed:"$rc"
  fi
}
assert_equal removed:130 "$(interrupted_run INT)" \
  'SIGINT (Ctrl-C) -> working directory removed, exit 130' ||:
assert_equal removed:143 "$(interrupted_run TERM)" \
  'SIGTERM -> working directory removed, exit 143' ||:

print_summary 'cli-backend'
#fin
