#!/usr/bin/env bats
# test_ls.types.bats - Comprehensive tests for ls.types

# Get the directory where this test file lives
SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
LS_BASH="$SCRIPT_DIR/ls.bash"
LS_PYTHON="$SCRIPT_DIR/ls.python"
LS_PHP="$SCRIPT_DIR/ls.php"
LS_SH="$SCRIPT_DIR/ls.sh"
LS_TYPES="$SCRIPT_DIR/ls.types"

setup() {
  # Create temporary test directory
  TEST_DIR=$(mktemp -d)
  TEST_SUBDIR="$TEST_DIR/subdir"
  TEST_DEEP="$TEST_DIR/subdir/deep"
  TEST_EMPTY="$TEST_DIR/empty"
  TEST_SPACES="$TEST_DIR/dir with spaces"
  # Hermetic user config: the XDG path is searched first, so a real
  # ~/.config/ls.types/types.conf must never leak into a test run.
  export XDG_CONFIG_HOME="$TEST_DIR/xdg"

  mkdir -p "$TEST_SUBDIR" "$TEST_DEEP" "$TEST_EMPTY" "$TEST_SPACES"

  # Bash files
  cat > "$TEST_DIR/script.sh" <<'EOF'
#!/usr/bin/env bash
echo "hello"
EOF

  cat > "$TEST_DIR/script.bash" <<'EOF'
#!/bin/bash
echo "hello"
EOF

  # Bash file without shebang (extension only)
  cat > "$TEST_DIR/noshebang.sh" <<'EOF'
# No shebang, just a comment
echo "hello"
EOF

  # Bash shebang, no extension
  cat > "$TEST_DIR/noext" <<'EOF'
#!/usr/bin/env bash
echo "no extension"
EOF

  # Python file
  cat > "$TEST_DIR/script.py" <<'EOF'
#!/usr/bin/env python3
print("hello")
EOF

  # PHP file
  cat > "$TEST_DIR/script.php" <<'EOF'
#!/usr/bin/env php
<?php echo "hello"; ?>
EOF

  # Non-matching file
  cat > "$TEST_DIR/readme.txt" <<'EOF'
This is a text file
EOF

  # Binary file (with misleading .sh extension)
  printf '\x00\x01\x02\x03' > "$TEST_DIR/binary.sh"

  # Files in subdirectory (for depth testing)
  cat > "$TEST_SUBDIR/sub.sh" <<'EOF'
#!/bin/bash
echo "subdir"
EOF

  cat > "$TEST_DEEP/deep.sh" <<'EOF'
#!/bin/bash
echo "deep"
EOF

  # File in "dir with spaces"
  cat > "$TEST_SPACES/spaced.sh" <<'EOF'
#!/bin/bash
echo "spaces"
EOF

  # Symlink test fixtures
  TEST_SYMLINKS="$TEST_DIR/symlinks"
  mkdir -p "$TEST_SYMLINKS/realdir"

  # Real file and symlinked file
  cat > "$TEST_SYMLINKS/real.sh" <<'EOF'
#!/bin/bash
echo "real"
EOF
  ln -s real.sh "$TEST_SYMLINKS/link.sh"

  # File in real directory
  cat > "$TEST_SYMLINKS/realdir/nested.sh" <<'EOF'
#!/bin/bash
echo "nested"
EOF

  # Symlinked directory
  ln -s realdir "$TEST_SYMLINKS/linkeddir"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# =============================================================================
# Basic Options
# =============================================================================

@test "help: -h shows usage" {
  run "$LS_BASH" -h
  [[ $status -eq 0 ]]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"Options:"* ]]
}

@test "help: --help shows usage" {
  run "$LS_BASH" --help
  [[ $status -eq 0 ]]
  [[ "$output" == *"Usage:"* ]]
}

@test "version: -V shows version" {
  run "$LS_BASH" -V
  [[ $status -eq 0 ]]
  [[ "$output" == "ls.bash 2.1.0" ]]
}

