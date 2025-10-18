## Echo vs Messaging Functions

**Choose between plain `echo` and messaging functions based on the context, formatting requirements, and output destination. Use messaging functions for operational status updates that respect verbosity settings, and plain `echo` for data output and structured documentation that must always display.**

**Rationale:**

- **Stream Separation**: Messaging functions go to stderr (user-facing), `echo` goes to stdout (data/parseable output)
- **Verbosity Control**: Messaging functions respect `VERBOSE` flag, `echo` always displays (critical for pipeable data)
- **Consistent Formatting**: Messaging functions provide uniform prefixes, colors, and script name identification
- **Output Purpose**: Operational messages vs data output require different handling
- **Parseability**: Plain `echo` output is predictable and parseable; messaging functions include formatting
- **Script Composition**: Using proper streams allows scripts to be combined in pipelines without mixing data and status messages

**When to use messaging functions (`info`, `success`, `warn`, `error`):**

**1. Operational status updates:**

```bash
# Script progress indicators
info 'Starting database backup...'
success 'Database backup completed'
warn 'Backup size exceeds threshold'
error 'Database connection failed'

# Processing notifications
info "Processing file $count of $total"
success "Processed $filename successfully"
```

**2. User-facing diagnostic information:**

```bash
# Diagnostic output
debug "Variable state: count=$count, total=$total"
debug 'Entering validation phase'

# Configuration feedback
info "Using configuration file: $config_file"
info "Timeout set to $timeout seconds"
```

**3. Messages that should respect verbosity:**

```bash
# Only shown if VERBOSE=1
info 'Checking prerequisites...'
info 'Loading configuration...'
success 'All checks passed'

# Always shown (errors)
error 'Configuration file not found'
die 1 'Critical dependency missing'
```

**4. Messages needing visual formatting:**

```bash
# Color-coded status
success 'Build completed'        # Green checkmark
warn 'Using default settings'    # Yellow warning
error 'Compilation failed'       # Red X
info 'Tests running...'          # Cyan info icon
```

**When to use plain `echo`:**

**1. Data output (stdout):**

```bash
# Function returns data
get_user_email() {
  local -- username="$1"
  local -- email

  email=$(grep "^$username:" /etc/passwd | cut -d: -f5)

  echo "$email"  # Data output - must use echo
}

# Caller can capture output
user_email=$(get_user_email 'alice')
```

**2. Help text and documentation:**

```bash
usage() {
  cat <<'EOF'
Usage: script.sh [OPTIONS] FILE...

Process files with various options.

Options:
  -v, --verbose     Enable verbose output
  -h, --help        Show this help message
  -o, --output DIR  Output directory

Examples:
  script.sh file.txt
  script.sh -v -o /tmp file1.txt file2.txt
EOF
}
```

**3. Structured multi-line output:**

```bash
# Report generation
generate_report() {
  echo "System Report"
  echo "============="
  echo ""
  echo "Disk Usage:"
  df -h
  echo ""
  echo "Memory Usage:"
  free -h
  echo ""
  echo "Load Average:"
  uptime
}
```

**4. Output intended for parsing or piping:**

```bash
# List output for processing
list_users() {
  local -- user

  while IFS=: read -r user _; do
    echo "$user"
  done < /etc/passwd
}

# Can be piped or processed
list_users | grep '^admin' | wc -l
```

**5. Output that should always display regardless of verbosity:**

```bash
# Results that user explicitly requested
show_version() {
  echo "$SCRIPT_NAME $VERSION"
}

# Final summary output
echo "Processed $success_count files successfully"
echo "Failed: $fail_count files"
```

**Decision matrix:**

```bash
# Is this operational status or data?
#   Status → messaging function
#   Data   → echo

# Should this respect verbosity settings?
#   Yes → messaging function (info, warn, debug)
#   No  → echo (or error for critical messages)

# Will this be parsed or piped?
#   Yes → echo to stdout
#   No  → messaging function to stderr

# Is this multi-line formatted output?
#   Yes → echo (with here-doc or multiple statements)
#   No  → messaging function (single-line status)

# Does this need color/formatting?
#   Yes → messaging function
#   No  → echo
```

**Complete example showing both:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -i VERBOSE=0

# Colors (conditional on terminal)
if [[ -t 1 && -t 2 ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  CYAN=$'\033[0;36m'
  NC=$'\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  CYAN=''
  NC=''
fi
readonly -- RED GREEN YELLOW CYAN NC

# ============================================================================
# Messaging Functions (stderr, with verbosity control)
# ============================================================================

_msg() {
  local -- prefix="$SCRIPT_NAME:" msg

  case "${FUNCNAME[1]}" in
    success) prefix+=" ${GREEN}✓${NC}" ;;
    warn)    prefix+=" ${YELLOW}⚡${NC}" ;;
    info)    prefix+=" ${CYAN}◉${NC}" ;;
    error)   prefix+=" ${RED}✗${NC}" ;;
    *)       ;;
  esac

  for msg in "$@"; do
    printf '%s %s\n' "$prefix" "$msg"
  done
}

