## Temporary File Handling

**Always use `mktemp` to create temporary files and directories, never hard-code temp file paths. Use trap handlers to ensure cleanup occurs even on script failure or interruption. Store temp file paths in variables, make them readonly when possible, and always clean up in EXIT trap. Proper temp file handling prevents security vulnerabilities, avoids file collisions, and ensures resources are released.**

**Rationale:**

- **Security**: mktemp creates files with secure permissions (0600) in safe locations
- **Uniqueness**: Guaranteed unique filenames prevent collisions with other processes
- **Atomicity**: mktemp creates file atomically, preventing race conditions
- **Cleanup Guarantee**: EXIT trap ensures cleanup even when script fails or is interrupted
- **Resource Management**: Automatic cleanup prevents temp file accumulation
- **Portability**: mktemp works consistently across Unix-like systems
- **Predictable Location**: Uses system temp directory (TMPDIR or /tmp) appropriately

**Basic temp file creation:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Create temp file and ensure cleanup
create_temp_file() {
  local -- temp_file

  # Create temp file
  temp_file=$(mktemp) || die 1 'Failed to create temporary file'

  # Set up cleanup
  trap 'rm -f "$temp_file"' EXIT

  # Make variable readonly
  readonly -- temp_file

  info "Created temp file: $temp_file"

  # Use temp file
  echo 'Test data' > "$temp_file"
  cat "$temp_file"

  # Cleanup happens automatically via trap
}

main() {
  create_temp_file
}

main "$@"

#fin
```

**Basic temp directory creation:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Create temp directory and ensure cleanup
create_temp_dir() {
  local -- temp_dir

  # Create temp directory
  temp_dir=$(mktemp -d) || die 1 'Failed to create temporary directory'

  # Set up cleanup
  trap 'rm -rf "$temp_dir"' EXIT

  # Make variable readonly
  readonly -- temp_dir

  info "Created temp directory: $temp_dir"

  # Use temp directory
  echo 'file1' > "$temp_dir/file1.txt"
  echo 'file2' > "$temp_dir/file2.txt"

  ls -la "$temp_dir"

  # Cleanup happens automatically via trap
}

main() {
  create_temp_dir
}

main "$@"

#fin
```

**Custom temp file templates:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Temp file with custom template
create_custom_temp() {
  local -- temp_file

  # Template: myapp.XXXXXX (at least 3 X's required)
  temp_file=$(mktemp /tmp/"$SCRIPT_NAME".XXXXXX) ||
    die 1 'Failed to create temporary file'

  trap 'rm -f "$temp_file"' EXIT
  readonly -- temp_file

  info "Created temp file: $temp_file"
  # Output example: /tmp/myscript.Ab3X9z

  # Use temp file
  echo 'Data' > "$temp_file"
}

# ✓ CORRECT - Temp directory with custom template
create_custom_temp_dir() {
  local -- temp_dir

  # Template for directory
  temp_dir=$(mktemp -d /tmp/"$SCRIPT_NAME"-work.XXXXXX) ||
    die 1 'Failed to create temporary directory'

  trap 'rm -rf "$temp_dir"' EXIT
  readonly -- temp_dir

  info "Created temp directory: $temp_dir"
  # Output example: /tmp/myscript-work.Xy7Pm2
}

# ✓ CORRECT - Temp file with extension
create_temp_with_extension() {
  local -- temp_file

  # mktemp doesn't support extensions directly, so add it
  temp_file=$(mktemp /tmp/"$SCRIPT_NAME".XXXXXX)
  mv "$temp_file" "$temp_file.json"
  temp_file="$temp_file.json"

  trap 'rm -f "$temp_file"' EXIT
  readonly -- temp_file

  info "Created temp file: $temp_file"

  # Use temp file
  echo '{"key": "value"}' > "$temp_file"
}

main() {
  create_custom_temp
  create_custom_temp_dir
  create_temp_with_extension
}

main "$@"

