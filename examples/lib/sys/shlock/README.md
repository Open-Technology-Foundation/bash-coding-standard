# shlock - File-based Locking System

A robust, production-ready file-based locking utility using `flock(1)` for safe concurrent script execution with stale lock detection and flexible waiting modes.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Options](#options)
- [Exit Codes](#exit-codes)
- [Examples](#examples)
- [How It Works](#how-it-works)
- [Use Cases](#use-cases)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Features

- **Exclusive Locking**: Prevents multiple instances of the same operation from running simultaneously
- **Stale Lock Detection**: Automatically removes locks left behind by crashed processes
- **Flexible Waiting Modes**:
  - Non-blocking (default): Fail immediately if lock is held
  - Blocking: Wait indefinitely for lock to become available
  - Timeout: Wait up to a specified number of seconds
- **PID Tracking**: Tracks which process holds each lock
- **Clean Exit Handling**: Automatic lock cleanup on normal exit or signal termination
- **Lock Stealing**: Administrative override to break held or abandoned locks (`--steal`)
- **Safe for Automation**: Ideal for cron jobs, systemd services, and CI/CD pipelines
- **Comprehensive Error Messages**: Clear, actionable error reporting
- **Battle-tested**: 153 comprehensive test cases

## Installation

### Complete Installation (Recommended)

Install the script, manpage, and bash completion using either the Makefile or installation script.

#### Using Makefile

```bash
# Install to /usr/local (default) - may require sudo
make install

# Install to /usr - requires sudo
sudo make PREFIX=/usr install

# Install to user directory (no sudo needed)
make PREFIX=~/.local install

# Uninstall
make uninstall
```

#### Using install.sh Script

```bash
# Install to /usr/local (default) - may require sudo
./install.sh install

# Install to /usr - requires sudo
sudo ./install.sh --prefix /usr install

# Install to user directory (no sudo needed)
./install.sh --prefix ~/.local install

# Skip confirmation prompts
./install.sh -y install

# Uninstall
./install.sh uninstall
```

### Partial Installation

Install only specific components:

#### Install Script Only

```bash
# Using Makefile
make install-script

# Using install.sh
./install.sh install-script
```

#### Install Manpage Only

```bash
# Using Makefile
make install-man

# Using install.sh
./install.sh install-man
```

#### Install Bash Completion Only

```bash
# Using Makefile
make install-completion

# Using install.sh
./install.sh install-completion
```

### Manual Installation

If you prefer manual installation:

```bash
# Copy script
sudo cp shlock /usr/local/bin/
sudo chmod +x /usr/local/bin/shlock

# Build and install manpage (requires pandoc)
pandoc --standalone --to man -o shlock.1 shlock.1.md
sudo cp shlock.1 /usr/local/share/man/man1/
sudo mandb -q

# Install bash completion
sudo cp shlock.bash_completion /usr/share/bash-completion/completions/shlock
```

### Direct Usage (No Installation)

Use directly from the repository without installing:

```bash
/ai/scripts/lib/shlock/shlock [OPTIONS] [LOCKNAME] -- COMMAND [ARGS...]
```

### Installation Requirements

**Script requirements:**
- Bash 5.0 or later
- `flock` utility (usually from `util-linux` package)
- `/run/lock` directory (standard on most Linux distributions)

**Manpage build requirements** (optional, only needed for `make install-man`):
- **pandoc** - Document converter

Install pandoc:
```bash
# Debian/Ubuntu
sudo apt install pandoc

# Fedora/RHEL
sudo dnf install pandoc

# macOS
brew install pandoc
```

### Bash Completion

Bash completion is automatically installed with `make install` or `./install.sh install`. It provides intelligent tab-completion for:

- **Options**: `-m`, `-w`, `-t`, `-s`, `-h`, `-V`, `--max-age`, `--wait`, `--timeout`, `--steal`, `--help`, `--version`
- **Lock names**: Existing locks from `/run/lock/*.lock`
- **Commands**: After `--`, completes available commands and files

**Manual activation** (if not using system-wide installation):

```bash
# Source completion for current shell
source shlock.bash_completion

# Or add to ~/.bashrc for permanent activation
echo 'source /path/to/shlock.bash_completion' >> ~/.bashrc
```

**Usage examples:**
```bash
shlock --<TAB>         # Shows: --help --max-age --steal --timeout --version --wait
shlock -m <TAB>        # Suggests hours values
shlock -t <TAB>        # Suggests seconds values
shlock backup<TAB>     # Shows existing lock names starting with 'backup'
shlock mylock -- <TAB> # Completes available commands
```

### Custom Prefix Configuration

If installing to a custom prefix (e.g., `~/.local`), add to your `~/.bashrc` or `~/.profile`:

```bash
export PATH="$HOME/.local/bin:$PATH"
export MANPATH="$HOME/.local/share/man:$MANPATH"

# Bash completion directory (if needed)
export BASH_COMPLETION_USER_DIR="$HOME/.local/share/bash-completion"
```

After installation to a custom prefix, restart your shell or run:
```bash
source ~/.bashrc
```

### Renaming the Script

You can rename the script to any name you prefer without affecting functionality. This is useful to avoid name conflicts with other programs:

```bash
# Rename to avoid conflicts
mv shlock sherlock
chmod +x sherlock

# Use with new name
sherlock backup -- /usr/local/bin/backup.sh
```

The script name is not referenced internally, so renaming has no effect on its operation.

## Usage

```bash
shlock [OPTIONS] [LOCKNAME] -- COMMAND [ARGS...]
```

### Arguments

- **LOCKNAME**: Unique identifier for the lock (e.g., `backup`, `deployment`, `sync`)
  - **Optional**: If omitted, auto-generated from basename of COMMAND
  - Example: `shlock -- /usr/local/bin/backup.sh` uses lockname "backup.sh"
- **COMMAND**: Command to execute while holding the lock
- **ARGS**: Optional arguments passed to COMMAND

**Important**: The `--` separator is required to separate options from the command.

## Options

| Option | Argument | Description |
|--------|----------|-------------|
| `-m, --max-age` | HOURS | Maximum lock age before considered stale (default: 24) |
| `-w, --wait` | - | Wait indefinitely for lock to become available |
| `-t, --timeout` | SECONDS | Maximum time to wait for lock |
| `-s, --steal` | - | Forcefully remove existing lock (prompts if holder is running) |
| `-h, --help` | - | Display help message |
| `-V, --version` | - | Display version information |

## Exit Codes

> **Breaking change in v2.0.0**: exit codes have been remapped to BCS-canonical values. Callers that branch on `$?` MUST update. See commit message and [CHANGELOG](#changelog) below.

| Code | Meaning |
|------|---------|
| 0 | Command executed successfully (wrapped command exit code passed through) |
| 1 | Lock held (non-timeout acquisition failure) or steal cancelled by user |
| 2 | Usage error (missing `COMMAND` or `--` separator) |
| 5 | I/O error (lock acquired but PID file write failed — post-acquisition disk/fs failure) |
| 13 | Permission denied (no writable lock directory, or lock file cannot be opened) |
| 22 | Invalid argument (unknown option, bad `LOCKNAME`, non-numeric value) |
| 24 | Timeout (`--timeout N` expired) |
| *other* | Propagated from the wrapped command (standard Unix-wrapper convention, matches `nice(1)`, `timeout(1)`, `sudo(1)`, `env(1)`) |

## Examples

### Basic Usage (Non-blocking)

Fail immediately if lock is already held:

```bash
# Explicit lock name
shlock backup -- /usr/local/bin/backup.sh

# Auto-generated lock name (from command basename)
shlock -- /usr/local/bin/backup.sh

# Lock with arguments
shlock sync -- rsync -av /src /dest

# Lock with custom stale threshold
shlock --max-age 12 critical -- /path/to/critical.sh
```

### Blocking Mode (Wait Indefinitely)

Wait until the lock becomes available:

```bash
# Wait for deployment lock
shlock --wait deployment -- ./deploy.sh production

# Wait with custom stale threshold
shlock --max-age 6 --wait database-backup -- /usr/local/bin/db-backup.sh
```

### Timeout Mode

Wait up to a specified time:

```bash
# Wait up to 30 seconds
shlock --timeout 30 sync -- rsync -av /src /dest

# Wait up to 5 minutes (300 seconds)
shlock --timeout 300 report -- /usr/local/bin/generate-report.sh

# Critical task with short timeout
shlock --timeout 10 healthcheck -- curl -f http://localhost/health
```

### Lock Stealing

Break held or abandoned locks:

```bash
# Steal an abandoned lock: no process holds it (automatic, no prompt)
shlock --steal backup -- /usr/local/bin/backup.sh

# Steal a lock a live process holds (prompts for confirmation, even when the
# holder's PID file is missing or stale)
shlock --steal deployment -- ./deploy.sh production
```

Without a terminal (cron, systemd) the confirmation prompt reads end-of-file and declines, so `--steal` breaks a held lock only when a person confirms; abandoned locks are still cleared unattended.

### Cron Job Usage

Prevent overlapping executions:

```bash
# In crontab with explicit lock name
*/5 * * * * /usr/local/bin/shlock backup -- /usr/local/bin/backup.sh 2>&1 | logger -t backup

# Using auto-generated lock name
*/5 * * * * /usr/local/bin/shlock -- /usr/local/bin/backup.sh 2>&1 | logger -t backup

# With timeout for long-running tasks
0 2 * * * /usr/local/bin/shlock --timeout 3600 nightly-job -- /usr/local/bin/nightly.sh
```

### Systemd Service

```bash
# In your script or ExecStart
ExecStart=/usr/local/bin/shlock --wait service-name -- /usr/local/bin/your-service
```

### CI/CD Pipeline

```bash
#!/bin/bash
# Ensure only one deployment runs at a time

if ! shlock --timeout 60 deploy-prod -- ./deploy.sh production; then
    case $? in
      1)  echo "Deployment already in progress (lock held)" ;;
      5)  echo "I/O error writing PID file after lock acquired" ;;
      24) echo "Timed out waiting for deployment lock" ;;
      *)  echo "shlock or deployment failed with code $?" ;;
    esac
    exit 1
fi
```

### Error Handling

```bash
#!/bin/bash

if shlock database-maintenance -- /usr/local/bin/maintenance.sh; then
    echo "Maintenance completed successfully"
else
    exit_code=$?
    case $exit_code in
        1)  echo "Lock is held by another process" ;;
        2)  echo "Usage error (missing COMMAND or -- separator)" ;;
        5)  echo "I/O error: PID file write failed after lock was acquired" ;;
        13) echo "Permission denied: lock directory or lock file not writable" ;;
        22) echo "Invalid argument" ;;
        24) echo "Timeout waiting for lock" ;;
        *)  echo "Maintenance script exited with code $exit_code" ;;
    esac
    exit $exit_code
fi
```

## How It Works

### Locking Mechanism

1. **LOCKNAME Resolution**: If LOCKNAME is omitted, derives it from the basename of COMMAND
2. **Lock Directory Determination**: Automatically selects lock directory:
   - Tries `/run/lock` (standard tmpfs location)
   - Falls back to `/var/lock` if `/run/lock` unavailable
   - Falls back to `/tmp/locks` (created if needed)
   - Fails if no directory is writable
3. **Lock File Path**: Constructs path `<LOCK_DIR>/<LOCKNAME>.lock`
4. **Lock Stealing** (optional): If `--steal` is specified, removes an existing lock first (auto-cleans locks no process holds, prompts when the holder is alive)
5. **Stale Lock Check**: If the lock file exists, cleans it up when either (a) older than `--max-age` with dead holder, or (b) within `--max-age` but holder process is dead. Refuses if an over-age lock's holder is alive (see [Stale Lock Detection](#stale-lock-detection))
6. **Lock Acquisition**: Uses `flock(1)` for atomic, kernel-level locking
7. **PID Tracking**: Writes the script's PID to `<LOCK_DIR>/<LOCKNAME>.pid`
8. **Command Execution**: Runs the specified command while holding the lock
9. **Cleanup**: On exit, removes the PID file only if it still records this process (a failed contender never deletes the holder's); lock file persists for reuse

### File Locations

Lock files are stored in the first writable directory from this list:

1. **`/run/lock/`** (preferred) - tmpfs filesystem, cleared on reboot
2. **`/var/lock/`** (fallback) - persistent across reboots on most systems
3. **`/tmp/locks/`** (last resort) - created automatically if needed, cleared on reboot

File patterns:
- **Lock files**: `<LOCK_DIR>/<LOCKNAME>.lock`
- **PID files**: `<LOCK_DIR>/<LOCKNAME>.pid`

### Stale Lock Detection

Before attempting to acquire the lock, shlock examines the existing lock file and applies one of two cleanup paths. The holder counts as **alive** if the PID in the PID file is running, or if a non-blocking `flock` probe finds the lock held: the PID file can be missing, unreadable or stale while its holder still runs, so shlock never removes a lock on the PID file's word alone.

1. **Age-based (`--max-age` exceeded)** — If the lock file mtime is older than `--max-age` hours (default: 24):
   - If the holder is **dead** → lock is removed (stale, cleaned).
   - If the holder is **alive** → lock acquisition fails with error code 1 (long-running process, not stale).

2. **Holder-based (within `--max-age`)** — If the lock file is younger than `--max-age`, the PID file holder is no longer running and no process holds the lock, the lock is reclaimed automatically with a warning. This covers crashes where the process died before releasing the lock. If the lock is still held (the PID file is stale), nothing is removed: shlock reports the lock as held, or waits for it with `--wait` / `--timeout`.

Both paths leave a live holder's lock untouched.

The lock is held through a file descriptor (fd 200) that the wrapped command inherits, as with `flock(1)`. If shlock itself is killed (`kill -9`) while its command keeps running, or the command leaves a background process holding the descriptor, the lock stays held until those processes exit: later runs report it as held, past `--max-age` too, instead of starting alongside them. Close fd 200 (`200>&-`) in background processes that should not keep the lock.

### Waiting Modes

**Non-blocking (default)**:
- Attempts to acquire lock once
- Fails immediately if lock is held
- Best for: Cron jobs where you want to skip if already running

**Blocking (`--wait`)**:
- Waits indefinitely for lock to become available
- Acquires lock as soon as it's released
- Best for: Sequential tasks that must eventually run

**Timeout (`--timeout SECONDS`)**:
- Waits up to specified seconds for lock
- Fails with exit code 24 if timeout expires
- Works independently — does not require `--wait`. If both are specified, `--timeout` takes priority
- Best for: Tasks with time constraints

## Use Cases

### 1. Prevent Overlapping Cron Jobs

```bash
# In crontab - runs every 5 minutes but skips if previous run is still active
*/5 * * * * shlock sync -- /usr/local/bin/sync-data.sh

# Or use auto-generated lock name
*/5 * * * * shlock -- /usr/local/bin/sync-data.sh
```

### 2. Serialize Database Operations

```bash
# Multiple scripts accessing the same database
shlock --wait database -- /usr/local/bin/db-operation-1.sh
shlock --wait database -- /usr/local/bin/db-operation-2.sh
```

### 3. Safe Deployment Pipeline

```bash
# Ensure only one deployment runs at a time
shlock --timeout 300 deployment -- ./deploy.sh "$ENVIRONMENT"
```

### 4. Resource-Intensive Tasks

```bash
# Prevent multiple instances of CPU/IO-heavy operations
shlock backup -- /usr/local/bin/full-backup.sh
shlock indexing -- /usr/local/bin/rebuild-search-index.sh
```

### 5. Graceful Service Restarts

```bash
# Prevent multiple restart attempts
shlock --timeout 30 service-restart -- systemctl restart myservice
```

### 6. Break Abandoned Locks

```bash
# When a lock was left behind by a crashed process
shlock --steal backup -- /usr/local/bin/backup.sh
```

## Testing

The utility includes a comprehensive test suite with 153 test cases covering all functionality.

### Running Tests

```bash
# Run all tests
cd /ai/scripts/lib/shlock/tests
./run_tests.sh

# Run specific test file
./test_basic.sh
./test_wait_timeout.sh
```

### Test Coverage

- **test_basic.sh** (21 tests): Basic functionality, argument handling, exit codes, short option bundling, wrapped command propagation
- **test_concurrent.sh** (13 tests): Concurrent lock acquisition, race conditions
- **test_edge_cases.sh** (26 tests): Edge cases, stress tests, special characters
- **test_errors.sh** (45 tests): Error handling, invalid inputs, signal handling, LOCKNAME sanitization, post-acquisition PID-file I/O failure, unopenable lock file, unreadable PID file, leading-zero numeric options
- **test_stale_locks.sh** (14 tests): Stale lock detection, max-age thresholds, live-holder refusal after a failed contender, live holder with a missing or stale PID file
- **test_steal.sh** (19 tests): Lock stealing, dead/running process handling, steal combinations, PID-file ownership on contention and steal, live holder with a missing or stale PID file
- **test_wait_timeout.sh** (15 tests): Blocking mode, timeout behavior, queuing

## Troubleshooting

### Lock Won't Release

**Symptom**: Lock appears held even though no process is running

**Solutions**:
```bash
# Use --steal to break a held lock
shlock --steal YOUR_LOCKNAME -- your-command

# Check for lock files
ls -la /run/lock/YOUR_LOCKNAME.*

# Check which process holds the lock
cat /run/lock/YOUR_LOCKNAME.pid
ps -p $(cat /run/lock/YOUR_LOCKNAME.pid)

# Force remove stale lock manually (use with caution)
rm -f /run/lock/YOUR_LOCKNAME.lock /run/lock/YOUR_LOCKNAME.pid
```

### Permission Denied

**Symptom**: Cannot create lock files

**Solutions**:
```bash
# Check /run/lock permissions
ls -ld /run/lock

# Ensure your user can write to /run/lock
# Typically this requires being in the appropriate group or running as root
```

### Timeout Not Working

**Symptom**: `--timeout` flag not recognized or failing

**Check**:
1. Verify `flock` supports `-w` option: `flock --help | grep -e '-w'`
2. Update util-linux if needed: `apt-get update && apt-get install util-linux`
3. Ensure timeout value is numeric and positive

### Lock Always Considered Stale

**Symptom**: Lock is removed even when process is running

**Check**:
```bash
# Verify timestamp on lock file
stat /run/lock/YOUR_LOCKNAME.lock

# Check if system time is correct
date
```

## Best Practices

### 1. Choose Meaningful Lock Names

```bash
# Good - explicit lock names
shlock database-backup -- ...
shlock customer-data-sync -- ...
shlock nightly-reports -- ...

# Also good - auto-generated from descriptive script names
shlock -- /usr/local/bin/database-backup.sh
shlock -- /usr/local/bin/customer-data-sync.sh

# Avoid
shlock lock1 -- ...
shlock temp -- ...
```

### 2. Set Appropriate max-age Values

```bash
# Short-running tasks (< 1 hour)
shlock --max-age 2 quick-sync -- ...

# Medium tasks (few hours)
shlock --max-age 12 backup -- ...

# Long-running tasks (overnight)
shlock --max-age 48 monthly-report -- ...
```

### 3. Use Timeout for Critical Paths

```bash
# Don't let deployments wait forever
shlock --timeout 300 deployment -- ./deploy.sh

# Quick healthchecks should timeout fast
shlock --timeout 5 healthcheck -- ./check-health.sh
```

### 4. Handle Exit Codes Properly

```bash
if ! shlock backup -- /usr/local/bin/backup.sh; then
    # Alert, log, or take corrective action
    echo "Backup failed or locked" | mail -s "Backup Alert" admin@example.com
fi
```

### 5. Log Lock Events

```bash
# In cron
* * * * * shlock task -- /path/to/script.sh 2>&1 | logger -t task-lock

# In scripts
shlock task -- /path/to/script.sh 2>&1 | tee -a /var/log/task.log
```

### 6. Combine with Monitoring

```bash
#!/bin/bash
# Check if lock is held too long

LOCK_FILE="/run/lock/backup.lock"
MAX_AGE_SECONDS=7200  # 2 hours

if [[ -f "$LOCK_FILE" ]]; then
    AGE=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE")))
    if ((AGE > MAX_AGE_SECONDS)); then
        echo "Warning: backup lock held for ${AGE} seconds" | \
            mail -s "Lock Alert" admin@example.com
    fi
fi
```

### 7. Document Lock Dependencies

```bash
# README or comment in script
# This script uses locks:
# - "database-backup" - Exclusive access to database during backup
# - "file-sync" - Prevents concurrent rsync operations
#
# Dependencies:
# - database-backup must complete before file-sync can run
```

## Advanced Usage

### Nested Operations (Different Locks)

```bash
#!/bin/bash
# Outer operation
shlock operation-a -- bash -c '
    echo "Running operation A"

    # Inner operation with different lock
    shlock operation-b -- echo "Running operation B"
'
```

### Conditional Locking

```bash
#!/bin/bash

if [[ "$FORCE" == "yes" ]]; then
    # Skip lock for forced execution
    /usr/local/bin/task.sh
else
    # Normal locked execution
    shlock task -- /usr/local/bin/task.sh
fi
```

### Integration with systemd

```ini
[Unit]
Description=My Locked Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/shlock --wait my-service -- /usr/local/bin/my-service.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

## Performance Considerations

- **Lock file creation**: Negligible overhead (< 1ms)
- **Lock acquisition**: Atomic kernel operation (< 1ms)
- **Stale lock check**: Single file stat + process check (< 10ms)
- **Lock release**: Automatic on process exit

The utility adds minimal overhead to command execution, making it suitable for frequent operations and time-sensitive tasks.

## Security Considerations

1. **File Permissions**: Lock files inherit permissions from `/run/lock` (typically world-writable with sticky bit)
2. **PID Spoofing**: The utility validates process existence but doesn't verify process identity
3. **Race Conditions**: `flock` provides atomic locking, preventing race conditions
4. **Symlink Attacks**: Lock files are created with `>` redirection, following symlinks

For security-critical applications, consider:
- Running with appropriate user permissions
- Using dedicated lock directories with restricted permissions
- Implementing additional process validation

## FAQ

**Q: What happens if the system crashes while holding a lock?**
A: The lock file persists but becomes stale. On next acquisition attempt, it will be removed if older than `--max-age` and the PID is not running.

**Q: Can I use the same lock name from different scripts?**
A: Yes, that's the intended use. The same lock name ensures mutual exclusion across all scripts using it.

**Q: What if `/run/lock` doesn't exist?**
A: shlock automatically falls back through multiple directories: `/run/lock` → `/var/lock` → `/tmp/locks` (created if needed). If none are writable, the script fails with an error message.

**Q: Is it safe to use in containers?**
A: Yes, but note that locks are container-scoped. Different containers don't share locks unless they share the same `/run/lock` volume.

**Q: Can I use this with non-Bash scripts?**
A: Yes, you can lock any executable: `shlock task -- python3 script.py` or `shlock task -- /usr/bin/my-binary`

**Q: How many locks can I have?**
A: Practically unlimited. Each lock is just two small files in the lock directory.

## Contributing

Contributions are welcome! Please ensure:
- All tests pass: `./tests/run_tests.sh`
- Shellcheck compliance: `shellcheck shlock`
- Documentation updates for new features

## License

This utility is part of the Okusi Group bash scripting standard library.

## Changelog

### v2.0.2 (2026-11-27)

Bug-fix release.

- **Mutual-exclusion fix** — a contender that failed to acquire the lock deleted the running holder's PID file (the EXIT trap is armed before `flock` and removed the file unconditionally). With the PID gone, `--steal` took the holder for dead and stole without prompting, and once the lock passed `--max-age` the next run removed it, so two holders ran at once. `cleanup()` now removes the PID file only if it records the exiting process, which also stops a stolen-from holder deleting the new holder's PID file on exit.
- **Exit code 13 extended** — failure to open the lock file (e.g. another user's lock file in `/run/lock`) now exits 13 with a message naming the file. It previously fell through `set -e` as exit 1, indistinguishable from "lock held".
- **Leading-zero numbers** — `-m 08` / `-t 09` aborted with an octal error (exit 1); `-t 010` meant 8 seconds. Numeric options are now always decimal.
- **Live holder with a missing, unreadable or stale PID file** — `--steal`, the age-stale cleanup and the dead-holder reclaim judged liveness from the PID file alone. A holder whose PID file was missing or named a dead process had its lock removed — by `--steal` without a prompt — and a second process acquired it. Every removal now also probes the lock with `flock -n`: a held lock makes `--steal` prompt, makes the age-stale check refuse (exit 1), and is left to `flock` in the fresh case (reported as held, or waited for). This covers a wrapper killed with `kill -9` whose command is still running: its lock now stays held until the command exits, where it used to be reclaimed and a second instance started beside it. Unattended, `--steal` no longer breaks such a lock (the prompt declines without a terminal).
- **Unreadable PID file** — `read_holder_pid` used `$(<file)`; on bash 5.2 a failed `$(<file)` aborts under `set -e` even before `||`, so an unreadable PID file, or one deleted between the size test and the read, killed shlock with a raw bash error. It now reads with `read` and reports the PID as unknown.
- **Held-lock message** names the holder PID only if that process is running; a stale PID file no longer names a dead process as the holder.
- **BCS hardening** — `--` before pathname operands of `mkdir`, `chmod`, `stat` (BCS1005); the "Expected -- after LOCKNAME" usage error now quotes the offending argument; parsed settings are readonly once validated; suppressed errors carry their reason.
- **Tests** — +13 assertions (PID-file ownership, steal and stale paths after a failed contender, unopenable lock file, leading zeros, live holder with a missing or stale PID file under `--steal` and the stale checks, unreadable PID file); documented `test_steal.sh` count corrected (it already had 14, not 12); bwrap exit-13 test now skips when bwrap cannot create a sandbox (`kernel.apparmor_restrict_unprivileged_userns=1`); suite runs 153 cases.
- **Test suite BCS cleanup** — all seven suites and `run_tests.sh`: `PATH` hardened; no `set +e` (statuses captured with `|| rc=$?`); every background job reaped with its expected exit status checked instead of `wait … || true`, concurrent jobs reaped together (`reap_all`) so one failure cannot hide another's status; mtime backdating aborts the suite on failure instead of silently testing a fresh lock; scratch files in a per-suite `mktemp -d` directory instead of predictable `/tmp/…_$$` paths; `[[ -f ]]` instead of `test -f`; `--` before pathname operands; fixture setup guarded by a `setup_failed` helper that names the failing line; `assert_duration` checks the exit code as well as the elapsed time; PID files read with `read` in one checked step (a vanishing file no longer aborts a suite); runner declares its loop variables and sends all its own output, summary included, to stderr (stdout carries only the suites' output); shellcheck clean.

### v2.0.1 (2026-04-23)

Bug-fix and hardening release. No CLI or exit-code changes for successful paths.

- **New exit code 5** — I/O failure writing the PID file *after* the lock has been acquired (disk full, read-only filesystem, etc.). Previously surfaced as an opaque `echo` failure.
- **Trap ordering fix** — `trap cleanup EXIT` is now installed immediately after opening fd 200, not after `flock` succeeds. An abort between those two steps still runs cleanup.
- **Stale-lock reclaim** — locks younger than `--max-age` but held by a dead PID are now reclaimed automatically with a warning (previously left to age-out).
- **Installation** — `COMPDIR` default now tiers by `PREFIX`: system installs (`/usr`, `/usr/local`) place completion at `/etc/bash_completion.d/shlock`; user/custom prefixes place it at `$PREFIX/share/bash-completion/completions/shlock`. Overridable via `make COMPDIR=…` or `COMPDIR=… ./install.sh`.
- **Tests** — +9 assertions for edge coverage; +2 assertions for exit-code-5 (post-acquisition PID-file I/O failure); suite runs 138 cases.
- **Help output** — minor formatting alignment (BCS0704).

### v2.0.0 (2026-04-19) — Breaking Change

Exit codes remapped to BCS-canonical values. **No compatibility flag provided** — callers that branch on `$?` MUST update.

Migration:

| Old | New | Meaning |
|-----|-----|---------|
| 1 | 1 | Lock held, steal cancelled (unchanged) |
| 1 | 13 | No writable lock directory |
| 1 | 24 | `--timeout` expired |
| 2 | 2 | Missing `COMMAND` or `--` separator (unchanged) |
| 2 | 22 | Unknown option, invalid `LOCKNAME`, non-numeric `-m`/`-t` |
| 3 | *propagated* | Wrapped command's own exit code |

The "Command failed with exit code N" message has been removed; the wrapped command's own stderr is authoritative. shlock is now a transparent wrapper matching `nice(1)`, `timeout(1)`, `sudo(1)`, and `env(1)`.

### v1.0.4 and earlier

See `git log`.

## See Also

- `flock(1)` - Linux manual page
- `fcntl(2)` - POSIX file locking
- Bash Coding Standard: `/usr/local/share/yatti/BCS/data/`

---

**Version**: 2.0.2
**Last Updated**: 2026-11-27
**Maintainer**: Gary Dean (Biksu Okusi)
