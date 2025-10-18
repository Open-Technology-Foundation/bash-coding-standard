## Conditional Declarations with Exit Code Handling

**When using arithmetic conditionals for optional declarations or actions under `set -e`, append `|| :` to prevent false conditions from triggering script exit.**

**Rationale:**

- **Arithmetic conditionals return exit codes**: `(())` returns 0 (success) when true, 1 (failure) when false
- **`set -e` exits on non-zero**: Under `set -euo pipefail`, any command returning non-zero exits the script
- **Conditional execution is intentional**: Sometimes we want `((condition)) && action` where action runs only if condition is true
- **False condition shouldn't exit**: When condition is false, we want to continue, not exit
- **`|| :` provides safe fallback**: The colon command `:` is a no-op that always returns 0 (success)
- **Idiomatic shell pattern**: `|| :` is the traditional Unix idiom for "ignore this error"

**The core problem:**

```bash
#!/bin/bash
set -euo pipefail

declare -i complete=0

# ✗ DANGEROUS: Script exits here if complete=0!
((complete)) && declare -g BLUE=$'\033[0;34m'
# When complete=0:
#   1. (( complete )) evaluates to false, returns 1
#   2. && short-circuits, declare never runs
#   3. Overall exit code is 1 (from the arithmetic test)
#   4. set -e sees exit code 1 and terminates the script!

echo "This line never executes"
```

**The solution:**

```bash
#!/bin/bash
set -euo pipefail

declare -i complete=0

# ✓ SAFE: Script continues even when complete=0
((complete)) && declare -g BLUE=$'\033[0;34m' || :
# When complete=0:
#   1. (( complete )) evaluates to false, returns 1
#   2. && short-circuits, declare never runs
#   3. || : triggers, colon returns 0
#   4. Overall exit code is 0 (success)
#   5. Script continues normally

echo "This line executes correctly"
```

**Why `:` (colon) over `true`:**

```bash
# Both are functionally equivalent no-ops that return 0

# ✓ PREFERRED: Colon command
((condition)) && action || :
# - Traditional Unix idiom (dates to Bourne shell)
# - Built-in command (no fork)
# - 1 character (concise)
# - Standard in POSIX scripts
# - Slightly faster (no PATH lookup)

# ✓ ACCEPTABLE: true command
((condition)) && action || true
# - More explicit/readable for beginners
# - 4 characters (slightly more verbose)
# - Also a built-in (no performance difference in practice)
# - Common in modern scripts

# Both are correct; colon is traditional shell idiom
```

**Common patterns:**

**Pattern 1: Conditional variable declaration**

```bash
declare -i complete=0 verbose=0

# Declare extended variables only in complete mode
((complete)) && declare -g BLUE=$'\033[0;34m' MAGENTA=$'\033[0;35m' || :

# Print variables only in verbose mode
((verbose)) && declare -p NC RED GREEN YELLOW || :
```

**Pattern 2: Nested conditional declarations**

```bash
if ((color)); then
  declare -g NC=$'\033[0m' RED=$'\033[0;31m'
  ((complete)) && declare -g BLUE=$'\033[0;34m' MAGENTA=$'\033[0;35m' || :
else
  declare -g NC='' RED=''
  ((complete)) && declare -g BLUE='' MAGENTA='' || :
fi
```

**Pattern 3: Conditional block execution**

```bash
((verbose)) && {
  declare -p NC RED GREEN
  ((complete)) && declare -p BLUE MAGENTA || :
} || :
```

**Pattern 4: Multiple conditional actions**

```bash
declare -i flags=0 complete=0

if ((flags)); then
  declare -ig VERBOSE=${VERBOSE:-1}
  ((complete)) && declare -ig DEBUG=0 DRY_RUN=1 PROMPT=1 || :
fi
```

**Real-world example from color-set.sh:**