#fin
```

**Multiple temp files with cleanup:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Global array for temp files
declare -a TEMP_FILES=()

# Cleanup function for all temp files
cleanup_temp_files() {
  local -i exit_code=$?
  local -- file

  if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
    info "Cleaning up ${#TEMP_FILES[@]} temporary files"

    for file in "${TEMP_FILES[@]}"; do
      if [[ -f "$file" ]]; then
        rm -f "$file"
      elif [[ -d "$file" ]]; then
        rm -rf "$file"
      fi
    done
  fi

  return "$exit_code"
}

# Set up cleanup trap
trap cleanup_temp_files EXIT

# Create and register temp file
create_temp() {
  local -- temp_file

  temp_file=$(mktemp) || die 1 'Failed to create temporary file'
  TEMP_FILES+=("$temp_file")

  echo "$temp_file"
}

# Create and register temp directory
create_temp_dir() {
  local -- temp_dir

  temp_dir=$(mktemp -d) || die 1 'Failed to create temporary directory'
  TEMP_FILES+=("$temp_dir")

  echo "$temp_dir"
}

main() {
  local -- temp1 temp2 temp_dir

  # Create multiple temp files
  temp1=$(create_temp)
  temp2=$(create_temp)
  temp_dir=$(create_temp_dir)

  readonly -- temp1 temp2 temp_dir

  info "Temp file 1: $temp1"
  info "Temp file 2: $temp2"
  info "Temp directory: $temp_dir"

  # Use temp files
  echo 'Data 1' > "$temp1"
  echo 'Data 2' > "$temp2"
  echo 'File in dir' > "$temp_dir/file.txt"

  # Cleanup happens automatically via trap
}

main "$@"

#fin
```

**Temp files with error handling:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Robust temp file creation with validation
create_temp_robust() {
  local -- temp_file

  # Create temp file
  if ! temp_file=$(mktemp 2>&1); then
    die 1 "Failed to create temporary file: $temp_file"
  fi

  # Validate temp file was created
  if [[ ! -f "$temp_file" ]]; then
    die 1 "Temp file does not exist: $temp_file"
  fi

  # Check permissions (should be 0600)
  local -- perms
  perms=$(stat -c %a "$temp_file" 2>/dev/null || stat -f %Lp "$temp_file" 2>/dev/null)
  if [[ "$perms" != '600' ]]; then
    rm -f "$temp_file"
    die 1 "Temp file has insecure permissions: $perms"
  fi

  # Set up cleanup
  trap 'rm -f "$temp_file"' EXIT
  readonly -- temp_file

  info "Created secure temp file: $temp_file (permissions: $perms)"

  echo "$temp_file"
}

main() {
  local -- temp_file
  temp_file=$(create_temp_robust)

  # Use temp file
  echo 'Sensitive data' > "$temp_file"
}

main "$@"

