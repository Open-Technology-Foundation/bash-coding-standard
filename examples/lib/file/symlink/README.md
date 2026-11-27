# Symlink Utility

![Version](https://img.shields.io/badge/Version-1.5.1-blue.svg)
![License](https://img.shields.io/badge/License-GPL--3.0-green.svg)

A Bash utility that creates symbolic links in `/usr/local/bin` for executables, making them accessible system-wide. Designed for managing scripts across multiple directories with built-in safety and batch processing.

**Quick install:**
```bash
git clone https://github.com/Open-Technology-Foundation/symlink.git && cd symlink && sudo make install
```

## Primary Use Case: `.symlink` Files

Create a `.symlink` file in any project directory listing executables to make available system-wide:

```
# Comments start with #
  # Indented comments are valid

script1                       # → script1 (inline comments stripped)
tools/script2                 # → script2
build.bash build              # → build (custom name)
util.sh helper util-cmd       # → helper AND util-cmd (multiple links)
my\ script.sh                 # → "my script.sh" (escaped space in source)
my\ script.sh myscript        # → myscript (escaped source, custom name)
```

**Format:** `<source> [<linkname>...]` — paths relative to `.symlink` location.

**Parsing rules:**
1. Strip inline comments (`#` to end of line)
2. Trim leading/trailing whitespace
3. Skip empty lines
4. First token = source file (supports `\ ` for literal spaces), remaining tokens = link names
5. If no link names specified, use `basename(source)`
6. Link names do NOT support spaces (commands in /usr/local/bin shouldn't have spaces)

Process all `.symlink` files in a directory tree:

```bash
sudo symlink -SPd /my/scripts
```

This scans for `.symlink` files (max depth 5), creates symlinks, skips prompts for existing links (`-P`), and cleans broken symlinks (`-d`).

## Installation

```bash
git clone https://github.com/Open-Technology-Foundation/symlink.git
cd symlink
sudo make install
```

This installs:
- `symlink` to `/usr/local/bin/`
- manpage to `/usr/local/share/man/man1/`
- bash completion to `/etc/bash_completion.d/`

To uninstall:
```bash
sudo make uninstall
```

Verify:
```bash
symlink --version
man symlink
```

## Usage Examples

```bash
# Main usage - scan with no prompts, clean broken links
sudo symlink -SPd /my/scripts

# Scan current directory
sudo symlink -SPd

# List .symlink contents without creating links
symlink -l /path/to/projects

# Single file symlinking
sudo symlink /path/to/script

# Dry-run to preview changes
symlink -n ./my-script.sh

# Debug mode
symlink --debug -nSPd /path/to/scripts
```

## Command-Line Options

| Option | Description |
|--------|-------------|
| `-S, --scan-symlink` | Scan for `.symlink` files and process them |
| `-P, --no-prompt` | Skip confirmation prompts |
| `-f, --force` | Replace pre-existing non-symlink files (non-interactive) |
| `--backup` | Back up a replaced file to `NAME.bak~` before clobbering |
| `-d, --delete-broken-symlinks` | Clean up broken symlinks in target directory |
| `-t, --target-dir DIR` | Custom target directory (default: `/usr/local/bin`) |
| `-l, --list` | List `.symlink` file contents only |
| `-n, --dry-run` | Preview changes without executing |
| `-v, --verbose` | Verbose output |
| `-q, --quiet` | Suppress verbose output (opposite of `-v`) |
| `-D, --debug` | Debug mode with trace logging |
| `-h, --help` | Display help |
| `-V, --version` | Show version |

Options can be combined: `-SPd` for no-prompt scan with cleanup.

## Safety Features

Hard-protects a list of critical system binaries (`bash`, `sudo`, `ssh`, `rm`, …) from accidental replacement and flags any link that would shadow another `PATH` command. Pre-existing non-symlink files are skipped unless `--force`. `.symlink` source paths and link names are kept inside the project tree (no `..`/absolute escape). Scan depth is limited to 5 levels, a 2s timeout guards path resolution, and interactive mode is auto-detected for appropriate prompting. The critical-file list is a best-effort convenience guard, not a security boundary.

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `SYMLINK_DEBUG=1` | Enable debug logging to a `mktemp` file in `$TMPDIR` (default `/tmp`) |
| `SYMLINK_FORCE_CRITICAL=1` | Bypass critical file protection (use with caution) |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 3 | File not found |
| 13 | Permission denied |
| 22 | Invalid option |
| 50 | No symlink files found |

## Files

| File | Description |
|------|-------------|
| `symlink` | Main script |
| `symlink.1` | Manpage — full reference for options, `.symlink` format, and exit codes (`man symlink`) |
| `symlink.bash_completion` | Bash tab-completion for all options and arguments |
| `Makefile` | Install/uninstall targets (`make help` for details) |

## Requirements

- Bash 5.2+
- Root privileges (auto-elevates with sudo)
- Standard Linux utilities (realpath, timeout)

## License

[GPL-3.0](LICENSE) - GNU General Public License v3.0

## Contributing

Contributions welcome via Pull Requests.
