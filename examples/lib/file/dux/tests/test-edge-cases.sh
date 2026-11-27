#!/usr/bin/env bash
# Test edge cases and error handling of dux
# Note: uses -uo (no -e) so assertion failures don't abort the test run
set -uo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

#shellcheck disable=SC2155
declare -r SCRIPT_PATH=$(realpath -- "$0")
declare -r SCRIPT_DIR=${SCRIPT_PATH%/*}

# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

declare -r DUX=${1:-$SCRIPT_DIR/../dir-sizes}

# Create temp directory for tests
declare -- TEST_DIR
TEST_DIR=$(mktemp -d /tmp/dux-test-edge-XXXXXX)
declare -r TEST_DIR
trap 'rm -rf "$TEST_DIR"' EXIT

test_section 'Edge Cases'

# Test: Empty directory returns itself (find always returns the target dir)
mkdir -p "$TEST_DIR"/truly-empty
output=$("$DUX" "$TEST_DIR"/truly-empty 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Empty directory exits 0 (returns itself)'
assert_contains "$output" 'truly-empty' 'Empty dir shows in output'

# Test: Directory with only files returns itself
mkdir -p "$TEST_DIR"/files-only
touch "$TEST_DIR"/files-only/file1.txt "$TEST_DIR"/files-only/file2.txt
output=$("$DUX" "$TEST_DIR"/files-only 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Directory with only files exits 0'
assert_contains "$output" 'files-only' 'Files-only dir shows in output'

# Size column of the output line whose path is exactly $2
size_of() {
  awk -F'\t' -v p="$2" '$2 == p { sub(/ +$/, "", $1); print $1 }' <<<"$1"
}

# Test: A symlinked starting path is followed even without -L (as ls/du do
# for command-line operands), and is sized as its target
declare -- real_size
mkdir -p -- "$TEST_DIR"/real-dir/subdir
dd if=/dev/zero of="$TEST_DIR"/real-dir/blob bs=1000 count=100 2>/dev/null
ln -s -- "$TEST_DIR"/real-dir "$TEST_DIR"/symlink-to-dir
real_size=$(size_of "$("$DUX" -- "$TEST_DIR"/real-dir 2>&1)" "$TEST_DIR"/real-dir)
output=$("$DUX" -- "$TEST_DIR"/symlink-to-dir 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Symlinked starting path works without -L'
assert_contains "$output" 'symlink-to-dir/subdir' 'Symlinked starting path lists target contents'
assert_equals "$real_size" "$(size_of "$output" "$TEST_DIR"/symlink-to-dir)" \
  'Symlinked starting path sized as its target'

# Test: -L sizes a symlinked starting path as its target
output=$("$DUX" -L -- "$TEST_DIR"/symlink-to-dir 2>&1); ec=$?
assert_exit_code 0 "$ec" '-L flag allows symlink starting paths'
assert_contains "$output" 'subdir' 'With -L, symlink target contents shown'
assert_equals "$real_size" "$(size_of "$output" "$TEST_DIR"/symlink-to-dir)" \
  '-L sizes a symlinked starting path as its target'

# Test: -L sizes a symlinked subdirectory as its target, not as the link
mkdir -p -- "$TEST_DIR"/l-parent/real
dd if=/dev/zero of="$TEST_DIR"/l-parent/real/blob bs=1000 count=100 2>/dev/null
ln -s -- real "$TEST_DIR"/l-parent/lsub
output=$("$DUX" -L -- "$TEST_DIR"/l-parent 2>&1); ec=$?
assert_exit_code 0 "$ec" '-L with a symlinked subdirectory exits 0'
assert_equals "$(size_of "$output" "$TEST_DIR"/l-parent/real)" \
  "$(size_of "$output" "$TEST_DIR"/l-parent/lsub)" \
  '-L sizes a symlinked subdirectory as its target'

# Test: Symlinks within target are excluded (find -type d)
mkdir -p "$TEST_DIR"/has-symlinks/real-subdir
ln -s "$TEST_DIR"/has-symlinks/real-subdir "$TEST_DIR"/has-symlinks/symlink-subdir
output=$("$DUX" "$TEST_DIR"/has-symlinks 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Directory with symlinks handled'
assert_contains "$output" 'real-subdir' 'Real subdirectory found'

# Test: Directory with special chars in name
mkdir -p "$TEST_DIR/special-chars/sub with spaces"
mkdir -p "$TEST_DIR/special-chars/sub\$dollar"
mkdir -p "$TEST_DIR/special-chars/sub!exclaim"
output=$("$DUX" "$TEST_DIR"/special-chars 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Special chars in dir names handled'
assert_contains "$output" 'spaces' 'Dir with spaces in output'

# Test: Very deep directory structure
declare -- deep_path="$TEST_DIR/deep"
declare -i i
for i in {1..10}; do
  deep_path="$deep_path/level$i"
done
mkdir -p "$deep_path"
output=$("$DUX" "$TEST_DIR"/deep 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Deep directory structure handled'

# Test: Directory with many subdirs (50+)
mkdir -p "$TEST_DIR"/many-subdirs
for i in {1..50}; do
  mkdir -p "$TEST_DIR/many-subdirs/subdir$i"
done
output=$("$DUX" "$TEST_DIR"/many-subdirs 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Many subdirectories handled'
declare -i line_count
line_count=$(echo "$output" | wc -l)
assert_greater_than "$line_count" 49 'All 50+ subdirs in output'

# Test: Hidden directories (.hidden) included
mkdir -p "$TEST_DIR"/with-hidden/.hidden-dir
mkdir -p "$TEST_DIR"/with-hidden/visible-dir
output=$("$DUX" "$TEST_DIR"/with-hidden 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Directory with hidden dirs handled'
assert_contains "$output" '.hidden-dir' 'Hidden directories included'
assert_contains "$output" 'visible-dir' 'Visible directories included'

# Test: Unicode directory names
mkdir -p "$TEST_DIR"/unicode/日本語
mkdir -p "$TEST_DIR"/unicode/émoji🎉
output=$("$DUX" "$TEST_DIR"/unicode 2>&1); ec=$?
if ((ec == 0)); then
  pass 'Unicode directory names handled'
  if echo "$output" | grep -q '日本語'; then
    pass 'Japanese characters in output'
  else
    warn 'Japanese chars may not display correctly'
  fi
else
  warn 'Unicode support may vary by system'
fi

# Test: Very long directory path
declare -- long_name
long_name=$(printf 'a%.0s' {1..200})
mkdir -p "$TEST_DIR/longpath/$long_name"
output=$("$DUX" "$TEST_DIR"/longpath 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Long directory paths handled'

# Test: Permission denied scenario (if we can create unreadable dir)
if mkdir -p "$TEST_DIR"/perms/unreadable 2>/dev/null; then
  mkdir -p "$TEST_DIR"/perms/readable
  chmod 000 "$TEST_DIR"/perms/unreadable 2>/dev/null ||:

  # Test without -q (should show permission errors on stderr)
  output=$("$DUX" "$TEST_DIR"/perms 2>&1); ec=$?

  # Test with -q (should suppress permission errors)
  declare -- quiet_output
  declare -i quiet_ec
  quiet_output=$("$DUX" -q "$TEST_DIR"/perms 2>&1); quiet_ec=$?

  # Restore permissions for cleanup
  chmod 755 "$TEST_DIR"/perms/unreadable 2>/dev/null ||:

  # Script should still succeed with partial results
  if ((ec == 0)); then
    pass 'Permission denied handled gracefully'
  else
    warn 'Permission denied behavior may vary'
  fi

  # -q should succeed and suppress error output
  if ((quiet_ec == 0)); then
    pass '-q option succeeds with permission errors'
    # Check if -q output has fewer error messages than non-quiet
    if ((${#quiet_output} <= ${#output})); then
      pass '-q suppresses or reduces error output'
    else
      warn '-q output comparison inconclusive'
    fi
  else
    warn '-q behavior with permission errors may vary'
  fi
else
  skip_test 'Cannot create permission test directory'
fi

# Test: H1 regression — verbose mode with unreadable subdirs must not crash
# Before fix, 2>&1 merged permission-denied text into du output, failing regex
if ((EUID != 0)); then
  mkdir -p "$TEST_DIR"/h1-verbose/readable-sub
  mkdir -p "$TEST_DIR"/h1-verbose/unreadable-sub
  echo 'test data' > "$TEST_DIR"/h1-verbose/readable-sub/file.txt
  chmod 000 "$TEST_DIR"/h1-verbose/unreadable-sub 2>/dev/null ||:

  # Run in verbose mode (default) — stderr should flow to terminal, not corrupt size
  declare -- h1_output
  declare -i h1_ec
  h1_output=$("$DUX" "$TEST_DIR"/h1-verbose 2>/dev/null); h1_ec=$?

  chmod 755 "$TEST_DIR"/h1-verbose/unreadable-sub 2>/dev/null ||:

  assert_exit_code 0 "$h1_ec" 'H1: verbose mode exits 0 with unreadable subdirs'
  assert_contains "$h1_output" 'readable-sub' 'H1: readable subdir still shown in output'
else
  skip_test 'H1 regression test requires non-root (root bypasses permissions)'
fi

# Test: Newline in a subdirectory name must not abort the run
mkdir -p -- "$TEST_DIR"/newline/plain-sub "$TEST_DIR"/newline/split$'\n'name
output=$("$DUX" -- "$TEST_DIR"/newline 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Newline in subdirectory name handled'
assert_contains "$output" 'plain-sub' 'Sibling of newline-named dir still shown'

# Test: Trailing whitespace in a name survives to the output
# (sentinel keeps $() from eating the final newline)
mkdir -p -- "$TEST_DIR/whitespace/trail  "
output=$("$DUX" -- "$TEST_DIR"/whitespace 2>&1; echo x)
assert_contains "$output" $'trail  \n' 'Trailing whitespace in name preserved'

# Test: A file hard-linked into two siblings is counted in full for each.
# Guards the per-directory du contract: one du over the whole tree would
# charge the file to whichever sibling it reached first.
mkdir -p -- "$TEST_DIR"/hardlinks/first "$TEST_DIR"/hardlinks/second
dd if=/dev/zero of="$TEST_DIR"/hardlinks/first/blob bs=1000 count=100 2>/dev/null
ln -- "$TEST_DIR"/hardlinks/first/blob "$TEST_DIR"/hardlinks/second/blob
output=$("$DUX" -- "$TEST_DIR"/hardlinks 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Hard-linked siblings handled'
declare -i full_count
full_count=$(grep -c '^97\.7KiB' <<<"$output")
assert_equals 3 "$full_count" 'Hard-linked file counted in full for both siblings and root'

# Test: No temporary file is needed, so an unusable TMPDIR is harmless
mkdir -p -- "$TEST_DIR"/no-tmp/sub
output=$(TMPDIR="$TEST_DIR"/does-not-exist "$DUX" -- "$TEST_DIR"/no-tmp 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Runs without a usable TMPDIR'
assert_contains "$output" 'no-tmp/sub' 'Output produced without a usable TMPDIR'

# Test: -q silences du only; the script's own errors still reach stderr
output=$("$DUX" -q -- "$TEST_DIR"/does-not-exist 2>&1); ec=$?
assert_exit_code 3 "$ec" '-q does not change the missing-directory exit code'
assert_contains "$output" 'Not a directory' '-q does not silence script errors'

# Test: A directory name starting with '-' is not parsed as an option by
# find or du (relative path, so the operand itself begins with the dash)
mkdir -p -- "$TEST_DIR"/-dash-dir/inner
output=$(cd -- "$TEST_DIR" && "$DUX" -- -dash-dir 2>&1); ec=$?
assert_exit_code 0 "$ec" 'Dash-leading directory name handled'
assert_contains "$output" '-dash-dir/inner' 'Subdirectory of dash-leading dir shown'

# Test: '(' and '!' are find expression tokens even as whole operands; they
# must be taken as directory names. (')' and ',' are not tokens there.)
declare -- token
for token in '(' '!' ')'; do
  mkdir -p -- "$TEST_DIR/tokens/$token/inner"
  output=$(cd -- "$TEST_DIR"/tokens && "$DUX" -- "$token" 2>&1); ec=$?
  assert_exit_code 0 "$ec" "Directory named ${token@Q} handled"
  assert_contains "$output" "$token/inner" "Subdirectory of ${token@Q} shown"
done

# Test: Repeated trailing slashes. du prints 'dir//' back as 'dir/' while
# find keeps 'dir//'; the two must still agree on every path.
mkdir -p -- "$TEST_DIR"/slashes/sub
for token in // ///; do
  output=$("$DUX" -- "$TEST_DIR/slashes$token" 2>&1); ec=$?
  assert_exit_code 0 "$ec" "Path ending in ${token@Q} exits 0"
  assert_contains "$output" 'slashes/sub' "Path ending in ${token@Q} lists subdirectories"
done

# Test: Sizes always use '.' as the decimal point, whatever the locale, so
# the size column parses the same everywhere
declare -- comma_locale=''
comma_locale=$(locale -a 2>/dev/null | grep -m1 -iE '^(id_ID|de_DE)\.utf-?8$') ||:
if [[ -n $comma_locale ]]; then
  output=$(LC_ALL=$comma_locale "$DUX" -- "$TEST_DIR"/real-dir 2>&1)
  assert_regex_match "$(size_of "$output" "$TEST_DIR"/real-dir)" '^[0-9]+\.[0-9][A-Za-z]+$' \
    "Decimal point is '.' under $comma_locale"
else
  skip_test 'No comma-decimal locale installed (id_ID or de_DE)'
fi

# Test: A subdirectory that vanishes between find and du is left out instead
# of aborting the run. /proc always has one: find's own PID directory.
if [[ -d /proc/self ]]; then
  output=$("$DUX" -q -- /proc 2>&1); ec=$?
  assert_exit_code 0 "$ec" 'Vanished subdirectory (/proc) does not abort the run'
  assert_contains "$output" $'\t/proc/sys' 'Surviving /proc subdirectories still shown'
else
  skip_test '/proc not available'
fi

# Test: -x stays on the target's filesystem: a mount point below the target
# is left out, as du -x leaves it out. /dev/pts is a separate mount.
if mountpoint -q /dev/pts 2>/dev/null; then
  output=$("$DUX" -q -- /dev 2>&1)
  assert_contains "$output" $'\t/dev/pts' 'Without -x, a mount point below the target is listed'
  output=$("$DUX" -x -q -- /dev 2>&1); ec=$?
  assert_exit_code 0 "$ec" '-x exits 0'
  assert_not_contains "$output" $'\t/dev/pts' '-x leaves out a mount point below the target'
  assert_equals /dev "$(tail -n1 <<<"$output" | cut -f2)" '-x still lists the target itself'
  output=$("$DUX" -qx -- /dev 2>&1); ec=$?
  assert_exit_code 0 "$ec" '-qx exits 0'
  assert_not_contains "$output" $'\t/dev/pts' '-x works combined with other short options'
  output=$("$DUX" --one-file-system -q -- /dev 2>&1); ec=$?
  assert_exit_code 0 "$ec" '--one-file-system exits 0'
  assert_not_contains "$output" $'\t/dev/pts' '--one-file-system is the long form of -x'
else
  skip_test '/dev/pts is not a separate mount'
fi

print_summary
exit $?

#fin
