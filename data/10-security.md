<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Section 10: Security

## BCS1000 Section Overview

Seven essential security areas: SUID/SGID prohibition, PATH security, IFS safety, eval avoidance, input sanitization, temporary file handling, and environment scrubbing before exec. These prevent privilege escalation, command injection, and path traversal attacks.

## BCS1001 SUID/SGID Prohibition

**Tier:** core

Never use SUID or SGID bits on Bash scripts. No exceptions.

```bash
# wrong — catastrophically dangerous
chmod u+s script.sh

# correct — use sudo instead
sudo /usr/local/bin/myscript.sh
# or configure /etc/sudoers.d/myapp for specific commands
```

For elevated privileges, use sudo, capabilities (`setcap`), compiled wrappers, PolicyKit, or systemd services.

## BCS1002 PATH Security

**Tier:** core

**Scope.** A script that runs any external command must set PATH itself, at script start (after `set` and `shopt`, before the first external command), so that an inherited PATH cannot substitute a trojan for `grep` or `rm`. A script that uses only builtins has nothing to protect and needs no PATH line: a missing PATH is a finding only when an external command is run. The rest of this rule governs what the value may contain.

**Placement: before the script metadata block.** The usual first external command in a BCS script is the one that populates the metadata -- `SCRIPT_PATH=$(realpath -- "$0")` and the `SCRIPT_DIR`/`SCRIPT_NAME` derived from it. PATH must therefore be set *above* the metadata declarations, not after them; a PATH line that follows `SCRIPT_PATH` has already let one external command run under the caller's PATH, which is the whole defect. The order is: `set` -> `shopt` -> `PATH` -> metadata.

**Sourced libraries are exempt.** A library does not set PATH: it runs inside a caller's process and assigning PATH there would silently replace the caller's, which is both surprising and a defect of its own. A missing PATH line in a file meant to be sourced is therefore not a finding, even where the library runs external commands. The obligation belongs to the executable that sources it, which must harden PATH before the `source`. A library that sets PATH anyway *is* a finding under this rule.

Secure PATH at script start to prevent command hijacking.

```bash
# correct — non-privileged interactive/user tooling only
declare -rx PATH=~/.local/bin:/usr/local/bin:/usr/bin:/bin

# correct — for production/security-critical scripts
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

# correct — PATH is set before the metadata that shells out to realpath
set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/bin:/usr/bin:/bin
#shellcheck disable=SC2155  # accepted: declare masks realpath's exit status (BCS0103)
declare -r SCRIPT_PATH=$(realpath -- "$0")

# not a finding — only builtins and keywords run (read, printf, [[ ]]; a
# redirection is not a command), so there is nothing for PATH to protect
set -euo pipefail
shopt -s inherit_errexit
declare -i count=0
declare -- line
while IFS= read -r line; do
  if [[ -n $line ]]; then
    count+=1
  fi
done < /etc/hosts
printf '%d non-blank lines\n' "$count"

# wrong — external commands run with whatever PATH the environment supplied
set -euo pipefail
shopt -s inherit_errexit
grep -c '^' /etc/hosts               # no PATH line above: whichever grep the caller chose

# wrong — PATH set, but one external command already ran under the caller's
declare -r SCRIPT_PATH=$(realpath -- "$0")
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

# wrong — includes dangerous elements
PATH=.:$PATH                         # current directory
PATH="/tmp:$PATH"                    # world-writable directory
```

Set PATH above the metadata block, and never in a sourced library. Never include `.`, empty elements (`::`, leading/trailing `:`), or `/tmp` in PATH. User-writable directories such as `~/.local/bin` are permitted only in non-privileged user tooling; production, security-critical, or privilege-elevated (sudo/SUID-adjacent) scripts must use the system-directories-only form. Place PATH setting early, before any commands that depend on it.

## BCS1003 IFS Safety

**Tier:** recommended

Never trust inherited IFS values.

