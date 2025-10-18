## Case Statements

**Use `case` statements for multi-way branching based on pattern matching. Case statements are more readable and efficient than long `if/elif` chains when testing a single value against multiple patterns. Choose compact format for simple single-action cases, and expanded format for multi-line logic. Always align actions consistently and use appropriate pattern matching syntax.**

**Rationale:**

- **Readability**: Case statements are clearer than long if/elif chains for pattern-based branching
- **Pattern Matching**: Native support for wildcards, alternation, and character classes
- **Performance**: Case is faster than multiple if/elif tests - single evaluation of the test value
- **Maintainability**: Easy to add, remove, or reorder cases without restructuring logic
- **Argument Parsing**: Perfect for command-line option processing with multiple flags
- **Exhaustive Matching**: Default `*)` case ensures all possibilities are handled
- **Visual Organization**: Column alignment makes structure immediately obvious

**When to use case vs if/elif:**

```bash
# ✓ Use case when - testing single variable against multiple values
case "$action" in
  start) start_service ;;
  stop) stop_service ;;
  restart) restart_service ;;
  status) show_status ;;
  *) die 22 "Invalid action: $action" ;;
esac

# ✓ Use case when - pattern matching needed
case "$filename" in
  *.txt) process_text_file ;;
  *.pdf) process_pdf_file ;;
  *.md) process_markdown_file ;;
  *) die 22 "Unsupported file type" ;;
esac

# ✓ Use case when - parsing command-line arguments
case $1 in
  -v|--verbose) VERBOSE=1 ;;
  -h|--help) usage; exit 0 ;;
  -*) die 22 "Invalid option: $1" ;;
  *) FILENAME="$1" ;;
esac

# ✗ Use if/elif when - testing different variables
if [[ ! -f "$file" ]]; then
  die 2 "File not found: $file"
elif [[ ! -r "$file" ]]; then
  die 1 "File not readable: $file"
elif [[ -z "$output" ]]; then
  die 22 "Output path required"
fi

# ✗ Use if/elif when - complex conditional logic
if [[ "$count" -gt 100 && "$verbose" -eq 1 ]]; then
  info 'Processing large batch in verbose mode'
elif [[ "$count" -gt 100 ]]; then
  info 'Processing large batch'
fi

# ✗ Use if/elif when - testing numeric ranges
if ((value < 0)); then
  error='negative'
elif ((value == 0)); then
  error='zero'
elif ((value <= 10)); then
  category='small'
else
  category='large'
fi
```

**Compact format:**

Use compact format when each case performs a single action or simple command.

**Guidelines:**
- All actions on same line as pattern
- Terminate with `;;` on same line
- Align `;;` at consistent column (typically 14-18)
- No blank lines between cases
- Perfect for argument parsing with simple flag setting

**Compact format example:**

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
declare -i DRY_RUN=0
declare -i FORCE=0
declare -- OUTPUT_FILE=''
declare -a INPUT_FILES=()

# Compact case for simple argument parsing
while (($#)); do
  case $1 in
    -v|--verbose) VERBOSE=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    -f|--force)   FORCE=1 ;;
    -q|--quiet)   VERBOSE=0 ;;
    -h|--help)    usage; exit 0 ;;
    -V|--version) echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
    -o|--output)  noarg "$@"; shift; OUTPUT_FILE="$1" ;;
    --)           shift; break ;;
    -*)           die 22 "Invalid option: $1" ;;
    *)            INPUT_FILES+=("$1") ;;
  esac
  shift
done

INPUT_FILES+=("$@")
readonly -- VERBOSE DRY_RUN FORCE OUTPUT_FILE
readonly -a INPUT_FILES

