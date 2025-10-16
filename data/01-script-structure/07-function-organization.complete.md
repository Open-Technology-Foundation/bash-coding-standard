### Function Organization

**Always organize functions bottom-up: lowest-level primitives first (messaging, utilities), then composition layers, ending with `main()` as the highest-level orchestrator. This pattern makes scripts readable, maintainable, and eliminates forward reference issues.**

**Rationale:**

- **No Forward References**: Bash reads top-to-bottom; defining functions in dependency order ensures all called functions exist before use
- **Readability**: Readers understand primitives first, then see how they're composed into complex operations
- **Debugging Efficiency**: When debugging, you can read from top down and understand dependencies immediately
- **Maintainability**: Clear dependency hierarchy makes it obvious where to add new functions
- **Testability**: Low-level functions can be tested independently before testing higher-level compositions
- **Cognitive Load**: Understanding small pieces first, then compositions reduces mental overhead

**Standard 7-layer organization pattern:**

```bash
#!/bin/bash
set -euo pipefail

# 1. Messaging functions (lowest level - used by everything)
_msg() { ... }
success() { >&2 _msg "$@"; }
warn() { >&2 _msg "$@"; }
info() { >&2 _msg "$@"; }
error() { >&2 _msg "$@"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

# 2. Documentation functions (no dependencies)
show_help() { ... }

# 3. Helper/utility functions (used by validation and business logic)
yn() { ... }
noarg() { ... }

# 4. Validation functions (check prerequisites, dependencies)
check_root() { ... }
check_prerequisites() { ... }
check_builtin_support() { ... }

# 5. Business logic functions (domain-specific operations)
build_standalone() { ... }
build_builtin() { ... }
install_standalone() { ... }
install_builtin() { ... }
install_completions() { ... }
update_man_database() { ... }

# 6. Orchestration/flow functions
show_completion_message() { ... }
uninstall_files() { ... }

# 7. Main function (highest level - orchestrates everything)
main() {
  check_root
  check_prerequisites

  if ((UNINSTALL)); then
    uninstall_files
    return 0
  fi

  build_standalone
  ((INSTALL_BUILTIN)) && build_builtin

  install_standalone
  install_completions
  ((INSTALL_BUILTIN)) && install_builtin

  update_man_database
  show_completion_message
}

main "$@"
#fin
```

**Key principle of bottom-up organization:**

Each function can safely call functions defined ABOVE it (earlier in the file). Dependencies flow downward: higher functions call lower functions, never upward.

