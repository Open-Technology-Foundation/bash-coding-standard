### Filesystem Hierarchy Standard (FHS) Preference

**When designing scripts that install files or search for resources, follow the Filesystem Hierarchy Standard (FHS) where practical. FHS compliance enables predictable file locations, supports both system and user installations, and integrates smoothly with package managers.**

**Rationale:**

- **Predictability**: Users and package managers expect files in standard locations (`/usr/local/bin/`, `/usr/share/`, etc.)
- **Multi-Environment Support**: Scripts work correctly in development, local install, system install, and user-specific install scenarios
- **Package Manager Compatibility**: FHS-compliant layouts work seamlessly with apt, yum, pacman, etc.
- **No Hardcoded Paths**: Using FHS search patterns eliminates brittle absolute paths
- **Portability**: Scripts work across different Linux distributions without modification
- **Separation of Concerns**: FHS separates executables, data, configuration, and documentation logically

**Common FHS locations:**
- `/usr/local/bin/` - User-installed executables (system-wide, not managed by package manager)
- `/usr/local/share/` - Architecture-independent data files
- `/usr/local/lib/` - Libraries and loadable modules
- `/usr/local/etc/` - Configuration files
- `/usr/bin/` - System executables (managed by package manager)
- `/usr/share/` - System-wide architecture-independent data
- `$HOME/.local/bin/` - User-specific executables (in user's PATH)
- `$HOME/.local/share/` - User-specific data files
- `${XDG_CONFIG_HOME:-$HOME/.config}/` - User-specific configuration

**When FHS is useful:**
- Installation scripts that need to place files in standard locations
- Scripts that search for data files in multiple standard locations
- Scripts that support both system-wide and user-specific installation
- Projects distributed to multiple systems expecting standard paths

**Example pattern - searching for data files:**
```bash
find_data_file() {
  local -- script_dir="$1"
  local -- filename="$2"
  local -a search_paths=(
    "$script_dir"/"$filename"  # Same directory (development)
    /usr/local/share/myapp/"$filename" # Local install
    /usr/share/myapp/"$filename" # System install
    "${XDG_DATA_HOME:-$HOME/.local/share}/myapp/$filename"  # User install
  )

  local -- path
  for path in "${search_paths[@]}"; do
    [[ -f "$path" ]] && { echo "$path"; return 0; }
  done

  return 1
}
```

**Complete installation example (Makefile pattern):**

\`\`\`bash
#!/bin/bash
# install.sh - FHS-compliant installation script
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Installation paths (customizable via PREFIX)
declare -- PREFIX="${PREFIX:-/usr/local}"
declare -- BIN_DIR="$PREFIX/bin"
declare -- SHARE_DIR="$PREFIX/share/myapp"
declare -- LIB_DIR="$PREFIX/lib/myapp"
declare -- ETC_DIR="$PREFIX/etc/myapp"
declare -- MAN_DIR="$PREFIX/share/man/man1"
readonly -- PREFIX BIN_DIR SHARE_DIR LIB_DIR ETC_DIR MAN_DIR

install_files() {
  # Create directories
  install -d "$BIN_DIR"
  install -d "$SHARE_DIR"
  install -d "$LIB_DIR"
  install -d "$ETC_DIR"
  install -d "$MAN_DIR"

  # Install executable
  install -m 755 "$SCRIPT_DIR/myapp" "$BIN_DIR/myapp"

  # Install data files
  install -m 644 "$SCRIPT_DIR/data/template.txt" "$SHARE_DIR/template.txt"

  # Install libraries
  install -m 644 "$SCRIPT_DIR/lib/common.sh" "$LIB_DIR/common.sh"

  # Install configuration (preserve existing)
  if [[ ! -f "$ETC_DIR/myapp.conf" ]]; then
    install -m 644 "$SCRIPT_DIR/myapp.conf.example" "$ETC_DIR/myapp.conf"
  fi

  # Install man page
  install -m 644 "$SCRIPT_DIR/docs/myapp.1" "$MAN_DIR/myapp.1"

  info "Installation complete to $PREFIX"
  info "Executable: $BIN_DIR/myapp"
}

uninstall_files() {
  # Remove installed files
  rm -f "$BIN_DIR/myapp"
  rm -f "$SHARE_DIR/template.txt"
  rm -f "$LIB_DIR/common.sh"
  rm -f "$MAN_DIR/myapp.1"

  # Remove directories if empty
  rmdir --ignore-fail-on-non-empty "$SHARE_DIR"
  rmdir --ignore-fail-on-non-empty "$LIB_DIR"
  rmdir --ignore-fail-on-non-empty "$ETC_DIR"

  info "Uninstallation complete"
}

main() {
  case "${1:-install}" in
    install)   install_files ;;
    uninstall) uninstall_files ;;
    *)         die 2 "Usage: $SCRIPT_NAME {install|uninstall}" ;;
  esac
}

main "$@"

#fin
\`\`\`

**FHS-aware resource loading pattern:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Find data file using FHS search pattern
find_data_file() {
  local -- filename="$1"
  local -a search_paths=(
    # Development: same directory as script
    "$SCRIPT_DIR/$filename"

    # Local install: /usr/local/share
    "/usr/local/share/myapp/$filename"

    # System install: /usr/share
    "/usr/share/myapp/$filename"

    # User install: XDG Base Directory
    "${XDG_DATA_HOME:-$HOME/.local/share}/myapp/$filename"
  )

  local -- path
  for path in "${search_paths[@]}"; do
    if [[ -f "$path" ]]; then
      echo "$path"
      return 0
    fi
  done

  die 2 "Data file not found: $filename"
}

# Find configuration file with XDG support
find_config_file() {
  local -- filename="$1"
  local -a search_paths=(
    # User-specific config (highest priority)
    "${XDG_CONFIG_HOME:-$HOME/.config}/myapp/$filename"

    # System-wide local config
    "/usr/local/etc/myapp/$filename"

    # System-wide config
    "/etc/myapp/$filename"

    # Development/fallback
    "$SCRIPT_DIR/$filename"
  )

  local -- path
  for path in "${search_paths[@]}"; do
    if [[ -f "$path" ]]; then
      echo "$path"
      return 0
    fi
  done

  # Return empty if not found (config is optional)
  return 1
}

# Load library from FHS locations
load_library() {
  local -- lib_name="$1"
  local -a search_paths=(
    # Development
    "$SCRIPT_DIR/lib/$lib_name"

    # Local install
    "/usr/local/lib/myapp/$lib_name"

    # System install
    "/usr/lib/myapp/$lib_name"
  )

  local -- path
  for path in "${search_paths[@]}"; do
    if [[ -f "$path" ]]; then
      source "$path"
      return 0
    fi
  done

  die 2 "Library not found: $lib_name"
}

main() {
  # Load required library
  load_library 'common.sh'

  # Find data file
  local -- template
  template=$(find_data_file 'template.txt')
  info "Using template: $template"

  # Find config file (optional)
  local -- config
  if config=$(find_config_file 'myapp.conf'); then
    info "Loading config: $config"
    source "$config"
  else
    info 'No config file found, using defaults'
  fi

  # Main logic here
}

main "$@"

#fin
\`\`\`

**PREFIX customization (make install pattern):**

\`\`\`bash
# Makefile example
PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
SHAREDIR = $(PREFIX)/share/myapp
MANDIR = $(PREFIX)/share/man/man1

install:
	install -d $(BINDIR)
	install -d $(SHAREDIR)
	install -d $(MANDIR)
	install -m 755 myapp $(BINDIR)/myapp
	install -m 644 data/template.txt $(SHAREDIR)/template.txt
	install -m 644 docs/myapp.1 $(MANDIR)/myapp.1

uninstall:
	rm -f $(BINDIR)/myapp
	rm -f $(SHAREDIR)/template.txt
	rm -f $(MANDIR)/myapp.1

# Usage:
# make install                  # Installs to /usr/local
# make PREFIX=/usr install      # Installs to /usr
# make PREFIX=$HOME/.local install  # User install
\`\`\`

**XDG Base Directory Specification:**

For user-specific files, follow XDG Base Directory spec:

\`\`\`bash
# XDG environment variables with fallbacks
declare -- XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
declare -- XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
declare -- XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
declare -- XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# User-specific paths
declare -- USER_DATA_DIR="$XDG_DATA_HOME/myapp"
declare -- USER_CONFIG_DIR="$XDG_CONFIG_HOME/myapp"
declare -- USER_CACHE_DIR="$XDG_CACHE_HOME/myapp"
declare -- USER_STATE_DIR="$XDG_STATE_HOME/myapp"

# Create user directories if needed
install -d "$USER_DATA_DIR"
install -d "$USER_CONFIG_DIR"
install -d "$USER_CACHE_DIR"
install -d "$USER_STATE_DIR"
\`\`\`

**Real-world example from this repository:**

The `bash-coding-standard` script searches for `BASH-CODING-STANDARD.md` in:

\`\`\`bash
find_bcs_file() {
  local -a search_paths=(
    # Development: same directory as script
    "$SCRIPT_DIR/BASH-CODING-STANDARD.md"

    # Local install: /usr/local/share
    '/usr/local/share/yatti/bash-coding-standard/BASH-CODING-STANDARD.md'

    # System install: /usr/share
    '/usr/share/yatti/bash-coding-standard/BASH-CODING-STANDARD.md'
  )

  local -- path
  for path in "${search_paths[@]}"; do
    [[ -f "$path" ]] && { echo "$path"; return 0; }
  done

  die 2 'BASH-CODING-STANDARD.md not found in any standard location'
}

BCS_FILE=$(find_bcs_file)
\`\`\`

This approach allows the script to work in:
- Development mode (running from source directory)
- After `make install` (to /usr/local)
- After `make PREFIX=/usr install` (system-wide)
- When installed by package manager (debian, rpm, etc.)

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - hardcoded absolute path
data_file='/home/user/projects/myapp/data/template.txt'

# ✓ Correct - FHS search pattern
data_file=$(find_data_file 'template.txt')

# ✗ Wrong - assuming specific install location
source /usr/local/lib/myapp/common.sh

# ✓ Correct - search multiple FHS locations
load_library 'common.sh'

# ✗ Wrong - using relative paths from CWD
source ../lib/common.sh  # Breaks when run from different directory

# ✓ Correct - paths relative to script location
source "$SCRIPT_DIR/../lib/common.sh"

# ✗ Wrong - installing to non-standard location
install myapp /opt/random/location/bin/

# ✓ Correct - use PREFIX-based FHS paths
install myapp "$PREFIX/bin/"

# ✗ Wrong - not supporting PREFIX customization
BIN_DIR=/usr/local/bin  # Hardcoded

# ✓ Correct - respect PREFIX environment variable
PREFIX="${PREFIX:-/usr/local}"
BIN_DIR="$PREFIX/bin"

# ✗ Wrong - mixing executables and data in same directory
install myapp /opt/myapp/
install template.txt /opt/myapp/

# ✓ Correct - separate by FHS hierarchy
install myapp "$PREFIX/bin/"
install template.txt "$PREFIX/share/myapp/"

# ✗ Wrong - overwriting user configuration on upgrade
install myapp.conf "$PREFIX/etc/myapp/myapp.conf"

# ✓ Correct - preserve existing config
[[ -f "$PREFIX/etc/myapp/myapp.conf" ]] || \
  install myapp.conf.example "$PREFIX/etc/myapp/myapp.conf"
\`\`\`

**Edge cases:**

**1. PREFIX with trailing slash:**

\`\`\`bash
# Handle PREFIX with or without trailing slash
PREFIX="${PREFIX:-/usr/local}"
PREFIX="${PREFIX%/}"  # Remove trailing slash if present
BIN_DIR="$PREFIX/bin"
\`\`\`

**2. User install without sudo:**

\`\`\`bash
# Detect if user has write permissions
if [[ ! -w "$PREFIX" ]]; then
  warn "No write permission to $PREFIX"
  info "Try: PREFIX=\$HOME/.local make install"
  die 5 'Permission denied'
fi
\`\`\`

**3. Library path for runtime:**

\`\`\`bash
# Some systems need LD_LIBRARY_PATH for custom locations
if [[ -d "$PREFIX/lib/myapp" ]]; then
  export LD_LIBRARY_PATH="$PREFIX/lib/myapp${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
\`\`\`

**4. Symlink vs real path:**

\`\`\`bash
# If script is symlinked to /usr/local/bin, SCRIPT_DIR resolves to actual location
# This is correct - we want the real installation directory, not the symlink location
SCRIPT_PATH=$(realpath -- "$0")  # Resolves symlinks
SCRIPT_DIR=${SCRIPT_PATH%/*}

# Now SCRIPT_DIR points to actual install location, not /usr/local/bin
\`\`\`

**When NOT to use FHS:**

- **Single-user scripts**: Scripts only used by one user don't need FHS
- **Project-specific tools**: Build scripts, test runners that stay in project directory
- **Container applications**: Docker containers often use app-specific paths like `/app`
- **Embedded systems**: Limited systems may use custom layouts

**Summary:**

- **Follow FHS** for scripts that install system-wide or distribute to users
- **Use PREFIX** to support custom installation locations
- **Search multiple locations** for resources (development, local, system, user)
- **Separate file types**: bin/ for executables, share/ for data, etc/ for config, lib/ for libraries
- **Support XDG** for user-specific files (`XDG_CONFIG_HOME`, `XDG_DATA_HOME`)
- **Preserve user config** on upgrades (don't overwrite existing files)
- **Make PREFIX customizable** via environment variable

**Key principle:** FHS compliance makes scripts portable, predictable, and compatible with package managers. Design scripts to work in development mode and multiple install scenarios without modification.