@test "version: --version shows version" {
  run "$LS_BASH" --version
  [[ $status -eq 0 ]]
  [[ "$output" == *"2.1.0"* ]]
}

@test "error: unknown option exits 22" {
  run "$LS_BASH" -X
  [[ $status -eq 22 ]]
  [[ "$output" == *"error"* ]]
  [[ "$output" == *"Unknown option"* ]]
}

@test "symlinks: -S lists symlinks" {
  run "$LS_BASH" -S
  [[ $status -eq 0 ]]
  [[ "$output" == *"Symlinks defined in"* ]]
  [[ "$output" == *"ls.bash"* ]]
}

@test "symlinks: ./ls.types -S works without symlink" {
  run "$LS_TYPES" -S
  [[ $status -eq 0 ]]
  [[ "$output" == *"Symlinks defined in"* ]]
}

@test "maxdepth: -d 2 finds files in subdirs" {
  run "$LS_BASH" -d 2 "$TEST_DIR"
  [[ $status -eq 0 ]]
  [[ "$output" == *"sub.sh"* ]]
}

# =============================================================================
# File Detection
# =============================================================================

@test "detection: finds file by bash shebang" {
  run "$LS_BASH" "$TEST_DIR"
  [[ $status -eq 0 ]]
  [[ "$output" == *"script.sh"* ]]
  [[ "$output" == *"script.bash"* ]]
}

@test "detection: finds file by extension only (no shebang)" {
  run "$LS_BASH" "$TEST_DIR"
  [[ $status -eq 0 ]]
  [[ "$output" == *"noshebang.sh"* ]]
}

@test "detection: finds file by shebang only (no extension)" {
  run "$LS_BASH" "$TEST_DIR"
  [[ $status -eq 0 ]]
  [[ "$output" == *"noext"* ]]
}

@test "detection: does not find non-matching files" {
  run "$LS_BASH" "$TEST_DIR"
  [[ $status -eq 0 ]]
  [[ "$output" != *"readme.txt"* ]]
}

@test "detection: excludes binary files" {
  run "$LS_BASH" "$TEST_DIR"
  [[ $status -eq 0 ]]
  [[ "$output" != *"binary.sh"* ]]
}

@test "detection: ls.python finds python files" {
  run "$LS_PYTHON" "$TEST_DIR"
  [[ $status -eq 0 ]]
  [[ "$output" == *"script.py"* ]]
  [[ "$output" != *"script.sh"* ]]
}

@test "detection: ls.php finds php files" {
  run "$LS_PHP" "$TEST_DIR"
  [[ $status -eq 0 ]]
  [[ "$output" == *"script.php"* ]]
  [[ "$output" != *"script.sh"* ]]
}

# =============================================================================
# Output Modes
# =============================================================================

@test "output: default shows plain filenames" {
  run "$LS_BASH" "$TEST_DIR"
  [[ $status -eq 0 ]]
  # Should contain filename but not ls -l style output
  [[ "$output" == *"script.sh"* ]]
  [[ "$output" != *"rwx"* ]]
}

@test "output: -r shows absolute paths" {
  run "$LS_BASH" -r "$TEST_DIR"
  [[ $status -eq 0 ]]
  # Output should contain absolute paths
  [[ "$output" == *"$TEST_DIR"* ]]
}

@test "output: -l shows ls format" {
  run "$LS_BASH" -l "$TEST_DIR"
  [[ $status -eq 0 ]]
  # ls -l output has permission strings
  [[ "$output" == *"rw"* ]]
}

@test "output: -rl combines realpath and ls" {
  run "$LS_BASH" -rl "$TEST_DIR"
  [[ $status -eq 0 ]]
  # Should have absolute paths in ls format
  [[ "$output" == *"$TEST_DIR"* ]]
  [[ "$output" == *"rw"* ]]
}

# =============================================================================
# Directory Handling
# =============================================================================

