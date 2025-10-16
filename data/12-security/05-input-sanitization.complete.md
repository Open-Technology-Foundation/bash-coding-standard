### Input Sanitization

**Always validate and sanitize user input to prevent security issues.**

**Rationale:**
- **Prevent injection attacks**: User input could contain malicious code
- **Prevent directory traversal**: `../../../etc/passwd` type attacks
- **Validate data types**: Ensure input matches expected format
- **Fail early**: Reject invalid input before processing
- **Defense in depth**: Never trust user input

**1. Filename validation:**

\`\`\`bash
# Validate filename - no directory traversal, no special chars
sanitize_filename() {
  local -- name="$1"

  # Reject empty input
  [[ -n "$name" ]] || die 22 'Filename cannot be empty'

  # Remove directory traversal attempts
  name="${name//\.\./}"  # Remove all ..
  name="${name//\//}"    # Remove all /

  # Allow only safe characters: alphanumeric, dot, underscore, hyphen
  if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    die 22 "Invalid filename '$name': contains unsafe characters"
  fi

  # Reject hidden files (starting with .)
  [[ "$name" =~ ^\\. ]] && die 22 "Filename cannot start with dot: $name"

  # Reject names that are too long
  ((${#name} > 255)) && die 22 "Filename too long (max 255 chars): $name"

  echo "$name"
}

# Usage
user_filename=$(sanitize_filename "$user_input")
safe_path="$SAFE_DIR/$user_filename"
\`\`\`

**2. Numeric input validation:**

\`\`\`bash
# Validate integer (positive or negative)
validate_integer() {
  local -- input="$1"
  [[ -n "$input" ]] || die 22 'Number cannot be empty'

  if [[ ! "$input" =~ ^-?[0-9]+$ ]]; then
    die 22 "Invalid integer: '$input'"
  fi
  echo "$input"
}

# Validate positive integer
validate_positive_integer() {
  local -- input="$1"
  [[ -n "$input" ]] || die 22 'Number cannot be empty'

  if [[ ! "$input" =~ ^[0-9]+$ ]]; then
    die 22 "Invalid positive integer: '$input'"
  fi

  # Check for leading zeros (often indicates octal interpretation)
  [[ "$input" =~ ^0[0-9] ]] && die 22 "Number cannot have leading zeros: $input"

  echo "$input"
}

# Validate with range check
validate_port() {
  local -- port="$1"
  port=$(validate_positive_integer "$port")

  ((port >= 1 && port <= 65535)) || die 22 "Port must be 1-65535: $port"
  echo "$port"
}
\`\`\`

**3. Path validation:**

\`\`\`bash
# Validate path is within allowed directory
validate_path() {
  local -- input_path="$1"
  local -- allowed_dir="$2"

  # Resolve to absolute path
  local -- real_path
  real_path=$(realpath -e -- "$input_path") || die 22 "Invalid path: $input_path"

  # Ensure path is within allowed directory
  if [[ "$real_path" != "$allowed_dir"* ]]; then
    die 5 "Path outside allowed directory: $real_path"
  fi

  echo "$real_path"
}

# Usage
safe_path=$(validate_path "$user_path" "/var/app/data")
\`\`\`

**4. Email validation:**

\`\`\`bash
validate_email() {
  local -- email="$1"
  [[ -n "$email" ]] || die 22 'Email cannot be empty'

  # Basic email regex (not RFC-compliant but sufficient for most cases)
  local -- email_regex='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

  if [[ ! "$email" =~ $email_regex ]]; then
    die 22 "Invalid email format: $email"
  fi

  # Check length limits
  ((${#email} <= 254)) || die 22 "Email too long (max 254 chars): $email"

  echo "$email"
}
\`\`\`

**5. URL validation:**

\`\`\`bash
validate_url() {
  local -- url="$1"
  [[ -n "$url" ]] || die 22 'URL cannot be empty'

  # Only allow http and https schemes
  if [[ ! "$url" =~ ^https?:// ]]; then
    die 22 "URL must start with http:// or https://: $url"
  fi

  # Reject URLs with credentials (security risk)
  if [[ "$url" =~ @ ]]; then
    die 22 'URL cannot contain credentials'
  fi

  echo "$url"
}
\`\`\`

**6. Whitelist validation:**

\`\`\`bash
# Validate input against whitelist
validate_choice() {
  local -- input="$1"
  shift
  local -a valid_choices=("$@")

  local choice
  for choice in "${valid_choices[@]}"; do
    [[ "$input" == "$choice" ]] && return 0
  done

  die 22 "Invalid choice '$input'. Valid: ${valid_choices[*]}"
}

# Usage
declare -a valid_actions=('start' 'stop' 'restart' 'status')
validate_choice "$user_action" "${valid_actions[@]}"
\`\`\`

**7. Username validation:**

\`\`\`bash
validate_username() {
  local -- username="$1"
  [[ -n "$username" ]] || die 22 'Username cannot be empty'

  # Standard Unix username rules
  if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    die 22 "Invalid username: $username"
  fi

  # Check length (typically max 32 chars on Unix)
  ((${#username} >= 1 && ${#username} <= 32)) || \
    die 22 "Username must be 1-32 characters: $username"

  echo "$username"
}
\`\`\`

**8. Command injection prevention:**

\`\`\`bash
# NEVER pass user input directly to shell
# ✗ DANGEROUS - command injection vulnerability
user_file="$1"
cat "$user_file"  # If user_file="; rm -rf /", disaster!

# ✓ Safe - validate first
validate_filename "$user_file"
cat -- "$user_file"  # Use -- to prevent option injection

# ✗ DANGEROUS - using eval with user input
eval "$user_command"  # NEVER DO THIS!

# ✓ Safe - whitelist allowed commands
case "$user_command" in
  start|stop|restart) systemctl "$user_command" myapp ;;
  *) die 22 "Invalid command: $user_command" ;;
esac
\`\`\`

**9. Option injection prevention:**

\`\`\`bash
# User input could be malicious option like "--delete-all"
user_file="$1"

# ✗ Dangerous - if user_file="--delete-all", disaster!
rm "$user_file"

# ✓ Safe - use -- separator
rm -- "$user_file"

# ✗ Dangerous - filename starting with -
ls "$user_file"  # If user_file="-la", becomes: ls -la

# ✓ Safe - use -- or prepend ./
ls -- "$user_file"
ls ./"$user_file"
\`\`\`

**10. SQL injection prevention (if generating SQL):**

\`\`\`bash
# ✗ DANGEROUS - SQL injection vulnerability
user_id="$1"
query="SELECT * FROM users WHERE id=$user_id"  # user_id="1 OR 1=1"

# ✓ Safe - validate input type first
user_id=$(validate_positive_integer "$user_id")
query="SELECT * FROM users WHERE id=$user_id"

# ✓ Better - use parameterized queries (with proper DB tools)
# This is just bash demo - use proper DB library in production
\`\`\`

**Complete validation example:**

\`\`\`bash
#!/usr/bin/env bash
set -euo pipefail

# Validation functions
validate_positive_integer() {
  local input="$1"
  [[ -n "$input" && "$input" =~ ^[0-9]+$ ]] || \
    die 22 "Invalid positive integer: $input"
  echo "$input"
}

sanitize_filename() {
  local name="$1"
  name="${name//\.\./}"
  name="${name//\//}"
  [[ "$name" =~ ^[a-zA-Z0-9._-]+$ ]] || \
    die 22 "Invalid filename: $name"
  echo "$name"
}

# Parse and validate arguments
while (($#)); do case $1 in
  -c|--count)     noarg "$@"; shift
                  count=$(validate_positive_integer "$1") ;;
  -f|--file)      noarg "$@"; shift
                  filename=$(sanitize_filename "$1") ;;
  -*)             die 22 "Invalid option: $1" ;;
  *)              die 2 "Unexpected argument: $1" ;;
esac; shift; done

# Validate required arguments provided
[[ -n "${count:-}" ]] || die 2 'Missing required option: --count'
[[ -n "${filename:-}" ]] || die 2 'Missing required option: --file'

# Use validated input safely
for ((i=0; i<count; i+=1)); do
  echo "Processing iteration $i" >> "$filename"
done
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ WRONG - trusting user input
rm -rf "$user_dir"  # user_dir="/" = disaster!

# ✓ Correct - validate first
validate_path "$user_dir" "/safe/base/dir"
rm -rf "$user_dir"

# ✗ WRONG - weak validation
[[ -n "$filename" ]] && process "$filename"  # Not enough!

# ✓ Correct - thorough validation
filename=$(sanitize_filename "$filename")
process "$filename"

# ✗ WRONG - blacklist approach (always incomplete)
[[ "$input" != *'rm'* ]] || die 1 'Invalid input'  # Can be bypassed!

# ✓ Correct - whitelist approach
[[ "$input" =~ ^[a-zA-Z0-9]+$ ]] || die 1 'Invalid input'
\`\`\`

**Security principles:**

1. **Whitelist over blacklist**: Define what IS allowed, not what isn't
2. **Validate early**: Check input before any processing
3. **Fail securely**: Reject invalid input with clear error
4. **Use `--` separator**: Prevent option injection in commands
5. **Never use `eval`**: Especially not with user input
6. **Absolute paths**: When possible, use full paths to prevent PATH manipulation
7. **Principle of least privilege**: Run with minimum necessary permissions

**Summary:**
- **Always validate** user input before use
- **Use whitelist** validation (regex, allowed values)
- **Check type, format, range, length**
- **Use `--` separator** in commands
- **Never trust** user input, even if it "looks safe"