```bash
#!/bin/bash
# Dual-purpose script: sourceable library + executable demo

color_set() {
  local -i color=-1 complete=0 verbose=0 flags=0

  # Parse arguments to set flags
  while (($#)); do
    case ${1:-auto} in
      complete) complete=1 ;;
      basic)    complete=0 ;;
      flags)    flags=1 ;;
      verbose)  verbose=1 ;;
      always)   color=1 ;;
      never)    color=0 ;;
      auto)     color=-1 ;;
      *)        >&2 echo "$FUNCNAME: error: Invalid mode ${1@Q}"
                return 1 ;;
    esac
    shift
  done

  # Auto-detect if color not explicitly set
  ((color== -1)) && { [[ -t 1 && -t 2 ]] && color=1 || color=0; }

  # Declare flag variables only if flags mode active
  if ((flags)); then
    declare -ig VERBOSE=${VERBOSE:-1}
    # Only declare DEBUG/DRY_RUN/PROMPT in complete mode
    ((complete)) && declare -ig DEBUG=0 DRY_RUN=1 PROMPT=1 || :
  fi

  # Declare color variables
  if ((color)); then
    # Always declare basic colors
    declare -g NC=$'\033[0m' RED=$'\033[0;31m' GREEN=$'\033[0;32m'
    # Only declare extended colors in complete mode
    ((complete)) && declare -g BLUE=$'\033[0;34m' MAGENTA=$'\033[0;35m' BOLD=$'\033[1m' || :
  else
    declare -g NC='' RED='' GREEN=''
    ((complete)) && declare -g BLUE='' MAGENTA='' BOLD='' || :
  fi

  # Print variables only in verbose mode
  if ((verbose)); then
    ((flags)) && declare -p VERBOSE || :
    declare -p NC RED GREEN
    ((complete)) && {
      ((flags)) && declare -p DEBUG DRY_RUN PROMPT || :
      declare -p BLUE MAGENTA BOLD
    } || :
  fi

  return 0
}
declare -fx color_set

# Dual-purpose pattern: only execute when run directly
[[ ${BASH_SOURCE[0]} == "$0" ]] || return 0
#!/bin/bash #semantic
set -euo pipefail

color_set "$@"

#fin
```

This script demonstrates:
- Two-tier system (basic vs complete)
- Feature flags (flags mode)
- Multiple conditional declarations
- Safe handling under `set -e`
- All using `|| :` for exit code management

**When to use this pattern:**

**✓ Use `|| :` when:**

1. **Optional variable declarations** based on feature flags
   ```bash
   ((DEBUG)) && declare -g DEBUG_OUTPUT=/tmp/debug.log || :
   ```

2. **Conditional exports** for environment variables
   ```bash
   ((PRODUCTION)) && export PATH=/opt/app/bin:$PATH || :
   ```

3. **Feature-gated actions** that should be silent when disabled
   ```bash
   ((VERBOSE)) && echo "Processing $file" || :
   ((DRY_RUN)) && echo "Would execute: $command" || :
   ```

4. **Optional logging or debug output**
   ```bash
   ((LOG_LEVEL >= 2)) && log_debug "Variable value: $var" || :
   ```

5. **Tier-based variable sets** (like basic vs complete colors)
   ```bash
   ((FULL_FEATURES)) && declare -g EXTRA_VAR=value || :
   ```

**✗ Don't use when:**

1. **The action must succeed** - use explicit error handling instead
   ```bash
   # ✗ Wrong - suppresses critical errors
   ((required_flag)) && critical_operation || :

   # ✓ Correct - check explicitly
   if ((required_flag)); then
     critical_operation || die 1 "Critical operation failed"
   fi
   ```

2. **You need to know if it failed** - capture the exit code
   ```bash
   # ✗ Wrong - hides failure
   ((condition)) && risky_operation || :

   # ✓ Correct - handle failure
   if ((condition)) && ! risky_operation; then
     error "risky_operation failed"
     return 1
   fi
   ```

3. **The condition itself is the operation** - use if statement
   ```bash
   # ✗ Awkward - condition is the operation
   ((count+=1)) && echo "Incremented" || :

   # ✓ Clearer - just do the operation
   count+=1
   echo "Incremented"
   ```

**Anti-patterns to avoid:**