\`\`\`
Top of file
     ↓
[Layer 1: Messaging] ← Can call nothing (primitives)
     ↓
[Layer 2: Documentation] ← Can call Layer 1
     ↓
[Layer 3: Utilities] ← Can call Layers 1-2
     ↓
[Layer 4: Validation] ← Can call Layers 1-3
     ↓
[Layer 5: Business Logic] ← Can call Layers 1-4
     ↓
[Layer 6: Orchestration] ← Can call Layers 1-5
     ↓
[Layer 7: main()] ← Can call all layers
     ↓
main "$@" invocation
#fin
\`\`\`

**Detailed layer descriptions:**

**Layer 1: Messaging functions (lowest primitives)**
- `_msg()`, `info()`, `warn()`, `error()`, `die()`, `success()`, `debug()`, `vecho()`
- **Purpose**: Output messages to user
- **Dependencies**: None (pure I/O)
- **Used by**: Everything

**Layer 2: Documentation functions**
- `show_help()`, `show_version()`, `show_usage()`
- **Purpose**: Display help text and usage information
- **Dependencies**: May use messaging functions
- **Used by**: Argument parsing, main()

**Layer 3: Helper/utility functions**
- `yn()`, `noarg()`, `trim()`, `s()`, `decp()`
- **Purpose**: Generic utilities usable anywhere
- **Dependencies**: May use messaging
- **Used by**: Validation, business logic

**Layer 4: Validation functions**
- `check_root()`, `check_prerequisites()`, `validate_input()`, `check_dependencies()`
- **Purpose**: Verify preconditions and input
- **Dependencies**: Utilities, messaging
- **Used by**: main(), business logic

**Layer 5: Business logic functions**
- Domain-specific operations: `build_project()`, `process_file()`, `deploy_app()`
- **Purpose**: Core functionality of the script
- **Dependencies**: All lower layers
- **Used by**: Orchestration, main()

**Layer 6: Orchestration functions**
- `run_build_phase()`, `run_deploy_phase()`, `cleanup()`
- **Purpose**: Coordinate multiple business logic functions
- **Dependencies**: Business logic, validation
- **Used by**: main()

**Layer 7: main() function**
- **Purpose**: Top-level script flow
- **Dependencies**: Can call any function
- **Used by**: Script invocation line

**Complete example showing full organization:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Global variables
declare -i VERBOSE=0
declare -i DRY_RUN=0
declare -- BUILD_DIR='/tmp/build'

# ============================================================================
# Layer 1: Messaging functions
# ============================================================================

_msg() {
  local -- func="${FUNCNAME[1]}"
  echo "[$func] $*"
}

info() {
  >&2 _msg "$@"
}

warn() {
  >&2 _msg "WARNING: $*"
}

error() {
  >&2 _msg "ERROR: $*"
}

die() {
  local -i exit_code=$1
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}

success() {
  >&2 _msg "SUCCESS: $*"
}

debug() {
  ((VERBOSE)) && >&2 _msg "DEBUG: $*"
  return 0
}

# ============================================================================
# Layer 2: Documentation functions
# ============================================================================

show_version() {
  echo "$SCRIPT_NAME $VERSION"
}

show_help() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Build and deploy application.

Options:
  -v, --verbose   Enable verbose output
  -n, --dry-run   Dry-run mode (no changes)
  -h, --help      Show this help
  -V, --version   Show version

Version: $VERSION
EOF
}

# ============================================================================
# Layer 3: Helper/utility functions
# ============================================================================

yn() {
  local -- prompt="${1:-Continue?}"
  local -- response

  while true; do
    read -rp "$prompt [y/n] " response
    case "$response" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *) warn 'Please answer y or n' ;;
    esac
  done
}

noarg() {
  (($# < 2)) && die 2 "Option $1 requires an argument"
}

# ============================================================================
# Layer 4: Validation functions
# ============================================================================

check_prerequisites() {
  info 'Checking prerequisites...'

  # Check required commands
  local -- cmd
  for cmd in git make tar; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      die 1 "Required command not found: $cmd"
    fi
  done

  # Check build directory writable
  if [[ ! -w "${BUILD_DIR%/*}" ]]; then
    die 5 "Cannot write to build directory: $BUILD_DIR"
  fi

  success 'Prerequisites check passed'
}

validate_config() {
  info 'Validating configuration...'

  # Check config file exists
  [[ -f 'config.conf' ]] || die 2 'Configuration file not found: config.conf'

  # Validate config contents
  source 'config.conf'

  [[ -n "${APP_NAME:-}" ]] || die 22 'APP_NAME not set in config'
  [[ -n "${APP_VERSION:-}" ]] || die 22 'APP_VERSION not set in config'

  debug "App: $APP_NAME $APP_VERSION"
  success 'Configuration validated'
}

# ============================================================================
# Layer 5: Business logic functions
# ============================================================================

clean_build_dir() {
  info "Cleaning build directory: $BUILD_DIR"

  if ((DRY_RUN)); then
    info '[DRY-RUN] Would remove build directory'
    return 0
  fi

  if [[ -d "$BUILD_DIR" ]]; then
    rm -rf "$BUILD_DIR"
    debug "Removed: $BUILD_DIR"
  fi

  install -d "$BUILD_DIR"
  success "Build directory ready: $BUILD_DIR"
}

compile_sources() {
  info 'Compiling sources...'

  if ((DRY_RUN)); then
    info '[DRY-RUN] Would compile sources'
    return 0
  fi

  # Compile logic here
  make -C src all BUILD_DIR="$BUILD_DIR"

  success 'Sources compiled'
}

run_tests() {
  info 'Running tests...'

  if ((DRY_RUN)); then
    info '[DRY-RUN] Would run tests'
    return 0
  fi

  # Test logic here
  make -C tests all

  success 'Tests passed'
}

create_package() {
  info 'Creating package...'
  local -- package_file="$BUILD_DIR/app.tar.gz"

  if ((DRY_RUN)); then
    info "[DRY-RUN] Would create package: $package_file"
    return 0
  fi

  tar -czf "$package_file" -C "$BUILD_DIR" .
  success "Package created: $package_file"
}

# ============================================================================
# Layer 6: Orchestration functions
# ============================================================================

run_build_phase() {
  info 'Starting build phase...'

  clean_build_dir
  compile_sources
  run_tests

  success 'Build phase complete'
}

run_package_phase() {
  info 'Starting package phase...'

  create_package

  success 'Package phase complete'
}

# ============================================================================
# Layer 7: Main function (highest level)
# ============================================================================

main() {
  # Parse arguments (simplified for example)
  while (($#)); do case $1 in
    -v|--verbose) VERBOSE=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    -h|--help)    show_help; exit 0 ;;
    -V|--version) show_version; exit 0 ;;
    -*)           die 22 "Invalid option: $1" ;;
    *)            die 2 "Unexpected argument: $1" ;;
  esac; shift; done

  # Set readonly after argument parsing
  readonly -- VERBOSE DRY_RUN

  info "Starting $SCRIPT_NAME $VERSION"
  ((DRY_RUN)) && info 'DRY-RUN MODE ENABLED'

  # Validate environment
  check_prerequisites
  validate_config

  # Execute phases in order
  run_build_phase
  run_package_phase

  success "$SCRIPT_NAME completed successfully"
}

main "$@"

#fin
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - main() at the top (forward references required)
main() {
  build_project  # build_project not defined yet!
  deploy_app     # deploy_app not defined yet!
}

build_project() { ... }
deploy_app() { ... }

# ✓ Correct - main() at bottom
build_project() { ... }
deploy_app() { ... }

main() {
  build_project
  deploy_app
}

# ✗ Wrong - business logic before utilities it calls
process_file() {
  validate_input "$1"  # validate_input not defined yet!
  # ...
}

validate_input() { ... }

# ✓ Correct - utilities before business logic
validate_input() { ... }

process_file() {
  validate_input "$1"
  # ...
}

# ✗ Wrong - random/alphabetical organization ignoring dependencies
cleanup() { ... }
build() { ... }
check_deps() { ... }
main() { ... }

# ✓ Correct - dependency-ordered organization
check_deps() { ... }  # No dependencies
build() { check_deps; ... }  # Depends on check_deps
cleanup() { ... }  # No dependencies
main() { build; cleanup; }  # Depends on all

# ✗ Wrong - messaging functions scattered throughout
info() { ... }
build() { ... }
warn() { ... }
deploy() { ... }
error() { ... }

# ✓ Correct - all messaging together at top
info() { ... }
warn() { ... }
error() { ... }
die() { ... }

build() { ... }
deploy() { ... }

# ✗ Wrong - circular dependencies (A calls B, B calls A)
function_a() {
  # ...
  function_b  # Calls B
}

function_b() {
  # ...
  function_a  # Calls A - circular dependency!
}

# ✓ Correct - extract common logic to lower-level function
common_logic() {
  # Shared code
}

function_a() {
  common_logic
  # A-specific code
}

function_b() {
  common_logic
  # B-specific code
}
\`\`\`

**Guidelines for within-layer ordering:**

**1. Within Layer 1 (Messaging):**
Order by severity/importance:
- `_msg()` (core utility)
- `info()`
- `success()`
- `debug()`/`vecho()`
- `warn()`
- `error()`
- `die()` (terminates script)

**2. Within Layer 3 (Helpers):**
Order alphabetically or by frequency of use:
- Most commonly used first
- Or alphabetically for easy lookup

**3. Within Layer 4 (Validation):**
Order by execution sequence:
- Functions called early in script first
- Or alphabetically

**4. Within Layer 5 (Business Logic):**
Order by logical workflow:
- Functions representing sequential steps in order
- Or group related operations together

**Edge cases and special considerations:**

**1. Circular dependencies:**

\`\`\`bash
# Problem: Function A needs B, but B needs A

# Solution 1: Extract common logic to lower layer
shared_validation() {
  # Common validation used by both
}

function_a() {
  shared_validation
  # A-specific logic
}

function_b() {
  shared_validation
  # B-specific logic
}

# Solution 2: Restructure to eliminate circular dependency
# Often indicates design issue - rethink function responsibilities
\`\`\`

**2. Optional functions (sourced libraries):**

\`\`\`bash
# When sourcing libraries, they may define functions
# Place source statements after your messaging layer

# Messaging functions
info() { ... }
warn() { ... }
error() { ... }
die() { ... }

# Source library (may define additional utilities)
source "$SCRIPT_DIR/lib/common.sh"

# Your utilities
# (Can now use both your messaging AND library functions)
validate_email() { ... }
\`\`\`

**3. Private functions:**

\`\`\`bash
# Functions prefixed with _ are private/internal
# Place in same layer as public functions that use them

# Layer 1: Messaging
_msg() { ... }  # Private core utility
info() { >&2 _msg "$@"; }  # Public wrapper

# Layer 3: Utilities
_internal_parser() { ... }  # Private helper
parse_config() { _internal_parser "$@"; }  # Public interface
\`\`\`

**Summary:**

- **Always organize bottom-up**: messaging → utilities → validation → business logic → orchestration → main()
- **Group functions** with section comments (e.g., `# Layer 3: Utilities`)
- **Dependencies flow downward**: higher functions call lower functions, never upward
- **Within each layer**: order alphabetically or by logical sequence
- **main() is always last** before invocation
- **Avoid circular dependencies**: extract common logic to lower layer
- **Use section comments** to visually separate layers

**Key principle:** Bottom-up organization mirrors how programmers think: understand primitives first, then compositions. This pattern eliminates forward reference issues and makes scripts immediately understandable to readers.
