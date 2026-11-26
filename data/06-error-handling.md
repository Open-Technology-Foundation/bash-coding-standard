<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Section 06: Error Handling

## BCS0600 Section Overview

Error handling covers strict mode, exit codes, traps, return value checking, and error suppression patterns. Every script must fail safely and provide clear error context.

## BCS0601 Exit on Error

**Tier:** core

Scripts run under `set -euo pipefail` (BCS0101). Handle expected failures explicitly — `||:`, an `if` guard, or `|| die` — never by disabling strict mode with `set +e`.

`set -euo pipefail` provides three protections: `-e` exits on command failure, `-u` exits on undefined variables, `-o pipefail` fails pipeline if any command fails.

`-e` has one blind spot to design around: a function called as the condition of `if`, `while`, `&&` or `||` runs with `-e` suspended for its whole call tree, with or without `inherit_errexit`. Inside `if fn; then` or `fn || die`, a failing command in `fn` does not stop it, and `fn` returns the status of its last command. A function meant to be called that way checks its own critical steps (BCS0604).

```bash
# correct — allow expected failures
command_that_might_fail ||:
if command_that_might_fail; then
  process_result
fi

# correct — handle undefined optional variables
val="${OPTIONAL_VAR:-default}"
echo "${OPTIONAL_VAR:-}"

# correct — capture failing command safely
if result=$(failing_command); then
  echo "$result"
fi
output=$(cmd) || die 1 'cmd failed'

# wrong
set +e                               # never disable broadly
command
set -e
```

## BCS0602 Exit Codes

**Tier:** recommended

**Scope.** This rule governs which exit code a script reports and that a failing exit says why. It does not decide whether a script defines `die()`: BCS0703 owns that. Where `die()` is defined it is the standard exit function: a failing exit below the definition that hand-rolls `echo ...; exit N` instead is a finding. Code that has no `die()` to call -- a short script that defines none, a wrapper, a version guard that runs above the definition (BCS0409) -- may report to stderr and `exit N` directly; that is **not** a finding.

```bash
die() { (($# < 2)) || error "${@:2}"; exit "${1:-0}"; }

# correct — die() is defined, so every failing exit goes through it
[[ -f $config ]] || die 3 "Config not found ${config@Q}"

# correct — no die() in this script: message to stderr, then a code from the table
((${#FIELDS[@]})) || { >&2 echo 'No fields given'; exit 2; }

# wrong — die() is defined above and bypassed
[[ -f $config ]] || { >&2 echo "Config not found ${config@Q}"; exit 3; }
```

Standard exit codes:

| Code | Use Case |
|------|----------|
| 0 | Success |
| 1 | General error |
| 2 | Usage / argument error |
| 3 | File/directory not found |
| 5 | I/O error |
| 8 | Required argument missing |
| 13 | Permission denied |
| 18 | Missing dependency |
| 19 | Configuration error |
| 22 | Invalid argument |
| 24 | Timeout |

Where the table names the failure exactly -- a missing file (3), a missing dependency (18), an invalid option or value (22) -- use that code, not 1. Anything else is a general error: whether a failed `mktemp` or `stat` counts as an "I/O error" is a judgement call, and choosing 1 there is **not** a finding.

When the failure concerns a particular value -- a path, an option, a setting -- the message names it. A failure with no such value needs no invented context.

```bash
# correct — the message names the value at fault
die 3 "Config not found ${config@Q}"
die 22 "Invalid option ${1@Q}"

# correct — there is no value to name
die 2 'No input files specified'
die 18 'curl required'

# wrong — a path was at fault and the message hides it
die 3 'File not found'

# correct — 1 for a failure the table does not name exactly
temp_dir=$(mktemp -d) || die 1 'Failed to create temp dir'
size=$(stat -c '%s' -- "$path") || die 1 "Cannot stat ${path@Q}"

# wrong — the table names this failure exactly: a missing file is 3
die 1 "Config not found ${config@Q}"
```

Reserved: 64-78 (sysexits), 126 (cannot execute), 127 (not found), 128+n (signals).

## BCS0603 Trap Handling

**Tier:** core

Install cleanup traps early, before creating any resources.

This is the canonical rule for the trap/cleanup pattern (quoting, signal lists, recursion guard) — cite BCS0603 for trap-content violations. BCS0110 owns the structural-placement requirement (trap installed before resource-creating code).

