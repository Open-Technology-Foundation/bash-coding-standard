### Array Expansions

**Always quote array expansions with double quotes to preserve element boundaries and prevent word splitting. Use `"${array[@]}"` for separate elements and `"${array[*]}"` for a single concatenated string. Proper array quoting is critical for handling elements containing spaces, newlines, or special characters.**

**Rationale:**

- **Element Preservation**: `"${array[@]}"` preserves each element as a separate word, regardless of content
- **Word Splitting Prevention**: Unquoted arrays undergo word splitting, breaking elements on whitespace
- **Glob Protection**: Unquoted arrays trigger pathname expansion on glob characters
- **Empty Element Handling**: Quoted arrays preserve empty elements; unquoted arrays lose them
- **Predictable Behavior**: Quoting ensures consistent behavior across different array contents
- **Safe Iteration**: Quoted `"${array[@]}"` is the only safe way to iterate over array elements

**Basic array expansion forms:**

**1. Expand all elements as separate words (`[@]`):**

```bash
# Create array
declare -a files=('file1.txt' 'file 2.txt' 'file3.txt')

# ✓ Correct - quoted expansion (3 elements)
for file in "${files[@]}"; do
  echo "$file"
done
# Output:
# file1.txt
# file 2.txt
# file3.txt

# ✗ Wrong - unquoted expansion (4 elements due to word splitting!)
for file in ${files[@]}; do
  echo "$file"
done
# Output:
# file1.txt
# file
# 2.txt
# file3.txt
```

**2. Expand all elements as single string (`[*]`):**

```bash
# Array of words
declare -a words=('hello' 'world' 'foo' 'bar')

# ✓ Correct - single space-separated string
combined="${words[*]}"
echo "$combined"  # Output: hello world foo bar

# With custom IFS
IFS=','
combined="${words[*]}"
echo "$combined"  # Output: hello,world,foo,bar
IFS=' '
```

**When to use [@] vs [*]:**

**Use `[@]` (expand to separate words):**

```bash
# 1. Iteration
for item in "${array[@]}"; do
  process "$item"
done

# 2. Passing to functions
my_function "${array[@]}"

# 3. Passing to commands
grep pattern "${files[@]}"

# 4. Building new arrays
new_array=("${old_array[@]}" "additional" "elements")

# 5. Copying arrays
copy=("${original[@]}")
```

**Use `[*]` (expand to single string):**

```bash
# 1. Concatenating for output
echo "Items: ${array[*]}"

# 2. Custom separator with IFS
IFS=','
csv="${array[*]}"  # Creates comma-separated values

# 3. String comparison
if [[ "${array[*]}" == "one two three" ]]; then

# 4. Logging multiple values
log "Processing: ${files[*]}"
```

**Complete array expansion examples:**

**1. Safe array iteration:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Process files with spaces in names
process_files() {
  local -a files=(
    'document 1.txt'
    'report (final).pdf'
    'data-2024.csv'
  )

  local -- file
  local -i count=0

  # ✓ Correct - quoted expansion
  for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
      info "Processing: $file"
      ((count+=1))
    else
      warn "File not found: $file"
    fi
  done

  info "Processed $count files"
}

# Pass array to function
process_items() {
  local -a items=("$@")  # Capture arguments as array
  local -- item

  info "Received ${#items[@]} items"

  for item in "${items[@]}"; do
    info "Item: $item"
  done
}

main() {
  declare -a my_items=('item one' 'item two' 'item three')

  # ✓ Correct - pass array elements as separate arguments
  process_items "${my_items[@]}"

  # Process files
  process_files
}

main "$@"

#fin
```

**2. Array with custom IFS:**

```bash
# Create CSV from array
create_csv() {
  local -a data=("$@")
  local -- csv

  # Save original IFS
  local -- old_ifs="$IFS"

  # Set custom separator
  IFS=','
  csv="${data[*]}"  # Uses IFS as separator

  # Restore IFS
  IFS="$old_ifs"

  echo "$csv"
}

# Usage
declare -a fields=('name' 'age' 'email')
csv_line=$(create_csv "${fields[@]}")
echo "$csv_line"  # Output: name,age,email
```

**3. Building arrays from arrays:**

```bash
# Combine multiple arrays
declare -a fruits=('apple' 'banana')
declare -a vegetables=('carrot' 'potato')
declare -a dairy=('milk' 'cheese')

# ✓ Correct - combine arrays
declare -a all_items=(
  "${fruits[@]}"
  "${vegetables[@]}"
  "${dairy[@]}"
)

