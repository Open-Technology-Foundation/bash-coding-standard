<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Section 03: Strings & Quoting

## BCS0300 Section Overview

Single quotes signal "literal text"; double quotes signal "shell processing needed." This semantic distinction clarifies intent for both developers and AI assistants.

## BCS0301 Quoting Fundamentals

**Tier:** style

Use single quotes for static strings. Use double quotes only when variable expansion is needed.

```bash
# correct
info 'Checking prerequisites...'
info "Processing $count files"
die 1 "Unknown option ${1@Q}"
EMAIL='user@domain.com'
VAR=''

# wrong — double quotes for static string
info "Checking prerequisites..."
EMAIL="user@domain.com"
VAR=""
```

One-word alphanumeric literals (`a-zA-Z0-9_-./`) may be unquoted: `STATUS=success`, `[[ $level == INFO ]]`. When in doubt, quote everything.

Quote variable portions separately from literal path components: write `"$PREFIX"/bin`. The combined form `"$PREFIX/bin"` is compliant and MUST NOT be flagged.

```bash
# preferred — clear boundaries
"$PREFIX"/bin
"$SCRIPT_DIR"/data/"$filename"

# compliant — do not flag
"$PREFIX/bin"
"$SCRIPT_DIR/data/$filename"
```

## BCS0302 Command Substitution

**Tier:** core

Write command substitution as `$(...)`, never with backticks. Use double quotes when strings include command substitution.

```bash
# correct
echo "Current time: $(printf '%(%T)T')"
result=$(git describe --tags)        # simple assignment, quotes optional
VERSION="$(git describe)".beta       # quotes optional in assignments, even with concatenation
echo "$result"                       # always quote when using

# correct — $(...) nests without escaping
owner=$(stat -c %U -- "$(realpath -- "$file")")

# wrong
echo Time: $(date)                   # unquoted substitution word-splits and globs
echo $result                         # unquoted use of substitution result

# wrong — backticks
now=`date +%s`
owner=`stat -c %U -- "\`realpath -- "$file"\`"`   # nesting needs escaped backticks
```

**Backticks are forbidden.** The backtick form is legacy syntax: it cannot nest without backslash-escaping the inner backticks, it treats backslashes differently from `$(...)`, and it is easily misread as a single quote. Every backtick command substitution is a finding under this rule, quoted or not. A `#shellcheck disable=SC2006` directive does not excuse it; only `#bcscheck disable=BCS0302` does. A literal backtick that is not a command substitution -- inside single quotes, a quoted heredoc, or a comment -- is not a finding.

This rule owns backtick substitution, and unquoted use of command substitutions and their results, at core severity. BCS0307 lists the unquoted pattern only as a catch-all summary and does not own the finding; BCS1205 (builtins over external commands) does not own backticks.

## BCS0303 Quoting in Conditionals

**Tier:** core

Inside `[[ ]]`, **no word splitting or pathname expansion occurs** — variables are safe unquoted in any position. Quoting only matters for the right-hand side of `==`/`!=` (where it controls pattern vs literal matching) and `=~` (where it disables regex).

```bash
# correct — all unquoted forms are safe inside [[ ]]
[[ -f $file ]]
[[ -d $dir && -r $dir ]]
[[ $name == "$expected" ]]           # quoted RHS: literal comparison
[[ $mode == production ]]            # static value, quotes optional

# correct — glob matching (right side unquoted)
[[ $filename == *.txt ]]

# correct — regex (right side unquoted)
[[ $email =~ ^[a-z]+@[a-z]+$ ]]

# wrong
[ -f $file ]                         # **never** use [ ]; it requires quoting (cite BCS0901: a file test)
[[ $input =~ "$pattern" ]]           # quoted regex disables matching
```

This rule owns the quoted-regex finding: a quoted right-hand side of `=~` is a quoting defect, cited as BCS0303. BCS0507 repeats the advice while describing `BASH_REMATCH` extraction and does not own the finding.

## BCS0304 Here Documents

**Tier:** recommended

Use quoted delimiter `<<'EOF'` for literal content. Use unquoted delimiter `<<EOF` for variable expansion. The delimiter should name the content (`VARS`, `SQL`, `USAGE`), not be a generic `EOF`/`EOT`.