#fin
```

**Complete example - Data processor with temp files:**

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
declare -i KEEP_TEMP=0
declare -a TEMP_RESOURCES=()

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
    debug) prefix+=" ⋯" ;;
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
debug() { ((VERBOSE >= 2)) || return 0; >&2 _msg "$@"; }

die() {
  local -i exit_code=${1:-1}
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}

# ============================================================================
# Cleanup Functions
# ============================================================================

cleanup() {
  local -i exit_code=$?
  local -- resource

  if ((KEEP_TEMP)); then
    if [[ ${#TEMP_RESOURCES[@]} -gt 0 ]]; then
      info 'Keeping temporary files (--keep-temp specified):'
      for resource in "${TEMP_RESOURCES[@]}"; do
        info "  $resource"
      done
    fi
    return "$exit_code"
  fi

  if [[ ${#TEMP_RESOURCES[@]} -gt 0 ]]; then
    debug "Cleaning up ${#TEMP_RESOURCES[@]} temporary resources"

    for resource in "${TEMP_RESOURCES[@]}"; do
      if [[ -f "$resource" ]]; then
        debug "Removing temp file: $resource"
        rm -f "$resource"
      elif [[ -d "$resource" ]]; then
        debug "Removing temp directory: $resource"
        rm -rf "$resource"
      fi
    done
  fi

  return "$exit_code"
}

# Set up cleanup trap
trap cleanup EXIT

# ============================================================================
# Temp Resource Management
# ============================================================================

# Create temp file and register for cleanup
make_temp_file() {
  local -- template="${1:-}"
  local -- temp_file

  if [[ -n "$template" ]]; then
    temp_file=$(mktemp "/tmp/$template.XXXXXX") ||
      die 1 "Failed to create temp file with template: $template"
  else
    temp_file=$(mktemp) ||
      die 1 'Failed to create temp file'
  fi

  # Register for cleanup
  TEMP_RESOURCES+=("$temp_file")

  debug "Created temp file: $temp_file"
  echo "$temp_file"
}

# Create temp directory and register for cleanup
make_temp_dir() {
  local -- template="${1:-}"
  local -- temp_dir

  if [[ -n "$template" ]]; then
    temp_dir=$(mktemp -d "/tmp/$template.XXXXXX") ||
      die 1 "Failed to create temp directory with template: $template"
  else
    temp_dir=$(mktemp -d) ||
      die 1 'Failed to create temp directory'
  fi

  # Register for cleanup
  TEMP_RESOURCES+=("$temp_dir")

  debug "Created temp directory: $temp_dir"
  echo "$temp_dir"
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

# Process file with multiple temp files
process_file() {
  local -- input_file="$1"
  local -- output_file="$2"

  # Validate input
  if [[ ! -f "$input_file" ]]; then
    error "Input file not found: $input_file"
    return 2
  fi

  if [[ ! -r "$input_file" ]]; then
    error "Input file not readable: $input_file"
    return 1
  fi

  info "Processing: $input_file -> $output_file"

  # Create temp files for processing stages
  local -- temp_filtered temp_sorted temp_unique
  temp_filtered=$(make_temp_file "$SCRIPT_NAME-filtered")
  temp_sorted=$(make_temp_file "$SCRIPT_NAME-sorted")
  temp_unique=$(make_temp_file "$SCRIPT_NAME-unique")

  # Stage 1: Filter comments and empty lines
  debug 'Stage 1: Filtering'
  grep -v '^#' "$input_file" | grep -v '^[[:space:]]*$' > "$temp_filtered"

  local -i filtered_lines
  filtered_lines=$(wc -l < "$temp_filtered")
  debug "Filtered lines: $filtered_lines"

  # Stage 2: Sort
  debug 'Stage 2: Sorting'
  sort "$temp_filtered" > "$temp_sorted"

  # Stage 3: Remove duplicates
  debug 'Stage 3: Removing duplicates'
  sort -u "$temp_sorted" > "$temp_unique"

  local -i unique_lines
  unique_lines=$(wc -l < "$temp_unique")
  debug "Unique lines: $unique_lines"

  # Write final output
  if ((DRY_RUN)); then
    info "[DRY-RUN] Would write to: $output_file"
    info "[DRY-RUN] Output preview:"
    head -n 5 "$temp_unique"
  else
    cp "$temp_unique" "$output_file"
    success "Processed $input_file -> $output_file ($unique_lines unique lines)"
  fi

  return 0
}

# Batch process multiple files
batch_process() {
  local -a input_files=("$@")
  local -- input_file output_file
  local -i success_count=0
  local -i error_count=0

  # Create temp directory for outputs
  local -- temp_output_dir
  temp_output_dir=$(make_temp_dir "$SCRIPT_NAME-output")

  info "Processing ${#input_files[@]} files"

  for input_file in "${input_files[@]}"; do
    output_file="$temp_output_dir/${input_file##*/}.processed"

    if process_file "$input_file" "$output_file"; then
      ((success_count+=1))
    else
      ((error_count+=1))
    fi
  done

  # Report results
  info "Results: $success_count succeeded, $error_count failed"

  if ((success_count > 0)); then
    info 'Processed files:'
    ls -lh "$temp_output_dir"
  fi

  # Return appropriate exit code
  ((error_count == 0))
}

# ============================================================================
# Main Function
# ============================================================================

usage() {
  cat <<'EOF'
Usage: script.sh [OPTIONS] FILE...

Process files with temporary file handling.

Options:
  -v, --verbose       Verbose output
  -vv                 Very verbose (debug) output
  -n, --dry-run       Dry-run mode
  -k, --keep-temp     Keep temporary files after completion
  -h, --help          Show this help message
  -V, --version       Show version

Arguments:
  FILE...             Input files to process

Examples:
  script.sh file.txt
  script.sh -v file1.txt file2.txt
  script.sh -k --dry-run data/*.txt
EOF
}

main() {
  local -a input_files=()

  # Parse arguments
  while (($#)); do
    case $1 in
      -v|--verbose)
        VERBOSE=1
        ;;

      -vv)
        VERBOSE=2
        ;;

      -n|--dry-run)
        DRY_RUN=1
        ;;

      -k|--keep-temp)
        KEEP_TEMP=1
        ;;

      -V|--version)
        echo "$SCRIPT_NAME $VERSION"
        return 0
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
    esac
    shift
  done

  # Collect remaining arguments
  input_files+=("$@")

  # Make variables readonly
  readonly -- VERBOSE DRY_RUN KEEP_TEMP
  readonly -a input_files

  # Validate
  if [[ ${#input_files[@]} -eq 0 ]]; then
    error 'No input files specified'
    usage
    return 22
  fi

  # Display configuration
  if ((VERBOSE)); then
    info "$SCRIPT_NAME $VERSION"
    info "Input files: ${#input_files[@]}"
    ((DRY_RUN)) && info '[DRY-RUN] Mode enabled'
    ((KEEP_TEMP)) && info '[KEEP-TEMP] Temporary files will be preserved'
  fi

  # Process files
  batch_process "${input_files[@]}"
}

# ============================================================================
# Script Invocation
# ============================================================================

main "$@"

#fin
```

