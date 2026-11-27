#!/bin/bash
# post_slug - Convert strings into URL/filename-friendly ASCII slugs
# Transliterates to ASCII, removes special chars, normalizes separators
# Returns empty string on error for safe handling
# Version: 1.1.0

post_slug() {
  # iconv //TRANSLIT and bash's own character counting both follow the
  # locale; pin one so output does not change under cron or LC_ALL=C.
  local -x LC_ALL=C.UTF-8
  local -- input_str=${1:-} sep_char=${2:--} rest run
  local -i preserve_case max_len rc=0

  # Validate before any integer assignment: arithmetic evaluation would
  # execute an argument such as 'a[$(cmd)]'.
  if [[ ${3:-0} == *[!0-9]* || ${4:-0} == *[!0-9]* ]]; then
    >&2 echo 'post_slug: preserve_case and max_len must be non-negative integers'
    return 22
  fi
  preserve_case=10#${3:-0}
  max_len=10#${4:-0}

  sep_char=${sep_char:0:1}
  input_str=${input_str:0:255}

  # Kludges to increase cross-platform output similarity.
  # Characters meant to become separators map to a plain '-' or ' ', which
  # the non-alphanumeric step converts to sep_char. sep_char itself is not
  # used until that step, so no separator can act as a pattern or regex.
  input_str=${input_str//—/-}
  input_str=${input_str//â�¹/Rs}
  input_str=${input_str//�/-}
  input_str=${input_str//½/-}
  input_str=${input_str//¼/-}
  input_str=${input_str// & / and }
  input_str=${input_str//★/ }
  input_str=${input_str//\?/-}   # keep real '?' apart from iconv's '?' below
  input_str=${input_str//€/EUR}
  input_str=${input_str//£/GBP}
  input_str=${input_str//©/C}
  input_str=${input_str//®/R}
  input_str=${input_str//™/-TM}
  # iconv gives these an ASCII form that Python and JS do not ('!', ':-)',
  # '<3', '-'); delete them, as the other modules do. \xc2\xad is a soft
  # hyphen; the byte range is U+1F300-U+1FAFF, emoji and pictographs, which
  # iconv partly renders as ':-D' or '<3'.
  input_str=${input_str//[¡☺☻♡♥❤]/}
  input_str=${input_str//$'\xc2\xad'/}
  input_str=${input_str//[$'\xf0\x9f\x8c\x80'-$'\xf0\x9f\xab\xbf']/}

  # Replace HTML entities (&amp; &#8217; ...) with '-'. As with the other
  # modules' '&[^ \t;]*;', a match runs from '&' to the first ';' before
  # the next space or tab. Parameter expansion only: no fork, and [[ =~ ]]
  # would overwrite the caller's BASH_REMATCH.
  if [[ $input_str == *'&'*';'* ]]; then
    rest=$input_str
    input_str=''
    while [[ $rest == *'&'* ]]; do
      input_str+=${rest%%'&'*}
      rest=${rest#*'&'}
      run=${rest%%[$' \t']*}
      if [[ $run == *';'* ]]; then
        run=${run%%';'*}
        rest=${rest:${#run}+1}
        input_str+=-
      else
        input_str+='&'
      fi
    done
    input_str+=$rest
  fi

  # Transliterate to ASCII; pure-ASCII input skips the iconv fork.
  # Input iconv cannot read (invalid UTF-8, exit 1) gives an empty slug, as in
  # the PHP and C modules; still print the line so stream callers stay
  # aligned. Any other exit (126, 127) means iconv itself is missing or
  # broken, which must not pass for an empty slug.
  if [[ $input_str == *[![:ascii:]]* ]]; then
    input_str=$(iconv -f UTF-8 -t ASCII//TRANSLIT <<< "$input_str" 2>/dev/null) || rc=$?
    if ((rc == 1)); then
      printf '\n'
      return 0
    elif ((rc)); then
      >&2 echo "post_slug: iconv failed (exit $rc)"
      return "$rc"
    fi
    input_str=${input_str//\?/}   # iconv's marker for untranslatable chars
  fi
  input_str=${input_str//[\'\"\`]/}

  ((preserve_case)) || input_str=${input_str,,}

  # Non-alphanumerics become sep_char; collapse runs and trim the ends
  input_str=${input_str//[^a-zA-Z0-9]/"$sep_char"}
  while [[ $input_str == *"$sep_char$sep_char"* ]]; do
    input_str=${input_str//"$sep_char$sep_char"/"$sep_char"}
  done
  input_str=${input_str#"$sep_char"}
  input_str=${input_str%"$sep_char"}

  # Truncate to max_len, then back to the last separator
  if ((max_len && ${#input_str} > max_len)); then
    input_str=${input_str:0:max_len}
    input_str=${input_str%"$sep_char"*}
  fi

  printf '%s\n' "$input_str"
}
declare -fx post_slug

[[ ${BASH_SOURCE[0]} == "$0" ]] || return 0

set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

show_help() {
  cat <<'HELP'
post_slug - Convert strings into URL/filename-friendly ASCII slugs

Usage: post_slug <input_str> [sep_char] [preserve_case] [max_len]

Arguments:
  input_str      String to convert (max 255 chars)
  sep_char       Separator character; first char only (default: '-')
  preserve_case  0=lowercase, 1=preserve (default: 0)
  max_len        Max output length, 0=unlimited (default: 0)

Examples:
  post_slug 'Hello, World!'           # hello-world
  post_slug 'Hello, World!' '_' 1     # Hello_World
  post_slug 'Long title here' '-' 0 8 # long

HELP
}

case ${1:-} in
  -h|--help) show_help; exit 0 ;;
  *)         ;;
esac
(($#)) || { show_help >&2; exit 2; }

post_slug "$@"
#fin
