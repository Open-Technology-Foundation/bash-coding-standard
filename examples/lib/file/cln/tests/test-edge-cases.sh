#!/usr/bin/env bash
# Test edge cases for cln
set -euo pipefail
shopt -s inherit_errexit

declare -r SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

declare -r CLN="$SCRIPT_DIR/../cln"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_nonexistent_path() {
  test_section "Non-Existent Path Handling"

  local output exit_code=0

  output=$("$CLN" -P /nonexistent/path/xyz 2>&1) || exit_code=$?

  assert_success $exit_code "Exits 0 (skips invalid paths)"
  assert_contains "$output" "not a directory" "Warns about invalid path"
  assert_contains "$output" "Skipping" "Shows skipping message"
}

test_file_instead_of_dir() {
  test_section "File Instead of Directory"

  local temp_file output exit_code=0
  temp_file=$(mktemp)
  trap "rm -f '$temp_file'" RETURN

  output=$("$CLN" -P "$temp_file" 2>&1) || exit_code=$?

  assert_success $exit_code "Exits 0 (skips files)"
  assert_contains "$output" "not a directory" "Warns about file"
}

test_empty_directory() {
  test_section "Empty Directory"

  local temp_dir output exit_code=0
  temp_dir=$(mktemp -d)
  trap "rm -rf '$temp_dir'" RETURN

  output=$("$CLN" -P "$temp_dir" 2>&1) || exit_code=$?

  assert_success $exit_code "Empty directory exits 0"
  assert_contains "$output" "No matching files" "Shows no matches"
}

test_spaces_in_path() {
  test_section "Spaces in Path"

  local temp_dir
  temp_dir=$(mktemp -d)
  trap "rm -rf '$temp_dir'" RETURN

  mkdir -p "$temp_dir/path with spaces"
  touch "$temp_dir/path with spaces/file~"

  "$CLN" -Pq "$temp_dir/path with spaces" 2>/dev/null || true

  if [[ ! -f "$temp_dir/path with spaces/file~" ]]; then
    pass "Handles spaces in path"
  else
    fail "Failed to clean path with spaces"
  fi
}

test_special_characters() {
  test_section "Special Characters in Filenames"

  local temp_dir
  temp_dir=$(mktemp -d)
  trap "rm -rf '$temp_dir'" RETURN

  # Create files with special chars (that match patterns)
  touch "$temp_dir/file with spaces~"
  touch "$temp_dir/file-with-dash~"
  touch "$temp_dir/file.with.dots~"

  "$CLN" -Pq "$temp_dir" 2>/dev/null || true

  [[ ! -f "$temp_dir/file with spaces~" ]] && pass "Handles spaces in filename" || fail "spaces in filename failed"
  [[ ! -f "$temp_dir/file-with-dash~" ]] && pass "Handles dashes in filename" || fail "dashes in filename failed"
  [[ ! -f "$temp_dir/file.with.dots~" ]] && pass "Handles dots in filename" || fail "dots in filename failed"
}

test_symlink_option() {
  test_section "Symlink Following (-L)"

  local temp_dir target_dir
  temp_dir=$(mktemp -d)
  target_dir=$(mktemp -d)
  trap "rm -rf '$temp_dir' '$target_dir'" RETURN

  # Create symlink to target
  touch "$target_dir/file~"
  ln -s "$target_dir" "$temp_dir/link"

  # Without -L, should not follow symlinks
  "$CLN" -Pq "$temp_dir" 2>/dev/null || true
  if [[ -f "$target_dir/file~" ]]; then
    pass "Without -L, symlink target untouched"
  else
    fail "Without -L, should not follow symlinks"
  fi

  # Re-create file
  touch "$target_dir/file~"

  # With -L, should follow symlinks
  "$CLN" -Pq -L "$temp_dir" 2>/dev/null || true
  if [[ ! -f "$target_dir/file~" ]]; then
    pass "With -L, follows symlinks"
  else
    fail "With -L, should follow symlinks"
  fi
}

