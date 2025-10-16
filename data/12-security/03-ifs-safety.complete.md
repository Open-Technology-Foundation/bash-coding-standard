### IFS Manipulation Safety

**Never trust or use inherited IFS values. Always protect IFS changes to prevent field splitting attacks and unexpected behavior.**

**Rationale:**

- **Security Vulnerability**: Attackers can manipulate IFS in the calling environment to exploit scripts that don't protect IFS
- **Field Splitting Exploits**: Malicious IFS values cause word splitting at unexpected characters, breaking argument parsing
- **Command Injection**: IFS manipulation combined with unquoted variables enables command execution
- **Global Side Effects**: Changing IFS without restoration breaks subsequent operations throughout the script
- **Environment Inheritance**: IFS is inherited from parent processes and may be attacker-controlled
- **Subtle Bugs**: IFS changes cause hard-to-debug issues when forgotten or improperly scoped

**Understanding IFS:**

IFS (Internal Field Separator) controls how Bash splits words during expansion. Default is `$' \t\n'` (space, tab, newline).

\`\`\`bash
# Default IFS behavior
IFS=$' \t\n'  # Space, tab, newline (default)
data="one two three"
read -ra words <<< "$data"
# Result: words=("one" "two" "three")

# Custom IFS for CSV parsing
IFS=','
data="apple,banana,orange"
read -ra fruits <<< "$data"
# Result: fruits=("apple" "banana" "orange")
\`\`\`

**Attack Example 1: Field Splitting Exploitation**

\`\`\`bash
# Vulnerable script - doesn't protect IFS
#!/bin/bash
set -euo pipefail

# Script expects space-separated list
process_files() {
  local -- file_list="$1"
  local -a files

  # Vulnerable: IFS could be manipulated
  read -ra files <<< "$file_list"

  for file in "${files[@]}"; do
    rm -- "$file"  # Deletes each file
  done
}

# Normal usage
process_files "temp1.txt temp2.txt temp3.txt"
# Deletes: temp1.txt, temp2.txt, temp3.txt
\`\`\`

**Attack:**
\`\`\`bash
# Attacker sets IFS to slash
export IFS='/'
./vulnerable-script.sh

# Inside the script, file_list="temp1.txt temp2.txt"
# With IFS='/', read -ra splits on '/' not spaces!
# files=("temp1.txt temp2.txt")  # NOT split - treated as one filename!

# Or worse - attacker uses this to bypass filtering:
export IFS=$'\n'
./vulnerable-script.sh "/etc/passwd
/root/.ssh/authorized_keys"
# Now the script processes these filenames as if they were in the list
\`\`\`

**Attack Example 2: Command Injection via IFS**

\`\`\`bash
# Vulnerable script
#!/bin/bash
set -euo pipefail

# Process user-provided command with arguments
user_input="$1"
# Split on spaces to get command and arguments
read -ra cmd_parts <<< "$user_input"

# Execute command
"${cmd_parts[@]}"
\`\`\`

**Attack:**
\`\`\`bash
# Attacker manipulates IFS before calling script
export IFS='X'
./vulnerable-script.sh "lsX-laX/etc/shadow"

# With IFS='X', the splitting becomes:
# cmd_parts=("ls" "-la" "/etc/shadow")
# Script executes: ls -la /etc/shadow
# Attacker bypassed any input validation that checked for spaces!
\`\`\`

**Attack Example 3: Privilege Escalation via SUID Script**

\`\`\`bash
# Vulnerable SUID script (should never exist, but illustrative)
#!/bin/bash
# /usr/local/bin/backup.sh (SUID root - NEVER DO THIS!)

# Supposed to back up only allowed directories
allowed_dirs="home var opt"

# Check if user-provided directory is allowed
user_dir="$1"
is_allowed=0

for dir in $allowed_dirs; do  # Unquoted expansion uses IFS!
  [[ "$user_dir" == "$dir" ]] && is_allowed=1
done

((is_allowed)) || die 5 "Directory not allowed: $user_dir"

# Back up the directory with root privileges
tar -czf "/backup/${user_dir}.tar.gz" "/$user_dir"
\`\`\`

**Attack:**
\`\`\`bash
# Attacker sets IFS to 'e'
export IFS='e'
/usr/local/bin/backup.sh "etc"

# The loop splits "home var opt" on 'e':
# Results in words: "hom" " var opt"
# None match "etc", but if validation was bypassed differently...

# More direct attack - set IFS to include the target:
export IFS=' e'
# Now "home" splits to "hom " "
# The attacker can craft IFS to make "etc" appear in the allowed list
\`\`\`

**Safe Pattern 1: Save and Restore IFS (Explicit)**

\`\`\`bash
# ✓ Correct - save, modify, restore
parse_csv() {
  local -- csv_data="$1"
  local -a fields
  local -- saved_ifs

  # Save current IFS
  saved_ifs="$IFS"

  # Set IFS for CSV parsing
  IFS=','
  read -ra fields <<< "$csv_data"

  # Restore IFS immediately
  IFS="$saved_ifs"

  # Process fields with original IFS restored
  for field in "${fields[@]}"; do
    info "Field: $field"
  done
}
\`\`\`

**Safe Pattern 2: Subshell Isolation (Preferred)**

\`\`\`bash
# ✓ Correct - IFS change isolated to subshell
parse_csv() {
  local -- csv_data="$1"
  local -a fields

  # Use subshell - IFS change automatically reverts when subshell exits
  fields=( $(
    IFS=','
    read -ra temp <<< "$csv_data"
    printf '%s\n' "${temp[@]}"
  ) )

  # Or simpler - capture in subshell directly
  IFS=',' read -ra fields <<< "$csv_data"  # This also works in some contexts

  # Process with original IFS intact
  for field in "${fields[@]}"; do
    info "Field: $field"
  done
}
\`\`\`

**Safe Pattern 3: Local IFS in Function**

\`\`\`bash
# ✓ Correct - use local to scope IFS change
parse_csv() {
  local -- csv_data="$1"
  local -a fields
  local -- IFS  # Make IFS local to this function

  # Now changes to IFS only affect this function
  IFS=','
  read -ra fields <<< "$csv_data"

  # IFS automatically restored when function returns
  for field in "${fields[@]}"; do
    info "Field: $field"
  done
}

# After function returns, IFS is unchanged in caller
\`\`\`

**Safe Pattern 4: One-Line IFS Assignment**

\`\`\`bash
# ✓ Correct - IFS change applies only to single command
# This is a bash feature: VAR=value command applies VAR only to that command

# Parse CSV in one line
IFS=',' read -ra fields <<< "$csv_data"
# IFS is automatically reset after the read command

# Parse colon-separated PATH
IFS=':' read -ra path_dirs <<< "$PATH"
# IFS is automatically reset after the read command

# This is the most concise and safe pattern for single operations
\`\`\`

**Safe Pattern 5: Explicitly Set IFS at Script Start**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Explicitly set IFS to known-safe value at script start
# This defends against inherited malicious IFS
IFS=$' \t\n'  # Space, tab, newline (standard default)
readonly IFS  # Prevent modification
export IFS

# Rest of script operates with trusted IFS
# Any attempt to modify IFS will fail due to readonly
\`\`\`

**Edge case: IFS with read -d (delimiter)**

\`\`\`bash
# When using read -d, IFS still matters for field splitting
# The delimiter (-d) determines where to stop reading
# IFS determines how to split what was read

# Reading null-delimited input (common with find -print0)
while IFS= read -r -d '' file; do
  # IFS= prevents field splitting
  # -d '' sets null byte as delimiter
  process "$file"
done < <(find . -type f -print0)

# This is the safe pattern for filenames with spaces
\`\`\`

**Edge case: IFS and globbing**

\`\`\`bash
# IFS affects word splitting, NOT pathname expansion (globbing)
IFS=':'
files=*.txt  # Glob expands normally

# But IFS affects how results are split if unquoted
echo $files  # Splits on ':' - WRONG!

# Always quote to prevent IFS-based splitting
echo "$files"  # Safe - no splitting
\`\`\`

**Edge case: Empty IFS**

\`\`\`bash
# Setting IFS='' (empty) disables field splitting entirely
IFS=''
data="one two three"
read -ra words <<< "$data"
# Result: words=("one two three")  # NOT split!

# This can be useful to preserve exact input
IFS= read -r line < file.txt  # Preserves leading/trailing whitespace
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - modifying IFS without save/restore
IFS=','
read -ra fields <<< "$csv_data"
# IFS is now ',' for the rest of the script - BROKEN!

# ✓ Correct - save and restore
saved_ifs="$IFS"
IFS=','
read -ra fields <<< "$csv_data"
IFS="$saved_ifs"

# ✗ Wrong - trusting inherited IFS
#!/bin/bash
set -euo pipefail
# No IFS protection - vulnerable to manipulation!
read -ra parts <<< "$user_input"

# ✓ Correct - set IFS explicitly
#!/bin/bash
set -euo pipefail
IFS=$' \t\n'  # Set to known-safe value
readonly IFS
read -ra parts <<< "$user_input"

# ✗ Wrong - forgetting to restore IFS in error cases
saved_ifs="$IFS"
IFS=','
some_command || return 1  # IFS not restored on error!
IFS="$saved_ifs"

# ✓ Correct - use trap or subshell
(
  IFS=','
  some_command || return 1  # Subshell ensures IFS is restored
)

# ✗ Wrong - modifying IFS globally
IFS=$'\n'  # Changed for entire script
for line in $(cat file.txt); do
  process "$line"
done
# Now ALL subsequent operations use wrong IFS!

# ✓ Correct - isolate IFS change
while IFS= read -r line; do
  process "$line"
done < file.txt

# ✗ Wrong - using IFS for complex parsing
IFS=':' read -r user pass uid gid name home shell <<< "$passwd_line"
# Fragile - breaks if any field contains ':'

# ✓ Correct - use cut or awk for structured data
user=$(cut -d: -f1 <<< "$passwd_line")
uid=$(cut -d: -f3 <<< "$passwd_line")
\`\`\`

**Complete safe example:**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Set IFS to known-safe value immediately
IFS=$' \t\n'
readonly IFS
export IFS

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Parse CSV data safely
parse_csv_file() {
  local -- csv_file="$1"
  local -a records

  # Read file line by line
  while IFS= read -r line; do
    # Parse CSV fields using subshell-isolated IFS
    local -a fields
    (
      IFS=','
      read -ra fields <<< "$line"

      # Process fields
      info "Name: ${fields[0]}"
      info "Email: ${fields[1]}"
      info "Age: ${fields[2]}"
    )
  done < "$csv_file"
}

# Alternative: One-line IFS for each read
parse_csv_line() {
  local -- csv_line="$1"
  local -a fields

  # IFS applies only to this read command
  IFS=',' read -ra fields <<< "$csv_line"

  # Process with normal IFS
  for field in "${fields[@]}"; do
    info "Field: $field"
  done
}

main() {
  parse_csv_file 'data.csv'
}

main "$@"

#fin
\`\`\`

**Testing IFS safety:**

\`\`\`bash
# Test script behavior with malicious IFS
test_ifs_safety() {
  # Save original IFS
  local -- original_ifs="$IFS"

  # Set malicious IFS
  IFS='/'

  # Run function that should be IFS-safe
  parse_csv_line "apple,banana,orange"

  # Verify IFS was restored
  if [[ "$IFS" == "$original_ifs" ]]; then
    success 'IFS properly protected'
  else
    error 'IFS leaked - security vulnerability!'
    return 1
  fi
}
\`\`\`

**Checking current IFS:**

\`\`\`bash
# Display current IFS (non-printable characters shown)
debug() {
  local -- ifs_visual
  ifs_visual=$(printf '%s' "$IFS" | cat -v)
  >&2 echo "DEBUG: Current IFS: [$ifs_visual]"
  >&2 echo "DEBUG: IFS length: ${#IFS}"
  >&2 printf 'DEBUG: IFS bytes: %s\n' "$(printf '%s' "$IFS" | od -An -tx1)"
}

# Verify IFS is default
verify_default_ifs() {
  local -- expected=$' \t\n'
  if [[ "$IFS" == "$expected" ]]; then
    info 'IFS is default (safe)'
  else
    warn 'IFS is non-standard'
    debug
  fi
}
\`\`\`

**Summary:**

- **Set IFS explicitly** at script start: `IFS=$' \t\n'; readonly IFS`
- **Use subshells** to isolate IFS changes: `( IFS=','; read -ra fields <<< "$data" )`
- **Use one-line assignment** for single commands: `IFS=',' read -ra fields <<< "$data"`
- **Use local IFS** in functions to scope changes: `local -- IFS; IFS=','`
- **Always restore IFS** if modifying: `saved_ifs="$IFS"; IFS=','; ...; IFS="$saved_ifs"`
- **Never trust inherited IFS** - always set it yourself
- **Test IFS safety** as part of security validation

**Key principle:** IFS is a global variable that affects word splitting throughout your script. Treat it as security-critical and always protect changes with proper scoping or save/restore patterns.