@test "directory: defaults to current dir" {
  cd "$TEST_DIR"
  run "$LS_BASH"
  [[ $status -eq 0 ]]
  [[ "$output" == *"script.sh"* ]]
}

@test "directory: accepts single directory" {
  run "$LS_BASH" "$TEST_DIR"
  [[ $status -eq 0 ]]
  [[ "$output" == *"script.sh"* ]]
}

@test "directory: accepts multiple directories" {
  run "$LS_BASH" "$TEST_DIR" "$TEST_SUBDIR"
  [[ $status -eq 0 ]]
  [[ "$output" == *"script.sh"* ]]
  [[ "$output" == *"sub.sh"* ]]
}

@test "directory: errors on invalid directory" {
  run "$LS_BASH" "/nonexistent/path"
  [[ $status -eq 3 ]]
  [[ "$output" == *"error"* ]]
  [[ "$output" == *"Not a directory"* ]]
}

@test "directory: empty dir produces no output" {
  run "$LS_BASH" "$TEST_EMPTY"
  [[ $status -eq 0 ]]
  [[ -z "$output" ]]
}

# =============================================================================
# Symlink Management
# =============================================================================

@test "symlinks: -S list shows status" {
  run "$LS_BASH" -S
  [[ $status -eq 0 ]]
  [[ "$output" == *"[exists]"* ]] || [[ "$output" == *"[missing]"* ]]
}

@test "symlinks: -S create makes symlinks in temp dir" {
  local symlink_dir
  symlink_dir=$(mktemp -d)
  run "$LS_BASH" -S create "$symlink_dir"
  [[ $status -eq 0 ]]
  # Check that at least one symlink was created
  [[ -L "$symlink_dir/ls.bash" ]] || [[ -L "$symlink_dir/ls.python" ]]
  rm -rf "$symlink_dir"
}

@test "symlinks: -S invalid action errors" {
  run "$LS_BASH" -S invalidaction
  [[ $status -eq 22 ]]
  [[ "$output" == *"error"* ]]
  [[ "$output" == *"Unknown action"* ]]
}

@test "symlinks: -S create invalid dir errors" {
  run "$LS_BASH" -S create "/nonexistent/path"
  [[ $status -eq 3 ]]
  [[ "$output" == *"error"* ]]
  [[ "$output" == *"Directory not found"* ]]
}

# =============================================================================
# Symlink Following (-L/--follow)
# =============================================================================

@test "follow: help shows -L option" {
  run "$LS_BASH" -h
  [[ $status -eq 0 ]]
  [[ "$output" == *"-L, --follow"* ]]
  [[ "$output" == *"symbolic links"* ]]
}

@test "follow: default ignores symlinked files" {
  run "$LS_BASH" "$TEST_SYMLINKS"
  [[ $status -eq 0 ]]
  [[ "$output" == *"real.sh"* ]]
  [[ "$output" != *"link.sh"* ]]
}

@test "follow: -L finds symlinked files" {
  run "$LS_BASH" -L "$TEST_SYMLINKS"
  [[ $status -eq 0 ]]
  [[ "$output" == *"real.sh"* ]]
  [[ "$output" == *"link.sh"* ]]
}

@test "follow: --follow finds symlinked files" {
  run "$LS_BASH" --follow "$TEST_SYMLINKS"
  [[ $status -eq 0 ]]
  [[ "$output" == *"link.sh"* ]]
}

@test "follow: default ignores symlinked directories" {
  run "$LS_BASH" -d 2 "$TEST_SYMLINKS"
  [[ $status -eq 0 ]]
  [[ "$output" == *"realdir/nested.sh"* ]]
  [[ "$output" != *"linkeddir/nested.sh"* ]]
}

@test "follow: -L traverses symlinked directories" {
  run "$LS_BASH" -L -d 2 "$TEST_SYMLINKS"
  [[ $status -eq 0 ]]
  [[ "$output" == *"realdir/nested.sh"* ]]
  [[ "$output" == *"linkeddir/nested.sh"* ]]
}

