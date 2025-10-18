## Section Comments

Use lightweight section comments to organize code into logical groups. These are simpler than full 80-dash separators and provide just enough context:

\`\`\`bash
# Default values
declare -- PREFIX=/usr/local
declare -i VERBOSE=1
declare -i DRY_RUN=0

# Derived paths
declare -- BIN_DIR="$PREFIX"/bin
declare -- LIB_DIR="$PREFIX"/lib
declare -- DOC_DIR="$PREFIX"/share/doc

# Core message function
_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  # ...
}

# Conditional messaging functions
vecho() { ((VERBOSE)) || return 0; _msg "$@"; }
success() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }

# Unconditional messaging functions
error() { >&2 _msg "$@"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }
\`\`\`

**Guidelines:**
- Use simple \`# Description\` format (no dashes, no box drawing)
- Keep section comments short and descriptive (2-4 words typically)
- Place section comment immediately before the group it describes
- Follow with a blank line after the group (before next section)
- Use for grouping related variables, functions, or logical blocks
- Reserve 80-dash separators for major script divisions only

**Common section comment patterns:**
- \`# Default values\` / \`# Configuration\`
- \`# Derived paths\` / \`# Computed variables\`
- \`# Core message function\`
- \`# Conditional messaging functions\` / \`# Unconditional messaging functions\`
- \`# Helper functions\` / \`# Utility functions\`
- \`# Business logic\` / \`# Main logic\`
- \`# Validation functions\` / \`# Installation functions\`
