# Changelog

All notable changes to dux are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.5.0] - 2026-11-26

### Added
- `-x, --one-file-system`: stay on the target's filesystem. Subdirectories
  that are mount points of other filesystems are left out and sizes exclude
  other mounts (as `du -x`), so `sudo dux -x /` no longer counts `/proc`
  (whose `kcore` alone has an apparent size of 128 TiB) or network mounts.

### Fixed
- Reject extra operands after `--` with canonical usage exit code `2` instead
  of silently ignoring trailing arguments.
- Keep installer metadata in sync with runtime version (`install.sh` reports the
  same version as `dux`).
- Sync man page metadata and exit-code documentation with runtime behavior
  (`0, 2, 3, 5, 22`).
- Handle newlines in subdirectory names (previously aborted with exit `5`) and
  preserve trailing whitespace in names (previously stripped from the output);
  the pipeline is now NUL-delimited end to end.
- Accept a directory name beginning with `-` (`dux -- -dir`); it was parsed
  as a `find` expression and failed with exit `3`. Such a path is shown with a
  `./` prefix. The same now applies to directories named `(` or `!`.
- A path ending in repeated slashes (`dux dir//`) failed with exit `5`; it is
  now normalised to a single trailing slash. (Regression introduced by the
  parallel `du` change below; never released.)
- `-L` now passes `-L` to `du` as well as `find`: a symlinked starting
  directory or subdirectory was sized as the link itself (a few bytes).
- A symlinked starting directory now works without `-L` (`find -H`, `du -D`,
  as `ls` and `du` treat their operands); it previously failed with exit `3`
  unless given a trailing slash.
- An empty operand (`dux ''`) now exits `3` (`Not a directory ''`) instead of
  silently sizing the current directory, and counts towards the one-operand
  limit (`dux '' /tmp` exits `2`).
- Sizes use `.` as the decimal point in every locale (`id_ID` printed
  `1,5KB`).
- `install.sh` no longer always warns that `~/.local/bin` is not in `PATH`; it
  checked its own locked-down `PATH` instead of the caller's.
- Bash completion registers with `-o filenames`, so directory names containing
  spaces are escaped and completed directories get a trailing `/`.

### Changed
- **BREAKING:** size labels are now `KiB`, `MiB`, `GiB`, `TiB` (were `KB`,
  `MB`, `GB`, `TB` on the same base-1024 numbers), as `--help`, the README
  and the man page always documented. Scripts that match `KB`/`MB` in the
  size column must update; the numbers themselves are unchanged.
- A subdirectory that disappears between listing and sizing is left out
  instead of aborting the whole run with exit `5`; `dux /proc` always failed
  because `find` listed its own short-lived PID directory. Exit `5` now means
  `du` returned no size for a directory that still exists.
- `--help` and the README state that sizes are apparent sizes (`du -b`).
- Measure subdirectories in parallel: one `du -sb` per directory, one job per
  CPU via `xargs`. Reported sizes are unchanged, including for hard links.
- Format the whole result with a single `numfmt` instead of one per line.
- Drop the temporary file and its `SIGINT/SIGTERM/EXIT` trap; `mktemp` is no
  longer a failure mode behind exit `5`, and a `SIGTERM` now exits `143`.
- `find`/`xargs` (findutils) and `nproc` are now required alongside `du`,
  `sort` and `numfmt`.
- Remove undocumented `-v/--verbose` alias from argument parsing; verbose mode
  remains the default behavior.
- Add argument-contract tests for `--` edge cases and invalid combined options.
- `dux` enables the full BCS `shopt` set (`shift_verbose extglob nullglob`).
- Test harness: `assert_contains`/`assert_not_contains` match literal
  substrings instead of regexes, and `warn` is reported as a warning rather
  than counted as a pass. The relative-path output test, which could never
  match and always warned, now asserts.

## [1.4.4] - 2026-05-06

### Fixed
- Close trap/mktemp signal-race window (BCS §BCS0110): install
  `SIGINT/SIGTERM/EXIT` trap *before* `mktemp`, so a signal arriving
  between resource creation and trap installation can no longer leave
  an orphan temporary file. `cleanup` already guards on
  `${DIRSIZES_TMPFILE:-}`, so firing pre-mktemp is a safe no-op.

