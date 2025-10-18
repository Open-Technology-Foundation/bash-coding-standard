### Common Layout Anti-Patterns

**This subrule demonstrates common violations of the BCS0101 13-step layout pattern, showing both the incorrect approach and the correct solution for each.**

---

## Anti-Patterns

### ✗ Wrong: Missing `set -euo pipefail`

```bash
#!/usr/bin/env bash

# Script starts without error handling
VERSION='1.0.0'

# Commands can fail silently
rm -rf /important/data
cp config.txt /etc/
```

**Problem:** Errors are not caught, script continues executing after failures, leading to silent corruption or incomplete operations.

### ✓ Correct: Error Handling First

```bash
#!/usr/bin/env bash

# Installation script with proper safeguards

set -euo pipefail

shopt -s inherit_errexit shift_verbose

VERSION='1.0.0'
# ... rest of script
```

---

### ✗ Wrong: Declaring Variables After Use

```bash
#!/usr/bin/env bash
set -euo pipefail

main() {
  # Using VERBOSE before it's declared
  ((VERBOSE)) && echo 'Starting...'

  process_files
}

# Variables declared after main()
declare -i VERBOSE=0

main "$@"
#fin
```

**Problem:** Variables are referenced before they're declared, leading to "unbound variable" errors with `set -u`.

### ✓ Correct: Declare Before Use

```bash
#!/usr/bin/env bash
set -euo pipefail

# Declare all globals up front
declare -i VERBOSE=0
declare -i DRY_RUN=0

main() {
  # Now safe to use
  ((VERBOSE)) && echo 'Starting...'

  process_files
}

main "$@"
#fin
```

---

### ✗ Wrong: Business Logic Before Utilities

```bash
#!/usr/bin/env bash
set -euo pipefail

# Business logic defined first
process_files() {
  local -- file
  for file in *.txt; do
    # Calling die() which isn't defined yet!
    [[ -f "$file" ]] || die 2 "Not a file '$file'"
    echo "Processing '$file'"
  done
}

# Utilities defined after business logic
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

main() {
  process_files
  : ...
}

main "$@"
#fin
```

**Problem:** `process_files()` calls `die()` which isn't defined yet. This works in bash (functions are resolved at runtime) but violates the principle of bottom-up organization and makes code harder to understand.

### ✓ Correct: Utilities Before Business Logic

```bash
#!/usr/bin/env bash
set -euo pipefail

# Utilities first
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

# Business logic can safely call utilities
process_files() {
  local -- file
  for file in *.txt; do
    [[ -f "$file" ]] || die 2 "Not a file '$file'"
    echo "Processing '$file'"
  done
}

main() {
  process_files
}

main "$@"
#fin
```

---

### ✗ Wrong: No `main()` Function in Large Script

`set -euo pipefail` must be placed before the start of the first line of executing code.

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'

# ... 200 lines of functions ...

# Argument parsing scattered throughout
if [[ "$1" == '--help' ]]; then
  echo 'Usage: ...'
  exit 0
fi

# Business logic runs directly
check_prerequisites
validate_config
install_files

echo 'Done'
#fin
```

**Problem:** No clear entry point, argument parsing is scattered, can't easily test the script, can't source it to test individual functions.

### ✓ Correct: Use `main()` for Scripts Over 40 Lines

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'

# ... 200 lines of functions ...

main() {
  # Centralized argument parsing
  while (($#)); do
    case $1 in
      -h|--help) usage; exit 0 ;;
      *) die 22 "Invalid argument '$1'" ;;
    esac
    shift
  done

  # Clear execution flow
  check_prerequisites
  validate_config
  install_files

  success 'Installation complete'
}

main "$@"
#fin
```

---

### ✗ Wrong: Missing End Marker

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'

main() {
  echo 'Hello, World!'
}

main "$@"
# File ends without #fin or #end
```

**Problem:** No visual confirmation that file is complete, harder to detect truncated files.

### ✓ Correct: Always End With `#fin`

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'

main() {
  echo 'Hello, World!'
}

main "$@"
#fin
```

---

### ✗ Wrong: Readonly Before Parsing Arguments

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'
PREFIX='/usr/local'

# Made readonly too early!
readonly -- VERSION PREFIX

main() {
  while (($#)); do
    case $1 in
      --prefix)
        shift
        # This will fail - PREFIX is readonly!
        PREFIX="$1"
        ;;
    esac
    shift
  done
}

main "$@"
#fin
```

**Problem:** Variables that need to be modified during argument parsing are made readonly too early.

### ✓ Correct: Readonly After Argument Parsing

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_NAME  # These never change

declare -- PREFIX='/usr/local'  # Will be modified during parsing

main() {
  while (($#)); do
    case $1 in
      --prefix)
        shift
        PREFIX="$1"  # OK - not readonly yet
        ;;
    esac
    shift
  done

  # Now make readonly after parsing complete
  readonly -- PREFIX

  # Rest of logic...
}

main "$@"
#fin
```

---

### ✗ Wrong: Mixing Declaration and Logic

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'

# Some globals
declare -i VERBOSE=0

# Function in the middle
check_something() {
  echo 'Checking...'
}

# More globals after function
declare -- PREFIX='/usr/local'
declare -- CONFIG_FILE=''

main() {
  check_something
}

main "$@"
#fin
```

**Problem:** Globals are scattered throughout the file, making it hard to see all state variables at once.

### ✓ Correct: All Globals Together

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION='1.0.0'

# All globals in one place
declare -i VERBOSE=0
declare -- PREFIX='/usr/local'
declare -- CONFIG_FILE=''

# All functions after globals
check_something() {
  echo 'Checking...'
}

main() {
  check_something
}

main "$@"
#fin
```

---

### ✗ Wrong: Sourcing Without Protecting Execution

```bash
#!/usr/bin/env bash
# This file is meant to be sourced, but...

set -euo pipefail  # Modifies caller's shell!

die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

# Runs automatically when sourced!
main "$@"
#fin
```

**Problem:** When sourced, this modifies the caller's shell settings and runs `main` automatically.

### ✓ Correct: Dual-Purpose Script

```bash
#!/usr/bin/env bash
# Only set strict mode when executed (not sourced)

error() { >&2 echo "ERROR: $*"; }

die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

# Only run main when executed (not sourced)
# Fast exit if sourced
[[ "${BASH_SOURCE[0]}" == "$0" ]] || return 0

# Now start main script
set -euo pipefail

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_NAME  # These never change

: ...

main() {
  echo 'Running main'
  : ...
}

main "$@"

#fin
```

---

## Summary

These eight anti-patterns represent the most common violations of the BCS0101 13-step layout:

1. **Missing strict mode** - Scripts without `set -euo pipefail` fail silently
2. **Declaration order** - Variables must be declared before use
3. **Function organization** - Utilities must come before business logic
4. **Missing main()** - Large scripts need structured entry point
5. **Missing end marker** - Scripts must end with `#fin` or `#end`
6. **Premature readonly** - Variables that change must not be readonly until after parsing
7. **Scattered declarations** - All globals must be grouped together
8. **Unprotected sourcing** - Dual-purpose scripts must protect execution code

Following the correct patterns ensures scripts are safe, maintainable, and predictable. Each violation leads to specific classes of bugs that are completely preventable through proper structure.
