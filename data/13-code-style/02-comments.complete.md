#### Comments

Focus comments on explaining **WHY** (rationale, business logic, non-obvious decisions) rather than **WHAT** (which the code already shows):

\`\`\`bash
# Section separator (80 dashes)
# --------------------------------------------------------------------------------

# ✓ Good - explains WHY (rationale and special cases)
# PROFILE_DIR intentionally hardcoded to /etc/profile.d for system-wide bash profile
# integration, regardless of PREFIX. This ensures builtins are available in all
# user sessions. To override, modify this line or use a custom install method.
declare -- PROFILE_DIR=/etc/profile.d

((max_depth > 0)) || max_depth=255  # -1 means unlimited (WHY -1 is special)

# If user explicitly requested --builtin, try to install dependencies
if ((BUILTIN_REQUESTED)); then
  warn 'bash-builtins package not found, attempting to install...'
fi

# ✗ Bad - restates WHAT the code already shows
# Set PROFILE_DIR to /etc/profile.d
declare -- PROFILE_DIR=/etc/profile.d

# Check if max_depth is greater than 0, otherwise set to 255
((max_depth > 0)) || max_depth=255

# If BUILTIN_REQUESTED is non-zero
if ((BUILTIN_REQUESTED)); then
  # Print warning message
  warn 'bash-builtins package not found, attempting to install...'
fi
\`\`\`

**Good comment patterns:**
- Explain non-obvious business rules or edge cases
- Document intentional deviations from normal patterns
- Clarify complex logic that isn't immediately apparent
- Note why a specific approach was chosen over alternatives
- Warn about subtle gotchas or side effects

**Avoid commenting:**
- Simple variable assignments
- Obvious conditionals
- Standard patterns already documented in this style guide
- Code that is self-explanatory through good naming
\`\`\`
