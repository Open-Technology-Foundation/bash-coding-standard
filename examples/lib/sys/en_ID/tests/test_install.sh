#!/usr/bin/env bash
# Integration test: install, package update, reinstall and uninstall on a
# real system. It rewrites system locale settings, so it runs only as root,
# only when EN_ID_TEST_DISPOSABLE=1, and only in a throwaway container:
#   docker run --rm -e EN_ID_TEST_DISPOSABLE=1 -v "$PWD":/src:ro IMAGE \
#     bash /src/tests/test_install.sh
set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

declare -- SCRIPT_PATH
SCRIPT_PATH=$(realpath -- "$0")
declare -r SCRIPT_PATH
declare -r SCRIPT_NAME=${SCRIPT_PATH##*/} TESTS_DIR=${SCRIPT_PATH%/*}
declare -r SRC_DIR=${TESTS_DIR%/*}

# Hook files written by releases up to 2.2.1, which the new code must delete
declare -ra OLD_HOOKS=(
  /etc/apt/apt.conf.d/99en-id-locale-gen
  /etc/dnf/plugins/post-transaction-actions.d/en_id_locale.action
  /etc/pacman.d/hooks/en_id_locale.hook
)
# Per-category lines that releases up to 2.2.1 wrote next to LANG
declare -r LEGACY_LC='^LC_[A-Z]+="?en_ID\.UTF-8"?$'

declare -- FAMILY='' INSTALLER='' DEFAULT_FILE='' WORK_DIR='' REPO='' LOG=''

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

section() { printf '\n== %s\n' "$1"; }

show_log() {
  [[ -s $LOG ]] || return 0
  printf '  last output:\n'
  tail -n 40 -- "$LOG" | sed 's/^/  /'
}

# check DESCRIPTION COMMAND [ARG...]
# One line per assertion; the first failure ends the run.
check() {
  local -- description=$1
  shift
  if "$@"; then
    printf 'ok   %s\n' "$description"
    return 0
  fi
  printf 'FAIL %s\n' "$description"
  show_log
  exit 1
}

# run DESCRIPTION RC COMMAND [ARG...]
# Runs COMMAND with its output in $LOG and expects exit status RC.
run() {
  local -- description=$1
  local -i expected=$2 actual=0
  shift 2
  "$@" &>"$LOG" </dev/null || actual=$?
  if ((actual == expected)); then
    printf 'ok   %s\n' "$description"
    return 0
  fi
  printf 'FAIL %s: exit %d, expected %d\n' "$description" "$actual" "$expected"
  show_log
  exit 1
}

# A failing locale -a returns 2, so it can never read as an empty list
listed() {
  local -- all
  all=$(locale -a 2>/dev/null) || return 2
  [[ $all == *"$1"* ]]
}

not_listed() {
  local -- all
  all=$(locale -a 2>/dev/null) || return 2
  [[ $all != *"$1"* ]]
}

has_line()   { [[ -f $1 ]] && grep -qxF -- "$2" "$1"; }
lacks()      { [[ ! -f $1 ]] || ! grep -qE -- "$2" "$1"; }
absent()     { [[ ! -e $1 && ! -L $1 ]]; }
is_dir()     { [[ -d $1 ]]; }
equal()      { [[ $1 == "$2" ]]; }

symlink_state() {
  if [[ -L $1 ]]; then
    printf 'symlink\n'
  else
    printf 'not a symlink\n'
  fi
}

# Checksums of the named files, one per line; a missing file reads 'absent'
sums() {
  local -- file sum
  for file in "$@"; do
    if [[ -e $file ]]; then
      sum=$(sha256sum -- "$file") || die 5 "Cannot read ${file@Q}"
      printf '%s %s\n' "${sum%% *}" "$file"
    else
      printf 'absent %s\n' "$file"
    fi
  done
}

# The system default must name a locale that exists, or every login warns.
default_locale_valid() {
  local -- out
  # locale's exit status says nothing here; its warnings are the evidence
  # shellcheck disable=SC2016 # $1 expands in the inner shell
  out=$(env -i bash -c 'set -a; . -- "$1"; locale' _ "$DEFAULT_FILE" 2>&1) ||:
  [[ $out != *'Cannot set'* ]]
}

detect_family() {
  local -- ids
  # shellcheck source=/dev/null
  ids=$(. /etc/os-release && printf '%s %s' "${ID:-}" "${ID_LIKE:-}") \
    || die 1 'Cannot read /etc/os-release'
  case " $ids " in
    *' debian '* | *' ubuntu '*)
      FAMILY=debian INSTALLER=install-ubuntu.sh DEFAULT_FILE=/etc/default/locale ;;
    *' fedora '* | *' rhel '* | *' centos '*)
      FAMILY=fedora INSTALLER=install-fedora.sh DEFAULT_FILE=/etc/locale.conf ;;
    *' arch '*)
      FAMILY=arch INSTALLER=install-arch.sh DEFAULT_FILE=/etc/locale.conf ;;
    *)
      die 1 "Unsupported distribution: ${ids@Q}" ;;
  esac
}

# Called through run(), where errexit is off: each family's steps are
# chained with && so a failure reaches the caller.
bootstrap() {
  case $FAMILY in
    debian) apt-get update -qq && apt-get install -y -qq git make locales ;;
    fedora) dnf install -y -q git make ;;
    arch)   pacman -Sy --needed --noconfirm git make ;;
    *)      die 1 "Unsupported family ${FAMILY@Q}" ;;
  esac
}

# A package operation that rewrites the locale archive
package_operation() {
  case $FAMILY in
    debian) apt-get install -y -qq --reinstall locales ;;
    fedora) dnf install -y -q glibc-all-langpacks && dnf reinstall -y -q glibc-all-langpacks ;;
    arch)   pacman -S --noconfirm glibc ;;
    *)      die 1 "Unsupported family ${FAMILY@Q}" ;;
  esac
}

# Recreate what an install by release 2.1.0 or earlier left behind.
seed_legacy_state() {
  printf '%s\n' LC_ALL=en_ID.UTF-8 LC_TIME=en_ID.UTF-8 >> "$DEFAULT_FILE" \
    || die 5 "Cannot write ${DEFAULT_FILE@Q}"
  printf '%s\n' LC_ALL=en_ID.UTF-8 >> /etc/environment || die 5 'Cannot write /etc/environment'
  mkdir -p -- "${OLD_HOOKS[@]%/*}" /etc/ssh || die 5 'Cannot create the hook directories'

  cat > "${OLD_HOOKS[0]}" <<'APT_HOOK' || die 5 "Cannot write ${OLD_HOOKS[0]@Q}"
// Automatically regenerate en_ID locale after package updates
DPkg::Post-Invoke { "if [ -f /etc/locale.gen ] && grep -q '^en_ID.UTF-8' /etc/locale.gen; then locale-gen en_ID.UTF-8 2>/dev/null || true; fi"; };
APT_HOOK
  cat > "${OLD_HOOKS[1]}" <<'DNF_HOOK' || die 5 "Cannot write ${OLD_HOOKS[1]@Q}"
# Regenerate en_ID locale after glibc updates
glibc*:update:/usr/bin/localedef -i en_ID -f UTF-8 en_ID.UTF-8 2>/dev/null || true
DNF_HOOK
  cat > "${OLD_HOOKS[2]}" <<'PACMAN_HOOK' || die 5 "Cannot write ${OLD_HOOKS[2]@Q}"
[Trigger]
Operation = Upgrade
Operation = Install
Type = Package
Target = glibc

[Action]
Description = Regenerate en_ID locale
When = PostTransaction
Exec = /usr/bin/bash -c "if grep -q '^en_ID.UTF-8' /etc/locale.gen; then locale-gen en_ID.UTF-8 2>/dev/null || true; fi"
PACMAN_HOOK

  [[ -e /etc/ssh/sshd_config ]] || touch -- /etc/ssh/sshd_config \
    || die 5 'Cannot create /etc/ssh/sshd_config'
  printf 'ok   legacy settings and hooks seeded\n'
}

# The installer clones tag v$VERSION, so build a repository from this tree
# that carries that tag. A copy keeps the source tree read-only.
make_fixture_repo() {
  local -- version
  mkdir -p -- "$REPO" || die 5 "Cannot create ${REPO@Q}"
  cp -R -- "$SRC_DIR"/. "$REPO"/ || die 5 "Cannot copy ${SRC_DIR@Q}"
  rm -rf -- "$REPO"/.git "$REPO"/build || die 5 "Cannot clean ${REPO@Q}"
  version=$(sed -nE -- 's/^declare -r (.* )?VERSION=([0-9]+\.[0-9]+\.[0-9]+)( .*)?$/\2/p' \
    "$REPO/$INSTALLER") || die 1 "Cannot read ${INSTALLER@Q}"
  [[ -n $version ]] || die 1 "No VERSION found in ${INSTALLER@Q}"
  git -C "$REPO" init -q -b main || die 1 'git init failed'
  git -C "$REPO" add -A || die 1 'git add failed'
  git -C "$REPO" -c user.name=Biksu-Okusi -c user.email=biksu@okusi.id \
    commit -q -m 'Integration test fixture' || die 1 'git commit failed'
  git -C "$REPO" tag -- "v$version" || die 1 "git tag v$version failed"
  printf 'ok   fixture repository tagged v%s\n' "$version"
}

# The documented form, 'wget -O- URL | sudo bash', reads the script from stdin.
run_installer() {
  EN_ID_REPO_URL=file://$REPO bash < "$REPO/$INSTALLER"
}

main() {
  local -- sshd_sum default_link before supported hook file
  local -a files

  [[ ${EN_ID_TEST_DISPOSABLE:-0} == 1 ]] \
    || die 22 'This test rewrites system locale settings.' \
              'Run it in a disposable container with EN_ID_TEST_DISPOSABLE=1.'
  ((EUID == 0)) || die 13 'This test must run as root'

  detect_family
  [[ $FAMILY != debian ]] || export DEBIAN_FRONTEND=noninteractive
  trap 'cleanup $?' EXIT
  WORK_DIR=$(mktemp -d) || die 5 'Failed to create a temporary directory'
  LOG=$WORK_DIR/output.log REPO=$WORK_DIR/en_ID
  printf '%s: %s family, installer %s\n' "$SCRIPT_NAME" "$FAMILY" "$INSTALLER"

  section 'Bootstrap'
  run "bootstrap packages ($FAMILY)" 0 bootstrap
  seed_legacy_state
  sshd_sum=$(sums /etc/ssh/sshd_config)
  default_link=$(symlink_state "$DEFAULT_FILE")
  make_fixture_repo

  section "Install over a 2.1.0 install, piped as documented ($INSTALLER)"
  run 'installer succeeds' 0 run_installer
  check 'installer names itself, not "bash"' lacks "$LOG" '^bash:'
  check 'en_ID is listed' listed en_ID
  check "$DEFAULT_FILE sets LANG=en_ID.UTF-8" has_line "$DEFAULT_FILE" LANG=en_ID.UTF-8
  check "$DEFAULT_FILE has no LC_* line for en_ID" lacks "$DEFAULT_FILE" "$LEGACY_LC"
  check '/etc/environment has no LC_* line for en_ID' lacks /etc/environment "$LEGACY_LC"
  for hook in "${OLD_HOOKS[@]}"; do
    check "old hook removed: $hook" absent "$hook"
  done
  check 'sshd_config is untouched' equal "$(sums /etc/ssh/sshd_config)" "$sshd_sum"
  check "$DEFAULT_FILE is still $default_link" \
    equal "$(symlink_state "$DEFAULT_FILE")" "$default_link"

  section 'Package update'
  # A control locale that no persistence mechanism protects: if it survives,
  # the package operation did not rebuild the archive and proves nothing.
  run 'control locale en_ZZ compiles into the archive' 0 localedef -i en_ID -f UTF-8 en_ZZ.UTF-8
  check 'en_ZZ is listed' listed en_ZZ
  run "package operation ($FAMILY)" 0 package_operation
  check 'the package operation rebuilt the archive (en_ZZ is gone)' not_listed en_ZZ
  check 'en_ID survives the package operation' listed en_ID
  run 'test suite passes against the installed locale' 0 \
    env EN_ID_TEST_INSTALLED=1 "$REPO"/tests/test_en_ID.sh

  section 'Second install changes nothing'
  files=("$DEFAULT_FILE" /etc/environment)
  [[ ! -f /etc/locale.gen ]] || files+=(/etc/locale.gen)
  before=$(sums "${files[@]}")
  run 'installer succeeds again' 0 run_installer
  check 'no settings file changed' equal "$(sums "${files[@]}")" "$before"
  if [[ $FAMILY != fedora ]]; then
    # grep -c exits 1 on a zero count; the count itself is the assertion
    check '/etc/locale.gen has one en_ID line' equal "$(grep -c -- en_ID /etc/locale.gen ||:)" 1
  fi

  section 'Uninstall'
  run 'make uninstall succeeds' 0 make -C "$REPO" uninstall
  check 'en_ID is no longer listed' not_listed en_ID
  for file in "${files[@]}"; do
    check "no en_ID left in $file" lacks "$file" en_ID
  done
  check 'locale source removed' absent /usr/share/i18n/locales/en_ID
  check 'compiled locale directory removed' absent /usr/lib/locale/en_ID.utf8
  check "$DEFAULT_FILE is still $default_link" \
    equal "$(symlink_state "$DEFAULT_FILE")" "$default_link"
  check 'the system default names a locale that exists' default_locale_valid

  section 'make install, then make uninstall, leaves the default alone'
  before=$(sums "$DEFAULT_FILE")
  run 'make install succeeds' 0 make -C "$REPO" install
  run 'make uninstall succeeds' 0 make -C "$REPO" uninstall
  check "$DEFAULT_FILE is unchanged" equal "$(sums "$DEFAULT_FILE")" "$before"

  section 'install-persistent on a system that never had en_ID'
  run 'make install-persistent succeeds' 0 make -C "$REPO" install-persistent
  check 'en_ID is listed' listed en_ID
  run 'make uninstall succeeds' 0 make -C "$REPO" uninstall
  check 'en_ID is no longer listed' not_listed en_ID

  if [[ $FAMILY == debian ]]; then
    section 'locales-all: en_ID survives its update, which deletes the locale archive'
    run 'install locales-all' 0 apt-get install -y -qq locales-all
    run 'make install-persistent succeeds' 0 make -C "$REPO" install-persistent
    run 'reinstall locales-all' 0 apt-get install -y -qq --reinstall locales-all
    check 'en_ID survives the locales-all update' listed en_ID
    run 'make uninstall succeeds' 0 make -C "$REPO" uninstall
    check 'en_ID is no longer listed' not_listed en_ID
    run 'remove locales-all' 0 apt-get remove -y -qq locales-all

    section 'A symlinked /etc/locale.gen ("All locales") is not written through'
    mv -- /etc/locale.gen "$WORK_DIR"/locale.gen || die 5 'Cannot move /etc/locale.gen aside'
    ln -s -- /usr/share/i18n/SUPPORTED /etc/locale.gen || die 5 'Cannot link /etc/locale.gen'
    supported=$(sums /usr/share/i18n/SUPPORTED)
    run 'make install-persistent succeeds' 0 make -C "$REPO" install-persistent
    check 'the packaged SUPPORTED list is unchanged' \
      equal "$(sums /usr/share/i18n/SUPPORTED)" "$supported"
    check 'en_ID is compiled outside the archive' is_dir /usr/lib/locale/en_ID.utf8
    run 'make uninstall succeeds' 0 make -C "$REPO" uninstall
    check 'en_ID is no longer listed' not_listed en_ID
    rm -f -- /etc/locale.gen || die 5 'Cannot remove the /etc/locale.gen link'
    mv -- "$WORK_DIR"/locale.gen /etc/locale.gen || die 5 'Cannot restore /etc/locale.gen'
  fi

  # A default changed since install, or a backup some other tool wrote, is not ours
  section 'make uninstall leaves a default that no longer names en_ID, and its backup'
  printf '%s\n' '# Not written by en_ID' LANG=C.UTF-8 > "$DEFAULT_FILE".backup \
    || die 5 "Cannot write ${DEFAULT_FILE@Q}.backup"
  before=$(sums "$DEFAULT_FILE" "$DEFAULT_FILE".backup)
  run 'make install succeeds' 0 make -C "$REPO" install
  run 'make uninstall succeeds' 0 make -C "$REPO" uninstall
  check "$DEFAULT_FILE and its backup are unchanged" \
    equal "$(sums "$DEFAULT_FILE" "$DEFAULT_FILE".backup)" "$before"
  rm -f -- "$DEFAULT_FILE".backup || die 5 "Cannot remove ${DEFAULT_FILE@Q}.backup"

  printf '\nAll checks passed (%s)\n' "$FAMILY"
}

main "$@"
#fin