echo "Total items: ${#all_items[@]}"  # Output: 6

# Add prefix to each element
declare -a files=('report.txt' 'data.csv')
declare -a prefixed=()

local -- file
for file in "${files[@]}"; do
  prefixed+=("/backup/$file")
done

# Result: /backup/report.txt, /backup/data.csv
```

**4. Array expansion in commands:**

```bash
# Pass array elements to command
declare -a search_paths=(
  '/usr/local/bin'
  '/usr/bin'
  '/opt/custom/bin'
)

# ✓ Correct - each path is separate argument
find "${search_paths[@]}" -type f -name 'myapp'

# Grep multiple patterns
declare -a patterns=('error' 'warning' 'critical')

# ✓ Correct - each pattern as separate -e argument
local -- pattern
local -a grep_args=()
for pattern in "${patterns[@]}"; do
  grep_args+=(-e "$pattern")
done

grep "${grep_args[@]}" logfile.txt
```

**5. Conditional array checks:**

```bash
# Check if array contains value
array_contains() {
  local -- needle="$1"
  shift
  local -a haystack=("$@")
  local -- item

  for item in "${haystack[@]}"; do
    [[ "$item" == "$needle" ]] && return 0
  done

  return 1
}

declare -a allowed_users=('alice' 'bob' 'charlie')

if array_contains 'bob' "${allowed_users[@]}"; then
  info 'User authorized'
else
  error 'User not authorized'
fi
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - unquoted [@] expansion
declare -a files=('file 1.txt' 'file 2.txt')
for file in ${files[@]}; do
  echo "$file"
done
# Splits on spaces: 'file', '1.txt', 'file', '2.txt'

# ✓ Correct - quoted expansion
for file in "${files[@]}"; do
  echo "$file"
done
# Preserves: 'file 1.txt', 'file 2.txt'

# ✗ Wrong - unquoted [*] expansion
declare -a items=('one' 'two' 'three')
combined=${items[*]}  # Unquoted

# ✓ Correct - quoted expansion
combined="${items[*]}"

# ✗ Wrong - using [@] without quotes in assignment
declare -a source=('a' 'b' 'c')
copy=(${source[@]})  # Wrong - word splitting!

# ✓ Correct - quoted expansion
copy=("${source[@]}")

# ✗ Wrong - unquoted array in function call
my_function ${array[@]}  # Word splitting on each element

# ✓ Correct - quoted expansion
my_function "${array[@]}"

# ✗ Wrong - using [*] for iteration
for item in "${array[*]}"; do  # Single iteration with all elements!
  echo "$item"
done

# ✓ Correct - using [@] for iteration
for item in "${array[@]}"; do  # Separate iteration per element
  echo "$item"
done

# ✗ Wrong - unquoted array with glob characters
declare -a patterns=('*.txt' '*.md')
for pattern in ${patterns[@]}; do
  # Glob expansion happens - wrong!
  echo "$pattern"
done

# ✓ Correct - quoted to preserve literal values
for pattern in "${patterns[@]}"; do
  echo "$pattern"
done

# ✗ Wrong - using [@] for string concatenation
declare -a words=('hello' 'world')
sentence="${words[@]}"  # Results in "hello world" but fragile

# ✓ Correct - using [*] for concatenation
sentence="${words[*]}"  # Explicitly concatenates

# ✗ Wrong - forgetting quotes in command substitution
result=$(echo ${array[@]})  # Word splitting in subshell

# ✓ Correct - quoted expansion
result=$(echo "${array[@]}")

# ✗ Wrong - partial quoting
for item in "${array[@]"; do  # Missing closing quote!

# ✓ Correct - properly quoted
for item in "${array[@]}"; do
```

**Edge cases and special scenarios:**

**1. Empty arrays:**

```bash
# Empty array
declare -a empty=()

# ✓ Correct - safe iteration (zero iterations)
for item in "${empty[@]}"; do
  echo "$item"  # Never executes
done

# Array count
echo "Count: ${#empty[@]}"  # Output: 0
```

**2. Arrays with empty elements:**

```bash
# Array with empty string
declare -a mixed=('first' '' 'third')

# ✓ Quoted - preserves empty element (3 iterations)
for item in "${mixed[@]}"; do
  echo "Item: [$item]"
done
# Output:
# Item: [first]
# Item: []
# Item: [third]

# ✗ Unquoted - loses empty element (2 iterations)
for item in ${mixed[@]}; do
  echo "Item: [$item]"
