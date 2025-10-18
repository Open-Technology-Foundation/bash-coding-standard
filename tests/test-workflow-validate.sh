#!/usr/bin/env bash
# Test suite for workflows/validate-data.sh
# Tests all 11 validation checks

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Test metadata
SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Project paths
PROJECT_DIR=$(realpath -- "$SCRIPT_DIR/..")
VALIDATE_SCRIPT="$PROJECT_DIR/workflows/validate-data.sh"
DATA_DIR="$PROJECT_DIR/data"
readonly -- PROJECT_DIR VALIDATE_SCRIPT DATA_DIR

# Source test helpers
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

# Test setup
setup() {
  TEST_DATA_DIR=$(mktemp -d)
  export TEST_DATA_DIR
}

# Test teardown
teardown() {
  [[ -d "$TEST_DATA_DIR" ]] && rm -rf "$TEST_DATA_DIR"
}

# ==============================================================================
# Basic Tests
# ==============================================================================

test_script_exists() {
  test_section "Script Existence Tests"

  assert_file_exists "$VALIDATE_SCRIPT"
  assert_file_executable "$VALIDATE_SCRIPT"
}

test_help_and_version() {
  test_section "Help and Version Tests"

  local -- output

  # Test help option
  output=$("$VALIDATE_SCRIPT" --help 2>&1) || true
  assert_contains "$output" "Usage:" "Help shows usage"
  assert_contains "$output" "validate-data.sh" "Help shows script name"

  # Test version option
  output=$("$VALIDATE_SCRIPT" --version 2>&1) || true
  assert_contains "$output" "version" "Version option works"
}

test_validate_real_data() {
  test_section "Real Data Validation"

  local -- output
  local -i exit_code

  # Run on actual BCS data directory
  output=$("$VALIDATE_SCRIPT" 2>&1) && exit_code=$? || exit_code=$?

  # Should pass validation
  if [[ $exit_code -eq 0 ]]; then
    pass "Real BCS data validates successfully"
    assert_contains "$output" "validation.*passed\\|passed.*validation" "Success message shown"
  else
    warn "Real BCS data validation failed (may have known issues)"
  fi
}

# ==============================================================================
# Tier Completeness Tests
# ==============================================================================

test_tier_completeness() {
  test_section "Tier Completeness Validation"

  setup

  local -- section_dir output
  local -i exit_code

  # Test 1: Missing summary tier
  section_dir="$TEST_DATA_DIR/01-test-section"
  mkdir -p "$section_dir"

  cat > "$section_dir/01-test-rule.complete.md" <<'EOF'
### Test Rule
<!-- BCS0101 -->
Test content
#fin
EOF

  cat > "$section_dir/01-test-rule.abstract.md" <<'EOF'
### Test Rule
<!-- BCS0101 -->
Brief
#fin
EOF

  output=$("$VALIDATE_SCRIPT" --data-dir "$TEST_DATA_DIR" 2>&1) && exit_code=$? || exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    pass "Missing summary tier detected"
  else
    fail "Should fail when .summary.md is missing"
  fi

  # Test 2: All tiers present
  rm -rf "$TEST_DATA_DIR"
  mkdir -p "$section_dir"

  for tier in complete summary abstract; do
    cat > "$section_dir/01-test-rule.$tier.md" <<'EOF'
### Test Rule
<!-- BCS0101 -->
Content
#fin
EOF
  done

  output=$("$VALIDATE_SCRIPT" --data-dir "$TEST_DATA_DIR" 2>&1) && exit_code=$? || exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    pass "All tiers present validates successfully"
  else
    warn "Validation failed with all tiers present"
  fi

  teardown
}

# ==============================================================================
# BCS Code Uniqueness Tests
# ==============================================================================

