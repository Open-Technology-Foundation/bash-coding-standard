### Variables in Conditionals

**Always quote variables in test expressions to prevent word splitting and glob expansion, even when the variable is guaranteed to contain a safe value. Variable quoting in conditionals is mandatory; static comparison values follow normal quoting rules (single quotes for literals, unquoted for one-word values).**

**Rationale:**

- **Word Splitting Protection**: Unquoted variables undergo word splitting, breaking multi-word values into separate tokens
- **Glob Expansion Safety**: Unquoted variables trigger pathname expansion if they contain wildcards (`*`, `?`, `[`)
- **Whitespace Handling**: Quoted variables preserve leading/trailing whitespace and internal spacing
- **Empty Value Safety**: Unquoted empty variables disappear entirely, causing syntax errors in conditionals
- **Consistent Behavior**: Quoting ensures predicable behavior regardless of variable content
- **Security**: Prevents injection attacks where malicious input could exploit word splitting

**Always quote variables:**

**1. File test operators:**

```bash
# File existence tests
[[ -f "$file" ]]         # ✓ Correct - variable quoted
[[ -f $file ]]           # ✗ Wrong - word splitting if $file has spaces

# Directory tests
[[ -d "$path" ]]         # ✓ Correct
[[ -d $path ]]           # ✗ Wrong

# Readable/writable tests
[[ -r "$config_file" ]]  # ✓ Correct
[[ -w "$log_file" ]]     # ✓ Correct

# All file test operators require quoting
[[ -e "$file" ]]         # Exists
[[ -s "$file" ]]         # Non-empty
[[ -x "$binary" ]]       # Executable
[[ -L "$link" ]]         # Symbolic link
```

**2. String comparisons:**

```bash
# Equality/inequality
[[ "$name" == "$expected" ]]    # ✓ Correct - both variables quoted
[[ "$name" != "$other" ]]       # ✓ Correct

# Pattern matching (variable quoted, pattern may be quoted or not)
[[ "$filename" == *.txt ]]      # ✓ Correct - pattern unquoted for globbing
[[ "$filename" == '*.txt' ]]    # ✓ Also correct - literal match (no globbing)

# String emptiness
[[ -n "$value" ]]               # ✓ Correct - non-empty test
[[ -z "$value" ]]               # ✓ Correct - empty test
```

**3. Integer comparisons (in [[ ]]):**

```bash
# Numeric comparisons
[[ "$count" -eq 0 ]]            # ✓ Correct - variable quoted
[[ "$count" -gt 10 ]]           # ✓ Correct
[[ "$age" -le 18 ]]             # ✓ Correct

# All numeric operators
[[ "$a" -eq "$b" ]]             # Equal
[[ "$a" -ne "$b" ]]             # Not equal
[[ "$a" -lt "$b" ]]             # Less than
[[ "$a" -le "$b" ]]             # Less than or equal
[[ "$a" -gt "$b" ]]             # Greater than
[[ "$a" -ge "$b" ]]             # Greater than or equal
```

**4. Logical operators:**

```bash
# AND
[[ -f "$file" && -r "$file" ]]  # ✓ Correct - both variables quoted

# OR
[[ -f "$file1" || -f "$file2" ]] # ✓ Correct

# NOT
[[ ! -f "$file" ]]               # ✓ Correct

# Complex conditions
[[ -f "$config" && -r "$config" && -s "$config" ]] # ✓ All quoted
```

**Static comparison values - quoting rules:**

**1. Single-word literals (can be unquoted):**

```bash
# One-word values - unquoted acceptable
[[ "$action" == start ]]        # ✓ Acceptable - one-word literal
[[ "$action" == stop ]]         # ✓ Acceptable

# But single quotes also correct
[[ "$action" == 'start' ]]      # ✓ Also correct - explicit literal
[[ "$action" == 'stop' ]]       # ✓ Also correct
```