test_default_path() {
  test_section "Default Path (.)"

  local temp_dir output exit_code=0
  temp_dir=$(mktemp -d)
  trap "rm -rf '$temp_dir'" RETURN

  touch "$temp_dir/file~"

  # Run from temp_dir without specifying path
  output=$(cd "$temp_dir" && "$CLN" -P 2>&1) || exit_code=$?

  assert_success $exit_code "Default path exits 0"
  [[ ! -f "$temp_dir/file~" ]] && pass "Default path (.) works" || fail "Default path should clean current dir"
}

test_verbose_cap() {
  test_section "Verbose Level Cap"

  local output exit_code=0

  # Multiple -v flags should cap at 3
  output=$("$CLN" -h 2>&1) || exit_code=$?
  # Default VERBOSE is 1, with -vvv it should be 3

  # Just verify the option is accepted without error
  exit_code=0
  "$CLN" -vvvvv --help >/dev/null 2>&1 || exit_code=$?
  assert_success $exit_code "Multiple -v flags accepted"
}

test_mixed_valid_invalid_paths() {
  test_section "Mixed Valid/Invalid Paths"

  local temp_dir output exit_code=0
  temp_dir=$(mktemp -d)
  trap "rm -rf '$temp_dir'" RETURN

  touch "$temp_dir/file~"

  # Mix of valid and invalid paths
  output=$("$CLN" -P /nonexistent "$temp_dir" /also-nonexistent 2>&1) || exit_code=$?

  assert_success $exit_code "Continues despite invalid paths"
  [[ ! -f "$temp_dir/file~" ]] && pass "Valid path still cleaned" || fail "Valid path should still be cleaned"
}

test_expression_named_directories() {
  test_section "Directories Named Like find Expressions"

  local -- temp_dir=''
  local -i exit_code=0
  # runs at this function's return, while temp_dir is still in scope, then clears itself
  trap '[[ -z ${temp_dir:-} ]] || rm -rf -- "$temp_dir"; trap - RETURN' RETURN
  temp_dir=$(mktemp -d) || { fail 'Cannot create a temp directory'; return 0; }

  mkdir -- "$temp_dir"/-delete "$temp_dir"/!
  touch -- "$temp_dir"/keep.txt "$temp_dir"/-delete/keep.txt "$temp_dir"/-delete/file~ "$temp_dir"/!/file~

  # find reads a starting point that begins with '-' or is '!' as part of its
  # expression; '-delete' once emptied the whole current directory
  (cd -- "$temp_dir" && "$CLN" -P -- '!') >/dev/null 2>&1 || exit_code=$?
  assert_success "$exit_code" "Directory named ! exits 0"
  if [[ ! -f $temp_dir/!/file~ ]]; then pass "Matching file in ! removed"; else fail "Matching file in ! should be removed"; fi

  exit_code=0
  (cd -- "$temp_dir" && "$CLN" -P -- -delete) >/dev/null 2>&1 || exit_code=$?
  assert_success "$exit_code" "Directory named -delete exits 0"
  if [[ -f $temp_dir/keep.txt ]]; then pass "Current directory untouched"; else fail "Files outside the named directory were deleted"; fi
  if [[ -f $temp_dir/-delete/keep.txt ]]; then pass "Non-matching file in -delete kept"; else fail "Non-matching file in -delete was deleted"; fi
  if [[ ! -f $temp_dir/-delete/file~ ]]; then pass "Matching file in -delete removed"; else fail "Matching file in -delete should be removed"; fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Run tests
test_nonexistent_path
test_file_instead_of_dir
test_empty_directory
test_spaces_in_path
test_special_characters
test_symlink_option
test_default_path
test_verbose_cap
test_mixed_valid_invalid_paths
test_expression_named_directories

# Print summary
print_summary
#fin
