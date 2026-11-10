---
description: BCS-aligned audit of a Bash 5.2+ codebase -- structure, ShellCheck, security, style
argument-hint: <file-or-directory>
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Bash 5.2+ Raw Code Audit

Perform a comprehensive audit of this Bash codebase targeting **Bash 5.2+ exclusively**. This is a raw code audit with no framework assumptions.

## Context Requirements

- **Bash Version**: 5.2+ only (modern features expected, no compatibility layers)
- **Coding Standard**: Check against Bash Coding Standard (BCS) if present
- **Code Style**: Raw shell scripts, no frameworks
- **Dependencies**: Minimal external dependencies, standard tools only

## 1. BCS Compliance

File `BASH-CODING-STANDARD.md` or `@BASH-CODING-STANDARD.md` may exist in the project; use this as a guide.

- Check for BCS compliance using the `bcscheck` skill (never the binary: it is LLM-backed and denied in managed settings)
- Validate against all 12 BCS sections
- Reference specific BCS codes (format: BCS0102, BCS0205, etc.)

### Script Structure (BCS0100, strongly recommended)
1. Bash Shebang (line 1): `#!/usr/bin/bash`, `#!/bin/bash`, or `#!/usr/bin/env bash`
2. ShellCheck directives (if needed)
3. Brief description comment
4. `set -euo pipefail` (mandatory, lines 4-6)
5. Required shopt: `shopt -s inherit_errexit` (add `shift_verbose extglob nullglob` when appropriate)
6. Script metadata: `VERSION`, `SCRIPT_PATH`, `SCRIPT_DIR`, `SCRIPT_NAME` with `declare -r`; Note: not all scripts will require all these variables.
7. Global variable declarations
8. Color definitions (if terminal output)
9. Utility functions (messaging, helpers)
10. Business logic functions
11. `main()` function (required for scripts >200 lines)
12. Script invocation: `main "$@"`
13. End marker: `#fin`

## 2. ShellCheck Compliance

**Compulsory**: Run ShellCheck on all bash scripts

```bash
shellcheck -x script.sh
```

- Report all warnings and errors
- Validate documented disable directives (must have comments explaining why)
- Flag undocumented suppressions as violations

## 3. Bash 5.2+ Language Features & Control Flow (BCS0500)

### Required Patterns
- `[[ ]]` for conditionals (BCS0501) (NEVER `[ ]`)
- `(( ))` for arithmetic/boolean (BCS0505) (NEVER `expr` or `$[]`)
- Process substitution: `< <(command)` over pipes to while loops
- `declare -n` nameref instead of `eval` for indirection
- `mapfile`/`readarray` for reading files into arrays
- `${var@Q}` for safe quoting when needed

### Forbidden/Deprecated Patterns
- Backticks (use `$()` instead)
- `expr` for arithmetic
- `eval` with user-controlled input (use `declare -n`)
- Increment with plain `count+=1` (BCS0505). NEVER `((count++))`, `((++count))`, `count++`, or `((count+=1))`. Declaring `declare -i count=0` up front ensures `+=1` is arithmetic rather than string concatenation outside arithmetic context.
- Function keyword: `function name()` (use `name()` only)
- `test` or `[` (use `[[` instead)

## 4. Security Vulnerabilities (BCS1000)

### Critical Security Checks

**Command Injection (BCS1004)**
- Unsafe `eval` usage with user/variable input
- `eval` with unvalidated variable names
- Recommend `declare -n` nameref as safe alternative

**Path Traversal**
- Unvalidated `cd` operations
- Missing `realpath` validation before directory changes
- Symlink attack vectors

**Unsafe File Operations**
- `rm -rf` without variable validation
- Missing checks: `[[ -n $var && $var != '/' && $var != '.' ]]`
- Wildcard usage without explicit paths: `rm *` vs `rm ./*`

**SUID/SGID Scripts (BCS1001)**
- FORBIDDEN: Bash scripts must NEVER use SUID/SGID
- Flag any setuid/setgid permissions

**PATH Manipulation (BCS1002)**
- Unsafe PATH modifications
- Missing PATH validation
- Recommend explicit tool paths or PATH locking where appropriate

**Input Validation (BCS1005)**
- Unvalidated user input in critical operations
- Missing argument validation (use noarg pattern)
- Unsanitized input in SQL/command contexts