**2. Multi-word literals (must use single quotes):**

```bash
# Multi-word values - single quotes required
[[ "$message" == 'hello world' ]]        # ✓ Correct
[[ "$message" == hello world ]]          # ✗ Wrong - syntax error

# Sentences/phrases
[[ "$status" == 'operation complete' ]]  # ✓ Correct
[[ "$error" == 'file not found' ]]       # ✓ Correct
```

**3. Values with special characters (must be quoted):**

```bash
# Special characters - single quotes required
[[ "$input" == 'user@domain.com' ]]      # ✓ Correct - contains @
[[ "$path" == '/usr/local/bin' ]]        # ✓ Correct - contains /
[[ "$pattern" == '*.txt' ]]              # ✓ Correct - literal asterisk

# Avoid double quotes for static literals
[[ "$path" == "/usr/local/bin" ]]        # ✗ Unnecessary - no variables
```

**Pattern matching in conditionals:**

**1. Glob patterns (right side unquoted for matching):**

```bash
# Glob pattern matching - right side unquoted
[[ "$filename" == *.txt ]]               # ✓ Matches any .txt file
[[ "$filename" == *.@(jpg|png) ]]        # ✓ Extended glob pattern
[[ "$filename" == data_[0-9]*.csv ]]     # ✓ Pattern with character class

# Quoting pattern makes it literal
[[ "$filename" == '*.txt' ]]             # ✓ Matches literal "*.txt" only
```

**2. Regex patterns (use =~ operator):**

```bash
# Regex matching - pattern unquoted or in variable
[[ "$email" =~ ^[a-z]+@[a-z]+\.[a-z]+$ ]]  # ✓ Regex pattern unquoted
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] # ✓ Semver pattern

# Pattern in variable (must be unquoted variable)
pattern='^[0-9]{3}-[0-9]{4}$'
[[ "$phone" =~ $pattern ]]               # ✓ Correct - pattern variable unquoted
[[ "$phone" =~ "$pattern" ]]             # ✗ Wrong - treats as literal string
```

**Complete example with comprehensive quoting:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Validate file with proper quoting
validate_file() {
  local -- file="$1"
  local -- required_ext="$2"

  # File existence - variable quoted
  if [[ ! -f "$file" ]]; then
    error "File not found: $file"
    return 2
  fi

  # Readability - variable quoted
  if [[ ! -r "$file" ]]; then
    error "File not readable: $file"
    return 5
  fi

  # Non-empty - variable quoted
  if [[ ! -s "$file" ]]; then
    error "File is empty: $file"
    return 22
  fi

  # Extension check - pattern matching
  if [[ "$file" == *."$required_ext" ]]; then
    info "File has correct extension: .$required_ext"
  else
    error "File must have .$required_ext extension"
    return 22
  fi

  return 0
}

