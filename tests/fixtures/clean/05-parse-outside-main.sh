#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit

declare -rx PATH=/usr/local/bin:/usr/bin:/bin

declare -r VERSION=0.4.1
#shellcheck disable=SC2155  # accepted: declare masks realpath's exit status (BCS0103)
declare -r SCRIPT_PATH=$(realpath -- "$0")
declare -r SCRIPT_NAME=${SCRIPT_PATH##*/}

declare -i MIN_SIZE=0
declare -- TARGET_DIR=. TEMP_FILE=''

_msg() { >&2 printf "$SCRIPT_NAME: $1 %s\n" "${@:2}"; }
error() { _msg '✗' "$@"; }
die() { (($# < 2)) || error "${@:2}"; exit "${1:-0}"; }

noarg() { (($# > 1)) || die 22 "Option ${1@Q} requires an argument"; }

cleanup() {
  local -i exitcode=${1:-$?}
  trap - SIGINT SIGTERM EXIT
  [[ -z $TEMP_FILE ]] || rm -f -- "$TEMP_FILE"
  exit "$exitcode"
}

parse_arguments() {
  while (($#)); do case $1 in
    -m|--min-size) noarg "$@"; shift
                   [[ $1 =~ ^[0-9]+$ ]] || die 22 "Invalid size ${1@Q}"
                   MIN_SIZE=$1
                   ;;
    -V|--version)  echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
    -h|--help)     echo "Usage: $SCRIPT_NAME [-m BYTES] [DIR]"; exit 0 ;;
    -[mVh]?*)      set -- "${1:0:2}" "-${1:2}" "${@:2}"; continue ;;
    -*)            die 22 "Invalid option ${1@Q}" ;;
    *)             TARGET_DIR=$1 ;;
  esac; shift; done
  readonly MIN_SIZE TARGET_DIR
}

report() {
  local -- dir=$1 path
  local -i count=0 total=0 size
  while IFS= read -r -d '' path; do
    size=$(stat -c '%s' -- "$path") || die 1 "Cannot stat ${path@Q}"
    ((size >= MIN_SIZE)) || continue
    count+=1
    total+=$size
    printf '%10d  %s\n' "$size" "$path" >> "$TEMP_FILE"
  done < <(find -- "$dir" -maxdepth 1 -type f -print0)
  sort -rn -- "$TEMP_FILE"
  printf '%d files, %d bytes\n' "$count" "$total"
}

main() {
  parse_arguments "$@"
  local -- dir
  dir=$(realpath -e -- "$TARGET_DIR") || die 3 "Directory not found ${TARGET_DIR@Q}"
  [[ -d $dir ]] || die 3 "Not a directory ${dir@Q}"
  trap 'cleanup $?' SIGINT SIGTERM EXIT
  TEMP_FILE=$(mktemp) || die 1 'Failed to create temp file'
  report "$dir"
}

main "$@"
#fin
