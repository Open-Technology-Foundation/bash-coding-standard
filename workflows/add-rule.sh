#!/usr/bin/env bash
# Add new BCS rule with all three tiers
# Interactive workflow for creating rules with templates and validation

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Script metadata
SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Project paths
PROJECT_DIR=$(realpath -- "$SCRIPT_DIR/..")
DATA_DIR="$PROJECT_DIR/data"
BCS_CMD="$PROJECT_DIR/bcs"
readonly -- PROJECT_DIR DATA_DIR BCS_CMD

# Global variables
declare -i VERBOSE=1 QUIET=0 INTERACTIVE=1 AUTO_COMPRESS=1 AUTO_VALIDATE=1
declare -- SECTION='' RULE_NUMBER='' RULE_NAME='' TEMPLATE='standard'

# Colors
if [[ -t 1 && -t 2 ]]; then
  declare -- RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m'
  declare -- CYAN=$'\033[0;36m' BOLD=$'\033[1m' NC=$'\033[0m'
else
  declare -- RED='' GREEN='' YELLOW='' CYAN='' BOLD='' NC=''
fi
readonly -- RED GREEN YELLOW CYAN BOLD NC

# Messaging functions
_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case ${FUNCNAME[1]} in
    vecho)   ;;
    info)    prefix+=" ${CYAN}◉${NC}" ;;
    warn)    prefix+=" ${YELLOW}⚡${NC}" ;;
    success) prefix+=" ${GREEN}✓${NC}" ;;
    error)   prefix+=" ${RED}✗${NC}" ;;
    *)       ;;
  esac
  for msg in "$@"; do printf '%s %s\n' "$prefix" "$msg"; done
}

vecho() { ((VERBOSE && !QUIET)) || return 0; _msg "$@"; }
info() { ((VERBOSE && !QUIET)) || return 0; >&2 _msg "$@"; }
warn() { ((QUIET)) || >&2 _msg "$@"; }
success() { ((VERBOSE && !QUIET)) || return 0; >&2 _msg "$@"; }
error() { >&2 _msg "$@"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

# Usage
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Add new BCS rule with interactive prompts and automatic validation.

OPTIONS:
  -h, --help              Show this help message
  --section NUMBER        Section number (01-14)
  --number NUMBER         Rule number within section
  --name NAME             Short descriptive name (lowercase-with-hyphens)
  --template TYPE         Template: minimal, standard, comprehensive (default: standard)
  --no-interactive        Non-interactive mode (requires all parameters)
  --no-compress           Skip automatic compression
  --no-validate           Skip automatic validation

EXAMPLES:
  $SCRIPT_NAME                                    # Interactive mode
  $SCRIPT_NAME --section 02 --number 06 --name special-vars
  $SCRIPT_NAME --section 08 --number 05 --name trap-handlers --template comprehensive

WORKFLOW:
  1. Prompt for section, number, name (if interactive)
  2. Validate no duplicate BCS code
  3. Create .complete.md from template
  4. Open in editor for content
  5. Generate .summary.md and .abstract.md (if auto-compress)
  6. Validate new files (if auto-validate)
  7. Display next steps
EOF
  exit "${1:-0}"
}

# Parse arguments
parse_arguments() {
  while (($# > 0)); do
    case $1 in
      -h|--help) usage 0 ;;
      --section)
        (($# > 1)) || die 2 "Missing value for --section"
        SECTION=$2
        shift 2
        ;;
      --number)
        (($# > 1)) || die 2 "Missing value for --number"
        RULE_NUMBER=$2
        shift 2
        ;;
      --name)
        (($# > 1)) || die 2 "Missing value for --name"
        RULE_NAME=$2
        shift 2
        ;;
      --template)
        (($# > 1)) || die 2 "Missing value for --template"
        TEMPLATE=$2
        shift 2
        ;;
      --no-interactive)
        INTERACTIVE=0
        shift
        ;;
      --no-compress)
        AUTO_COMPRESS=0
        shift
        ;;
      --no-validate)
        AUTO_VALIDATE=0
        shift
        ;;
      -*) die 2 "Unknown option: $1" ;;
      *) die 2 "Unexpected argument: $1" ;;
    esac
  done
}

# Interactive prompts
prompt_for_parameters() {
  ((INTERACTIVE)) || return 0

  info "Interactive mode - enter rule details"
  echo ""

  # Section
  if [[ -z "$SECTION" ]]; then
    read -r -p "Section number (01-14): " SECTION
  fi

  # Rule number
  if [[ -z "$RULE_NUMBER" ]]; then
    read -r -p "Rule number within section: " RULE_NUMBER
  fi

  # Rule name
  if [[ -z "$RULE_NAME" ]]; then
    read -r -p "Rule name (lowercase-with-hyphens): " RULE_NAME
  fi

  echo ""
}

