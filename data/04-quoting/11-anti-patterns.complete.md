### Anti-Patterns (What NOT to Do)

**This section catalogues common quoting mistakes that lead to bugs, security vulnerabilities, and poor code quality. Each anti-pattern is shown with the incorrect form (✗) and the correct alternative (✓). Understanding these anti-patterns is critical for writing robust, maintainable Bash scripts.**

**Rationale for avoiding these anti-patterns:**

- **Security**: Improper quoting enables code injection and command injection attacks
- **Reliability**: Unquoted variables cause word splitting and glob expansion bugs
- **Consistency**: Mixed quoting styles make code harder to read and maintain
- **Performance**: Unnecessary quoting/bracing adds parsing overhead
- **Clarity**: Wrong quote choice obscures intent and confuses readers
- **Maintenance**: Anti-patterns make scripts fragile and error-prone

**Category 1: Double quotes for static strings**

This is the most common anti-pattern in Bash scripts.

```bash
# ✗ Wrong - double quotes for static strings (no variables)
info "Checking prerequisites..."
success "Operation completed"
error "File not found"
readonly ERROR_MSG="Invalid input"

# ✓ Correct - single quotes for static strings
info 'Checking prerequisites...'
success 'Operation completed'
error 'File not found'
readonly ERROR_MSG='Invalid input'

# ✗ Wrong - double quotes for multi-line static strings
cat <<EOF
{
  "name": "myapp",
  "version": "1.0.0"
}
EOF

# ✓ Correct - single quotes or literal here-doc
cat <<'EOF'
{
  "name": "myapp",
  "version": "1.0.0"
}
EOF

# ✗ Wrong - double quotes in case patterns
case "$action" in
  "start") start_service ;;
  "stop")  stop_service ;;
  "restart") restart_service ;;
esac

# ✓ Correct - unquoted one-word patterns
case "$action" in
  start) start_service ;;
  stop)  stop_service ;;
  restart) restart_service ;;
esac

# ✗ Wrong - double quotes for constant declarations
declare -- SCRIPT_NAME="myapp"
declare -- DEFAULT_CONFIG="/etc/myapp/config"

# ✓ Correct - single quotes for constants
declare -- SCRIPT_NAME='myapp'
declare -- DEFAULT_CONFIG='/etc/myapp/config'
```

**Category 2: Unquoted variables**

Unquoted variables are dangerous and unpredictable.

```bash
# ✗ Wrong - unquoted variable in conditional
[[ -f $file ]]
[[ -d $directory ]]
[[ -z $value ]]

# ✓ Correct - quoted variables
[[ -f "$file" ]]
[[ -d "$directory" ]]
[[ -z "$value" ]]

# ✗ Wrong - unquoted variable in assignment
target=$source
backup_file=$original_file

# ✓ Correct - quoted variable assignment (when source might have spaces)
target="$source"
backup_file="$original_file"

# ✗ Wrong - unquoted variable in echo
echo Processing $file...
echo Status: $status

# ✓ Correct - quoted variables
echo "Processing $file..."
echo "Status: $status"

# ✗ Wrong - unquoted variable in command
rm $temp_file
cp $source $destination

# ✓ Correct - quoted variables
rm "$temp_file"
cp "$source" "$destination"

# ✗ Wrong - unquoted array expansion
for item in ${items[@]}; do
  process $item
done

# ✓ Correct - quoted array expansion
for item in "${items[@]}"; do
  process "$item"
done
```

**Category 3: Unnecessary braces**

Braces should only be used when required.

```bash
# ✗ Wrong - braces not needed
echo "${HOME}/bin"
info "Installing to ${PREFIX}/share"
path="${CONFIG_DIR}/app.conf"

# ✓ Correct - no braces when not needed
echo "$HOME/bin"
info "Installing to $PREFIX/share"
path="$CONFIG_DIR/app.conf"

# ✗ Wrong - braces in simple assignments
name="${USER}"
dir="${PWD}"

# ✓ Correct - no braces needed
name="$USER"
dir="$PWD"

# ✗ Wrong - braces in conditionals (when not needed)
[[ -f "${file}" ]]
[[ "${count}" -eq 0 ]]

# ✓ Correct - no braces needed
[[ -f "$file" ]]
[[ "$count" -eq 0 ]]

# When braces ARE needed:
# ✓ Correct - braces required for parameter expansion
echo "${HOME:-/tmp}"        # Default value
echo "${file##*/}"          # Remove prefix
echo "${name/old/new}"      # Substitution
echo "${array[@]}"          # Array expansion
echo "${var1}${var2}"       # Adjacent variables
```

**Category 4: Unnecessary double quotes AND braces**

This combines two anti-patterns.