@test "follow: -L2 clustered options work" {
  run "$LS_BASH" -L2 "$TEST_SYMLINKS"
  [[ $status -eq 0 ]]
  [[ "$output" == *"link.sh"* ]]
  [[ "$output" == *"linkeddir/nested.sh"* ]]
}

@test "follow: -Ll combines follow and ls format" {
  run "$LS_BASH" -Ll "$TEST_SYMLINKS"
  [[ $status -eq 0 ]]
  [[ "$output" == *"link.sh"* ]]
  [[ "$output" == *"real.sh"* ]]
  [[ "$output" == *"rw"* ]]
}

# =============================================================================
# Edge Cases
# =============================================================================

@test "edge: handles paths with spaces" {
  run "$LS_BASH" "$TEST_SPACES"
  [[ $status -eq 0 ]]
  [[ "$output" == *"spaced.sh"* ]]
}

@test "edge: no matching files produces no output" {
  # Create dir with only non-matching files
  local nomatch_dir
  nomatch_dir=$(mktemp -d)
  echo "text" > "$nomatch_dir/file.txt"
  run "$LS_BASH" "$nomatch_dir"
  [[ $status -eq 0 ]]
  [[ -z "$output" ]]
  rm -rf "$nomatch_dir"
}

@test "edge: unreadable file is skipped" {
  local unread_dir
  unread_dir=$(mktemp -d)
  cat > "$unread_dir/unreadable.sh" <<'EOF'
#!/bin/bash
echo "unreadable"
EOF
  chmod 000 "$unread_dir/unreadable.sh"
  run "$LS_BASH" "$unread_dir"
  [[ $status -eq 0 ]]
  [[ "$output" != *"unreadable.sh"* ]]
  chmod 644 "$unread_dir/unreadable.sh"
  rm -rf "$unread_dir"
}

@test "edge: -d 3 finds deeply nested files" {
  run "$LS_BASH" -d 3 "$TEST_DIR"
  [[ $status -eq 0 ]]
  [[ "$output" == *"deep.sh"* ]]
}

@test "edge: -d without argument exits 22" {
  run "$LS_BASH" -d
  [[ $status -eq 22 ]]
  [[ "$output" == *"requires an argument"* ]]
}

@test "edge: -d with non-numeric argument exits 22" {
  run "$LS_BASH" -d abc
  [[ $status -eq 22 ]]
  [[ "$output" == *"numeric"* ]]
}

@test "edge: -- stops option parsing" {
  run "$LS_BASH" -- "$TEST_DIR"
  [[ $status -eq 0 ]]
  [[ "$output" == *"script.sh"* ]]
}

@test "edge: -3abc numeric shorthand rejects non-numeric" {
  run "$LS_BASH" -3abc "$TEST_DIR"
  [[ $status -eq 22 ]]
  [[ "$output" == *"Invalid numeric option"* ]]
}

# =============================================================================
# Dash-leading / expression-like DIR operands (find takes no '--')
# Each test runs inside its own dir under TEST_DIR: a regression would make
# find run '-delete' on the current directory, so it must be disposable.
# =============================================================================

# Fixture: CWD holds a dir named $1 containing a bash script, plus a sentinel.
_dash_fixture() {
  DASH_CWD="$TEST_DIR/dashcwd"
  mkdir -p -- "$DASH_CWD/$1"
  printf '#!/bin/bash\necho x\n' > "$DASH_CWD/$1/dash.sh"
  touch "$DASH_CWD/sentinel"
  cd "$DASH_CWD"
}

@test "edge: dir named -delete is a start point, not a find action" {
  _dash_fixture -delete
  run "$LS_BASH" -- -delete
  [[ $status -eq 0 ]]
  [[ "$output" == "./-delete/dash.sh" ]]
  [[ -e "$DASH_CWD/sentinel" ]]
  [[ -e "$DASH_CWD/-delete/dash.sh" ]]
}

