<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# BCS Core-Rules Cheat-Sheet

The **33 core-tier rules** — the `[ERROR]` set. A violation of any of these is a real
correctness or safety bug, and `bcs check --strict` (or any check with core findings) exits
non-zero. This is the minimum bar for "it works and won't bite you."

> Derived from `bcs codes -T core`. For the full rule body of any code: `bcs codes -E BCSdddd`.
> For all 112 codes (100 rules + 12 section overviews) across all tiers: `bcs codes`.

Icons: ◉ info · ▲ caution · ✓ correct · ✗ wrong.

---

## 1 · Script Structure & Layout
- **BCS0101 Strict Mode** — `set -euo pipefail` is mandatory; the first executable line after the shebang, comments, and shellcheck directives.
- **BCS0102 Shebang** — first line is a shebang: `#!/bin/bash`, `#!/usr/bin/bash`, or `#!/usr/bin/env bash`.
- **BCS0110 Cleanup and Traps** — define the cleanup function and set its trap *before* any code creates temporary resources.

## 2 · Variables & Data Types
- **BCS0202 Variable Scoping** — declare function-specific variables `local`.
- **BCS0206 Arrays** — always quote `"${arr[@]}"`; never `${arr[*]}` in iteration; build with `readarray -t`/`mapfile -t`, not word-splitting.

## 3 · Strings & Quoting
- **BCS0302 Command Substitution** — double-quote strings that contain `$(...)`.
- **BCS0303 Quoting in Conditionals** — inside `[[ ]]` there is no word-splitting/globbing; quoting matters only on the RHS of `==`/`!=` (pattern vs literal) and `=~` (quotes disable the regex).

## 4 · Functions & Libraries
- **BCS0406 Dual-Purpose Scripts** — for source-or-execute scripts, define functions before the source fence and `set -euo pipefail` after it.
- **BCS0407 Library Patterns** — pure libraries reject direct execution.
- **BCS0409 Bash Version Detection** — compare `BASH_VERSINFO` element by element, short-circuiting on the first differing index (never one compound `&&`).
- **BCS0410 Recursive Function State** — every variable assigned inside a recursive function must be `local`, *including for-loop variables*.

## 5 · Control Flow
- **BCS0501 Conditionals** — `[[ ]]` for string/file tests, `(( ))` for arithmetic; never legacy `[ ]`.
- **BCS0503 Loops** — declare loop-local variables before the loop, not inside it.
- **BCS0504 Process Substitution** — never pipe into a `while` loop; the pipe spawns a subshell and variable updates are lost. Use `done < <(cmd)`.

## 6 · Error Handling
- **BCS0601 Exit on Error** — `set -euo pipefail`: `-e` exits on failure, `-u` on unset variables, `-o pipefail` on any failed pipeline stage.
- **BCS0603 Trap Handling** — install cleanup traps early, before creating any resource; trap `EXIT` alone (it runs on INT/TERM too), since `trap 'cleanup $?' SIGINT SIGTERM EXIT` turns an interrupted run into exit 0.
- **BCS0604 Checking Return Values** — check the return value of every critical operation.
- **BCS0606 Conditional Declarations** — under `set -e`, an `&&` chain built on an arithmetic test must end with `||:` (or be inverted with `||`), since a false `(( ))` returns exit 1.

## 7 · I/O & Messaging
- **BCS0702 STDOUT vs STDERR Separation** — data to stdout, all messages/diagnostics to stderr, so `$(...)` capture and pipelines stay clean.

## 8 · Command-Line Arguments
- **BCS0801 Standard Parsing Pattern** — parse with `while (($#)); do case $1 in … esac; shift; done` and bundle combined short options; an option's argument is always a separate word (`-o FILE`, `--output FILE`).
- **BCS0803 Argument Validation** — confirm an option's argument exists before capturing it (`noarg "$@"`).

## 9 · File Operations
- **BCS0901 Safe File Testing** — use `[[ ]]` for file tests and always name the file in error messages.
- **BCS0902 Wildcard Expansion** — prefix globs with an explicit path (`./*`) so filenames beginning with `-` are not read as flags.
- **BCS0903 Process Substitution** — feed `while` loops with `< <(command)` to avoid subshell scope loss.

## 10 · Security
- **BCS1001 SUID/SGID Prohibition** — never set SUID/SGID on a Bash script. No exceptions.
- **BCS1002 PATH Security** — set a known-good `PATH` at script start to prevent command hijacking.
- **BCS1004 Eval Avoidance** — never `eval` untrusted input; prefer arrays and namerefs (see BCS0210), and validate a variable name from outside the script before `${!name}`, `printf -v` or `local -n`.
- **BCS1005 Input Sanitization** — validate and sanitize all input; whitelist over blacklist; validate an outside integer before any arithmetic context sees it.
- **BCS1006 Temporary File Handling** — always create temp files with `mktemp`; never hardcode temp paths.

## 11 · Concurrency & Jobs
- **BCS1101 Background Job Management** — track the PID of every background job you start.
- **BCS1103 Wait Patterns** — never discard a `wait` exit code; accumulate failures into a counter and fail once at the end.
- **BCS1104 Timeout Handling** — wrap network operations with `timeout`.

## 12 · Style & Development
- **BCS1206 Static Analysis Directives** — ShellCheck compliance is compulsory; suppress only documented exceptions with `#shellcheck disable=SCxxxx` / `#bcscheck disable=BCSxxxx`.

---

*This is the core subset. `recommended` (45) and `style` (22) rules round out the standard —*
*see [`data/BASH-CODING-STANDARD.md`](../data/BASH-CODING-STANDARD.md) or run `bcs codes`.*