# Process configuration with string comparisons
process_config() {
  local -- config_file="$1"
  local -- line
  local -- key
  local -- value

  # Read configuration
  while IFS='=' read -r key value; do
    # Empty line check - variable quoted
    [[ -z "$key" ]] && continue

    # Comment line check - pattern matching
    [[ "$key" == \#* ]] && continue

    # String comparison - both sides quoted
    if [[ "$key" == 'timeout' ]]; then
      # Integer comparison - variable quoted
      if [[ "$value" -gt 0 ]]; then
        info "Timeout: $value seconds"
      else
        error "Timeout must be positive: $value"
        return 22
      fi
    elif [[ "$key" == 'mode' ]]; then
      # Multi-value comparison - static values single-quoted
      if [[ "$value" == 'production' || "$value" == 'development' ]]; then
        info "Mode: $value"
      else
        error "Invalid mode: $value (must be 'production' or 'development')"
        return 22
      fi
    fi
  done < "$config_file"
}

# Validate user input with comprehensive checks
validate_input() {
  local -- input="$1"
  local -- email_pattern='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

  # Empty check - variable quoted
  if [[ -z "$input" ]]; then
    error 'Input cannot be empty'
    return 22
  fi

  # Length check - string comparison
  if [[ "${#input}" -lt 3 ]]; then
    error "Input too short: minimum 3 characters"
    return 22
  fi

  # Pattern matching - glob
  if [[ "$input" == admin* ]]; then
    warn "Input starts with 'admin' - reserved prefix"
    return 1
  fi

  # Regex matching - pattern in variable
  if [[ "$input" =~ $email_pattern ]]; then
    info "Valid email format: $input"
  else
    error "Invalid email format: $input"
    return 22
  fi

  return 0
}

main() {
  local -- test_file='data.txt'
  local -- test_config='config.conf'
  local -- test_email='user@example.com'

  # Validate file
  if validate_file "$test_file" 'txt'; then
    success "File validation passed: $test_file"
  else
    die $? "File validation failed: $test_file"
  fi

  # Process configuration
  if [[ -f "$test_config" ]]; then
    process_config "$test_config"
  else
    warn "Config file not found: $test_config (using defaults)"
  fi

  # Validate input
  if validate_input "$test_email"; then
    success "Input validation passed: $test_email"
  else
    die $? "Input validation failed: $test_email"
  fi
}

main "$@"

#fin
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - unquoted variable in file test
[[ -f $file ]]
# If $file contains spaces, this becomes:
# [[ -f my file.txt ]]  # Syntax error!

# ✓ Correct - quoted variable
[[ -f "$file" ]]

# ✗ Wrong - unquoted variable with glob characters
file='*.txt'
[[ -f $file ]]  # Expands to all .txt files!

# ✓ Correct - quoted variable
[[ -f "$file" ]]  # Tests for literal "*.txt" file

# ✗ Wrong - unquoted empty variable
name=''
[[ -z $name ]]  # Becomes: [[ -z ]] - syntax error!

# ✓ Correct - quoted variable
[[ -z "$name" ]]  # Correctly tests for empty string

# ✗ Wrong - unquoted variable in string comparison
[[ $action == start ]]
# If $action has spaces: "start server"
# Becomes: [[ start server == start ]]  # Syntax error!

# ✓ Correct - quoted variable
[[ "$action" == start ]]

# ✗ Wrong - double quotes for static literal
[[ "$mode" == "production" ]]

# ✓ Correct - single quotes for static literal
[[ "$mode" == 'production' ]]

# Or unquoted for one-word literal
[[ "$mode" == production ]]

# ✗ Wrong - unquoted pattern variable in regex
pattern='^test'
[[ $input =~ "$pattern" ]]  # Wrong - double quotes make it literal

# ✓ Correct - unquoted pattern variable
pattern='^test'
[[ "$input" =~ $pattern ]]  # Correct - regex matching

# ✗ Wrong - inconsistent quoting
[[ -f $file && -r "$file" ]]  # Inconsistent!

# ✓ Correct - consistent quoting
[[ -f "$file" && -r "$file" ]]

# ✗ Wrong - unquoted integer variable
[[ $count -eq 0 ]]
# If $count is empty or has spaces, syntax error

# ✓ Correct - quoted integer variable
[[ "$count" -eq 0 ]]

# ✗ Wrong - multi-word literal unquoted
[[ "$message" == hello world ]]  # Syntax error

# ✓ Correct - multi-word literal in single quotes
[[ "$message" == 'hello world' ]]
```

**Edge cases and special scenarios:**

**1. Variables containing dashes:**

```bash
# Variable with leading dash
arg='-v'

# ✗ Wrong - unquoted could be interpreted as option
[[ $arg == '-v' ]]  # Might cause issues

# ✓ Correct - quoted protects against option interpretation
[[ "$arg" == '-v' ]]
```

**2. Null vs empty strings:**

```bash
# Unset variable
unset var

# ✓ Correct - safely tests unset variables
[[ -z "$var" ]]      # True (empty)
[[ -n "$var" ]]      # False (not empty)

# Works even with set -u (nounset)
[[ -z "${var:-}" ]]  # Safe with nounset
```

**3. Pattern matching with quotes:**

```bash
# Glob pattern matching
[[ "$file" == *.txt ]]       # ✓ Pattern matching (glob)
[[ "$file" == '*.txt' ]]     # ✓ Literal string match
[[ "$file" == "*.txt" ]]     # ✓ Literal string match (unnecessary double quotes)

# Know which behavior you want!
```

**4. Case-insensitive comparisons:**

```bash
# Use nocasematch for case-insensitive glob
shopt -s nocasematch

[[ "$input" == yes ]]        # Matches: yes, YES, Yes, YeS, etc.

shopt -u nocasematch
```

**5. Regex with special characters:**

```bash
# Regex pattern with backslashes
[[ "$version" =~ ^[0-9]+\.[0-9]+$ ]]  # ✓ Correct - literal regex

# Pattern in variable - no backslash escaping needed
pattern='^[0-9]+\.[0-9]+$'
[[ "$version" =~ $pattern ]]  # ✓ Correct
```

**Testing conditional quoting:**

```bash
# Test word splitting protection
test_word_splitting() {
  local -- file='my file.txt'

  # This should succeed with quoting
  [[ -f "$file" ]] || info "File not found (expected): $file"

  # Test glob protection
  local -- pattern='*.txt'
  [[ -f "$pattern" ]] || info "Pattern file not found (expected)"

  info 'Word splitting tests passed'
}

# Test empty variable handling
test_empty_variables() {
  local -- empty=''

  # Empty string tests
  [[ -z "$empty" ]] || die 1 'Empty test failed'
  [[ ! -n "$empty" ]] || die 1 'Non-empty test failed'

  info 'Empty variable tests passed'
}

# Test pattern matching
test_pattern_matching() {
  local -- filename='test.txt'

  # Glob pattern
  [[ "$filename" == *.txt ]] || die 1 'Glob pattern failed'

  # Literal pattern
  [[ "$filename" == '*.txt' ]] && die 1 'Literal pattern should not match'

  info 'Pattern matching tests passed'
}
```

**When old test [ ] is used (legacy code):**

```bash
# Old test command - MUST quote variables (no exceptions)
[ -f "$file" ]               # ✓ Correct
[ -f $file ]                 # ✗ Wrong - very dangerous!

# String comparisons - MUST quote
[ "$var" = "value" ]         # ✓ Correct (= not ==)
[ $var = value ]             # ✗ Wrong - will fail with spaces

# Modern [[ ]] is preferred - more forgiving but still quote
[[ -f "$file" ]]             # ✓ Correct (preferred)
```

**Summary:**

- **Always quote variables** in all conditional tests (`[[ ]]` or `[ ]`)
- **File tests**: Quote the variable: `[[ -f "$file" ]]`
- **String comparisons**: Quote variables, use single quotes for static literals: `[[ "$var" == 'value' ]]`
- **Integer comparisons**: Quote variables: `[[ "$count" -eq 0 ]]`
- **Pattern matching**: Quote variable, leave pattern unquoted for globbing: `[[ "$file" == *.txt ]]`
- **Regex matching**: Quote variable, leave pattern unquoted: `[[ "$input" =~ $pattern ]]`
- **Static literals**: Use single quotes for multi-word or special chars, can omit quotes for one-word literals
- **Consistency**: Quote all variables consistently throughout conditional
- **Safety**: Quoting prevents word splitting, glob expansion, and injection attacks

**Key principle:** Variable quoting in conditionals is not optional - it's mandatory. Every variable reference in a test expression should be quoted to ensure safe, predictable behavior. Static comparison values follow the normal quoting rules: single quotes for literals, but one-word values can be unquoted. When in doubt, quote everything.
