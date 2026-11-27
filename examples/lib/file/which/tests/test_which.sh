#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Comprehensive test suite for which
set -uo pipefail  # Note: no -e, we handle exit codes manually

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
WHICH="$SCRIPT_DIR/../which"

declare -i tests=0 passed=0 failed=0

# TAP-style output
ok()     { ((++tests)); ((++passed)); printf 'ok %d - %s\n' "$tests" "$1"; }
not_ok() { ((++tests)); ((++failed)); printf 'not ok %d - %s\n' "$tests" "$1"; }

# Assertions
assert_exit() {
  local -i expected=$1 actual=$2
  local desc=$3
  if [[ $actual -eq $expected ]]; then ok "$desc"; else not_ok "$desc (expected $expected, got $actual)"; fi
}

assert_output() {
  local expected=$1 actual=$2 desc=$3
  if [[ "$actual" == "$expected" ]]; then ok "$desc"; else not_ok "$desc (expected '$expected', got '$actual')"; fi
}

assert_contains() {
  local needle=$1 haystack=$2 desc=$3
  if [[ "$haystack" == *"$needle"* ]]; then ok "$desc"; else not_ok "$desc (missing '$needle')"; fi
}

assert_empty() {
  local actual=$1 desc=$2
  if [[ -z "$actual" ]]; then ok "$desc"; else not_ok "$desc (expected empty, got '$actual')"; fi
}

assert_not_empty() {
  local actual=$1 desc=$2
  if [[ -n "$actual" ]]; then ok "$desc"; else not_ok "$desc (expected non-empty)"; fi
}

# Setup test fixtures
setup() {
  TESTDIR=$(mktemp -d)
  mkdir -p "$TESTDIR"/{bin1,bin2,bin3}

  # Test executable in multiple dirs
  printf '#!/bin/sh\necho test' > "$TESTDIR/bin1/testcmd"
  chmod +x "$TESTDIR/bin1/testcmd"
  cp "$TESTDIR/bin1/testcmd" "$TESTDIR/bin2/testcmd"

  # Symlink for -c testing
  ln -s "$TESTDIR/bin1/testcmd" "$TESTDIR/bin1/symcmd"

  # Multi-level symlink
  ln -s "$TESTDIR/bin1/symcmd" "$TESTDIR/bin1/sym2cmd"

  # Broken symlink
  ln -s "$TESTDIR/nonexistent" "$TESTDIR/bin1/brokensym"

  # Non-executable file
  touch "$TESTDIR/bin1/noexec"

  # Directory with same name (shouldn't match)
  mkdir "$TESTDIR/bin1/testdir"

  # Executable for cwd test
  printf '#!/bin/sh\necho cwd' > "$TESTDIR/cwdcmd"
  chmod +x "$TESTDIR/cwdcmd"

  # Command starting with hyphen
  printf '#!/bin/sh\necho hyphen' > "$TESTDIR/bin1/-hyphen"
  chmod +x "$TESTDIR/bin1/-hyphen"

  # Directory with spaces in name
  mkdir -p "$TESTDIR/bin with spaces"
  cp "$TESTDIR/bin1/testcmd" "$TESTDIR/bin with spaces/testcmd"

  # Absolute symlink for -c slash path testing
  ln -s "$TESTDIR/bin1/testcmd" "$TESTDIR/symlink_abs"

  # Special character command
  printf '#!/bin/sh\necho special' > "$TESTDIR/bin1/test+cmd"
  chmod +x "$TESTDIR/bin1/test+cmd"

  TESTPATH="$TESTDIR/bin1:$TESTDIR/bin2:$TESTDIR/bin3:/usr/bin:/bin"
}

teardown() {
  rm -rf "$TESTDIR"
}

trap teardown EXIT

# === TESTS ===

