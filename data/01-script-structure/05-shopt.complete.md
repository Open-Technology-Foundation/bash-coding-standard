## shopt

**Recommended settings for most scripts:**

```bash
# STRONGLY RECOMMENDED - apply to all scripts
shopt -s inherit_errexit  # Critical: makes set -e work in subshells,
                          # command substitutions
shopt -s shift_verbose    # Catches shift errors when no arguments remain
shopt -s extglob          # Enables extended glob patterns like !(*.txt)

# CHOOSE ONE based on use case:
shopt -s nullglob   # For arrays/loops: unmatched globs → empty (no error)
                # OR
shopt -s failglob   # For strict scripts: unmatched globs → error

# OPTIONAL based on needs:
shopt -s globstar   # Enable ** for recursive matching (slow on deep trees)
```

**Detailed rationale for each setting:**

**`inherit_errexit` (CRITICAL):**
- **Without it**: `set -e` does NOT apply inside command substitutions or subshells
- **With it**: Errors in `$(...)` and `(...)` properly propagate
- **Example of the problem:**
```bash
set -e  # Without inherit_errexit
result=$(false)  # This does NOT exit the script!
echo "Still running"  # This executes

# With inherit_errexit
shopt -s inherit_errexit
result=$(false)  # Script exits here as expected
```

**`shift_verbose`:**
- **Without it**: `shift` silently fails when no arguments remain, continues execution
- **With it**: Prints error message when shift fails (respects `set -e`)
- **Example:**
```bash
shopt -s shift_verbose
shift  # If no arguments: "bash: shift: shift count must be <= $#"
```

**`extglob`:**
- **Enables advanced pattern matching** that regular globs cannot do
- **Patterns enabled**: `?(pattern)`, `*(pattern)`, `+(pattern)`, `@(pattern)`, `!(pattern)`
- **Example use cases:**
```bash
shopt -s extglob

# Delete everything EXCEPT .txt files
rm !(*.txt)

# Match files with multiple extensions
cp *.@(jpg|png|gif) /destination/

# Match one or more digits
[[ $input == +([0-9]) ]] && echo "Number"
```

**`nullglob` vs `failglob` (Choose one):**

**`nullglob`:**
- **Best for**: Scripts that process file lists in loops/arrays
- **Behavior**: Unmatched glob expands to empty string (no error)
- **Example:**
```bash
shopt -s nullglob
for file in *.txt; do  # If no .txt files, loop body never executes
  echo "$file"
done

files=(*.log)  # If no .log files: files=() (empty array)
```

**`failglob`:**
- **Best for**: Strict scripts where unmatched glob indicates an error
- **Behavior**: Unmatched glob causes error (respects `set -e`)
- **Example:**
```bash
shopt -s failglob
cat *.conf  # If no .conf files: "bash: no match: *.conf" (exits with set -e)
```

**Without either (default bash behavior):**
```bash
# ✗ Dangerous default behavior
for file in *.txt; do  # If no .txt files, $file = literal string "*.txt"
  rm "$file"  # Tries to delete file named "*.txt"!
done
```

**`globstar` (OPTIONAL):**
- **Enables `**` for recursive directory matching** (like `find`)
- **Warning**: Can be slow on deep directory trees
- **Example:**
```bash
shopt -s globstar

# Recursively find all .sh files
for script in **/*.sh; do
  shellcheck "$script"
done

# Equivalent to: find . -name '*.sh' -type f
```

**Typical script configuration:**
```bash
#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob
```

**When NOT to use these settings:**
- **Interactive scripts**: May want more lenient behavior
- **Legacy compatibility**: Older bash versions may not support all options
- **Performance-critical loops**: `globstar` can be slow on large trees
