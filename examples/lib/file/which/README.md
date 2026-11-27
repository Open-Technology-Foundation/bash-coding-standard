# which

A robust `which` for Bash 4.4+ — a drop-in replacement for the Debian (debianutils) `which`, adding canonical-path resolution, a true silent mode, and correct POSIX PATH handling.

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL%203.0-blue.svg)](LICENSE)
[![Bash 4.4+](https://img.shields.io/badge/Bash-4.4%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Tests: 201 passing](https://img.shields.io/badge/Tests-201%20passing-brightgreen.svg)](tests/)

**Requires Bash 4.4+.**

## TL;DR

```bash
git clone https://github.com/Open-Technology-Foundation/whichx.git
cd whichx && sudo make install
which -a python3
```

## Why Replace which?

The standard `which` command varies significantly across Unix systems:

| Issue | Debian | macOS | Busybox |
|-------|--------|-------|---------|
| Exit code (no args) | 1 | 0 | 0 |
| Exit code (bad option) | 2 | 1 | 1 |
| `-s` silent mode | No | Yes | No |
| Long options | No | No | No |

This implementation provides:

- **Drop-in parity** with debianutils `which`: same exit codes, and option parsing stops at the first operand
- **Consistent exit codes**: `0` (found), `1` (not found, including no args), `2` (invalid option)
- **POSIX PATH compliance**: correct handling of empty PATH elements
- **Dual-mode execution**: run as a script OR source as a function (~12x faster)
- **Canonical resolution**: follow symlinks to the actual executable (`-c`)

## Installation

### Quick Install

```bash
git clone https://github.com/Open-Technology-Foundation/whichx.git
cd whichx && sudo make install
```

Installs to `/usr/local/bin/which` with the man page.

### Custom Prefix

```bash
sudo make install PREFIX=/usr/bin
```

### Sourceable Use (Recommended for Interactive Shells)

`which` can run as a shell **function** instead of an external process — no
`fork()`/`exec()` per call. After installing, source the script in your shell:

```bash
echo 'source /usr/local/bin/which' >> ~/.bashrc
```

Or make it available to all login shells by copying it into `profile.d`:

```bash
sudo cp which /etc/profile.d/which.sh
```

**Why is this faster?** An external command invocation costs fork() + exec() +
bash startup (~1.6ms); an in-process function is ~0.13ms — about **12x faster**.

**Note:** `/etc/profile.d/` is sourced by login shells via `/etc/profile`. Most
terminal emulators start non-login shells, which read `~/.bashrc` instead. If
`which` isn't a function in new terminals, add the `source` line to `~/.bashrc`.

### Uninstall

```bash
sudo make uninstall
```

If you enabled sourceable use, also remove the `source` line from `~/.bashrc`
or delete `/etc/profile.d/which.sh`.

## Usage

```
which [OPTIONS] [--] command ...
```

### Options

| Option | Long | Description |
|--------|------|-------------|
| `-a` | `--all` | Print all matches in PATH, not just the first |
| `-c` | `--canonical` | Resolve symlinks to the canonical path via `realpath` |
| `-s` | `--silent` | No output; communicate via exit code only |
| `-V` | `--version` | Print version and exit |
| `-h` | `--help` | Print help and exit |

Options can be combined (`-ac` equals `-a -c`) and must precede the command
names: the first non-option argument ends option parsing (getopts-style),
matching debianutils `which`.

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All commands found |
| 1 | One or more not found (or no arguments given) |
| 2 | Invalid option |

### Examples

```bash
which ls                       # /usr/bin/ls
which -a python3               # All python3 in PATH
which -c /usr/bin/python3      # Resolve symlink to the real binary
which -s docker && echo "ok"   # Silent check (exit code only)
which ls cat grep              # Multiple commands
which -- -weird-name           # Command starting with a hyphen
```

## Architecture

### Dual-Mode Design

The script works both as an executable and as a sourceable function:

```bash
# As executable (subprocess)
./which ls

# As sourced function (in-process)
source ./which
which ls
```

This is achieved with a **source fence** — a top-level `return` that only
succeeds when the file is being sourced:

```bash
which() {
  # ... function body ...
}

# --- source fence ---
return 0 2>/dev/null || {
  # --- direct execution ---
  set -euo pipefail
  shopt -s inherit_errexit
  which "$@"
}
```

When **sourced**, the top-level `return 0` succeeds and short-circuits the
`||`, leaving just the `which()` function defined in your shell. When
**executed**, `return` outside a function fails (silenced by `2>/dev/null`),
so the braced block enables strict mode and runs `which "$@"`.

The function is deliberately **not** exported with `declare -fx`: that would
shadow the system `which` in every child shell and leak this implementation's
semantics. A sourced `which()` lives only in the shell that sourced it; that
shell's children resolve the real `which` binary on PATH.

### Strict Mode Without Pollution

Enabling strict mode at the top of the file would pollute the sourcing shell.
The script places it **inside the source fence**, so it only ever applies to
direct execution:

- **Sourced**: `return 0` fires before strict mode — caller's shell unaffected
- **Executed**: strict mode applies only to the subprocess

### Function Structure

All logic lives in a single `which()` function with:

- All variables declared `local` (no namespace pollution)
- `return` instead of `exit` (function-safe)
- Help text inlined under `-h` — no helper functions leak into the sourcing shell
- The same usage text in both modes

### PATH Parsing

```bash
local _path=${PATH:-}
[[ $_path != *: ]] || _path+=':'   # Trailing colon = cwd; preserve the empty field
IFS=':' read -ra path_dirs <<< "$_path"

for path in "${path_dirs[@]}"; do
  [[ -n $path ]] || path='.'        # Empty element = cwd
  # ...
done
```

`read -ra` with a here-string drops trailing empty elements, so a trailing
colon is preserved by appending another `:` before the split.

## POSIX Compliance

Per POSIX, an empty element in PATH means the current directory. Many `which`
implementations get this wrong.

```bash
# Leading colon = cwd searched first
PATH=":/usr/bin" which ./script

# Trailing colon = cwd searched last
PATH="/usr/bin:" which ./script

# Double colon = cwd searched in middle
PATH="/usr/bin::/usr/local/bin" which ./script
```

This matters for security audits and understanding command resolution.

## Security

`-c` resolves symlinks with `realpath`, invoked with a **pinned** `PATH`
(`/usr/bin:/bin`). The PATH being searched is never used to locate `realpath`,
so a hostile directory on the caller's PATH cannot hijack canonical resolution.

## Performance

### Methodology

Benchmarks run each command 1000 times, measuring wall-clock time with
nanosecond precision.

### Results

| Test | which (subprocess) | which (sourced) | old.which (dash) |
|------|-------------------|-----------------|------------------|
| Single lookup | ~600 ops/s | ~7,500 ops/s | ~1,200 ops/s |
| Large PATH (50 dirs) | ~500 ops/s | ~6,000 ops/s | ~1,200 ops/s |
| Not found | ~600 ops/s | ~7,500 ops/s | ~1,200 ops/s |

### Analysis

**Why is subprocess mode ~2x slower than dash-based which?**

Bash has more startup overhead than dash. The actual PATH searching is nearly
identical, but bash's interpreter initialization dominates.

**Why is sourced mode ~12x faster?**

No fork(), no exec(), no interpreter startup. The function runs directly in the
current shell's process space.

### Run Benchmarks

```bash
bash tests/benchmark.sh
```

## Testing

### Run Tests

```bash
make test         # Bash functional suite (104 tests)
make test-posix   # POSIX /bin/sh suite (52 tests, for which.sh)
make test-compat  # Parity vs debianutils which (45 tests)
make test-all     # All of the above (201 tests)
```

Static analysis is run directly with `shellcheck -x which`.

### Test Coverage

- Basic operations (find, not found, multiple targets)
- All options (`-a`, `-c`, `-s`, `-V`, `-h`, and `--long` forms)
- Combined options (`-ac`, `-sa`, `-as`)
- Exit codes (0, 1, 2)
- Drop-in parity (option-after-operand, bare `-`, trailing `--`)
- PATH edge cases (leading/trailing/double colon, empty, nonexistent dirs)
- Input handling (absolute path, relative path, `--` separator, hyphen commands)
- Edge cases (non-executable, directories, symlinks, broken symlinks)
- Security (`-c` does not execute a PATH-supplied `realpath`)

### Adding Tests

Tests use TAP-style output. Add to `tests/test_which.sh`:

```bash
out=$("$WHICH" -a python3 2>&1); rc=$?
assert_exit 0 $rc "description"
assert_contains "python" "$out" "description"
```

## Contributing

### Code Style

- All variables `local` (sourceable requirement)
- Integer variables: `local -i count=0`
- Arrays: `local -a items=()`
- Conditionals: `[[ ]]` never `[ ]`
- Arithmetic: `(( ))` only
- 2-space indentation
- Quote all variable expansions
- Errors to stderr: `>&2 printf`

### Requirements

- Must pass `shellcheck -x which`
- Must pass `make test-all` (201 tests)
- No new dependencies

### Pull Requests

1. Fork the repository
2. Create a feature branch
3. Make changes
4. Run `make test-all`
5. Submit PR

## License

GPL-3.0-or-later — see [LICENSE](LICENSE)

**Indonesian Open Technology Foundation**
admin@yatti.id

## See Also

- `man which` — installed man page
- `type(1)` — bash builtin, shows aliases/functions too
- `command -v` — POSIX way to find commands
- `whereis(1)` — also searches man pages and source
