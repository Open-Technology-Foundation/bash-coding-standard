# Testing Guide for symlink

This document describes the comprehensive test suite for the `symlink` script.

## Overview

The test suite provides extensive coverage of all `symlink` functionality with 97 organized test cases covering:

- Option parsing and validation
- Single file symlinking operations
- Dry-run mode behavior
- Broken symlink cleanup
- .symlink file processing and scanning
- Path resolution
- Critical file protection
- Debug mode functionality
- Exit code validation
- Edge cases and error conditions
- Integration workflows

## Test Architecture

### Components

The test suite consists of three main components:

#### 1. **test-harness**
Custom BCS-compliant test framework providing:
- Test registration and execution
- Setup/teardown lifecycle hooks
- Rich assertion library
- Color-coded output
- Summary reporting
- Test isolation

#### 2. **test-helpers**
Utility library with:
- Test environment setup/cleanup
- Mock file creation functions
- .symlink file generators
- Custom assertions for symlink testing
- Command execution helpers

#### 3. **test-symlink**
Comprehensive test suite with all test cases organized by feature area.

## Prerequisites

### Required
- **Root access or sudo privileges** - The test suite requires `sudo` to test actual symlink creation in target directories
- **Bash 5.2+** - Required for BCS compliance
- **Standard Unix utilities** - `realpath`, `stat`, `find`, `readlink`

### Recommended
- **shellcheck** - For validating test scripts (optional)

## Running the Tests

### Basic Execution

Run all tests with sudo:

```bash
sudo ./test-symlink
```

### Expected Output

The test harness will display:
- Progress for each test (✓ passed, ✗ failed, ▲ skipped)
- Detailed failure messages for failed tests
- Summary with counts and statistics

Example output:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Running 97 test(s)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Help flag (short)
✓ Help flag (long)
✓ Version flag (short)
✓ Version flag (long)
...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Test Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total:   97
Passed:  97
Failed:  0
Skipped: 0

✓ All tests passed!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Test Organization

Tests are organized into the following categories:

### 1. Option Parsing Tests (20 tests)
- No arguments (shows help, exits 1)
- Help output contains all sections
- Help and version flags (short/long)
- Invalid option handling
- Dry-run mode flags
- Target directory specification
- Verbose/quiet flags and output verification
- No-prompt flag
- Aggregated short options
- List and scan mode flags
- Delete broken symlinks flag

### 2. Single File Symlinking Tests (9 tests)
- Creating new symlinks
- Custom symlink names
- Skipping existing identical symlinks
- Replacing different symlinks
- Replacing regular files
- Error handling for:
  - Nonexistent source files
  - Non-executable source files
  - Source directories
  - Nonexistent target directories

### 3. Dry-Run Mode Tests (4 tests)
- New symlink preview
- Existing symlink preview
- Replace symlink preview
- Nonexistent source handling

### 4. Broken Symlink Cleanup Tests (4 tests)
- Deleting single broken symlink
- Deleting multiple broken symlinks
- Preserving valid symlinks
- Dry-run preview of cleanup

### 5. .symlink File Processing Tests (17 tests)
- Scanning single .symlink file
- Custom names in .symlink files
- Comment handling
- Blank line handling
- Inline comment handling
- Inline comments with custom name
- Multiple link names per entry
- Multiple link names with inline comment
- Indented comments
- Nested .symlink file discovery
- Max depth enforcement
- List mode display
- List mode nested directories
- No files found error
- Subdirectory source paths
- Critical file skipped in scan mode
- Critical file dry-run skip in scan mode

### 6. Path Resolution Tests (3 tests)
- Relative path resolution
- Paths with spaces
- Symlink-to-executable following

### 7. Critical File Protection Tests (4 tests)
- Protection for bash, sh, sudo
- Force override with environment variable

### 8. Debug Mode Tests (4 tests)
- Debug flag trace file creation
- Debug via environment variable
- Debug trace file content verification
- Symlink owner matches source file

### 9. Exit Code Tests (5 tests)
- Success (0)
- File not found (3)
- Invalid option (22)
- No .symlink files (50)
- Target dir requires argument (22)

### 10. Edge Cases Tests (9 tests)
- Empty custom names
- Scripts without extensions
- Hidden files
- Multiple files in one command
- Windows line endings in .symlink files
- Escaped spaces in .symlink source paths
- Escaped space with custom name
- Escaped space in directory path
- Multiple escaped spaces

