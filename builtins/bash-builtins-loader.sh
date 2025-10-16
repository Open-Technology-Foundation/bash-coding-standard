# bash-builtins-loader.sh
# Auto-loader for bash loadable builtins
# This file is sourced by bash to automatically enable custom builtins
#
# System-wide: /etc/profile.d/bash-builtins.sh
# User-local: ~/.config/bash-builtins/bash-builtins-loader.sh

# Only load for interactive bash shells
[[ $- == *i* ]] || return 0

# Only run in bash
[ -n "$BASH_VERSION" ] || return 0

# Determine builtin directory
if [ -n "$1" ]; then
    # Directory passed as argument (user installation)
    BUILTIN_DIR="$1"
elif [ -d /usr/local/lib/bash-builtins ]; then
    BUILTIN_DIR=/usr/local/lib/bash-builtins
elif [ -d /usr/lib/bash-builtins ]; then
    BUILTIN_DIR=/usr/lib/bash-builtins
elif [ -d "$HOME/.config/bash-builtins" ]; then
    BUILTIN_DIR="$HOME/.config/bash-builtins"
else
    # No builtin directory found
    return 0
fi

# List of builtins to load
declare -a BUILTINS=(
    basename
    dirname
    realpath
    head
    cut
)

# Track successfully loaded builtins
declare -i LOADED_COUNT=0
declare -i FAILED_COUNT=0

# Load each builtin
for builtin_name in "${BUILTINS[@]}"; do
    builtin_file="$BUILTIN_DIR/${builtin_name}.so"

    if [ -f "$builtin_file" ]; then
        if enable -f "$builtin_file" "$builtin_name" 2>/dev/null; then
            ((LOADED_COUNT++))
        else
            ((FAILED_COUNT++))
        fi
    fi
done

# Optional: Show status (only if BASH_BUILTINS_VERBOSE is set)
if [ -n "$BASH_BUILTINS_VERBOSE" ] && ((LOADED_COUNT > 0)); then
    echo "Loaded $LOADED_COUNT bash builtin(s) from $BUILTIN_DIR"
    if ((FAILED_COUNT > 0)); then
        echo "Warning: Failed to load $FAILED_COUNT builtin(s)"
    fi
fi

# Export function to check if builtins are loaded
check_builtins() {
    echo "Bash Loadable Builtins Status:"
    echo "==============================="
    local -i total=0
    local -i loaded=0

    for builtin_name in basename dirname realpath head cut; do
        ((total++))
        if type -t "$builtin_name" 2>/dev/null | grep -q builtin; then
            echo "  ✓ $builtin_name (builtin)"
            ((loaded++))
        elif command -v "$builtin_name" >/dev/null 2>&1; then
            echo "  ✗ $builtin_name (external: $(command -v "$builtin_name"))"
        else
            echo "  ✗ $builtin_name (not found)"
        fi
    done

    echo ""
    echo "Summary: $loaded/$total loaded as builtins"

    if ((loaded == total)); then
        echo "Status: All builtins loaded successfully!"
        return 0
    elif ((loaded > 0)); then
        echo "Status: Partially loaded"
        return 1
    else
        echo "Status: No builtins loaded"
        return 2
    fi
}

# Export function to reload builtins
reload_builtins() {
    echo "Reloading bash builtins..."

    # Disable existing builtins
    for builtin_name in "${BUILTINS[@]}"; do
        enable -d "$builtin_name" 2>/dev/null
    done

    # Re-source this script
    if [ -f /etc/profile.d/bash-builtins.sh ]; then
        source /etc/profile.d/bash-builtins.sh
    elif [ -f "$HOME/.config/bash-builtins/bash-builtins-loader.sh" ]; then
        source "$HOME/.config/bash-builtins/bash-builtins-loader.sh" "$HOME/.config/bash-builtins"
    fi

    echo "Reload complete."
    check_builtins
}

# Export functions for user convenience
export -f check_builtins reload_builtins

# Clean up
unset BUILTIN_DIR BUILTINS LOADED_COUNT FAILED_COUNT builtin_name builtin_file