@test "edge: dir named -delete with -r is a start point, not a find action" {
  _dash_fixture -delete
  run "$LS_BASH" -r -- -delete
  [[ $status -eq 0 ]]
  [[ "$output" == "$(realpath -- "$DASH_CWD")/-delete/dash.sh" ]]
  [[ -e "$DASH_CWD/sentinel" ]]
  [[ -e "$DASH_CWD/-delete/dash.sh" ]]
}

@test "edge: dir named ! is a start point, not find negation" {
  _dash_fixture '!'
  run "$LS_BASH" '!'
  [[ $status -eq 0 ]]
  [[ "$output" == "./!/dash.sh" ]]
}

@test "directory: relative dir output is ./-prefixed; . is not doubled" {
  cd "$TEST_DIR"
  run "$LS_BASH" subdir
  [[ $status -eq 0 ]]
  [[ "$output" == "./subdir/sub.sh" ]]
  run "$LS_BASH" .
  [[ "$output" == *"./script.sh"* && "$output" != *"././"* ]]
  run "$LS_BASH" ./subdir
  [[ "$output" == "./subdir/sub.sh" ]]
}

# =============================================================================
# -d takes its argument as the next word only (BCS0801: no attached arguments)
# =============================================================================

@test "maxdepth: -d2 glued form is rejected with exit 22" {
  run "$LS_BASH" -d2 "$TEST_DIR"
  [[ $status -eq 22 ]]
  [[ "$output" == *"Unknown option"* ]]
}

@test "maxdepth: -rd2 glued within cluster is rejected with exit 22" {
  run "$LS_BASH" -rd2 "$TEST_DIR"
  [[ $status -eq 22 ]]
  [[ "$output" == *"Unknown option"* ]]
}

@test "maxdepth: -rd 2 cluster ending in -d takes the next word" {
  run "$LS_BASH" -rd 2 "$TEST_DIR"
  [[ $status -eq 0 ]]
  [[ "$output" == *"$TEST_DIR"* ]]
  [[ "$output" == *"sub.sh"* ]]
}

# =============================================================================
# -S list DIR honours target_dir (regression for A2, #2)
# =============================================================================

@test "symlinks: -S list DIR reflects that dir, not SCRIPT_DIR" {
  local d
  d=$(mktemp -d)
  ln -s "$LS_TYPES" "$d/ls.bash"   # only ls.bash present in this dir
  run "$LS_BASH" -S list "$d"
  [[ $status -eq 0 ]]
  [[ "$output" == *"Symlinks defined in $d"* ]]
  [[ "$output" == *"[exists]"* ]]
  # SCRIPT_DIR has every symlink; a [missing] proves $d was read, not SCRIPT_DIR
  [[ "$output" == *"[missing]"* ]]
  rm -rf "$d"
}

# =============================================================================
# ls.sh dispatch and sh/bash boundary (#5)
# =============================================================================

@test "detection: ls.sh finds /bin/sh shebang files" {
  local d
  d=$(mktemp -d)
  printf '#!/bin/sh\necho posix\n' > "$d/posix.sh"
  run "$LS_SH" "$d"
  [[ $status -eq 0 ]]
  [[ "$output" == *"posix.sh"* ]]
  rm -rf "$d"
}

@test "detection: ls.sh lists .sh bash files via extension boundary" {
  # script.sh carries a bash shebang; ls.sh's '/bin/sh' pattern does NOT match it,
  # but the 'sh' extension does -> it is listed (documented boundary behaviour).
  run "$LS_SH" "$TEST_DIR"
  [[ $status -eq 0 ]]
  [[ "$output" == *"script.sh"* ]]
}

# =============================================================================
# Unknown symlink name and direct invocation (#25, #26)
# =============================================================================