**Temp file security considerations:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ CORRECT - Secure temp file handling
secure_temp_file() {
  local -- temp_file

  # Create with secure permissions (0600)
  temp_file=$(mktemp) || die 1 'Failed to create temp file'

  # Verify it's a regular file
  if [[ ! -f "$temp_file" ]]; then
    die 1 "Temp file is not a regular file: $temp_file"
  fi

  # Verify ownership (should be current user)
  local -- owner
  owner=$(stat -c %U "$temp_file" 2>/dev/null || stat -f %Su "$temp_file" 2>/dev/null)
  if [[ "$owner" != "$USER" ]]; then
    rm -f "$temp_file"
    die 1 "Temp file has wrong owner: $owner (expected: $USER)"
  fi

  # Verify permissions (0600)
  local -- perms
  perms=$(stat -c %a "$temp_file" 2>/dev/null || stat -f %Lp "$temp_file" 2>/dev/null)
  if [[ "$perms" != '600' ]]; then
    rm -f "$temp_file"
    die 1 "Temp file has insecure permissions: $perms"
  fi

  # Set up cleanup
  trap 'rm -f "$temp_file"' EXIT
  readonly -- temp_file

  info "Created secure temp file: $temp_file"
  info "  Owner: $owner"
  info "  Permissions: $perms"

  echo "$temp_file"
}

# ✓ CORRECT - Secure temp directory handling
secure_temp_dir() {
  local -- temp_dir

  # Create with secure permissions (0700)
  temp_dir=$(mktemp -d) || die 1 'Failed to create temp directory'

  # Verify it's a directory
  if [[ ! -d "$temp_dir" ]]; then
    die 1 "Temp path is not a directory: $temp_dir"
  fi

  # Verify permissions (0700)
  local -- perms
  perms=$(stat -c %a "$temp_dir" 2>/dev/null || stat -f %Lp "$temp_dir" 2>/dev/null)
  if [[ "$perms" != '700' ]]; then
    rm -rf "$temp_dir"
    die 1 "Temp directory has insecure permissions: $perms"
  fi

  # Set up cleanup
  trap 'rm -rf "$temp_dir"' EXIT
  readonly -- temp_dir

  info "Created secure temp directory: $temp_dir (permissions: $perms)"

  echo "$temp_dir"
}

main() {
  local -- temp_file temp_dir

  temp_file=$(secure_temp_file)
  temp_dir=$(secure_temp_dir)

  # Use temp resources
  echo 'Sensitive data' > "$temp_file"
  echo 'More data' > "$temp_dir/file.txt"
}

main "$@"

#fin
```

**Anti-patterns to avoid:**

```bash
# ✗ WRONG - Hard-coded temp file path
temp_file="/tmp/myapp_temp.txt"
echo 'data' > "$temp_file"
# Problems:
# - Not unique (collisions with other instances)
# - Predictable name (security risk)
# - No automatic cleanup

# ✓ CORRECT - Use mktemp
temp_file=$(mktemp) || die 1 'Failed to create temp file'
trap 'rm -f "$temp_file"' EXIT
echo 'data' > "$temp_file"

# ✗ WRONG - Using PID in filename
temp_file="/tmp/myapp_$$.txt"
echo 'data' > "$temp_file"
# Problems:
# - Still predictable
# - Race condition between check and create
# - No automatic cleanup

