## Arithmetic Operations

**Declare integer variables explicitly:**

\`\`\`bash
# Always declare integer variables with -i flag
declare -i i j result count total

# Or declare with initial value
declare -i counter=0
declare -i max_retries=3
\`\`\`

**Rationale for `declare -i`:**
- **Automatic arithmetic context**: All assignments become arithmetic (no need for `$(())`)
- **Type safety**: Helps catch errors when non-numeric values assigned
- **Performance**: Slightly faster for repeated arithmetic operations
- **Clarity**: Signals to readers that variable holds numeric values

**Increment operations:**

\`\`\`bash
# ✓ PREFERRED: Simple increment (works with or without declare -i)
i+=1              # Clearest, most readable
((i+=1))          # Also safe, always returns 0 (success)

# ✓ SAFE: Pre-increment (returns value AFTER increment)
((++i))           # Returns new value, safe with set -e

# ✗ DANGEROUS: Post-increment (returns value BEFORE increment)
((i++))           # AVOID! Returns old value
                  # If i=0, returns 0 (false), triggers set -e exit!
\`\`\`

**Why `((i++))` is dangerous:**

\`\`\`bash
#!/usr/bin/env bash
set -e  # Exit on error

i=0
((i++))  # Returns 0 (the old value), which is "false"
         # Script exits here with set -e!
         # i now equals 1, but we never reach next line

echo "This never executes"
\`\`\`

**Safe demonstration:**

\`\`\`bash
#!/usr/bin/env bash
set -e

# ✓ Safe patterns
i=0
i+=1      # i=1, no exit
echo "i=$i"

j=0
((++j))   # j=1, returns 1 (true), no exit
echo "j=$j"

k=0
((k+=1))  # k=1, returns 0 (always success), no exit
echo "k=$k"
\`\`\`

**Arithmetic expressions:**

\`\`\`bash
# In (()) - no $ needed for variables
((result = x * y + z))
((i = j * 2 + 5))
((total = sum / count))

# With $(()), for use in assignments or commands
result=$((x * y + z))
echo "$((i * 2 + 5))"
args=($((count - 1)))  # In array context
\`\`\`

**Arithmetic operators:**

| Operator | Meaning | Example |
|----------|---------|---------|
| `+` | Addition | `((i = a + b))` |
| `-` | Subtraction | `((i = a - b))` |
| `*` | Multiplication | `((i = a * b))` |
| `/` | Integer division | `((i = a / b))` |
| `%` | Modulo (remainder) | `((i = a % b))` |
| `**` | Exponentiation | `((i = a ** b))` |
| `++` / `--` | Increment/Decrement | Use `i+=1` instead |
| `+=` / `-=` | Compound assignment | `((i+=5))` |

**Arithmetic conditionals:**

\`\`\`bash
# Use (()) for arithmetic comparisons
if ((i < j)); then
  echo 'i is less than j'
fi

((count > 0)) && process_items
((attempts >= max_retries)) && die 1 'Too many attempts'

# All C-style operators work
((i >= 10)) && echo 'Ten or more'
((i <= 5)) || echo 'More than five'
((i == j)) && echo 'Equal'
((i != j)) && echo 'Not equal'
\`\`\`

**Comparison operators in (()):**

| Operator | Meaning |
|----------|---------|
| `<` | Less than |
| `<=` | Less than or equal |
| `>` | Greater than |
| `>=` | Greater than or equal |
| `==` | Equal |
| `!=` | Not equal |

**Complex expressions:**

\`\`\`bash
# Parentheses for grouping
((result = (a + b) * (c - d)))

# Multiple operations
((total = sum + count * average / 2))

# Ternary operator (bash 5.2+)
((max = a > b ? a : b))

# Bitwise operations
((flags = flag1 | flag2))  # Bitwise OR
((masked = value & 0xFF))  # Bitwise AND
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - using [[ ]] for arithmetic
[[ "$count" -gt 10 ]]  # Verbose, old-style

# ✓ Correct - use (())
((count > 10))

# ✗ Wrong - post-increment
((i++))  # Dangerous with set -e when i=0

# ✓ Correct - use +=1
i+=1

# ✗ Wrong - expr command (slow, external)
result=$(expr $i + $j)

# ✓ Correct - use $(()) or (())
result=$((i + j))
((result = i + j))

# ✗ Wrong - $ inside (()) on left side
((result = $i + $j))  # Unnecessary $

# ✓ Correct - no $ inside (())
((result = i + j))

# ✗ Wrong - quotes around arithmetic
result="$((i + j))"  # Unnecessary quotes

# ✓ Correct - no quotes needed
result=$((i + j))
\`\`\`

**Integer division gotcha:**

\`\`\`bash
# Integer division truncates (rounds toward zero)
((result = 10 / 3))  # result=3, not 3.333...
((result = -10 / 3)) # result=-3, not -3.333...

# For floating point, use bc or awk
result=$(bc <<< "scale=2; 10 / 3")  # result=3.33
result=$(awk 'BEGIN {print 10/3}')   # result=3.33333
\`\`\`

**Practical examples:**

\`\`\`bash
# Loop counter
declare -i i
for ((i=0; i<10; i+=1)); do
  echo "Iteration $i"
done

# Retry logic
declare -i attempts=0
declare -i max_attempts=5
while ((attempts < max_attempts)); do
  if process_item; then
    break
  fi
  attempts+=1
  ((attempts < max_attempts)) && sleep 1
done
((attempts >= max_attempts)) && die 1 'Max attempts reached'

# Percentage calculation
declare -i total=100
declare -i completed=37
declare -i percentage=$((completed * 100 / total))
echo "Progress: $percentage%"
\`\`\`