```bash
# ✗ Wrong - both unnecessary braces and wrong quotes
info "${PREFIX}/bin"              # Wrong: braces + part not variable
echo "Installing to ${PREFIX}"    # Wrong: braces not needed

# ✓ Correct - multiple valid forms
info "$PREFIX/bin"                # Best - no braces, literal unquoted
info "$PREFIX"/bin                # Also OK - explicit literal
echo "Installing to $PREFIX"      # Best - no braces

# ✗ Wrong - braces in static context
path="${HOME}/Documents"          # Braces not needed
file="${name}.txt"                # Braces not needed

# ✓ Correct - no braces
path="$HOME/Documents"
file="$name.txt"
```

**Category 5: Mixing quote styles inconsistently**

Inconsistent quoting confuses readers.

```bash
# ✗ Wrong - inconsistent quoting
info "Starting process..."
success 'Process complete'
warn "Warning: something happened"
error 'Error occurred'

# ✓ Correct - consistent quoting (all single quotes for static)
info 'Starting process...'
success 'Process complete'
warn 'Warning: something happened'
error 'Error occurred'

# ✗ Wrong - inconsistent variable quoting
[[ -f $file && -r "$file" ]]
path=$dir/$file
target="$destination"

# ✓ Correct - consistent variable quoting
[[ -f "$file" && -r "$file" ]]
path="$dir/$file"
target="$destination"
```

**Category 6: Quote escaping nightmares**

Avoid excessive escaping by using the right quote type.

```bash
# ✗ Wrong - escaping in double quotes
message="It's \"really\" important"
pattern="User: \"$USER\""

# ✓ Correct - use single quotes to avoid escaping
message='It'\''s "really" important'
# Or use $'...' for better readability
message=$'It\'s "really" important'

# ✗ Wrong - escaping backslashes
path="C:\\Users\\$USER\\Documents"

# ✓ Correct - single quotes for literal backslashes
path='C:\Users\Documents'
# Or when variable needed:
path="C:\\Users\\$USER\\Documents"  # If variable needed
```

**Category 7: Glob expansion dangers**

Unquoted variables can trigger unwanted glob expansion.

```bash
# ✗ Wrong - unquoted variable with glob characters
pattern='*.txt'
echo $pattern        # Expands to all .txt files!
[[ -f $pattern ]]    # Tests all .txt files!

# ✓ Correct - quoted to preserve literal
echo "$pattern"      # Outputs: *.txt
[[ -f "$pattern" ]]  # Tests for file named "*.txt"

# ✗ Wrong - unquoted in loop
files='*.sh'
for file in $files; do  # Glob expansion!
  echo "$file"
done

# ✓ Correct - quoted to prevent expansion
for file in "$files"; do  # Single iteration with literal
  echo "$file"  # Outputs: *.sh
done
```

**Category 8: Command substitution quoting**

Command substitution requires careful quoting.

```bash
# ✗ Wrong - unquoted command substitution
result=$(command)
echo $result         # Word splitting on result!

# ✓ Correct - quoted command substitution
result=$(command)
echo "$result"       # Preserves whitespace

# ✗ Wrong - double quotes for literal in substitution
version=$(cat "${VERSION_FILE}")

# ✓ Correct - only quote the variable
version=$(cat "$VERSION_FILE")

# ✗ Wrong - unquoted multi-line output
output=$(long_command)
echo $output         # Collapses to single line!

# ✓ Correct - quoted to preserve formatting
output=$(long_command)
echo "$output"       # Preserves all lines
```

**Category 9: Here-document quoting**

Here-docs have specific quoting rules.

```bash
# ✗ Wrong - quoted delimiter when variables needed
cat <<"EOF"
User: $USER          # Not expanded - stays as $USER
Home: $HOME          # Not expanded - stays as $HOME
EOF

# ✓ Correct - unquoted delimiter for variable expansion
cat <<EOF
User: $USER          # Expands to actual user
Home: $HOME          # Expands to actual home
EOF

# ✗ Wrong - unquoted delimiter for literal content
cat <<EOF
{
  "api_key": "$API_KEY"    # Expands variable (might not want this!)
}
EOF

# ✓ Correct - quoted delimiter for literal JSON
cat <<'EOF'
{
  "api_key": "$API_KEY"    # Literal - stays as $API_KEY
}
EOF
```

**Category 10: Special characters and escaping**

Special characters need proper handling.

```bash
# ✗ Wrong - unquoted special characters
email=user@domain.com         # @ has special meaning!
file=test(1).txt              # () are special!

# ✓ Correct - quoted for safety
email='user@domain.com'
file='test(1).txt'

# ✗ Wrong - escaping instead of quoting
message="It\'s a test"        # Unnecessary escape in double quotes
path="/usr/local/bin/\$cmd"   # Escaping $

# ✓ Correct - use appropriate quote type
message="It's a test"         # Single quote doesn't need escape in double quotes
message='It'\''s a test'      # Or use single quotes with escaped quote
path='/usr/local/bin/$cmd'    # Single quotes - $ is literal
```

**Complete anti-pattern example (full of mistakes):**