info()    { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
success() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn()    { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
error()   { >&2 _msg "$@"; }

die() {
  local -i exit_code=${1:-1}
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}

# ============================================================================
# Data Functions (stdout, always output)
# ============================================================================

# Return user's home directory (data output)
get_user_home() {
  local -- username="$1"
  local -- home_dir

  home_dir=$(getent passwd "$username" | cut -d: -f6)

  if [[ -z "$home_dir" ]]; then
    return 1
  fi

  echo "$home_dir"  # Data to stdout
}

# Generate structured report (data output)
show_report() {
  echo "User Report"
  echo "==========="
  echo ""
  echo "Username: $USER"
  echo "Home: $HOME"
  echo "Shell: $SHELL"
  echo ""
  echo "Disk Usage:"
  df -h "$HOME" | tail -n 1
}

# ============================================================================
# Documentation Functions (stdout, always output)
# ============================================================================

usage() {
  cat <<'EOF'
Usage: script.sh [OPTIONS] USERNAME

Get information about a user.

Options:
  -v, --verbose    Show detailed progress
  -h, --help       Show this help

Examples:
  script.sh alice
  script.sh -v bob
EOF
}

# ============================================================================
# Main Logic
# ============================================================================

main() {
  local -- username
  local -- user_home

  # Parse arguments (messaging functions for progress)
  while (($#)); do case $1 in
    -v|--verbose) VERBOSE=1 ;;
    -h|--help)    usage; return 0 ;;
    --)           shift; break ;;
    -*)           die 22 "Invalid option: $1" ;;
    *)            break ;;
  esac; shift; done

  readonly -- VERBOSE

  # Validate arguments (error message)
  if (($# != 1)); then
    error 'Expected exactly one argument'
    usage
    return 22
  fi

  username="$1"

  # Operational status (messaging functions to stderr)
  info "Looking up user: $username"

  # Get data (echo to stdout)
  if ! user_home=$(get_user_home "$username"); then
    error "User not found: $username"
    return 1
  fi

  # Operational status (messaging function)
  success "Found user: $username"

  # Data output (echo to stdout) - always displays
  show_report

  # Operational status (messaging function)
  info 'Report generation complete'
}

main "$@"

#fin
```

**Running the example:**

```bash
# Without verbose - only data output and errors
$ ./script.sh alice
User Report
===========

Username: alice
Home: /home/alice
Shell: /bin/bash

Disk Usage:
/dev/sda1  100G  50G  50G  50% /home

# With verbose - operational messages visible (to stderr)
$ ./script.sh -v alice
script.sh: ◉ Looking up user: alice
script.sh: ✓ Found user: alice
User Report
===========

Username: alice
Home: /home/alice
Shell: /bin/bash

Disk Usage:
/dev/sda1  100G  50G  50G  50% /home
script.sh: ◉ Report generation complete

# Pipe output (only stdout data piped, stderr messages visible)
$ ./script.sh -v alice | grep Shell
script.sh: ◉ Looking up user: alice
script.sh: ✓ Found user: alice
Shell: /bin/bash
script.sh: ◉ Report generation complete

# Redirect output (data to file, messages to terminal)
$ ./script.sh -v alice > report.txt
script.sh: ◉ Looking up user: alice
script.sh: ✓ Found user: alice
script.sh: ◉ Report generation complete

$ cat report.txt
User Report
===========
...
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - using info() for data output
get_user_email() {
  local -- email="$1"
  info "$email"  # Goes to stderr! Can't be captured!
}
email=$(get_user_email 'alice')  # $email is empty!

# ✓ Correct - use echo for data output
get_user_email() {
  local -- email="$1"
  echo "$email"  # Goes to stdout, can be captured
}
email=$(get_user_email 'alice')  # $email contains value

# ✗ Wrong - using echo for operational status
process_file() {
  local -- file="$1"
  echo "Processing $file..."  # Goes to stdout - mixes with data!
  cat "$file"
}

# ✓ Correct - use messaging function for status
process_file() {
  local -- file="$1"
  info "Processing $file..."  # Goes to stderr - separated from data
  cat "$file"                  # Data to stdout
}

# ✗ Wrong - help text using info()
show_help() {
  info 'Usage: script.sh [OPTIONS]'
  info '  -v  Verbose mode'
  info '  -h  Show help'
}
# Won't display if VERBOSE=0!

# ✓ Correct - help text using echo/cat
show_help() {
  cat <<'EOF'
Usage: script.sh [OPTIONS]
  -v  Verbose mode
  -h  Show help
EOF
}

# ✗ Wrong - mixing data and status on same stream
list_files() {
  echo "Listing files..."  # Status to stdout
  ls                       # Data to stdout
}
# Can't parse output cleanly!

# ✓ Correct - status to stderr, data to stdout
list_files() {
  info 'Listing files...'  # Status to stderr
  ls                        # Data to stdout
}

# ✗ Wrong - error messages to stdout
validate_input() {
  if [[ ! -f "$1" ]]; then
    echo "File not found: $1"  # To stdout - wrong stream!
    return 1
  fi
}

# ✓ Correct - error messages to stderr
validate_input() {
  if [[ ! -f "$1" ]]; then
    error "File not found: $1"  # To stderr - correct stream
    return 1
  fi
}

# ✗ Wrong - data output respecting VERBOSE
get_count() {
  local -i count=10
  ((VERBOSE)) && echo "$count"  # Data not shown if VERBOSE=0!
}

# ✓ Correct - data always outputs
get_count() {
  local -i count=10
  echo "$count"  # Always outputs data
}

# ✗ Wrong - multi-line help with info()
show_usage() {
  info 'Usage: script.sh [OPTIONS]'
  info ''
  info 'Options:'
  info '  -v  Verbose'
}
# Verbose-dependent, ugly formatting

# ✓ Correct - multi-line help with echo/cat
show_usage() {
  cat <<'EOF'
Usage: script.sh [OPTIONS]

Options:
  -v  Verbose
EOF
}
```

**Edge cases and borderline scenarios:**

**1. Version output:**

```bash
# Version is data output (always display)
show_version() {
  echo "$SCRIPT_NAME $VERSION"  # Use echo
}

# Not this:
show_version() {
  info "$SCRIPT_NAME $VERSION"  # Wrong - version won't show if VERBOSE=0
}
```

**2. Progress during data generation:**

```bash
# Need progress while generating data
generate_data() {
  local -i i

  # Progress to stderr
  info 'Generating data...'

  # Data to stdout
  for ((i=1; i<=100; i++)); do
    echo "line $i"
  done

  # Completion status to stderr
  success 'Data generation complete'
}

# Caller can capture data, see progress
data=$(generate_data)
```

**3. Conditional output formatting:**

```bash
# Different output for interactive vs non-interactive
show_result() {
  if [[ -t 1 ]]; then
    # Interactive terminal - use messaging functions
    success 'Operation completed'
    info "Result: $result"
  else
    # Non-interactive/piped - use plain echo
    echo "$result"
  fi
}
```

**4. Error context in functions:**

```bash
# Function can use messaging for context, return code for status
validate_config() {
  local -- config_file="$1"

  if [[ ! -f "$config_file" ]]; then
    error "Config file not found: $config_file"
    return 2
  fi

  if [[ ! -r "$config_file" ]]; then
    error "Config file not readable: $config_file"
    return 5
  fi

  # Validation passed - no output needed
  return 0
}

# Caller handles based on return code
if ! validate_config "$config"; then
  die $? 'Configuration validation failed'
fi
```

**5. Logging vs user messages:**

```bash
# Log to file (echo), message to user (messaging function)
process_item() {
  local -- item="$1"

  # Log entry (data to stdout, redirected to file)
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processing: $item"

  # User message (status to stderr)
  info "Processing $item..."
}

# Usage with logging
process_item "$item" >> "$log_file"
```

**Testing stream separation:**

```bash
# Test that data goes to stdout
test_data_output() {
  local -- output

  output=$(get_user_home 'alice')

  [[ -n "$output" ]] || die 1 'Expected output from get_user_home'
  info "Test passed: Data captured correctly"
}

# Test that messages don't interfere with data capture
test_message_separation() {
  local -- output

  # Capture stdout only
  output=$(
    info 'Starting process...'  # To stderr - not captured
    echo 'data'                  # To stdout - captured
    success 'Process complete'   # To stderr - not captured
  )

  [[ "$output" == 'data' ]] || die 1 "Expected 'data', got '$output'"
  info 'Test passed: Messages separate from data'
}
```

**Summary:**

- **Use messaging functions** for operational status, diagnostics, and user-facing messages
- **Use plain `echo`** for data output, help text, structured reports, and parseable output
- **Stream separation**: Messaging to stderr (user-facing), echo to stdout (data/parseable)
- **Verbosity**: Messaging functions respect `VERBOSE`, echo always displays
- **Pipeability**: Only stdout (echo) should contain data for piping/capturing
- **Multi-line output**: Use echo with here-docs, not multiple messaging function calls
- **Error messages**: Always to stderr (use `error()` or `>&2 echo`)
- **Help/version**: Always display (echo), never verbose-dependent

**Key principle:** The choice between echo and messaging functions is fundamentally about stream separation. Operational messages (how the script is working) belong on stderr via messaging functions. Data output (what the script produces) belongs on stdout via echo. This separation enables proper script composition, piping, and redirection while keeping users informed of progress.
