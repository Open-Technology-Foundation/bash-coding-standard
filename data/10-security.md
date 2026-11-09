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
# correct — arrays for dynamic commands
local -a cmd=(find -- "$path" -name "$pattern")
"${cmd[@]}"

# correct — indirect expansion
echo "${!var_name}"

# correct — printf -v for dynamic assignment
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

## BCS1005 Input Sanitization

**Tier:** core

Validate and sanitize all user input. Use whitelist over blacklist. Pass `--` before any pathname operand that originates from variables or user input (`rm -- "$f"`, `cp -- "$src" "$dst"`) to prevent option injection via filenames beginning with `-`.

**Scope of `--`.** Every command that takes a pathname operand, read-only ones and builtins included: `cat`, `head`, `sort`, `grep`, `wc`, `stat`, `diff`, `source` and `cd` parse a leading dash exactly as `rm` does, and "read-only" is no defence — a file named `-o/etc/cron.d/job` turns `sort "$f"` into a write. The `--` is owed when an operand **begins with an expansion** (`"$f"`, `"$dir"/x`, `"${files[@]}"`, `"$(cmd)"/x`). It is **not** owed, and its absence is never a finding, when the operand begins with literal text (`./"$f"`, `/etc/"$name"`: it cannot start with a dash), when the variable is an option's argument (`sort -o "$out"`, `grep -f "$patterns"`), for a redirection (`< "$file"`), inside `[[ ]]`, or for a command that takes no pathname (`echo`, `printf`, `tr`). Place it before the first operand, which is not always the pathname: `grep -- "$pattern" "$file"`, `chmod -- 644 "$f"`, `awk -- 'prog' "$f"` (after the program, `awk` reads `--` as a filename).

```bash
# correct — validate integer
[[ $input =~ ^-?[0-9]+$ ]] || die 22 "Invalid integer: ${input@Q}"

# correct — validate path within allowed directory
# allowed_dir must be canonical (realpath output) with no trailing slash
real_path=$(realpath -e -- "$path")
[[ $real_path == "$allowed_dir"/* || $real_path == "$allowed_dir" ]] || die 13 'Path traversal blocked'

# correct — sanitize a bare filename: no separator, no traversal, not hidden
# (an allowed-character class alone admits '..' and '.hidden')
[[ $name =~ ^[a-zA-Z0-9_][a-zA-Z0-9._-]*$ ]] || die 22 "Invalid filename ${name@Q}"

# correct — -- before pathname operands from variables or input
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

# correct — no -- owed: literal-leading operand, option-argument, redirection
cat ./"$name"
wc -l /var/log/"$SCRIPT_NAME".log
sort -o "$output" -- "$input"
content=$(< "$file")
```

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

# correct — custom template
mktemp /tmp/"$SCRIPT_NAME".XXXXXX

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
      BASH_ENV ENV SHELLOPTS
exec /usr/libexec/myapp/helper "$@"
```

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
