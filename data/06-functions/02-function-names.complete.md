### Function Names
Use lowercase with underscores to match shell conventions and avoid conflicts with built-in commands.

```bash
# ✓ Good - lowercase with underscores
my_function() {
  …
}

process_log_file() {
  …
}

# ✓ Private functions use leading underscore
_my_private_function() {
  …
}

_validate_input() {
  …
}

# ✗ Avoid - CamelCase or UPPER_CASE
MyFunction() {      # Don't do this
  …
}

PROCESS_FILE() {    # Don't do this
  …
}
```

**Rationale:**
- **Lowercase with underscores**: Matches standard Unix/Linux utility naming (e.g., `grep`, `sed`, `file_name`)
- **Avoid CamelCase**: Can be confused with variables or commands
- **Underscore prefix for private**: Clear signal that function is for internal use only
- **Consistency**: All built-in bash commands are lowercase

**Anti-patterns to avoid:**
```bash
# ✗ Don't override built-in commands without good reason
cd() {           # Dangerous - overrides built-in cd
  builtin cd "$@" && ls
}

# ✓ If you must wrap built-ins, use a different name
change_dir() {
  builtin cd "$@" && ls
}

# ✗ Don't use special characters
my-function() {  # Dash creates issues in some contexts
  …
}
```
