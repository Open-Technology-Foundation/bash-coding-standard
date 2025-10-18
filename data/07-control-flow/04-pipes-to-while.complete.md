## Pipes to While Loops

**Avoid piping commands to while loops because pipes create subshells where variable assignments don't persist outside the loop. Use process substitution `< <(command)` or `readarray` instead. This is one of the most common and insidious bugs in Bash scripts.**

**Rationale:**

- **Variable Persistence**: Pipes create subshells; variables modified inside don't persist outside the loop
- **Debugging Difficulty**: The script appears to work but counters stay at 0, arrays stay empty
- **Silent Failure**: No error messages - script continues with wrong values
- **Process Substitution Fixes**: `< <(command)` runs loop in current shell, variables persist
- **Readarray Alternative**: For simple line collection, `readarray` is cleaner and faster
- **Set -e Interaction**: Failures in piped commands may not trigger `set -e` properly

**The subshell problem:**

When you pipe to while, Bash creates a subshell for the while loop. Any variable modifications happen in that subshell and are lost when the pipe ends.

```bash
# ✗ WRONG - Subshell loses variable changes
declare -i count=0

echo -e "line1\nline2\nline3" | while IFS= read -r line; do
  echo "$line"
  ((count+=1))
done

echo "Count: $count"  # Output: Count: 0 (NOT 3!)
# Variable changes were lost!
```

**Why this happens:**

```bash
# Pipe creates process tree:
#   Parent shell (count=0)
#      |
#      └─> Subshell (while loop)
#            - Inherits count=0
#            - Modifies count (1, 2, 3)
#            - Subshell exits
#            - Changes discarded!
#      |
#   Back to parent (count still 0)
```

**Solution 1: Process substitution (most common)**

```bash
# ✓ CORRECT - Process substitution avoids subshell
declare -i count=0

while IFS= read -r line; do
  echo "$line"
  ((count+=1))
done < <(echo -e "line1\nline2\nline3")

echo "Count: $count"  # Output: Count: 3 (correct!)
```

**Solution 2: Readarray/mapfile (when collecting lines)**

```bash
# ✓ CORRECT - readarray reads all lines into array
declare -a lines

readarray -t lines < <(echo -e "line1\nline2\nline3")

# Now process array
declare -i count="${#lines[@]}"
echo "Count: $count"  # Output: Count: 3 (correct!)

# Iterate if needed
local -- line
for line in "${lines[@]}"; do
  echo "$line"
done
```

**Solution 3: Here-string (for single variables)**

```bash
# ✓ CORRECT - Here-string when input is in variable
declare -- input=$'line1\nline2\nline3'
declare -i count=0

while IFS= read -r line; do
  echo "$line"
  ((count+=1))
done <<< "$input"

echo "Count: $count"  # Output: Count: 3 (correct!)
```

**Complete examples:**

**Example 1: Counting matching lines**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✗ WRONG - Counter stays 0
count_errors_wrong() {
  local -- log_file="$1"
  local -i error_count=0

  # Pipe creates subshell!
  grep 'ERROR' "$log_file" | while IFS= read -r line; do
    echo "Found: $line"
    ((error_count+=1))
  done

  echo "Errors: $error_count"  # Always 0!
  return "$error_count"  # Returns 0 even if errors found!
}

# ✓ CORRECT - Process substitution
count_errors_correct() {
  local -- log_file="$1"
  local -i error_count=0

  # Process substitution keeps loop in current shell
  while IFS= read -r line; do
    echo "Found: $line"
    ((error_count+=1))
  done < <(grep 'ERROR' "$log_file")

  echo "Errors: $error_count"  # Correct count!
  return "$error_count"
}

# ✓ ALSO CORRECT - Using wc (when only count matters)
count_errors_simple() {
  local -- log_file="$1"
  local -i error_count

  error_count=$(grep -c 'ERROR' "$log_file")
  echo "Errors: $error_count"
  return "$error_count"
}

main() {
  local -- test_log='/var/log/app.log'

  count_errors_correct "$test_log"
}

main "$@"

#fin
```

**Example 2: Building array from command output**

```bash
# ✗ WRONG - Array stays empty
collect_users_wrong() {
  local -a users=()

  # Pipe creates subshell!
  getent passwd | while IFS=: read -r user _; do
    users+=("$user")
  done

  echo "Users: ${#users[@]}"  # Always 0!
  # Array modifications lost!
}