run_tests() {
  echo "# which test suite"

  # --- BASIC OPERATIONS ---
  echo "# Basic operations"

  local out rc

  # Find existing command
  out=$("$WHICH" ls 2>&1); rc=$?
  assert_exit 0 $rc "basic: find ls"
  assert_contains "/ls" "$out" "basic: output contains /ls"

  # Find non-existent command
  out=$("$WHICH" nonexistent_cmd_xyz 2>&1); rc=$?
  assert_exit 1 $rc "basic: nonexistent returns 1"

  # Multiple commands (all exist)
  out=$("$WHICH" ls cat 2>&1); rc=$?
  assert_exit 0 $rc "basic: multiple existing"

  # Multiple commands (mixed)
  out=$("$WHICH" ls nonexistent_xyz cat 2>&1); rc=$?
  assert_exit 1 $rc "basic: mixed returns 1"

  # Multiple commands (none exist)
  out=$("$WHICH" nope1 nope2 nope3 2>&1); rc=$?
  assert_exit 1 $rc "basic: all nonexistent returns 1"

  # --- OPTIONS ---
  echo "# Options"

  # -a / --all
  out=$(PATH="$TESTPATH" "$WHICH" -a testcmd 2>&1); rc=$?
  assert_exit 0 $rc "opt: -a finds command"
  local lines
  lines=$(echo "$out" | wc -l)
  if [[ $lines -ge 2 ]]; then ok "opt: -a returns multiple matches"; else not_ok "opt: -a returns multiple matches (got $lines)"; fi

  out=$(PATH="$TESTPATH" "$WHICH" --all testcmd 2>&1); rc=$?
  assert_exit 0 $rc "opt: --all works"

  # -c / --canonical
  out=$(PATH="$TESTPATH" "$WHICH" -c symcmd 2>&1); rc=$?
  assert_exit 0 $rc "opt: -c finds symlink"
  assert_contains "testcmd" "$out" "opt: -c resolves to real path"

  out=$(PATH="$TESTPATH" "$WHICH" --canonical symcmd 2>&1); rc=$?
  assert_exit 0 $rc "opt: --canonical works"

  # -s returns correct exit codes
  out=$(PATH="$TESTPATH" "$WHICH" -s testcmd 2>&1); rc=$?
  assert_exit 0 $rc "opt: -s returns 0 when found"
  assert_empty "$out" "opt: -s produces no output (found)"

  out=$(PATH="$TESTPATH" "$WHICH" -s nonexistent 2>&1); rc=$?
  assert_exit 1 $rc "opt: -s returns 1 when not found"

  out=$(PATH="$TESTPATH" "$WHICH" --silent testcmd 2>&1); rc=$?
  assert_empty "$out" "opt: --silent produces no output"

  # -q is not a valid option (removed in 2.0)
  out=$(PATH="$TESTPATH" "$WHICH" -q testcmd 2>&1); rc=$?
  assert_exit 2 $rc "opt: -q is invalid option"

  # -V / --version
  out=$("$WHICH" -V 2>&1); rc=$?
  assert_exit 0 $rc "opt: -V returns 0"
  assert_contains "which" "$out" "opt: -V shows name"
  assert_contains "2.0" "$out" "opt: -V shows version"

  out=$("$WHICH" --version 2>&1); rc=$?
  assert_exit 0 $rc "opt: --version works"

  # -h / --help
  out=$("$WHICH" -h 2>&1); rc=$?
  assert_exit 0 $rc "opt: -h returns 0"
  assert_contains "Usage:" "$out" "opt: -h shows usage"

  out=$("$WHICH" --help 2>&1); rc=$?
  assert_exit 0 $rc "opt: --help works"

  # Combined options
  out=$(PATH="$TESTPATH" "$WHICH" -ac symcmd 2>&1); rc=$?
  assert_exit 0 $rc "opt: -ac combined works"

  out=$(PATH="$TESTPATH" "$WHICH" -sa testcmd 2>&1); rc=$?
  assert_exit 0 $rc "opt: -sa combined works"
  assert_empty "$out" "opt: -sa still silent"

  out=$(PATH="$TESTPATH" "$WHICH" -as testcmd 2>&1); rc=$?
  assert_exit 0 $rc "opt: -as combined works"

  # --- EXIT CODES ---
  echo "# Exit codes"

  "$WHICH" ls >/dev/null 2>&1; rc=$?
  assert_exit 0 $rc "exit: 0 when found"

  "$WHICH" nonexistent_xyz >/dev/null 2>&1; rc=$?
  assert_exit 1 $rc "exit: 1 when not found"

  "$WHICH" 2>/dev/null; rc=$?
  assert_exit 1 $rc "exit: 1 when no args"

  "$WHICH" -z 2>/dev/null; rc=$?
  assert_exit 2 $rc "exit: 2 for invalid option"

  "$WHICH" --badopt 2>/dev/null; rc=$?
  assert_exit 2 $rc "exit: 2 for invalid long option"

  # --- PATH HANDLING ---
  echo "# PATH handling"

  # Note: /usr/bin included so #!/usr/bin/env bash can find bash
  # Leading colon (cwd first)
  pushd "$TESTDIR" >/dev/null || return 1
  out=$(PATH=":/usr/bin:$TESTDIR/bin1" "$WHICH" cwdcmd 2>&1); rc=$?
  assert_exit 0 $rc "path: leading colon finds cwd"
  popd >/dev/null || return 1

  # Trailing colon (cwd last)
  pushd "$TESTDIR" >/dev/null || return 1
  out=$(PATH="/usr/bin:$TESTDIR/bin1:" "$WHICH" cwdcmd 2>&1); rc=$?
  assert_exit 0 $rc "path: trailing colon finds cwd"
  popd >/dev/null || return 1

  # Double colon (cwd in middle)
  pushd "$TESTDIR" >/dev/null || return 1
  out=$(PATH="/usr/bin:$TESTDIR/bin1::$TESTDIR/bin2" "$WHICH" cwdcmd 2>&1); rc=$?
  assert_exit 0 $rc "path: double colon finds cwd"
  popd >/dev/null || return 1

  # Empty PATH - invoke bash directly since env can't find it with empty PATH
  out=$(PATH="" /bin/bash "$WHICH" ls 2>&1); rc=$?
  assert_exit 1 $rc "path: empty PATH returns 1"

  # PATH with non-existent directories
  out=$(PATH="/nonexistent:/usr/bin:$TESTDIR/bin1" "$WHICH" testcmd 2>&1); rc=$?
  assert_exit 0 $rc "path: skips non-existent dirs"

  # Single dot in PATH
  pushd "$TESTDIR" >/dev/null || return 1
  out=$(PATH=".:/usr/bin" "$WHICH" cwdcmd 2>&1); rc=$?
  assert_exit 0 $rc "path: explicit dot works"
  popd >/dev/null || return 1

  # --- INPUT HANDLING ---
  echo "# Input handling"

  # Absolute path
  out=$("$WHICH" /usr/bin/ls 2>&1); rc=$?
  assert_exit 0 $rc "input: absolute path"
  assert_output "/usr/bin/ls" "$out" "input: absolute path output"

  # Relative path
  pushd "$TESTDIR" >/dev/null || return 1
  out=$("$WHICH" ./cwdcmd 2>&1); rc=$?
  assert_exit 0 $rc "input: relative path"
  popd >/dev/null || return 1

  # -- separator
  out=$(PATH="$TESTPATH" "$WHICH" -- testcmd 2>&1); rc=$?
  assert_exit 0 $rc "input: -- separator"

  # Command starting with hyphen
  out=$(PATH="$TESTPATH" "$WHICH" -- -hyphen 2>&1); rc=$?
  assert_exit 0 $rc "input: hyphen command via --"

  # --- EDGE CASES ---
  echo "# Edge cases"

  # Non-executable not matched
  out=$(PATH="$TESTPATH" "$WHICH" noexec 2>&1); rc=$?
  assert_exit 1 $rc "edge: non-executable not matched"

  # Directory not matched
  out=$(PATH="$TESTPATH" "$WHICH" testdir 2>&1); rc=$?
  assert_exit 1 $rc "edge: directory not matched"

  # Multi-level symlink resolution
  out=$(PATH="$TESTPATH" "$WHICH" -c sym2cmd 2>&1); rc=$?
  assert_exit 0 $rc "edge: multi-level symlink resolved"
  assert_contains "testcmd" "$out" "edge: resolves to final target"

  # Broken symlink with -c
  out=$(PATH="$TESTPATH" "$WHICH" brokensym 2>&1); rc=$?
  assert_exit 1 $rc "edge: broken symlink not found (not executable)"

  # --- EXTENDED COVERAGE ---
  echo "# Extended coverage"

  # Error message on stderr for invalid option
  out=$("$WHICH" -z 2>&1 >/dev/null); rc=$?
  assert_contains "Illegal option" "$out" "ext: invalid option shows Illegal option on stderr"

  # No-args produces no stdout
  out=$("$WHICH" 2>/dev/null); rc=$?
  assert_empty "$out" "ext: no-args produces no output"

  # Spaces in PATH directory name
  out=$(PATH="$TESTDIR/bin with spaces:/usr/bin" "$WHICH" testcmd 2>&1); rc=$?
  assert_exit 0 $rc "ext: spaces in PATH directory"
  assert_contains "bin with spaces/testcmd" "$out" "ext: spaces in PATH output correct"

  # -c with absolute symlink slash path
  out=$("$WHICH" -c "$TESTDIR/symlink_abs" 2>&1); rc=$?
  assert_exit 0 $rc "ext: -c with absolute symlink path"
  assert_contains "testcmd" "$out" "ext: -c resolves absolute symlink"

  # -c broken symlink via slash path returns 1
  out=$("$WHICH" -c "$TESTDIR/bin1/brokensym" 2>&1); rc=$?
  assert_exit 1 $rc "ext: -c broken symlink via slash path returns 1"

  # -a output ordering: first match from bin1
  out=$(PATH="$TESTDIR/bin1:$TESTDIR/bin2" "$WHICH" -a testcmd 2>&1); rc=$?
  local first_line
  first_line=$(echo "$out" | head -n1)
  assert_contains "$TESTDIR/bin1" "$first_line" "ext: -a first match from first PATH entry"

  # -a output ordering: second match from bin2
  local second_line
  second_line=$(echo "$out" | sed -n '2p')
  assert_contains "$TESTDIR/bin2" "$second_line" "ext: -a second match from second PATH entry"

  # -a shows duplicate PATH entries
  out=$(PATH="$TESTDIR/bin1:$TESTDIR/bin1" "$WHICH" -a testcmd 2>&1); rc=$?
  lines=$(echo "$out" | wc -l)
  if [[ $lines -ge 2 ]]; then ok "ext: -a shows duplicate PATH entries"; else not_ok "ext: -a shows duplicate PATH entries (got $lines)"; fi

  # Very long target name handled
  local longname
  longname=$(printf 'a%.0s' {1..200})
  out=$(PATH="$TESTPATH" "$WHICH" "$longname" 2>&1); rc=$?
  assert_exit 1 $rc "ext: very long target name handled"

  # -- prevents -a being parsed as option
  out=$(PATH="$TESTPATH" "$WHICH" -- -a 2>&1); rc=$?
  assert_exit 1 $rc "ext: -- prevents -a being parsed as option"

  # -- prevents -V being parsed
  out=$(PATH="$TESTPATH" "$WHICH" -- -V 2>&1); rc=$?
  assert_exit 1 $rc "ext: -- prevents -V being parsed as option"

  # -- with multiple targets
  out=$(PATH="$TESTPATH" "$WHICH" -- testcmd testcmd 2>&1); rc=$?
  assert_exit 0 $rc "ext: -- with multiple targets"

  # Symlink found without -c (not resolved)
  out=$(PATH="$TESTPATH" "$WHICH" symcmd 2>&1); rc=$?
  assert_exit 0 $rc "ext: symlink found without -c"
  assert_contains "symcmd" "$out" "ext: symlink not resolved without -c"

  # Executable in trailing-slash dir (path/)
  out=$(PATH="$TESTDIR/bin1/:/usr/bin" "$WHICH" testcmd 2>&1); rc=$?
  assert_exit 0 $rc "ext: executable in trailing-slash dir"

  # Target with special chars (test+cmd)
  out=$(PATH="$TESTPATH" "$WHICH" "test+cmd" 2>&1); rc=$?
  assert_exit 0 $rc "ext: target with special chars"

  # Single target repeated (which ls ls)
  out=$("$WHICH" ls ls 2>&1); rc=$?
  assert_exit 0 $rc "ext: single target repeated"
  lines=$(echo "$out" | wc -l)
  if [[ $lines -ge 2 ]]; then ok "ext: repeated target shows multiple lines"; else not_ok "ext: repeated target shows multiple lines (got $lines)"; fi

  # -a with single match only
  out=$(PATH="$TESTDIR/bin1" "$WHICH" -a testcmd 2>&1); rc=$?
  assert_exit 0 $rc "ext: -a with single match"
  lines=$(echo "$out" | wc -l)
  assert_output "1" "$lines" "ext: -a with single match only shows 1 line"

  # -s with nonexistent + stderr check
  out=$(PATH="$TESTPATH" "$WHICH" -s nonexistent 2>&1); rc=$?
  assert_exit 1 $rc "ext: -s nonexistent returns 1"
  assert_empty "$out" "ext: -s suppresses all output for nonexistent"

  # -ac combined on symlink
  out=$(PATH="$TESTDIR/bin1:$TESTDIR/bin2:/usr/bin" "$WHICH" -ac symcmd 2>&1); rc=$?
  assert_exit 0 $rc "ext: -ac combined on symlink"
  assert_contains "testcmd" "$out" "ext: -ac resolves symlink"

  # PATH with relative dir (../bin)
  pushd "$TESTDIR/bin2" >/dev/null || return 1
  out=$(PATH="../bin1:/usr/bin" "$WHICH" testcmd 2>&1); rc=$?
  assert_exit 0 $rc "ext: PATH with relative dir"
  popd >/dev/null || return 1

  # --- DROP-IN COMPATIBILITY & SECURITY ---
  echo "# Drop-in compatibility & security"

  # Options after the first operand are literal targets, not parsed (debianutils parity)
  out=$(PATH="$TESTPATH" "$WHICH" testcmd -s 2>&1); rc=$?
  assert_exit 1 $rc "dropin: option after operand not parsed (-s looked up as a name)"
  assert_contains "testcmd" "$out" "dropin: operand before a stray option is still printed"

  # Bare - is a filename operand, not an illegal option (rc 1, not 2; no error)
  out=$("$WHICH" - 2>&1); rc=$?
  assert_exit 1 $rc "dropin: bare - is a not-found operand (rc 1)"
  if [[ "$out" != *"Illegal option"* ]]; then ok "dropin: bare - emits no Illegal option error"; else not_ok "dropin: bare - emits no Illegal option error (got '$out')"; fi

  # Trailing -- after an operand is a literal target (debianutils parity)
  out=$(PATH="$TESTPATH" "$WHICH" testcmd -- 2>&1); rc=$?
  assert_exit 1 $rc "dropin: trailing -- after operand looked up as a name"

  # Trailing-slash PATH element joins raw (double slash), matching debianutils byte-for-byte
  out=$(PATH="$TESTDIR/bin1/:/usr/bin" "$WHICH" testcmd 2>&1); rc=$?
  assert_exit 0 $rc "dropin: executable found via trailing-slash PATH element"
  assert_contains "$TESTDIR/bin1//testcmd" "$out" "dropin: trailing-slash PATH joins raw (byte-parity)"

  # -c must not execute a PATH-supplied realpath (no hijack -> no arbitrary code exec)
  local hijackdir
  hijackdir=$(mktemp -d)
  printf '#!/bin/sh\necho HIJACKED\n' > "$hijackdir/realpath"
  chmod +x "$hijackdir/realpath"
  out=$(PATH="$hijackdir:$TESTDIR/bin1:/usr/bin:/bin" "$WHICH" -c symcmd 2>&1); rc=$?
  assert_exit 0 $rc "security: -c succeeds with a hostile realpath on PATH"
  assert_contains "testcmd" "$out" "security: -c uses the system realpath (resolves symlink)"
  if [[ "$out" != *HIJACKED* ]]; then ok "security: -c does not execute a PATH-supplied realpath"; else not_ok "security: -c executed a PATH-supplied realpath (HIJACK)"; fi
  rm -rf "$hijackdir"

  # --- SOURCED MODE ---
  echo "# Sourced mode"

  # Source creates which function
  out=$(bash -c "source '$WHICH' && type which 2>&1"); rc=$?
  assert_exit 0 $rc "sourced: creates which function"
  assert_contains "function" "$out" "sourced: type reports function"

  # Function finds commands
  out=$(bash -c "source '$WHICH' && which ls 2>&1"); rc=$?
  assert_exit 0 $rc "sourced: finds ls"
  assert_contains "/ls" "$out" "sourced: outputs path"

  # Options work: -a
  out=$(bash -c "source '$WHICH' && PATH='$TESTPATH' which -a testcmd 2>&1"); rc=$?
  assert_exit 0 $rc "sourced: -a works"

  # Options work: -s
  out=$(bash -c "source '$WHICH' && which -s ls 2>&1"); rc=$?
  assert_exit 0 $rc "sourced: -s works"
  assert_empty "$out" "sourced: -s no output"

  # Options work: -V
  out=$(bash -c "source '$WHICH' && which -V 2>&1"); rc=$?
  assert_exit 0 $rc "sourced: -V works"
  assert_contains "2.0" "$out" "sourced: -V shows version"

  # Options work: -h (brief help when sourced)
  out=$(bash -c "source '$WHICH' && which -h 2>&1"); rc=$?
  assert_exit 0 $rc "sourced: -h works"
  assert_contains "Usage:" "$out" "sourced: -h shows usage"

  # Strict mode isolation: errexit not set
  out=$(bash -c "source '$WHICH'; [[ \$- == *e* ]] && echo FAIL || echo OK"); rc=$?
  assert_output "OK" "$out" "sourced: errexit not set in parent"

  # Strict mode isolation: nounset not set
  out=$(bash -c "source '$WHICH'; [[ \$- == *u* ]] && echo FAIL || echo OK"); rc=$?
  assert_output "OK" "$out" "sourced: nounset not set in parent"

  # Strict mode isolation: pipefail not set
  out=$(bash -c "source '$WHICH'; shopt -q -o pipefail && echo FAIL || echo OK"); rc=$?
  assert_output "OK" "$out" "sourced: pipefail not set in parent"

  # Function NOT exported to subshells (avoids shadowing the system which in children).
  # env -i isolates the check from any ambient BASH_FUNC_which a profile.d install exports.
  out=$(env -i PATH="$PATH" bash --norc -c "source '$WHICH' && bash -c 'type -t which' 2>&1")
  if [[ "$out" != "function" ]]; then ok "sourced: which not exported to child shells"; else not_ok "sourced: which exported to child shells (shadows system which)"; fi

  # Help does not leak a global _which_help into the caller's namespace
  out=$(env -i PATH="$PATH" bash --norc -c "source '$WHICH'; which ls >/dev/null 2>&1; type -t _which_help 2>/dev/null")
  assert_empty "$out" "sourced: _which_help not leaked into namespace"

  # Return vs exit: error doesn't kill shell
  out=$(bash -c "source '$WHICH'; which nonexistent_xyz 2>/dev/null; echo ALIVE"); rc=$?
  assert_contains "ALIVE" "$out" "sourced: error returns, doesn't exit"

  # Return vs exit: no args doesn't kill shell
  out=$(bash -c "source '$WHICH'; which 2>/dev/null; echo ALIVE"); rc=$?
  assert_contains "ALIVE" "$out" "sourced: no args returns, doesn't exit"

  # --- SUMMARY ---
  echo
  printf '1..%d\n' "$tests"
  echo "# $tests tests, $passed passed, $failed failed"

  return $failed
}

setup
run_tests
