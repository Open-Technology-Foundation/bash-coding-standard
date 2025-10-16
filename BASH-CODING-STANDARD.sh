#!/usr/bin/env bash
#shellcheck disable=1090
# Display current BASH-CODING-STANDARD{.complete,.summary,.abstract}.md
# Default tier is abstract
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# parent program location locking, for a specific application with unique namespace
#shellcheck disable=SC2034
[[ -v BCS_VERSION ]] || {
  declare -x BCS_VERSION='1.0.0'
  #shellcheck disable=SC2155
  declare -x BCS_PATH=$(realpath -- "${BASH_SOURCE[0]}")
  declare -x BCS_DIR=${BCS_PATH%/*} \
             BCS_NAME=${BCS_PATH##*/}
#  declare -n VERSION=BCS_VERSION SCRIPT_PATH=BCS_PATH SCRIPT_DIR=BCS_DIR SCRIPT_NAME=BCS_NAME
}

[[ -v BCS_DEFAULT_TIER ]] || {
  # BCS_DEFAULT_TIER can be {'',complete,summary,abstract}
  # When '', tier defaults to using the user selected symlink 
  #   BASH-CODING-STANDARD.md which in turn points to one of 
  #   BASH-CODING-STANDARD{.complete,.summary,.abstract}.md
  declare -x BCS_DEFAULT_TIER=abstract
  declare -x BCS_TIER="${BCS_DEFAULT_TIER}"
}


case ${1:-} in
  ''|complete|summary|abstract) 
    BCS_TIER=."${1:-"$BCS_DEFAULT_TIER"}"
    ;;
  *)  
    >&2 echo "$BCS_NAME: error: Invalid tier '$1'" 
    exit 2
    ;;
esac

cat "$BCS_DIR"/BASH-CODING-STANDARD"$BCS_TIER".md

#fin