done
# Output:
# Item: [first]
# Item: [third]
```

**3. Arrays with newlines:**

```bash
# Array with newline in element
declare -a data=(
  'line one'
  $'line two\nline three'
  'line four'
)

# ✓ Quoted - preserves newline
for item in "${data[@]}"; do
  echo "Item: $item"
  echo "---"
done
```

**4. Associative arrays:**

```bash
# Associative array
declare -A config=(
  [name]='myapp'
  [version]='1.0.0'
)

# ✓ Correct - iterate over keys
for key in "${!config[@]}"; do
  echo "$key = ${config[$key]}"
done

# ✓ Correct - iterate over values
for value in "${config[@]}"; do
  echo "Value: $value"
done
```

**5. Array slicing:**

```bash
# Array slicing
declare -a numbers=(0 1 2 3 4 5 6 7 8 9)

# ✓ Correct - quoted slice
subset=("${numbers[@]:2:4}")  # Elements 2-5
echo "${subset[@]}"  # Output: 2 3 4 5

# All elements from index 5
tail=("${numbers[@]:5}")
echo "${tail[@]}"  # Output: 5 6 7 8 9
```

**6. Parameter expansion with arrays:**

```bash
# Modify array elements
declare -a paths=('/usr/bin' '/usr/local/bin')

# Remove prefix from all elements
declare -a basenames=("${paths[@]##*/}")
echo "${basenames[@]}"  # Output: bin bin

# Add suffix to all elements
declare -a configs=('app' 'db' 'cache')
declare -a config_files=("${configs[@]/%/.conf}")
echo "${config_files[@]}"  # Output: app.conf db.conf cache.conf
```

**Testing array expansions:**

```bash
# Test word splitting behavior
test_word_splitting() {
  local -a test_array=('one two' 'three')

  # Count with quoted expansion
  local -a quoted=("${test_array[@]}")
  local -i quoted_count="${#quoted[@]}"

  # Count with unquoted expansion (DON'T DO THIS - just for testing)
  set -f  # Disable globbing for test
  local -a unquoted=(${test_array[@]})
  local -i unquoted_count="${#unquoted[@]}"
  set +f

  echo "Quoted count: $quoted_count"    # Output: 2
  echo "Unquoted count: $unquoted_count" # Output: 3

  [[ $quoted_count -eq 2 ]] || die 1 'Quoted expansion failed'
  info 'Array expansion test passed'
}

# Test empty element preservation
test_empty_elements() {
  local -a with_empty=('first' '' 'third')

  local -i count=0
  local -- item

  for item in "${with_empty[@]}"; do
    ((count+=1))
  done

  [[ $count -eq 3 ]] || die 1 'Empty element not preserved'
  info 'Empty element test passed'
}
```

**When to use different expansion forms:**

```bash
# [@] - Separate elements (most common)
# Use for:
# - Function arguments: func "${array[@]}"
# - Command arguments: cmd "${array[@]}"
# - Iteration: for item in "${array[@]}"
# - Array copying: copy=("${array[@]}")

# [*] - Single string (less common)
# Use for:
# - Display: echo "Items: ${array[*]}"
# - Logging: log "Values: ${array[*]}"
# - CSV with IFS: IFS=','; csv="${array[*]}"
# - String comparison: [[ "${array[*]}" == "a b c" ]]

# Individual element access (no quotes needed for single element)
echo "${array[0]}"     # First element
echo "${array[-1]}"    # Last element (Bash 4.3+)
echo "${array[index]}" # Specific index

# Array length (no quotes needed)
echo "${#array[@]}"    # Number of elements
```

**Summary:**

- **Always quote array expansions**: `"${array[@]}"` or `"${array[*]}"`
- **Use `[@]`** for separate elements (iteration, function args, commands)
- **Use `[*]`** for single concatenated string (display, logging, CSV)
- **Quoted `[@]`** is the only safe iteration form
- **Unquoted arrays** undergo word splitting and glob expansion (dangerous!)
- **Empty elements** are preserved only with quoted expansion
- **Consistent quoting** prevents subtle bugs with spaces, newlines, or special chars
- **Element boundaries** are maintained only when properly quoted

**Key principle:** Array expansion quoting is non-negotiable. The form `"${array[@]}"` is the standard, safe way to expand arrays. Any deviation from quoted expansion introduces word splitting and glob expansion bugs. When you need a single string, explicitly use `"${array[*]}"`. When iterating or passing to functions/commands, always use `"${array[@]}"`.
