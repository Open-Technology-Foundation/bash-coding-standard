# Missing shebang - BCS violation
set -euo pipefail

main() {
  echo 'This script is missing a shebang'
}

main "$@"
#fin
