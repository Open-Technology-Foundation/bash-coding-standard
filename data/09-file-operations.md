<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Section 09: File Operations

## BCS0900 Section Overview

Safe file testing, wildcard expansion, process substitution, here documents, and input redirection patterns to prevent common shell scripting pitfalls.

## BCS0901 Safe File Testing

**Tier:** core

Use `[[ ]]` for all file tests. Always include filenames in error messages for debugging.

```bash
# correct
[[ -f $file ]] || die 3 "Not found ${file@Q}"
[[ -f $file && -r $file ]] || die 5 "Cannot read ${file@Q}"
[[ -d $dir ]] || mkdir -p -- "$dir" || die 1 "Cannot create ${dir@Q}"
[[ -s $logfile ]] || warn 'Log file is empty'
[[ $source -nt $destination ]] && cp -- "$source" "$destination" ||:

# wrong
[ -f "$file" ]                       # old test syntax
test -r "$file"                      # same defect, spelled with the test builtin
```

This rule owns every file test not written with `[[ ]]` — `[ -f "$file" ]` and `test -f "$file"` alike. Cite BCS0901 for them, not BCS0501, which owns `[ ]` and `test` on strings and numbers.

## BCS0902 Wildcard Expansion

**Tier:** core

Always use explicit path prefix to prevent filenames starting with `-` from being interpreted as flags.

```bash
# correct
rm -v ./*
for file in ./*.txt; do
  process "$file"
done

# wrong — dangerous
rm -v *                              # file named -rf would be catastrophic
for file in *.txt; do                # less safe
```

## BCS0903 Process Substitution in File Operations

**Tier:** core

Use process substitution (`<(command)`, `>(command)`) for file-operation idioms that would otherwise need temp files or lossy pipes: feeding while loops with `< <(command)`, populating arrays with `readarray`, comparing outputs with `diff <(...) <(...)`, parallel output with `tee >(...)`, and null-delimited filename handling. See BCS0504 for the pipe-to-while prohibition — cite BCS0504, not this rule, for `command | while read` violations. An unchecked failure inside `<( )` where the result is compared or captured is owned by BCS0604 -- cite BCS0604, not this rule; a loop fed by `< <(cmd)` is not a finding under either.

```bash
# correct — variables preserved in current shell
declare -i count=0
while IFS= read -r line; do
  count+=1
done < <(grep -- 'pattern' "$file")

# correct — populate arrays
readarray -t lines < <(find . -name '*.txt')

# correct — compare outputs without temp files; capture first, because diff cannot
# see a failure inside <( ): an unreadable file would compare as empty (BCS0604)
sorted1=$(sort -- "$file1") || die 1 "Cannot sort ${file1@Q}"
sorted2=$(sort -- "$file2") || die 1 "Cannot sort ${file2@Q}"
diff -- <(printf '%s\n' "$sorted1") <(printf '%s\n' "$sorted2")

# correct — null-delimited for special filenames
while IFS= read -r -d '' file; do
  process "$file"
done < <(find /data -type f -print0)

# correct — tee for parallel output
tee >(grep ERROR > errors.txt) >(grep WARN > warnings.txt) < logfile

# wrong — pipe loses variables (cite BCS0504)
command | while read -r line; do count+=1; done
```

## BCS0904 Here Documents

**Tier:** recommended

Quote the here-document delimiter (`<<'NOTES'`) whenever the body must be literal; leave it unquoted only when expansion is intended. An unquoted delimiter over a body containing literal `$` or `` ` `` characters is a violation.

Delimiter quoting semantics are owned by BCS0304 (the canonical code for delimiter-quoting findings, including descriptive delimiter names and `<<-`); this rule covers heredocs in file-operation contexts.

```bash
# correct — no expansion (quoted delimiter)
cat <<'NOTES'
Variables like $HOME are not expanded.
NOTES

# correct — with expansion (unquoted delimiter)
cat <<GREETING
Hello $USER, home is $HOME
GREETING

# wrong — body needs literal $HOME but delimiter is unquoted, so it expands
cat <<MSG
Set your home directory with: export HOME=$HOME
MSG
```

## BCS0905 Input Redirection

**Tier:** style

Use `$(< file)` instead of `$(cat file)` — 107x faster (zero process fork).

```bash
# correct
content=$(< "$file")
grep pattern < "$file"

# wrong — unnecessary cat
content=$(cat -- "$file")
cat -- "$file" | grep pattern
```

Use `cat` only when concatenating multiple files or using cat-specific options (`-n`, `-A`, `-b`).

## BCS0906 find Subshell Pitfalls

**Tier:** recommended

Piping `find` into a loop (`find ... | while read`) creates a subshell -- any variable set in the loop body is invisible to the parent. That lost-state defect is owned at core severity by BCS0504/BCS0903 -- cite those codes for it. This rule covers the find-specific pitfalls and performance guidance: use process substitution when state must escape the loop; use `-exec ... +` or built-in actions when no state is needed.

**Stateful iteration -- process substitution + null-delimited input:**

```bash
# correct — state persists; filenames with spaces/newlines handled safely
declare -i count=0
declare -a paths=()
while IFS= read -r -d '' f; do
  count+=1
  paths+=("$f")
done < <(find . -type f -print0)
info "Found $count files"
```

**Stateless batching -- `-exec ... +`** (one fork for N matches):

```bash
# correct — batches arguments; efficient
find . -name '*.log' -exec gzip {} +
find /tmp -type f -mtime +7 -exec rm -- {} +
```

**Stateless built-in actions** (preferred over `-exec` when available):

```bash
find . -name '*.tmp' -delete
find . -type d -empty -delete
```

**Anti-patterns:**

```bash
# wrong — subshell loses count (core violation: cite BCS0504/BCS0903)
declare -i count=0
find . -name '*.log' | while read -r f; do
  count+=1
done
echo "$count"                            # always 0

# wrong — filenames with spaces/newlines break plain read
find . -type f | while read f; do        # should be -print0 + read -r -d ''
  process "$f"
done

# wrong — -exec ... \; forks once per match (slow, cannot aggregate)
find . -name '*.log' -exec gzip {} \;    # use + instead of \; when possible
```

Always pair `find -print0` with `read -r -d ''` so filenames containing spaces, tabs, or newlines are handled correctly.

Cross-references: BCS0411 (subshell return patterns), BCS0504 (process substitution in while loops), BCS0903 (process substitution generally).
