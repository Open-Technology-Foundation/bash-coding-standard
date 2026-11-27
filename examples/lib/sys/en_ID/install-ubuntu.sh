#!/usr/bin/env bash
# Install the en_ID locale and make it the system default.
# For Ubuntu and Debian.
set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Named literally: piped into bash, as documented, $0 is "bash"
declare -r SCRIPT_NAME=install-ubuntu.sh VERSION=2.3.1
declare -r REPO_URL=${EN_ID_REPO_URL:-https://github.com/Open-Technology-Foundation/en_ID.git}
# update-locale writes here (on newer releases, a symlink to /etc/locale.conf)
declare -r DEFAULT_LOCALE=/etc/default/locale ENVIRONMENT=/etc/environment

declare -i VERBOSE=1
declare -- TEMP_DIR=''

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

# Cleanup on exit
# shellcheck disable=SC2317,SC2329 # invoked via trap
cleanup() {
  local -i exitcode=${1:-$?}
  trap - EXIT
  [[ -z $TEMP_DIR ]] || rm -rf -- "$TEMP_DIR"
  exit "$exitcode"
}
trap 'cleanup $?' EXIT

# Installation functions
install_packages() {
  info 'Installing required packages'
  # A stale or broken third-party source must not block the install
  apt-get update -qq \
    || warn 'apt-get update reported errors; continuing with the existing package lists'
  apt-get install -y -qq git make locales || die 18 'Failed to install: git make locales'
}

# Clones the release matching this installer, then installs the locale and
# makes it survive package updates.
install_locale() {
  TEMP_DIR=$(mktemp -d) || die 5 'Failed to create a temporary directory'
  info "Downloading en_ID v$VERSION"
  timeout 300 git clone --quiet --depth 1 --branch "v$VERSION" -- "$REPO_URL" "$TEMP_DIR"/en_ID \
    || die 1 "Failed to download en_ID v$VERSION from ${REPO_URL@Q}"
  make -C "$TEMP_DIR"/en_ID install-persistent || die 1 'Installation failed'
}

# Keeps the first backup, which holds the settings from before en_ID.
backup_settings() {
  local -- file=$1
  if [[ -f $file.backup ]]; then
    info "Existing backup $file.backup preserved"
  elif [[ -f $file ]]; then
    cp -- "$file" "$file".backup || die 5 "Failed to back up ${file@Q}"
    info "Backed up current locale settings to $file.backup"
  fi
}

# Releases up to 2.2.1 wrote twelve LC_* lines, and up to 2.1.0 LC_ALL as well.
# LANG alone sets the default.
strip_legacy_lc() {
  local -- file
  for file in "$@"; do
    [[ -f $file ]] || continue
    sed -i --follow-symlinks -E '/^LC_[A-Z]+="?en_ID\.UTF-8"?$/d' -- "$file" \
      || die 5 "Failed to update ${file@Q}"
  done
}

# A last line without a newline would merge with an appended one.
end_with_newline() {
  local -- file=$1
  [[ -s $file && -n $(tail -c 1 -- "$file") ]] || return 0
  printf '\n' >> "$file" || die 5 "Failed to write ${file@Q}"
}

set_default_lang() {
  update-locale LANG=en_ID.UTF-8 || die 1 'update-locale failed'
}

# For programs that read /etc/environment rather than the locale settings
set_environment_lang() {
  if [[ -f $ENVIRONMENT ]] && grep -qxF -- 'LANG=en_ID.UTF-8' "$ENVIRONMENT"; then
    return 0
  fi
  end_with_newline "$ENVIRONMENT"
  printf 'LANG=en_ID.UTF-8\n' >> "$ENVIRONMENT" || die 5 "Failed to write ${ENVIRONMENT@Q}"
}

main() {
  local -- sample

  [[ $REPO_URL =~ ^(https://|file:///) ]] \
    || die 22 "Invalid repository URL ${REPO_URL@Q}" \
              'EN_ID_REPO_URL must start with https:// (or file:/// for a local clone)'
  ((EUID == 0)) || die 13 'This script must be run as root or with sudo'

  info "Installing en_ID v$VERSION as the system default locale"
  install_packages
  install_locale
  backup_settings "$DEFAULT_LOCALE"
  strip_legacy_lc "$DEFAULT_LOCALE" "$ENVIRONMENT"
  set_default_lang
  set_environment_lang

  success 'Installation complete: en_ID is the system default locale'
  warn 'Log out and back in, or reconnect over SSH, for the new default to take effect'
  # date, not printf's %()T: glibc never looks again for a locale archive that
  # was missing when this shell first looked, and on a new system this run created it
  sample=$(LC_ALL=en_ID.UTF-8 date +'%x = %A, %d %B %Y') || sample='unavailable'
  info "Date format sample: $sample"
}

main "$@"
#fin
