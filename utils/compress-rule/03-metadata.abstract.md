### Script Metadata

**Declare VERSION, SCRIPT_PATH, SCRIPT_DIR, SCRIPT_NAME immediately after `shopt`, make readonly as group.**

**Rationale:** `realpath` provides canonical paths (fails early on missing files); SCRIPT_DIR enables relative resource loading; readonly prevents modification.

**Pattern:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME
```

**Variables:**
- **VERSION**: Semantic version (Major.Minor.Patch)
- **SCRIPT_PATH**: Absolute path via `realpath -- "$0"` (`--` prevents option injection)
- **SCRIPT_DIR**: Script directory via `${SCRIPT_PATH%/*}`
- **SCRIPT_NAME**: Filename via `${SCRIPT_PATH##*/}`

**Usage:**

```bash
source "$SCRIPT_DIR/lib/common.sh"  # Load relative resources
die() { >&2 echo "$SCRIPT_NAME: error: $*"; exit "$1"; }
```

**Use realpath (not readlink):** Simpler, POSIX compliant, loadable builtin available, fails early.

**Anti-patterns:**
- `SCRIPT_PATH="$0"` → No realpath (unreliable)
- `SCRIPT_DIR=$(dirname "$0")` → Slow, unreliable
- `readonly SCRIPT_PATH=$(realpath -- "$0")` → Can't derive SCRIPT_DIR after
- `SCRIPT_DIR="$PWD"` → Wrong! CWD ≠ script location

**Ref:** See comprehensive version for sourcing detection, edge cases, complete examples.
