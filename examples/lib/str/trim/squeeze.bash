#!/usr/bin/env bash
# Squeezes consecutive blank characters (spaces and tabs) into single spaces, preserving leading and trailing whitespace

squeeze() {
  # Process arguments if provided
  if (($#)); then
    local -i process_escape=0
    # Check for -e flag to process escape sequences
    if [[ ${1:-} == '-e' ]]; then
      process_escape=1
      shift
    fi

    local -- v
    # Process escape sequences if -e flag was used
    if ((process_escape)); then
      # Note: $* joins multi-arg input with IFS (space); \c halts %b output
      printf -v v '%b' "$*"
    else
      # Note: $* joins multi-arg input with IFS (space)
      v="$*"
    fi

    # Squeeze consecutive blanks using pure Bash
    # First convert tabs to spaces for uniform handling
    v=${v//$'\t'/ }
    # Squeeze multiple spaces to single space
    while [[ $v == *'  '* ]]; do
      v=${v//  / }
    done
    printf '%s\n' "$v"
    return 0
  fi

  # Process stdin if no arguments provided
  if [[ ! -t 0 ]]; then
    local -- REPLY
    while IFS= read -r REPLY || [[ -n $REPLY ]]; do
      # Convert tabs to spaces
      REPLY=${REPLY//$'\t'/ }
      # Squeeze multiple spaces
      while [[ $REPLY == *'  '* ]]; do
        REPLY=${REPLY//  / }
      done
      printf '%s\n' "$REPLY"
    done
  fi
  return 0
}

# Check if the script is being sourced or executed directly
[[ ${BASH_SOURCE[0]} == "$0" ]] || { declare -fx squeeze; return 0; }

# --- command mode ---
set -euo pipefail
(( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) )) \
  || { >&2 echo "${0##*/}: requires Bash >= 4.4 (have ${BASH_VERSION:-unknown})"; exit 2; }
shopt -s inherit_errexit shift_verbose extglob nullglob

declare -rx PATH=/usr/local/bin:/usr/bin:/bin

declare -r VERSION='1.0.0' SCRIPT_NAME=${0##*/}

die() { >&2 printf "$SCRIPT_NAME: ✗ %s\n" "${@:2}"; exit "$1"; }

if (($#)); then
  case $1 in
    -h|--help)
        cat <<HELP
$SCRIPT_NAME $VERSION - Squeeze consecutive blanks to single space

Squeezes consecutive blank characters (spaces and tabs) into single spaces.
Preserves leading and trailing whitespace.

Usage: squeeze [-e] string   # Squeeze consecutive blanks to single space
       squeeze < file        # Process stdin stream

Options:
  -e             Process escape sequences in the input string
                 Note: \\c halts further output (printf %b semantics)
  -V, --version  Display "$SCRIPT_NAME $VERSION"
  -h, --help     Display this help message

Source mode:
  Sourcing is the primary intended usage for this utility.

  source squeeze                               # Single utility
  source /usr/local/share/yatti/trim/trim.inc.sh     # All utilities

  result=\$(squeeze "  hello    world  ")

Examples:
  str="hello    world"
  str=\$(squeeze "\$str")     # Result: "hello world"
  echo "  multiple    spaces  " | squeeze  # Output: " multiple spaces "

See also: trim, ltrim, rtrim, trimall, trimv
HELP
        exit 0
        ;;
    -V|--version)
        printf '%s %s\n' "$SCRIPT_NAME" "$VERSION"
        exit 0
        ;;
    --) shift ;;
    -*) [[ $1 == '-e' ]] || die 22 "Unknown option ${1@Q}" ;;
    *)  ;;
  esac
else
  [[ -t 0 ]] && die 22 "Usage: $SCRIPT_NAME [-e] string  |  $SCRIPT_NAME < file"
fi

squeeze "$@"
#fin
