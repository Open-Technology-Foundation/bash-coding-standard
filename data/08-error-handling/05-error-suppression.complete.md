### Error Suppression

**Only suppress errors when the failure is expected, non-critical, and you have explicitly decided it's safe to continue. Always document WHY errors are being suppressed. Indiscriminate error suppression masks bugs and creates unreliable scripts.**

**Rationale:**

- **Masks Real Bugs**: Suppressing errors hides failures that should be fixed
- **Silent Failures**: Scripts appear to succeed while actually failing
- **Security Risk**: Ignored errors can leave systems in insecure states
- **Debugging Nightmare**: Suppressed errors make it impossible to diagnose problems
- **False Success**: Users think operation succeeded when it actually failed
- **Technical Debt**: Suppressed errors often indicate design problems that should be fixed

**When error suppression IS appropriate:**

**1. Checking if command exists (expected to fail):**

\`\`\`bash
# ✓ Appropriate - failure is expected and non-critical
if command -v optional_tool >/dev/null 2>&1; then
  info 'optional_tool available'
else
  info 'optional_tool not found (optional)'
fi
\`\`\`

**2. Checking if file exists (expected to fail):**

\`\`\`bash
# ✓ Appropriate - testing existence, failure is expected
if [[ -f "$optional_config" ]]; then
  source "$optional_config"
else
  info "Using default configuration (no $optional_config)"
fi
\`\`\`

**3. Cleanup operations (may fail if nothing to clean):**

\`\`\`bash
# ✓ Appropriate - cleanup may have nothing to do
cleanup_temp_files() {
  # Suppress errors - temp files might not exist
  rm -f /tmp/myapp_* 2>/dev/null || true
  rmdir /tmp/myapp 2>/dev/null || true
}
\`\`\`

**4. Optional operations with fallback:**

\`\`\`bash
# ✓ Appropriate - md2ansi is optional, have fallback
if command -v md2ansi >/dev/null 2>&1; then
  md2ansi < "$file" || cat "$file"  # Fallback to cat
else
  cat "$file"  # md2ansi not available
fi
\`\`\`

**5. Idempotent operations:**

\`\`\`bash
# ✓ Appropriate - directory may already exist
install -d "$target_dir" 2>/dev/null || true

# ✓ Appropriate - user may already exist
id "$username" >/dev/null 2>&1 || useradd "$username"
\`\`\`

**When error suppression is DANGEROUS:**

**1. File operations (usually critical):**

\`\`\`bash
# ✗ DANGEROUS - if copy fails, script continues with missing file!
cp "$important_config" "$destination" 2>/dev/null || true

# ✓ Correct - check result and fail explicitly
if ! cp "$important_config" "$destination"; then
  die 1 "Failed to copy config to $destination"
fi
\`\`\`

**2. Data processing (silently loses data):**

\`\`\`bash
# ✗ DANGEROUS - if processing fails, data is lost!
process_data < input.txt > output.txt 2>/dev/null || true

# ✓ Correct - check result
if ! process_data < input.txt > output.txt; then
  die 1 'Data processing failed'
fi
\`\`\`

**3. System configuration (leaves system broken):**

\`\`\`bash
# ✗ DANGEROUS - if systemctl fails, service is not running!
systemctl start myapp 2>/dev/null || true

# ✓ Correct - verify service started
systemctl start myapp || die 1 'Failed to start myapp service'
\`\`\`

**4. Security operations (creates vulnerabilities):**

\`\`\`bash
# ✗ DANGEROUS - if chmod fails, file has wrong permissions!
chmod 600 "$private_key" 2>/dev/null || true

# ✓ Correct - security operations must succeed
chmod 600 "$private_key" || die 1 "Failed to secure $private_key"
\`\`\`

**5. Dependency checks (script runs without required tools):**

\`\`\`bash
# ✗ DANGEROUS - if git is missing, later commands will fail mysteriously!
command -v git >/dev/null 2>&1 || true

# ✓ Correct - fail early if dependency missing
command -v git >/dev/null 2>&1 || die 1 'git is required'
\`\`\`

**Error suppression patterns:**

**Pattern 1: Redirect stderr to /dev/null**

\`\`\`bash
# Suppress only error messages
command 2>/dev/null

# Use when: Error messages are noisy but you still check return value
if ! command 2>/dev/null; then
  error "command failed"
fi
\`\`\`

**Pattern 2: || true (ignore return code)**

\`\`\`bash
# Make command always succeed
command || true

# Use when: Failure is acceptable and you want to continue
rm -f /tmp/optional_file || true
\`\`\`

**Pattern 3: Combined suppression**

\`\`\`bash
# Suppress both errors and return code
command 2>/dev/null || true

# Use when: Both error messages and return code are irrelevant
rmdir /tmp/maybe_exists 2>/dev/null || true
\`\`\`

**Pattern 4: Suppress with comment (ALWAYS document WHY)**

\`\`\`bash
# Suppress errors for optional cleanup
# Rationale: Temp files may not exist, this is not an error
rm -f /tmp/myapp_* 2>/dev/null || true

# Suppress errors for idempotent operation
# Rationale: Directory may already exist from previous run
install -d "$cache_dir" 2>/dev/null || true
\`\`\`

**Pattern 5: Conditional suppression**

\`\`\`bash
# Only suppress in specific cases
if ((DRY_RUN)); then
  # In dry-run, operations are expected to fail
  actual_operation 2>/dev/null || true
else
  # In real mode, operations must succeed
  actual_operation || die 1 'Operation failed'
fi
\`\`\`

**Complete example with appropriate suppression:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -- CACHE_DIR="$HOME/.cache/myapp"
declare -- LOG_FILE="$HOME/.local/share/myapp/app.log"

# Check for optional dependency (suppress is OK)
check_optional_tools() {
  # ✓ Safe to suppress - tool is optional
  if command -v md2ansi >/dev/null 2>&1; then
    info 'md2ansi available for formatted output'
    declare -g -i HAS_MD2ANSI=1
  else
    info 'md2ansi not found (optional)'
    declare -g -i HAS_MD2ANSI=0
  fi
}

# Check required dependency (DO NOT suppress)
check_required_tools() {
  # ✗ Do NOT suppress - tool is required
  if ! command -v jq >/dev/null 2>&1; then
    die 1 'jq is required but not found'
  fi
  info 'Required tools found'
}

# Create directories (suppress is OK for idempotent operation)
create_directories() {
  # ✓ Safe to suppress - directory may already exist
  # Rationale: install -d is idempotent, existing directory is not an error
  install -d "$CACHE_DIR" 2>/dev/null || true
  install -d "${LOG_FILE%/*}" 2>/dev/null || true

  # But verify they exist now
  [[ -d "$CACHE_DIR" ]] || die 1 "Failed to create cache directory: $CACHE_DIR"
  [[ -d "${LOG_FILE%/*}" ]] || die 1 "Failed to create log directory: ${LOG_FILE%/*}"
}

# Cleanup old files (suppress is OK)
cleanup_old_files() {
  info 'Cleaning up old files...'

  # ✓ Safe to suppress - files may not exist
  # Rationale: Cleanup is best-effort, missing files are not an error
  rm -f "$CACHE_DIR"/*.tmp 2>/dev/null || true
  rm -f "$CACHE_DIR"/*.old 2>/dev/null || true

  # ✓ Safe to suppress - directory may be empty or not exist
  # Rationale: rmdir only removes empty directories, failure is expected
  rmdir "$CACHE_DIR"/temp_* 2>/dev/null || true

  info 'Cleanup complete'
}

# Process data (DO NOT suppress)
process_data() {
  local -- input_file="$1"
  local -- output_file="$2"

  # ✗ Do NOT suppress - data processing errors are critical
  if ! jq '.data' < "$input_file" > "$output_file"; then
    die 1 "Failed to process $input_file"
  fi

  # ✗ Do NOT suppress - validation must succeed
  if ! jq empty < "$output_file"; then
    die 1 "Output file is invalid: $output_file"
  fi

  info "Processed: $input_file -> $output_file"
}

main() {
  check_required_tools
  check_optional_tools
  create_directories
  cleanup_old_files

  # Process files (errors NOT suppressed)
  process_data 'input.json' "$CACHE_DIR/output.json"

  info 'Processing complete'
}

main "$@"

#fin
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ WRONG - suppressing critical operation
cp "$important_file" "$backup" 2>/dev/null || true
# If cp fails, you have no backup but script continues!

# ✓ Correct - check critical operations
cp "$important_file" "$backup" || die 1 "Failed to create backup"

# ✗ WRONG - suppressing without understanding why
some_command 2>/dev/null || true
# Why are we suppressing? Is this safe?

# ✓ Correct - document reason for suppression
# Suppress errors: temp directory may not exist (non-critical)
rmdir /tmp/myapp 2>/dev/null || true

# ✗ WRONG - suppressing all errors in function
process_files() {
  # ... many operations ...
} 2>/dev/null
# This suppresses ALL errors in function - extremely dangerous!

# ✓ Correct - only suppress specific operations
process_files() {
  critical_operation || die 1 'Critical operation failed'
  optional_cleanup 2>/dev/null || true  # Only this is suppressed
}

# ✗ WRONG - using set +e to suppress errors
set +e
critical_operation
set -e
# Disables error checking for entire block!

# ✓ Correct - use || true for specific command
critical_operation || {
  error 'Operation failed but continuing'
  # Decided this is safe to ignore in this context
  true
}

# ✗ WRONG - suppressing in production but not development
if [[ "$ENV" == "production" ]]; then
  operation 2>/dev/null || true
else
  operation
fi
# If it fails in production, you need to know!

# ✓ Correct - same error handling everywhere
operation || die 1 'Operation failed'
\`\`\`

**Testing error suppression:**

\`\`\`bash
# Verify suppression is appropriate
test_error_suppression() {
  # Test that suppressed operation actually might fail
  rm -f /nonexistent/file 2>/dev/null || true

  # Verify this didn't break anything
  [[ -d /tmp ]] || die 1 'Suppressed operation broke system!'

  # Test that non-suppressed operations are checked
  if ! cp /etc/passwd /tmp/test_passwd 2>&1; then
    info 'Correctly detected failure'
  else
    die 1 'Should have failed without /tmp write permission'
  fi

  rm -f /tmp/test_passwd
}
\`\`\`

**Summary:**

- **Only suppress** when failure is expected, non-critical, and safe to ignore
- **Always document** WHY errors are suppressed (comment above suppression)
- **Never suppress** critical operations (data, security, required dependencies)
- **Use `|| true`** to ignore return code while keeping stderr visible
- **Use `2>/dev/null`** to suppress error messages while checking return code
- **Use both** (`2>/dev/null || true`) only when both messages and return code are irrelevant
- **Verify after** suppressed operations when possible
- **Test without** suppression first to ensure operation is correct

**Key principle:** Error suppression should be the exception, not the rule. Every `2>/dev/null` and `|| true` is a deliberate decision that this specific failure is safe to ignore. Document the decision with a comment explaining why.