This is the canonical code for here-document delimiter-quoting findings; BCS0904 covers heredocs in file-operation contexts and defers delimiter semantics here.

```bash
# correct — no expansion needed
cat <<'VARS'
Variables like $HOME are literal text.
VARS

# correct — expansion needed
cat <<GREETING
Hello $USER, your home is $HOME
GREETING

# correct — indented (strips leading tabs, not spaces; the one place BCS1201 allows tabs)
if true; then
	cat <<-CONTENT
	indented content
	CONTENT
fi
```

Quote the delimiter for JSON, SQL, or any content where `$`, backticks, or backslashes must remain literal — the criterion is intended expansion, not mere presence of `$`.

## BCS0305 Printf Patterns

**Tier:** recommended

Use single quotes for format strings, double quotes for variable arguments.

```bash
# correct
printf '%s: %d files\n' "$name" "$count"
printf 'Line1\nLine2\n'

# wrong
echo -e "Line1\nLine2"              # inconsistent escape handling
```

Use `$'...'` syntax as an alternative for escape sequences: `echo $'Line1\nLine2'`.

### Exception: per-iteration constant prefix in reused format strings

`printf` reuses the format string once per cycle of consumed conversion specs. When a *constant* prefix (e.g. the script name) is meant to appear on every emitted line, it must be embedded in the format string — moving it to a `%s` positional argument breaks the iteration because the prefix would consume one slot per cycle, misaligning subsequent arguments.

```bash
# correct — $SCRIPT_NAME is a per-line constant; it MUST live in the format
die() {
  (($# < 2)) || >&2 printf "$SCRIPT_NAME: ✗ %s\n" "${@:2}"
  exit "${1:-0}"
}

# wrong — naive "fix" that breaks multi-arg output
die() {
  (($# < 2)) || >&2 printf '%s: ✗ %s\n' "$SCRIPT_NAME" "${@:2}"
  exit "${1:-0}"
}
# With ${@:2} = (msg1 msg2):
#   first cycle:  "$SCRIPT_NAME: ✗ msg1"
#   second cycle: "msg2: ✗ "          ← prefix lost, args shift
```

Do **not** flag `"$VAR: ... %s ..."` formats when:

1. The format is consumed multiple times (more positional args than `%`-specs in one cycle), AND
2. The embedded variable is a per-line constant the caller expects on every line.

This pattern is canonical for `die()`, `warn()`, `info()`, and similar diagnostic helpers across BCS-compliant scripts.

## BCS0306 Parameter Quoting with @Q

**Tier:** recommended

Use `${parameter@Q}` to safely display user input in error messages.

```bash
# correct
die 22 "Invalid option ${1@Q}"
error "File not found ${file@Q}"
info "[DRY-RUN] Would execute ${cmd@Q}"

# wrong — no safe quoting for display
die 22 "Invalid option $1"          # special chars break output
die 2 "Invalid argument '$1'"       # special chars break output
```

Never use `@Q` for normal variable expansion or comparisons.

## BCS0307 Anti-Patterns

**Tier:** recommended

Catch-all summary of quoting anti-patterns. Where an example below duplicates a more specific rule, report the violation under the owning code, not BCS0307.

```bash
# wrong — double quotes for static strings (owned by BCS0301)
info "Starting backup..."           # use single quotes
echo "${HOME}/bin"                  # unnecessary braces (owned by BCS0207)

# wrong — unquoted expansions (core: BCS0302 scalars, BCS0206 arrays)
echo $result
rm $temp_file
for item in ${items[@]}

# correct
info 'Starting backup...'
echo "$HOME"/bin
echo "$result"
rm -- "$temp_file"
for item in "${items[@]}"
```

The unquoted-expansion anti-patterns above (`rm $temp_file`, `for item in ${items[@]}`, `echo $result`) are genuine correctness bugs enforced at **core** severity under BCS0206 (array expansions) and BCS0302 (scalar and command-substitution results) — the [ERROR] belongs to those codes. BCS0307 itself remains a recommended-tier catch-all list and emits findings only for patterns with no more specific home.

Use braces only when required: `${var:-default}`, `${file##*/}`, `${array[@]}`, `${var1}${var2}`.