```bash
# ✗ WRONG: No || :, script exits when condition is false
((complete)) && declare -g BLUE=$'\033[0;34m'
# If complete=0, script exits with set -e!

# ✗ WRONG: Double negative, less readable
((complete==0)) || declare -g BLUE=$'\033[0;34m'
# Logically equivalent but harder to understand

# ✗ WRONG: Using true instead of : (verbose, less idiomatic)
((complete)) && declare -g BLUE=$'\033[0;34m' || true
# Works but : is preferred in shell scripts

# ✗ WRONG: Complex fallback
((complete)) && declare -g BLUE=$'\033[0;34m' || { true; }
# Unnecessarily complex, just use :

# ✗ WRONG: Suppressing critical operations
((user_confirmed)) && delete_all_files || :
# If delete_all_files fails, error is hidden!

# ✓ CORRECT: Check critical operations explicitly
if ((user_confirmed)); then
  delete_all_files || die 1 "Failed to delete files"
fi
```

**Comparison of alternatives:**

**Alternative 1: if statement (most explicit)**

```bash
# ✓ Most readable, best for complex logic
if ((complete)); then
  declare -g BLUE=$'\033[0;34m' MAGENTA=$'\033[0;35m'
fi

# Pros: Crystal clear intent, no exit code issues
# Cons: More verbose (4 lines vs 1)
# Use when: Logic is complex or has multiple statements
```

**Alternative 2: Arithmetic test with `|| :`**

```bash
# ✓ Concise, safe under set -e
((complete)) && declare -g BLUE=$'\033[0;34m' || :

# Pros: One line, traditional idiom, safe
# Cons: Less obvious for beginners
# Use when: Simple conditional declaration
```

**Alternative 3: Double-negative pattern**

```bash
# ✓ Works but less readable
((complete==0)) || declare -g BLUE=$'\033[0;34m'

# Pros: No || : needed (fails when complete≠0, which is fine)
# Cons: Double negative is confusing
# Use when: Never - prefer positive logic with || :
```

**Alternative 4: Temporarily disable errexit**

```bash
# ✗ Not recommended - disables error checking
set +e
((complete)) && declare -g BLUE=$'\033[0;34m'
set -e

# Pros: None
# Cons: Disables error checking for all commands in between
# Use when: Never - use || : instead
```

**Testing the pattern:**

```bash
#!/bin/bash
set -euo pipefail

# Test 1: Verify false condition doesn't exit
test_false_condition() {
  local -i flag=0

  # Without || :, this would exit the script
  ((flag)) && echo "This won't print" || :

  # Script continues
  echo "Test 1 passed: false condition didn't exit"
}

# Test 2: Verify true condition executes action
test_true_condition() {
  local -i flag=1
  local -- output=''

  # Action should execute
  ((flag)) && output="executed" || :

  [[ "$output" == "executed" ]] || {
    echo "Test 2 failed: true condition didn't execute"
    return 1
  }

  echo "Test 2 passed: true condition executed action"
}

# Test 3: Verify nested conditionals
test_nested_conditionals() {
  local -i outer=1 inner=0
  local -i executed=0

  ((outer)) && {
    executed=1
    ((inner)) && executed=2 || :
  } || :

  ((executed == 1)) || {
    echo "Test 3 failed: expected executed=1, got $executed"
    return 1
  }

  echo "Test 3 passed: nested conditionals work correctly"
}

# Test 4: Verify set -e still catches real errors
test_error_detection() {
  local -i flag=1

  # Real error should still exit
  if ((flag)) && false; then
    echo "Test 4 failed: error not detected"
    return 1
  fi

  echo "Test 4 passed: real errors still caught"
}

# Run tests
test_false_condition
test_true_condition
test_nested_conditionals
test_error_detection

echo "All tests passed!"

#fin
```

**Summary:**

- **Use `|| :`** after `((condition)) && action` to prevent false conditions from triggering `set -e` exit
- **Colon `:` is preferred** over `true` (traditional shell idiom, concise)
- **Only for optional operations** - critical operations need explicit error handling
- **Document intent** with comments when the pattern might not be obvious
- **Test both paths** - verify behavior when condition is true and false
- **Cross-reference**: See BCS0705 (Arithmetic Operations), BCS0805 (Error Suppression), BCS0801 (Exit on Error)

**Key principle:** When you want conditional execution without risking script exit, use `((condition)) && action || :`. This makes your intent explicit: "Do this if condition is true, but don't exit if condition is false."
