#!/usr/bin/env bash
# Tests for bcs template subcommand
set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Load test helpers
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR"/test-helpers.sh

SCRIPT="$SCRIPT_DIR"/../bash-coding-standard

# Test help output
test_template_help() {
  test_section "Template Help Tests"
  local -- output
  output=$("$SCRIPT" template --help 2>&1)

  assert_contains "$output" "Usage:" "template --help shows usage"
  assert_contains "$output" "bcs template" "Help mentions template command"
  assert_contains "$output" "--type" "Help shows --type option"
  assert_contains "$output" "--name" "Help shows --name option"
  assert_contains "$output" "--description" "Help shows --description option"
  assert_contains "$output" "--version" "Help shows --version option"
  assert_contains "$output" "--output" "Help shows --output option"
  assert_contains "$output" "--executable" "Help shows --executable option"
  assert_contains "$output" "--force" "Help shows --force option"
  assert_contains "$output" "minimal" "Help mentions minimal template"
  assert_contains "$output" "basic" "Help mentions basic template"
  assert_contains "$output" "complete" "Help mentions complete template"
  assert_contains "$output" "library" "Help mentions library template"
}

# Test basic template generation (stdout)
test_template_basic() {
  test_section "Basic Template Output Tests"
  local -- output

  # Default (basic) template
  output=$("$SCRIPT" template 2>&1)
  assert_contains "$output" "#!/usr/bin/env bash" "Basic template has shebang"
  assert_contains "$output" "set -euo pipefail" "Basic template has set -e"
  assert_contains "$output" "VERSION='1.0.0'" "Basic template has VERSION"
  assert_contains "$output" "SCRIPT_PATH" "Basic template has SCRIPT_PATH"
  assert_contains "$output" "main()" "Basic template has main function"
  assert_contains "$output" "#fin" "Basic template has fin marker"

  # With name
  output=$("$SCRIPT" template -n myapp 2>&1)
  assert_contains "$output" "Hello from myapp" "Template substitutes NAME"
}

# Test minimal template
test_template_minimal() {
  test_section "Minimal Template Tests"
  local -- output
  output=$("$SCRIPT" template -t minimal 2>&1)

  assert_contains "$output" "#!/usr/bin/env bash" "Minimal has shebang"
  assert_contains "$output" "set -euo pipefail" "Minimal has set -e"
  assert_contains "$output" "error()" "Minimal has error function"
  assert_contains "$output" "die()" "Minimal has die function"
  assert_contains "$output" "main()" "Minimal has main function"
  assert_contains "$output" "#fin" "Minimal has fin marker"
  assert_not_contains "$output" "VERSION=" "Minimal does not have VERSION"
}

# Test complete template
test_template_complete() {
  test_section "Complete Template Tests"
  local -- output
  output=$("$SCRIPT" template -t complete 2>&1)

  assert_contains "$output" "#!/usr/bin/env bash" "Complete has shebang"
  assert_contains "$output" "set -euo pipefail" "Complete has set -e"
  assert_contains "$output" "VERSION=" "Complete has VERSION"
  assert_contains "$output" "VERBOSE=" "Complete has VERBOSE"
  assert_contains "$output" "DEBUG=" "Complete has DEBUG"
  assert_contains "$output" "GREEN=" "Complete has colors"
  assert_contains "$output" "vecho()" "Complete has vecho"
  assert_contains "$output" "success()" "Complete has success"
  assert_contains "$output" "warn()" "Complete has warn"
  assert_contains "$output" "info()" "Complete has info"
  assert_contains "$output" "debug()" "Complete has debug"
  assert_contains "$output" "yn()" "Complete has yn"
  assert_contains "$output" "show_help()" "Complete has show_help"
  assert_contains "$output" "parse_args()" "Complete has parse_args"
  assert_contains "$output" "#fin" "Complete has fin marker"
}

# Test library template
test_template_library() {
  test_section "Library Template Tests"
  local -- output
  output=$("$SCRIPT" template -t library -n mylib 2>&1)

  assert_contains "$output" "#!/usr/bin/env bash" "Library has shebang"
  assert_contains "$output" "This is a sourceable library script" "Library has comment"
  assert_contains "$output" "declare -x mylib_VERSION" "Library has prefixed VERSION"
  assert_contains "$output" "mylib_PATH" "Library has prefixed PATH"
  assert_contains "$output" "mylib_msg()" "Library has prefixed msg function"
  assert_contains "$output" "declare -fx mylib_msg" "Library exports msg function"
  assert_contains "$output" "mylib_error()" "Library has prefixed error function"
  assert_contains "$output" "mylib_hello()" "Library has example function"
  assert_contains "$output" "mylib_init()" "Library has init function"
  assert_contains "$output" "#fin" "Library has fin marker"
  assert_not_contains "$output" "set -euo pipefail" "Library does not have set -e"
}

