# Short-Option Disaggregation in Command-Line Processing Loops

## Overview

Short-option disaggregation is the process of splitting bundled short options (e.g., `-abc`) into individual options (`-a -b -c`) for processing in command-line argument parsing loops. This allows users to write commands like `script -vvn` instead of `script -v -v -n`, following standard Unix conventions.

This document provides a comprehensive analysis of three methods for implementing short-option disaggregation in Bash scripts, including performance benchmarks, implementation details, and practical examples.

## Why Disaggregation is Needed

Unix/Linux command-line conventions allow users to bundle single-character options:

```bash
# These should be equivalent:
ls -lha
ls -l -h -a

# These should be equivalent:
script -vvn file.txt
script -v -v -n file.txt
```

Without disaggregation support, your script would treat `-lha` as a single unknown option rather than three separate options (`-l`, `-h`, `-a`). Disaggregation makes your script user-friendly and compliant with Unix conventions.

## The Three Methods

### Method 1: grep (Current Standard)

**Approach:** Use `grep -o .` to split characters

```bash
case $1 in
  # ...
  -[amLpvqVh]*) #shellcheck disable=SC2046 #split up aggregated short options
    set -- '' $(printf -- "-%c " $(grep -o . <<<"${1:1}")) "${@:2}"
    ;;
  # ...
esac
```

**How it works:**
1. `${1:1}` removes the leading dash from the option string
2. `grep -o .` outputs each character on a separate line
3. `printf -- "-%c "` adds a dash before each character
4. `set --` replaces the argument list with the expanded options
5. Leading empty string is added then removed to handle edge cases

**Pros:**
- Compact one-liner
- Standard approach used in most scripts
- Well-tested and reliable

**Cons:**
- Requires external `grep` command
- Slower performance (~190 iter/sec)
- Requires shellcheck disable for SC2046
- External process overhead

**Performance:** ~190 iterations/second

### Method 2: fold (Alternative)

**Approach:** Use `fold -w1` to split characters

```bash
case $1 in
  # ...
  -[amLpvqVh]*) #split up aggregated short options
    set -- '' $(printf -- "-%c " $(fold -w1 <<<"${1:1}")) "${@:2}"
    ;;
  # ...
esac
```

**How it works:**
1. `${1:1}` removes the leading dash
2. `fold -w1` wraps text at 1-character width (splits each char to its own line)
3. `printf -- "-%c "` adds a dash before each character
4. `set --` replaces the argument list

**Pros:**
- Slightly faster than grep (~3% improvement)
- More semantically correct (fold is designed for line wrapping)
- One-liner implementation

**Cons:**
- Still requires external command
- Still needs shellcheck disable
- Marginal performance improvement over grep
- External process overhead

**Performance:** ~195 iterations/second

### Method 3: Pure Bash (Recommended)

**Approach:** Use only bash built-ins for maximum performance

```bash
case $1 in
  # ...
  -[amLpvqVh]*) # Split up single options (pure bash)
    local -- opt=${1:1}
    local -a new_args=()
    while ((${#opt})); do
      new_args+=("-${opt:0:1}")
      opt=${opt:1}
    done
    set -- '' "${new_args[@]}" "${@:2}"
    ;;
  # ...
esac
```

**How it works:**
1. `opt=${1:1}` captures option string without leading dash
2. Initialize empty array `new_args=()`
3. Loop while option string has characters: `while ((${#opt}))`
4. Extract first character, prepend dash, append to array: `new_args+=("-${opt:0:1}")`
5. Remove first character from string: `opt=${opt:1}`
6. Replace argument list with expanded options

**Pros:**
- **68% faster** than grep/fold methods (~318 iter/sec)
- No external dependencies
- No shellcheck warnings needed
- More portable (works anywhere bash 4+ is available)
- No subprocess overhead

**Cons:**
- More verbose (6 lines vs 1 line)
- Slightly more complex logic

**Performance:** ~318 iterations/second

## Performance Comparison

**Benchmark Results (3-second test runs):**