```bash
# correct — one-line IFS for single command
IFS=',' read -ra fields <<< "$csv_data"

# correct — subshell isolation (results must be used inside the subshell)
( IFS=','; read -ra fields <<< "$data"; printf '%s\n' "${fields[@]}" )

# correct — local scoping in functions
parse_csv() {
  local -- IFS=','
  read -ra fields <<< "$1"
}

# correct — null-delimited input
while IFS= read -r -d '' file; do
  process "$file"
done < <(find . -print0)

# wrong — modifying global IFS without restore
IFS=','
```

## BCS1004 Eval Avoidance

**Tier:** core

Never use `eval` with untrusted input. Almost every use case has a safer alternative. When `eval` cannot be avoided, the comment above it must say why, and its operand must be validated against a strict pattern first; an unexplained or unvalidated `eval` is a violation even on data believed to be trusted.

```bash
# correct — arrays for dynamic commands (search_dir is realpath output, BCS1005)
local -a cmd=(find "$search_dir" -name "$pattern")
"${cmd[@]}"

# correct — indirect expansion (var_name validated as below)
echo "${!var_name}"

# correct — printf -v for dynamic assignment (var_name validated as below)
printf -v "$var_name" '%s' "$value"

# correct — associative arrays for dynamic data
declare -A data
data["$key"]="$value"

# correct — case for dispatch
case $action in
  start) start_fn ;;
  stop)  stop_fn ;;
esac

# wrong
eval "echo \$$var_name"
eval "$var_name='$value'"
eval "${action}_function"
```

**A variable name is code.** The alternatives above are not eval-free when the name comes from outside the script. `${!name}`, `printf -v "$name"`, `local -n ref=$name` and `unset "$name"` all accept an array subscript inside the name, and Bash evaluates that subscript as arithmetic: a name of `a[$(cmd)]` runs `cmd`. A name from outside the script (the command line, which includes the parameters of `main "$@"`; the environment; a file; another program) must match `^[a-zA-Z_][a-zA-Z0-9_]*$` before it reaches any of them; check it once, where it enters. A literal needs no check, and neither does a helper's parameter when every caller passes a name the script wrote. The keys of an associative array are data, not names, so `data["$key"]` is safe with any key.

```bash
# correct — validate a name from outside the script before indirection
[[ $var_name =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || die 22 "Invalid variable name ${var_name@Q}"
printf -v "$var_name" '%s' "$value"

# wrong — main's parameters are the command line: a name of 'x[$(cmd)]' runs cmd
main() { printf -v "$1" '%s' "$value"; echo "${!2}"; }

# not a finding — a literal the script itself wrote
local -n result_ref=RESULT

# not a finding — a helper whose every caller passes a name the script wrote
read_into() { local -n out=$1; IFS= read -r out; }
read_into ANSWER
```

## BCS1005 Input Sanitization

**Tier:** core

Validate and sanitize all user input. Use whitelist over blacklist. Guard any pathname operand that originates from variables or user input against option injection through a leading `-`: with `--` where the program supports it (`rm -- "$f"`, `cp -- "$src" "$dst"`), otherwise with an operand that cannot begin with `-` (below).

**Integers from outside.** Bash evaluates as arithmetic whatever reaches `declare -i`, `local -i`, an integer variable's assignment, `(( ))`, `$(( ))` or an array index, and an array subscript inside the value runs as a command: `n='a[$(cmd)]'; local -i x=$n` runs `cmd`. A value from outside the script (the command line, which includes the parameters of `main "$@"`; the environment; a config file; another program) must match an integer pattern (`^[0-9]+$`, or `^-?[0-9]+$` where negatives are allowed) before it gets there; check it once, where it enters. A value the script computed itself, a literal, `$#`, `$?` and `$!` need no check, and neither does a helper's parameter when every caller passes such a value.

