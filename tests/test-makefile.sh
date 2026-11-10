#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-makefile.sh - Makefile targets behave as documented
#
# Every install here is either a dry run or staged into a sandbox
# (SKILLDIR/CMDDIR overrides); nothing on the host is written.
set -euo pipefail
shopt -s inherit_errexit

declare -rx PATH=~/.local/bin:/usr/local/bin:/usr/bin:/bin

#shellcheck source-path=SCRIPTDIR source=test-helpers.sh
source "$(dirname "$0")"/test-helpers.sh

echo 'Testing: Makefile targets'

declare -- SANDBOX='' OUT=''
declare -i RC=0

trap '[[ -z $SANDBOX ]] || rm -rf -- "$SANDBOX"' EXIT
SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}"/bcs-make.XXXXXX) \
  || { >&2 echo 'Failed to create sandbox directory'; exit 1; }

# run_make ARGS... -> fills RC and OUT (stdout+stderr)
run_make() {
  RC=0
  OUT=$(make --no-print-directory -C "$PROJECT_DIR" "$@" 2>&1) || RC=$?
}

# ---- Enterprise skills/commands: install set and drift check ----
declare -r SKILLS="$SANDBOX"/skills CMDS="$SANDBOX"/commands
declare -a CLAUDE_DIRS=(SKILLDIR="$SKILLS" CMDDIR="$CMDS")

begin_test 'install-claude install set'
run_make -n install-claude "${CLAUDE_DIRS[@]}"
assert_contains "$OUT" 'skills/bcscheck/SKILL.md' 'installs the bcscheck skill' ||:
assert_contains "$OUT" 'commands/audit-bash.md' 'installs the audit-bash command' ||:
assert_not_contains "$OUT" 'bcs-audit' 'installs no bcs-audit skill or command' ||:

begin_test 'check-claude: nothing installed'
run_make check-claude "${CLAUDE_DIRS[@]}"
assert_equal 0 "$RC" 'nothing installed -> not drift' ||:
assert_contains "$OUT" 'not installed' 'nothing installed -> says so' ||:

begin_test 'check-claude: fresh install'
run_make install-claude "${CLAUDE_DIRS[@]}"
assert_equal 0 "$RC" 'staged install-claude succeeds' ||:
run_make check-claude "${CLAUDE_DIRS[@]}"
assert_equal 0 "$RC" 'fresh install -> clean' ||:

begin_test 'check-claude: deployed copy edited by hand'
echo 'hand edit' >> "$SKILLS"/bcscheck/SKILL.md
run_make check-claude "${CLAUDE_DIRS[@]}"
assert_equal 1 "$((RC != 0))" 'edited deployed skill -> non-zero' ||:
# check-claude prints every path in every state, so match the verdict too.
assert_contains "$OUT" 'bcscheck/SKILL.md: DIFFERS' 'edited deployed skill -> named as differing' ||:
assert_contains "$OUT" 'audit-bash.md: OK' 'the untouched file is still reported clean' ||:

# The bcs-audit skill is no longer shipped, but earlier releases installed it.
begin_test 'uninstall-claude still clears a bcs-audit left by an earlier release'
run_make -n uninstall-claude "${CLAUDE_DIRS[@]}"
assert_contains "$OUT" "$SKILLS/bcs-audit" 'legacy skill directory is removed' ||:
assert_contains "$OUT" "$CMDS/bcs-audit.md" 'legacy command file is removed' ||:

begin_test 'audit-bash routes to the skill'
# Backticks are literal Markdown here, not a command substitution.
#shellcheck disable=SC2016
assert_contains "$(< "$PROJECT_DIR"/ai-agents/commands/audit-bash.md)" \
  'the `bcscheck` skill' 'audit-bash routes BCS checks to the bcscheck skill' ||:

# ---- Completion directory follows PREFIX (dry-run; never touches the host) ----
begin_test 'COMPDIR'
run_make -n install PREFIX="$SANDBOX"/prefix
assert_not_contains "$OUT" '/etc/' 'install with a custom PREFIX writes nothing under /etc' ||:
assert_contains "$OUT" "$SANDBOX/prefix/share/bash-completion/completions" \
  'install with a custom PREFIX keeps completions under PREFIX' ||:
run_make -n uninstall PREFIX="$SANDBOX"/prefix
assert_not_contains "$OUT" '/etc/' 'uninstall with a custom PREFIX removes nothing under /etc' ||:
run_make -n install
assert_contains "$OUT" '/etc/bash_completion.d' 'default PREFIX keeps the system completion dir' ||:
run_make -n install PREFIX=/usr
assert_contains "$OUT" '/etc/bash_completion.d' 'PREFIX=/usr keeps the system completion dir' ||:
run_make -n install PREFIX="$SANDBOX"/prefix COMPDIR="$SANDBOX"/comp
assert_contains "$OUT" "$SANDBOX/comp" 'an explicit COMPDIR still wins' ||:

# ---- Test targets: dry-run only, a real `make test` here would recurse ----
begin_test 'test targets'
run_make -n test
assert_contains "$OUT" 'BCS_SKIP_FIXTURES=1' 'make test is the fast suite (no LLM gate)' ||:
run_make -n test-fast
assert_contains "$OUT" 'BCS_SKIP_FIXTURES=1' 'make test-fast skips the LLM gate' ||:
assert_contains "$OUT" 'tests/run-all-tests.sh' 'make test-fast runs the suite runner' ||:
run_make -n test-full
assert_contains "$OUT" 'BCS_FIXTURES_REQUIRE_BACKEND=1' 'make test-full demands a backend' ||:
assert_contains "$OUT" 'BCS_SKIP_FIXTURES=0' 'make test-full overrides an exported skip flag' ||:
run_make help
assert_contains "$OUT" 'test-fast' 'help lists test-fast' ||:
assert_contains "$OUT" 'test-full' 'help lists test-full' ||:
assert_contains "$(< "$PROJECT_DIR"/.github/workflows/ci.yml)" 'make test-fast' \
  'CI runs make test-fast' ||:

print_summary 'makefile'
#fin
