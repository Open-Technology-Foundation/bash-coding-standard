#!/usr/bin/env bash
# install.sh - Install dux utility, completion, and manpage
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# The caller's PATH, for the "not in PATH" hint; the locked PATH below never
# contains ~/.local/bin, so testing it would always warn.
declare -r CALLER_PATH=${PATH:-}

# Lock down PATH for security
declare -rx PATH='/usr/local/bin:/usr/bin:/bin'

declare -r VERSION='1.5.0'
declare -r SCRIPT_NAME=${0##*/}
declare -- SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
declare -r SCRIPT_DIR

# Source files
declare -r SRC_BIN="$SCRIPT_DIR/dir-sizes"
declare -r SRC_COMP="$SCRIPT_DIR/dux.bash_completion"
declare -r SRC_MAN="$SCRIPT_DIR/dux.1"

# Destination directories (set based on root/user)
declare -- DEST_BIN='' DEST_COMP='' DEST_MAN=''

# Colors for output (TTY-conditional)
if [[ -t 1 && -t 2 ]]; then
  declare -r RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m' NC='\033[0m'
else
  declare -r RED='' GREEN='' YELLOW='' NC=''
fi

msg()   { printf '%b\n' "$*"; }
ok()    { msg "${GREEN}✓${NC} $*"; }
warn()  { msg "${YELLOW}▲${NC} $*"; }
error() { msg "${RED}✗${NC} $*" >&2; }
die()   { error "${*:2}"; exit "${1:-1}"; }

show_help() {
  cat <<EOF
$SCRIPT_NAME $VERSION - Install dux utility

USAGE
  ./$SCRIPT_NAME [OPTIONS]

OPTIONS
  -h, --help        Show this help
  -u, --uninstall   Remove installed files
  -n, --dry-run     Show what would be done without doing it

INSTALL LOCATIONS
  Root user:
    Executable:  /usr/local/bin/dir-sizes (symlink: dux)
    Completion:  /etc/bash_completion.d/dux
    Manpage:     /usr/share/man/man1/dux.1

  Regular user:
    Executable:  ~/.local/bin/dir-sizes (symlink: dux)
    Completion:  ~/.local/share/bash-completion/completions/dux
    Manpage:     ~/.local/share/man/man1/dux.1

EXAMPLES
  sudo ./install.sh      # System-wide install
  ./install.sh           # User install
  ./install.sh -u        # Uninstall
EOF
}

set_destinations() {
  if ((EUID == 0)); then
    DEST_BIN='/usr/local/bin'
    DEST_COMP='/etc/bash_completion.d'
    DEST_MAN='/usr/share/man/man1'
  else
    DEST_BIN="$HOME/.local/bin"
    DEST_COMP="$HOME/.local/share/bash-completion/completions"
    DEST_MAN="$HOME/.local/share/man/man1"
  fi
}

check_sources() {
  local -i errors=0
  [[ -f "$SRC_BIN" ]]  || { error "Missing: $SRC_BIN"; errors+=1; }
  [[ -f "$SRC_COMP" ]] || { error "Missing: $SRC_COMP"; errors+=1; }
  [[ -f "$SRC_MAN" ]]  || { error "Missing: $SRC_MAN"; errors+=1; }
  ((errors == 0)) || die 2 "Source files not found. Run from the dux directory."
}

do_install() {
  local -i dry_run=${1:-0}

  msg "\nInstalling dux..."
  msg "  Binary:     $DEST_BIN"
  msg "  Completion: $DEST_COMP"
  msg "  Manpage:    $DEST_MAN\n"

  # Create directories
  for dir in "$DEST_BIN" "$DEST_COMP" "$DEST_MAN"; do
    if [[ ! -d "$dir" ]]; then
      if ((dry_run)); then
        msg "Would create: $dir"
      else
        mkdir -p "$dir"
        ok "Created: $dir"
      fi
    fi
  done

  # Install executable
  if ((dry_run)); then
    msg "Would install: $DEST_BIN/dir-sizes"
    msg "Would symlink: $DEST_BIN/dux -> dir-sizes"
  else
    install -m 755 "$SRC_BIN" "$DEST_BIN/dir-sizes"
    ok "Installed: $DEST_BIN/dir-sizes"

    # Create symlink (remove existing first)
    rm -f "$DEST_BIN/dux"
    ln -s dir-sizes "$DEST_BIN/dux"
    ok "Symlinked: $DEST_BIN/dux -> dir-sizes"
  fi

  # Install completion
  if ((dry_run)); then
    msg "Would install: $DEST_COMP/dux"
  else
    install -m 644 "$SRC_COMP" "$DEST_COMP/dux"
    ok "Installed: $DEST_COMP/dux"
  fi

  # Install manpage
  if ((dry_run)); then
    msg "Would install: $DEST_MAN/dux.1"
  else
    install -m 644 "$SRC_MAN" "$DEST_MAN/dux.1"
    ok "Installed: $DEST_MAN/dux.1"

    # Update man database
    if command -v mandb &>/dev/null; then
      if ((EUID == 0)); then
        mandb -q 2>/dev/null ||:
      else
        mandb -q "$DEST_MAN/.." 2>/dev/null ||:
      fi
      ok "Updated man database"
    fi
  fi

  # Check PATH for user installs
  if ((EUID != 0)) && [[ ":$CALLER_PATH:" != *":$DEST_BIN:"* ]]; then
    warn "$DEST_BIN is not in PATH"
    msg "  Add to ~/.bashrc:  export PATH=\"\$PATH:$DEST_BIN\""
  fi

  msg "\n${GREEN}Installation complete!${NC}"
  if ((dry_run)); then
    msg "(dry-run mode - no changes made)"
  else
    msg "Run 'dux --help' to get started."
    if ((EUID != 0)); then
      msg "Restart your shell or run: source ~/.bashrc"
    fi
  fi
}

do_uninstall() {
  local -i dry_run=${1:-0}

  msg "\nUninstalling dux..."

  local -a files=(
    "$DEST_BIN/dir-sizes"
    "$DEST_BIN/dux"
    "$DEST_COMP/dux"
    "$DEST_MAN/dux.1"
  )

  for file in "${files[@]}"; do
    if [[ -e "$file" ]] || [[ -L "$file" ]]; then
      if ((dry_run)); then
        msg "Would remove: $file"
      else
        rm -f "$file"
        ok "Removed: $file"
      fi
    fi
  done

  # Update man database if root
  if ((EUID == 0)) && ! ((dry_run)) && command -v mandb &>/dev/null; then
    mandb -q 2>/dev/null ||:
  fi

  msg "\n${GREEN}Uninstallation complete!${NC}"
  if ((dry_run)); then
    msg "(dry-run mode - no changes made)"
  fi
}

main() {
  local -i uninstall=0 dry_run=0

  while (($#)); do
    case $1 in
      -h|--help)      show_help; exit 0 ;;
      -u|--uninstall) uninstall=1 ;;
      -n|--dry-run)   dry_run=1 ;;
      *)              die 22 "Unknown option ${1@Q}" ;;
    esac
    shift
  done
  readonly -- uninstall dry_run

  set_destinations
  check_sources

  if ((uninstall)); then
    do_uninstall "$dry_run"
  else
    do_install "$dry_run"
  fi
}

main "$@"

#fin
