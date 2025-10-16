### Conditionals

**Use `[[ ]]` for string/file tests, `(())` for arithmetic:**

\`\`\`bash
# String and file tests - use [[ ]]
[[ -d "$path" ]] && echo 'Directory exists'
[[ -f "$file" ]] || die 1 "File not found: $file"
[[ "$status" == 'success' ]] && continue

# Arithmetic tests - use (())
((VERBOSE==0)) || echo 'Verbose mode'
((var > 5)) || return 1
((count >= MAX_RETRIES)) && die 1 'Too many retries'

# Complex conditionals - combine both
if [[ -n "$var" ]] && ((count > 0)); then
  process_data
fi

# Short-circuit evaluation
[[ -f "$file" ]] && source "$file"
((VERBOSE)) || return 0
\`\`\`

**Rationale for `[[ ]]` over `[ ]`:**

1. **No word splitting or glob expansion** on variables
2. **Pattern matching** with `==` and `=~` operators
3. **Logical operators** `&&` and `||` work inside (no `-a` / `-o` needed)
4. **No need to quote variables** in most cases (but still recommended)
5. **More operators**: `<`, `>` for string comparison (lexicographic)

**Comparison of `[[ ]]` vs `[ ]`:**

\`\`\`bash
var="two words"

# ✗ [ ] requires quotes or fails
[ $var = "two words" ]  # ERROR: too many arguments
[ "$var" = "two words" ]  # Works but fragile

# ✓ [[ ]] handles unquoted variables (but quote anyway)
[[ $var == "two words" ]]  # Works even without quotes
[[ "$var" == "two words" ]]  # Recommended - quote anyway

# Pattern matching (only works in [[ ]])
[[ "$file" == *.txt ]] && echo "Text file"
[[ "$input" =~ ^[0-9]+$ ]] && echo "Number"

# Logical operators inside [[ ]]
[[ -f "$file" && -r "$file" ]] && cat "$file"

# vs [ ] requires separate tests
[ -f "$file" ] && [ -r "$file" ] && cat "$file"
\`\`\`

**Arithmetic conditionals - use `(())`:**

\`\`\`bash
# ✓ Correct - natural C-style syntax
if ((count > 0)); then
  echo "Count: $count"
fi

((i >= MAX)) && die 1 'Limit exceeded'

# ✗ Wrong - using [[ ]] for arithmetic (verbose, error-prone)
if [[ "$count" -gt 0 ]]; then  # Unnecessary
  echo "Count: $count"
fi

# Comparison operators in (())
((a > b))   # Greater than
((a >= b))  # Greater or equal
((a < b))   # Less than
((a <= b))  # Less or equal
((a == b))  # Equal
((a != b))  # Not equal
\`\`\`

**Pattern matching examples:**

\`\`\`bash
# Glob pattern matching
[[ "$filename" == *.@(jpg|png|gif) ]] && process_image "$filename"

# Regular expression matching
if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  echo "Valid email"
else
  die 22 "Invalid email: $email"
fi

# Case-insensitive matching (bash 3.2+)
shopt -s nocasematch
[[ "$input" == "yes" ]] && echo "Affirmative"  # Matches YES, Yes, yes
shopt -u nocasematch
\`\`\`

**Short-circuit evaluation:**

\`\`\`bash
# Execute second command only if first succeeds
[[ -f "$config" ]] && source "$config"
((DEBUG)) && set -x

# Execute second command only if first fails
[[ -d "$dir" ]] || mkdir -p "$dir"
((count > 0)) || die 1 'No items to process'

# Chaining multiple conditions
[[ -f "$file" ]] && [[ -r "$file" ]] && cat "$file"
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - using old [ ] syntax
if [ -f "$file" ]; then  # Use [[ ]] instead
  echo "Found"
fi

# ✗ Wrong - using -a and -o in [ ]
[ -f "$file" -a -r "$file" ]  # Deprecated, fragile

# ✓ Correct - use [[ ]] with && and ||
[[ -f "$file" && -r "$file" ]]

# ✗ Wrong - string comparison with [ ] unquoted
[ $var = "value" ]  # Breaks if var contains spaces

# ✓ Correct - use [[ ]] (still quote for clarity)
[[ "$var" == "value" ]]

# ✗ Wrong - arithmetic with [[ ]] using -gt/-lt
[[ "$count" -gt 10 ]]  # Verbose, less readable

# ✓ Correct - use (()) for arithmetic
((count > 10))
\`\`\`

**Common file test operators (use with `[[ ]]`):**

| Operator | Meaning |
|----------|---------|
| `-e file` | File exists |
| `-f file` | Regular file |
| `-d dir` | Directory |
| `-r file` | Readable |
| `-w file` | Writable |
| `-x file` | Executable |
| `-s file` | Not empty (size > 0) |
| `-L link` | Symbolic link |
| `file1 -nt file2` | file1 newer than file2 |
| `file1 -ot file2` | file1 older than file2 |

**Common string test operators (use with `[[ ]]`):**

| Operator | Meaning |
|----------|---------|
| `-z "$str"` | String is empty (zero length) |
| `-n "$str"` | String is not empty |
| `"$a" == "$b"` | Strings are equal |
| `"$a" != "$b"` | Strings are not equal |
| `"$a" < "$b"` | Lexicographic less than |
| `"$a" > "$b"` | Lexicographic greater than |
| `"$str" =~ regex` | String matches regex |
| `"$str" == pattern` | String matches glob pattern |
