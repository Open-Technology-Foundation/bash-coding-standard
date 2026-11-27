# Changelog

All notable changes to the en_ID locale will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.3.1] - 2026-11-26

### Fixed
- An installer interrupted with Ctrl-C or killed with SIGTERM exited 0, so a cut-off install reported success. The installers and the test scripts now clean up from the `EXIT` trap alone and exit 130 or 143 when interrupted.
- `ensure-persistence.sh` read a failing `locale -a` as "en_ID is missing": it recompiled the locale, then stopped with "en_ID is not available after setup". `make test-installed` reported "en_ID is not installed" in the same case. Both now stop with an error that names `locale -a`.
- CI: the check that en_ID is gone after `make uninstall` passed when `locale -a` failed.

### Changed
- The test scripts use colour only when both stdout and stderr are terminals, as the installers do.
- Section comments and blank lines in the scripts follow the Bash Coding Standard.

## [2.3.0] - 2026-11-13

### Fixed
- `make test` tested the installed locale whenever en_ID was installed, so on every maintainer machine it passed against a broken source. It now always tests `build/` (through `LOCPATH`); `make test-installed` tests the installed locale.
- The Ubuntu APT hook never regenerated anything (Ubuntu's `locale-gen` rejects a named custom locale), and `make install-persistent` exited 1 on its first run on Ubuntu for the same reason. Debian, Ubuntu and Arch now rely on the `/etc/locale.gen` line, which their packages rebuild from.
- The Fedora DNF hook never fired: it used transaction states DNF rejects, and DNF5 does not read that directory. Fedora and RHEL now get en_ID compiled as a directory under `/usr/lib/locale`, outside the archive that package updates replace.
- On Debian and Ubuntu with `locales-all`, which deletes the locale archive on every update, en_ID was lost at the next glibc update; it is now compiled as a directory there too. The same applies where `/etc/locale.gen` links to the packaged list of all locales, which is no longer written through.
- Re-running an installer over an install made by 2.1.0 or earlier left the system-wide `LC_ALL` override in place. Installers now remove `LC_ALL` and the per-category `LC_*` lines for en_ID.
- `make uninstall` left the system default naming a locale that no longer existed. It now runs `uninstall.sh`, which restores the backup and reverts every file the installers change. A default that no longer names en_ID is left alone, with its backup.
- `int_select` was `00`, described as Indonesia's international access code. Indonesia has no single prefix; it is now `001,008,007,009`, as in glibc's `id_ID`.
- The LC_NAME comment and README claimed Mr./Ms. prefixes that were never defined.
- `make -f /path/Makefile` from another directory failed and left a stray `build/` there; source paths are now anchored to the Makefile's directory.
- Installer messages began `bash:` when piped into bash, as documented; they now name the script.
- CHANGELOG dates for 1.0.0 and 2.0.0 (2025, not 2024), and links to tags that never existed.

### Changed
- Installers clone the release tag matching their own version (shallow, with a timeout) instead of `main`, accept only `https://` and `file:///` sources, and run everything inside `main()`, so a download cut off mid-stream runs nothing.
- Installers set the system default through `LANG` alone.
- Installers call `make install-persistent` instead of carrying their own copies of the persistence code.
- `ensure-persistence.sh` deletes the hook files written by earlier releases and exits 13 when not run as root (was 1).
- LC_MESSAGES copies `en_GB` instead of `en_SG`; the compiled category is identical.
- README quick-start URLs name the release tag; manual installation uses `make install-persistent`.
- `LICENSE` now holds the full GPLv3 text; the copyright notice moved to the README.

### Added
- `uninstall.sh`, run by `make uninstall`.
- `make test-installed`.
- Twelve tests (59 in total) covering the week definition, `date_fmt`, rendered 12-hour time, the remaining monetary fields, and two new categories, `LC_CTYPE` and `LC_COLLATE`.
- `tests/test_scripts.sh`, which checks the test harness, the Makefile and the scripts' refusals without root.
- `tests/test_install.sh`, a root-only integration test that CI runs in Ubuntu, Debian, Fedora, Rocky Linux and Arch containers: install over a 2.1.0 install, package update, second install, uninstall.
- CI: ShellCheck, whitespace and tab checks, and a pinned, read-only workflow.

### Removed
- Package-manager hooks for APT, DNF and pacman.
- Installer edits to `/etc/ssh/sshd_config`. Forwarding a client's locale needs `AcceptEnv LANG LC_*` on the server, which most distributions ship.
- The installers' rename of another package's APT configuration file around `apt-get update`; a failed update now only warns.

## [2.2.1] - 2026-06-03

### Fixed
- `make uninstall` now deregisters the compiled locale from the glibc archive. It previously deleted only `en_ID.UTF-8`, but the archive entry is normalised to `en_ID.utf8`, so the delete matched nothing and left `en_ID` in `locale -a`; it now also removes the normalised name.

## [2.2.0] - 2026-06-03

### Added
- Makefile `info` (display locale metadata) and `install-persistent` (install + run `ensure-persistence.sh`) targets.

### Fixed
- Restored 8 LC_MONETARY / `postal_fmt` / `lang_lib` tests inadvertently dropped after v2.1.0 (test suite back to 47).
- Installers no longer set a system-wide `LC_ALL` override; they set `LANG` plus per-category `LC_*` so individual category settings are honoured.
- `make check` now exits non-zero when en_ID is absent (was always exit 0, so it could never fail a build or gate `make install`).
- Installers no longer overwrite an existing locale backup on re-run, preserving the original pre-en_ID configuration.
- Installer `/etc/environment` and `/etc/locale.gen` idempotency checks use `grep -qxF` (fixed-string, whole-line) instead of a substring regex, so a commented or partial line no longer falsely suppresses the real append.

### Changed
- Test suite now verifies formatted date/time/number output in CI via `LOCPATH` against `build/` (previously gated behind `USE_SYSTEM_LOCALE` and skipped in build-only CI).
- `make test` now depends on `compile`.
- CI matrix drops `ubuntu-26.04` (no reliable hosted runner — jobs queue until the 24h auto-cancel); tests run on `ubuntu-22.04` and `ubuntu-24.04`.
- CI drops the redundant "Check locale syntax" step; `make compile` validates the locale definition's syntax, and `make check` is a post-install availability gate.
- CI installs the locale for real (`sudo make install`) and re-runs the suite in system-locale mode, exercising the install path and the post-install `check` gate end-to-end (was a `make -n install` dry run).
- Installers exit `13` (EACCES) instead of `1` when not run as root, matching the project's errno-style exit codes.
- Bare `make` now compiles to `build/` (previously printed help; use `make help` for the target list).
- README: corrected the 12-hour (`02:30:45 PM`), datetime weekday (`Mon 2024-01-15`), and `printf` grouping (`LC_NUMERIC`, not `LC_MONETARY`) examples, and replaced stale system-wide `LC_ALL` guidance with `LANG` + per-category `LC_*` to match the installers.
- Locale revision bumped to 2.2 (LC_IDENTIFICATION metadata only; the locale definition is unchanged from 2.1).

## [2.1.0] - 2026-03-09

### Added
- 8 new tests for LC_MONETARY fields, `postal_fmt`, and `lang_lib` (47 total)

### Changed
- Installer scripts refactored for BCS compliance (PATH hardening, messaging functions, error handling)
- CI workflow now tests across Ubuntu 22.04, 24.04, 26.04 (was 3 identical ubuntu-latest jobs)

### Fixed
- Makefile `check` target now properly validates locale syntax
- Makefile `.PHONY` missing `info` and `help` targets
- README `int_select` documentation (001 → 00)

### Removed
- Vestigial `[1.1.0] - Unreleased` CHANGELOG section

## [2.0.0] - 2025-12-13

### Added
- LC_TIME: Added `date_fmt` for ISO 8601 consistency in `date(1)` output
- LC_TIME: Added `week` definition (7;19971130;4) for ISO 8601 week numbering
- LC_TIME: Added proper 12-hour time support (`am_pm`, `t_fmt_ampm`)
- LC_ADDRESS: Added `country_name`, `lang_name`, `country_car`, `lang_ab`, `lang_term`, `lang_lib`
- LC_TELEPHONE: Added `tel_dom_fmt`, `int_select`, `int_prefix`
- Test suite expanded to 39 tests across 10 categories
- Locale Categories Reference table in README

### Changed
- Locale revision bumped to 2.0
- LC_TIME: `d_t_fmt` now uses ISO 8601 hybrid format (`%a %Y-%m-%d %T`)
- LC_TELEPHONE: `tel_dom_fmt` includes trunk prefix 0 for correct domestic dialing
- LC_TELEPHONE: `int_select` changed from "001" to "00" (generic international prefix)
- LC_MONETARY: `n_sign_posn` changed from 0 to 1 (minus prefix instead of parentheses)
- LC_NAME: Updated comments to accurately describe minimal definition
- README: Expanded Features table, added datetime/week/12-hour info
- README: Fixed currency format documentation (no space: Rp1,234.56)

### Fixed
- LC_TIME: Removed FIXME comment, replaced with proper week definition
- LC_TELEPHONE: `tel_int_fmt` formatting (removed extra semicolons)
- Documentation/code mismatch in LC_NAME comments

## [1.0.0] - 2025-06-27

### Added
- Initial release of en_ID locale
- Support for English language with Indonesian regional settings
- Complete locale definition covering all standard categories:
  - LC_MONETARY: Indonesian Rupiah (IDR) formatting
  - LC_NUMERIC: Decimal point and comma thousands separator
  - LC_TIME: 24-hour format with ISO 8601 dates
  - LC_MESSAGES: English yes/no strings (inherited from en_SG)
  - LC_PAPER: A4 paper size
  - LC_ADDRESS: Indonesian country codes
  - LC_TELEPHONE: International dialing format
  - LC_MEASUREMENT: Metric system
- Comprehensive test suite
- Build system using Makefile
- GitHub Actions CI/CD workflow
- Documentation and contribution guidelines

### Technical Details
- Based on en_GB for British English spelling
- Incorporates Indonesian formatting conventions
- Compatible with GNU libc locale system
- UTF-8 character encoding

[2.3.1]: https://github.com/Open-Technology-Foundation/en_ID/releases/tag/v2.3.1
[2.3.0]: https://github.com/Open-Technology-Foundation/en_ID/releases/tag/v2.3.0
[2.2.1]: https://github.com/Open-Technology-Foundation/en_ID/releases/tag/v2.2.1
[2.2.0]: https://github.com/Open-Technology-Foundation/en_ID/releases/tag/v2.2.0
[2.1.0]: https://github.com/Open-Technology-Foundation/en_ID/releases/tag/v2.1.0