**Another program's output: the form decides, not the command's name.** Output that is a bare number whatever the data holds is a value the script computed and needs no check: `wc -l < "$f"` and `wc -c < "$f"` (the file on a redirection), `stat -c %s -- "$f"` (a format with no `%n`), `grep -c -- "$pat" "$f"` (one file), `date +%s`, `id -u`, `nproc`. Output that can carry outside text is outside: `wc -l -- "$f"` and `du -- "$f"` print the file name after the number, `stat -c '%s %n'` and `grep -c` over several files print names, and `cut`, `awk`, `sed`, `jq`, `head` and `curl` relay whatever the data holds. A file named `+BASH_VERSINFO[$(cmd)]` turns `n=$(wc -l -- "$f")` into a command when `n` is an integer.

**Option injection: guard every pathname operand that begins with an expansion.** An operand such as `"$f"`, `"$dir"/x`, `"${files[@]}"` or `"$(cmd)"/x` can begin with `-`, and the program then reads it as an option: a file named `-o/etc/cron.d/job` turns `sort "$f"` into a write, so "read-only" is no defence. How it is guarded depends on the program:

- **A program that supports `--`** accepts it as the end of its options and reads every later word as an operand. The GNU coreutils (`rm`, `cp`, `mv`, `cat`, `head`, `tail`, `sort`, `wc`, `stat`, `du`, `chmod`, `ln`, `mkdir`, `ls`, `realpath`, `basename`, `dirname` ...), `diff`, `grep`, `sed`, `awk`, `shellcheck` and the Bash builtins `cd` and `source` all do. For these `--` is the guard, owed even when the variable holds an absolute path. Place it before the first operand, which is not always the pathname: `grep -- "$pattern" "$file"`, `chmod -- 644 "$f"`, `awk -- 'prog' "$f"`.
- **A program that does not support `--`** needs an operand that cannot begin with `-`: an absolute path (`realpath` output) or `./` before a relative one, added only when the path is relative, because `./` turns `/etc` into `.//etc`, which is relative: `[[ $f == /* ]] || f=./$f`.

**`--` is only for programs that support it.** Elsewhere it guards nothing, or becomes data: `find` reads a word that begins with `-` as the start of its expression even after `--`, so `find -- "$dir" -type f` with `dir=-delete` deletes everything under the current directory (GNU findutils); `awk` after its program text opens `--` as a file; `echo -- x` prints `-- x`. For such a program an operand that can begin with `-` is a finding whether or not `--` stands before it. Where support is in doubt, read the program's manual or probe it: `prog -- -x` must take `-x` as an operand. A `--` given to a program that does not support it is itself a finding, even before an operand that is already safe: `find` never takes `--` (`find -- "$abs"` protects nothing and tells the reader it does), and for `awk` after its program or for `echo` it becomes data.

No guard is owed, and its absence is never a finding, when the operand begins with literal text (`./"$f"`, `/etc/"$name"`: it cannot start with a dash), when the variable is an option's argument (`sort -o "$out"`, `grep -f "$patterns"`), for a redirection (`< "$file"`), inside `[[ ]]`, or for a command that takes no pathname (`echo`, `printf`, `tr`).