| Method | Iterations | Iter/Sec | Relative Speed | External Deps | Shellcheck |
|--------|-----------|----------|----------------|---------------|------------|
| grep (current) | ~573 | 190.82 | Baseline | grep | SC2046 disable |
| fold | ~586 | 195.25 | +2.3% | fold | SC2046 disable |
| **Pure Bash** | **~954** | **317.75** | **+66.5%** | **None** | **Clean** |

**Key Finding:** Pure bash is approximately **68% faster** than external command methods, with no external dependencies and no shellcheck warnings.

## Complete Implementation Examples

### Example 1: Using grep (Current Standard)

```bash
#!/usr/bin/env bash
# My first script
set -euo pipefail
shopt -s inherit_errexit shift_verbose

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Default values
declare -i VERBOSE=0
declare -i DRY_RUN=0
declare -- output_file=''
declare -a files=()

# ============================================================================
# Utility Functions
# ============================================================================

error() { >&2 echo "$SCRIPT_NAME: error: $*"; }
die() { (($#>1)) && error "$@"; exit ${1:-0}; }

noarg() { (($# > 1)) || die 2 "Option '$1' requires an argument"; }

show_help() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] FILE...

Process files with various options.

Options:
  -o, --output FILE  Output file (required)
  -n, --dry-run      Dry-run mode
  -v, --verbose      Verbose output (stackable)
  -V, --version      Show version
  -h, --help         Show this help

Examples:
  $SCRIPT_NAME -o output.txt file1.txt file2.txt
  $SCRIPT_NAME -vvno output.txt *.txt
EOF
}

# ============================================================================
# Main Function
# ============================================================================

main() {
  # Parse arguments
  while (($#)); do case $1 in
    -o|--output)    noarg "$@"; shift; output_file=$1 ;;
    -n|--dry-run)   DRY_RUN=1 ;;

    -v|--verbose)   VERBOSE+=1 ;;
    -q|--quiet)     VERBOSE=0 ;;

    -V|--version)   echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
    -h|--help)      show_help; exit 0 ;;

    # Short option bundling support (grep method)
    -[onvqVh]*) #shellcheck disable=SC2046
                    set -- '' $(printf -- "-%c " $(grep -o . <<<"${1:1}")) "${@:2}" ;;
    -*)             die 22 "Invalid option '$1'" ;;
    *)              files+=("$1") ;;
  esac; shift; done

  # Make variables readonly after parsing
  readonly -- VERBOSE DRY_RUN output_file
  readonly -a files

  # Validate required arguments
  ((${#files[@]} > 0)) || die 2 'No input files specified'
  [[ -n "$output_file" ]] || die 2 'Output file required (use -o)'

  # Use parsed arguments
  ((VERBOSE)) && echo "Processing ${#files[@]} files"
  ((DRY_RUN)) && echo "[DRY RUN] Would write to ${output_file@Q}"

  # Process files
  local -- file
  for file in "${files[@]}"; do
    ((VERBOSE > 1)) && echo "Processing: $file"
    # Processing logic here
  done

  ((VERBOSE)) && echo "Results would be written to ${output_file@Q}"
}

main "$@"

#fin
```

### Example 2: Using fold

```bash
#!/usr/bin/env bash
# My first script
set -euo pipefail
shopt -s inherit_errexit shift_verbose

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Default values
declare -i VERBOSE=0
declare -i FORCE=0
declare -- config_file=''

# ============================================================================
# Utility Functions
# ============================================================================

error() { >&2 echo "$SCRIPT_NAME: error: $*"; }
die() { (($#>1)) && error "$@"; exit ${1:-0}; }

noarg() { (($# > 1)) || die 2 "Option ${1@Q} requires an argument"; }

show_help() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Configuration manager.

Options:
  -c, --config FILE  Configuration file
  -v, --verbose      Verbose output
  -f, --force        Force operation
  -V, --version      Show version
  -h, --help         Show this help
EOF
}

# ============================================================================
# Main Function
# ============================================================================

main() {
  # Parse arguments
  while (($#)); do case $1 in
    -c|--config)    (($#>0)) || die 22 "Option '$1' requires argument"
                    shift
                    config_file=$1 ;;
    -f|--force)     FORCE=1 ;;

    -v|--verbose)   VERBOSE+=1 ;;
    -q|--quiet)     VERBOSE=0 ;;

    -V|--version)   echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
    -h|--help)      show_help; exit 0 ;;

    # Short option bundling support (fold method)
    -[cfvqVh]*) #shellcheck disable=SC2046
                    set -- '' $(printf -- "-%c " $(fold -w1 <<<"${1:1}")) "${@:2}" ;;
    -*)             die 22 "Invalid option '$1'" ;;
    *)              die 2 "Unexpected argument '$1'" ;;
  esac; shift; done

  # Make variables readonly after parsing
  readonly -- VERBOSE FORCE config_file

  # Validate required arguments
  [[ -n "$config_file" ]] || die 2 'Configuration file required (use -c)'

  ((VERBOSE)) && echo "Using config ${config_file@Q}"
  ((FORCE)) && echo '[FORCE MODE] Ignoring safety checks'

  # Main logic here
}

main "$@"

#fin
```

