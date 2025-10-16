### Progressive State Management

Manage script state by modifying boolean flags based on runtime conditions, separating decision logic from execution.

\`\`\`bash
# Initial flag declarations
declare -i INSTALL_BUILTIN=0
declare -i BUILTIN_REQUESTED=0
declare -i SKIP_BUILTIN=0

# Parse command-line arguments
main() {
  while (($#)); do
    case $1 in
      --builtin)    INSTALL_BUILTIN=1
                    BUILTIN_REQUESTED=1
                    ;;
      --no-builtin) SKIP_BUILTIN=1
                    ;;
    esac
    shift
  done

  # Progressive state management: adjust flags based on runtime conditions

  # If user explicitly requested to skip, disable installation
  if ((SKIP_BUILTIN)); then
    INSTALL_BUILTIN=0
  fi

  # Check if prerequisites are met, adjust flags accordingly
  if ! check_builtin_support; then
    # If user explicitly requested builtins, try to install dependencies
    if ((BUILTIN_REQUESTED)); then
      warn 'bash-builtins package not found, attempting to install...'
      install_bash_builtins || {
        error 'Failed to install bash-builtins package'
        INSTALL_BUILTIN=0  # Disable builtin installation
      }
    else
      # User didn't explicitly request, just skip
      info 'bash-builtins not found, skipping builtin installation'
      INSTALL_BUILTIN=0
    fi
  fi

  # Build phase: disable on failure
  if ((INSTALL_BUILTIN)); then
    if ! build_builtin; then
      error 'Builtin build failed, disabling builtin installation'
      INSTALL_BUILTIN=0
    fi
  fi

  # Execution phase: actions based on final flag state
  install_standalone
  ((INSTALL_BUILTIN)) && install_builtin  # Only runs if still enabled

  show_completion_message
}
\`\`\`

**Pattern structure:**
1. Declare all boolean flags at the top with initial values
2. Parse command-line arguments, setting flags based on user input
3. Progressively adjust flags based on runtime conditions:
   - Dependency checks (disable if prerequisites missing)
   - Build/operation failures (disable dependent features)
   - User preferences override system defaults
4. Execute actions based on final flag state

**Real-world example - conditional builtin installation:**
\`\`\`bash
# Initial state (defaults)
declare -i INSTALL_BUILTIN=0
declare -i BUILTIN_REQUESTED=0
declare -i SKIP_BUILTIN=0

# State progression through script lifecycle:

# 1. User input (--builtin flag)
INSTALL_BUILTIN=1
BUILTIN_REQUESTED=1

# 2. Override check (--no-builtin takes precedence)
((SKIP_BUILTIN)) && INSTALL_BUILTIN=0

# 3. Dependency check (no bash-builtins package)
if ! check_builtin_support; then
  if ((BUILTIN_REQUESTED)); then
    # Try to install, disable on failure
    install_bash_builtins || INSTALL_BUILTIN=0
  else
    # User didn't ask, just disable
    INSTALL_BUILTIN=0
  fi
fi

# 4. Build check (compilation failed)
((INSTALL_BUILTIN)) && ! build_builtin && INSTALL_BUILTIN=0

# 5. Final execution (only runs if INSTALL_BUILTIN=1)
((INSTALL_BUILTIN)) && install_builtin
\`\`\`

**Benefits:**
- Clean separation between decision logic and action
- Easy to trace how flags change throughout execution
- Fail-safe behavior (disable features when prerequisites fail)
- User intent preserved (\`BUILTIN_REQUESTED\` tracks original request)
- Idempotent (same input → same state → same output)

**Guidelines:**
- Group related flags together (e.g., \`INSTALL_*\`, \`SKIP_*\`)
- Use separate flags for user intent vs. runtime state
- Document state transitions with comments
- Apply state changes in logical order (parse → validate → execute)
- Never modify flags during execution phase (only in setup/validation)

**Rationale:** This pattern allows scripts to adapt to runtime conditions while maintaining clarity about why decisions were made. It's especially useful for installation scripts where features may need to be disabled based on system capabilities or build failures.
