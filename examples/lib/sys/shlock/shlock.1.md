% SHLOCK(1) shlock 2.0.2
% Gary Dean (Biksu Okusi)
% November 2026

# NAME

shlock - file-based locking utility with stale lock detection

# SYNOPSIS

**shlock** [*OPTIONS*] [*LOCKNAME*] **--** *COMMAND* [*ARGS*...]

# DESCRIPTION

**shlock** provides exclusive file-based locking using **flock**(1) for safe concurrent script execution. It prevents multiple instances of the same operation from running simultaneously and includes automatic stale lock detection for cleanup of locks left behind by crashed processes.

The lock is held using kernel-level **flock**(1) on a lock file, ensuring atomic lock acquisition and automatic release when the process terminates. A separate PID file tracks which process holds the lock for informational purposes and stale lock validation. The lock directory is automatically determined with fallback (see **FILES**).

## Key Features

- **Exclusive locking**: Only one instance of a locked operation can run at a time
- **Stale lock detection**: Automatically removes locks from dead processes
- **Flexible waiting modes**: Non-blocking, timeout-based, or indefinite waiting
- **PID tracking**: Identifies which process holds each lock
- **Lock stealing**: Administrative override to break held locks
- **Clean exit handling**: Automatic cleanup on normal exit or signal termination
- **Safe for automation**: Designed for cron jobs, systemd services, and CI/CD pipelines

# ARGUMENTS

*LOCKNAME*
:   Unique identifier for the lock (e.g., "backup", "deployment", "sync").
    If omitted, automatically derived from the basename of *COMMAND*.
    For example, `shlock -- /usr/local/bin/backup.sh` uses lockname "backup.sh".

*COMMAND*
:   Command to execute while holding the lock.

*ARGS*
:   Optional arguments passed to *COMMAND*.

**Important**: The `--` separator is required to clearly delineate lock options from the wrapped command and its arguments.

# OPTIONS

**-m**, **--max-age** *HOURS*
:   Maximum lock age in hours before considered stale (default: 24).
    If a lock file is older than this threshold and the owning process is no longer running, the lock is automatically removed.

**-w**, **--wait**
:   Wait indefinitely for lock to become available instead of failing immediately.
    The process will block until the lock can be acquired.

**-t**, **--timeout** *SECONDS*
:   Maximum time to wait for lock acquisition in seconds.
    If the lock cannot be acquired within this time, exits with code 24.
    Works independently; does not require **--wait**.

**-s**, **--steal**
:   Forcefully remove an existing lock. If no process holds the lock (its holder
    died), the lock is removed automatically without prompting. If the holder is
    alive (its recorded PID is running, or the lock is held even though the PID
    file is missing, unreadable or stale), displays a warning and prompts for
    confirmation before stealing. Exits with code 1 if the user declines.
    Without a terminal the prompt reads end-of-file and declines, so a held
    lock is never stolen unattended.

**-h**, **--help**
:   Display help message and exit.

**-V**, **--version**
:   Display version information and exit.

**Note**: Short option bundling is supported. The argument-taking option must be last in the bundle. For example: **-wt 60** or **-wm 12**.

# EXIT STATUS

Exit codes follow the Bash Coding Standard (BCS) canonical table. **v2.0.0 is a breaking change from v1.0.x** — callers that branch on `$?` must update.

