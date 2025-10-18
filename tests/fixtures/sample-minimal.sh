#!/usr/bin/env bash
# Minimal BCS-compliant script example
set -euo pipefail

# Script metadata
SCRIPT_PATH=$(realpath -- "$0")
readonly -- SCRIPT_PATH

# Error function
error() { >&2 echo "$@"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

# Main function
main() {
  (($# > 0)) || die 1 "No arguments provided"
  echo "Hello, $1"
}

main "$@"
#fin
