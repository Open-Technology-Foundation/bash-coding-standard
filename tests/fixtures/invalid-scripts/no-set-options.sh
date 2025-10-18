#!/usr/bin/env bash
# Missing set -euo pipefail - BCS violation

main() {
  echo 'This script is missing set -euo pipefail'
}

main "$@"
#fin
