### Arrays for Safe List Handling

**Use arrays to store lists of elements safely, especially for command arguments, file lists, and any collection where elements may contain spaces, special characters, or wildcards. Arrays provide proper element boundaries and eliminate word splitting and glob expansion issues that plague string-based lists.**

**Rationale:**

- **Element Preservation**: Arrays maintain element boundaries regardless of content (spaces, newlines, special chars)
- **No Word Splitting**: Array elements don't undergo word splitting when expanded with `"${array[@]}"`
- **Glob Safety**: Array elements containing wildcards are preserved literally
- **Safe Command Construction**: Arrays enable building commands with arbitrary arguments safely
- **Iteration Safety**: Array iteration processes each element exactly once, preserving all content
- **Dynamic Lists**: Arrays can grow, shrink, and be modified without quoting complications

**Why arrays are safer than strings:**

**Problem with string lists:**

```bash
# ✗ DANGEROUS - String-based list
files_str="file1.txt file with spaces.txt file3.txt"

# Word splitting breaks this!
for file in $files_str; do
  echo "$file"
done
# Output:
# file1.txt
# file
# with
# spaces.txt
# file3.txt
# (5 iterations instead of 3!)

# Command arguments break too
cmd $files_str  # Passes 5 arguments instead of 3!
```

**Solution with arrays:**

```bash
# ✓ SAFE - Array-based list
declare -a files=(
  'file1.txt'
  'file with spaces.txt'
  'file3.txt'
)

# Proper iteration
for file in "${files[@]}"; do
  echo "$file"
done
# Output:
# file1.txt
# file with spaces.txt
# file3.txt
# (3 iterations - correct!)

# Safe command arguments
cmd "${files[@]}"  # Passes exactly 3 arguments
```

**Safe command argument construction:**

**1. Building commands with variable arguments:**

```bash
# ✓ Correct - array for command arguments
build_command() {
  local -- output_file="$1"
  local -i verbose="$2"

  # Build command in array
  local -a cmd=(
    'myapp'
    '--config' '/etc/myapp/config.conf'
    '--output' "$output_file"
  )

  # Add conditional arguments
  if ((verbose)); then
    cmd+=('--verbose')
  fi

  # Execute safely
  "${cmd[@]}"
}

build_command 'output file.txt' 1
# Executes: myapp --config /etc/myapp/config.conf --output 'output file.txt' --verbose
```

**2. Complex command with many options:**

```bash
# ✓ Correct - build find command safely
search_files() {
  local -- search_dir="$1"
  local -- pattern="$2"

  local -a find_args=(
    "$search_dir"
    '-type' 'f'
  )

  # Add name pattern if provided
  if [[ -n "$pattern" ]]; then
    find_args+=('-name' "$pattern")
  fi

  # Add time constraints
  find_args+=(
    '-mtime' '-7'
    '-size' '+1M'
  )

  # Execute
  find "${find_args[@]}"
}

search_files '/home/user' '*.log'
```

**3. SSH/rsync with dynamic arguments:**

```bash
# ✓ Correct - SSH command with conditional arguments
ssh_connect() {
  local -- host="$1"
  local -i use_key="$2"
  local -- key_file="$3"

  local -a ssh_args=(
    '-o' 'StrictHostKeyChecking=no'
    '-o' 'UserKnownHostsFile=/dev/null'
  )

  if ((use_key)) && [[ -f "$key_file" ]]; then
    ssh_args+=('-i' "$key_file")
  fi

  ssh_args+=("$host")

  ssh "${ssh_args[@]}"
}

ssh_connect 'user@example.com' 1 "$HOME/.ssh/id_rsa"
```

**Safe file list handling:**

**1. Processing multiple files:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Process list of files safely
process_files() {
  # Collect files into array
  local -a files=(
    "$SCRIPT_DIR/data/file 1.txt"
    "$SCRIPT_DIR/data/report (final).pdf"
    "$SCRIPT_DIR/data/config.conf"
  )

  local -- file
  local -i processed=0

  # Safe iteration
  for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
      info "Processing: $file"
      # Process file
      ((processed+=1))
    else
      warn "File not found: $file"
    fi
  done

  info "Processed $processed files"
}

