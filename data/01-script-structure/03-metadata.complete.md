### Script Metadata

**Every script must declare standard metadata variables (VERSION, SCRIPT_PATH, SCRIPT_DIR, SCRIPT_NAME) immediately after `shopt` settings and before any other code. Make these readonly as a group.**

**Rationale:**

- **Reliable Path Resolution**: Using `realpath` provides canonical absolute paths and fails early if the script doesn't exist, preventing errors when script is called from different directories
- **Self-Documentation**: VERSION provides clear versioning for deployment and debugging
- **Resource Location**: SCRIPT_DIR enables reliable loading of companion files, libraries, and configuration
- **Logging and Error Messages**: SCRIPT_NAME provides consistent script identification in logs and error output
- **Defensive Programming**: Making metadata readonly prevents accidental modification that could break resource loading
- **Consistency**: Standard metadata variables work the same way across all scripts, reducing cognitive load

**Standard metadata pattern:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Script metadata - immediately after shopt
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Rest of script follows
\`\`\`

**Metadata variables explained:**

**1. VERSION**
- **Purpose**: Semantic version of the script
- **Format**: Major.Minor.Patch (e.g., '1.0.0', '2.3.1')
- **Used for**: `--version` output, logging, deployment tracking
- **Example usage**: `echo "$SCRIPT_NAME $VERSION"`

\`\`\`bash
VERSION='1.0.0'

# Display version
show_version() {
  echo "$SCRIPT_NAME $VERSION"
}

# Log with version
info "Starting $SCRIPT_NAME $VERSION"
\`\`\`

**2. SCRIPT_PATH**
- **Purpose**: Absolute canonical path to the script file
- **Resolves**: Symlinks, relative paths, `.` and `..` components
- **Command**: `realpath -- "$0"`
  - `--`: Prevents option injection if filename starts with `-`
  - `"$0"`: Current script name/path
  - **Behavior**: Fails if file doesn't exist (intentional - catches errors early)
  - **Builtin available**: A loadable builtin for realpath is available for maximum performance

\`\`\`bash
SCRIPT_PATH=$(realpath -- "$0")
# Examples:
# /usr/local/bin/myapp
# /home/user/projects/app/deploy.sh
# /opt/app/bin/processor

# Use for logging script location
debug "Running from: $SCRIPT_PATH"
\`\`\`

**3. SCRIPT_DIR**
- **Purpose**: Directory containing the script
- **Derivation**: `${SCRIPT_PATH%/*}` removes last `/` and everything after
- **Used for**: Loading companion files, finding resources relative to script

\`\`\`bash
SCRIPT_DIR=${SCRIPT_PATH%/*}
# Examples:
# If SCRIPT_PATH=/usr/local/bin/myapp
# Then SCRIPT_DIR=/usr/local/bin

# If SCRIPT_PATH=/home/user/projects/app/bin/deploy.sh
# Then SCRIPT_DIR=/home/user/projects/app/bin

# Load library from same directory
source "$SCRIPT_DIR/lib/common.sh"

# Read configuration from relative path
config_file="$SCRIPT_DIR/../conf/app.conf"
\`\`\`

**4. SCRIPT_NAME**
- **Purpose**: Base name of the script (filename only, no path)
- **Derivation**: `${SCRIPT_PATH##*/}` removes everything up to last `/`
- **Used for**: Error messages, logging, `--help` output

\`\`\`bash
SCRIPT_NAME=${SCRIPT_PATH##*/}
# Examples:
# If SCRIPT_PATH=/usr/local/bin/myapp
# Then SCRIPT_NAME=myapp

# If SCRIPT_PATH=/home/user/deploy.sh
# Then SCRIPT_NAME=deploy.sh

# Use in error messages
die() {
  local -i exit_code=$1
  shift
  >&2 echo "$SCRIPT_NAME: error: $*"
  exit "$exit_code"
}

# Use in help text
show_help() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] FILE

Process FILE according to configured rules.
EOF
}
\`\`\`

**Why readonly as a group:**

\`\`\`bash
# ✓ Correct - make readonly together after all assignments
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# This pattern:
# 1. Groups related declarations visibly
# 2. Makes intent clear (these are immutable metadata)
# 3. Prevents accidental reassignment anywhere in script
\`\`\`

**Using metadata for resource location:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Load libraries relative to script location
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/validation.sh"

# Load configuration
declare -- config_file="$SCRIPT_DIR/../etc/app.conf"
[[ -f "$config_file" ]] && source "$config_file"

# Access data files
declare -- data_dir="$SCRIPT_DIR/../share/data"
[[ -d "$data_dir" ]] || die 2 "Data directory not found: $data_dir"

# Use metadata in logging
info "Starting $SCRIPT_NAME $VERSION"
debug "Script location: $SCRIPT_PATH"
debug "Config: $config_file"
\`\`\`

**Edge case: Script in root directory**

\`\`\`bash
# If script is /myscript (in root directory)
SCRIPT_PATH='/myscript'
SCRIPT_DIR=${SCRIPT_PATH%/*}  # Results in empty string!

# Solution: Handle this edge case if script might be in /
SCRIPT_DIR=${SCRIPT_PATH%/*}
[[ -z "$SCRIPT_DIR" ]] && SCRIPT_DIR='/'
readonly -- SCRIPT_DIR

# Or use dirname (less portable)
SCRIPT_DIR=$(dirname -- "$SCRIPT_PATH")
\`\`\`

**Edge case: Sourced vs executed**

\`\`\`bash
# When script is sourced, $0 is the calling shell, not the script
# To detect if sourced:
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  # Script is being sourced
  SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
else
  # Script is being executed
  SCRIPT_PATH=$(realpath -- "$0")
fi

SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
\`\`\`

**Why realpath over readlink:**

\`\`\`bash
# realpath is the canonical BCS approach because:
# 1. Simpler syntax: No need for -e and -n flags (default behavior is correct)
# 2. Builtin available: Loadable builtin provides maximum performance
# 3. Widely available: Standard on modern Linux systems
# 4. POSIX compliant: realpath is in POSIX, readlink is GNU-specific
# 5. Consistent behavior: realpath fails if file doesn't exist (catches errors early)

# ✓ Correct - use realpath
SCRIPT_PATH=$(realpath -- "$0")

# ✗ Avoid - readlink requires -en flags (more complex, GNU-specific)
SCRIPT_PATH=$(readlink -en -- "$0")

# Note: realpath without -m will fail if file doesn't exist
# This is INTENTIONAL - we want to catch missing scripts early
# If you need to allow missing files, use: realpath -m -- "$0"
# (But for SCRIPT_PATH, we always want existing files)

# For maximum performance, load realpath as builtin:
# enable -f /usr/local/lib/bash-builtins/realpath.so realpath
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - using $0 directly without realpath
SCRIPT_PATH="$0"  # Could be relative path or symlink!

# ✓ Correct - resolve with realpath
SCRIPT_PATH=$(realpath -- "$0")

# ✗ Wrong - using dirname and basename (requires external commands)
SCRIPT_DIR=$(dirname "$0")
SCRIPT_NAME=$(basename "$0")

# ✓ Correct - use parameter expansion (faster, more reliable)
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}

# ✗ Wrong - using PWD for script directory
SCRIPT_DIR="$PWD"  # Wrong! This is current working directory, not script location

# ✓ Correct - derive from SCRIPT_PATH
SCRIPT_DIR=${SCRIPT_PATH%/*}

# ✗ Wrong - making readonly individually
readonly VERSION='1.0.0'
readonly SCRIPT_PATH=$(realpath -- "$0")
readonly SCRIPT_DIR=${SCRIPT_PATH%/*}  # Can't assign to readonly variable!

# ✓ Correct - assign first, then make readonly as group
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR

# ✗ Wrong - no VERSION variable
# Every script should have a version for tracking

# ✓ Correct - include VERSION
VERSION='1.0.0'

# ✗ Wrong - using inconsistent variable names
SCRIPT_VERSION='1.0.0'  # Should be VERSION
SCRIPT_DIRECTORY="$SCRIPT_DIR"  # Redundant
MY_SCRIPT_PATH="$SCRIPT_PATH"  # Non-standard

# ✓ Correct - use standard names
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}

# ✗ Wrong - declaring metadata late in script
# ... 50 lines of code ...
VERSION='1.0.0'  # Too late! Should be near top

# ✓ Correct - declare immediately after shopt
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob
VERSION='1.0.0'  # Right after shopt
\`\`\`

**Complete example with metadata usage:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Script metadata
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Global variables
declare -- LOG_FILE="$SCRIPT_DIR/../logs/$SCRIPT_NAME.log"
declare -- CONFIG_FILE="$SCRIPT_DIR/../etc/$SCRIPT_NAME.conf"

# Messaging functions
info() {
  echo "[$SCRIPT_NAME] $*" | tee -a "$LOG_FILE"
}

error() {
  >&2 echo "[$SCRIPT_NAME] ERROR: $*" | tee -a "$LOG_FILE"
}

die() {
  local -i exit_code=$1
  shift
  error "$*"
  exit "$exit_code"
}

# Show version
show_version() {
  echo "$SCRIPT_NAME $VERSION"
}

# Show help with script name
show_help() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Process data according to configuration.

Options:
  -h, --help     Show this help message
  -V, --version  Show version information

Version: $VERSION
Location: $SCRIPT_PATH
EOF
}

# Load configuration from script directory
load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    info "Loading configuration from $CONFIG_FILE"
    source "$CONFIG_FILE"
  else
    die 2 "Configuration file not found: $CONFIG_FILE"
  fi
}

main() {
  info "Starting $SCRIPT_NAME $VERSION"
  info "Running from: $SCRIPT_PATH"

  load_config

  # Main logic here
  info 'Processing complete'
}

main "$@"

#fin
\`\`\`

**Testing metadata:**

\`\`\`bash
# Test that metadata is set correctly
test_metadata() {
  # VERSION should be set
  [[ -n "$VERSION" ]] || die 1 'VERSION not set'

  # SCRIPT_PATH should be absolute
  [[ "$SCRIPT_PATH" == /* ]] || die 1 'SCRIPT_PATH is not absolute'

  # SCRIPT_PATH should exist
  [[ -f "$SCRIPT_PATH" ]] || die 1 'SCRIPT_PATH does not exist'

  # SCRIPT_DIR should be a directory
  [[ -d "$SCRIPT_DIR" ]] || die 1 'SCRIPT_DIR is not a directory'

  # SCRIPT_NAME should not contain /
  [[ "$SCRIPT_NAME" != */* ]] || die 1 'SCRIPT_NAME contains /'

  # All should be readonly
  readonly -p | grep -q 'VERSION' || die 1 'VERSION not readonly'
  readonly -p | grep -q 'SCRIPT_PATH' || die 1 'SCRIPT_PATH not readonly'

  success 'Metadata validation passed'
}
\`\`\`

**Summary:**

- **Always declare metadata** immediately after `shopt` settings
- **Use standard names**: VERSION, SCRIPT_PATH, SCRIPT_DIR, SCRIPT_NAME
- **Use realpath** to resolve SCRIPT_PATH reliably (canonical BCS approach)
- **Derive SCRIPT_DIR and SCRIPT_NAME** from SCRIPT_PATH using parameter expansion
- **Make readonly as a group** after all assignments
- **Use metadata** for resource location, logging, error messages, version display
- **Handle edge cases**: root directory, sourced scripts
- **Performance**: Consider loading realpath as builtin for maximum speed

**Key principle:** Metadata provides the foundation for reliable script operation. Declaring it consistently at the top of every script enables predictable behavior regardless of how the script is invoked or where it's located.
