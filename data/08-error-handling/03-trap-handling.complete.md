## Trap Handling

**Standard cleanup pattern:**

\`\`\`bash
cleanup() {
  local -i exitcode=${1:-0}

  # Disable trap during cleanup to prevent recursion
  trap - SIGINT SIGTERM EXIT

  # Cleanup operations
  [[ -n "$temp_dir" && -d "$temp_dir" ]] && rm -rf "$temp_dir"
  [[ -n "$lockfile" && -f "$lockfile" ]] && rm -f "$lockfile"

  # Log cleanup completion
  ((exitcode == 0)) && info 'Cleanup completed successfully' || warn "Cleanup after error (exit $exitcode)"

  exit "$exitcode"
}

# Install trap
trap 'cleanup $?' SIGINT SIGTERM EXIT
\`\`\`

**Rationale for trap handling:**
- **Resource cleanup**: Ensures temp files, locks, processes are cleaned up even on errors
- **Signal handling**: Responds to Ctrl+C (SIGINT), kill (SIGTERM), and normal exit
- **Preserves exit code**: `$?` captures original exit status
- **Prevents partial state**: Cleanup runs regardless of how script exits

**Understanding trap signals:**

| Signal | Meaning | When Triggered |
|--------|---------|----------------|
| `EXIT` | Script exit | Always runs on script exit (normal or error) |
| `SIGINT` | Interrupt | User presses Ctrl+C |
| `SIGTERM` | Terminate | `kill` command (default signal) |
| `ERR` | Error | Command fails (with `set -e`) |
| `DEBUG` | Debug | Before every command (debugging only) |

**Common trap patterns:**

**1. Temp file cleanup:**
\`\`\`bash
# Create temp file
temp_file=$(mktemp) || die 1 'Failed to create temp file'
trap 'rm -f "$temp_file"' EXIT

# Script uses temp_file
echo "data" > "$temp_file"
# ...

# Cleanup happens automatically on exit
\`\`\`

**2. Temp directory cleanup:**
\`\`\`bash
# Create temp directory
temp_dir=$(mktemp -d) || die 1 'Failed to create temp directory'
trap 'rm -rf "$temp_dir"' EXIT

# Use temp directory
extract_archive "$archive" "$temp_dir"
# ...

# Directory automatically cleaned up on exit
\`\`\`

**3. Lockfile cleanup:**
\`\`\`bash
lockfile="/var/lock/myapp.lock"

acquire_lock() {
  if [[ -f "$lockfile" ]]; then
    die 1 "Already running (lock file exists: $lockfile)"
  fi
  echo $$ > "$lockfile" || die 1 'Failed to create lock file'
  trap 'rm -f "$lockfile"' EXIT
}

acquire_lock
# Script runs exclusively
# Lock released automatically on exit
\`\`\`

**4. Process cleanup:**
\`\`\`bash
# Start background process
long_running_command &
bg_pid=$!

# Ensure background process is killed on exit
trap 'kill $bg_pid 2>/dev/null' EXIT

# Script continues
# Background process killed automatically on exit
\`\`\`

**5. Comprehensive cleanup function:**
\`\`\`bash
#!/usr/bin/env bash
set -euo pipefail

# Global cleanup resources
declare -- temp_dir=''
declare -- lockfile=''
declare -i bg_pid=0

cleanup() {
  local -i exitcode=${1:-0}

  # Disable trap to prevent recursion
  trap - SIGINT SIGTERM EXIT

  # Kill background processes
  ((bg_pid > 0)) && kill "$bg_pid" 2>/dev/null

  # Remove temp directory
  if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
    rm -rf "$temp_dir" || warn "Failed to remove temp directory: $temp_dir"
  fi

  # Remove lockfile
  if [[ -n "$lockfile" && -f "$lockfile" ]]; then
    rm -f "$lockfile" || warn "Failed to remove lockfile: $lockfile"
  fi

  # Log exit
  if ((exitcode == 0)); then
    info 'Script completed successfully'
  else
    error "Script exited with error code: $exitcode"
  fi

  exit "$exitcode"
}

# Install trap EARLY (before creating resources)
trap 'cleanup $?' SIGINT SIGTERM EXIT

# Create resources
temp_dir=$(mktemp -d)
lockfile="/var/lock/myapp-$$.lock"
echo $$ > "$lockfile"

# Start background job
monitor_process &
bg_pid=$!

# Main script logic
main "$@"

# cleanup() called automatically on exit
\`\`\`

**Multiple trap handlers (bash 3.2+):**
\`\`\`bash
# Can combine multiple traps for same signal
trap 'echo "Exiting..."' EXIT
trap 'rm -f "$temp_file"' EXIT  # ✗ This REPLACES the previous trap!

# ✓ Correct - combine in one trap
trap 'echo "Exiting..."; rm -f "$temp_file"' EXIT

# ✓ Or use a cleanup function
trap 'cleanup' EXIT
\`\`\`

**Trap execution order:**
\`\`\`bash
# Traps execute in order: specific signal, then EXIT
trap 'echo "SIGINT handler"' SIGINT
trap 'echo "EXIT handler"' EXIT

# On Ctrl+C:
# 1. SIGINT handler runs
# 2. EXIT handler runs
# 3. Script exits
\`\`\`

**Disabling traps:**
\`\`\`bash
# Disable specific trap
trap - EXIT
trap - SIGINT SIGTERM

# Disable trap during critical section
trap - SIGINT  # Ignore Ctrl+C during critical operation
perform_critical_operation
trap 'cleanup $?' SIGINT  # Re-enable
\`\`\`

**Trap gotchas and best practices:**

**1. Trap recursion prevention:**
\`\`\`bash
cleanup() {
  # ✓ CRITICAL: Disable trap first to prevent recursion
  trap - SIGINT SIGTERM EXIT

  # If cleanup fails, trap won't trigger again
  rm -rf "$temp_dir"  # If this fails...
  exit "$exitcode"    # ...we still exit cleanly
}
\`\`\`

**2. Preserve exit code:**
\`\`\`bash
# ✓ Correct - capture $? immediately
trap 'cleanup $?' EXIT

# ✗ Wrong - $? may change between trigger and handler
trap 'cleanup' EXIT  # $? inside cleanup may be different
\`\`\`

**3. Quote trap commands:**
\`\`\`bash
# ✓ Correct - single quotes prevent early expansion
trap 'rm -f "$temp_file"' EXIT

# ✗ Wrong - double quotes expand variables now, not on trap
temp_file="/tmp/foo"
trap "rm -f $temp_file" EXIT  # Expands to: trap 'rm -f /tmp/foo' EXIT
temp_file="/tmp/bar"  # Trap still removes /tmp/foo!
\`\`\`

**4. Set trap early:**
\`\`\`bash
# ✓ Correct - set trap BEFORE creating resources
trap 'cleanup $?' EXIT
temp_file=$(mktemp)

# ✗ Wrong - resource created before trap installed
temp_file=$(mktemp)
trap 'cleanup $?' EXIT  # If script exits between these lines, temp_file leaks!
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - not preserving exit code
trap 'rm -f "$temp_file"; exit 0' EXIT  # Always exits with 0!

# ✓ Correct - preserve exit code
trap 'exitcode=$?; rm -f "$temp_file"; exit $exitcode' EXIT

# ✗ Wrong - using function without ()
trap cleanup EXIT  # Tries to run command named "cleanup"

# ✓ Correct - use function call syntax
trap 'cleanup $?' EXIT

# ✗ Wrong - complex cleanup logic inline
trap 'rm "$file1"; rm "$file2"; kill $pid; rm -rf "$dir"' EXIT

# ✓ Correct - use cleanup function
cleanup() {
  rm -f "$file1" "$file2"
  kill "$pid" 2>/dev/null
  rm -rf "$dir"
}
trap 'cleanup' EXIT
\`\`\`

**Testing trap handlers:**

\`\`\`bash
#!/usr/bin/env bash
set -euo pipefail

cleanup() {
  echo "Cleanup called with exit code: ${1:-?}"
  trap - EXIT
  exit "${1:-0}"
}

trap 'cleanup $?' EXIT

echo "Normal operation..."
# Test Ctrl+C: press Ctrl+C -> cleanup called
# Test error: false -> cleanup called with exit code 1
# Test normal: script ends -> cleanup called with exit code 0
\`\`\`

**Summary:**
- **Always use cleanup function** for non-trivial cleanup
- **Disable trap inside cleanup** to prevent recursion
- **Set trap early** before creating resources
- **Preserve exit code** with `trap 'cleanup $?' EXIT`
- **Use single quotes** to delay variable expansion
- **Test thoroughly** with normal exit, errors, and signals