# Test placeholder substitution
test_template_placeholders() {
  test_section "Placeholder Substitution Tests"
  local -- output

  # Test NAME substitution
  output=$("$SCRIPT" template -n testscript 2>&1)
  assert_contains "$output" "Hello from testscript" "NAME placeholder substituted"

  # Test DESCRIPTION substitution
  output=$("$SCRIPT" template -d "My test script" 2>&1)
  assert_contains "$output" "# My test script" "DESCRIPTION placeholder substituted"

  # Test VERSION substitution
  output=$("$SCRIPT" template -v "2.5.0" 2>&1)
  assert_contains "$output" "VERSION='2.5.0'" "VERSION placeholder substituted"

  # Test all together
  output=$("$SCRIPT" template -n myapp -d "My Application" -v "3.0.0" 2>&1)
  assert_contains "$output" "# My Application" "All placeholders work together 1"
  assert_contains "$output" "VERSION='3.0.0'" "All placeholders work together 2"
  assert_contains "$output" "Hello from myapp" "All placeholders work together 3"
}

# Test file output
test_template_file_output() {
  test_section "File Output Tests"
  local -- test_file="/tmp/bcs-test-$$-output.sh"
  local -- output

  # Clean up any existing file
  rm -f "$test_file"

  # Create file
  output=$("$SCRIPT" template -t minimal -o "$test_file" 2>&1)
  assert_contains "$output" "Generated minimal template" "Output message shown"
  assert_file_exists "$test_file" "Output file created"

  # Verify content
  local -- content
  content=$(cat "$test_file")
  assert_contains "$content" "#!/usr/bin/env bash" "File has correct content"
  assert_contains "$content" "#fin" "File has fin marker"

  # Clean up
  rm -f "$test_file"
}

# Test executable flag
test_template_executable() {
  test_section "Executable Flag Tests"
  local -- test_file="/tmp/bcs-test-$$-exec.sh"
  local -- output

  # Clean up any existing file
  rm -f "$test_file"

  # Create file with -x flag
  output=$("$SCRIPT" template -o "$test_file" -x 2>&1)
  assert_contains "$output" "Made executable" "Executable message shown"
  assert_file_exists "$test_file" "File created"

  # Check if executable
  if [[ -x "$test_file" ]]; then
    pass "File is executable"
  else
    fail "File should be executable"
  fi

  # Clean up
  rm -f "$test_file"
}

# Test force overwrite
test_template_force_overwrite() {
  test_section "Force Overwrite Tests"
  local -- test_file="/tmp/bcs-test-$$-force.sh"
  local -- output exit_code

  # Clean up any existing file
  rm -f "$test_file"

  # Create initial file
  "$SCRIPT" template -o "$test_file" >/dev/null 2>&1
  assert_file_exists "$test_file" "Initial file created"

  # Try to overwrite without force (should fail)
  output=$("$SCRIPT" template -o "$test_file" 2>&1) && exit_code=0 || exit_code=$?
  assert_not_zero $exit_code "Fails without --force flag"
  assert_contains "$output" "already exists" "Error message mentions file exists"
  assert_contains "$output" "--force" "Error message suggests --force"

  # Overwrite with force (should succeed)
  output=$("$SCRIPT" template -o "$test_file" -f 2>&1) && exit_code=0 || exit_code=$?
  assert_zero $exit_code "Succeeds with --force flag"
  assert_contains "$output" "Generated" "Success message shown"

  # Clean up
  rm -f "$test_file"
}

# Test error handling
test_template_errors() {
  test_section "Error Handling Tests"
  local -- output exit_code

  # Invalid template type
  output=$("$SCRIPT" template -t invalid 2>&1) && exit_code=0 || exit_code=$?
  assert_not_zero $exit_code "Invalid template type fails"
  assert_contains "$output" "Invalid template type" "Error message for invalid type"
  assert_contains "$output" "minimal, basic, complete, library" "Error shows valid types"
}


# Test exit codes
test_template_exit_codes() {
  test_section "Exit Code Tests"
  local -- exit_code test_file="/tmp/bcs-test-$$-exitcode.sh"

  # Clean up
  rm -f "$test_file"

  # Success case
  "$SCRIPT" template -o "$test_file" >/dev/null 2>&1 && exit_code=0 || exit_code=$?
  assert_zero $exit_code "Success returns 0"

  # Help returns 0
  "$SCRIPT" template --help >/dev/null 2>&1 && exit_code=0 || exit_code=$?
  assert_zero $exit_code "Help returns 0"

  # Invalid option returns non-zero
  "$SCRIPT" template --invalid >/dev/null 2>&1 && exit_code=0 || exit_code=$?
  assert_not_zero $exit_code "Invalid option returns non-zero"

  # Invalid type returns non-zero
  "$SCRIPT" template -t invalid >/dev/null 2>&1 && exit_code=0 || exit_code=$?
  assert_not_zero $exit_code "Invalid type returns non-zero"

  # Clean up
  rm -f "$test_file"
}

# Test script name inference
test_template_name_inference() {
  test_section "Name Inference Tests"
  local -- test_file="/tmp/myinferredscript.sh"
  local -- content

  # Clean up
  rm -f "$test_file"

  # Create file without explicit name
  "$SCRIPT" template -o "$test_file" >/dev/null 2>&1
  content=$(cat "$test_file")

  # Should infer name from filename
  assert_contains "$content" "Hello from myinferredscript" "Name inferred from output filename"

  # Clean up
  rm -f "$test_file"
}

# Run all tests
test_template_help
test_template_basic
test_template_minimal
test_template_complete
test_template_library
test_template_placeholders
test_template_file_output
test_template_executable
test_template_force_overwrite
test_template_errors
test_template_exit_codes
test_template_name_inference

# Print summary
test_summary