**Privilege Escalation**
- Unsafe sudo usage
- Group management in install scripts
- SGID directory creation without justification

## 5. Variable Handling & Quoting

### Variable Expansion (BCS0207)
- Default: `"$var"` (no braces unless required)
- Use braces when: `"${var##pattern}"`, `"${var:-default}"`, `"${array[@]}"`, `"${var1}${var2}"`

### Quoting Rules (BCS0301-0303)
- Single quotes for static strings: `info 'Processing files'`
- Double quotes when variables needed: `info "Processing $count files"`
- Never unquoted variables (except in very specific contexts)

### Array Handling (BCS0206)
- Proper array declaration: `declare -a array=()`
- Safe iteration: `for item in "${array[@]}"; do`
- Avoid string splitting as array simulation

### Boolean Flags (BCS0208)
- Pattern: `declare -i FLAG=0`
- Usage: `((FLAG)) && action ||:`, `((!FLAG)) || action`
- NOT: `if [[ $FLAG == '1' ]]`

### Readonly Variables (BCS0205)
- Group readonly declarations: `readonly VAR1 VAR2 VAR3`
- Place after variable initialization

## 6. Function Organization & Design

### Function Structure (BCS0401-0408)
- Bottom-up organization (low-level functions first)
- Naming: `lowercase_with_underscores`
- Export with: `declare -fx function_name` (if needed)
- One purpose per function
- Clear return values (0=success, non-zero=error)

### Recommended Utility Functions (BCS0703, BCS1211)
```bash
_msg()      # Core messaging function (where appropriate)
info()      # Info messages
warn()      # Warnings (>&2)
error()     # Errors (>&2)
die()       # Exit with error
vecho()     # Verbose output
debug()     # Debug messages
yn()        # Yes/no prompts
noarg()     # Argument validation
```

### main() Function (BCS0108, BCS0403)
- Required for scripts >200 lines
- All script logic inside main()
- Invoked as: `main "$@"`

## 7. Error Handling

### set -e Compliance (BCS0601)
- `set -euo pipefail` mandatory (lines 4-6)
- Exception: Dual-purpose scripts may conditionally set
- Check return values explicitly when needed: `command || { error 'Failed'; return 1; }`

### Error Output (BCS0702)
- Prefer the `error()` helper, which handles `>&2` redirection, colour, and exit-aware formatting.
- Raw `echo` to stderr: either `>&2 echo 'error'` or `echo 'error' >&2` is acceptable -- placement is a style preference, not a rule.

### Trap Usage (BCS0603, BCS0110)
- Use EXIT trap for cleanup
- Proper trap syntax: `trap cleanup EXIT`

### Exit Codes (BCS0602)

BCS defines 11 canonical exit codes. Use `die()` as the standard exit function and always include context.

| Code | Use Case |
|------|----------|
| 0 | Success |
| 1 | General error |
| 2 | Usage / argument error |
| 3 | File/directory not found |
| 5 | I/O error |
| 8 | Required argument missing |
| 13 | Permission denied |
| 18 | Missing dependency |
| 19 | Configuration error |
| 22 | Invalid argument |
| 24 | Timeout |

```bash
# correct -- include context
die 3 "Config not found ${config@Q}"
die 22 "Invalid option ${1@Q}"

# wrong -- no context
die 3 'File not found'
```

**Reserved:** 64-78 (sysexits), 126 (cannot execute), 127 (not found), 128+n (signals)

## 8. Code Style & Best Practices

### Formatting (BCS1201)
- Indentation: 2 spaces (never tabs)
- Line length: 100 characters (except URLs/paths)
- One command per line (except simple `&&` chains)

### Comments (BCS1202)
- Explain WHY, not WHAT
- Document non-obvious logic
- Comment complex regex patterns
- Explain security-critical sections

### Naming Conventions (BCS0203, BCS0402)
- Constants: `UPPER_CASE`
- Functions: `lowercase_with_underscores`
- Local variables: `lower_case`
- Private functions: `_leading_underscore`

## 9. Command-Line Arguments (BCS0800)

