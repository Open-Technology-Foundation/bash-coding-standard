#!/usr/bin/env bash
# Removes leading whitespace from strings or input streams

ltrim() {
  # Process arguments if provided
  if (($#)); then
    local -- v
    if [[ $1 == '-e' ]]; then
      # Process escape sequences when -e flag is used
      shift
      # Note: $* joins multi-arg input with IFS (space); \c halts %b output
      printf -v v '%b' "$*"
    else
      # Note: $* joins multi-arg input with IFS (space)
      v="$*"
    fi
    # Remove leading whitespace using parameter expansion
    printf '%s\n' "${v#"${v%%[![:blank:]]*}"}"
    return 0
  # Process stdin if available
  elif [[ ! -t 0 ]]; then
    local -- REPLY
    while IFS= read -r REPLY || [[ -n $REPLY ]]; do
      # Remove leading whitespace
      REPLY=${REPLY#"${REPLY%%[![:blank:]]*}"}
      printf '%s\n' "$REPLY"
    done
  fi
  return 0
}

# Check if the script is being sourced or executed directly
[[ ${BASH_SOURCE[0]} == "$0" ]] || { declare -fx ltrim; return 0; }

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
$SCRIPT_NAME $VERSION - Remove leading blanks

Usage: ltrim [-e] string    # Remove leading whitespace
       ltrim < file         # Process stdin stream

Options:
  -e            Process escape sequences in the input string
                Note: \\c halts further output (printf %b semantics)
  -V, --version Display "$SCRIPT_NAME $VERSION"
  -h, --help    Display this help message

Examples:
  str="   hello world   "
  str=\$(ltrim "\$str")       # Result: "hello world   "
  echo "  text  " | ltrim   # Output: "text  "

Source mode:
  Sourcing is the primary intended usage for this utility.

  source ltrim                              # Single utility
  source /usr/local/share/yatti/trim/trim.inc.sh  # All utilities

  result=\$(ltrim "  hello  ")

Inline alternatives:
  For tight loops, avoid function call overhead with direct
  parameter expansion:

  v="\${v#"\${v%%[![:blank:]]*}"}"             # Leading
  v="\${v%"\${v##*[![:blank:]]}"}"             # Trailing
  v="\${v#"\${v%%[![:blank:]]*}"}"; v="\${v%"\${v##*[![:blank:]]}"}"  # Both

See also: trim, rtrim, trimv, trimall, squeeze
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

ltrim "$@"
#fin