# ✓ CORRECT - Use mktemp with template
temp_file=$(mktemp /tmp/myapp.XXXXXX) || die 1 'Failed to create temp file'
trap 'rm -f "$temp_file"' EXIT

# ✗ WRONG - No cleanup trap
temp_file=$(mktemp)
echo 'data' > "$temp_file"
# Script exits, temp file remains!

# ✓ CORRECT - Always set trap
temp_file=$(mktemp) || die 1 'Failed to create temp file'
trap 'rm -f "$temp_file"' EXIT

# ✗ WRONG - Cleanup in script body
temp_file=$(mktemp)
echo 'data' > "$temp_file"
rm -f "$temp_file"
# If script fails before rm, file remains!

# ✓ CORRECT - Cleanup in trap
temp_file=$(mktemp) || die 1 'Failed to create temp file'
trap 'rm -f "$temp_file"' EXIT
echo 'data' > "$temp_file"
# Cleanup happens even if script fails

# ✗ WRONG - Creating temp file manually
temp_file="/tmp/myapp_$(date +%s).txt"
touch "$temp_file"
chmod 600 "$temp_file"
# Problems:
# - Not atomic
# - Race conditions
# - Reinventing mktemp badly

# ✓ CORRECT - Use mktemp
temp_file=$(mktemp) || die 1 'Failed to create temp file'
trap 'rm -f "$temp_file"' EXIT

# ✗ WRONG - Insecure permissions
temp_file=$(mktemp)
chmod 666 "$temp_file"  # World writable!
echo 'sensitive data' > "$temp_file"

# ✓ CORRECT - Keep default secure permissions
temp_file=$(mktemp) || die 1 'Failed to create temp file'
# Permissions are already 0600 (user read/write only)
echo 'sensitive data' > "$temp_file"

# ✗ WRONG - Not checking mktemp success
temp_file=$(mktemp)
echo 'data' > "$temp_file"  # May fail if mktemp failed!

# ✓ CORRECT - Check mktemp success
temp_file=$(mktemp) || die 1 'Failed to create temp file'
echo 'data' > "$temp_file"

# ✗ WRONG - Multiple traps overwrite each other
temp1=$(mktemp)
trap 'rm -f "$temp1"' EXIT

temp2=$(mktemp)
trap 'rm -f "$temp2"' EXIT  # Overwrites previous trap!
# temp1 won't be cleaned up!

# ✓ CORRECT - Single trap for all cleanup
temp1=$(mktemp) || die 1 'Failed to create temp file'
temp2=$(mktemp) || die 1 'Failed to create temp file'
trap 'rm -f "$temp1" "$temp2"' EXIT

# ✓ BETTER - Cleanup function
declare -a TEMP_FILES=()
cleanup() {
  local -- file
  for file in "${TEMP_FILES[@]}"; do
    [[ -f "$file" ]] && rm -f "$file"
  done
}
trap cleanup EXIT

temp1=$(mktemp)
TEMP_FILES+=("$temp1")

temp2=$(mktemp)
TEMP_FILES+=("$temp2")

# ✗ WRONG - Using /tmp directly in script directory
temp_file="$SCRIPT_DIR/temp.txt"
# Problem: pollutes script directory

# ✓ CORRECT - Use system temp directory
temp_file=$(mktemp) || die 1 'Failed to create temp file'
trap 'rm -f "$temp_file"' EXIT

# ✗ WRONG - Removing temp directory without -r
temp_dir=$(mktemp -d)
trap 'rm "$temp_dir"' EXIT  # Fails if directory not empty!

# ✓ CORRECT - Use -rf for directories
temp_dir=$(mktemp -d) || die 1 'Failed to create temp directory'
trap 'rm -rf "$temp_dir"' EXIT
```

**Edge cases:**

**1. Cleanup on different exit conditions:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -- TEMP_FILE=''

cleanup() {
  local -i exit_code=$?

  if [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]]; then
    if ((exit_code == 0)); then
      info 'Cleaning up (success)'
    else
      warn "Cleaning up (error: exit code $exit_code)"
    fi
    rm -f "$TEMP_FILE"
  fi

  return "$exit_code"
}

trap cleanup EXIT

main() {
  TEMP_FILE=$(mktemp) || die 1 'Failed to create temp file'
  readonly -- TEMP_FILE

  info "Using temp file: $TEMP_FILE"

  # Do work...

  # Cleanup happens automatically
  return 0
}

main "$@"

#fin
```