#fin
```

**Expanded format:**

Use expanded format when cases have multi-line actions, require comments, or perform complex operations.

**Guidelines:**
- Action starts on next line, indented
- Multiple statements aligned at consistent column
- Terminate with `;;` on separate line, aligned left
- Blank line after `;;` separates cases visually
- Comments within case branches are acceptable
- Column alignment typically at 14-18 characters

**Expanded format example:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -i INSTALL_BUILTIN=0
declare -i VERBOSE=0
declare -- PREFIX='/usr/local'
declare -- BIN_DIR=''
declare -- LIB_DIR=''

# Expanded case for complex argument parsing
while (($#)); do
  case $1 in
    -b|--builtin)     INSTALL_BUILTIN=1
                      ((VERBOSE)) && info 'Builtin installation enabled'
                      ;;

    -p|--prefix)      noarg "$@"
                      shift
                      PREFIX="$1"
                      BIN_DIR="$PREFIX/bin"
                      LIB_DIR="$PREFIX/lib/bash"
                      ((VERBOSE)) && info "Prefix set to: $PREFIX"
                      ;;

    -v|--verbose)     VERBOSE=1
                      info 'Verbose mode enabled'
                      ;;

    -V|--version)     echo "$SCRIPT_NAME $VERSION"
                      exit 0
                      ;;

    -h|--help)        usage
                      exit 0
                      ;;

    --)               shift
                      break
                      ;;

    -*)               error "Invalid option: $1"
                      usage
                      exit 22
                      ;;

    *)                error "Unexpected argument: $1"
                      usage
                      exit 22
                      ;;
  esac
  shift
done

readonly -- INSTALL_BUILTIN VERBOSE PREFIX BIN_DIR LIB_DIR

#fin
```

**Pattern matching syntax:**

**1. Literal patterns:**

```bash
# Exact string match
case "$value" in
  start) echo 'Starting...' ;;
  stop) echo 'Stopping...' ;;
  restart) echo 'Restarting...' ;;
esac

# Quote pattern if it contains special characters
case "$email" in
  'admin@example.com') echo 'Admin user' ;;
  'user@example.com') echo 'Regular user' ;;
esac
```

**2. Wildcard patterns (globbing):**

```bash
# Star wildcard - matches any characters
case "$filename" in
  *.txt) echo 'Text file' ;;
  *.pdf) echo 'PDF file' ;;
  *.log) echo 'Log file' ;;
  *) echo 'Unknown file type' ;;
esac

# Question mark wildcard - matches single character
case "$code" in
  ??) echo 'Two-character code' ;;
  ???) echo 'Three-character code' ;;
  *) echo 'Other length' ;;
esac

# Prefix/suffix matching
case "$path" in
  /usr/*) echo 'System path' ;;
  /home/*) echo 'Home directory' ;;
  /tmp/*) echo 'Temporary path' ;;
  *) echo 'Other path' ;;
esac
```

**3. Alternation (OR patterns):**

```bash
# Multiple patterns with |
case "$option" in
  -h|--help|help) usage; exit 0 ;;
  -v|--verbose|verbose) VERBOSE=1 ;;
  -q|--quiet|quiet) VERBOSE=0 ;;
esac

# Combining alternation with wildcards
case "$filename" in
  *.txt|*.md|*.rst) echo 'Text document' ;;
  *.jpg|*.png|*.gif) echo 'Image file' ;;
  *.sh|*.bash) echo 'Shell script' ;;
esac
```

**4. Character classes:**

```bash
# With extglob enabled
shopt -s extglob

case "$input" in
  # ?(pattern) - zero or one occurrence
  test?(s)) echo 'test or tests' ;;

  # *(pattern) - zero or more occurrences
  file*(s).txt) echo 'file.txt, files.txt, filess.txt, etc.' ;;

  # +(pattern) - one or more occurrences
  log+([0-9]).txt) echo 'log followed by digits' ;;

  # @(pattern) - exactly one occurrence
  @(start|stop|restart)) echo 'Valid action' ;;

  # !(pattern) - anything except pattern
  !(*.tmp|*.bak)) echo 'Not a temp or backup file' ;;
esac

# Bracket expressions
case "$char" in
  [0-9]) echo 'Digit' ;;
  [a-z]) echo 'Lowercase letter' ;;
  [A-Z]) echo 'Uppercase letter' ;;
  [!a-zA-Z0-9]) echo 'Special character' ;;
esac
```

**Complete argument parsing example:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ============================================================================
# Global Variables
# ============================================================================

declare -i VERBOSE=0
declare -i DRY_RUN=0
declare -i FORCE=0
declare -- OUTPUT_DIR=''
declare -- CONFIG_FILE="$SCRIPT_DIR/config.conf"
declare -a INPUT_FILES=()

# ============================================================================
# Messaging Functions
# ============================================================================

_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case "${FUNCNAME[1]}" in
    info) prefix+=" ◉" ;;
    warn) prefix+=" ⚠" ;;
    error) prefix+=" ✗" ;;
    success) prefix+=" ✓" ;;
    *) ;;
  esac
  for msg in "$@"; do
    printf '%s %s\n' "$prefix" "$msg"
  done
}

