### Main Function

**Always include a `main()` function for scripts longer than approximately 40 lines. The main function serves as the single entry point, orchestrating the script's logic and making the code more organized, testable, and maintainable. Place `main "$@"` at the bottom of the script, just before the `#fin` marker.**

**Rationale:**

- **Single Entry Point**: Provides clear script execution flow starting from one well-defined function
- **Testability**: Scripts can be sourced for testing without executing; functions can be tested individually
- **Organization**: Separates initialization, argument parsing, and main logic into clear sections
- **Debugging**: Easy to add debugging output or dry-run logic in one central location
- **Scope Control**: All script execution variables can be local to main, preventing global namespace pollution
- **Exit Code Management**: Centralized return/exit code handling for consistent error reporting

**When to use main():**

```bash
# Use main() when:
# - Script is longer than ~40 lines
# - Script has multiple functions
# - Script requires argument parsing
# - Script needs to be testable
# - Script has complex logic flow

# Can skip main() when:
# - Script is trivial (< 40 lines)
# - Script is a simple wrapper
# - Script has no functions
# - Script is linear (no branching)
```

**Basic main() structure:**

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
# Functions
# ============================================================================

# ... helper functions ...

# ============================================================================
# Main
# ============================================================================

main() {
  # Parse arguments
  while (($#)); do case $1 in
    -h|--help) usage; return 0 ;;
    *) die 22 "Invalid option: $1" ;;
  esac; shift; done

  # Main logic
  info 'Starting processing...'

  # ... business logic ...

  # Return success
  return 0
}

# Script invocation
main "$@"

