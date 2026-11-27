#!/bin/bash
# update_version.sh - set the version number in every file of the post_slug
# project that carries one
set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

#shellcheck disable=SC2155  # exit-on-error catches realpath failure
declare -r SCRIPT_PATH=$(realpath -- "$0")
declare -r SCRIPT_DIR=${SCRIPT_PATH%/*} SCRIPT_NAME=${SCRIPT_PATH##*/}

# A version number, as a sed/grep basic regular expression
declare -r VER_RE='[0-9]\+\.[0-9]\+\.[0-9]\+'
declare -- NEW_VERSION='' NEW_RE=''

_msg()    { >&2 printf "$SCRIPT_NAME: $1 %s\n" "${@:2}"; }
success() { _msg '✓' "$@"; }
info()    { _msg '◉' "$@"; }
error()   { _msg '✗' "$@"; }
die()     { (($# < 2)) || error "${@:2}"; exit "${1:-0}"; }

show_help() {
  cat <<HELP
$SCRIPT_NAME - set the post_slug version in every file that carries it

Usage: $SCRIPT_NAME X.Y.Z
       $SCRIPT_NAME -h|--help

Each version marker is checked after it is written; a marker that is not
found stops the update with an error, naming the file.
HELP
}

# bump FILE BEFORE [AFTER] - replace the version number that follows the
# regex BEFORE (and precedes AFTER) in FILE, then check the new one is there
bump() {
  local -- file=$1 before=$2 after=${3:-}
  [[ -f $file ]] || die 3 "File not found ${file@Q}"
  sed -i "s/\\($before\\)$VER_RE\\($after\\)/\\1$NEW_VERSION\\2/" -- "$file" \
    || die 1 "Cannot update ${file@Q}"
  grep -q -- "$before$NEW_RE$after" "$file" \
    || die 1 "No version marker matching ${before@Q} in ${file@Q}"
}

main() {
  local -- today
  case ${1:-} in
    -h|--help) show_help; exit 0 ;;
    '')        >&2 show_help; exit 2 ;;
    -*)        die 22 "Invalid option ${1@Q}" ;;
    *)         ;;
  esac
  (($# == 1)) || die 2 "Expected one version number; see '$SCRIPT_NAME --help'"
  [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 22 "Version must be X.Y.Z, not ${1@Q}"
  NEW_VERSION=$1
  NEW_RE=${NEW_VERSION//./\\.}
  readonly NEW_VERSION NEW_RE

  cd -- "$SCRIPT_DIR" || die 1 "Cannot enter ${SCRIPT_DIR@Q}"
  info "Updating version to $NEW_VERSION"

  printf '%s\n' "$NEW_VERSION" > VERSION || die 1 'Cannot write VERSION'

  bump post_slug.py   "__version__ = '" "'"
  # The two docstring versions stand alone on the line after a 'Version:'
  # heading (and its underline); the range ends at the first such number.
  sed -i "/Version:\$/,/^ *$VER_RE\$/ s/^\\( *\\)$VER_RE\$/\\1$NEW_VERSION/" -- post_slug.py \
    || die 1 'Cannot update post_slug.py'
  (($(grep -c -- "^ *$NEW_RE\$" post_slug.py) == 2)) \
    || die 1 'Expected two docstring versions in post_slug.py'
  bump post_slug.js   '@version '
  bump post_slug.php  '@version '
  bump post_slug.bash '^# Version: '
  bump slugify-files  '^declare -r VERSION='
  bump c/post_slug.c  '^ \* Version: '
  bump c/post_slug.c  '^#define POST_SLUG_VERSION "' '"'
  bump c/post_slug.h  '^ \* Version: '
  bump c/Makefile     '^# Version: '
  bump c/README.md    '^\*\*Version\*\*: '
  bump pyproject.toml '^version = "' '"'
  bump README.md      '^\*\*Version\*\*: '
  # The manpage's .TH line carries the version and the release date
  bump c/post_slug.1  '^\.TH POST_SLUG 1 "[0-9-]*" "post_slug ' '"'
  today=$(date +%F) || die 1 'Cannot read the date'
  sed -i "s/^\\(\\.TH POST_SLUG 1 \"\\)[0-9-]*\"/\\1$today\"/" -- c/post_slug.1 \
    || die 1 'Cannot update the date in c/post_slug.1'
  success "Version $NEW_VERSION set in 13 files"

  info 'Next steps:'
  info '  1. Add a changelog entry to the docstrings of post_slug.py, .js and .php'
  info "  2. git commit -am 'chore: bump version to $NEW_VERSION'"
  info "  3. git tag -a v$NEW_VERSION -m 'Version $NEW_VERSION'"
  info "  4. git push origin v$NEW_VERSION"
}

main "$@"
#fin