info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn() { >&2 _msg "$@"; }
error() { >&2 _msg "$@"; }
success() { >&2 _msg "$@"; }

die() {
  local -i exit_code=${1:-1}
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}

# ============================================================================
# Documentation Functions
# ============================================================================

usage() {
  cat <<'EOF'
Usage: script.sh [OPTIONS] FILE...

Process files with various options.

Options:
  -v, --verbose          Enable verbose output
  -n, --dry-run          Show what would be done without doing it
  -f, --force            Force overwrite of existing files
  -q, --quiet            Suppress non-error output
  -o, --output DIR       Output directory
  -c, --config FILE      Configuration file
  -h, --help             Show this help message
  -V, --version          Show version information

Arguments:
  FILE...                Input files to process

Examples:
  script.sh file.txt
  script.sh -v -o /tmp file1.txt file2.txt
  script.sh -n --output /backup *.txt
EOF
}

# ============================================================================
# Helper Functions
# ============================================================================

noarg() {
  if (($# < 2)) || [[ "$2" =~ ^- ]]; then
    die 22 "Option $1 requires an argument"
  fi
}

# ============================================================================
# Business Logic
# ============================================================================

process_file() {
  local -- file="$1"

  if [[ ! -f "$file" ]]; then
    error "File not found: $file"
    return 2
  fi

  if ((DRY_RUN)); then
    info "[DRY-RUN] Would process: $file"
  else
    info "Processing: $file"
    # Process file logic here
  fi

  return 0
}

# ============================================================================
# Main Function
# ============================================================================

main() {
  # Parse command-line arguments
  while (($#)); do
    case $1 in
      -v|--verbose)     VERBOSE=1
                        info 'Verbose mode enabled'
                        ;;

      -n|--dry-run)     DRY_RUN=1
                        ;;

      -f|--force)       FORCE=1
                        ;;

      -q|--quiet)       VERBOSE=0
                        ;;

      -o|--output)      noarg "$@"
                        shift
                        OUTPUT_DIR="$1"
                        ;;

      -c|--config)      noarg "$@"
                        shift
                        CONFIG_FILE="$1"
                        ;;

      -V|--version)     echo "$SCRIPT_NAME $VERSION"
                        return 0
                        ;;

      -h|--help)        usage
                        return 0
                        ;;

      --)               shift
                        break
                        ;;

      -*)               die 22 "Invalid option: $1"
                        ;;

      *)                INPUT_FILES+=("$1")
                        ;;
    esac
    shift
  done

  # Collect remaining arguments after --
  INPUT_FILES+=("$@")

  # Make parsed values readonly
  readonly -- VERBOSE DRY_RUN FORCE OUTPUT_DIR CONFIG_FILE
  readonly -a INPUT_FILES

  # Validate arguments
  if [[ ${#INPUT_FILES[@]} -eq 0 ]]; then
    error 'No input files specified'
    usage
    return 22
  fi

  if [[ -n "$OUTPUT_DIR" && ! -d "$OUTPUT_DIR" ]]; then
    if ((FORCE)); then
      info "Creating output directory: $OUTPUT_DIR"
      mkdir -p "$OUTPUT_DIR"
    else
      die 2 "Output directory not found: $OUTPUT_DIR (use -f to create)"
    fi
  fi

  if [[ ! -f "$CONFIG_FILE" ]]; then
    warn "Config file not found: $CONFIG_FILE (using defaults)"
  fi

  # Display configuration
  if ((VERBOSE)); then
    info "$SCRIPT_NAME $VERSION"
    info "Input files: ${#INPUT_FILES[@]}"
    [[ -n "$OUTPUT_DIR" ]] && info "Output: $OUTPUT_DIR"
    ((DRY_RUN)) && info '[DRY-RUN] Mode enabled'
  fi

  # Process files
  local -- file
  local -i success_count=0
  local -i error_count=0

  for file in "${INPUT_FILES[@]}"; do
    if process_file "$file"; then
      ((success_count+=1))
    else
      ((error_count+=1))
    fi
  done

  # Report results
  if ((VERBOSE)); then
    success "Processed: $success_count files"
    ((error_count > 0)) && warn "Errors: $error_count"
  fi

  # Return appropriate exit code
  ((error_count == 0))
}

# ============================================================================
# Script Invocation
# ============================================================================

main "$@"

#fin
```

**File type routing example:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Route files based on extension
process_file_by_type() {
  local -- file="$1"
  local -- filename="${file##*/}"

  case "$filename" in
    *.txt|*.md|*.rst)
      info "Processing text document: $file"
      process_text "$file"
      ;;

    *.jpg|*.jpeg|*.png|*.gif)
      info "Processing image: $file"
      process_image "$file"
      ;;

    *.pdf)
      info "Processing PDF: $file"
      process_pdf "$file"
      ;;

    *.sh|*.bash)
      info "Processing shell script: $file"
      validate_script "$file"
      ;;

    *.json)
      info "Processing JSON: $file"
      validate_json "$file"
      ;;

    *.xml)
      info "Processing XML: $file"
      validate_xml "$file"
      ;;

    .*)
      warn "Skipping hidden file: $file"
      return 0
      ;;

    *.tmp|*.bak|*~)
      warn "Skipping temporary file: $file"
      return 0
      ;;

    *)
      error "Unknown file type: $file"
      return 1
      ;;
  esac
}

process_text() {
  local -- file="$1"
  # Text processing logic
}

process_image() {
  local -- file="$1"
  # Image processing logic
}

process_pdf() {
  local -- file="$1"
  # PDF processing logic
}

validate_script() {
  local -- file="$1"
  shellcheck "$file"
}

validate_json() {
  local -- file="$1"
  jq empty "$file"
}

validate_xml() {
  local -- file="$1"
  xmllint --noout "$file"
}

main() {
  local -a files=("$@")

  if [[ ${#files[@]} -eq 0 ]]; then
    die 22 'No files specified'
  fi

  local -- file
  for file in "${files[@]}"; do
    process_file_by_type "$file"
  done
}

main "$@"

#fin
```

**Action routing example:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Service control script
SERVICE_NAME='myapp'
PID_FILE="/var/run/$SERVICE_NAME.pid"

start_service() {
  if [[ -f "$PID_FILE" ]]; then
    warn "Service already running (PID: $(cat "$PID_FILE"))"
    return 0
  fi

  info "Starting $SERVICE_NAME..."
  # Start service logic
  success "$SERVICE_NAME started"
}

stop_service() {
  if [[ ! -f "$PID_FILE" ]]; then
    warn "Service not running"
    return 0
  fi

  local -i pid
  pid=$(cat "$PID_FILE")
  info "Stopping $SERVICE_NAME (PID: $pid)..."
  kill "$pid"
  rm -f "$PID_FILE"
  success "$SERVICE_NAME stopped"
}

restart_service() {
  info "Restarting $SERVICE_NAME..."
  stop_service
  sleep 1
  start_service
}

status_service() {
  if [[ -f "$PID_FILE" ]]; then
    local -i pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      info "$SERVICE_NAME is running (PID: $pid)"
      return 0
    else
      error "$SERVICE_NAME is not running (stale PID file)"
      return 1
    fi
  else
    info "$SERVICE_NAME is not running"
    return 3
  fi
}

reload_service() {
  if [[ ! -f "$PID_FILE" ]]; then
    die 1 'Service not running'
  fi

  local -i pid
  pid=$(cat "$PID_FILE")
  info "Reloading $SERVICE_NAME configuration..."
  kill -HUP "$pid"
  success 'Configuration reloaded'
}

main() {
  local -- action="${1:-}"

  if [[ -z "$action" ]]; then
    die 22 'No action specified (start|stop|restart|status|reload)'
  fi

  # Route to appropriate handler
  case "$action" in
    start)
      start_service
      ;;

    stop)
      stop_service
      ;;

    restart)
      restart_service
      ;;

    status)
      status_service
      ;;

    reload)
      reload_service
      ;;

    # Handle common variations
    st|stat)
      status_service
      ;;

    re|rest)
      restart_service
      ;;

    # Reject unknown actions
    *)
      die 22 "Invalid action: $action (use: start|stop|restart|status|reload)"
      ;;
  esac
}

