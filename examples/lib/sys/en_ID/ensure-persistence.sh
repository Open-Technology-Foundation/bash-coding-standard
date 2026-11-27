#!/usr/bin/env bash
# Make the en_ID locale survive glibc and locale package updates.
#
# Debian, Ubuntu and Arch rebuild every locale listed in /etc/locale.gen when
# those packages update, so en_ID is listed there. Fedora and RHEL ship the
# locale archive inside a package that replaces it on update, so en_ID is
# compiled outside the archive, as a directory under /usr/lib/locale, which
# package updates leave alone. Debian and Ubuntu get the directory form too
# where locales-all is installed or /etc/locale.gen is a symlink.
set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

declare -r SCRIPT_NAME=${0##*/}
declare -r LOCALE_SRC=/usr/share/i18n/locales/en_ID
declare -r LOCALE_GEN=/etc/locale.gen LOCALE_GEN_LINE='en_ID.UTF-8 UTF-8'

# Package-manager hooks written by releases up to 2.2.1. None of them ever
# regenerated en_ID: Ubuntu's locale-gen rejects a named custom locale, DNF
# rejected the transaction states they used, and DNF5 never reads them.
declare -ra OLD_HOOKS=(
  /etc/apt/apt.conf.d/99en-id-locale-gen
  /etc/dnf/plugins/post-transaction-actions.d/en_id_locale.action
  /etc/pacman.d/hooks/en_id_locale.hook
)

declare -i VERBOSE=1

if [[ -t 1 && -t 2 ]]; then
  declare -r RED=$'\033[0;31m' GREEN=$'\033[0;32m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  declare -r RED='' GREEN='' CYAN='' NC=''
fi

# Message functions
_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case ${FUNCNAME[1]} in
    info)    prefix+=" $CYAN◉$NC" ;;
    success) prefix+=" $GREEN✓$NC" ;;
    error)   prefix+=" $RED✗$NC" ;;
    *)       ;;
  esac
  for msg in "$@"; do >&2 printf '%s %s\n' "$prefix" "$msg"; done
}
info()    { ((VERBOSE)) || return 0; _msg "$@"; }
success() { ((VERBOSE)) || return 0; _msg "$@"; }
error()   { _msg "$@"; }
die()     { (($# < 2)) || error "${@:2}"; exit "${1:-0}"; }

# Persistence functions
# Prints debian, fedora or arch. /etc/os-release is read in a subshell so
# that its variables (NAME, VERSION, ID...) never enter this script.
detect_family() {
  local -- ids
  # shellcheck source=/dev/null
  ids=$(. /etc/os-release && printf '%s %s' "${ID:-}" "${ID_LIKE:-}") \
    || die 1 'Cannot read /etc/os-release'
  case " $ids " in
    *' debian '* | *' ubuntu '*)                                  echo debian ;;
    *' fedora '* | *' rhel '* | *' centos '* | *' rocky '* | *' almalinux '*) echo fedora ;;
    *' arch '*)                                                   echo arch ;;
    *) die 1 "Unsupported distribution: ${ids@Q}" ;;
  esac
}

remove_old_hooks() {
  local -- hook
  for hook in "${OLD_HOOKS[@]}"; do
    [[ -e $hook ]] || continue
    rm -f -- "$hook" || die 5 "Cannot remove ${hook@Q}"
    info "Removed ${hook@Q}: it never regenerated the locale"
  done
}

# Debian, Ubuntu, Arch: the locales/glibc packages rebuild what is listed here.
list_in_locale_gen() {
  if [[ -f $LOCALE_GEN ]] && grep -qxF -- "$LOCALE_GEN_LINE" "$LOCALE_GEN"; then
    info "en_ID is already listed in $LOCALE_GEN"
    return 0
  fi
  # A last line without a newline would merge with the appended one
  if [[ -s $LOCALE_GEN && -n $(tail -c 1 -- "$LOCALE_GEN") ]]; then
    printf '\n' >> "$LOCALE_GEN" || die 5 "Cannot write ${LOCALE_GEN@Q}"
  fi
  printf '%s\n' "$LOCALE_GEN_LINE" >> "$LOCALE_GEN" || die 5 "Cannot write ${LOCALE_GEN@Q}"
  info "Listed en_ID in $LOCALE_GEN"
}

# Fedora, RHEL: a directory under /usr/lib/locale, outside the packaged archive.
compile_outside_archive() {
  localedef --no-archive -i en_ID -f UTF-8 en_ID.UTF-8 \
    || die 1 'localedef failed to compile en_ID outside the archive'
  info 'Compiled en_ID to /usr/lib/locale/en_ID.utf8'
}

# locales-all deletes the locale archive on every update, and while it is
# installed the locales package skips locale-gen.
locales_all_wanted() {
  local -- want
  # shellcheck disable=SC2016 # ${...} is a dpkg-query format, not a shell expansion
  want=$(dpkg-query -W -f='${db:Status-Want}' locales-all 2>/dev/null) || return 1
  [[ $want == install ]]
}

# Debian, Ubuntu. A symlinked /etc/locale.gen (debconf's "All locales") points
# into a file the locales package replaces, so en_ID is not written there.
# Either case needs the directory form, which package updates leave alone.
persist_debian() {
  if [[ -L $LOCALE_GEN ]]; then
    info "$LOCALE_GEN links to a packaged file: en_ID is not listed there"
  else
    list_in_locale_gen
  fi
  if [[ -L $LOCALE_GEN ]] || locales_all_wanted; then
    compile_outside_archive
  fi
}

main() {
  local -- family all

  ((EUID == 0)) || die 13 'This script must be run as root or with sudo'
  family=$(detect_family)
  [[ -f $LOCALE_SRC ]] || die 3 "en_ID source not found ${LOCALE_SRC@Q}" \
    'Install the locale first: sudo make install'

  info "Setting up en_ID persistence ($family family)"
  remove_old_hooks
  case $family in
    debian) persist_debian ;;
    arch)   list_in_locale_gen ;;
    fedora) compile_outside_archive ;;
    *)      die 1 "Unsupported family ${family@Q}" ;;
  esac

  # Repairs a locale that has already disappeared
  all=$(locale -a) || die 1 'locale -a failed, so the locale list cannot be read'
  if [[ $all != *en_ID* ]]; then
    localedef -i en_ID -f UTF-8 en_ID.UTF-8 || die 1 'localedef failed to compile en_ID'
    info 'Compiled en_ID into the locale archive'
  fi

  all=$(locale -a) || die 1 'locale -a failed, so the setup cannot be confirmed'
  [[ $all == *en_ID* ]] || die 1 'en_ID is not available after setup'
  success 'en_ID will be kept across glibc and locale package updates'
}

main "$@"
#fin
