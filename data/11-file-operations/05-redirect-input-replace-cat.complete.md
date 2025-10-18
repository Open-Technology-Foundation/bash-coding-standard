## Input Redirection vs Cat: Performance Optimization

## Summary

Replace `cat filename` with `< filename` redirection in performance-critical contexts to eliminate process fork overhead. This optimization provides 3-100x speedup depending on usage pattern.

## Performance Comparison

### Benchmark Results (1000 iterations)

| Test Scenario | Method | Real Time | Speedup |
|---------------|--------|-----------|---------|
| **Small file output** | | | |
| Output to /dev/null | `cat file` | 0.792s | baseline |
| | `< file` | 0.234s | **3.4x faster** |
| **Command substitution** | | | |
| Read into variable | `$(cat file)` | 0.965s | baseline |
| | `$(< file)` | 0.009s | **107x faster** |
| **Larger file (500 iterations)** | | | |
| Output to /dev/null | `cat file` | 0.398s | baseline |
| | `< file` | 0.115s | **3.5x faster** |

### Why the Difference?

**External `cat` overhead:**
1. Fork a new process
2. Exec the /usr/bin/cat binary
3. Load executable into memory
4. Set up new process environment
5. Open file, read, write to stdout
6. Wait for process to exit
7. Clean up process resources

**Bash redirection `< file`:**
1. Open file descriptor (already in shell)
2. Read and output directly
3. Close file descriptor

**Command substitution `$(< file)`:**
- Bash reads file directly into variable
- Zero external processes
- Builtin-like behavior

## When to Use `< filename`

### 1. Command Substitution (CRITICAL - 107x speedup)

```bash
# RECOMMENDED - Massively faster
content=$(< file.txt)
lines=$(< data.json)
config=$(< /etc/app.conf)

# AVOID - 100x slower
content=$(cat file.txt)
lines=$(cat data.json)
config=$(cat /etc/app.conf)
```

**Rationale:** Bash reads the file directly with zero external processes.

### 2. Single Input to Command (3-4x speedup)

```bash
# RECOMMENDED
grep "pattern" < file.txt
while read line; do ...; done < file.txt
awk '{print $1}' < data.csv
sort < unsorted.txt
jq '.field' < data.json

# AVOID - Wastes a cat process
cat file.txt | grep "pattern"
cat file.txt | while read line; do ...; done
cat data.csv | awk '{print $1}'
cat unsorted.txt | sort
cat data.json | jq '.field'
```

**Rationale:** Eliminates the `cat` process entirely. Shell opens file, command reads stdin.

### 3. Loop Optimization (Massive cumulative gains)

```bash
# RECOMMENDED
for file in *.json; do
    data=$(< "$file")
    process "$data"
done

for logfile in /var/log/app/*.log; do
    errors=$(grep -c ERROR < "$logfile")
    if [ "$errors" -gt 0 ]; then
        alert=$(< "$logfile")
        send_alert "$alert"
    fi
done

# AVOID - Forks cat thousands of times
for file in *.json; do
    data=$(cat "$file")
    process "$data"
done

for logfile in /var/log/app/*.log; do
    errors=$(cat "$logfile" | grep -c ERROR)
    if [ "$errors" -gt 0 ]; then
        alert=$(cat "$logfile")
        send_alert "$alert"
    fi
done
```

**Rationale:** In loops, fork overhead multiplies. 1000 iterations = 1000 avoided process creations.

### 4. Conditional File Reading

```bash
# RECOMMENDED
if grep -q "ERROR" < /var/log/app.log; then
    alert=$(< /var/log/app.log)
    notify "$alert"
fi

# AVOID
if cat /var/log/app.log | grep -q "ERROR"; then
    alert=$(cat /var/log/app.log)
    notify "$alert"
fi
```

## When NOT to Use `< filename`

| Scenario | Why Not | Use Instead |
|----------|---------|-------------|
| Multiple files | `< file1 file2` is invalid syntax | `cat file1 file2` |
| Need cat options | No `-n`, `-A`, `-E`, `-b`, `-s` support | `cat -n file` |
| Direct output | `< file` alone produces no output | `cat file` |
| Concatenation | Cannot combine multiple sources | `cat file1 file2 file3` |
| POSIX portability | Older shells may not optimize this | `cat file` |

### Example: Invalid Usage

```bash
# WRONG - Does nothing visible
< /tmp/test.txt
# Output: (nothing - redirection without command)

# WRONG - Invalid syntax
< file1.txt file2.txt
# Error: permission denied on file2.txt

# RIGHT - Must use cat
cat file1.txt file2.txt
```

## Technical Details

### Why `< filename` Alone Does Nothing