```bash
# correct
declare -- TEMP_FILE
#...
cleanup() {
  local -i exitcode=${1:-$?}
  trap - EXIT                        # prevent recursion
  [[ -z ${TEMP_FILE:-} ]] || rm -f -- "$TEMP_FILE"
  exit "$exitcode"
}
trap 'cleanup $?' EXIT
#...
TEMP_FILE=$(mktemp) || die 1 'Failed to create temp file'
readonly TEMP_FILE
```

Use single quotes for trap commands to delay variable expansion. Use `||:` for cleanup operations that might fail.

```bash
# correct — single quotes delay expansion
trap 'rm -f -- "$temp_file"' EXIT

# correct — kill background processes in cleanup
((bg_pid)) && kill "$bg_pid" 2>/dev/null ||:   # the job may have exited already

# wrong — double quotes expand immediately
trap "rm -f $temp_file" EXIT

# wrong — exit 0 in the trap reports success for a script that failed
trap 'rm -f -- "$temp_file"; exit 0' EXIT
```

The handler must propagate the script's exit status: pass `$?` in (`trap 'cleanup $?' ...`) and finish with `exit "$exitcode"`, as in the example above. A trap that ends in `exit 0`, or any fixed status, hides the failure from the caller.

**Signals.** Trap `EXIT` alone for cleanup. When a fatal signal (INT, TERM, HUP) kills the script, Bash still runs the EXIT trap and then dies by that signal, so the caller sees 130, 143 or 129. Adding `SIGINT SIGTERM` to the `cleanup $?` trap turns that death into an ordinary exit with whatever `$?` held when the signal arrived, which is **0** while the script is running builtins: an interrupted script reports success. A script that must react to INT or TERM itself maps each to its conventional status and leaves cleanup to EXIT:

```bash
# correct — EXIT does the cleanup; INT and TERM only set a non-zero status
trap 'cleanup $?' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# wrong — a signal during builtins leaves $? at 0, so the interrupted script exits 0
trap 'cleanup $?' SIGINT SIGTERM EXIT
```

Never combine multiple traps for the same signal (replaces previous). Use a single trap with a cleanup function.

## BCS0604 Checking Return Values

**Tier:** core

Always check return values of critical operations. Critical operations are state-changing commands whose failure needs a contextual message or cleanup -- file moves/copies/removals, command substitutions whose output is used later, network calls, and anything followed by dependent steps. For these operations, a bare command relying on `set -e` to abort with no context is a violation.

```bash
# correct
mv -- "$file" "$dest" || die 1 "Failed to move ${file@Q}"
output=$(command) || die 1 'Command failed'

# correct — command group with cleanup on failure
cp -- "$src" "$dst" || {
  rm -f -- "$dst"
  die 1 'Copy failed'
}

# correct — check PIPESTATUS for pipelines (condition context, see pitfalls)
if ! sort -- "$file" | uniq > "$output"; then
  ((PIPESTATUS[0] == 0)) || die 1 'Sort failed'
  die 1 'Pipeline failed'
fi

# correct — capture the status; a bare cmd1 would let set -e abort before $? is read
local -i result=0
cmd1 || result=$?

# wrong — a failure inside <( ) is invisible: diff silently compares against empty input
diff -- <(failing_command) "$file"

# correct — run and check first, then feed the output on
out=$(failing_command) || die 1 'Command failed'
diff -- <(printf '%s\n' "$out") "$file"

# correct — loop feed: an empty stream is an ordinary outcome, nothing to check
while IFS= read -r line; do process "$line"; done < <(grep -- 'pattern' "$file")
```

A command run only inside a process substitution (`<(cmd)`) has no exit status anyone checks: `set -e` and `pipefail` never see it, and the consumer reads empty input. This is a finding where an empty result would be taken for a real one: a `diff`, `cmp` or `comm` against `<(cmd)`, or a result captured for later use. Run such a command first and check it. The prescribed loop feed `while ... done < <(cmd)` (BCS0504, BCS0903), where an empty stream is an ordinary outcome, is not a finding.

**`PIPESTATUS` pitfalls:**

