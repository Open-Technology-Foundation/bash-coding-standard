#!/usr/bin/env bash
# install.sh - Installation script for bash loadable builtins
# This script automates the build and installation process

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
declare -i USER_INSTALL=0
declare -i FORCE=0
declare -i SKIP_BUILD=0

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

Install bash loadable builtins for enhanced performance.

OPTIONS:
    -s, --system        Install system-wide (requires root)
    -u, --user          Install for current user only
    -f, --force         Force reinstallation
    -S, --skip-build    Skip build step (use existing .so files)
    -h, --help          Show this help message
    -V, --version       Show version information

EXAMPLES:
    # Install for current user
    $SCRIPT_NAME --user

    # Install system-wide (requires sudo)
    sudo $SCRIPT_NAME --system

    # Force reinstall for user
    $SCRIPT_NAME --user --force

EOF
}

# Check if running in script directory
check_directory() {
    if [[ ! -f "$SCRIPT_DIR/Makefile" ]]; then
        die "Must run from the builtins directory containing Makefile"
    fi
}

# Check for required tools
check_dependencies() {
    local -a missing=()

    for cmd in gcc make; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if ((${#missing[@]} > 0)); then
        error "Missing required tools: ${missing[*]}"
        echo ""
        echo "Install with:"
        echo "  Debian/Ubuntu: sudo apt-get install build-essential bash-builtins"
        echo "  RedHat/Fedora: sudo dnf install gcc make bash-devel"
        exit 1
    fi
}

# Check for bash headers
check_bash_headers() {
    info "Checking for bash headers..."

    local -a header_paths=(
        /usr/lib/bash/loadables.h
        /usr/include/bash/loadables.h
        /usr/local/lib/bash/loadables.h
    )

    for path in "${header_paths[@]}"; do
        if [[ -f "$path" ]]; then
            success "Found bash headers at $path"
            return 0
        fi
    done

    error "Cannot find bash loadables.h header file"
    echo ""
    echo "Install with:"
    echo "  Debian/Ubuntu: sudo apt-get install bash-builtins"
    echo "  RedHat/Fedora: sudo dnf install bash-devel"
    exit 1
}

# Build builtins
build_builtins() {
    if ((SKIP_BUILD)); then
        info "Skipping build step (--skip-build specified)"
        return 0
    fi

    info "Building bash loadable builtins..."

    cd "$SCRIPT_DIR"

    if make clean >/dev/null 2>&1; then
        success "Cleaned previous build"
    fi

    if make; then
        success "Build completed successfully"
    else
        die "Build failed. Check error messages above."
    fi
}

# Verify built files exist
verify_build() {
    info "Verifying built files..."

    local -a required_files=(
        basename.so
        dirname.so
        realpath.so
        head.so
        cut.so
    )

    local -i missing=0
    for file in "${required_files[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
            error "Missing: $file"
            ((missing++))
        fi
    done

    if ((missing > 0)); then
        die "$missing required .so files are missing. Run build first."
    fi

    success "All required files present"
}

# Install system-wide
install_system() {
    if [[ $EUID -ne 0 ]]; then
        die "System-wide installation requires root privileges. Run with sudo."
    fi

    info "Installing system-wide..."

    cd "$SCRIPT_DIR"

    if make install-system; then
        success "System-wide installation complete"
        echo ""
        info "Builtins will be available in new bash sessions"
        info "To enable in current session, run:"
        echo "    source /etc/profile.d/bash-builtins.sh"
        return 0
    else
        die "System-wide installation failed"
    fi
}

# Install for user
install_user() {
    info "Installing for user $USER..."

    cd "$SCRIPT_DIR"

    if make install-user; then
        success "User installation complete"
        echo ""
        info "Builtins will be available in new bash sessions"
        info "To enable in current session, run:"
        echo "    source ~/.config/bash-builtins/bash-builtins-loader.sh ~/.config/bash-builtins"
        return 0
    else
        die "User installation failed"
    fi
}

# Check if already installed
check_existing() {
    if ((FORCE)); then
        return 0
    fi

    if ((SYSTEM_WIDE)) && [[ -d /usr/local/lib/bash-builtins ]]; then
        warn "System-wide installation already exists"
        echo "Use --force to reinstall"
        return 1
    fi

    if ((USER_INSTALL)) && [[ -d "$HOME/.config/bash-builtins" ]]; then
        warn "User installation already exists"
        echo "Use --force to reinstall"
        return 1
    fi

    return 0
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
                USER_INSTALL=1
                shift
                ;;
            -f|--force)
                FORCE=1
                shift
                ;;
            -S|--skip-build)
                SKIP_BUILD=1
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
    if ((SYSTEM_WIDE + USER_INSTALL == 0)); then
        error "Must specify either --system or --user"
        echo ""
        usage
        exit 1
    fi

    if ((SYSTEM_WIDE + USER_INSTALL > 1)); then
        error "Cannot specify both --system and --user"
        exit 1
    fi

    # Run installation steps
    echo "Bash Loadable Builtins Installer v$VERSION"
    echo "==========================================="
    echo ""

    check_directory
    check_dependencies
    check_bash_headers

    if ! check_existing; then
        exit 1
    fi

    build_builtins
    verify_build

    echo ""

    if ((SYSTEM_WIDE)); then
        install_system
    else
        install_user
    fi

    echo ""
    success "Installation completed successfully!"
}

# Run main function
main "$@"

#fin