### Example 3: Using Pure Bash (Recommended)

```bash
#!/usr/bin/env bash
# My first script
set -euo pipefail
shopt -s inherit_errexit shift_verbose

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Default values
declare -i VERBOSE=0
declare -i PARALLEL=1
declare -- mode='normal'
declare -a targets=()

# ============================================================================
# Utility Functions
# ============================================================================

error() { >&2 echo "$SCRIPT_NAME: error: $*"; }
die() { (($#>1)) && error "$@"; exit ${1:-0}; }

noarg() { (($# > 1)) || die 2 "Option '$1' requires an argument"; }

show_help() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] TARGET...

Process targets with configurable parallelism.

Options:
  -m, --mode MODE    Processing mode (normal|fast|safe)
  -j, --parallel N   Number of parallel jobs (default: 1)
  -v, --verbose      Verbose output (stackable)
  -q, --quiet        Quiet mode (suppress normal output)
  -V, --version      Show version
  -h, --help         Show this help

Examples:
  $SCRIPT_NAME -v target1 target2
  $SCRIPT_NAME -j4 -m fast target1 target2
  $SCRIPT_NAME -vvqj2 target1  # -q overrides -vv
EOF
}

# ============================================================================
# Main Function
# ============================================================================

main() {
  # Parse arguments
  while (($#)); do case $1 in
    -m|--mode)      noarg "$@"; shift
                    mode=$1 ;;
    -j|--parallel)  noarg "$@"; shift
                    PARALLEL=$1 ;;

    -v|--verbose)   VERBOSE+=1 ;;
    -q|--quiet)     VERBOSE=0 ;;

    -V|--version)   echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
    -h|--help)      show_help; exit 0 ;;

    # Short option bundling support (pure bash method)
    -[mjvqVh]*) # Split up single options (pure bash)
                    local -- opt=${1:1}
                    local -a new_args=()
                    while ((${#opt})); do
                      new_args+=("-${opt:0:1}")
                      opt=${opt:1}
                    done
                    set -- '' "${new_args[@]}" "${@:2}" ;;
    -*)             die 22 "Invalid option '$1'" ;;
    *)              targets+=("$1") ;;
  esac; shift; done

  # Make variables readonly after parsing
  readonly -- VERBOSE PARALLEL mode
  readonly -a targets

  # Validate arguments
  ((${#targets[@]} > 0)) || die 2 'No targets specified'
  [[ "$mode" =~ ^(normal|fast|safe)$ ]] || die 2 "Invalid mode: '$mode'"
  ((PARALLEL > 0)) || die 2 'Parallel jobs must be positive'

  # Use parsed arguments
  ((VERBOSE)) && {
    echo "Mode: $mode"
    echo "Parallel jobs: $PARALLEL"
    echo "Processing ${#targets[@]} targets"
  }

  # Process targets
  local -- target
  for target in "${targets[@]}"; do
    ((VERBOSE)) && echo "Processing '$target'"
    # Processing logic here
  done

  ((VERBOSE)) && echo "Complete"
}

main "$@"

#fin
```

## Usage Examples

All three methods support the same user-facing functionality:

```bash
# Single options
./script -v -v -n file.txt

# Bundled short options
./script -vvn file.txt

# Mixed bundled and separate
./script -vv -n file.txt

# Options with arguments cannot be bundled at the end
./script -vno output.txt file.txt  # -n -o output.txt

# Long options work normally
./script --verbose --verbose --dry-run file.txt

# Mixed long and short
./script -vv --dry-run -o output.txt file.txt
```

