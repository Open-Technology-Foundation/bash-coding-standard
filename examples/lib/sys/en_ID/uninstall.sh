#!/usr/bin/env bash
# Remove the en_ID locale and revert everything the installers changed:
# the system default, /etc/environment, /etc/locale.gen, the compiled
# locale and its source. It checks every path on every distribution, so it
# also cleans up after older releases.
set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

declare -r SCRIPT_NAME=${0##*/}
declare -r LOCALE_SRC=/usr/share/i18n/locales/en_ID
declare -r LOCALE_DIR=/usr/lib/locale/en_ID.utf8
declare -r LOCALE_GEN=/etc/locale.gen ENVIRONMENT=/etc/environment
declare -r SSHD_CONFIG=/etc/ssh/sshd_config
# Files that hold the system default: Debian and Ubuntu, then the rest
declare -ra DEFAULT_FILES=(/etc/default/locale /etc/locale.conf)
# Package-manager hooks written by releases up to 2.2.1
declare -ra OLD_HOOKS=(
  /etc/apt/apt.conf.d/99en-id-locale-gen
  /etc/dnf/plugins/post-transaction-actions.d/en_id_locale.action
  /etc/pacman.d/hooks/en_id_locale.hook
)
# LANG and LC_* lines naming en_ID, quoted or not
declare -r EN_ID_LINE='^(LANG|LC_[A-Z]+)="?en_ID\.UTF-8"?$'

declare -i VERBOSE=1

if [[ -t 1 && -t 2 ]]; then
  declare -r RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  declare -r RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

# Message functions
_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case ${FUNCNAME[1]} in
    info)    prefix+=" $CYAN◉$NC" ;;
    warn)    prefix+=" $YELLOW▲$NC" ;;
    success) prefix+=" $GREEN✓$NC" ;;
    error)   prefix+=" $RED✗$NC" ;;
    *)       ;;
  esac
  for msg in "$@"; do >&2 printf '%s %s\n' "$prefix" "$msg"; done
}
info()    { ((VERBOSE)) || return 0; _msg "$@"; }
warn()    { _msg "$@"; }
success() { ((VERBOSE)) || return 0; _msg "$@"; }
error()   { _msg "$@"; }
die()     { (($# < 2)) || error "${@:2}"; exit "${1:-0}"; }

# Revert functions
# The installers back up the default-locale file once, before their first
# change. Restore it, then remove en_ID lines the backup may itself hold
# (it was taken over an older install) or that were added without one.
# A file that no longer names en_ID was changed after the install, and a
# backup beside it may not be ours: both are left alone.
# /etc/default/locale is often a symlink to /etc/locale.conf: handle the
# file it points to once, and write through the link so it stays a link.
revert_default_locale() {
  local -- file real seen=' '
  for file in "${DEFAULT_FILES[@]}"; do
    [[ -e $file ]] || continue
    real=$(realpath -- "$file") || die 5 "Cannot resolve ${file@Q}"
    [[ $seen != *" $real "* ]] || continue
    seen+="$real "

    if ! grep -qE -- "$EN_ID_LINE" "$file"; then
      [[ ! -f $file.backup ]] \
        || info "Left $file and $file.backup alone: $file no longer names en_ID"
      continue
    fi
    if [[ -f $file.backup ]]; then
      cp -- "$file".backup "$file" || die 5 "Failed to restore ${file@Q}"
      rm -f -- "$file".backup || die 5 "Failed to remove ${file@Q}.backup"
      info "Restored $file from its backup"
    fi
    if grep -qE -- "$EN_ID_LINE" "$file"; then
      sed -i --follow-symlinks -E \
        -e 's/^LANG="?en_ID\.UTF-8"?$/LANG=C.UTF-8/' \
        -e '/^LC_[A-Z]+="?en_ID\.UTF-8"?$/d' -- "$file" \
        || die 5 "Failed to update ${file@Q}"
      info "Removed en_ID from $file"
    fi
  done
}

revert_environment() {
  [[ -f $ENVIRONMENT ]] && grep -qE -- "$EN_ID_LINE" "$ENVIRONMENT" || return 0
  sed -i --follow-symlinks -E "/$EN_ID_LINE/d" -- "$ENVIRONMENT" \
    || die 5 "Failed to update ${ENVIRONMENT@Q}"
  info "Removed en_ID from $ENVIRONMENT"
}

# Debian's locales package comments out lines it rewrites, so a commented
# en_ID line is ours too.
revert_locale_gen() {
  local -r line='^[# ]*en_ID\.UTF-8 UTF-8 *$'
  [[ -f $LOCALE_GEN ]] && grep -qE -- "$line" "$LOCALE_GEN" || return 0
  sed -i --follow-symlinks -E "/$line/d" -- "$LOCALE_GEN" \
    || die 5 "Failed to update ${LOCALE_GEN@Q}"
  info "Removed en_ID from $LOCALE_GEN"
}

remove_old_hooks() {
  local -- hook
  for hook in "${OLD_HOOKS[@]}"; do
    [[ -e $hook ]] || continue
    rm -f -- "$hook" || die 5 "Failed to remove ${hook@Q}"
    info "Removed $hook"
  done
}

# The archive may hold en_ID under its normalised name (en_ID.utf8), the
# name it was compiled as (en_ID.UTF-8), or both.
remove_compiled_locale() {
  local -- list name
  if [[ -d $LOCALE_DIR ]]; then
    rm -rf -- "$LOCALE_DIR" || die 5 "Failed to remove ${LOCALE_DIR@Q}"
    info "Removed $LOCALE_DIR"
  fi
  # No archive at all is normal (directory-only installs); the final
  # 'locale -a' check in main() catches anything left behind
  list=$(localedef --list-archive 2>/dev/null) ||:
  while IFS= read -r name; do
    [[ $name == en_ID* ]] || continue
    localedef --delete-from-archive -- "$name" \
      || die 5 "Failed to remove ${name@Q} from the locale archive"
    info "Removed $name from the locale archive"
  done <<<"$list"
}

main() {
  local -- all

  ((EUID == 0)) || die 13 'This script must be run as root or with sudo'

  revert_default_locale
  revert_environment
  revert_locale_gen
  remove_old_hooks
  remove_compiled_locale
  if [[ -f $LOCALE_SRC ]]; then
    rm -f -- "$LOCALE_SRC" || die 5 "Failed to remove ${LOCALE_SRC@Q}"
    info "Removed $LOCALE_SRC"
  fi

  all=$(locale -a) || die 1 'locale -a failed, so the removal cannot be confirmed'
  [[ $all != *en_ID* ]] || die 1 'en_ID is still listed by locale -a'
  success 'en_ID is removed and the system default reverted'
  warn 'Log out and back in for the change to take effect'
  if [[ -f $SSHD_CONFIG ]] && grep -qxF -- 'AcceptEnv LANG LC_*' "$SSHD_CONFIG"; then
    info "The 'AcceptEnv LANG LC_*' line in $SSHD_CONFIG is left in place:" \
         'releases up to 2.2.1 may have added it, and most distributions ship it'
  fi
}

main "$@"
#fin