main "$@"

#fin
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - quoting patterns unnecessarily
case "$value" in
  "start") echo 'Starting...' ;;    # Don't quote literal patterns
  "stop") echo 'Stopping...' ;;
esac

# ✓ Correct - unquoted literal patterns
case "$value" in
  start) echo 'Starting...' ;;
  stop) echo 'Stopping...' ;;
esac

# ✗ Wrong - not quoting the test variable
case $filename in    # Unquoted variable!
  *.txt) process_text ;;
esac

# ✓ Correct - quote the test variable
case "$filename" in
  *.txt) process_text ;;
esac

# ✗ Wrong - using if/elif for simple pattern matching
if [[ "$ext" == 'txt' ]]; then
  process_text
elif [[ "$ext" == 'pdf' ]]; then
  process_pdf
elif [[ "$ext" == 'md' ]]; then
  process_markdown
else
  die 1 'Unknown type'
fi

# ✓ Correct - case is clearer
case "$ext" in
  txt) process_text ;;
  pdf) process_pdf ;;
  md) process_markdown ;;
  *) die 1 'Unknown type' ;;
esac

# ✗ Wrong - missing default case
case "$action" in
  start) start_service ;;
  stop) stop_service ;;
esac
# What if $action is 'restart'? Silent failure!

# ✓ Correct - always include default case
case "$action" in
  start) start_service ;;
  stop) stop_service ;;
  restart) restart_service ;;
  *) die 22 "Invalid action: $action" ;;