### Standard Parsing Pattern (BCS0801)
- `while (($#)); do case $1 in` pattern (NOT `while [[ $# -gt 0 ]]`)
- `noarg "$@"; shift` before capturing option values
- `--) shift; break` for end-of-options
- Short option bundling support via re-splitting: `-vqn` → `-v -q -n`
- Invalid option catch-all: `-*) die 22 "Invalid option ${1@Q}"`

### Version Output (BCS0802)
- Format: `printf '%s %s\n' "$SCRIPT_NAME" "$VERSION"` (no "version" or "vs" word)

### Argument Validation (BCS0803)
- Validate option arguments exist before `shift`
- Validate required positional arguments after parse loop
- Use `noarg()` helper: `(($# > 1)) || die 22 "Option ${1@Q} requires an argument"`

## 10. File Operations (BCS0900)

### Safe File Testing (BCS0901)
- Use `[[ ]]` not `[ ]` for file tests
- Include filenames in error messages: `die 3 "Not found ${file@Q}"`

### Wildcard Expansion (BCS0902)
- Always use explicit path prefix: `rm ./*` not `rm *`
- Loop with prefix: `for file in ./*.txt; do`

### Process Substitution (BCS0903)
- Use `< <(command)` with while loops to avoid subshell variable scope loss

## 11. Concurrency & Jobs (BCS1100)

If the script uses background jobs or parallel execution:

### Background Job Management (BCS1101)
- Track PIDs: `command & pid=$!`
- Store multiple PIDs in array: `pids+=($!)`
- Clean up in trap: kill tracked PIDs on EXIT

### Wait Patterns (BCS1103)
- Always capture wait exit codes: `wait $pid || errors+=1`
- Use `wait -n` (Bash 4.3+) for processing as completed

### Timeout Handling (BCS1104)
- Wrap network operations with `timeout`
- Handle timeout exit code 124 explicitly

## 12. Dual-Purpose Scripts (BCS0106, BCS0406)

For scripts that can be both executed and sourced:

```bash
# --- source fence ---
[[ ${BASH_SOURCE[0]} == "$0" ]] || {
  # Sourced mode - skip set -e; export functions
  declare -fx function_name
  return 0
}
# --- script mode - enable strict mode ---
set -euo pipefail
function_name "$@"
#fin
```

## 13. Testing

- Test file structure and organization
- Use of test helpers/assertions
- Coverage of critical functions
- ShellCheck in test pipeline
- Test isolation and cleanup

## 14. Performance Issues

### Subprocess Spawning
- Excessive command substitution `$()`
- Find operations in loops
- Repeated command execution (cache results)

### File I/O
- Multiple reads of same file
- Inefficient text processing
- Missing use of bash built-ins

### Bash Built-ins vs External Commands
- Prefer bash built-ins when available
- Consider loadable builtins for performance-critical paths
- Document why external commands are necessary

## 15. FHS Compliance & Installation

For installed scripts:
- Search paths: script dir → `/usr/local/share/` → `/usr/share/`
- Proper use of `PREFIX` variable
- Makefile security (no unsafe privilege escalation)
- Group/permission management (justify SGID)

## Output Format

For each issue found:

1. **Severity**: Critical/High/Medium/Low
2. **Location**: `file.sh:line_number`
3. **BCS Code**: Reference if applicable (e.g., BCS0601)
4. **Description**: Clear explanation of the issue
5. **Impact**: How this affects the script/system
6. **Recommendation**: Concrete fix with Bash 5.2+ syntax

## Executive Summary

Provide:
- **Overall Health Score**: X/10 with justification
- **Top Critical Issues**: (if any) Immediate attention required
- **Quick Wins**: (if any) Low-effort, high-impact improvements
- **Long-term Recommendations**: (if any) Architectural improvements
- **ShellCheck Results**: Summary of findings
- **BCS Compliance**: Overall compliance percentage (if applicable)

## Tool Integration

Run these tools automatically:

```bash
# ShellCheck (compulsory)
shellcheck -x script.sh

# BCS check (compulsory) -- use the bcscheck SKILL, not the binary.
# The LLM-backed binary is never run (denied in managed settings).

# Optional: Test suite
./tests/run-all-tests.sh
```

## Save Results

Save the complete audit report to:

```
./AUDIT-BASH.md
```

Include:
- Date and auditor information
- File statistics (total lines, functions, scripts)
- Complete findings organized by severity
- Tool output summaries
- Actionable recommendations with code examples