```bash
# correct — validate integer before any arithmetic context sees it
[[ $input =~ ^-?[0-9]+$ ]] || die 22 "Invalid integer: ${input@Q}"
local -i count=$input

# wrong — the environment value goes straight to an integer declaration
declare -i RETRIES=${RETRIES:-3}

# wrong — main's parameters are the command line (main "$@")
main() { local -i retries=${2:-3}; }

# not a finding — the script's own values
local -i total=$((count * 2)) nargs=$#

# not a finding — a helper whose every caller passes the script's own value
cleanup() { local -i exitcode=${1:-$?}; trap - EXIT; exit "$exitcode"; }
trap 'cleanup $?' EXIT

# not a finding — output that is a bare number whatever the file holds
local -i lines size
lines=$(wc -l < "$file") || die 1 "Cannot read ${file@Q}"
size=$(stat -c %s -- "$file") || die 1 "Cannot stat ${file@Q}"

# wrong — wc prints the file name after the count: a file named
# '+BASH_VERSINFO[$(cmd)]' runs cmd in the integer assignment
local -i count
count=$(wc -l -- "$file")

# wrong — cut relays whatever the config line holds
local -i port
port=$(cut -d= -f2 <<< "$config_line")

# correct — validate path within allowed directory
# allowed_dir must be canonical (realpath output) with no trailing slash
real_path=$(realpath -e -- "$path")
[[ $real_path == "$allowed_dir"/* || $real_path == "$allowed_dir" ]] || die 13 'Path traversal blocked'

# correct — sanitize a bare filename: no separator, no traversal, not hidden
# (an allowed-character class alone admits '..' and '.hidden')
[[ $name =~ ^[a-zA-Z0-9_][a-zA-Z0-9._-]*$ ]] || die 22 "Invalid filename ${name@Q}"

# correct — -- before pathname operands, for programs that support it
rm -- "$user_file"
cp -- "$source" "$dest"

# correct — read-only commands and builtins owe it too
sort -- "$file" | head -n 5
grep -c -- 'pattern' "$file"
source -- "$lib_path"
cd -- "$target_dir"

# wrong — a file named '-o/etc/cron.d/job' makes sort write; '-r' makes head fail
sort "$file"
head -n 5 "$file"
cat "$dir"/"$name"

# wrong — rm supports --, so it is owed even before realpath output
target=$(realpath -e -- "$input") || die 3 "Not found ${input@Q}"
rm "$target"

# correct — no guard owed: literal-leading operand, option-argument, redirection
cat ./"$name"
wc -l /var/log/"$SCRIPT_NAME".log
sort -o "$output" -- "$input"
content=$(< "$file")

# wrong — awk supports -- only before its program text; after it, awk opens -- as a file
awk '{print $1}' -- "$file"

# wrong — dir comes straight from the command line, and find takes no --: it
# reads a dash-leading starting point as its expression even after --, so
# dir='-delete' deletes everything under the current directory
dir=$1
find -- "$dir" -type f

# correct — give find a starting point that cannot begin with a dash
[[ $dir == /* ]] || dir=./$dir
find "$dir" -type f

# correct — realpath output is absolute, so it cannot begin with a dash
dir=$(realpath -e -- "$input") || die 3 "Directory not found ${input@Q}"
find "$dir" -maxdepth 1 -type f

# correct — a helper whose every caller passes realpath output needs no guard of its own
scan() {
  local -- dir=$1
  find "$dir" -maxdepth 1 -type f
}
dir=$(realpath -e -- "$input") || die 3 "Directory not found ${input@Q}"
scan "$dir"

# wrong — -- before find's starting point, even a safe one: find takes no --
find -- "$dir" -maxdepth 1 -type f
```

`realpath -e` requires the path to exist; for an output path that does not exist yet, `realpath -m` resolves it without that requirement. Ranges such as `a-z` follow the locale's collation, so under `en_US.UTF-8` they also admit accented letters such as `é`. The patterns here stay safe that way (a letter is never a separator, a quote or a leading dash); where only ASCII may pass, test under `LC_ALL=C`.

Validate early, fail securely with clear errors, run with minimum necessary permissions.

## BCS1006 Temporary File Handling

**Tier:** core

Always use `mktemp`. Never hardcode temp file paths.

This rule owns how a temporary name is made: a hardcoded or predictable path is cited here. The cleanup trap belongs to BCS0110 -- a temporary resource with no cleanup trap, or a trap installed after `mktemp`, is cited as BCS0110, not as this rule. The examples below show the trap only because a correct example must obey BCS0110.