### 11. Integration Workflow Tests (3 tests)
- Admin full scan workflow
- Developer preview workflow
- Debug comprehensive workflow

### 12. Summary Reporting Tests (3 tests)
- Created count display
- Skipped count display
- Dry-run format

## Test Environment

### Isolation

Each test runs in an isolated environment:
- Temporary directory structure created per test
- Separate source and target directories
- Automatic cleanup after each test
- No pollution between tests

### Directory Structure

For each test:
```
/tmp/symlink-test-XXXXXX/          # Test root
├── source/                         # Mock source scripts
├── target/                         # Mock target directory
└── work/                          # Working directory
```

### Safety

- Tests **never** modify `/usr/local/bin` or other system directories
- All operations are performed in temporary test directories
- Cleanup is automatic even on test failures
- Root access is used only for testing sudo elevation

## Assertions Available

The test harness provides the following assertions:

### General Assertions
- `assert_equals <expected> <actual> [message]`
- `assert_not_equals <not_expected> <actual> [message]`
- `assert_empty <value> [message]`
- `assert_not_empty <value> [message]`

### Command Assertions
- `assert_success <command...>`
- `assert_failure <command...>`
- `assert_exit_code <code> <command...>`

### File Assertions
- `assert_file_exists <path> [message]`
- `assert_file_not_exists <path> [message]`
- `assert_executable <path> [message]`
- `assert_file_owner <path> <owner>`
- `assert_file_perms <path> <perms>`

### Symlink Assertions
- `assert_symlink <path> [message]`
- `assert_symlink_to <symlink> <target> [message]`
- `assert_symlink_created <name>` (in TEST_TARGET_DIR)
- `assert_symlink_points_to <name> <source>`
- `assert_symlink_count <directory> <count>`
- `assert_broken_symlink <path>`

### String Assertions
- `assert_contains <string> <substring> [message]`
- `assert_matches <string> <pattern> [message]`
- `assert_output_contains <text>` (checks TEST_OUTPUT)
- `assert_output_not_contains <text>` (checks TEST_OUTPUT)

### Test Control
- `skip [reason]` - Skip current test
- `fail <message>` - Manually fail current test

## Adding New Tests

### 1. Define Test Function

```bash
test_my_new_feature() {
  # Arrange - set up test environment
  local -r test_script="${TEST_SOURCE_DIR}/test.sh"
  create_mock_executable "${test_script}"

  # Act - run the command
  run_symlink_sudo -P -t "${TEST_TARGET_DIR}" "${test_script}"

  # Assert - verify results
  assert_symlink_created "test.sh"
  assert_exit_code 0 echo "${TEST_EXIT_CODE}"
}
```

### 2. Register Test

```bash
test "My new feature description" test_my_new_feature
```

### 3. Test Naming Conventions

- Function names: `test_<feature>_<scenario>`
- Use underscores, not hyphens
- Be descriptive but concise
- Examples:
  - `test_create_new_symlink`
  - `test_dry_run_existing_symlink`
  - `test_scan_nested_symlink_files`

### 4. Test Structure

Follow the Arrange-Act-Assert pattern:

```bash
test_example() {
  # Arrange: Set up test data
  local -r test_file="${TEST_SOURCE_DIR}/example.sh"
  create_mock_executable "${test_file}"

  # Act: Execute the function under test
  run_symlink_sudo -P -t "${TEST_TARGET_DIR}" "${test_file}"

  # Assert: Verify expected outcomes
  assert_symlink_created "example.sh"
  assert_equals "0" "${TEST_EXIT_CODE}"
}
```

## Helper Functions

### Environment Setup
- `setup_test_env()` - Creates isolated test directories (automatic)
- `cleanup_test_env()` - Removes test artifacts (automatic)

### Mock Creation
- `create_mock_executable <path> [content]` - Create executable file
- `create_mock_file <path> [content]` - Create regular file
- `create_mock_symlink <link> <target>` - Create symlink
- `create_broken_symlink <path>` - Create broken symlink
- `create_mock_directory <path>` - Create directory
- `create_mock_file_with_perms <path> <perms>` - File with permissions
- `create_mock_file_with_owner <path> <owner> [group]` - File with owner

