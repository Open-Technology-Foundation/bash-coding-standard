## Constants and Environment Variables

**Constants (readonly):**
```bash
# Use readonly for values that never change
readonly -- SCRIPT_VERSION='1.0.0'
readonly -- MAX_RETRIES=3
readonly -- CONFIG_DIR='/etc/myapp'

# Group readonly declarations
VERSION='1.0.0'
AUTHOR='John Doe'
LICENSE='MIT'
readonly -- VERSION AUTHOR LICENSE
```

**Environment variables (export):**
```bash
# Use declare -x (or export) for variables passed to child processes
declare -x ORACLE_SID='PROD'
declare -x DATABASE_URL='postgresql://localhost/mydb'

# Alternative syntax
export LOG_LEVEL='DEBUG'
export TEMP_DIR='/tmp/myapp'
```

**Rationale:**

**When to use `readonly`:**
- **Script metadata** that never changes (VERSION, AUTHOR, LICENSE)
- **Configuration paths** determined at startup (CONFIG_DIR, DATA_DIR)
- **Constants derived from calculations** that shouldn't be modified later
- **Purpose**: Prevent accidental modification, signal intent to readers

**When to use `declare -x` / `export`:**
- **Values needed by child processes** (commands executed by script)
- **Environment configuration** for tools (DATABASE_URL, API_KEY)
- **Settings inherited by subshells** (LOG_LEVEL, DEBUG_MODE)
- **Purpose**: Make variable available in subprocess environment

**Key differences:**

| Feature | `readonly` | `declare -x` / `export` |
|---------|-----------|------------------------|
| Prevents modification | ✓ Yes | ✗ No |
| Available in subprocesses | ✗ No | ✓ Yes |
| Can be changed later | ✗ Never | ✓ Yes |
| Use case | Constants | Environment config |

**Combining both (readonly + export):**
```bash
# Make a constant that is also exported to child processes
declare -rx BUILD_ENV='production'
readonly -x MAX_CONNECTIONS=100

# Or in two steps
declare -x DATABASE_URL='postgresql://prod-db/app'
readonly -- DATABASE_URL
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - exporting constants unnecessarily
export MAX_RETRIES=3  # Child processes don't need this

# ✓ Correct - only make it readonly
readonly -- MAX_RETRIES=3

# ✗ Wrong - not making true constants readonly
CONFIG_FILE='/etc/app.conf'  # Could be accidentally modified later

# ✓ Correct - protect against modification
readonly -- CONFIG_FILE='/etc/app.conf'

# ✗ Wrong - making user-configurable variables readonly too early
readonly -- OUTPUT_DIR="$HOME/output"  # Can't be overridden by user!

# ✓ Correct - allow override, then make readonly
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/output}"
readonly -- OUTPUT_DIR
```

**Example combining both:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Script constants (not exported)
readonly -- SCRIPT_VERSION='2.1.0'
readonly -- MAX_FILE_SIZE=$((100 * 1024 * 1024))  # 100MB

# Environment variables for child processes (exported)
declare -x LOG_LEVEL="${LOG_LEVEL:-INFO}"
declare -x TEMP_DIR="${TMPDIR:-/tmp}"

# Combined: readonly + exported
declare -rx BUILD_ENV='production'

# Derived constants (readonly)
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
readonly -- SCRIPT_PATH SCRIPT_DIR
```
