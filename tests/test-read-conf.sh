#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-read-conf.sh - Unit tests for read_conf()
#
# Overrides _conf_search_paths to point at test fixtures, verifies
# cascade precedence (user overrides system), and exercises the
# world/group-writable permission warning.

set -euo pipefail
shopt -s inherit_errexit
# bcs is sourced below and leaves PATH to its caller (BCS1002), so the suite
# sets the value an executed bcs would.
declare -rx PATH=~/.local/bin:/usr/local/bin:/usr/bin:/bin

#shellcheck source=tests/test-helpers.sh
source "$(dirname "$0")"/test-helpers.sh
#shellcheck source=bcs
source "$BCS_CMD"   # source guard keeps main() from running

echo 'Testing: read_conf'

# Fixture layout: two conf files; system first, user second.
declare -- FIXTURE_ROOT
FIXTURE_ROOT=$(mktemp -d) || { echo 'mktemp failed' >&2; exit 1; }
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

declare -- SYS_CONF="$FIXTURE_ROOT"/system.conf
declare -- USR_CONF="$FIXTURE_ROOT"/user.conf

# Override to use only our two fixtures (we keep the array small for
# cascade tests; the real cascade has four levels).
_conf_search_paths() {
  printf '%s\n' "$SYS_CONF" "$USR_CONF"
}

# --- Single-file loading ------------------------------------------------

begin_test 'single file: variable assigned'
: > "$SYS_CONF"
cat > "$USR_CONF" <<'EOF'
BCS_TEST_VAR=hello
EOF
chmod 600 "$USR_CONF"
unset BCS_TEST_VAR
read_conf 2>/dev/null
assert_equal hello "${BCS_TEST_VAR:-UNSET}"

begin_test 'multiple variables in single file'
: > "$SYS_CONF"
cat > "$USR_CONF" <<'EOF'
BCS_TEST_VAR_A=alpha
BCS_TEST_VAR_B=beta
EOF
chmod 600 "$USR_CONF"
unset BCS_TEST_VAR_A BCS_TEST_VAR_B
read_conf 2>/dev/null
assert_equal alpha "${BCS_TEST_VAR_A:-UNSET}" 'var A loaded'
assert_equal beta  "${BCS_TEST_VAR_B:-UNSET}" 'var B loaded'

# --- Cascade precedence (user overrides system) -------------------------

begin_test 'user overrides system'
cat > "$SYS_CONF" <<'EOF'
BCS_TEST_MODEL=system-default
EOF
cat > "$USR_CONF" <<'EOF'
BCS_TEST_MODEL=user-override
EOF
chmod 600 "$SYS_CONF" "$USR_CONF"
unset BCS_TEST_MODEL
read_conf 2>/dev/null
assert_equal user-override "${BCS_TEST_MODEL:-UNSET}" 'user value wins'

begin_test 'system values persist when user does not override'
cat > "$SYS_CONF" <<'EOF'
BCS_TEST_MODEL=system-default
BCS_TEST_EFFORT=high
EOF
cat > "$USR_CONF" <<'EOF'
BCS_TEST_MODEL=user-override
EOF
chmod 600 "$SYS_CONF" "$USR_CONF"
unset BCS_TEST_MODEL BCS_TEST_EFFORT
read_conf 2>/dev/null
assert_equal user-override "${BCS_TEST_MODEL:-UNSET}"  'overridden'
assert_equal high          "${BCS_TEST_EFFORT:-UNSET}" 'system value persists'

# --- Missing files ------------------------------------------------------

begin_test 'no files: read_conf returns non-zero'
rm -f "$SYS_CONF" "$USR_CONF"
if read_conf 2>/dev/null; then
  TESTS_FAILED+=1
  printf '  %s✗%s should have returned non-zero\n' "$RED" "$NC"
else
  TESTS_PASSED+=1
  printf '  %s✓%s returns non-zero when no files present\n' "$GREEN" "$NC"
fi

begin_test 'missing file skipped silently'
: > "$SYS_CONF"
rm -f "$USR_CONF"
cat > "$SYS_CONF" <<'EOF'
BCS_TEST_SINGLE=only
EOF
chmod 600 "$SYS_CONF"
unset BCS_TEST_SINGLE
read_conf 2>/dev/null
assert_equal only "${BCS_TEST_SINGLE:-UNSET}" 'system loaded despite missing user'

# --- Permission warning ------------------------------------------------

begin_test '600 mode: no warning'
: > "$SYS_CONF"
cat > "$USR_CONF" <<'EOF'
BCS_TEST_MODE_CHECK=present
EOF
chmod 600 "$USR_CONF"
err=$(read_conf 2>&1 1>/dev/null)
assert_not_contains "$err" 'permissive mode' '600 is silent'