esac

# ✗ Wrong - inconsistent format mixing
case "$opt" in
  -v) VERBOSE=1 ;;
  -o) shift
      OUTPUT="$1"
      ;;                 # Inconsistent - mixing compact and expanded
  -h) usage; exit 0 ;;
esac

# ✓ Correct - consistent compact format
case "$opt" in
  -v) VERBOSE=1 ;;
  -o) shift; OUTPUT="$1" ;;
  -h) usage; exit 0 ;;
esac

# ✗ Wrong - poor column alignment
case $1 in
  -v|--verbose) VERBOSE=1 ;;
  -n|--dry-run) DRY_RUN=1 ;;
  -f|--force) FORCE=1 ;;        # Alignment is inconsistent
  -h|--help) usage; exit 0 ;;
esac

# ✓ Correct - consistent column alignment
case $1 in
  -v|--verbose) VERBOSE=1 ;;
  -n|--dry-run) DRY_RUN=1 ;;
  -f|--force)   FORCE=1 ;;
  -h|--help)    usage; exit 0 ;;
esac

# ✗ Wrong - not using ;; terminator
case "$value" in
  start) start_service
  stop) stop_service       # Missing ;;
esac

# ✓ Correct - always use ;; terminator
case "$value" in
  start) start_service ;;
  stop) stop_service ;;
esac

# ✗ Wrong - fall-through patterns (not supported in Bash)
case "$code" in
  200|201|204)
    success='true'       # Bash doesn't fall through!
  300|301|302)
    redirect='true'      # This won't work as intended
    ;;
esac

# ✓ Correct - explicit pattern grouping
case "$code" in
  200|201|204) success='true' ;;
  300|301|302) redirect='true' ;;
esac

# ✗ Wrong - regex patterns (not supported)
case "$input" in
  [0-9]+) echo 'Number' ;;    # Not regex! This matches single digit only
esac

# ✓ Correct - use proper pattern syntax
case "$input" in
  +([0-9])) echo 'Number' ;;  # Requires extglob
esac
# Or use if with regex:
if [[ "$input" =~ ^[0-9]+$ ]]; then
  echo 'Number'
fi

# ✗ Wrong - side effects in patterns
case "$value" in
  $(complex_function)) echo 'Match' ;;  # Function called for every case!
esac

# ✓ Correct - evaluate once before case
result=$(complex_function)
case "$value" in
  "$result") echo 'Match' ;;
esac

# ✗ Wrong - testing multiple variables
case "$var1" in
  value1) case "$var2" in    # Nested case - hard to read
    value2) action ;;
  esac ;;
esac

# ✓ Correct - use if for multiple variable tests
if [[ "$var1" == value1 && "$var2" == value2 ]]; then
  action
fi
```

**Edge cases and advanced patterns:**

**1. Empty string handling:**

```bash
# Empty string is a valid case
case "$value" in
  '') echo 'Empty string' ;;
  *) echo "Value: $value" ;;
esac

# Multiple empty possibilities
case "$input" in
  ''|' '|$'\t') echo 'Blank or whitespace' ;;
  *) echo 'Has content' ;;
esac
```

**2. Special characters in patterns:**

```bash
# Quote patterns with special characters
case "$filename" in
  'file (1).txt') echo 'Match parentheses' ;;
  'file [backup].txt') echo 'Match brackets' ;;
  'file$special.txt') echo 'Match dollar sign' ;;
  *) echo 'Other' ;;
