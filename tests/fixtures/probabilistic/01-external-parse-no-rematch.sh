#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

main() {
  local -- tag=${1:-v1.2}
  local -- major minor
  major=$(printf '%s' "$tag" | grep -oE '[0-9]+' | head -1) \
    || { >&2 echo "No version number in ${tag@Q}"; return 22; }
  minor=$(printf '%s' "$tag" | cut -d. -f2)
  printf 'major=%s minor=%s\n' "$major" "$minor"
}

main "$@"
#fin
