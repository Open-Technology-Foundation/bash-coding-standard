<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Section 08: Command-Line Arguments

## BCS0800 Section Overview

Use `while (($#)); do case $1 in ... esac; shift; done` as the standard argument parsing pattern. This section covers parsing, standard options, option bundling, validation, and version output.

## BCS0801 Standard Parsing Pattern

**Tier:** core

**Scope.** This rule governs the form of an option-parsing loop where one exists. A script that takes no options has no loop to govern, and a script that answers a single flag may test it directly; in neither case is the absence of the loop a finding. The loop becomes mandatory once a script handles more than one option or any option that takes an argument: chaining `if`/`elif` tests over several options is a finding, because that is the pattern this loop replaces.

```bash
# correct — one flag, tested directly; no parsing loop is needed or expected
main() {
  if [[ ${1:-} == --version ]]; then
    printf '%s %s\n' "$SCRIPT_NAME" "$VERSION"
    return 0
  fi
  process "$@"
}

# correct — more than one option: the standard loop
while (($#)); do case $1 in
  -v|--verbose) VERBOSE=1 ;;
  -q|--quiet)   VERBOSE=0 ;;
  -n|--dry-run) DRY_RUN=1 ;;
  -o|--output)  noarg "$@"; shift; OUTPUT=$1 ;;
  -V|--version) printf '%s %s\n' "$SCRIPT_NAME" "$VERSION"; exit 0 ;;
  -h|--help)    show_help; exit 0 ;;
  --)           shift; FILES+=("$@"); break ;;
  -[vqnoVh]?*)  set -- "${1:0:2}" "-${1:2}" "${@:2}"; continue ;;
  -*)           die 22 "Invalid option ${1@Q}" ;;
  *)            FILES+=("$1") ;;
esac; shift; done

# wrong — missing the trailing shift: $1 is never consumed, infinite loop
while (($#)); do case $1 in
  -v|--verbose) VERBOSE=1 ;;
  -*)           die 22 "Invalid option ${1@Q}" ;;
  *)            FILES+=("$1") ;;
esac; done

# wrong — arms for attached option-arguments; the argument is always the next word
--output=*)   OUTPUT=${1#*=} ;;
-o?*)         OUTPUT=${1:2} ;;

# wrong — several options handled by an if/elif chain instead of the loop
if [[ $1 == -v || $1 == --verbose ]]; then
  VERBOSE=1
elif [[ $1 == -o || $1 == --output ]]; then
  OUTPUT=$2
fi
```

Key rules:
- Use `(($#))` as the loop condition, not `[[ $# -gt 0 ]]` (house style; functionally equivalent)
- The mandatory `shift` at loop end is critical — omitting it causes infinite loops
- For options with arguments: `noarg "$@"; shift; variable=$1`
- An option's argument is always a separate word, for short and long options alike (`-o FILE`, `--output FILE`). Attached forms (`-oFILE`, `--output=FILE`) are not part of a BCS interface: the loop has no arm for them, and help text documents only the separated form
- For boolean flags: just set, no extra shift needed
- For exit options (`--help`, `--version`): use `exit 0`, no shift needed
- Use `continue` after option disaggregation to re-process expanded options

See also: [Argument Processing Reference](../benchmarks/args-processing_reference.md) — comparison of BCS while/case, getopts, GNU getopt, and simple while/case with benchmark data.

## BCS0802 Version Output

**Tier:** style

Format: `scriptname X.Y.Z` without the word "version".

```bash
# correct
echo "$SCRIPT_NAME $VERSION"
# output: myscript 1.0.0

# wrong
echo "$SCRIPT_NAME version $VERSION"
echo "Version: $VERSION"
```

## BCS0803 Argument Validation

**Tier:** core

Validate option arguments exist before capturing them.

```bash
# correct — noarg checks $2 exists
noarg() { (($# > 1)) || die 22 "Option ${1@Q} requires an argument"; }

# usage
-o|--output) noarg "$@"; shift; OUTPUT=$1 ;;

# wrong — no validation
-o|--output) shift; OUTPUT=$1 ;;     # --output as the last word: $1 is unbound, set -u aborts
```

Always call validators BEFORE `shift` — they must inspect `$2`. `noarg` checks that a value follows; it does not reject a value that begins with `-`, because `-` (stdin) and negative numbers are legitimate values. When the option needs a particular form, validate the value itself (BCS1005).

Validate required arguments after parsing:

```bash
((${#FILES[@]})) || die 2 'No input files specified'
[[ $mode =~ ^(normal|fast|safe)$ ]] || die 22 "Invalid mode ${mode@Q}"
```

## BCS0804 Parsing Location

**Tier:** recommended

Place argument parsing inside `main()` for better testability.

```bash
# correct
main() {
  while (($#)); do case $1 in
    # ...
  esac; shift; done
  readonly VERBOSE DRY_RUN OUTPUT

  process_files
}

# acceptable for simple scripts under 200 lines
while (($#)); do case $1 in
  # ...
esac; shift; done
```

Make variables readonly after parsing completes.

## BCS0805 Short Option Bundling

**Tier:** recommended

Support bundled short options like `-vvn` expanding to `-v -v -n`.

