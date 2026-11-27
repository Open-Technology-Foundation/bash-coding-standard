#!/usr/bin/env bash
# _post_slug.sh - command-line driver for post_slug.bash, used by the tests
#
# Usage: _post_slug.sh input_str [sep_char [preserve_case [max_len]]]
#        _post_slug.sh --stdin [sep_char [preserve_case [max_len]]]
#
# --stdin prints one slug per input line, empty lines included.
set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

#shellcheck disable=SC2155  # exit-on-error catches realpath failure
declare -r SCRIPT_PATH=$(realpath -- "$0")
declare -r SCRIPT_DIR=${SCRIPT_PATH%/*} SCRIPT_NAME=${SCRIPT_PATH##*/}
declare -r LIB_PATH=${SCRIPT_DIR%/*}/post_slug.bash

[[ -f $LIB_PATH ]] || { >&2 echo "$SCRIPT_NAME: error: Missing library ${LIB_PATH@Q}"; exit 3; }
#shellcheck source-path=SCRIPTDIR/.. source=post_slug.bash
source -- "$LIB_PATH"

usage() {
  printf '%s\n' \
    "Usage: $SCRIPT_NAME input_str [sep_char [preserve_case [max_len]]]" \
    "       $SCRIPT_NAME --stdin [sep_char [preserve_case [max_len]]]"
}

main() {
  if [[ ${1:-} != --stdin ]]; then
    (($#)) || { >&2 usage; exit 2; }
    post_slug "$@"
    return 0
  fi
  shift
  local -- line=''
  while IFS= read -r line || [[ -n $line ]]; do
    post_slug "$line" "$@"
  done
}

main "$@"

#fin