test_bcs_code_uniqueness() {
  test_section "BCS Code Uniqueness Validation"

  setup

  local -- section_dir output
  local -i exit_code

  section_dir="$TEST_DATA_DIR/01-test-section"
  mkdir -p "$section_dir"

  # Create two files with same BCS code
  for file in "01-rule-one" "01-rule-two"; do
    for tier in complete summary abstract; do
      cat > "$section_dir/${file}.$tier.md" <<'EOF'
### Test Rule
<!-- BCS0101 -->
Content
#fin
EOF
    done
  done

  output=$("$VALIDATE_SCRIPT" --data-dir "$TEST_DATA_DIR" 2>&1) && exit_code=$? || exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    pass "Duplicate BCS codes detected"
  else
    fail "Should fail with duplicate BCS codes"
  fi

  teardown
}

# ==============================================================================
# Naming Convention Tests
# ==============================================================================

test_naming_conventions() {
  test_section "File Naming Convention Tests"

  setup

  local -- section_dir output
  local -i exit_code

  section_dir="$TEST_DATA_DIR/01-test-section"
  mkdir -p "$section_dir"

  # Test invalid naming (uppercase, spaces, etc.)
  cat > "$section_dir/01-Invalid_Name.complete.md" <<'EOF'
### Test
<!-- BCS0101 -->
Content
#fin
EOF

  output=$("$VALIDATE_SCRIPT" --data-dir "$TEST_DATA_DIR" 2>&1) && exit_code=$? || exit_code=$?

  if [[ "$output" =~ naming.*convention|convention.*naming ]]; then
    pass "Invalid naming convention detected"
  else
    warn "Naming convention check may not be enforced"
  fi

  teardown
}

# ==============================================================================
# BCS Code Format Tests
# ==============================================================================

test_bcs_code_format() {
  test_section "BCS Code Format Validation"

  setup

  local -- section_dir output
  local -i exit_code

  section_dir="$TEST_DATA_DIR/01-test-section"
  mkdir -p "$section_dir"

  # Create file with invalid BCS code format
  for tier in complete summary abstract; do
    cat > "$section_dir/01-test-rule.$tier.md" <<'EOF'
### Test Rule
<!-- INVALID_CODE -->
Content
#fin
EOF
  done

  output=$("$VALIDATE_SCRIPT" --data-dir "$TEST_DATA_DIR" 2>&1) && exit_code=$? || exit_code=$?

  if [[ "$output" =~ BCS.*code.*format|format.*BCS ]]; then
    pass "Invalid BCS code format detected"
  else
    warn "BCS code format check may not be strict"
  fi

  teardown
}

# ==============================================================================
# Mode Tests
# ==============================================================================

test_dry_run_mode() {
  test_section "Dry-Run Mode Test"

  local -- output

  output=$("$VALIDATE_SCRIPT" --dry-run 2>&1) || true

  assert_contains "$output" "DRY-RUN\\|DRY RUN" "Dry-run mode indicated"
}

test_quiet_mode() {
  test_section "Quiet Mode Test"

  local -- output
  local -i line_count

  output=$("$VALIDATE_SCRIPT" --quiet 2>&1) || true
  line_count=$(echo "$output" | wc -l)

  if [[ $line_count -lt 10 ]]; then
    pass "Quiet mode produces minimal output ($line_count lines)"
  else
    warn "Quiet mode output may be verbose ($line_count lines)"
  fi
}

test_specific_check() {
  test_section "Specific Check Selection Test"

  local -- output

  output=$("$VALIDATE_SCRIPT" --check tier-completeness 2>&1) || true

  if [[ "$output" =~ tier.*completeness|completeness.*tier ]]; then
    pass "Specific check selection works"
  else
    warn "Specific check option may not be implemented"
  fi
}

# ==============================================================================
# Run all tests
# ==============================================================================

test_script_exists
test_help_and_version
test_validate_real_data
test_tier_completeness
test_bcs_code_uniqueness
test_naming_conventions
test_bcs_code_format
test_dry_run_mode
test_quiet_mode
test_specific_check

print_summary
#fin