```bash
# correct — recommended disaggregation pattern (list valid short options explicitly)
-[vqnoVh]?*) set -- "${1:0:2}" "-${1:2}" "${@:2}"; continue ;;

# correct — alternative: single-pass disaggregation (avoids re-entering the case loop per character;
# see ../benchmarks/args-processing_reference.md); only worth it for very hot argument loops
-[vqnoVh]?*)
  local -- opt=${1:1}
  local -a new_args=()
  while ((${#opt})); do
    new_args+=("-${opt:0:1}")
    opt=${opt:1}
  done
  set -- '' "${new_args[@]}" "${@:2}"
  ;;
```

Place bundling case before `-*)` invalid option handler and after all explicit option cases. List only valid short options in the pattern to prevent incorrect expansion.

Include arg-taking options in the character class. They work correctly when last in the bundle — the disaggregation peels them off as a separate `-X` flag, and `shift` in their case handler picks up the argument normally. Example: `-vno output.txt` disaggregates to `-v -n -o`, then `-o` consumes `output.txt` via `shift`. The user must place arg-taking options last; `-von file` would incorrectly disaggregate to `-v -o -n`.

▲ Attached option-arguments (`-oFILE`) are NOT supported by this pattern — the disaggregator prepends `-` to the remainder, so `-ooutput.txt` becomes `-o -output.txt` and the handler silently captures `-output.txt` (`noarg` cannot catch it). Option arguments are always separate words, for short and long options alike: `-o FILE`, `--output FILE` (BCS0801).

```bash
# correct — the argument is the next word, bundled or not
myscript -vn -o out.txt input.txt
myscript -vno out.txt input.txt
myscript --verbose --output out.txt input.txt

# wrong — attached arguments are not part of a BCS interface
myscript -oout.txt input.txt
myscript --output=out.txt input.txt
```

## BCS0806 Standard Options

**Tier:** recommended

Use consistent option letters and variable names across all BCS-compliant scripts. Avoid reassigning a standard letter to a different purpose.

**Scope.** This rule is a registry of what each letter means, not a checklist of options a script must offer. A script chooses its own option set, and the absence of any option listed below is **never** a finding: a script that answers only `--version`, offers no `-h`, or provides `-n` without `-N` violates nothing here. The finding is *reassignment* — a listed letter or variable name put to a different purpose (`-v` for version, `-d` for debug, `-n` for anything but dry-run). The groupings below say how strongly each option is recommended to authors; they do not make its absence reportable.

**Strongly Recommended** — for any script with an option-parsing loop (BCS0801):

| Short | Long | Variable | Default | Purpose |
|-------|------|----------|---------|---------|
| `-V` | `--version` | — | — | Print version and exit |
| `-h` | `--help` | — | — | Print help and exit |

**Recommended** — include when the script produces output or performs actions:

| Short | Long | Variable | Default | Purpose |
|-------|------|----------|---------|---------|
| `-v` | `--verbose` | `VERBOSE` | `1` | Enable verbose output |
| `-q` | `--quiet` | `VERBOSE` | `0` | Suppress informational output |

**Optional** — use when the script needs these capabilities:

| Short | Long | Variable | Default | Purpose |
|-------|------|----------|---------|---------|
| `-n` | `--dry-run` | `DRY_RUN` | `0` or `1` | Preview without changes |
| `-N` | `--not-dry-run` | `DRY_RUN` | `0` | Execute changes (cancels dry-run) |
| `-f` | `--force` | `PROMPT` | `1` | Skip confirmation prompts: sets `PROMPT=0` (BCS0701, BCS0709) |
| `-D` | `--debug` | `DEBUG` | `0` | Enable debug output |
| `-p` | `--port` | `PORT` | varies | Network port |
| `-P` | `--prefix` | `PREFIX` | varies | Installation prefix |

Key rules:
- **Avoid reassigning** a standard letter to a different purpose — `-v` is always verbose, never version
- **Toggle pairs:** `-n`/`-N` and `-v`/`-q` are complementary toggles sharing a variable; a script that offers both halves spells them this way, but offering one half alone is not a finding
- **DRY_RUN=1 default** for destructive scripts — require `-N` to execute; use `DRY_RUN=0` for non-destructive scripts
- **Use `declare -i`** for all flag variables: `declare -i VERBOSE=1 DRY_RUN=0 DEBUG=0 PROMPT=1`

```bash
# correct — standard options with consistent letters and variables
declare -i VERBOSE=1 DRY_RUN=0 DEBUG=0 PROMPT=1

while (($#)); do case $1 in
  -v|--verbose)     VERBOSE=1 ;;
  -q|--quiet)       VERBOSE=0 ;;
  -n|--dry-run)     DRY_RUN=1 ;;
  -N|--not-dry-run) DRY_RUN=0 ;;
  -f|--force)       PROMPT=0 ;;
  -D|--debug)       DEBUG=1 ;;
  -V|--version)     echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
  -h|--help)        show_help; exit 0 ;;
  --)               shift; FILES+=("$@"); break ;;
  -[vqnNfDVh]?*)    set -- "${1:0:2}" "-${1:2}" "${@:2}"; continue ;;
  -*)               die 22 "Invalid option ${1@Q}" ;;
  *)                FILES+=("$1") ;;
esac; shift; done

# wrong — reassigned letters
-d|--debug)         # -d is not standard for debug; use -D
-v|--version)       # -v is verbose, never version; use -V

# not a finding — a small option set; nothing listed is mandatory
-V|--version)       echo "$SCRIPT_NAME $VERSION"; exit 0 ;;   # no -h, -v, -q: fine
```

See also: BCS0701 (message control flags), BCS0802 (version output format), BCS1207 (verbose pattern), BCS1208 (dry-run pattern).