begin_test '644 mode: no warning (group/others read-only)'
: > "$SYS_CONF"
cat > "$USR_CONF" <<'EOF'
BCS_TEST_MODE_CHECK=present
EOF
chmod 644 "$USR_CONF"
err=$(read_conf 2>&1 1>/dev/null)
assert_not_contains "$err" 'permissive mode' '644 is silent'

begin_test '664 mode: warning (group-writable)'
: > "$SYS_CONF"
cat > "$USR_CONF" <<'EOF'
BCS_TEST_MODE_CHECK=present
EOF
chmod 664 "$USR_CONF"
err=$(read_conf 2>&1 1>/dev/null)
assert_contains "$err" 'group-writable' '664 warns'

# World-writable modes now cause read_conf to die. Run in a subshell so
# the exit doesn't kill the test script.
begin_test '666 mode: read_conf dies (world-writable)'
: > "$SYS_CONF"
cat > "$USR_CONF" <<'EOF'
BCS_TEST_MODE_CHECK=present
EOF
chmod 666 "$USR_CONF"
if ( read_conf ) 2>"$FIXTURE_ROOT"/err.log; then
  TESTS_FAILED+=1
  printf '  %s✗%s should have died on world-writable 666\n' "$RED" "$NC"
else
  err=$(< "$FIXTURE_ROOT"/err.log)
  if [[ $err == *'refusing to source'* ]]; then
    TESTS_PASSED+=1
    printf '  %s✓%s 666 dies with refusing-to-source message\n' "$GREEN" "$NC"
  else
    TESTS_FAILED+=1
    printf '  %s✗%s 666 died but wrong message: %s\n' "$RED" "$NC" "$err"
  fi
fi

begin_test '777 mode: read_conf dies (fully open)'
: > "$SYS_CONF"
cat > "$USR_CONF" <<'EOF'
BCS_TEST_MODE_CHECK=present
EOF
chmod 777 "$USR_CONF"
if ( read_conf ) 2>"$FIXTURE_ROOT"/err.log; then
  TESTS_FAILED+=1
  printf '  %s✗%s should have died on world-writable 777\n' "$RED" "$NC"
else
  err=$(< "$FIXTURE_ROOT"/err.log)
  if [[ $err == *'refusing to source'* ]]; then
    TESTS_PASSED+=1
    printf '  %s✓%s 777 dies with refusing-to-source message\n' "$GREEN" "$NC"
  else
    TESTS_FAILED+=1
    printf '  %s✗%s 777 died but wrong message: %s\n' "$RED" "$NC" "$err"
  fi
fi

begin_test '706 mode: read_conf dies (others-writable without group)'
: > "$SYS_CONF"
cat > "$USR_CONF" <<'EOF'
BCS_TEST_MODE_CHECK=present
EOF
chmod 706 "$USR_CONF"
if ( read_conf ) 2>"$FIXTURE_ROOT"/err.log; then
  TESTS_FAILED+=1
  printf '  %s✗%s should have died on 706 (last digit 6 is world-writable)\n' "$RED" "$NC"
else
  err=$(< "$FIXTURE_ROOT"/err.log)
  if [[ $err == *'refusing to source'* ]]; then
    TESTS_PASSED+=1
    printf '  %s✓%s 706 dies with refusing-to-source message\n' "$GREEN" "$NC"
  else
    TESTS_FAILED+=1
    printf '  %s✗%s 706 died but wrong message: %s\n' "$RED" "$NC" "$err"
  fi
fi

# The file is sourced as shell. If its mode cannot be read, the permission
# policy above cannot be applied, so the file must not be sourced at all.
begin_test 'unreadable mode: file is not sourced'
: > "$SYS_CONF"
cat > "$USR_CONF" <<'CONF'
BCS_TEST_UNVERIFIED=sourced
CONF
chmod -- 600 "$USR_CONF"
err=$(
  #shellcheck disable=SC2329  # called by read_conf, which shells out to stat
  stat() { return 1; }
  read_conf 2>&1 1>/dev/null ||:
  echo "var=${BCS_TEST_UNVERIFIED:-unset}"
)
assert_contains "$err" 'var=unset' 'stat failure -> conf file not sourced' ||:
assert_contains "$err" 'cannot read its mode' 'stat failure -> the user is told why' ||:

# Reset to known-good mode at end so trap cleanup is quiet.
chmod 600 "$USR_CONF" 2>/dev/null ||:

print_summary 'read-conf'
#fin
