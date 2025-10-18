#!/usr/bin/env bash
# Minimal BCS-compliant test script
set -euo pipefail

error() { >&2 echo "$0: $*"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

main() {
  echo 'Minimal compliant script executed'
  return 0
}

main "$@"
#fin