- `PIPESTATUS` is overwritten by the **very next command** -- including `echo`. Snapshot it immediately if you need it across statements: `local -a ps=("${PIPESTATUS[@]}")`.
- Under strict mode a failing pipeline aborts the script before any follow-up `PIPESTATUS` check can run. Inspect `PIPESTATUS` from a condition context (`if ! pipeline; then ...`), where it survives into the body. Appending `||:` does NOT work -- the `:` itself overwrites `PIPESTATUS`.
- Under `set -o pipefail` (part of BCS0101 strict mode), `$?` already reflects the rightmost non-zero exit. Inspect `PIPESTATUS` only when you need to distinguish *which* stage failed.
- `((PIPESTATUS[0]))` only tells you about the first command. For a multi-stage pipeline, iterate over a snapshot:

```bash
# correct — snapshot, then inspect each stage
if ! sort -- "$file" | uniq | wc -l > "$output"; then
  local -a ps=("${PIPESTATUS[@]}")
  local -i i
  for i in "${!ps[@]}"; do
    ((ps[i] == 0)) || error "Stage $i failed (exit ${ps[i]})"
  done
  die 1 'Pipeline failed'
fi

# wrong — echo clobbers PIPESTATUS before we read it
if ! sort -- "$file" | uniq | wc -l > "$output"; then
  echo 'Pipeline failed'
  ((PIPESTATUS[0] == 0)) || die 1 'Sort failed'   # PIPESTATUS is now echo's
fi
```

## BCS0605 Error Suppression

**Tier:** recommended

Only suppress errors when failure is expected, non-critical, and explicitly safe to ignore. A suppression is a decision: the comment beside or above it must say why the failure is safe to ignore.

```bash
# correct — safe to suppress, and the comment says why
command -v optional_tool &>/dev/null ||:   # optional: the builtin path is used instead
rm -f /tmp/optional_*                      # -f: nothing to remove is the normal case
rmdir -- "$maybe_empty" 2>/dev/null ||:    # still populated means another job owns it

# correct — suppress message but check return
if result=$(command 2>/dev/null); then
  process "$result"
fi

# wrong — suppressing critical operations
cp -- "$src" "$dst" 2>/dev/null || true
set +e                               # never disable broadly

# wrong — unexplained suppression
some_command 2>/dev/null || true

# wrong — a whole function silenced: every error in it is lost, not only the expected one
process_files() {
  cp -- "$src" "$dst"
  rmdir -- "$maybe_empty"
} 2>/dev/null
```

Suppress at the single command whose failure is expected, never on a whole function or compound command (`} 2>/dev/null`, `done 2>/dev/null`).

Verify system state after suppressed operations when possible.

## BCS0606 Conditional Declarations

**Tier:** core

Under `set -e`, a false arithmetic condition (e.g., `((DRY_RUN))` when `DRY_RUN=0`) returns exit code 1 and terminates the script. Any `&&` chain built on an arithmetic condition MUST end with `||:` to suppress this, unless the chain is expressed in inverted form with `||`.

**Mandatory (correctness):** the `&&`-chain form requires `||:`:

```bash
# correct — flag-guarded action, safely wrapped
((DRY_RUN)) && info 'Dry-run mode' ||:
((VERBOSE)) && echo "Processing $file" ||:
((DEBUG)) && set -x ||:
((VERBOSE < 3)) && VERBOSE+=1 ||:

# wrong — missing ||:, the chain returns 1 when the flag is 0: fatal as a function's last
# statement, inside $(...), or as the script's last command
((DRY_RUN)) && info 'Dry-run mode'
```

The inverted form avoids the issue because the RHS returns 0:

```bash
# correct — no ||: needed (RHS is an assignment or command returning 0)
((width >= 20)) || width=20
((padding >= 0)) || padding=0
((color_count < 256)) || HAS_COLOR=1
command -v curl >/dev/null || die 18 'curl required'
```

The `||:` catches failure from **the entire chain**, including the arithmetic condition -- not just the final command. Use `:` over `true` (shorter, built-in, traditional shell idiom).

**Style (preference only):** when `||:` is present, both the `&&...||:` form and the inverted `||` form are correct, as is an `if ((FLAG)); then ...; fi` block, which needs no `||:` and cannot hide a failure of the action. Pick whichever reads more naturally -- short guard clauses favour inversion; flag-guarded actions often favour `&&...||:`. **Neither form alone is a violation.** LLM-based checkers MUST NOT report a rule violation for form choice when `||:` is properly present.

**Never:** never use `||:` for critical operations that must succeed -- it masks real failures.
