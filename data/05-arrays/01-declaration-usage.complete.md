## Array Declaration and Usage

**Declaring arrays:**

\`\`\`bash
# Indexed arrays (explicitly declared)
declare -a DELETE_FILES=('*~' '~*' '.~*')
declare -a paths=()  # Empty array

# Local arrays in functions
local -a Paths=()
local -a found_files

# Initialize with elements
declare -a colors=('red' 'green' 'blue')
declare -a numbers=(1 2 3 4 5)
\`\`\`

**Rationale for explicit array declaration:**
- **Clarity**: Signals to readers that variable is an array
- **Type safety**: Prevents accidental scalar assignment
- **Scope control**: Use `local -a` in functions to prevent global pollution
- **Consistency**: Makes arrays visually distinct from scalar variables

**Adding elements to arrays:**

\`\`\`bash
# Append single element
Paths+=("$1")
files+=("$filename")

# Append multiple elements
args+=("$arg1" "$arg2" "$arg3")

# Append another array
all_files+=("${config_files[@]}" "${log_files[@]}")
\`\`\`

**Array iteration (always use `"${array[@]}"`)**

\`\`\`bash
# ✓ Correct - quoted expansion, handles spaces safely
for path in "${Paths[@]}"; do
  process "$path"
done

# ✗ Wrong - unquoted, breaks with spaces
for path in ${Paths[@]}; do  # ✗ Dangerous!
  process "$path"
done

# ✗ Wrong - without [@], only processes first element
for path in "$Paths"; do  # ✗ Only iterates once
  process "$path"
done
\`\`\`

**Array length:**

\`\`\`bash
# Get number of elements
file_count=${#files[@]}
((${#Paths[@]} > 0)) && process_paths

# Check if array is empty
if ((${#array[@]} == 0)); then
  echo 'Array is empty'
fi

# Set default if empty
((${#Paths[@]})) || Paths=('.')  # If empty, set to current dir
\`\`\`

**Reading into arrays:**

\`\`\`bash
# Split string by delimiter into array
IFS=',' read -ra fields <<< "$csv_line"
IFS=':' read -ra path_components <<< "$PATH"

# Read command output into array (preferred method)
readarray -t lines < <(grep pattern file)
readarray -t files < <(find . -name "*.txt")

# Alternative: mapfile (same as readarray)
mapfile -t users < <(cut -d: -f1 /etc/passwd)

# Read file into array (one line per element)
readarray -t config_lines < config.txt
\`\`\`

**Rationale for `readarray -t`:**
- **`-t`**: Removes trailing newlines from each element
- **`< <()`**: Process substitution avoids subshell (variables persist)
- **Safety**: Handles filenames with spaces, newlines correctly
- **Clarity**: Purpose is immediately clear

**Accessing array elements:**

\`\`\`bash
# Access single element (0-indexed)
first=${array[0]}
second=${array[1]}
last=${array[-1]}  # Last element (bash 4.3+)

# All elements (for iteration or passing)
"${array[@]}"  # Each element as separate word
"${array[*]}"  # All elements as single word (rarely needed)

# Slice (subset of array)
"${array[@]:2}"     # Elements from index 2 onwards
"${array[@]:1:3}"   # 3 elements starting from index 1
\`\`\`

**Modifying arrays:**

\`\`\`bash
# Unset (delete) an element
unset 'array[3]'  # Remove element at index 3

# Unset last element
unset 'array[${#array[@]}-1]'

# Replace element
array[2]='new value'

# Clear entire array
array=()
unset array  # Also works, but () is clearer
\`\`\`

**Array patterns in practice:**

\`\`\`bash
# Collect arguments during parsing
declare -a input_files=()
while (($#)); do case $1 in
  -*)   handle_option "$1" ;;
  *)    input_files+=("$1") ;;
esac; shift; done

# Process collected files
for file in "${input_files[@]}"; do
  [[ -f "$file" ]] || die 2 "File not found: $file"
  process_file "$file"
done

# Build command arguments dynamically
declare -a find_args=()
find_args+=('-type' 'f')
((max_depth > 0)) && find_args+=('-maxdepth' "$max_depth")
[[ -n "$name_pattern" ]] && find_args+=('-name' "$name_pattern")

find "${search_dir:-.}" "${find_args[@]}"
\`\`\`

**Checking array membership:**

\`\`\`bash
# Check if value exists in array
has_element() {
  local search=$1
  shift
  local element
  for element; do
    [[ "$element" == "$search" ]] && return 0
  done
  return 1
}

# Usage
declare -a valid_options=('start' 'stop' 'restart')
has_element "$action" "${valid_options[@]}" || die 22 "Invalid action: $action"
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - unquoted array expansion
files=(*.txt)
rm ${files[@]}  # Breaks with filenames containing spaces

# ✓ Correct - quoted expansion
files=(*.txt)
rm "${files[@]}"

# ✗ Wrong - iterating with indices (unnecessary complexity)
for i in "${!array[@]}"; do
  echo "${array[$i]}"
done

# ✓ Correct - iterate over values directly
for value in "${array[@]}"; do
  echo "$value"
done

# ✗ Wrong - word splitting to create array
array=($string)  # Dangerous! Splits on whitespace, expands globs

# ✓ Correct - explicit array assignment or readarray
readarray -t array <<< "$string"

# ✗ Wrong - using array[*] in iteration
for item in "${array[*]}"; do  # ✗ Iterates once with all items as one string
  echo "$item"
done

# ✓ Correct - use array[@]
for item in "${array[@]}"; do
  echo "$item"
done
\`\`\`

**Summary of array operators:**

| Operation | Syntax | Description |
|-----------|--------|-------------|
| Declare | `declare -a arr=()` | Create empty array |
| Append | `arr+=("value")` | Add element to end |
| Length | `${#arr[@]}` | Number of elements |
| All elements | `"${arr[@]}"` | Each element as separate word |
| Single element | `"${arr[i]}"` | Element at index i |
| Last element | `"${arr[-1]}"` | Last element (bash 4.3+) |
| Slice | `"${arr[@]:2:3}"` | 3 elements from index 2 |
| Unset element | `unset 'arr[i]'` | Remove element at index i |
| Indices | `"${!arr[@]}"` | All array indices |

**Key principle:** Always quote array expansions: `"${array[@]}"` to preserve spacing and prevent word splitting.