```bash
#!/bin/bash
set -euo pipefail

# ✗ WRONG VERSION - Full of anti-patterns

VERSION="1.0.0"                              # ✗ Double quotes for static
SCRIPT_PATH=${0}                             # ✗ Unquoted expansion
SCRIPT_DIR=${SCRIPT_PATH%/*}                 # ✗ Unquoted
SCRIPT_NAME=${SCRIPT_PATH##*/}               # ✗ Unquoted

# ✗ Double quotes everywhere
readonly PREFIX="${PREFIX:-/usr/local}"      # ✗ Braces + double quotes
BIN_DIR="${PREFIX}/bin"                      # ✗ Braces not needed

# ✗ Unquoted variables
info "Starting ${SCRIPT_NAME}..."            # ✗ Double quotes for static, braces

check_file() {
  local file=$1                              # ✗ Unquoted assignment

  # ✗ Unquoted variable in conditional
  if [[ -f $file ]]; then
    info "Processing ${file}..."             # ✗ Double quotes, braces
    return 0
  else
    error "File not found: ${file}"          # ✗ Double quotes, braces
    return 1
  fi
}

# ✗ Unquoted array expansion
files=(file1.txt "file 2.txt" file3.txt)
for file in ${files[@]}; do                  # ✗ Unquoted - breaks on spaces!
  check_file $file                           # ✗ Unquoted argument
done

info "Done processing files"                 # ✗ Double quotes for static
```

**Corrected version:**

```bash
#!/bin/bash
set -euo pipefail

# ✓ CORRECT VERSION

VERSION='1.0.0'                              # ✓ Single quotes for static
SCRIPT_PATH=$(realpath -- "$0")          # ✓ Quoted variable
SCRIPT_DIR=${SCRIPT_PATH%/*}                 # ✓ Braces needed for expansion
SCRIPT_NAME=${SCRIPT_PATH##*/}               # ✓ Braces needed for expansion
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ Minimal quoting
readonly PREFIX="${PREFIX:-/usr/local}"      # ✓ Braces needed for default
BIN_DIR="$PREFIX/bin"                        # ✓ No braces, quotes for safety

# ✓ Single quotes for static
info 'Starting script...'

check_file() {
  local -- file="$1"                         # ✓ Quoted assignment

  # ✓ Quoted variable in conditional
  if [[ -f "$file" ]]; then
    info "Processing $file..."               # ✓ Double quotes (has variable), no braces
    return 0
  else
    error "File not found: $file"            # ✓ Double quotes (has variable), no braces
    return 1
  fi
}

# ✓ Quoted array expansion
declare -a files=('file1.txt' 'file 2.txt' 'file3.txt')
local -- file
for file in "${files[@]}"; do                # ✓ Quoted array expansion
  check_file "$file"                         # ✓ Quoted argument
done

info 'Done processing files'                 # ✓ Single quotes for static
```

**Quick reference checklist:**

```bash
# Static strings → Single quotes
'literal text'                ✓
"literal text"                ✗

# Variables in strings → Double quotes, no braces
"text with $var"              ✓
"text with ${var}"            ✗
'text with $var'              ✗ (doesn't expand)

# Variables in commands → Quoted
echo "$var"                   ✓
echo $var                     ✗

# Variables in conditionals → Quoted
[[ -f "$file" ]]              ✓
[[ -f $file ]]                ✗

# Array expansion → Quoted
"${array[@]}"                 ✓
${array[@]}                   ✗

# Braces → Only when needed
"${var##*/}"                  ✓ (parameter expansion)
"${array[@]}"                 ✓ (array expansion)
"${var1}${var2}"              ✓ (adjacent variables)
"${var:-default}"             ✓ (default value)
"${HOME}"                     ✗ (not needed)

# One-word literals → Unquoted or single quotes
[[ "$var" == value ]]         ✓
[[ "$var" == 'value' ]]       ✓
[[ "$var" == "value" ]]       ✗

# Command substitution → Quote the variable, not the path
result=$(cat "$file")         ✓
result=$(cat "${file}")       ✗
result=$(cat $file)           ✗

# Here-docs → Quote delimiter for literal
cat <<'EOF'                   ✓ (literal content)
cat <<"EOF"                   ✓ (same as above)
cat <<EOF                     ✓ (expand variables)
```

**Summary:**

- **Never use double quotes for static strings** - use single quotes or unquoted one-word literals
- **Always quote variables** - in conditionals, assignments, commands, and expansions
- **Don't use braces unless required** - parameter expansion, arrays, or adjacent variables only
- **Never combine unnecessary braces with static text** - use `"$VAR/path"` not `"${VAR}/path"`
- **Quote array expansions consistently** - `"${array[@]}"` is mandatory
- **Be consistent** - don't mix quote styles for similar contexts
- **Use the right quote type** - single for literal, double for variables, none for one-word literals
- **Avoid escaping nightmares** - choose quote type to minimize escaping

**Key principle:** Quoting anti-patterns make code fragile, insecure, and hard to maintain. Following proper quoting rules eliminates entire classes of bugs. When in doubt: quote variables, use single quotes for static text, and avoid unnecessary braces. The extra keystrokes for proper quoting prevent hours of debugging mysterious failures.