# Gather files with globbing into array
gather_files() {
  local -- pattern="$1"

  # Use array to collect glob results
  local -a matching_files=("$SCRIPT_DIR"/$pattern)

  # Check if glob matched anything
  if [[ ${#matching_files[@]} -eq 0 ]]; then
    error "No files matching: $pattern"
    return 1
  fi

  info "Found ${#matching_files[@]} files"

  # Process array
  local -- file
  for file in "${matching_files[@]}"; do
    info "File: $file"
  done
}

main() {
  process_files
  gather_files '*.txt'
}

main "$@"

#fin
```

**2. Building lists dynamically:**

```bash
# Build file list based on criteria
collect_log_files() {
  local -- log_dir="$1"
  local -i max_age="$2"

  local -a log_files=()
  local -- file

  # Collect matching files into array
  while IFS= read -r -d '' file; do
    log_files+=("$file")
  done < <(find "$log_dir" -name '*.log' -mtime "-$max_age" -print0)

  info "Collected ${#log_files[@]} log files"

  # Process array
  for file in "${log_files[@]}"; do
    process_log "$file"
  done
}
```

**Safe argument passing to functions:**

```bash
# ✓ Correct - pass array to function
process_items() {
  # Capture all arguments as array
  local -a items=("$@")
  local -- item

  info "Processing ${#items[@]} items"

  for item in "${items[@]}"; do
    info "Item: $item"
  done
}

# Build array and pass
declare -a my_items=(
  'item one'
  'item with "quotes"'
  'item with $special chars'
)

# Safe expansion
process_items "${my_items[@]}"
```

**Conditional array building:**

```bash
# Build array based on conditions
build_compiler_flags() {
  local -i debug="$1"
  local -i optimize="$2"

  local -a flags=('-Wall' '-Werror')

  if ((debug)); then
    flags+=('-g' '-DDEBUG')
  fi

  if ((optimize)); then
    flags+=('-O2' '-DNDEBUG')
  else
    flags+=('-O0')
  fi

  # Return array by echoing elements
  printf '%s\n' "${flags[@]}"
}

# Capture into array
declare -a compiler_flags
readarray -t compiler_flags < <(build_compiler_flags 1 0)

# Use array
gcc "${compiler_flags[@]}" -o myapp myapp.c
```

**Complete example with safe list handling:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -i VERBOSE=0
declare -i DRY_RUN=0

# Build backup command with safe argument handling
create_backup() {
  local -- source_dir="$1"
  local -- backup_dir="$2"

  # Build tar command in array
  local -a tar_args=(
    '-czf'
    "$backup_dir/backup-$(date +%Y%m%d).tar.gz"
    '-C' "${source_dir%/*}"
    "${source_dir##*/}"
  )

  # Add verbose flag if requested
  ((VERBOSE)) && tar_args+=('-v')

  # Build exclude patterns
  local -a exclude_patterns=(
    '*.tmp'
    '*.log'
    '.git'
  )

  # Add excludes to tar command
  local -- pattern
  for pattern in "${exclude_patterns[@]}"; do
    tar_args+=('--exclude' "$pattern")
  done

  # Execute or show command
  if ((DRY_RUN)); then
    info '[DRY-RUN] Would execute:'
    printf '  %s\n' "${tar_args[@]}"
  else
    info 'Creating backup...'
    tar "${tar_args[@]}"
  fi
}

# Process multiple directories
process_directories() {
  # Collect directories to process
  local -a directories=(
    "$HOME/Documents"
    "$HOME/Projects/my project"
    "$HOME/.config"
  )

  local -- dir
  local -i count=0

  for dir in "${directories[@]}"; do
    if [[ -d "$dir" ]]; then
      create_backup "$dir" '/backup'
      ((count+=1))
    else
      warn "Directory not found: $dir"
    fi
  done

  success "Backed up $count directories"
}

# Build rsync command with array
sync_files() {
  local -- source="$1"
  local -- destination="$2"

  # Build rsync command
  local -a rsync_args=(
    '-av'
    '--progress'
    '--exclude' '.git/'
    '--exclude' '*.tmp'
  )

  ((DRY_RUN)) && rsync_args+=('--dry-run')

  rsync_args+=(
    "$source"
    "$destination"
  )

  info 'Syncing files...'
  rsync "${rsync_args[@]}"
}

main() {
  # Parse arguments
  while (($#)); do case $1 in
    -v|--verbose) VERBOSE=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    *) die 22 "Invalid option: $1" ;;
  esac; shift; done

  readonly -- VERBOSE DRY_RUN

  process_directories
  sync_files "$HOME/data" '/backup/data'
}

main "$@"

#fin
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - string-based list
files_str="file1.txt file2.txt file with spaces.txt"
for file in $files_str; do  # Word splitting!
  process "$file"
done

# ✓ Correct - array-based list
declare -a files=('file1.txt' 'file2.txt' 'file with spaces.txt')
for file in "${files[@]}"; do
  process "$file"
done

# ✗ Wrong - concatenating strings for commands
cmd_args="-o output.txt --verbose"
mycmd $cmd_args  # Word splitting issues

# ✓ Correct - array for command arguments
declare -a cmd_args=('-o' 'output.txt' '--verbose')
mycmd "${cmd_args[@]}"

# ✗ Wrong - building command with string concatenation
cmd="find $dir -name $pattern"
eval "$cmd"  # Dangerous - eval with user input!

# ✓ Correct - array-based command construction
declare -a find_args=("$dir" '-name' "$pattern")
find "${find_args[@]}"

# ✗ Wrong - IFS manipulation for iteration
IFS=','
for item in $csv_string; do  # Fragile, modifies IFS
  echo "$item"
done
IFS=' '

# ✓ Correct - array from IFS split (if really needed)
IFS=',' read -ra items <<< "$csv_string"
for item in "${items[@]}"; do
  echo "$item"
done

# ✗ Wrong - collecting glob results in string
files=$(ls *.txt)  # Parses ls output - very wrong!
for file in $files; do
  process "$file"
done

# ✓ Correct - glob directly into array
declare -a files=(*.txt)
for file in "${files[@]}"; do
  process "$file"
done

# ✗ Wrong - passing list as single string
files="file1 file2 file3"
process_files "$files"  # Receives as single argument

# ✓ Correct - passing array elements
declare -a files=('file1' 'file2' 'file3')
process_files "${files[@]}"  # Each file as separate argument

# ✗ Wrong - unquoted array variable
declare -a items=('a' 'b' 'c')
cmd ${items[@]}  # Word splitting on each element!

# ✓ Correct - quoted array expansion
cmd "${items[@]}"
```

**Edge cases and advanced patterns:**

**1. Empty arrays:**

```bash
# Empty array is safe to iterate
declare -a empty=()

# Zero iterations - no errors
for item in "${empty[@]}"; do
  echo "$item"  # Never executes
done

# Safe to pass to functions
process_items "${empty[@]}"  # Function receives zero arguments
```

**2. Arrays with special characters:**

```bash
# Array with various special characters
declare -a special=(
  'file with spaces.txt'
  'file"with"quotes.txt'
  'file$with$dollars.txt'
  'file*with*wildcards.txt'
  $'file\nwith\nnewlines.txt'
)

# All elements preserved safely
for file in "${special[@]}"; do
  echo "File: $file"
done
```

**3. Merging arrays:**

```bash
# Combine multiple arrays
declare -a arr1=('a' 'b')
declare -a arr2=('c' 'd')
declare -a arr3=('e' 'f')

declare -a combined=(
  "${arr1[@]}"
  "${arr2[@]}"
  "${arr3[@]}"
)

echo "Combined: ${#combined[@]} elements"  # 6 elements
```

**4. Array slicing:**

```bash
# Extract subset of array
declare -a numbers=(0 1 2 3 4 5 6 7 8 9)

# Elements 2-5 (4 elements starting at index 2)
declare -a subset=("${numbers[@]:2:4}")
echo "${subset[@]}"  # Output: 2 3 4 5
```

**5. Removing duplicates:**

```bash
# Remove duplicates from array (preserves order)
remove_duplicates() {
  local -a input=("$@")
  local -a output=()
  local -A seen=()
  local -- item

  for item in "${input[@]}"; do
    if [[ ! -v seen[$item] ]]; then
      output+=("$item")
      seen[$item]=1
    fi
  done

  printf '%s\n' "${output[@]}"
}

declare -a with_dupes=('a' 'b' 'a' 'c' 'b' 'd')
declare -a unique
readarray -t unique < <(remove_duplicates "${with_dupes[@]}")
echo "${unique[@]}"  # Output: a b c d
```

**Summary:**

- **Use arrays for all lists** - files, arguments, options, any collection
- **Arrays preserve element boundaries** - no word splitting or glob expansion
- **Safe command construction** - build commands in arrays, expand with `"${array[@]}"`
- **Safe iteration** - `for item in "${array[@]}"` processes each element exactly once
- **Dynamic building** - arrays can be built conditionally and modified safely
- **Function arguments** - pass arrays with `"${array[@]}"`, receive with `local -a arr=("$@")`
- **Never use string lists** - they break with spaces, quotes, or special characters
- **Avoid IFS manipulation** - use arrays instead
- **Quote array expansion** - always use `"${array[@]}"` not `${array[@]}`

**Key principle:** Arrays are the safe, correct way to handle lists in Bash. String-based lists inevitably fail with edge cases (spaces, wildcards, special chars). Every list, whether of files, arguments, or values, should be stored in an array and expanded with `"${array[@]}"`. This eliminates entire categories of bugs and makes scripts robust against unexpected input.
