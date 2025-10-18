## Static Strings and Constants

**Always use single quotes for string literals that contain no variables:**

```bash
# Message functions - single quotes for static strings
info 'Checking prerequisites...'
success 'Prerequisites check passed'
warn 'bash-builtins package not found'
error 'Failed to install package'

# Variable assignments
SCRIPT_DESC='Mail Tools Installation Script'
DEFAULT_PATH='/usr/local/bin'
MESSAGE='Operation completed successfully'

# Conditionals with static strings
[[ "$status" == 'success' ]]     # ✓ Correct
[[ "$status" == "success" ]]     # ✗ Unnecessary double quotes
```

**Rationale:**

1. **Performance**: Single quotes are slightly faster (no parsing for variables/escapes)
2. **Clarity**: Signals to reader "this is a literal string, no substitution"
3. **Safety**: Prevents accidental variable expansion or command substitution
4. **Predictability**: What you see is exactly what you get (WYSIWYG)
5. **Escaping**: No need to escape special characters like `$`, `` ` ``, `\`, `!`

**When single quotes are required:**

```bash
# Strings with special characters
msg='The variable $PATH will not expand here'
cmd='This `command` will not execute'
note='Backslashes \ do not escape anything in single quotes'

# SQL queries and regex patterns
sql='SELECT * FROM users WHERE name = "John"'
regex='^\$[0-9]+\.[0-9]{2}$'  # Matches $12.34

# Shell commands stored as strings
find_cmd='find /tmp -name "*.log" -mtime +7 -delete'
```

**When double quotes are needed instead:**

```bash
# When variables must be expanded
info "Found $count files in $directory"
echo "Current user: $USER"
warn "File $filename does not exist"

# When command substitution is needed
msg="Current time: $(date +%H:%M:%S)"
info "Script running as $(whoami)"

# When escape sequences are needed
echo "Line 1\nLine 2"  # \n processed in double quotes
tab="Column1\tColumn2"  # \t processed in double quotes
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - double quotes for static strings
info "Checking prerequisites..."  # No variables, use single quotes
error "Failed to connect"          # No variables, use single quotes
[[ "$status" == "active" ]]        # Right side should be single-quoted

# ✓ Correct - single quotes for static content
info 'Checking prerequisites...'
error 'Failed to connect'
[[ "$status" == 'active' ]]

# ✗ Wrong - unnecessary escaping in double quotes
msg="The cost is \$5.00"           # Must escape $
path="C:\\Users\\John"             # Must escape backslashes

# ✓ Correct - no escaping needed in single quotes
msg='The cost is $5.00'
path='C:\Users\John'

# ✗ Wrong - trying to use variables in single quotes
name='John'
greeting='Hello, $name'  # ✗ $name not expanded, greeting = "Hello, $name"

# ✓ Correct - use double quotes when variables needed
name='John'
greeting="Hello, $name"  # ✓ greeting = "Hello, John"
```

**Combining single and double quotes:**

```bash
# When you need both variable expansion and literal single quotes
msg="It's $count o'clock"  # ✓ Works - single quote inside double quotes

# When you need both static text and variables
echo 'Static text: ' "$variable" ' more static'

# Or use double quotes for everything when mixing
echo "Static text: $variable more static"
```

**Special case - empty strings:**

```bash
# Both are equivalent for empty strings, but single quotes are preferred
var=''   # ✓ Preferred
var=""   # ✓ Also acceptable

# For consistency, use single quotes
DEFAULT_VALUE=''
EMPTY_STRING=''
```

**Summary rule:**
- **Single quotes `'...'`**: For all static strings (no variables, no escapes)
- **Double quotes `"..."`**: When you need variable expansion or command substitution
- **Consistency**: Using single quotes consistently for static strings makes the code more scannable - when you see double quotes, you know to look for variables or substitutions