**2. Preserving temp files for debugging:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -i KEEP_TEMP=0
declare -a TEMP_FILES=()

cleanup() {
  local -i exit_code=$?
  local -- file

  if ((KEEP_TEMP)); then
    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
      info 'Keeping temp files for debugging:'
      for file in "${TEMP_FILES[@]}"; do
        info "  $file"
      done
    fi
  else
    for file in "${TEMP_FILES[@]}"; do
      [[ -f "$file" ]] && rm -f "$file"
      [[ -d "$file" ]] && rm -rf "$file"
    done
  fi

  return "$exit_code"
}

trap cleanup EXIT

main() {
  # Parse --keep-temp option
  while (($#)); do
    case $1 in
      --keep-temp) KEEP_TEMP=1 ;;
      *) break ;;
    esac
    shift
  done

  readonly -- KEEP_TEMP

  local -- temp_file
  temp_file=$(mktemp)
  TEMP_FILES+=("$temp_file")

  echo 'Debug data' > "$temp_file"

  # If --keep-temp specified, files preserved
}

main "$@"

#fin
```

**3. Temp files in specific directory:**

```bash
# Create temp file in specific directory
temp_file=$(mktemp "$SCRIPT_DIR/temp.XXXXXX") ||
  die 1 'Failed to create temp file in script directory'

trap 'rm -f "$temp_file"' EXIT

# Create temp directory in specific location
temp_dir=$(mktemp -d "$HOME/work/temp.XXXXXX") ||
  die 1 'Failed to create temp directory'

trap 'rm -rf "$temp_dir"' EXIT
```

**4. Multiple trap handlers:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -a TEMP_FILES=()

# Cleanup temp files
cleanup_temp() {
  local -- file
  for file in "${TEMP_FILES[@]}"; do
    [[ -f "$file" ]] && rm -f "$file"
    [[ -d "$file" ]] && rm -rf "$file"
  done
}

# Other cleanup
cleanup_other() {
  # Other cleanup tasks
  info 'Performing other cleanup'
}

# Combined cleanup
cleanup() {
  local -i exit_code=$?

  cleanup_temp
  cleanup_other

  return "$exit_code"
}

trap cleanup EXIT

main() {
  local -- temp_file
  temp_file=$(mktemp)
  TEMP_FILES+=("$temp_file")

  # Do work...
}

main "$@"

#fin
```

**5. Handling signals:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -- TEMP_FILE=''

cleanup() {
  local -i exit_code=$?

  if [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]]; then
    rm -f "$TEMP_FILE"
  fi

  return "$exit_code"
}

# Cleanup on normal exit and signals
trap cleanup EXIT SIGINT SIGTERM

main() {
  TEMP_FILE=$(mktemp) || die 1 'Failed to create temp file'
  readonly -- TEMP_FILE

  info "Press Ctrl-C to test signal handling"

  # Simulate long-running operation
  local -i i
  for ((i=1; i<=60; i+=1)); do
    echo "Working... $i"
    sleep 1
  done

  # Cleanup happens even if interrupted
}

main "$@"

#fin
```

**Summary:**

- **Always use mktemp** - never hard-code temp file paths
- **Use trap for cleanup** - ensure cleanup happens even on failure
- **Register all temp resources** - in array or cleanup function
- **EXIT trap is mandatory** - automatic cleanup when script ends
- **Check mktemp success** - `|| die` to handle creation failure
- **Default permissions are secure** - mktemp creates 0600 files, 0700 directories
- **Template support** - use custom templates for recognizable temp files
- **Keep variables readonly** - prevent accidental modification
- **Cleanup function pattern** - for multiple temp files/directories
- **--keep-temp option** - useful for debugging
- **Signal handling** - trap SIGINT SIGTERM for interruption cleanup
- **Verify security** - check permissions and ownership if handling sensitive data

**Key principle:** Temporary files are a common source of security vulnerabilities and resource leaks. Always use mktemp for creation (never hard-code paths), always use trap EXIT for cleanup (never rely on manual cleanup), and always verify that cleanup actually occurs. The combination of mktemp + trap EXIT is the gold standard for temp file handling in Bash - it's atomic, secure, and guarantees cleanup even when scripts fail or are interrupted.
