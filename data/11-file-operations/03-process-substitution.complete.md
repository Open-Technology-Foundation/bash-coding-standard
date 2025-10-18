## Process Substitution

**Use process substitution `<(command)` and `>(command)` to provide command output as file-like inputs or to send data to commands as if writing to files. Process substitution eliminates the need for temporary files, avoids subshell issues with pipes, and enables powerful command composition patterns.**

**Rationale:**

- **No Temporary Files**: Eliminates need for creating, managing, and cleaning up temp files
- **Avoid Subshells**: Unlike pipes to while, process substitution preserves variable scope
- **Multiple Inputs**: Commands can read from multiple process substitutions simultaneously
- **Parallelism**: Multiple process substitutions run in parallel
- **Clean Syntax**: More readable than complex piping and temp file management
- **Resource Efficiency**: Data streams through FIFOs/file descriptors without disk I/O

**How process substitution works:**

Process substitution creates a temporary FIFO (named pipe) or file descriptor that connects command output to another command's input.

```bash
# >(command) - Output redirection
# Creates: /dev/fd/63 (or similar)
# Data written to this goes to command's stdin

# <(command) - Input redirection
# Creates: /dev/fd/63 (or similar)
# Data read from this comes from command's stdout

# Example visualization:
diff <(sort file1) <(sort file2)

# Bash expands to something like:
# diff /dev/fd/63 /dev/fd/64
# Where:
#   /dev/fd/63 contains output of: sort file1
#   /dev/fd/64 contains output of: sort file2
```

**Basic patterns:**

**1. Input process substitution `<(command)`:**

```bash
# Compare command outputs
diff <(ls dir1) <(ls dir2)

# Use command output as file
cat <(echo "Header") <(cat data.txt) <(echo "Footer")

# Feed command output to another command
grep pattern <(find /data -name '*.log')

# Multiple inputs
paste <(cut -d: -f1 /etc/passwd) <(cut -d: -f3 /etc/passwd)
```

**2. Output process substitution `>(command)`:**

```bash
# Tee output to multiple commands
command | tee >(wc -l) >(grep ERROR) > output.txt

# Split output to different processes
generate_data | tee >(process_type1) >(process_type2) > /dev/null

# Send to command as if writing file
echo "data" > >(base64)
```

**Common use cases:**

**1. Comparing command outputs:**

```bash
# Compare sorted directory listings
diff <(ls -1 /dir1 | sort) <(ls -1 /dir2 | sort)

# Compare file checksums
diff <(sha256sum /backup/file) <(sha256sum /original/file)

# Compare configuration
diff <(ssh host1 cat /etc/config) <(ssh host2 cat /etc/config)
```

**2. Reading command output into array:**

```bash
# ✓ BEST - readarray with process substitution
declare -a users
readarray -t users < <(getent passwd | cut -d: -f1)

# Array is populated correctly
echo "Users: ${#users[@]}"

# ✓ ALSO GOOD - null-delimited
declare -a files
readarray -d '' -t files < <(find /data -type f -print0)
```

**3. Avoiding subshell in while loops:**

```bash
# ✓ CORRECT - Process substitution (no subshell)
declare -i count=0

while IFS= read -r line; do
  echo "$line"
  ((count+=1))
done < <(cat file.txt)

echo "Count: $count"  # Correct value!

# Compare with pipe (wrong - creates subshell):
# cat file.txt | while read -r line; do ...
```

**4. Multiple simultaneous inputs:**

```bash
# Read from multiple sources
while IFS= read -r line1 <&3 && IFS= read -r line2 <&4; do
  echo "File1: $line1"
  echo "File2: $line2"
done 3< <(cat file1.txt) 4< <(cat file2.txt)

# Merge sorted files
sort -m <(sort file1) <(sort file2) <(sort file3)
```

**5. Parallel processing with tee:**

```bash
# Process log file multiple ways simultaneously
cat logfile.txt | tee \
  >(grep ERROR > errors.log) \
  >(grep WARN > warnings.log) \
  >(wc -l > line_count.txt) \
  > all_output.log
```

**Complete examples:**

