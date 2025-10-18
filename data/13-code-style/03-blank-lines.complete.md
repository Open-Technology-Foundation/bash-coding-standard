## Blank Line Usage

Use blank lines strategically to improve readability by creating visual separation between logical blocks:

\`\`\`bash
#!/bin/bash
set -euo pipefail

# Script metadata
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR
                                          # ← Blank line after metadata group

# Default values                          # ← Blank line before section comment
declare -- PREFIX=/usr/local
declare -i DRY_RUN=0
                                          # ← Blank line after variable group

# Derived paths
declare -- BIN_DIR="$PREFIX"/bin
declare -- LIB_DIR="$PREFIX"/lib
                                          # ← Blank line before function
check_prerequisites() {
  info 'Checking prerequisites...'

  # Check for gcc                         # ← Blank line after info call
  if ! command -v gcc &> /dev/null; then
    die 1 "'gcc' compiler not found."
  fi

  success 'Prerequisites check passed'    # ← Blank line between checks
}
                                          # ← Blank line between functions
main() {
  check_prerequisites
  install_files
}

main "$@"
#fin
\`\`\`

**Guidelines:**
- One blank line between functions
- One blank line between logical sections within functions
- One blank line after section comments
- One blank line between groups of related variables
- Blank lines before and after multi-line conditional or loop blocks
- Avoid multiple consecutive blank lines (one is sufficient)
- No blank line needed between short, related statements
