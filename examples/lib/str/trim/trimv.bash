#!/usr/bin/env bash
# Removes leading and trailing whitespace and assigns result to a variable

trimv() {
  local -i _trimv__escape=0
  local -- _trimv__varname=''

  if (($#)); then
    if [[ $1 == '-e' ]]; then
      _trimv__escape=1
      shift
    fi

    if [[ ${1:-} == '-n' ]]; then
      _trimv__varname=${2:-TRIM}

      [[ $_trimv__varname =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || {
        >&2 printf "${FUNCNAME[0]}: ✗ %s\n" "invalid variable name ${_trimv__varname@Q}"
        return 1
      }

      # A trailing bare -n has no name to skip; it takes the TRIM default
      if (($# > 1)); then shift 2; else shift; fi
    fi
  fi

  if (($#)); then
    local -- _trimv__val

    if ((_trimv__escape)); then
      # Note: $* joins multi-arg input with IFS (space); \c halts %b output
      printf -v _trimv__val '%b' "$*"
    else
      # Note: $* joins multi-arg input with IFS (space)
      _trimv__val="$*"
    fi

    _trimv__val=${_trimv__val#"${_trimv__val%%[![:blank:]]*}"}
    _trimv__val=${_trimv__val%"${_trimv__val##*[![:blank:]]}"}

    if [[ -n $_trimv__varname ]]; then
      local -n _trimv__ref=$_trimv__varname
      _trimv__ref=$_trimv__val
    else
      printf '%s\n' "$_trimv__val"
    fi
    return 0
  fi

  if [[ ! -t 0 ]]; then
    if [[ -n $_trimv__varname ]]; then
      local -- _trimv__content='' _trimv__line
      while IFS= read -r _trimv__line || [[ -n $_trimv__line ]]; do
        _trimv__line=${_trimv__line#"${_trimv__line%%[![:blank:]]*}"}
        _trimv__line=${_trimv__line%"${_trimv__line##*[![:blank:]]}"}
        _trimv__content+="$_trimv__line"$'\n'
      done
      # Remove trailing newline added by the loop
      _trimv__content=${_trimv__content%$'\n'}

      local -n _trimv__ref=$_trimv__varname
      _trimv__ref=$_trimv__content
    else
      local -- REPLY
      while IFS= read -r REPLY || [[ -n $REPLY ]]; do
        REPLY=${REPLY#"${REPLY%%[![:blank:]]*}"}
        REPLY=${REPLY%"${REPLY##*[![:blank:]]}"}
        printf '%s\n' "$REPLY"
      done
    fi
  fi
  return 0
}

[[ ${BASH_SOURCE[0]} == "$0" ]] || { declare -fx trimv; return 0; }

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
$SCRIPT_NAME $VERSION - Remove leading and trailing whitespace and assign to a variable

Usage:
  source trimv
  trimv [-e] [-n varname] string

Note: -e and -n are *positional* options; order is important.

Options:
  -e            Process escape sequences in the input string
                Note: \c halts further output (printf %b semantics)
  -n varname    Variable to store result (defaults to TRIM)
  -V, --version Display version
  -h, --help    Display this help message

Examples:
  source trimv
  trimv -n RESULT "  hello world  "
  echo "\$RESULT"                        # Outputs: hello world

  trimv -e -n CONTENT "\\t hello \\n"     # Process escape sequences
  cat file.txt | trimv -n DATA          # Read from stdin

Source mode:
  This utility MUST be sourced to use -n variable assignment.
  Running as a script, assignments only affect the subprocess.

  source trimv                              # Single utility
  source /usr/local/share/yatti/trim/trim.inc.sh # All utilities

Inline alternatives:
  For tight loops, avoid function call overhead with direct
  parameter expansion:

  v="\${v#"\${v%%[![:blank:]]*}"}"             # Leading
  v="\${v%"\${v##*[![:blank:]]}"}"             # Trailing
  v="\${v#"\${v%%[![:blank:]]*}"}"; v="\${v%"\${v##*[![:blank:]]}"}"  # Both

See also: trim, ltrim, rtrim, trimall, squeeze
HELP
        exit 0
        ;;
    -V|--version)
        printf '%s %s\n' "$SCRIPT_NAME" "$VERSION"
        exit 0
        ;;
    -n) die 22 "-n requires source mode (assignment cannot persist in a subprocess)" ;;
    --) shift ;;
    -*) [[ $1 == '-e' ]] || die 22 "Unknown option ${1@Q}" ;;
    *)  ;;
  esac
else
  [[ -t 0 ]] && die 22 "Usage: $SCRIPT_NAME [-e] string  |  $SCRIPT_NAME < file  |  source $SCRIPT_NAME; $SCRIPT_NAME [-e] -n var string"
fi

trimv "$@"
#fin
