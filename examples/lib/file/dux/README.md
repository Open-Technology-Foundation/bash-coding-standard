# dux - Quick Directory Size Overview

[![Bash](https://img.shields.io/badge/Bash-5.2+-green.svg)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)

**Find out where your disk space is going in seconds.**

```bash
$ dux /var
4.0KiB    /var/empty
52.0KiB   /var/mail
1.2MiB    /var/backups
23.4MiB   /var/cache
156.8MiB  /var/lib
512.3MiB  /var/log
```

## What It Does

`dux` shows you the size of each subdirectory, sorted smallest to largest. Use it to:

- **Find space hogs** - Quickly identify which directories are consuming disk space
- **Plan cleanup** - See at a glance what to delete or archive
- **Monitor growth** - Check which directories are growing over time

## Installation

**One-liner (user install):**
```bash
git clone https://github.com/Open-Technology-Foundation/dux.git && cd dux && ./install.sh
```

**One-liner (system-wide):**
```bash
git clone https://github.com/Open-Technology-Foundation/dux.git && cd dux && sudo ./install.sh
```

The installer sets up:
- `dux` command (symlink to `dir-sizes`)
- Bash completion
- Man page (`man dux`)

To uninstall: `./install.sh --uninstall`

## Usage

```bash
dux [OPTIONS] [DIRECTORY]
```

| Option | Description |
|--------|-------------|
| `-L` | Follow all symlinks (a symlinked starting directory is always followed) |
| `-x, --one-file-system` | Stay on the target's filesystem (skip other mounts, such as `/proc`) |
| `-q, --quiet` | Suppress permission errors |
| `-h, --help` | Show help |
| `-V, --version` | Show version |

### Common Tasks

**Where is my disk space going?**
```bash
dux ~              # Check home directory
dux /              # Check entire filesystem (may need sudo)
```

**Find the largest directories:**
```bash
dux /var | tail -5         # Show 5 largest in /var
sudo dux -x / | tail -10   # Show 10 largest on the root filesystem
```

**Check a project for bloat:**
```bash
dux ~/projects/myapp       # Find large folders in project
```

**Pipe to other tools:**
```bash
dux . | grep -v node_modules   # Exclude node_modules
dux /home | tee sizes.txt      # Save output to file
```

**Follow symlinks:**
```bash
dux -L /opt/myapp              # Include symlinked directories
```

## Output Format

```
<size>    <path>
```

- Sizes use IEC units: B, KiB, MiB, GiB, TiB
- Sizes are apparent sizes (bytes of content, as `du -b`), not disk blocks
- Output is tab-separated (easy to parse with `cut`, `awk`)
- Sorted smallest to largest (largest at bottom for visibility)

## Handling Permissions

Permission errors from `du` appear on stderr but don't stop execution:

```bash
dux /var                   # Shows errors inline
dux -q /var                # Suppress errors with --quiet
sudo dux /var              # Full access to all directories
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 2 | Usage error (too many arguments) |
| 3 | Directory not found |
| 5 | I/O error (du failure) |
| 22 | Invalid option |

Aligned with [BCS §BCS0602](https://github.com/Open-Technology-Foundation/bash-coding-standard) canonical exit codes since v1.4.2. Scripts that previously checked `[[ $? -eq 1 ]]` for "bad path" must update to `-eq 3`.

## Requirements

- Bash 5.2+
- GNU coreutils (`du` with `-sb`, `sort`, `numfmt`, `nproc`)
- GNU findutils (`find`, `xargs`)

## Why dux?

| | dux | du -h | ncdu | dust |
|--|-----|-------|------|------|
| Sorted output | Yes | No* | Yes | Yes |
| Human-readable | Yes | Yes | Yes | Yes |
| One command | Yes | No* | Yes | Yes |
| Interactive | No | No | Yes | No |
| Dependencies | coreutils, findutils | coreutils | ncurses | Rust |

*`du` requires piping through `sort -h` for sorted human-readable output

`dux` fills the gap between raw `du` output and full-featured tools like `ncdu`. It's the quick answer to "what's using my disk space?" without installing additional software.

## License

GPL-3.0 - See [LICENSE](LICENSE)

## See Also

- [ncdu](https://dev.yorhel.nl/ncdu) - Interactive disk usage analyzer
- [dust](https://github.com/bootandy/dust) - du + rust = dust
- [BASH Coding Standard](https://github.com/Open-Technology-Foundation/bash-coding-standard) - Coding standard used by this project
