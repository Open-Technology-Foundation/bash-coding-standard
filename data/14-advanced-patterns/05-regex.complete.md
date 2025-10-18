## Regular Expression Guidelines

Best practices for using regular expressions in Bash.

\`\`\`bash
# Use POSIX character classes for portability
[[ "$var" =~ ^[[:alnum:]]+$ ]]      # Alphanumeric only
[[ "$var" =~ [[:space:]] ]]         # Contains whitespace
[[ "$var" =~ ^[[:digit:]]+$ ]]      # Digits only
[[ "$var" =~ ^[[:xdigit:]]+$ ]]     # Hexadecimal

# Store complex patterns in readonly variables
readonly -- EMAIL_REGEX='^[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}$'
readonly -- IPV4_REGEX='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
readonly -- UUID_REGEX='^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$'

# Usage
[[ "$email" =~ $EMAIL_REGEX ]] || die 1 'Invalid email format'

# Capture groups
if [[ "$version" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  major="${BASH_REMATCH[1]}"
  minor="${BASH_REMATCH[2]}"
  patch="${BASH_REMATCH[3]}"
fi
\`\`\`
