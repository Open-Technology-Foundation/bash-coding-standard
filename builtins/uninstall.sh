#!/usr/bin/env bash
# uninstall.sh - Uninstallation script for bash loadable builtins

set -euo pipefail

# Script metadata
VERSION='1.0.0'
SCRIPT_PATH=$(readlink -en -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Colors for output
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[0;33m'
declare -r BLUE='\033[0;34m'
declare -r RESET='\033[0m'

# Configuration
declare -i SYSTEM_WIDE=0
declare -i USER_UNINSTALL=0
declare -i FORCE=0

# Messaging functions
info() {
    echo -e "${BLUE}[INFO]${RESET} $*"
}

success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $*"
}

warn() {
    echo -e "${YELLOW}[WARNING]${RESET} $*"
}

error() {
    >&2 echo -e "${RED}[ERROR]${RESET} $*"
}

die() {
    error "$@"
    exit 1
}

# Usage information
usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Uninstall bash loadable builtins.

OPTIONS:
    -s, --system    Uninstall system-wide installation (requires root)
    -u, --user      Uninstall user installation
    -f, --force     Force uninstall without confirmation
    -h, --help      Show this help message
    -V, --version   Show version information

EXAMPLES:
    # Uninstall user installation
    $SCRIPT_NAME --user

    # Uninstall system-wide (requires sudo)
    sudo $SCRIPT_NAME --system

EOF
}

# Confirm action
confirm() {
    if ((FORCE)); then
        return 0
    fi

    local prompt="$1"
    local response

    read -r -p "$prompt [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Uninstall system-wide
uninstall_system() {
    if [[ $EUID -ne 0 ]]; then
        die "System-wide uninstallation requires root privileges. Run with sudo."
    fi

    if [[ ! -d /usr/local/lib/bash-builtins ]] && [[ ! -f /etc/profile.d/bash-builtins.sh ]]; then
        warn "No system-wide installation found"
        return 1
    fi

    info "Found system-wide installation"

    if ! confirm "Uninstall system-wide bash builtins?"; then
        info "Uninstall cancelled"
        return 1
    fi

    info "Removing system-wide installation..."

    # Remove profile.d script
    if [[ -f /etc/profile.d/bash-builtins.sh ]]; then
        rm -f /etc/profile.d/bash-builtins.sh
        success "Removed /etc/profile.d/bash-builtins.sh"
    fi

    # Remove builtin directory
    if [[ -d /usr/local/lib/bash-builtins ]]; then
        rm -rf /usr/local/lib/bash-builtins
        success "Removed /usr/local/lib/bash-builtins"
    fi

    success "System-wide uninstallation complete"
    echo ""
    warn "Currently loaded builtins in active sessions are still enabled"
    info "Start a new bash session for changes to take effect"
}

# Uninstall user installation
uninstall_user() {
    local user_dir="$HOME/.config/bash-builtins"

    if [[ ! -d "$user_dir" ]]; then
        warn "No user installation found at $user_dir"
        return 1
    fi

    info "Found user installation at $user_dir"

    if ! confirm "Uninstall user bash builtins?"; then
        info "Uninstall cancelled"
        return 1
    fi

    info "Removing user installation..."

    # Remove directory
    rm -rf "$user_dir"
    success "Removed $user_dir"

    # Remove from .bashrc
    if [[ -f "$HOME/.bashrc" ]] && grep -q 'bash-builtins-loader' "$HOME/.bashrc"; then
        info "Removing auto-loader from ~/.bashrc..."

        # Create backup
        cp "$HOME/.bashrc" "$HOME/.bashrc.backup.$(date +%Y%m%d_%H%M%S)"

        # Remove the loader block
        sed -i '/# Load bash loadable builtins/,+4d' "$HOME/.bashrc"
        success "Removed auto-loader from ~/.bashrc (backup created)"
    fi

    success "User uninstallation complete"
    echo ""
    warn "Currently loaded builtins in active sessions are still enabled"
    info "Start a new bash session for changes to take effect"
}

# Main function
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--system)
                SYSTEM_WIDE=1
                shift
                ;;
            -u|--user)
                USER_UNINSTALL=1
                shift
                ;;
            -f|--force)
                FORCE=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -V|--version)
                echo "$SCRIPT_NAME $VERSION"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Validate options
    if ((SYSTEM_WIDE + USER_UNINSTALL == 0)); then
        error "Must specify either --system or --user"
        echo ""
        usage
        exit 1
    fi

    if ((SYSTEM_WIDE + USER_UNINSTALL > 1)); then
        error "Cannot specify both --system and --user"
        exit 1
    fi

    # Run uninstallation
    echo "Bash Loadable Builtins Uninstaller v$VERSION"
    echo "============================================="
    echo ""

    if ((SYSTEM_WIDE)); then
        uninstall_system
    else
        uninstall_user
    fi
}

# Run main function
main "$@"

#fin
