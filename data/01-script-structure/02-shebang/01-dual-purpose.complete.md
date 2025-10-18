### Dual-Purpose Scripts (Executable and Sourceable)

Some scripts are designed to work both as standalone executables and as source libraries that can be loaded into other scripts. For these dual-purpose scripts, `set -euo pipefail` and `shopt` settings must **ONLY** be applied when the script is executed directly, **NOT** when it is sourced.

**Rationale:** When a script is sourced, applying `set -e` or modifying `shopt` settings would alter the calling shell's environment, potentially breaking the caller's error handling or glob behavior. The sourced script should only provide functions and variables without side effects on the caller's shell state.

**Recommended pattern (early return):**
```bash
#!/bin/bash
# Description of dual-purpose script

# Function definitions (available in both modes)
my_function() {
  local -- arg="$1"
  [[ -n "$arg" ]] || return 1
  echo "Processing: $arg"
}
declare -fx my_function

# Early return for sourced mode - stops here when sourced
[[ ${BASH_SOURCE[0]} != "$0" ]] && return 0

# -----------------------------------------------------------------------------
# Executable code starts here (only runs when executed directly)
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Metadata initialization with guard (allows re-sourcing safety)
if [[ ! -v SCRIPT_VERSION ]]; then
  declare -x SCRIPT_VERSION='1.0.0'
  declare -x SCRIPT_PATH=$(realpath -- "$0")
  declare -x SCRIPT_DIR=${SCRIPT_PATH%/*}
  declare -x SCRIPT_NAME=${SCRIPT_PATH##*/}
  readonly -- SCRIPT_VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME
fi

# Helper functions (only needed for executable mode)
show_help() {
  cat <<EOT
$SCRIPT_NAME $SCRIPT_VERSION - Description

Usage: $SCRIPT_NAME [options] [arguments]
EOT
}

# Main execution logic
my_function "$@"

#fin
```

**Pattern breakdown:**

1. **Function definitions first** (lines 4-9)
   - Define all library functions at the top
   - Export with `declare -fx` if needed by subshells
   - Functions become available when sourced

2. **Early return** (line 12)
   - Single line: `[[ ${BASH_SOURCE[0]} != "$0" ]] && return 0`
   - When sourced: functions loaded, then immediate clean exit
   - When executed: test fails, continues to next line
   - Using `!=` (not equal) reads more naturally than `==`

3. **Visual separator** (line 14)
   - Clear comment line marks executable section boundary
   - Makes code organization obvious to readers

4. **Set and shopt** (lines 15-16)
   - Only applied when executed (never when sourced)
   - Placed immediately after the separation line

5. **Metadata with guard** (lines 18-24)
   - `if [[ ! -v SCRIPT_VERSION ]]` prevents re-initialization
   - Safe to source multiple times without errors
   - Uses `-v` to test if variable is set

**Alternative pattern (if/else block):**

For scripts requiring different initialization in each mode:
```bash
#!/bin/bash

# Functions first
process_data() { ... }
declare -fx process_data

# Dual-mode initialization
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  # EXECUTED MODE
  set -euo pipefail
  DATA_DIR=/var/lib/myapp
  process_data "$DATA_DIR"
else
  # SOURCED MODE - different initialization
  DATA_DIR=${DATA_DIR:-/tmp/test_data}
  # Export functions, return to caller
fi
```

**Key principles:**
- **Prefer early return pattern** for simplicity and clarity
- Place all function definitions **before** the sourced/executed detection
- Only apply `set -euo pipefail` and `shopt` in executable section
- Use `return` (not `exit`) for errors when sourced
- Guard metadata initialization with `[[ ! -v VARIABLE ]]` for idempotence
- Test both modes: `./script.sh` (execute) and `source script.sh` (source)

**Real-world examples:**
- The `bash-coding-standard` script in this repository
- The `getbcscode.sh` script provides `get_BCS_code_from_rule_filename()` function

**Common use cases:**
- Utility libraries that can also demonstrate usage when executed
- Scripts that provide reusable functions plus a CLI interface
- Test frameworks that can be sourced for functions or run for tests
