# bash-coding-standard Test Suite

Comprehensive test suite for the `bash-coding-standard` script covering all execution paths, argument combinations, and environment conditions.

## Test Structure

```
tests/
├── README.md                    # This file
├── run-all-tests.sh            # Main test runner
├── test-helpers.sh             # Assertion functions and test utilities
├── test-find-bcs-file.sh       # Tests for find_bcs_file() function
├── test-argument-parsing.sh    # Tests for all command-line arguments
├── test-execution-modes.sh     # Tests for direct execution vs sourcing
└── test-environment.sh         # Tests for environment conditions
```

## Running Tests

### Run All Tests

```bash
./tests/run-all-tests.sh
```

### Run Individual Test Suite

```bash
./tests/test-argument-parsing.sh
./tests/test-find-bcs-file.sh
./tests/test-execution-modes.sh
./tests/test-environment.sh
```

## Test Coverage

### test-find-bcs-file.sh
Tests the `find_bcs_file()` function:
- Finding file in current directory
- Finding file in standard FHS locations
- Handling nonexistent paths
- Search path order
- Output format validation
- Edge cases (empty paths)

### test-argument-parsing.sh
Tests all command-line argument combinations:
- **Help options**: `-h`, `--help`
- **Cat options**: `-c`, `--cat`, `-` (dash)
- **Bash declare option**: `-b`, `--bash`
- **md2ansi option**: `-a`, `--md2ansi`
- **Short option bundling**: `-hc`, `-cb`, `-ba`, `-hcba`, etc.
- **Viewer arguments passthrough**: Passing extra args to cat/md2ansi
- **Invalid options**: Error handling for unknown options
- **No arguments**: Default behavior
- **Option order**: Priority of conflicting options

### test-execution-modes.sh
Tests both execution modes:
- **Direct execution**:
  - Script runs successfully
  - `set -euo pipefail` is active
  - `shopt` settings are enabled
  - Error handling works correctly
  - Script metadata is set (BCS_PATH, BCS_FILE)

- **Sourced mode**:
  - Variables are set correctly (BCS_FILE, BCS_PATH, BCS_MD)
  - BCS_MD is pre-loaded with content
  - `display_BCS` function is available and exported
  - `find_bcs_file` function is available
  - Variables are global (`-gx` flag)

- **Mode differences**:
  - Direct execution uses `set -euo pipefail`
  - Sourced mode doesn't affect parent shell
  - Both modes can find files correctly

- **Error handling**:
  - Direct execution exits on invalid args
  - `display_BCS` function returns error codes

### test-environment.sh
Tests environment conditions and edge cases:
- **Terminal detection**:
  - Output to pipe
  - Output redirection
  - No terminal available

- **md2ansi availability**:
  - Script behavior with md2ansi installed
  - Fallback to cat when md2ansi unavailable
  - `--md2ansi` flag behavior
  - `--cat` bypasses md2ansi

- **File not found**:
  - Script in wrong location
  - Error reporting
  - Sourcing when file not found

- **Variable initialization**:
  - BCS_MD population
  - BCS_PATH and BCS_FILE correctness
  - Variable persistence

- **I/O handling**:
  - STDIN doesn't interfere
  - Errors go to STDERR
  - Help goes to STDOUT

- **Edge cases**:
  - Spaces in file paths
  - Special characters
  - Empty stdin

## Test Helpers

The `test-helpers.sh` library provides:

### Assertion Functions
- `assert_equals expected actual [test_name]` - Assert two strings are equal
- `assert_contains haystack needle [test_name]` - Assert string contains substring
- `assert_not_contains haystack needle [test_name]` - Assert string doesn't contain substring
- `assert_exit_code expected actual [test_name]` - Assert exit code matches
- `assert_file_exists file [test_name]` - Assert file exists
- `assert_success exit_code [test_name]` - Assert exit code is 0
- `assert_failure exit_code [test_name]` - Assert exit code is non-zero

### Utility Functions
- `test_section "Section Name"` - Print test section header
- `print_summary` - Print test results summary

### Test Counters
- `TESTS_RUN` - Total number of tests run
- `TESTS_PASSED` - Number of tests passed
- `TESTS_FAILED` - Number of tests failed
- `FAILED_TESTS` - Array of failed test names

## Writing New Tests

To add a new test file:

1. Create `test-<name>.sh` in the `tests/` directory
2. Follow this template:

```bash
#!/usr/bin/env bash
# Description of test suite

set -euo pipefail

# Load test helpers
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

SCRIPT="$SCRIPT_DIR"/../bash-coding-standard

test_feature_one() {
  test_section "Feature One Tests"

  # Your tests here
  local -- output
  output=$("$SCRIPT" --option 2>&1)
  assert_contains "$output" "expected" "Test description"
}

test_feature_two() {
  test_section "Feature Two Tests"

  # More tests
}

# Run all tests
test_feature_one
test_feature_two

print_summary

#fin
```

3. Make it executable: `chmod +x tests/test-<name>.sh`
4. Run it individually or via `run-all-tests.sh`

## Test Permutations Covered

### Command-Line Options (All Combinations)
- Single options: `-h`, `-c`, `-b`, `-a`
- Long options: `--help`, `--cat`, `--bash`, `--md2ansi`
- Short bundled options: All combinations of `-hcba`
- With viewer args: `-c -n`, `--cat --number`, etc.
- Invalid options: Unknown flags, non-option arguments

### Execution Contexts
- Direct execution (script mode)
- Sourced mode (library mode)
- With terminal (TTY)
- Without terminal (pipe/redirect)
- With md2ansi available
- Without md2ansi available

### File Locations
- Same directory as script (development)
- `/usr/local/share/yatti/bash-coding-standard/` (local install)
- `/usr/share/yatti/bash-coding-standard/` (system install)
- File not found (error condition)

### Environment Variations
- Standard paths
- Paths with spaces
- Empty stdin
- Piped output
- Redirected output

## Exit Codes

Tests follow standard exit codes:
- `0` - All tests passed
- `1` - One or more tests failed
- `2` - Test suite error (e.g., missing dependencies)

## Requirements

- Bash 5.2+
- Standard POSIX utilities (grep, find, head, etc.)
- Optional: md2ansi (for md2ansi-related tests)

## License

Same license as bash-coding-standard (CC BY-SA 4.0)