# Validate parameters
validate_parameters() {
  local -i errors=0

  # Validate section
  if [[ ! "$SECTION" =~ ^(0[1-9]|1[0-4])$ ]]; then
    error "Invalid section: $SECTION (must be 01-14)"
    ((errors+=1))
  fi

  # Validate rule number
  if [[ ! "$RULE_NUMBER" =~ ^[0-9]{2}$ ]]; then
    error "Invalid rule number: $RULE_NUMBER (must be two digits, e.g., 06)"
    ((errors+=1))
  fi

  # Validate rule name
  if [[ ! "$RULE_NAME" =~ ^[a-z0-9-]+$ ]]; then
    error "Invalid rule name: $RULE_NAME (must be lowercase-with-hyphens)"
    ((errors+=1))
  fi

  [[ "$errors" -eq 0 ]] || die 2 "Parameter validation failed"
}

# Check for duplicate BCS code
check_duplicate_code() {
  local -- bcs_code="BCS${SECTION}${RULE_NUMBER}"
  local -- section_dir="$DATA_DIR/${SECTION}-*"

  info "Checking for duplicate BCS code: $bcs_code"

  # Check if files already exist
  local -a existing_files=()
  for file in "$section_dir"/"${RULE_NUMBER}-"*; do
    [[ -f "$file" ]] && existing_files+=("$file")
  done

  if [[ "${#existing_files[@]}" -gt 0 ]]; then
    error "Duplicate BCS code $bcs_code - files already exist:"
    for file in "${existing_files[@]}"; do
      error "  - $(basename "$file")"
    done
    return 1
  fi

  success "No duplicate found - $bcs_code is available"
  return 0
}

# Create rule file from template
create_rule_file() {
  local -- tier=$1
  local -- section_dir bcs_code file_path

  # Find section directory
  section_dir=$(find "$DATA_DIR" -maxdepth 1 -type d -name "${SECTION}-*" | head -1)
  [[ -d "$section_dir" ]] || die 1 "Section directory not found for section $SECTION"

  bcs_code="BCS${SECTION}${RULE_NUMBER}"
  file_path="$section_dir/${RULE_NUMBER}-${RULE_NAME}.${tier}.md"

  info "Creating: $(basename "$file_path")"

  # Create file based on tier
  case $tier in
    complete)
      cat > "$file_path" <<EOF
### ${RULE_NAME^}

<!-- $bcs_code -->

Brief description of the rule.

**Pattern:**

\`\`\`bash
# Example code pattern
\`\`\`

**Rationale:**

Why this rule exists and what problems it solves.

**Examples:**

\`\`\`bash
# Good example
\`\`\`

\`\`\`bash
# Bad example (avoid)
\`\`\`

**Exceptions:**

When this rule might not apply.

#fin
EOF
      ;;
    summary)
      cat > "$file_path" <<EOF
### ${RULE_NAME^}

<!-- $bcs_code -->

Brief description.

\`\`\`bash
# Example
\`\`\`

**Rationale:** Key reason for this rule.

#fin
EOF
      ;;
    abstract)
      cat > "$file_path" <<EOF
### ${RULE_NAME^}

<!-- $bcs_code -->

Rule summary in one sentence.

#fin
EOF
      ;;
  esac

  success "Created: $file_path"
  echo "$file_path"
}

# Main function
main() {
  parse_arguments "$@"

  info "${BOLD}Add New BCS Rule${NC}"
  info "Data directory: $DATA_DIR"
  echo ""

  # Get parameters
  prompt_for_parameters
  validate_parameters

  # Check for duplicates
  check_duplicate_code || die 1 "Cannot proceed with duplicate BCS code"
  echo ""

  # Create files
  info "Creating rule files..."
  local -- complete_file summary_file abstract_file

  complete_file=$(create_rule_file "complete")
  summary_file=$(create_rule_file "summary")
  abstract_file=$(create_rule_file "abstract")
  echo ""

  # Open editor for complete file
  if ((INTERACTIVE)); then
    info "Opening editor for complete file..."
    "${EDITOR:-vi}" "$complete_file"
    echo ""
  fi

  # Auto-compress if enabled
  if ((AUTO_COMPRESS)); then
    info "Note: Manual compression needed. Run:"
    echo "  bcs compress --regenerate --context-level abstract"
    echo ""
  fi

  # Auto-validate if enabled
  if ((AUTO_VALIDATE)); then
    info "Running validation..."
    if [[ -x "$PROJECT_DIR/workflows/validate-data.sh" ]]; then
      "$PROJECT_DIR/workflows/validate-data.sh" -q
    fi
    echo ""
  fi

  # Next steps
  success "${BOLD}Rule created successfully!${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Edit the .complete.md file with full documentation"
  echo "  2. Run: bcs compress --regenerate --context-level abstract"
  echo "  3. Run: bcs generate --canonical"
  echo "  4. Validate: ./workflows/validate-data.sh"
  echo ""
  echo "Files created:"
  echo "  - $complete_file"
  echo "  - $summary_file"
  echo "  - $abstract_file"
}

main "$@"
#fin
