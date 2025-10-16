### Type-Specific Declarations

**Always use explicit type declarations (`declare -i`, `declare --`, `declare -a`, `declare -A`) to make variable intent clear and enable type-safe operations. Explicit typing prevents bugs, improves readability, and enables bash's built-in type checking.**

**Rationale:**

- **Type Safety**: Integer declarations (`-i`) automatically enforce numeric operations and catch non-numeric assignments
- **Intent Documentation**: Explicit types serve as inline documentation showing how the variable will be used
- **Array Safety**: Array declarations prevent accidental scalar assignment that would break array operations
- **Scope Control**: `declare` and `local` provide precise variable scoping (global vs function-local)
- **Performance**: Type-specific operations are faster than string-based operations
- **Error Prevention**: Type mismatches are caught early rather than causing subtle bugs later

**All declaration types:**

**1. Integer variables (`declare -i`)**

**Purpose**: Variables that will hold only numeric values and participate in arithmetic operations.

\`\`\`bash
# Declare integer variable
declare -i count=0
declare -i exit_code=1
declare -i port=8080

# Automatic arithmetic evaluation
count=count+1  # Same as: ((count+=1))
count='5 + 3'  # Evaluates to 8, not string "5 + 3"

# Type enforcement
count='abc'  # Evaluates to 0 (non-numeric becomes 0)
echo "$count"  # Output: 0
\`\`\`

**When to use:**
- Counters, loop indices
- Exit codes
- Port numbers
- Numeric flags (though consider using `declare -i FLAG=0` or `declare -i FLAG=1`)
- Any variable used in arithmetic operations

**Benefits:**
- Automatic arithmetic evaluation (no need for `$(())` in some contexts)
- Type checking (non-numeric values become 0)
- Clear intent that variable holds numbers

**2. String variables (`declare --`)**

**Purpose**: Variables that hold text strings. The `--` separator prevents option injection.

\`\`\`bash
# Declare string variables
declare -- filename='data.txt'
declare -- user_input=''
declare -- config_path="/etc/app/config.conf"

# ` --` prevents option injection if variable name starts with -
declare -- var_name='-weird'  # Without --, this would be interpreted as option
\`\`\`

**When to use:**
- File paths
- User input
- Configuration values
- Any text data
- Default choice for most variables

**Benefits:**
- Explicit intent that variable holds text
- `--` separator prevents option injection bugs
- Clear distinction from integers and arrays

**3. Indexed arrays (`declare -a`)**

**Purpose**: Ordered lists indexed by integers (0, 1, 2, ...).

\`\`\`bash
# Declare indexed array
declare -a files=()
declare -a args=('one' 'two' 'three')
declare -a paths

# Add elements
files+=('file1.txt')
files+=('file2.txt')

# Access elements
echo "${files[0]}"  # file1.txt
echo "${files[@]}"  # All elements
echo "${#files[@]}"  # Count: 2

# Iterate
for file in "${files[@]}"; do
  process "$file"
done
\`\`\`

**When to use:**
- Lists of items (files, arguments, options)
- Command arrays for safe execution
- Any sequential collection
- Anytime you need to iterate over multiple values

**Benefits:**
- Safe word splitting (quoted expansion preserves spaces)
- Clear intent that variable is a list
- Prevents accidental scalar assignment

**4. Associative arrays (`declare -A`)**

**Purpose**: Key-value maps (hash tables, dictionaries).

\`\`\`bash
# Declare associative array
declare -A config=(
  [app_name]='myapp'
  [app_port]='8080'
  [app_host]='localhost'
)

declare -A user_data=()

# Add/modify elements
user_data[name]='Alice'
user_data[email]='alice@example.com'

# Access elements
echo "${config[app_name]}"  # myapp
echo "${!config[@]}"  # All keys
echo "${config[@]}"  # All values

# Check if key exists
if [[ -v "config[app_port]" ]]; then
  echo "Port configured: ${config[app_port]}"
fi

# Iterate over keys
for key in "${!config[@]}"; do
  echo "$key = ${config[$key]}"
done
\`\`\`

**When to use:**
- Configuration data (key-value pairs)
- Dynamic function dispatch
- Caching/memoization
- Any data organized by named keys rather than numeric indices

**Benefits:**
- Clear key-value relationship
- Fast lookups by key
- Replaces need for multiple scalar variables

**5. Read-only constants (`readonly --`)**

**Purpose**: Variables that should never change after initialization.

\`\`\`bash
# Declare constants
readonly -- VERSION='1.0.0'
readonly -i MAX_RETRIES=3
readonly -a ALLOWED_ACTIONS=('start' 'stop' 'restart' 'status')

# Attempt to modify (will fail)
VERSION='2.0.0'  # bash: VERSION: readonly variable

# Verify readonly status
readonly -p | grep VERSION
# Output: declare -r VERSION="1.0.0"
\`\`\`

**When to use:**
- VERSION, SCRIPT_PATH, SCRIPT_DIR, SCRIPT_NAME
- Configuration values that shouldn't change
- Magic numbers/strings
- Validated user input (after validation, make readonly)

**Benefits:**
- Prevents accidental modification
- Self-documenting (signals immutability)
- Defensive programming

**6. Local variables in functions (`local`)**

**Purpose**: Variables scoped to function, not visible outside.

\`\`\`bash
process_file() {
  local -- filename="$1"
  local -i line_count
  local -a lines

  # These variables don't exist outside this function
  line_count=$(wc -l < "$filename")
  readarray -t lines < "$filename"

  echo "Processed $line_count lines"
}

# filename, line_count, lines don't exist here
\`\`\`

**When to use:**
- ALL function parameters
- ALL temporary variables in functions
- Variables that shouldn't leak to global scope

**Benefits:**
- Prevents global namespace pollution
- Avoids variable collision between functions
- Clear scoping (function-local vs global)

**Combining type and scope:**

\`\`\`bash
# Global integer
declare -i GLOBAL_COUNT=0

function count_files() {
  local -- dir="$1"
  local -i file_count
  local -a files

  # Local integer variable
  file_count=0

  # Local array
  files=("$dir"/*)

  for file in "${files[@]}"; do
    [[ -f "$file" ]] && ((file_count+=1))
  done

  echo "$file_count"
}

# Global array
declare -a PROCESSED_FILES=()

# Global associative array
declare -A FILE_STATUS=()

# Global readonly
readonly -- CONFIG_FILE='config.conf'
\`\`\`

**Complete example showing all types:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Integer variables
declare -i VERBOSE=0
declare -i ERROR_COUNT=0
declare -i MAX_RETRIES=3

# String variables
declare -- LOG_FILE="/var/log/$SCRIPT_NAME.log"
declare -- CONFIG_FILE="$SCRIPT_DIR/config.conf"

# Indexed arrays
declare -a FILES_TO_PROCESS=()
declare -a FAILED_FILES=()

# Associative arrays
declare -A CONFIG=(
  [timeout]='30'
  [retries]='3'
  [verbose]='false'
)

declare -A FILE_CHECKSUMS=()

# ============================================================================
# Color Definitions
# ============================================================================

if [[ -t 1 && -t 2 ]]; then
  readonly -- RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  readonly -- RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

# ============================================================================
# Utility Functions
# ============================================================================

_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case "${FUNCNAME[1]}" in
    info)    prefix+=" ${CYAN}◉${NC}" ;;
    warn)    prefix+=" ${YELLOW}⚡${NC}" ;;
    success) prefix+=" ${GREEN}✓${NC}" ;;
    *)       ;;
  esac
  for msg in "$@"; do printf '%s %s\n' "$prefix" "$msg"; done
}

info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn() { >&2 _msg "$@"; }
success() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }

# ============================================================================
# Business Logic Functions
# ============================================================================

# Function with local typed variables
process_file() {
  local -- input_file="$1"
  local -i attempt=0
  local -i success=0
  local -- checksum

  while ((attempt < MAX_RETRIES && !success)); do
    ((attempt+=1))

    info "Processing $input_file (attempt $attempt)"

    if process_command "$input_file"; then
      success=1
      checksum=$(sha256sum "$input_file" | cut -d' ' -f1)
      FILE_CHECKSUMS["$input_file"]="$checksum"
      info "Success: $input_file ($checksum)"
    else
      warn "Failed: $input_file (attempt $attempt/$MAX_RETRIES)"
      ((ERROR_COUNT+=1))
    fi
  done

  if ((success)); then
    return 0
  else
    FAILED_FILES+=("$input_file")
    return 1
  fi
}

main() {
  # Load files into array
  FILES_TO_PROCESS=("$SCRIPT_DIR"/data/*.txt)

  # Process each file
  local -- file
  for file in "${FILES_TO_PROCESS[@]}"; do
    process_file "$file"
  done

  # Report results
  info "Processed: ${#FILES_TO_PROCESS[@]} files"
  info "Errors: $ERROR_COUNT"
  info "Failed: ${#FAILED_FILES[@]} files"

  # Show checksums
  local -- filename
  for filename in "${!FILE_CHECKSUMS[@]}"; do
    info "Checksum: $filename = ${FILE_CHECKSUMS[$filename]}"
  done

  ((ERROR_COUNT == 0))  # Exit code: 0 if no errors, 1 if errors
}

main "$@"

#fin
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - no type declaration (intent unclear)
count=0
files=()

# ✓ Correct - explicit type declarations
declare -i count=0
declare -a files=()

# ✗ Wrong - using strings for numeric operations
max_retries='3'
attempts='0'
if [[ "$attempts" -lt "$max_retries" ]]; then  # String comparison!

# ✓ Correct - use integers for numeric operations
declare -i max_retries=3
declare -i attempts=0
if ((attempts < max_retries)); then  # Numeric comparison

# ✗ Wrong - forgetting -A for associative arrays
declare CONFIG  # Creates scalar, not associative array
CONFIG[key]='value'  # Treats 'key' as 0, creates indexed array!

# ✓ Correct - explicit associative array declaration
declare -A CONFIG=()
CONFIG[key]='value'

# ✗ Wrong - global variables in functions
process_data() {
  temp_var="$1"  # Global variable leak!
  result=$(process "$temp_var")
}

# ✓ Correct - local variables in functions
process_data() {
  local -- temp_var="$1"
  local -- result
  result=$(process "$temp_var")
}

# ✗ Wrong - forgetting -- separator
declare filename='-weird'  # Interpreted as option!

# ✓ Correct - use -- separator
declare -- filename='-weird'

# ✗ Wrong - scalar assignment to array variable
declare -a files=()
files='file.txt'  # Overwrites array with scalar!

# ✓ Correct - array assignment
declare -a files=()
files=('file.txt')  # Array with one element
# Or
files+=('file.txt')  # Append to array

# ✗ Wrong - using readonly without type
readonly VAR='value'  # Type unclear

# ✓ Correct - combine readonly with type
readonly -- VAR='value'
readonly -i COUNT=10
readonly -a ACTIONS=('start' 'stop')
\`\`\`

**Edge cases:**

**1. Integer overflow:**

\`\`\`bash
declare -i big_number=9223372036854775807  # Max 64-bit signed int
((big_number+=1))
echo "$big_number"  # Wraps to negative!

# For very large numbers, use string or bc
declare -- big='99999999999999999999'
result=$(bc <<< "$big + 1")
\`\`\`

**2. Associative array requires Bash 4.0+:**

\`\`\`bash
# Check bash version
if ((BASH_VERSINFO[0] < 4)); then
  die 1 'Associative arrays require Bash 4.0+'
fi

declare -A config=()
\`\`\`

**3. Array assignment syntax:**

\`\`\`bash
# All of these create arrays correctly:
declare -a arr1=()           # Empty array
declare -a arr2=('a' 'b')    # Array with 2 elements
declare -a arr3              # Declare without initialization

# This creates scalar, not array:
declare -a arr4='string'     # arr4 is string 'string', not array!

# Correct array with single element:
declare -a arr5=('string')   # Array with one element
\`\`\`

**4. Local arrays in functions:**

\`\`\`bash
process_list() {
  # Both type and scope modifiers
  local -a files=()
  local -A status=()

  # Use arrays locally
  files=("$@")
  status[total]="${#files[@]}"
}
\`\`\`

**5. Nameref variables (Bash 4.3+):**

\`\`\`bash
# Pass array by reference
modify_array() {
  local -n arr_ref=$1  # Nameref to array

  arr_ref+=('new element')
}

declare -a my_array=('a' 'b')
modify_array my_array  # Pass name, not value
echo "${my_array[@]}"  # Output: a b new element
\`\`\`

**Summary:**

- **Use `declare -i`** for integer variables (counters, exit codes, ports)
- **Use `declare --`** for string variables (paths, text, user input)
- **Use `declare -a`** for indexed arrays (lists, sequences)
- **Use `declare -A`** for associative arrays (key-value maps, configs)
- **Use `readonly --`** for constants that shouldn't change
- **Use `local`** for ALL variables in functions (prevent global leaks)
- **Combine modifiers** when needed: `local -i`, `local -a`, `readonly -A`
- **Always use `--`** separator to prevent option injection

**Key principle:** Explicit type declarations serve as inline documentation and enable type checking. When you declare `declare -i count=0`, you're telling both Bash and future readers: "This variable holds an integer and will be used in arithmetic operations."
