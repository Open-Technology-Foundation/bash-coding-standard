#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

main() {
  local -a files=()
  local -- f
  # shellcheck disable=SC2030,SC2031  # files is consumed right after the loop
  find /etc -maxdepth 1 -type f -print0 | while IFS= read -r -d '' f; do
    files+=("$f")
  done
  echo "collected (always empty): ${#files[@]}"
}

main "$@"
#fin