esac

# Wildcards in middle of pattern
case "$path" in
  /usr/*/bin) echo 'Binary path under /usr' ;;
  /home/*/Documents) echo 'User documents folder' ;;
esac
```

**3. Numeric patterns (as strings):**

```bash
# Case treats everything as strings
case "$port" in
  80|443) echo 'Standard web port' ;;
  22) echo 'SSH port' ;;
  [0-9][0-9][0-9][0-9]) echo 'Four-digit port' ;;
  *) echo 'Other port' ;;
esac

# For numeric comparison, use (()) instead
if ((port == 80 || port == 443)); then
  echo 'Standard web port'
fi
```

**4. Extglob patterns:**

```bash
shopt -s extglob

case "$filename" in
  # Zero or one occurrence
  test?(s).txt)
    echo 'test.txt or tests.txt'
    ;;

  # Zero or more occurrences
  file*(backup).txt)
    echo 'file.txt, filebackup.txt, filebackupbackup.txt'
    ;;

  # One or more occurrences
  log+([0-9]).txt)
    echo 'log1.txt, log123.txt, etc.'
    ;;

  # Exactly one of the patterns
  @(README|LICENSE|CHANGELOG))
    echo 'Standard project file'
    ;;

  # Anything except the patterns
  !(*.tmp|*.bak))
    echo 'Not a temp or backup file'
    ;;

  *)
    echo 'Other file'
    ;;
esac
```

**5. Case statement in functions:**

```bash
# Return different values based on case
validate_input() {
  local -- input="$1"

  case "$input" in
    [a-z]*)
      info 'Valid lowercase input'
      return 0
      ;;

    [A-Z]*)
      warn 'Input should be lowercase'
      return 1
      ;;

    [0-9]*)
      error 'Input should not start with digit'
      return 2
      ;;

    '')
      error 'Input is empty'
      return 22
      ;;

    *)
      error 'Invalid input format'
      return 1
      ;;
  esac
}

# Use return value
if validate_input "$user_input"; then
  process_input "$user_input"
fi
```

**6. Multi-level case routing:**

```bash
# First level: action
main() {
  local -- action="$1"
  shift

  case "$action" in
    user)
      handle_user_commands "$@"
      ;;

    group)
      handle_group_commands "$@"
      ;;

    system)
      handle_system_commands "$@"
      ;;

    *)
      die 22 "Invalid action: $action"
      ;;
  esac
}

# Second level: subcommand
handle_user_commands() {
  local -- subcommand="$1"
  shift

  case "$subcommand" in
    add) add_user "$@" ;;
    delete) delete_user "$@" ;;
    list) list_users ;;
    *) die 22 "Invalid user subcommand: $subcommand" ;;
  esac
}

handle_group_commands() {
  local -- subcommand="$1"
  shift

  case "$subcommand" in
    add) add_group "$@" ;;
    delete) delete_group "$@" ;;
    list) list_groups ;;
    *) die 22 "Invalid group subcommand: $subcommand" ;;
  esac
}
```

**Summary:**

- **Use case for pattern matching** - testing single variable against multiple patterns
- **Compact format** - single-line actions with aligned `;;`
- **Expanded format** - multi-line actions with `;;` on separate line
- **Always quote test variable** - `case "$var" in` not `case $var in`
- **Don't quote literal patterns** - `start)` not `"start")`
- **Include default case** - always have `*)` to handle unexpected values
- **Use alternation** - `pattern1|pattern2|pattern3)` for multiple matches
- **Leverage wildcards** - `*.txt)` for glob patterns
- **Enable extglob** - for advanced pattern matching `@(pattern)`, `!(pattern)`
- **Align consistently** - choose compact or expanded, align actions at same column
- **Prefer case over if/elif** - for single-variable multi-value tests
- **Use if for complex logic** - multiple variables, ranges, complex conditions
- **Terminate with ;;** - every case branch needs `;;`

**Key principle:** Case statements excel at routing based on pattern matching of a single value. They're more readable, maintainable, and efficient than long if/elif chains for this purpose. Choose compact format for simple flag setting (argument parsing), expanded format for complex multi-line logic. Always include a default `*)` case to handle unexpected values explicitly. The visual alignment and pattern syntax make case statements self-documenting and easy to modify.
