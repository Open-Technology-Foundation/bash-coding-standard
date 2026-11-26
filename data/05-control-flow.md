<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Section 05: Control Flow

## BCS0500 Section Overview

Use `[[ ]]` for string and file tests, `(())` for arithmetic. Never use `[ ]`. This section covers conditionals, case statements, loops, arithmetic, and floating-point operations.

## BCS0501 Conditionals

**Tier:** core

```bash
# correct — [[ ]] for strings/files, (()) for arithmetic
[[ -f $file ]]
[[ $name == "$expected" ]]
((count > 5))

# correct — arithmetic truthiness
((count))                            # true if non-zero
((VERBOSE)) || return 0

# correct — pattern matching
[[ $file == *.txt ]]                 # glob
[[ $input =~ ^[0-9]+$ ]]             # regex

# correct — short-circuit
[[ -f $file ]] && source -- "$file"
command -v curl >/dev/null || die 18 'curl required'

# wrong
[ "$name" = "$expected" ]            # never use [ ]
[ "$count" -gt 5 ]                   # never use [ ]; arithmetic belongs in (())

# style preference — prefer ((count)); see BCS0505. Not errors under this rule.
((count > 0))                        # prefer ((count))
((VERBOSE == 1))                     # prefer ((VERBOSE))
```

This is the canonical code for a `[ ]` or `test` conditional on strings or numbers. When what is tested is a file (`-f`, `-d`, `-r`, `-s`, `-nt`, ...), cite BCS0901 instead, in either spelling. BCS0303 and BCS1205 show `[ ]` only as an anti-pattern and own no `[ ]` finding.

## BCS0502 Case Statements

**Tier:** recommended

Use `case` for multi-way branching on a single variable.

```bash
# correct — no quotes on case expression or literal patterns
case ${1:-} in
  start)          start_service ;;
  stop)           stop_service ;;
  help|-h|--help) show_help ;;
  *.txt|*.md)     process_text "$1" ;;
  -*)             die 22 "Invalid option ${1@Q}" ;;
  *)              die 2 "Unknown command ${1@Q}" ;;
esac

# wrong
case "${1:-}" in                     # unnecessary quotes on expression
  "start")                           # unnecessary quotes on pattern
```

Always include default case `*)`  to handle unexpected values. Align actions consistently for readability. Enable `extglob` for advanced patterns: `@(start|stop)`, `!(*.tmp)`, `+([0-9])`.

## BCS0503 Loops

**Tier:** core

```bash
# correct — for with arrays and globs
for file in "${files[@]}"; do
  process "$file"
done
for f in ./*.txt; do
  echo "$f"
done

# correct — while for argument parsing
while (($#)); do case $1 in
  -v|--verbose) VERBOSE=1 ;;
esac; shift; done

# correct — while for reading input
while IFS= read -r line; do
  process "$line"
done < "$input_file"

# correct — C-style loop
for ((i=0; i<10; i+=1)); do
  echo "$i"
done

# wrong
for f in $(ls *.txt); do             # never parse ls
while read line; do                  # IFS= read -r: -r keeps backslashes, IFS= keeps blanks
for f in *.log; do process "$f"; done   # without nullglob, processes the literal '*.log'

# style preference — not errors under this rule (increment policy: BCS0505)
for ((i=0; i<10; i++)); do           # prefer i+=1
while (($# > 0)); do                 # prefer (($#))
```

Read lines with `IFS= read -r`: without `-r` backslashes are mangled, without `IFS=` leading and trailing whitespace is stripped.

A loop over a glob must handle the no-match case: enable `nullglob` (or `failglob`) in the script's `shopt` line, or test the first match with `[[ -e $f ]]`; otherwise the unmatched pattern itself is processed as a filename.

Declare local variables before loops, not inside:

```bash
# correct
local -- file
for file in ./*.txt; do process "$file"; done

# wrong
for file in ./*.txt; do local -- file; done
```

Use `while ((1))` for infinite loops — it is pure arithmetic evaluation with no command lookup or dispatch, making it the fastest construct (~14% faster than `while :`, ~21% faster than `while true` at 1M iterations).

```bash
# correct — arithmetic evaluation, fastest
while ((1)); do
  process_item || break
done

# acceptable — special builtin, POSIX-compatible
while :; do
  process_item || break
done

# acceptable — regular builtin, widely used
while true; do
  process_item || break
done

# wrong — unquoted variable expansion as command (fragile, dangerous)
running=true
while $running; do
  running=false
done

# wrong — unnecessary string comparison on constants
while [[ 1 == 1 ]]; do
  break
done
```

The flag-variable pattern (`while $running`) executes the variable content as a command — if it contains anything other than `true` or `false`, arbitrary code runs. Use arithmetic flags instead:

```bash
# correct — arithmetic flag, safe
local -i running=1
while ((running)); do
  # ...
  running=0
done
```

Use `break N` for nested loops (`break 2` exits two enclosing levels).

