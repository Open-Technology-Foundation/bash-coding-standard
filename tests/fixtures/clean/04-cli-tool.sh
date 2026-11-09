#!/usr/bin/env bash
#shellcheck disable=SC2015  # BCS idiom: ((cond)) && action ||:
set -euo pipefail
shopt -s inherit_errexit

declare -rx PATH=/usr/local/bin:/usr/bin:/bin

declare -r VERSION=1.2.0
#shellcheck disable=SC2155  # accepted: declare masks realpath's exit status (BCS0103)
declare -r SCRIPT_PATH=$(realpath -- "$0")
declare -r SCRIPT_NAME=${SCRIPT_PATH##*/}

declare -i VERBOSE=1 DRY_RUN=0
declare -- OUTPUT_DIR=./archive
declare -a FILES=()

if [[ -t 1 && -t 2 ]]; then
  declare -r RED=$'\033[0;31m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  declare -r RED='' YELLOW='' CYAN='' NC=''
fi

_msg() { >&2 printf "$SCRIPT_NAME: $1 %s\n" "${@:2}"; }
error() { _msg "$RED✗$NC" "$@"; }
die() { (($# < 2)) || error "${@:2}"; exit "${1:-0}"; }
warn() { _msg "$YELLOW▲$NC" "$@"; }
info() { ((VERBOSE)) || return 0; _msg "$CYAN◉$NC" "$@"; }

noarg() { (($# > 1)) || die 22 "Option ${1@Q} requires an argument"; }

show_help() {
  cat <<HELP
$SCRIPT_NAME $VERSION - archive files into a directory

Usage: $SCRIPT_NAME [OPTIONS] FILE [FILE ...]

Options:
  -o, --output DIR  Destination directory (default: $OUTPUT_DIR)
  -n, --dry-run     Show what would be copied
  -v, --verbose     Verbose output (default)
  -q, --quiet       Quiet mode
  -V, --version     Show version
  -h, --help        Show this help
HELP
}

archive_file() {
  local -- file=$1 dest
  [[ -f $file ]] || { warn "Skipping ${file@Q}: not a regular file"; return 0; }
  dest="$OUTPUT_DIR"/${file##*/}
  if ((DRY_RUN)); then
    info "[DRY-RUN] Would copy ${file@Q} to ${dest@Q}"
    return 0
  fi
  cp -- "$file" "$dest" || die 1 "Failed to copy ${file@Q}"
  info "Archived ${file@Q}"
}

main() {
  while (($#)); do case $1 in
    -o|--output)  noarg "$@"; shift; OUTPUT_DIR=$1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    -v|--verbose) VERBOSE=1 ;;
    -q|--quiet)   VERBOSE=0 ;;
    -V|--version) echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
    -h|--help)    show_help; exit 0 ;;
    --)           shift; FILES+=("$@"); break ;;
    -[onvqVh]?*)  set -- "${1:0:2}" "-${1:2}" "${@:2}"; continue ;;
    -*)           die 22 "Invalid option ${1@Q}" ;;
    *)            FILES+=("$1") ;;
  esac; shift; done
  readonly VERBOSE DRY_RUN OUTPUT_DIR

  ((${#FILES[@]})) || die 2 'No input files specified'
  ((DRY_RUN)) && info 'Dry-run mode' ||:
  if [[ ! -d $OUTPUT_DIR ]]; then
    if ((DRY_RUN)); then
      info "[DRY-RUN] Would create ${OUTPUT_DIR@Q}"
    else
      mkdir -p -- "$OUTPUT_DIR" || die 1 "Cannot create ${OUTPUT_DIR@Q}"
    fi
  fi

  local -- file
  for file in "${FILES[@]}"; do
    archive_file "$file"
  done
}

main "$@"
#fin