@test "error: unknown symlink name exits 19" {
  local d
  d=$(mktemp -d)
  ln -s "$LS_TYPES" "$d/ls.nonexistent"
  run "$d/ls.nonexistent" "$TEST_DIR"
  [[ $status -eq 19 ]]
  [[ "$output" == *"Unknown symlink"* ]]
  rm -rf "$d"
}

@test "direct: ./ls.types -V shows version" {
  run "$LS_TYPES" -V
  [[ $status -eq 0 ]]
  [[ "$output" == *"2.1.0"* ]]
}

@test "direct: ./ls.types -h shows generic help" {
  run "$LS_TYPES" -h
  [[ $status -eq 0 ]]
  [[ "$output" == *"Usage:"* ]]
}

@test "direct: ./ls.types with no args exits 22 with help" {
  run "$LS_TYPES"
  [[ $status -eq 22 ]]
  [[ "$output" == *"Usage:"* ]]
}

@test "direct: ./ls.types with unsupported option exits 22 and names it" {
  run "$LS_TYPES" -x
  [[ $status -eq 22 ]]
  [[ "$output" == *"Unsupported option '-x'"* ]]
}

# =============================================================================
# Config search: XDG user config first; paths shown in help; -E seeding
# =============================================================================

@test "config: XDG user config overrides system config" {
  mkdir -p "$XDG_CONFIG_HOME/ls.types"
  printf 'ls.bash:Bash:nomatchzz:zzz\n' > "$XDG_CONFIG_HOME/ls.types/types.conf"
  printf 'text\n' > "$TEST_DIR/only.zzz"
  run "$LS_BASH" "$TEST_DIR"
  [[ $status -eq 0 ]]
  [[ "$output" == "$TEST_DIR/only.zzz" ]]
}

@test "help: -h lists config search paths and the one in use" {
  run "$LS_BASH" -h
  [[ $status -eq 0 ]]
  [[ "$output" == *"Config (first readable file wins; in use: "* ]]
  [[ "$output" == *"$XDG_CONFIG_HOME/ls.types/types.conf"* ]]
  [[ "$output" == *"/etc/ls.types/types.conf"* ]]
}

@test "edit: -E seeds a new XDG config from the active config" {
  run bash -c 'printf "1\nn\n" | EDITOR=true "$1" -E' _ "$LS_BASH"
  [[ $status -eq 0 ]]
  [[ -f "$XDG_CONFIG_HOME/ls.types/types.conf" ]]
  grep -q '^ls.bash:' "$XDG_CONFIG_HOME/ls.types/types.conf"
}

@test "edit: -E on an unwritable config exits 13" {
  ((EUID)) || skip "root can write read-only files"
  mkdir -p "$XDG_CONFIG_HOME/ls.types"
  printf 'ls.bash:Bash:bash:sh,bash\n' > "$XDG_CONFIG_HOME/ls.types/types.conf"
  chmod 444 "$XDG_CONFIG_HOME/ls.types/types.conf"
  run bash -c 'printf "1\n" | EDITOR=true "$1" -E' _ "$LS_BASH"
  [[ $status -eq 13 ]]
  [[ "$output" == *"Cannot write to"* ]]
}

@test "output: -l into a pipe carries no ANSI colour escapes" {
  run "$LS_BASH" -l "$TEST_DIR"
  [[ $status -eq 0 ]]
  [[ "$output" == *"script.sh"* ]]
  [[ "$output" != *$'\e['* ]]
}

# =============================================================================
# Newline-in-filename safety (regression for B2, #11)
# =============================================================================

@test "edge: newline in filename is handled safely" {
  local d
  d=$(mktemp -d)
  local fn=$'line1\nline2.sh'
  printf '#!/bin/bash\necho x\n' > "$d/$fn" 2>/dev/null \
    || { rm -rf "$d"; skip "filesystem rejects newline in filename"; }
  run "$LS_BASH" "$d"
  [[ $status -eq 0 ]]
  [[ "$output" == *"line2.sh"* ]]
  rm -rf "$d"
}

#fin
