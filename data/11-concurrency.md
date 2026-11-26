<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Section 11: Concurrency & Jobs

## BCS1100 Section Overview

Background job management, parallel execution, wait patterns, timeouts, and retry logic. Never leave background jobs unmanaged.

## BCS1101 Background Job Management

**Tier:** core

Always track PIDs when starting background jobs.

```bash
# correct
command &
pid=$!

# correct — multiple PIDs
declare -a pids=()
command1 &
pids+=($!)
command2 &
pids+=($!)

# correct — check if process is running
kill -0 "$pid" 2>/dev/null           # signal 0 = existence check

# correct — cleanup in trap (EXIT runs on INT and TERM too: BCS0603)
cleanup() {
  local -i exitcode=${1:-$?}
  local -- pid
  trap - EXIT
  for pid in "${pids[@]}"; do
    kill "$pid" 2>/dev/null ||:      # a job that already exited has nothing to kill
  done
  exit "$exitcode"
}
trap 'cleanup $?' EXIT

# wrong
command &                            # untracked background job

# wrong — a loop of untracked jobs: nothing can wait on any of them
for f in ./*.in; do process_one "$f" & done
```

This rule owns the **untracked** job -- one whose `$!` is never captured, so
nothing can wait on it. What becomes of the exit code of a `wait` that does run
is BCS1103's finding; a script that starts jobs and never waits at all is cited
here alone.

Use `$!` for the last background PID. Never use `$$` (that's the parent PID).

## BCS1102 Parallel Execution

**Tier:** recommended

For ordered output, write results to temp files then display in order.

```bash
# correct — parallel with ordered output
declare -- temp_dir=''
trap '[[ -z $temp_dir ]] || rm -rf -- "$temp_dir"' EXIT
temp_dir=$(mktemp -d) || die 1 'Failed to create temp dir'
declare -a pids=()
declare -i i errors=0

# output files are named by index: a server name may contain '/' or repeat
for i in "${!servers[@]}"; do
  check_server "${servers[i]}" &> "$temp_dir"/"$i".out &
  pids[i]=$!
done

# Wait and display in order; accumulate failures (BCS1103)
for i in "${!servers[@]}"; do
  wait "${pids[i]}" || errors+=1
  cat -- "$temp_dir"/"$i".out
done
((errors == 0)) || die 1 "$errors job(s) failed"
```

Implement concurrency limits by checking the number of running jobs against `max_jobs` and using `wait -n` to wait for a slot; `wait -n -p` (Bash 5.1+) names the job that finished, so it can be removed from the list (BCS1103).

Never modify variables in background subshells expecting parent visibility — use temp files for results.

## BCS1103 Wait Patterns

**Tier:** core

Never discard the exit code of `wait`. Accumulate failures into a counter and fail the script once at the end if any background job failed. An unsuppressed `wait` under `set -e` terminates the script on the first failure -- losing information about other in-flight jobs.

```bash
# correct — accumulator pattern over a fixed list of pids
declare -i errors=0
for pid in "${pids[@]}"; do
  wait "$pid" || errors+=1
done
((errors == 0)) || die 1 "$errors job(s) failed"

# correct — process-as-completed (Bash 5.1+): -p names the job that finished,
# and the explicit pid list keeps wait -n from answering for any other child
declare -i errors=0
declare -A running=()
declare -- pid done_pid
for pid in "${pids[@]}"; do running[$pid]=1; done
while ((${#running[@]})); do
  wait -n -p done_pid "${!running[@]}" || errors+=1
  unset 'running[$done_pid]'
done
((errors == 0)) || die 1 "$errors job(s) failed"

# wrong — a bare wait -n also returns for a background job the list does not hold,
# and the loop drops pids[0], not the job that finished: it can end with errors=0
# while a tracked job that will fail is still running
while ((${#pids[@]})); do
  wait -n || errors+=1
  pids=("${pids[@]:1}")
done

# wrong — exit code discarded; failures silent
wait "$pid" ||:

# wrong — no accumulator; first failure kills script under set -e
for pid in "${pids[@]}"; do
  wait "$pid"
done

# not this rule — nothing was tracked and nothing waits: cite BCS1101
command &
```

This rule governs a `wait` that runs. Where no PID was captured and the script
never waits at all, the finding is BCS1101's (untracked job), not this rule's.

## BCS1104 Timeout Handling

**Tier:** core

Wrap network and remote operations (`ssh`, `curl`, `wget`, `nc`) with `timeout` or tool-native timeout flags. Bounding other operations that can block indefinitely — interactive `read` (use `read -t`), long-running local commands — is recommended but not required by this rule.

```bash
# correct
timeout 300 ssh -o ConnectTimeout=10 "$server" 'command'
timeout --signal=TERM --kill-after=10 60 long_command

# correct — an interactive command, or one a terminal Ctrl-C must reach: without
# --foreground, timeout moves it into its own process group, where it cannot read
# the terminal and never sees Ctrl-C (children of the command are then not timed out)
timeout --foreground 300 ssh "$server"

# correct — capture the exit code first; a bare command under set -e aborts
# before any `case $?` could run, so guard with `|| rc=$?`
declare -i rc=0
timeout 300 ssh -o ConnectTimeout=10 "$server" 'command' || rc=$?
case $rc in
  0)   success 'Command completed' ;;
  124) error 'Command timed out' ;;
  125) error 'Timeout itself failed' ;;
  *)   error 'Command failed' ;;
esac

# correct — user input timeout with default
read -r -t 10 -p 'Enter value: ' value || value='default'

# correct — SSH and curl timeouts
# ConnectTimeout bounds connection only — wrap in `timeout` to bound total runtime
timeout 300 ssh -o ConnectTimeout=10 -o BatchMode=yes "$host" 'command'
curl --connect-timeout 10 --max-time 60 "$url"
```

## BCS1105 Exponential Backoff

**Tier:** recommended

Use exponential backoff for retries. Never use fixed delays.

```bash
# correct
declare -i attempt=1 max_attempts=5 delay max_delay=60 jitter
declare -- out=''
trap '[[ -z $out ]] || rm -f -- "$out"' EXIT
out=$(mktemp) || die 1 'Failed to create temp file'

while ((attempt <= max_attempts)); do
  # Success requires both exit code 0 and non-empty output
  if try_operation > "$out" && [[ -s "$out" ]]; then
    break
  fi

  # no sleep after the last attempt: nothing follows it
  if ((attempt < max_attempts)); then
    delay=$((2 ** attempt))
    ((delay > max_delay)) && delay=$max_delay ||:
    # Add jitter to prevent thundering herd
    jitter=$((RANDOM % delay))
    sleep $((delay + jitter))
  fi

  attempt+=1
done
((attempt <= max_attempts)) || die 1 "operation failed after $max_attempts attempts"

# wrong — tight retry loop
while ! curl "$url"; do :; done      # floods failing services
```

Validate success conditions beyond exit code — the example treats empty output as failure via `[[ -s "$out" ]]`.