## [1.4.3] - 2026-05-06

### Changed
- Refactor size-calculation loop: drop `cut` subprocess and `|| echo ''`
  rescue in favor of direct `du -sb` capture with BCS-canonical `||:`
  suppression and parameter-expansion size extraction. No behavior change;
  one fewer subprocess spawned per directory iterated.

## [1.4.2] - 2026-05-06

### Changed
- **BREAKING:** Exit codes aligned with BCS §BCS0602 canonical values:
  - Directory not found (non-existent path or path is a file) now exits **3** (was 1)
  - I/O failures (mktemp, du size calculation) now exit **5** (was 1)
  - Codes 0, 2, 22 unchanged
- `die` adopts BCS canonical guard: `(($# < 2)) || error "${@:2}"; exit "${1:-0}"`
- `cleanup` adopts BCS canonical shape with `local -i exitcode=${1:-$?}`

### Migration
Scripts checking `[[ $? -eq 1 ]]` for "bad path" must update to `-eq 3`.
I/O failures previously masked under `1` now surface as `5`.

## [1.4.1] - 2025-12-18

### Changed
- Shebangs updated to `#!/usr/bin/env bash` for BCS compliance and portability
- Added `shift_verbose` shopt to install.sh for better error detection

### Fixed
- File permissions for root installs (chmod 644 for manpage and completion)
- Manpage accessibility for user installs (run mandb after install)
- ShellCheck warnings in test files (SC2155, SC2076, SC2034)
- Shebang test pattern to accept both `#!/bin/bash` and `#!/usr/bin/env bash`

## [1.4.0] - 2025-12-18

### Added
- `-L` option to follow symbolic links when finding directories
- `-q, --quiet` option to suppress permission error messages
- `install.sh` for easy installation and uninstallation
- Bash completion (`dux.bash_completion`) for both `dux` and `dir-sizes` commands
- Man page (`dux.1`) with full documentation
- Comprehensive test suite (131 tests across 6 test files)

### Changed
- Updated README with user-focused documentation
- Improved help text for clarity and brevity
- Bash completion now uses `mapfile` pattern (shellcheck compliant)

### Fixed
- Shellcheck warnings in bash completion file (SC2207)

## [1.3.0] - 2025-12-18

### Changed
- Rewrote README to be user-focused (reduced from 208 to 128 lines)
- Streamlined help text (reduced from 50 to 33 lines)
- Updated internal documentation

## [1.2.1] - 2025-12-17

### Added
- PATH security hardening
- Secure temporary file handling with `mktemp`
- Signal handling for clean interruption (SIGINT, SIGTERM)
- Proper exit codes (0=success, 1=error, 2=too many args, 22=invalid option)

### Changed
- Follows BCS (Bash Coding Standard) v1.2.0
- Uses `du -sb` for accurate byte-level size calculation
- Output sorted smallest to largest (largest at bottom for easy viewing)

## [1.0.0] - 2025-12-01

### Added
- Initial release
- Display directory sizes in human-readable format (IEC units)
- Tab-separated output for easy parsing
- Support for relative and absolute paths
- Permission error handling (continues with accessible content)

[Unreleased]: https://github.com/Open-Technology-Foundation/dux/compare/v1.5.0...HEAD
[1.5.0]: https://github.com/Open-Technology-Foundation/dux/compare/v1.4.4...v1.5.0
[1.4.4]: https://github.com/Open-Technology-Foundation/dux/compare/v1.4.3...v1.4.4
[1.4.3]: https://github.com/Open-Technology-Foundation/dux/compare/v1.4.2...v1.4.3
[1.4.2]: https://github.com/Open-Technology-Foundation/dux/compare/v1.4.1...v1.4.2
[1.4.1]: https://github.com/Open-Technology-Foundation/dux/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/Open-Technology-Foundation/dux/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/Open-Technology-Foundation/dux/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/Open-Technology-Foundation/dux/compare/v1.0.0...v1.2.1
[1.0.0]: https://github.com/Open-Technology-Foundation/dux/releases/tag/v1.0.0