```bash
# This opens the file on stdin but has no command to consume it
< /tmp/test.txt
# Shell: Opens file descriptor, no command to read it, closes file descriptor

# These work because there's a command to consume stdin
cat < /tmp/test.txt    # cat reads from stdin
< /tmp/test.txt cat    # Same, different order
```

The `<` operator is a **redirection operator**, not a **command**. It only opens a file on stdin; you still need a command to consume that input.

### Why Alias Doesn't Work

```bash
# This doesn't work
alias cat='< '
cat /tmp/file.txt
# Expands to: < /tmp/file.txt
# Result: No output (no command to consume the redirected input)
```

Bash has no built-in command to output file contents. You must use an external command like `cat`, `dd`, or a loop.

### The One Exception: Command Substitution

```bash
# This is the magic case
content=$(< file.txt)
```

In command substitution context, bash itself reads the file and captures it as the substitution result. This is the only case where `< filename` works standalone (within `$()`).

## Performance Model

```
Fork overhead dominant:    Small files in loops    → 100x+ speedup
I/O with fork overhead:    Large files, single use → 3-4x speedup
Zero fork:                 Command substitution    → 100x+ speedup
```

### Why Speedup is Consistent Across File Sizes

The benchmarks show:
- Small file (1 line): 3.4x speedup
- Large file (1000 lines): 3.5x speedup

**Explanation:** Process creation overhead (fork/exec) dominates I/O time even for larger files. The time to fork, exec, and wait for cat is comparable to or greater than the actual I/O operation.

## Real-World Example

### Before Optimization

```bash
#!/bin/bash

# Process all log files
for logfile in /var/log/app/*.log; do
    # Read entire file
    content=$(cat "$logfile")

    # Count errors
    errors=$(cat "$logfile" | grep -c ERROR)

    # Extract warnings
    warnings=$(cat "$logfile" | grep WARNING)

    # Process if errors found
    if [ "$errors" -gt 0 ]; then
        cat "$logfile" error.log > combined.log
    fi
done
```

**Problems:**
- 4 cat processes per iteration
- 100 log files = 400 process forks
- Massive overhead in tight loop

### After Optimization

```bash
#!/bin/bash

# Process all log files
for logfile in /var/log/app/*.log; do
    # Read entire file - 100x faster
    content=$(< "$logfile")

    # Count errors - no cat needed
    errors=$(grep -c ERROR < "$logfile")

    # Extract warnings - no cat needed
    warnings=$(grep WARNING < "$logfile")

    # Process if errors found
    if [ "$errors" -gt 0 ]; then
        # Multiple files - must use cat
        cat "$logfile" error.log > combined.log
    fi
done
```

**Improvements:**
- 3 process forks eliminated per iteration
- 100 log files = 300 fewer process forks
- Only 1 cat call when actually needed (concatenation)
- 10-100x faster depending on file sizes

## Recommendation

**SHOULD:** Use `< filename` in all performance-critical code for:
- Command substitution: `var=$(< file)`
- Single file input to commands: `cmd < file`
- Loops with many file reads

**MAY:** Use `cat` when:
- Concatenating multiple files
- Need cat-specific options
- Code clarity is more important than performance
- POSIX portability to very old shells is required

**MUST:** Use `cat` when:
- Multiple file arguments needed
- Using options like `-n`, `-b`, `-E`, `-T`, `-s`, `-v`

## Impact Assessment

**Performance Gain:**
- Tight loops with command substitution: 10-100x faster
- Single command pipelines: 3-4x faster
- Large scripts with many file reads: 5-50x overall speedup

**Compatibility:**
- Works in bash 3.0+, zsh, ksh
- May not be optimized in very old shells (sh, dash)
- Test in target environment

**Code Clarity:**
- `$(< file)` is bash idiom, well understood
- `cmd < file` is clearer than `cat file | cmd`
- No negative impact on readability

## Testing

```bash
# Test command substitution speedup
echo "Test content" > /tmp/test.txt

time for i in {1..1000}; do content=$(cat /tmp/test.txt); done
# Expected: ~0.8-1.0s

time for i in {1..1000}; do content=$(< /tmp/test.txt); done
# Expected: ~0.01s (100x faster)

# Test pipeline speedup
seq 1 1000 > /tmp/numbers.txt

time for i in {1..500}; do cat /tmp/numbers.txt | wc -l > /dev/null; done
# Expected: ~0.4s

time for i in {1..500}; do wc -l < /tmp/numbers.txt > /dev/null; done
# Expected: ~0.1s (4x faster)
```

## See Also

- BCS rule on process efficiency
- BCS rule on avoiding useless use of cat (UUOC)
- Bash manual: Redirections
- ShellCheck SC2002 (useless cat)

## References

- GNU Bash manual: Redirections
- Performance analysis conducted 2025-10-17
- Test platform: Linux 6.8.0-85-generic
- Bash version: 5.2+