## Edge Cases and Considerations

### 1. Options Requiring Arguments

Options that take arguments cannot be in the middle of a bundle:

```bash
# ✓ Correct - option with argument at end or separate
./script -vno output.txt file.txt    # -v -n -o output.txt
./script -vn -o output.txt file.txt  # -v -n -o output.txt

# ✗ Wrong - option with argument in middle
./script -von output.txt file.txt    # Would try: -v -o -n output.txt
                                      # -o captures "n" as argument!
```

**Solution:** Document that options requiring arguments should be:
1. Placed at the end of a bundle
2. Used separately
3. Used with long-form (--output)

### 2. Character Set Validation

The pattern `-[amLpvqVh]*` explicitly lists valid options. This:
- Prevents incorrect disaggregation of unknown options
- Allows unknown options to be caught by the `-*)` case
- Documents which short options are valid

```bash
# Valid options explicitly listed
-[ovnVh]*)  # Only -o -v -n -V -h are valid short options

# If user provides invalid option
./script -xyz  # Doesn't match pattern, caught by -*) case
               # Error: Invalid option '-xyz'
```

### 3. Special Character Handling

Bash parameter expansion handles special characters correctly:

```bash
# These characters work correctly in pure bash method:
# Digits: -123 → -1 -2 -3
# Letters: -abc → -a -b -c
# Mixed: -v1n2 → -v -1 -n -2

# The grep/fold methods also handle these correctly
```

### 4. Empty String After Removal

All three methods use `set -- '' ...` followed by `shift` or explicit removal. This handles the edge case where no options are provided.

### 5. Performance Considerations

For scripts that:
- Process arguments frequently (loops, recursive calls)
- Need to start quickly (interactive tools)
- Run in resource-constrained environments

**Recommendation:** Use pure bash method for 68% performance improvement.

For scripts where:
- Argument parsing happens once at startup
- External command overhead is negligible
- One-liner readability is valued

**Acceptable:** Use grep/fold methods.

## Implementation Checklist

When implementing short-option disaggregation:

- [ ] List all valid short options in pattern: `-[ovnVh]*`
- [ ] Place disaggregation case before `-*)` invalid option case
- [ ] Ensure `shift` happens at end of loop for all cases
- [ ] Document which options can be bundled
- [ ] Warn users about options-with-arguments bundling limitations
- [ ] Add shellcheck disable comment for grep/fold methods
- [ ] Test with: single options, bundled options, mixed long/short
- [ ] Test with: options before/after positional arguments
- [ ] Verify stacking behavior for flags (e.g., `-vvv`)

## Performance Benchmark Script

The following script provides comprehensive performance testing of all three disaggregation methods:

```bash
#!/usr/bin/env bash
# Speed comparison test for option disaggregation methods
# Each test runs for at least 3 seconds
set -euo pipefail

error() { >&2 echo "$(basename -- "$0")" 'error:' "$*"; }

# Test input: 15 random alphanumeric characters
declare -- TEST_INPUT TEST_OUTPUT
TEST_INPUT="-$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c15 || true)"

# Generate expected output from TEST_INPUT
TEST_OUTPUT=()
declare -- opt="${TEST_INPUT:1}"
while ((${#opt})); do
  TEST_OUTPUT+=("-${opt:0:1}")
  opt="${opt:1}"
done

# Method 1: Original (grep)
method_grep() {
  local -- input=${1:1}
  shift
  set -- '' $(printf -- "-%c " $(grep -o . <<<"$input")) "$@"
  shift  # Remove leading empty string
}

# Method 2: fold -w1
method_fold() {
  local -- input=${1:1}
  shift
  set -- '' $(printf -- "-%c " $(fold -w1 <<<"$input")) "$@"
  shift  # Remove leading empty string
}

# Method 3: Pure bash
method_bash() {
  local -- input=$1
  local -- opt=${input:1}
  shift
  local -a new_args=()
  while ((${#opt})); do
    new_args+=("-${opt:0:1}")
    opt=${opt:1}
  done
  set -- "${new_args[@]}" "$@"
}

# Verification function using inline logic
verify_grep() {
  local -a result
  set -- '' $(printf -- "-%c " $(grep -o . <<<"${TEST_INPUT:1}"))
  shift
  result=("$@")

  if [[ "${#result[@]}" -ne "${#TEST_OUTPUT[@]}" ]]; then
    error "grep produced ${#result[@]} args, expected ${#TEST_OUTPUT[@]}"
    return 1
  fi

  local -i i
  for ((i=0; i<${#TEST_OUTPUT[@]}; i+=1)); do
    if [[ "${result[$i]}" != "${TEST_OUTPUT[$i]}" ]]; then
      error "grep arg $i mismatch: '${result[$i]}' != '${TEST_OUTPUT[$i]}'"
      return 1
    fi
  done
  echo "✓ Original (grep) output verified"
}

verify_fold() {
  local -a result
  set -- '' $(printf -- "-%c " $(fold -w1 <<<"${TEST_INPUT:1}"))
  shift
  result=("$@")

  if [[ "${#result[@]}" -ne "${#TEST_OUTPUT[@]}" ]]; then
    error "fold produced ${#result[@]} args, expected ${#TEST_OUTPUT[@]}"
    return 1
  fi

  local -i i
  for ((i=0; i<${#TEST_OUTPUT[@]}; i+=1)); do
    if [[ "${result[$i]}" != "${TEST_OUTPUT[$i]}" ]]; then
      error "fold arg $i mismatch: '${result[$i]}' != '${TEST_OUTPUT[$i]}'"
      return 1
    fi
  done
  echo "✓ Option 1 (fold) output verified"
}

verify_bash() {
  local -- opt=${TEST_INPUT:1}
  local -a result=()
  while ((${#opt})); do
    result+=("-${opt:0:1}")
    opt=${opt:1}
  done

  if [[ "${#result[@]}" -ne "${#TEST_OUTPUT[@]}" ]]; then
    error "pure bash produced ${#result[@]} args, expected ${#TEST_OUTPUT[@]}"
    return 1
  fi

  local -i i
  for ((i=0; i<${#TEST_OUTPUT[@]}; i+=1)); do
    if [[ "${result[$i]}" != "${TEST_OUTPUT[$i]}" ]]; then
      error "pure bash arg $i mismatch: '${result[$i]}' != '${TEST_OUTPUT[$i]}'"
      return 1
    fi
  done
  echo "✓ Option 3 (pure bash) output verified"
}

# Test runner function
run_test() {
  local -- method_name=$1
  local -- method_func=$2

  echo "Testing: $method_name"
  echo "----------------------------------------"

  # Calculate iterations needed
  local -i iterations=0
  local -- current_time='' elapsed=''
  local -- start_time="${EPOCHREALTIME}"

  # Warm-up and calibration run
  while ((1)); do
    $method_func "$TEST_INPUT" arg1 arg2 arg3 >/dev/null 2>&1
    iterations+=1

    current_time="${EPOCHREALTIME}"
    elapsed=$(awk "BEGIN {print $current_time - $start_time}")

    # Check if we've exceeded 3 seconds
    if (( $(awk "BEGIN {print ($elapsed >= 3.0)}") )); then
      break
    fi
  done

  echo "Iterations: $iterations"
  echo "Elapsed time: ${elapsed}s"
  echo "Iterations/sec: $(awk "BEGIN {printf \"%.2f\", $iterations / $elapsed}")"
  echo ""
}

# Main test execution
echo "========================================"
echo "Option Disaggregation Speed Test"
echo "========================================"
echo "Test input: $TEST_INPUT (${#TEST_INPUT} chars, $((${#TEST_INPUT} - 1)) options)"
echo "Minimum test duration: 3.0000 seconds"
echo ""

# Source timer for use
source timer 2>/dev/null || {
  error 'timer not found or cannot be sourced'
  exit 1
}

# Verify all methods produce correct output
echo "Verifying method correctness..."
echo "Expected output: ${TEST_OUTPUT[*]}"
echo
verify_grep || exit 1
verify_fold || exit 1
verify_bash || exit 1
echo

# Run tests
timer -f bash -c "$(declare -f method_grep run_test); run_test 'Original (grep)' method_grep"
timer -f bash -c "$(declare -f method_fold run_test); run_test 'Option 1 (fold)' method_fold"
timer -f bash -c "$(declare -f method_bash run_test); run_test 'Option 3 (pure bash)' method_bash"

echo "========================================"
echo "Test complete"
echo "========================================"

#fin
```