### .symlink File Creation
- `create_symlink_file <path> <entries...>` - Create .symlink file
- `create_complex_symlink_file <path>` - Create with comments/blanks

### Command Execution
- `run_symlink <args...>` - Run symlink, capture output/exit code
- `run_symlink_sudo <args...>` - Run with sudo

Sets:
- `TEST_OUTPUT` - Captured stdout/stderr
- `TEST_EXIT_CODE` - Exit code of command

### Utilities
- `is_root()` - Check if running as root
- `has_sudo()` - Check if sudo is available
- `count_files <directory>` - Count files in directory
- `create_nested_dirs <base> <depth>` - Create nested structure

## Troubleshooting

### Permission Errors

If you see permission errors:
```bash
ERROR: This test suite requires root access or sudo privileges
Please run with: sudo ./test-symlink
```

**Solution**: Run with sudo:
```bash
sudo ./test-symlink
```

### Failed Tests

When tests fail, the output will show:
- Which test failed
- The specific assertion that failed
- Expected vs actual values

Example:
```
✗ Create new symlink
  FAIL: File does not exist: /tmp/symlink-test-abc123/target/test.sh
```

**Debugging**:
1. Check the specific assertion message
2. Review the test function code
3. Run symlink manually with similar arguments
4. Check for recent changes to the symlink script

### Cleanup Issues

If tests leave artifacts:
- Check for `trap` in test-helpers
- Ensure `cleanup_test_env()` is called
- Manually remove: `rm -rf /tmp/symlink-test-*`

### Debug Mode

To see detailed trace during test execution:
- Tests automatically use debug mode when symlink is run with `--debug`
- Check `/tmp/symlink-trace-*` files for detailed logs

## Coverage

Current test coverage:

| Area | Test Count | Coverage |
|------|------------|----------|
| Option Parsing | 20 | Comprehensive |
| File Operations | 11 | Comprehensive |
| Dry-Run Mode | 4 | Complete |
| Broken Symlinks | 4 | Complete |
| .symlink Processing | 17 | Comprehensive |
| Path Resolution | 3 | Core cases |
| Critical Files (incl. pty prompts) | 8 | Complete |
| Debug Mode | 4 | Comprehensive |
| PATH-shadow Advisory | 2 | Core cases |
| Containment / Security | 4 | Core cases |
| Exit Codes | 5 | Key codes |
| Edge Cases | 9 | Common cases |
| Integration | 3 | Key workflows |
| Summary | 3 | Core cases |
| **Total** | **97** | **High** |

### Not Yet Covered

Additional tests that could be added:
- Interactive prompting (requires TTY simulation)
- All 53 critical files individually
- Performance tests with large file sets
- Concurrent execution scenarios
- Network filesystem edge cases
- Unicode and special character edge cases
- All permission combinations
- Signal handling (SIGINT, SIGTERM)

## Contributing

When adding tests:

1. Follow BCS (Bash Coding Standard)
2. Use 2-space indentation
3. Add meaningful assertions
4. Include descriptive test names
5. Group related tests together
6. Update this README if adding new categories

## Best Practices

### Do's
- ✓ Use isolated test environments
- ✓ Clean up after tests
- ✓ Test one thing per test
- ✓ Use descriptive names
- ✓ Include edge cases
- ✓ Test error conditions
- ✓ Verify exit codes

### Don'ts
- ✗ Don't modify system directories
- ✗ Don't rely on test execution order
- ✗ Don't leave test artifacts
- ✗ Don't skip cleanup
- ✗ Don't assume sudo without checking
- ✗ Don't test multiple features in one test

## Files

| File | Purpose | Lines |
|------|---------|-------|
| `test-harness` | Test framework | ~510 |
| `test-helpers` | Test utilities | ~423 |
| `test-symlink` | Test suite | ~1267 |
| `README-TESTING.md` | Documentation | This file |

## License

GPL-3.0 (same as symlink)

## Support

For issues with the test suite:
1. Check this README
2. Review test-harness and test-helpers code
3. Run tests with verbose output
4. Check /tmp/symlink-trace-* debug logs
5. File an issue with test output

---

**Last Updated**: 2026-03-08
**Test Suite Version**: 1.0.0
**symlink Version**: 1.4.0