**0**
:   Command executed successfully (wrapped command's exit code was 0, passed through).

**1**
:   Lock held (non-timeout acquisition failure) or steal cancelled by user.

**2**
:   Usage error (missing *COMMAND* or `--` separator).

**5**
:   I/O error: failed to write PID file after acquiring the lock. The lock is released on exit (fd 200 closes); any partial state is cleaned up by the EXIT trap.

**13**
:   Permission denied: no writable lock directory in `/run/lock`, `/var/lock`, or `/tmp/locks`, or the lock file cannot be opened (e.g. another user's lock file).

**22**
:   Invalid argument (unknown option, bad *LOCKNAME*, non-numeric `-m`/`-t` value).

**24**
:   Timeout (`--timeout N` expired before lock became available).

*other*
:   Any other non-zero code is propagated unchanged from the wrapped command (standard Unix-wrapper convention — matches **nice**(1), **timeout**(1), **sudo**(1), **env**(1)).

The distinction between code 1 (lock held), code 24 (timed out), and a propagated non-zero (wrapped command ran but failed) is important for automation. Prior to v2.0.0, all three collapsed into codes 1 and 3.

# EXAMPLES

## Basic Usage

Non-blocking lock (default):

```bash
shlock backup -- /usr/local/bin/backup.sh
```

Auto-generate lock name from command:

```bash
shlock -- /usr/local/bin/backup.sh
# Uses lockname "backup.sh"
```

## Waiting Modes

Wait indefinitely for lock:

```bash
shlock --wait deployment -- ./deploy.sh production
```

Wait up to 30 seconds:

```bash
shlock --timeout 30 sync -- rsync -av /src /dest
```

Using short options with timeout:

```bash
shlock -t 60 -m 6 backup -- /usr/local/bin/backup.sh
```

## Cron Integration

Prevent overlapping cron jobs:

```bash
# In /etc/cron.d/backup
0 2 * * * root shlock daily-backup -- /usr/local/bin/backup.sh

# If previous backup still running, this one exits immediately (code 1 = lock held)
```

Handle cron job failures gracefully:

```bash
# Only alert if job actually ran and failed; skip silently when locked or timed out
0 2 * * * root shlock backup -- /usr/local/bin/backup.sh || \
  { rc=$?; [ "$rc" -eq 1 ] || [ "$rc" -eq 24 ] || \
    mail -s "Backup failed (rc=$rc)" admin@example.com; }
```

## Systemd Service Integration

Prevent concurrent service executions:

```ini
# /etc/systemd/system/data-sync.service
[Unit]
Description=Data Synchronization

[Service]
Type=oneshot
ExecStart=/usr/local/bin/shlock data-sync -- /usr/local/bin/sync.sh
Restart=no

[Install]
WantedBy=multi-user.target
```

With timeout for service watchdog:

```ini
[Service]
Type=oneshot
ExecStart=/usr/local/bin/shlock --timeout 300 data-sync -- /usr/local/bin/sync.sh
TimeoutStartSec=310
```

## CI/CD Pipeline Integration

Serialize deployments to prevent conflicts:

```yaml
# GitLab CI example
deploy:
  script:
    - shlock --timeout 600 deploy-prod -- ./deploy.sh production
  only:
    - main
```

Ensure only one build per branch:

```bash
#!/bin/bash
# build.sh
BRANCH=$(git rev-parse --abbrev-ref HEAD)
shlock "build-$BRANCH" -- npm run build
```

## Stale Lock Handling

Custom stale lock threshold (12 hours):

```bash
shlock --max-age 12 critical -- /path/to/critical.sh
```

Very short-lived locks (1 hour threshold):

```bash
shlock -m 1 quick-task -- /path/to/task.sh
```

## Lock Stealing

Steal a lock from a dead or running process:

```bash
shlock --steal backup -- /usr/local/bin/backup.sh
```

Combine steal with short option bundling:

```bash
shlock -st 30 backup -- /usr/local/bin/backup.sh
```

If no process holds the lock, it is removed automatically. If the holder is alive (by its recorded PID or, when the PID file is missing or stale, by a **flock** probe), **shlock** displays a warning and prompts for confirmation.

## Error Handling in Scripts

Distinguish between locked and failed:

```bash
#!/bin/bash
set -euo pipefail

if ! shlock myapp -- /path/to/command; then
  case $? in
    1)  echo "Already running, skipping..." >&2; exit 0 ;;
    2)  echo "Usage error" >&2; exit 2 ;;
    5)  echo "I/O error writing PID file" >&2; exit 5 ;;
    13) echo "Lock directory or lock file not writable" >&2; exit 13 ;;
    22) echo "Invalid argument" >&2; exit 22 ;;
    24) echo "Timeout waiting for lock" >&2; exit 24 ;;
    *)  rc=$?; echo "Command failed with exit code $rc" >&2; exit "$rc" ;;
  esac
fi
```

Retry logic with timeout:

```bash
for i in {1..3}; do
  if shlock --timeout 10 myapp -- /path/to/command; then
    exit 0
  fi
  echo "Attempt $i failed, retrying..." >&2
  sleep 5
done
echo "All attempts failed" >&2
exit 1
```

# INTERNALS

## Locking Mechanism

**shlock** uses a multi-phase approach to lock acquisition:

1. **Argument parsing**: Resolves *LOCKNAME* from arguments or derives from *COMMAND* basename
2. **Lock directory determination**: Selects first writable directory from `/run/lock`, `/var/lock`, `/tmp/locks`
3. **Lock stealing** (if **--steal**): Removes existing lock, prompting only if the holder is alive
4. **Stale lock check**: Validates lock age and holder liveness, removes stale locks no process holds
5. **Lock acquisition**: Opens file descriptor 200 on `<LOCK_DIR>/<LOCKNAME>.lock` and attempts **flock**(1)
6. **PID tracking**: Writes current process ID to `<LOCK_DIR>/<LOCKNAME>.pid`
7. **Command execution**: Runs *COMMAND* while holding lock, captures exit code
8. **Cleanup**: EXIT trap removes the PID file if it records this process, **flock** releases when fd closes

## File Descriptor 200

**shlock** uses file descriptor 200 for lock file operations. This hardcoded descriptor is chosen to:

- Avoid conflicts with standard descriptors (0, 1, 2)
- Remain outside typical script descriptor ranges
- Provide consistent, predictable behavior

If your scripts use fd 200, this may cause conflicts. Consider modifying **shlock** or avoiding fd 200 in wrapped commands.

## Lock File Persistence

Lock files at `<LOCK_DIR>/<LOCKNAME>.lock` are NOT deleted after use. They persist (empty) for reuse on subsequent acquisitions. This is intentional and follows standard **flock**(1) behavior:

- Avoids race conditions during lock file recreation
- Reduces filesystem operations
- Enables atomic lock semantics

The PID file (`<LOCK_DIR>/<LOCKNAME>.pid`) is temporary and removed by the EXIT trap of the process that wrote it. A contender that fails to acquire the lock leaves the holder's PID file alone, so stale-lock and **--steal** checks can still see a live holder.

## Stale Lock Detection Algorithm

Before attempting to acquire the lock, **shlock** examines the existing lock file and applies one of two cleanup paths. The holder counts as alive if the recorded PID is running (`kill -0 <PID>` succeeds) or if a non-blocking **flock** probe finds the lock held. The PID file can be missing, unreadable or stale while its holder still runs, so no lock file is removed on its word alone. The probe opens the file read-only, leaving its mtime unchanged, and treats a file it cannot open as held.

1. Check if lock file exists; read modification time (mtime).
2. Read PID from `<LOCK_DIR>/<LOCKNAME>.pid` (validated as positive integer).
3. **Age-based path** — if age > **--max-age** (converted to seconds):
    - If the holder is dead: remove both **.lock** and **.pid** files.
    - If the holder is alive: exit with code 1 (lock held by long-running process).
4. **Holder-based path** — if age ≤ **--max-age**, the holder PID is no longer running and the lock is not held:
    - Remove both **.lock** and **.pid** files, log a warning, and proceed.
    - If the lock is held after all (stale PID file), nothing is removed: acquisition reports the lock as held, or waits for it.

This ensures crashed processes don't block future executions (regardless of crash age), while still respecting legitimately long-running processes that exceed **--max-age**.

The lock is held through file descriptor 200, which *COMMAND* inherits, as with **flock**(1). If **shlock** itself is killed (SIGKILL) while *COMMAND* keeps running, or *COMMAND* leaves a background process holding the descriptor, the lock stays held until those processes exit: later runs report it as held, past **--max-age** too, rather than starting alongside them. Close fd 200 (`200>&-`) in background processes that should not keep the lock.

## Waiting Modes

Three distinct locking modes are supported:

**Non-blocking (default)**
:   Uses `flock -n` to fail immediately if lock is held. Exit code 1 if locked.

**Timeout mode (--timeout N)**
:   Uses `flock -w SECONDS` to wait up to specified time. Exit code 24 if timeout expires.

**Indefinite wait (--wait)**
:   Uses `flock` without flags to wait indefinitely until lock is available.

Priority order: **--timeout** > **--wait** > non-blocking. If both **--timeout** and **--wait** are specified, timeout takes precedence.

# INTEGRATION

## Systemd Timer Integration

Prevent timer-triggered services from overlapping:

```ini
# /etc/systemd/system/backup.timer
[Unit]
Description=Daily backup timer

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

```ini
# /etc/systemd/system/backup.service
[Unit]
Description=Daily backup

[Service]
Type=oneshot
ExecStart=/usr/local/bin/shlock backup -- /usr/local/bin/backup.sh
```

Enable with:

```bash
systemctl enable --now backup.timer
```

## Cron Best Practices

Always use explicit lock names for clarity:

```bash
# Good: explicit lock name
0 2 * * * shlock daily-backup -- /usr/local/bin/backup.sh

# Also good: auto-generated from command
0 2 * * * shlock -- /usr/local/bin/backup.sh
```

Use timeout to prevent infinite waits in cron:

```bash
# Wait max 5 minutes, then fail
*/15 * * * * shlock --timeout 300 sync -- /usr/local/bin/sync.sh
```

## CI/CD Best Practices

Use branch-specific locks to allow parallel builds:

```bash
LOCK="deploy-$(git rev-parse --abbrev-ref HEAD)"
shlock --timeout 900 "$LOCK" -- ./deploy.sh
```

Combine with deployment gates:

```yaml
deploy:
  stage: deploy
  script:
    - shlock --timeout 600 deploy-prod -- ./deploy.sh production
  when: manual
  only:
    - main
```

# FILES

`<LOCK_DIR>/<LOCKNAME>.lock`
:   Lock file used for **flock**(1) operations. Persists (empty) after use for reuse.
    The location of `<LOCK_DIR>` is automatically determined (see Lock Directory Selection below).

`<LOCK_DIR>/<LOCKNAME>.pid`
:   PID file containing process ID of lock holder. Removed by the holder's EXIT trap.
    Used for informational error messages and stale lock validation.

## Lock Directory Selection

**shlock** automatically selects the first writable directory from this list:

**/run/lock/**
:   Standard Linux lock directory (tmpfs). World-writable with sticky bit set.
    Automatically managed by **systemd-tmpfiles**(8). Cleared on reboot.
    **This is the preferred location.**

**/var/lock/**
:   Traditional lock directory. May persist across reboots on some systems.
    Used as fallback if `/run/lock` is unavailable or not writable.

**/tmp/locks/**
:   Last resort directory. Automatically created if it doesn't exist.
    Usually cleared on reboot. Only used if both above directories are unavailable.

If none of these directories are writable, **shlock** exits with code 13 (permission denied).

# NOTES

- Lock names should be unique within your system to prevent unintended conflicts.
- Lock directories on tmpfs are cleared on reboot, automatically removing all locks.
- Locks are automatically released when the process terminates (normal exit, signal, or crash).
- For very long-running commands, consider adjusting **--max-age** to prevent premature stale lock detection.
- PID reuse is possible but rare. It can only make a dead holder look alive, so **shlock** refuses or prompts instead of removing the lock; a live holder never looks dead, because the **flock** probe overrides the PID file.

# BUGS

No known bugs. Report issues at <https://github.com/Open-Technology-Foundation/bash-coding-standard/issues>.

# SEE ALSO

**flock**(1), **systemd-tmpfiles**(8), **flock**(2), **cron**(8), **systemd.service**(5), **systemd.timer**(5)

# AUTHOR

Gary Dean (Biksu Okusi) <https://garydean.id>