See also: [While Loops Reference](../benchmarks/while-loops_reference.md) — full benchmark data and analysis of `while ((1))` vs `while :` vs `while true`.

## BCS0504 Process Substitution

**Tier:** core

Never pipe to while loops — pipes create subshells where variable modifications are lost. This is the canonical code for the pipe-to-while anti-pattern; BCS0903 covers process substitution in file-operation contexts.

```bash
# correct — process substitution preserves variables
declare -i count=0
while IFS= read -r line; do
  count+=1
done < <(grep -- '' "$file")

# correct — readarray for collecting lines
readarray -t lines < <(find . -name '*.txt')

# correct — null-delimited for special filenames
while IFS= read -r -d '' file; do
  process "$file"
done < <(find /data -type f -print0)

# wrong — subshell loses count
grep -- '' "$file" | while read -r line; do
  count+=1
done
# count is still 0 here!
```

This rule owns the **lost state**: a pipe into a loop whose body sets a
variable the caller needs. BCS0411 catalogues the four patterns for returning
data from a subshell and BCS0906 the `find`-specific pitfalls; both defer here,
so cite BCS0504 for the defect itself.

Use here-string `<<< "$var"` when input is already in a variable.

## BCS0505 Arithmetic Operations

**Tier:** style

Always declare integer variables with `declare -i` or `local -i` before arithmetic.

```bash
# correct
declare -i count=0
count+=1                             # increment

# correct — arithmetic conditional
((count > 10)) && warn 'High count' ||:  # no $ needed inside (()); ||: per BCS0606

# correct — assignment via arithmetic expansion never affects exit status
result=$((x + y))

# wrong — NEVER use any form of ++
((count++))
((++count))
count++
((count+=1))                         # use plain count+=1
```

Use `i+=1` for ALL increments. A bare `((count++))` with count=0 evaluates to 0, returns status 1, and kills a `set -e` script — BCS0606 (core) owns that correctness hazard. Integer division truncates: `((10 / 3))` equals 3.

## BCS0506 Floating-Point Operations

**Tier:** recommended

Bash only supports integer arithmetic. Use `bc -l` or `awk` for floating-point.

```bash
# correct
result=$(echo 'scale=2; 10 / 3' | bc -l)
result=$(awk -v a="$a" -v b="$b" 'BEGIN {printf "%.2f", a * b}')

# correct — float comparison: validate both operands, then let awk's exit status answer
[[ $a =~ ^-?[0-9]+([.][0-9]+)?$ && $b =~ ^-?[0-9]+([.][0-9]+)?$ ]] || die 22 'Not a decimal number'
if awk -v a="$a" -v b="$b" 'BEGIN { exit !(a > b) }'; then
  echo 'a is greater'
fi

# wrong — bc evaluates its input as code, and (( )) evaluates bc's output again: a crafted
# value runs commands; a malformed one makes bc print nothing, which (( )) reads as false
if (($(echo "$a > $b" | bc -l))); then echo 'a is greater'; fi

# wrong
[[ "$a" > "$b" ]]                    # string comparison, not numeric
```

## BCS0507 Regex Captures with BASH_REMATCH

**Tier:** recommended

Extract substrings with the `[[ $s =~ re ]]` operator and the `BASH_REMATCH` array instead of shelling out to `grep`/`sed` for simple parsing.

```bash
# correct — capture groups land in BASH_REMATCH; [0] is the whole match
declare -- date='2026-05-29'
if [[ $date =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})$ ]]; then
  declare -- year=${BASH_REMATCH[1]} month=${BASH_REMATCH[2]} day=${BASH_REMATCH[3]}
fi

# correct — copy captures out immediately; the next match overwrites BASH_REMATCH
declare -- ver=''
[[ $line =~ v([0-9]+\.[0-9]+) ]] && ver=${BASH_REMATCH[1]}

# wrong — quoting the pattern forces a literal match (no regex, no captures)
[[ $date =~ "^([0-9]{4})" ]]          # matches literal text; BASH_REMATCH empty

# wrong — external tool for a job the shell does in-process
year=$(echo "$date" | grep -oE '^[0-9]{4}')
month=$(echo "$date" | cut -d- -f2)              # ${date:5:2} does it
day=$(printf '%s' "$date" | sed -n 's/.*-//p')   # ${date##*-} does it
```

This rule owns **parsing a shell variable with an external tool** where
`[[ =~ ]]` and `BASH_REMATCH`, or a parameter expansion, would do it in
process: `grep -oE`, `cut -d`, `sed -n 's/../\1/p'`, `awk '{print $2}'`.
BCS1205 states the same preference for builtins generally and defers here: cite
BCS0507 for a parse, not both.

Keep the regex unquoted — quoting any part forces a literal match (cite BCS0303, which owns that finding). For complex patterns, assign to a variable and reference it unquoted: `[[ $s =~ $re ]]`. `BASH_REMATCH` is global and is overwritten by every successful `[[ =~ ]]`, so copy out captures before the next match. Character classes such as `[[:alpha:]]` are locale-sensitive.