# ✓ CORRECT - Process substitution
collect_users_correct() {
  local -a users=()

  while IFS=: read -r user _; do
    users+=("$user")
  done < <(getent passwd)

  echo "Users: ${#users[@]}"  # Correct count!
  printf '%s\n' "${users[@]}"
}

# ✓ ALSO CORRECT - readarray (simpler)
collect_users_readarray() {
  local -a users

  # Read usernames directly into array
  readarray -t users < <(getent passwd | cut -d: -f1)

  echo "Users: ${#users[@]}"
  printf '%s\n' "${users[@]}"
}
```

**Example 3: Processing files with state**

```bash
# ✗ WRONG - State variables lost
process_files_wrong() {
  local -i total_size=0
  local -i file_count=0

  # Pipe creates subshell!
  find /data -type f | while IFS= read -r file; do
    local -- size
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    ((total_size+=size))
    ((file_count+=1))
  done

  echo "Files: $file_count, Total: $total_size"
  # Both 0 - variables lost!
}

# ✓ CORRECT - Process substitution
process_files_correct() {
  local -i total_size=0
  local -i file_count=0

  while IFS= read -r file; do
    local -- size
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    ((total_size+=size))
    ((file_count+=1))
  done < <(find /data -type f)

  echo "Files: $file_count, Total: $total_size"
  # Correct values!
}
```

**Example 4: Multi-variable read**

```bash
# ✗ WRONG - Associative array stays empty
parse_config_wrong() {
  local -A config=()

  # Pipe creates subshell!
  cat config.conf | while IFS='=' read -r key value; do
    config[$key]="$value"
  done

  # config is empty here!
  echo "Config entries: ${#config[@]}"  # 0
}

# ✓ CORRECT - Process substitution
parse_config_correct() {
  local -A config=()

  while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue

    config[$key]="$value"
  done < <(cat config.conf)

  # config has values!
  echo "Config entries: ${#config[@]}"

  # Display config
  local -- k
  for k in "${!config[@]}"; do
    echo "$k = ${config[$k]}"
  done
}
```

**When readarray is better:**

```bash
# If you just need lines in an array, use readarray

# ✓ BEST - readarray for simple line collection
declare -a log_lines
readarray -t log_lines < <(tail -n 100 /var/log/app.log)

# Process array
local -- line
for line in "${log_lines[@]}"; do
  [[ "$line" =~ ERROR ]] && echo "Error: $line"
done

# ✓ BEST - readarray with null-delimited input
declare -a files
readarray -d '' -t files < <(find /data -type f -print0)

# Safe iteration (handles spaces in filenames)
local -- file
for file in "${files[@]}"; do
  echo "Processing: $file"
done
```

**Complete working example:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Analyze log file with process substitution
analyze_log() {
  local -- log_file="$1"

  local -i error_count=0
  local -i warn_count=0
  local -i total_lines=0
  local -a error_lines=()

  # Process substitution - variables persist
  while IFS= read -r line; do
    ((total_lines+=1))

    if [[ "$line" =~ ERROR ]]; then
      ((error_count+=1))
      error_lines+=("$line")
    elif [[ "$line" =~ WARN ]]; then
      ((warn_count+=1))
    fi
  done < <(cat "$log_file")

  # All counters work correctly!
  echo "Analysis of $log_file:"
  echo "  Total lines: $total_lines"
  echo "  Errors: $error_count"
  echo "  Warnings: $warn_count"

  if ((error_count > 0)); then
    echo ""
    echo "Error lines:"
    printf '  %s\n' "${error_lines[@]}"
  fi
}

# Collect configuration with readarray
load_config() {
  local -- config_file="$1"
  local -a config_lines
  local -A config=()

  # Use readarray to collect lines
  readarray -t config_lines < <(grep -v '^#' "$config_file" | grep -v '^[[:space:]]*$')

  # Parse array
  local -- line key value
  for line in "${config_lines[@]}"; do
    IFS='=' read -r key value <<< "$line"
    config[$key]="$value"
  done

  # Config populated correctly
  echo "Configuration loaded: ${#config[@]} entries"
  local -- k
  for k in "${!config[@]}"; do
    echo "  $k = ${config[$k]}"
  done
}

# Process files safely
process_directory() {
  local -- dir="$1"
  local -a files

  # Collect files with readarray
  readarray -d '' -t files < <(find "$dir" -type f -name '*.txt' -print0)

  local -- file
  local -i processed=0

  for file in "${files[@]}"; do
    echo "Processing: $file"
    # Process file
    ((processed+=1))
  done

  echo "Processed $processed files"
}

main() {
  analyze_log '/var/log/app.log'
  load_config '/etc/app/config.conf'
  process_directory '/data'
}

main "$@"

#fin
```

