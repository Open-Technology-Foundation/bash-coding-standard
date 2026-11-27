#!/usr/bin/env bash
# Checks of the project's scripts rather than the locale data: the test
# harness itself, exit codes, and how the installers behave when piped.
# Runs unprivileged: the installer checks rely on being refused root.
set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

declare -- SCRIPT_PATH
SCRIPT_PATH=$(realpath -- "$0")
declare -r SCRIPT_PATH
declare -r SCRIPT_NAME=${SCRIPT_PATH##*/} TESTS_DIR=${SCRIPT_PATH%/*}
declare -r REPO_DIR=${TESTS_DIR%/*}

if [[ -t 1 && -t 2 ]]; then
  declare -r RED=$'\033[0;31m' GREEN=$'\033[0;32m' NC=$'\033[0m'
else
  declare -r RED='' GREEN='' NC=''
fi

declare -i CHECKS_RUN=0 CHECKS_PASSED=0
declare -- WORK_DIR=''

die() {
  local -i code=$1
  local -- msg
  shift
  for msg in "$@"; do >&2 printf '%s: %s\n' "$SCRIPT_NAME" "$msg"; done
  exit "$code"
}

# shellcheck disable=SC2317,SC2329 # invoked via trap
cleanup() {
  local -i exitcode=${1:-$?}
  trap - EXIT
  [[ -z $WORK_DIR ]] || rm -rf -- "$WORK_DIR"
  exit "$exitcode"
}

# expect_rc DESCRIPTION RC COMMAND [ARG...]
# Passes when COMMAND exits with status RC. On failure, shows the tail of
# the command's output so the reason is visible without a rerun.
expect_rc() {
  local -- description=$1 output
  local -i expected=$2 actual=0
  shift 2
  CHECKS_RUN+=1
  output=$("$@" 2>&1 </dev/null) || actual=$?
  if ((actual == expected)); then
    CHECKS_PASSED+=1
    printf '%sPASS%s %s\n' "$GREEN" "$NC" "$description"
  else
    printf '%sFAIL%s %s: exit %d, expected %d\n' "$RED" "$NC" "$description" "$actual" "$expected"
    [[ -z $output ]] || tail -n 5 <<<"$output" | sed 's/^/  /'
  fi
}

# Predicates for expect_rc; each returns 0 when the script behaves.
exists()  { [[ -e $1 ]]; }
is_file() { [[ -f $1 ]]; }

# Piped into bash, as documented, $0 is "bash"; the script must still name itself.
names_itself_when_piped() {
  local -- out
  # The exit status is checked by other checks; only the output matters here
  out=$(bash < "$1" 2>&1) ||:
  grep -q -- "^$1: " <<<"$out"
}

# Half a script must run nothing, not even the root check.
runs_nothing_when_cut_off() {
  local -- out
  local -i size
  size=$(stat -c %s -- "$1") || return 2
  # A syntax error at the cut is the expected outcome, so its status is ignored
  out=$(head -c "$((size / 2))" -- "$1" | bash 2>&1) ||:
  ! grep -q -- 'must be run as root' <<<"$out"
}

# The suite must test the build it is given, even where en_ID is installed.
check_test_harness() {
  local -- mutant=$WORK_DIR/mutant nobuild=$WORK_DIR/nobuild
  mkdir -p -- "$mutant" "$nobuild" || die 5 "Failed to create ${mutant@Q} and ${nobuild@Q}"
  cp -R -- Makefile localedata tests "$mutant"/ || die 5 "Failed to copy the tree to ${mutant@Q}"
  sed -i -- 's/^currency_symbol .*/currency_symbol       "XX"/' "$mutant"/localedata/en_ID \
    || die 5 "Failed to mutate ${mutant@Q}/localedata/en_ID"
  make -s -C "$mutant" compile >/dev/null || die 1 "Failed to compile the mutant in ${mutant@Q}"
  expect_rc 'suite fails when the source is wrong' 1 "$mutant"/tests/test_en_ID.sh LC_MONETARY

  cp -R -- tests "$nobuild"/ || die 5 "Failed to copy tests/ to ${nobuild@Q}"
  expect_rc 'suite reports a missing build' 3 "$nobuild"/tests/test_en_ID.sh
  expect_rc 'unknown category is an argument error' 22 tests/test_en_ID.sh LC_BOGUS
}

# make must behave the same from any directory, and DESTDIR must stage.
check_makefile() {
  local -- elsewhere=$WORK_DIR/elsewhere stage=$WORK_DIR/stage
  mkdir -p -- "$elsewhere" || die 5 "Failed to create ${elsewhere@Q}"
  expect_rc 'make compiles from another directory' 0 \
    make -s -C "$elsewhere" -f "$REPO_DIR"/Makefile compile
  expect_rc 'no stray build directory is left there' 1 exists "$elsewhere"/build
  expect_rc 'staged install writes only under DESTDIR' 0 make -s DESTDIR="$stage" install
  expect_rc 'staged install placed the source' 0 is_file "$stage"/usr/share/i18n/locales/en_ID
}

# Scripts that change the system must refuse to run when they should not.
check_refusals() {
  expect_rc 'install test refuses without the opt-in variable' 22 tests/test_install.sh
  expect_rc 'install test refuses without root' 13 env EN_ID_TEST_DISPOSABLE=1 tests/test_install.sh
  expect_rc 'ensure-persistence needs root' 13 ./ensure-persistence.sh
  expect_rc 'uninstall needs root' 13 ./uninstall.sh
}

# The documented install pipes an installer into 'sudo bash'.
check_installers() {
  local -- f
  for f in install-ubuntu.sh install-fedora.sh install-arch.sh; do
    expect_rc "$f needs root" 13 bash -- "$f"
    expect_rc "$f rejects a plain-http source" 22 \
      env EN_ID_REPO_URL=http://example.org/x.git bash -- "$f"
    expect_rc "$f names itself when piped" 0 names_itself_when_piped "$f"
    expect_rc "$f does nothing when cut off" 0 runs_nothing_when_cut_off "$f"
  done
}

main() {
  ((EUID)) || die 1 'Run as an ordinary user: the installer checks rely on being refused root'
  cd -- "$REPO_DIR" || die 3 "Cannot enter ${REPO_DIR@Q}"
  trap 'cleanup $?' EXIT
  WORK_DIR=$(mktemp -d) || die 5 'Failed to create a temporary directory'

  check_test_harness
  check_makefile
  check_refusals
  check_installers

  printf 'Checks passed: %d of %d\n' "$CHECKS_PASSED" "$CHECKS_RUN"
  ((CHECKS_PASSED == CHECKS_RUN)) || exit 1
}

main "$@"
#fin