#fin
```

**Main function with argument parsing:**

```bash
main() {
  # Local variables for parsed options
  local -i verbose=0
  local -i dry_run=0
  local -- output_file=''
  local -a input_files=()

  # Parse arguments
  while (($#)); do case $1 in
    -v|--verbose) verbose=1 ;;
    -n|--dry-run) dry_run=1 ;;
    -o|--output)
      noarg "$@"
      shift
      output_file="$1"
      ;;
    -h|--help)
      usage
      return 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die 22 "Invalid option: $1"
      ;;
    *)
      input_files+=("$1")
      ;;
  esac; shift; done

  # Remaining arguments after --
  input_files+=("$@")

  # Make parsed values readonly
  readonly -- verbose dry_run output_file
  readonly -a input_files

  # Validate arguments
  if [[ ${#input_files[@]} -eq 0 ]]; then
    error 'No input files specified'
    usage
    return 22
  fi

  # Main logic
  if ((verbose)); then
    info "Processing ${#input_files[@]} files"
    ((dry_run)) && info '[DRY-RUN] Mode enabled'
  fi

  # Process files
  local -- file
  for file in "${input_files[@]}"; do
    process_file "$file"
  done

  return 0
}
```

**Main function with setup/cleanup:**

```bash
# Cleanup function
cleanup() {
  local -i exit_code=$?

  # Cleanup operations
  if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi

  return "$exit_code"
}

main() {
  # Setup trap for cleanup
  trap cleanup EXIT

  # Create temp directory
  TEMP_DIR=$(mktemp -d)
  readonly -- TEMP_DIR

  # Main logic
  info "Using temp directory: $TEMP_DIR"

  # ... processing ...

  # Cleanup happens automatically via trap
  return 0
}

main "$@"

#fin
```

**Main function with error handling:**

```bash
main() {
  local -i errors=0

  # Parse arguments
  # ...

  # Process items with error tracking
  local -- item
  for item in "${items[@]}"; do
    if ! process_item "$item"; then
      error "Failed to process: $item"
      ((errors+=1))
    fi
  done

  # Report results
  if ((errors > 0)); then
    error "Completed with $errors errors"
    return 1
  else
    success 'All items processed successfully'
    return 0
  fi
}
```

**Main function enabling sourcing for tests:**

```bash
# Script can be sourced for testing
main() {
  # ... script logic ...
  return 0
}

# Only execute main if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

#fin
```

**Complete example with main():**

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
# Color Definitions
# ============================================================================

if [[ -t 1 && -t 2 ]]; then
  readonly -- RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  readonly -- RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

# ============================================================================
# Messaging Functions
# ============================================================================

_msg() {
  local -- prefix="$SCRIPT_NAME:" msg

  case "${FUNCNAME[1]}" in
    info) prefix+=" ${CYAN}◉${NC}" ;;
    error) prefix+=" ${RED}✗${NC}" ;;
    *) ;;
  esac

  for msg in "$@"; do
    printf '%s %s\n' "$prefix" "$msg"
  done
}

info() { >&2 _msg "$@"; }
error() { >&2 _msg "$@"; }

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
  -v, --verbose     Enable verbose output
  -n, --dry-run     Show what would be done
  -o, --output DIR  Output directory
  -h, --help        Show this help

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
# Business Logic Functions
# ============================================================================

process_file() {
  local -- file="$1"

  # Validate file
  if [[ ! -f "$file" ]]; then
    error "File not found: $file"
    return 2
  fi

  info "Processing: $file"

  # Process file logic
  # ...

  return 0
}

# ============================================================================
# Main Function
# ============================================================================

main() {
  # Declare option variables
  local -i verbose=0
  local -i dry_run=0
  local -- output_dir=''
  local -a input_files=()

  # Parse command-line arguments
  while (($#)); do case $1 in
    -v|--verbose) verbose=1 ;;
    -n|--dry-run) dry_run=1 ;;
    -o|--output)
      noarg "$@"
      shift
      output_dir="$1"
      ;;
    -h|--help)
      usage
      return 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die 22 "Invalid option: $1"
      ;;
    *)
      input_files+=("$1")
      ;;
  esac; shift; done

  # Collect remaining arguments
  input_files+=("$@")

  # Make options readonly
  readonly -- verbose dry_run output_dir
  readonly -a input_files

  # Validate arguments
  if [[ ${#input_files[@]} -eq 0 ]]; then
    error 'No input files specified'
    usage
    return 22
  fi

  if [[ -n "$output_dir" && ! -d "$output_dir" ]]; then
    error "Output directory not found: $output_dir"
    return 2
  fi

  # Display configuration
  if ((verbose)); then
    info "$SCRIPT_NAME $VERSION"
    info "Input files: ${#input_files[@]}"
    [[ -n "$output_dir" ]] && info "Output: $output_dir"
    ((dry_run)) && info '[DRY-RUN] Mode enabled'
  fi

  # Process each file
  local -- file
  local -i success_count=0
  local -i error_count=0

  for file in "${input_files[@]}"; do
    if ((dry_run)); then
      info "[DRY-RUN] Would process: $file"
      ((success_count+=1))
    elif process_file "$file"; then
      ((success_count+=1))
    else
      ((error_count+=1))
    fi
  done

  # Report results
  if ((verbose)); then
    info "Processed: $success_count files"
    ((error_count > 0)) && info "Errors: $error_count"
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

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - no main function in complex script
#!/bin/bash
set -euo pipefail

# ... 200 lines of code directly in script ...
# Hard to test, hard to organize

# ✓ Correct - main function
#!/bin/bash
set -euo pipefail

# ... helper functions ...

main() {
  # Script logic
}

main "$@"

#fin

# ✗ Wrong - main() not at end
main() {
  # ...
}

main "$@"  # Called here

# More functions defined after main is called
helper_function() {
  # ...
}
# This function is defined after main executes!

# ✓ Correct - main() at end, called last
helper_function() {
  # ...
}

main() {
  # Can call helper_function
}

main "$@"
#fin

# ✗ Wrong - parsing arguments outside main
verbose=0
dry_run=0

while (($#)); do
  # ... parse args ...
done

main() {
  # Uses global variables
}

main "$@"  # Arguments already consumed!

# ✓ Correct - parsing in main
main() {
  local -i verbose=0
  local -i dry_run=0

  while (($#)); do
    # ... parse args ...
  done

  readonly -- verbose dry_run
  # ... use variables ...
}

main "$@"

# ✗ Wrong - not passing arguments
main() {
  # Expects arguments but they're not passed
}

main  # Missing "$@"!

# ✓ Correct - pass all arguments
main "$@"

# ✗ Wrong - mixing global and local logic
total=0  # Global

main() {
  local -i count=0
  # Mixes global and local state
  ((total+=count))
}

# ✓ Correct - all logic in main
main() {
  local -i total=0
  local -i count=0
  # All local, clean scope
  ((total+=count))
}
```

**Edge cases:**

**1. Script needs global configuration:**

```bash
# Global configuration (before functions)
declare -i VERBOSE=0
declare -i DRY_RUN=0

main() {
  # Parse arguments and modify globals
  while (($#)); do case $1 in
    -v|--verbose) VERBOSE=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    *) die 22 "Invalid option: $1" ;;
  esac; shift; done

  # Make globals readonly
  readonly -- VERBOSE DRY_RUN

  # ... rest of logic ...
}

main "$@"
```

**2. Script has initialization code:**

```bash
# Initialization before main
declare -A CONFIG=()

load_config() {
  # Load configuration into global array
  # ...
}

# Load before main
load_config

main() {
  # Use CONFIG array
  echo "App: ${CONFIG[app_name]}"
}

main "$@"
```

**3. Script is library and executable:**

```bash
# Library functions
utility_function() {
  # ...
}

# Main function for when executed
main() {
  # ...
}

# Only run main if executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

#fin
```

**4. Multiple main scenarios:**

```bash
# Different modes
main_install() {
  # Installation logic
}

main_uninstall() {
  # Uninstallation logic
}

main() {
  local -- mode="${1:-}"

  case "$mode" in
    install) shift; main_install "$@" ;;
    uninstall) shift; main_uninstall "$@" ;;
    *) die 22 "Invalid mode: $mode" ;;
  esac
}

main "$@"
```

**Testing with main():**

```bash
# Script: myapp.sh
main() {
  local -i value="$1"
  ((value * 2))
  echo "$value"
}

# Only execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

# Test file: test_myapp.sh
#!/bin/bash
source ./myapp.sh  # Source without executing

# Test main function
result=$(main 5)

if [[ "$result" == "10" ]]; then
  echo "PASS"
else
  echo "FAIL: Expected 10, got $result"
fi
```

**Summary:**

- **Use main() for scripts >40 lines** - provides organization and testability
- **Single entry point** - all execution flows through main()
- **Place main() at end** - define helpers first, main last
- **Always call with "$@"** - `main "$@"` to pass all arguments
- **Parse arguments in main** - keep argument handling in one place
- **Make locals readonly** - after parsing, make option variables readonly
- **Return appropriate code** - 0 for success, non-zero for errors
- **Consider sourcing** - use `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` for testability
- **Organize sections** - messaging, documentation, helpers, business logic, main

**Key principle:** The main() function is the orchestrator - it doesn't do the work, it coordinates it. All heavy lifting should be in helper functions. Main's job is to parse arguments, validate input, call the right functions in the right order, and return an appropriate exit code. This separation makes scripts testable, debuggable, and maintainable.
