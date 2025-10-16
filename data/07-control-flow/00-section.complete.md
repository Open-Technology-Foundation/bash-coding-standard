## Control Flow

This section establishes patterns for conditionals, loops, case statements, and arithmetic operations. It mandates using `[[ ]]` over `[ ]` for test expressions, `(())` for arithmetic conditionals, and covers both compact case statement formats and expanded formats for complex logic. Critical guidance includes preferring process substitution (`< <(command)`) over pipes to while loops to avoid subshell variable persistence issues, and using safe arithmetic patterns: `i+=1` or `((i+=1))` instead of `((i++))` which returns the original value and fails with `set -e` when i=0.