### Running the Benchmark

```bash
# Save as speedtest.sh and make executable
chmod +x speedtest.sh

# Run the benchmark
./speedtest.sh
```

### Sample Output

```
========================================
Option Disaggregation Speed Test
========================================
Test input: -sJD2Vle76LlfR2J (16 chars, 15 options)
Minimum test duration: 3.0000 seconds

Verifying method correctness...
Expected output: -s -J -D -2 -V -l -e -7 -6 -L -l -f -R -2 -J

✓ Original (grep) output verified
✓ Option 1 (fold) output verified
✓ Option 3 (pure bash) output verified

Testing: Original (grep)
----------------------------------------
Iterations: 573
Elapsed time: 3.00276s
Iterations/sec: 190.82

Testing: Option 1 (fold)
----------------------------------------
Iterations: 586
Elapsed time: 3.00123s
Iterations/sec: 195.25

Testing: Option 3 (pure bash)
----------------------------------------
Iterations: 954
Elapsed time: 3.00239s
Iterations/sec: 317.75

========================================
Test complete
========================================
```

## Recommendations

### For New Scripts

**Use Pure Bash Method (Method 3)**

Reasons:
- 68% performance improvement over grep/fold
- No external dependencies
- No shellcheck warnings
- More portable across environments
- Future-proof (doesn't rely on external command availability)

Trade-off:
- Slightly more verbose (6 lines vs 1 line)
- Slightly more complex logic

**Implementation:**
```bash
-[ovnVh]*)   # Split up single options (pure bash)
              opt=${1:1}
              new_args=()
              while ((${#opt})); do
                new_args+=("-${opt:0:1}")
                opt=${opt:1}
              done
              set -- '' "${new_args[@]}" "${@:2}" ;;
```

### For Existing Scripts

**Keep Current Method (grep) Unless:**
1. Performance is critical
2. Script is called frequently
3. External dependencies are a concern
4. Running in restricted environment

**Migration Path:**
1. Run benchmarks in your environment
2. If performance matters, migrate to pure bash
3. Update tests to verify bundled options still work
4. Document the change in commit message

### For High-Performance Scripts

**Always Use Pure Bash Method**

Scripts that should prioritize performance:
- Called in tight loops
- Part of build systems
- Interactive tools (tab completion, prompts)
- Running in containers/restricted environments
- Called thousands of times per session

## Testing Your Implementation

### Basic Functionality Test

```bash
# Test single options
./script -v -v -n file.txt

# Test bundled options
./script -vvn file.txt

# Test mixed
./script -v --verbose -n file.txt

# Test with arguments
./script -vno output.txt file.txt

# Test invalid options
./script -xyz  # Should error

# Test option stacking
./script -vvvvv  # VERBOSE should be 5
```

### Automated Test Suite

```bash
#!/usr/bin/env bash
# test-option-bundling.sh

test_bundling() {
  local -- description=$1
  shift
  echo "Testing: $description"

  # Run your script with provided arguments
  output=$(./your-script "$@" 2>&1)

  # Verify output matches expectations
  # Add your verification logic here

  echo "  ✓ Passed"
}

# Test cases
test_bundling "Single options" -v -v -n file.txt
test_bundling "Bundled options" -vvn file.txt
test_bundling "Mixed long/short" -v --verbose -n file.txt
test_bundling "Options with args" -vno output.txt file.txt

echo "All tests passed!"
```

## Conclusion

Short-option disaggregation is essential for creating user-friendly command-line tools that follow Unix conventions. While all three methods produce identical results, the pure bash method offers significant performance advantages with no external dependencies.

**Summary:**
- **grep method:** Current standard, external dependency, ~190 iter/sec
- **fold method:** Marginal improvement, external dependency, ~195 iter/sec
- **Pure bash:** Recommended, no dependencies, ~318 iter/sec (68% faster)

Choose based on your script's requirements, but prefer pure bash for new development.

#fin