**Anti-patterns to avoid:**

```bash
# ✗ WRONG - Pipe to while with counter
cat file.txt | while read -r line; do
  ((count+=1))
done
echo "$count"  # Still 0!

# ✓ CORRECT - Process substitution
while read -r line; do
  ((count+=1))
done < <(cat file.txt)
echo "$count"  # Correct!

# ✗ WRONG - Pipe to while building array
find /data -name '*.txt' | while read -r file; do
  files+=("$file")
done
echo "${#files[@]}"  # Still 0!

# ✓ CORRECT - readarray
readarray -d '' -t files < <(find /data -name '*.txt' -print0)
echo "${#files[@]}"  # Correct!

# ✗ WRONG - Pipe to while modifying associative array
cat config | while IFS='=' read -r key val; do
  config[$key]="$val"
done
# config is empty!

# ✓ CORRECT - Process substitution
while IFS='=' read -r key val; do
  config[$key]="$val"
done < <(cat config)
# config has values!

# ✗ WRONG - Setting flag in piped while
has_errors=0
grep ERROR log | while read -r line; do
  has_errors=1
done
echo "$has_errors"  # Still 0!

# ✓ CORRECT - Use return value or process substitution
if grep -q ERROR log; then
  has_errors=1
fi
# Or:
while read -r line; do
  has_errors=1
done < <(grep ERROR log)

# ✗ WRONG - Complex pipeline with state
cat file | grep pattern | sort | while read -r line; do
  ((count+=1))
  data+=("$line")
done
# count=0, data=() - both lost!

# ✓ CORRECT - Process substitution with pipeline
while read -r line; do
  ((count+=1))
  data+=("$line")
done < <(cat file | grep pattern | sort)
# Variables persist!
```

**Edge cases:**

**1. Empty input:**

```bash
# Process substitution handles empty input correctly
declare -i count=0

while read -r line; do
  ((count+=1))
done < <(echo -n "")  # No output

echo "Count: $count"  # 0 - correct (no lines)
```

**2. Command failure in process substitution:**

```bash
# With set -e, command failure is detected
while read -r line; do
  process "$line"
done < <(failing_command)  # Script exits if failing_command fails
```

**3. Very large output:**

```bash
# readarray loads everything into memory
readarray -t lines < <(cat huge_file)  # Might use lots of RAM

# Process substitution processes line by line
while read -r line; do
  process "$line"  # Processes one at a time
done < <(cat huge_file)  # Lower memory usage
```

**4. Null-delimited input (filenames with newlines):**

```bash
# Use -d '' for null-delimited
while IFS= read -r -d '' file; do
  echo "File: $file"
done < <(find /data -print0)

# Or with readarray
readarray -d '' -t files < <(find /data -print0)
```

**Testing the subshell issue:**

```bash
# Demonstrate the problem
test_pipe_subshell() {
  local -i count=0

  # This fails
  echo "test" | while read -r line; do
    count=1
  done

  if ((count == 0)); then
    echo "FAIL: Pipe created subshell, count not updated"
  else
    echo "PASS: Count was updated"
  fi
}

# Demonstrate the solution
test_process_substitution() {
  local -i count=0

  # This works
  while read -r line; do
    count=1
  done < <(echo "test")

  if ((count == 1)); then
    echo "PASS: Process substitution kept variables"
  else
    echo "FAIL: Count not updated"
  fi
}

test_pipe_subshell        # Shows the problem
test_process_substitution # Shows the solution
```

**Summary:**

- **Never pipe to while** - creates subshell, variables don't persist
- **Use process substitution** - `while read; done < <(command)` - variables persist
- **Use readarray** - `readarray -t array < <(command)` - simple and efficient
- **Use here-string** - `while read; done <<< "$var"` - when input is in variable
- **Subshell variables are lost** - any modifications disappear when pipe ends
- **Debugging is hard** - script appears to work but uses wrong values
- **Always test with data** - empty counters/arrays indicate subshell problem

**Key principle:** Piping to while is a dangerous anti-pattern that silently loses variable modifications. Always use process substitution `< <(command)` or `readarray` instead. This is not a style preference - it's about correctness. If you find `| while read` in code, it's almost certainly a bug waiting to manifest.