```bash
# correct — temp file: trap first (BCS0110), guarded while the name is still empty
declare -- temp_file=''
trap '[[ -z $temp_file ]] || rm -f -- "$temp_file"' EXIT
temp_file=$(mktemp) || die 1 'Failed to create temp file'

# correct — temp dir (alternative; a second EXIT trap would overwrite the first)
declare -- temp_dir=''
trap '[[ -z $temp_dir ]] || rm -rf -- "$temp_dir"' EXIT
temp_dir=$(mktemp -d) || die 1 'Failed to create temp dir'

# correct — both resources: single cleanup function, one EXIT trap, set before either mktemp
cleanup() {
  [[ -z $temp_file ]] || rm -f -- "$temp_file"
  [[ -z $temp_dir ]] || rm -rf -- "$temp_dir"
}
trap cleanup EXIT

# correct — custom template; --tmpdir honours $TMPDIR (default /tmp)
temp_file=$(mktemp --tmpdir -- "$SCRIPT_NAME".XXXXXX) || die 1 'Failed to create temp file'

# wrong
echo data > /tmp/myapp_temp.txt      # predictable path
echo data > "/tmp/app_$$"            # PID-based (predictable)
```

Default `mktemp` permissions are secure (0600 files, 0700 directories). Multiple trap statements for the same signal overwrite each other — use a single cleanup function.

## BCS1007 Environment Scrubbing Before exec

**Tier:** recommended

Scripts that hand control to another program in a **privileged or delegating context** must sanitise the inherited environment before `exec`. Inherited variables like `LD_PRELOAD`, `LD_LIBRARY_PATH`, or `PYTHONPATH` can silently hijack the child process.

**Privileged or delegating contexts include:**

- Scripts invoked via `sudo` that then `exec` a helper
- `su`-style or wrapper scripts that elevate privilege
- PAM or systemd service scripts that `exec` user-supplied commands
- SSH `ForceCommand` wrappers and other shell-dispatch gatekeepers
- Scripts that `exec` an interpreter (python, perl, ruby, node) against a fixed script path

Scripts that merely run a pipeline of well-known commands (`grep`, `awk`, `curl`) in their own unprivileged context do not need this scrubbing.

**Minimum unset list** (loaders, interpreter search paths, shell startup files):

```bash
# correct — explicit scrubbing before exec in a privileged wrapper
unset LD_PRELOAD LD_LIBRARY_PATH LD_AUDIT \
      PYTHONPATH PERL5LIB RUBYLIB NODE_PATH \
      BASH_ENV ENV
export -n SHELLOPTS BASHOPTS         # readonly: cannot be unset, so stop exporting them
exec /usr/libexec/myapp/helper "$@"
```

`SHELLOPTS` and `BASHOPTS` are readonly; `unset` of either fails, which under `set -e` ends the script before the `exec`. `export -n` keeps them out of the child's environment. A denylist is a minimum, never a complete scrub: it misses exported Bash functions (`BASH_FUNC_name%%`) and loader variables added after it was written. Prefer `env -i` where the helper allows it.

**Stronger -- `env -i` for a fully-reset environment** (PATH must be set explicitly):

```bash
# correct — full environment reset
exec env -i \
  HOME="$HOME" \
  PATH=/usr/local/bin:/usr/bin:/bin \
  /usr/libexec/myapp/helper "$@"
```

**Anti-patterns:**

```bash
# wrong — sudoed wrapper exec's helper without scrubbing LD_PRELOAD
#!/usr/bin/bash
# invoked via: sudo /usr/local/bin/deploy-wrapper
set -euo pipefail
exec /usr/local/libexec/deploy "$@"      # LD_PRELOAD would hijack deploy

# wrong — partial scrub missing the -AUDIT variant
unset LD_PRELOAD LD_LIBRARY_PATH
exec /usr/libexec/helper "$@"            # LD_AUDIT still inherited
```

LLM-based checkers should flag `exec /path/to/binary "$@"` (or comparable direct-exec patterns) when the script shows markers of a privileged/delegating context -- a top-of-file comment documenting sudo/systemd/PAM invocation, a `ForceCommand` hint, or an explicit privilege handoff -- and no preceding `unset` of the minimum list. Benign scripts without such markers should NOT be flagged.

Cross-references: BCS1001 (SUID prohibition on bash itself), BCS1002 (PATH hardening).