**Example 1: Configuration comparison:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Compare configs on multiple servers
compare_configs() {
  local -a servers=("$@")
  local -- config_file='/etc/myapp/config.conf'

  if [[ ${#servers[@]} -lt 2 ]]; then
    error 'Need at least 2 servers to compare'
    return 22
  fi

  info "Comparing $config_file across ${#servers[@]} servers"

  # Compare first two servers
  local -- server1="${servers[0]}"
  local -- server2="${servers[1]}"

  diff \
    <(ssh "$server1" "cat $config_file 2>/dev/null || echo 'NOT FOUND'") \
    <(ssh "$server2" "cat $config_file 2>/dev/null || echo 'NOT FOUND'")

  local -i diff_exit=$?

  if ((diff_exit == 0)); then
    success "Configs are identical on $server1 and $server2"
  else
    warn "Configs differ between $server1 and $server2"
  fi

  return "$diff_exit"
}

main() {
  compare_configs 'server1.example.com' 'server2.example.com'
}

main "$@"

#fin
```

**Example 2: Log analysis with parallel processing:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Analyze log file in parallel
analyze_log() {
  local -- log_file="$1"
  local -- output_dir="${2:-.}"

  info "Analyzing $log_file..."

  # Process log file multiple ways simultaneously
  cat "$log_file" | tee \
    >(grep 'ERROR' | sort -u > "$output_dir/errors.txt") \
    >(grep 'WARN' | sort -u > "$output_dir/warnings.txt") \
    >(awk '{print $1}' | sort -u > "$output_dir/unique_timestamps.txt") \
    >(wc -l > "$output_dir/line_count.txt") \
    > "$output_dir/full_log.txt"

  # Wait for all background processes
  wait

  # Report results
  local -i error_count warn_count total_lines

  error_count=$(wc -l < "$output_dir/errors.txt")
  warn_count=$(wc -l < "$output_dir/warnings.txt")
  total_lines=$(cat "$output_dir/line_count.txt")

  info "Analysis complete:"
  info "  Total lines: $total_lines"
  info "  Unique errors: $error_count"
  info "  Unique warnings: $warn_count"
}

main() {
  local -- log_file="${1:-/var/log/app.log}"
  analyze_log "$log_file"
}

main "$@"

#fin
```

**Example 3: Data merging with process substitution:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Merge and compare data from multiple sources
merge_user_data() {
  local -- source1="$1"
  local -- source2="$2"

  # Read users from multiple sources simultaneously
  local -a users1 users2

  readarray -t users1 < <(cut -d: -f1 "$source1" | sort -u)
  readarray -t users2 < <(cut -d: -f1 "$source2" | sort -u)

  info "Source 1: ${#users1[@]} users"
  info "Source 2: ${#users2[@]} users"

  # Find users in both
  local -a common
  readarray -t common < <(comm -12 <(printf '%s\n' "${users1[@]}") <(printf '%s\n' "${users2[@]}"))

  # Find users only in source1
  local -a only_source1
  readarray -t only_source1 < <(comm -23 <(printf '%s\n' "${users1[@]}") <(printf '%s\n' "${users2[@]}"))

  # Find users only in source2
  local -a only_source2
  readarray -t only_source2 < <(comm -13 <(printf '%s\n' "${users1[@]}") <(printf '%s\n' "${users2[@]}"))

  # Report
  info "Common users: ${#common[@]}"
  info "Only in source 1: ${#only_source1[@]}"
  info "Only in source 2: ${#only_source2[@]}"
}

main() {
  merge_user_data '/etc/passwd' '/backup/passwd'
}

main "$@"

#fin
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - using temp files instead
temp1=$(mktemp)
temp2=$(mktemp)
sort file1 > "$temp1"
sort file2 > "$temp2"
diff "$temp1" "$temp2"
rm "$temp1" "$temp2"

# ✓ Correct - process substitution (no temp files)
diff <(sort file1) <(sort file2)

# ✗ Wrong - pipe to while (subshell issue)
count=0
cat file | while read -r line; do
  ((count+=1))
done
echo "$count"  # Still 0!

# ✓ Correct - process substitution (no subshell)
count=0
while read -r line; do
  ((count+=1))
done < <(cat file)
echo "$count"  # Correct value!

# ✗ Wrong - sequential processing
cat log | grep ERROR > errors.txt
cat log | grep WARN > warnings.txt
cat log | wc -l > count.txt
# Reads file 3 times!

# ✓ Correct - parallel with tee and process substitution
cat log | tee \
  >(grep ERROR > errors.txt) \
  >(grep WARN > warnings.txt) \
  >(wc -l > count.txt) \
  > /dev/null
# Reads file once, processes in parallel

# ✗ Wrong - not quoting process substitution
diff <(sort $file1) <(sort $file2)  # Word splitting!

# ✓ Correct - quote variables
diff <(sort "$file1") <(sort "$file2")

# ✗ Wrong - forgetting error handling
diff <(failing_command) file
# If failing_command fails, diff gets empty input

# ✓ Correct - check command success
if temp_output=$(failing_command); then
  diff <(echo "$temp_output") file
else
  die 1 'Command failed'
fi
```

**Edge cases and advanced patterns:**

**1. File descriptor assignment:**

```bash
# Assign process substitution to file descriptor
exec 3< <(long_running_command)

# Read from it later
while IFS= read -r line <&3; do
  echo "$line"
done

# Close when done
exec 3<&-
```

**2. Multiple outputs with tee:**

```bash
# Send different data to different commands
{
  echo "type1: data1"
  echo "type2: data2"
  echo "type1: data3"
} | tee \
  >(grep 'type1' > type1.log) \
  >(grep 'type2' > type2.log) \
  > all.log
```

**3. Combining with here-strings:**

```bash
# Pass variable through process
var="hello world"
result=$(tr '[:lower:]' '[:upper:]' < <(echo "$var"))
echo "$result"  # HELLO WORLD

# Or with here-string (simpler for variables)
result=$(tr '[:lower:]' '[:upper:]' <<< "$var")
```

**4. Process substitution with diff:**

```bash
# Compare sorted JSON
diff \
  <(jq -S . file1.json) \
  <(jq -S . file2.json)

# Compare command output against expected
diff \
  <(my_command --output) \
  <(echo "expected output")
```

**5. NULL-delimited with process substitution:**

```bash
# Handle filenames with spaces/newlines
while IFS= read -r -d '' file; do
  echo "Processing: $file"
done < <(find /data -type f -print0)

# With readarray
declare -a files
readarray -d '' -t files < <(find /data -type f -print0)
```

**6. Nested process substitution:**

```bash
# Complex data processing
diff \
  <(sort <(grep pattern file1)) \
  <(sort <(grep pattern file2))

# Process chains
cat <(echo "header") <(sort <(grep -v '^#' data.txt)) <(echo "footer")
```

**Testing process substitution:**

```bash
# Test that process substitution works
test_process_substitution() {
  # Should create file-like object
  local -- test_file
  test_file=$(echo <(echo "test"))

  if [[ -e "$test_file" ]]; then
    info "Process substitution creates: $test_file"
  else
    error "Process substitution not working"
    return 1
  fi

  # Test reading
  local -- content
  content=$(cat <(echo "hello"))

  if [[ "$content" == "hello" ]]; then
    info "Process substitution read test: PASS"
  else
    error "Expected 'hello', got: $content"
    return 1
  fi
}

# Test avoiding subshell
test_subshell_avoidance() {
  local -i count=0

  while read -r line; do
    ((count+=1))
  done < <(echo -e "a\nb\nc")

  if ((count == 3)); then
    info "Subshell avoidance test: PASS (count=$count)"
  else
    error "Expected count=3, got count=$count"
    return 1
  fi
}

test_process_substitution
test_subshell_avoidance
```

**When NOT to use process substitution:**

```bash
# Simple command output - command substitution is clearer
# ✗ Overcomplicated
result=$(cat <(command))

# ✓ Simpler
result=$(command)

# Single file input - direct redirection is clearer
# ✗ Overcomplicated
grep pattern < <(cat file)

# ✓ Simpler
grep pattern < file
# Or:
grep pattern file

# Variable expansion - use here-string
# ✗ Overcomplicated
command < <(echo "$variable")

# ✓ Simpler
command <<< "$variable"
```

**Summary:**

- **Use `<(command)` for input** - treats command output as readable file
- **Use `>(command)` for output** - treats command as writable file
- **Eliminates temp files** - data streams through FIFOs/file descriptors
- **Avoids subshells** - unlike pipes, preserves variable scope
- **Enables parallelism** - multiple substitutions run simultaneously
- **Multiple inputs** - commands can read from several process substitutions
- **Works with diff, comm, paste** - any command accepting file arguments
- **Quote variables** - inside process substitution, quote like normal
- **Combine with tee** - for parallel output processing

**Key principle:** Process substitution is Bash's answer to "I need this command's output to look like a file." It's more efficient than temp files, safer than pipes (no subshell), and enables powerful data processing patterns. When you find yourself creating temp files just to pass data between commands, process substitution is almost always the better solution.
