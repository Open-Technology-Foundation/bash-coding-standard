#!/usr/bin/env bash
# Missing #fin marker - BCS violation
set -euo pipefail

main() {
  echo 'This script is missing the #fin end marker'
}

main "$@"
