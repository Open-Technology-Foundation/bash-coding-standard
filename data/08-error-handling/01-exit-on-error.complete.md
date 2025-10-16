### Exit on Error
```bash
set -euo pipefail
# -e: Exit on command failure
# -u: Exit on undefined variable
# -o pipefail: Exit on pipe failure
```

**Detailed explanation:**

- **`set -e`** (errexit): Script exits immediately if any command returns non-zero
- **`set -u`** (nounset): Exit if referencing undefined variables
- **`set -o pipefail`**: Pipeline fails if any command in pipe fails (not just last)

**Rationale:** These flags turn Bash from "permissive" to "strict mode":
- Catches errors immediately instead of continuing with bad state
- Prevents cascading failures
- Makes scripts behave more like compiled languages

**Common patterns for handling expected failures:**

```bash
# Pattern 1: Allow specific command to fail
command_that_might_fail || true

# Pattern 2: Capture exit code
if command_that_might_fail; then
  echo "Success"
else
  echo "Expected failure occurred"
fi

# Pattern 3: Temporarily disable errexit
set +e
risky_command
set -e

# Pattern 4: Check if variable exists before using
if [[ -n "${OPTIONAL_VAR:-}" ]]; then
  echo "Variable is set: $OPTIONAL_VAR"
fi
```

**Important gotchas:**

```bash
# ✗ This will exit even though you check the result
result=$(failing_command)  # Script exits here with set -e
if [[ -n "$result" ]]; then  # Never reached
  echo "Never gets here"
fi

# ✓ Correct - disable errexit for this command
set +e
result=$(failing_command)
set -e
if [[ -n "$result" ]]; then
  echo "Now this works"
fi

# ✓ Alternative - check in conditional
if result=$(failing_command); then
  echo "Command succeeded: $result"
else
  echo "Command failed, that's okay"
fi
```

**When to disable these flags:**
- Interactive scripts where user errors should be recoverable
- Scripts that intentionally try multiple approaches
- During cleanup operations that might fail

**Best practice:** Keep them enabled for most scripts. Disable only when absolutely necessary and re-enable immediately after.
