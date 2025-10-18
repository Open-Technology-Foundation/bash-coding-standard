#!/usr/bin/env bash
# Interrogate/inspect BCS rules - query rule information by code or file path
# Provides comprehensive rule metadata and content viewing

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
declare -i VERBOSE=1 QUIET=0 SHOW_CONTENT=0 SHOW_METADATA=1 SHOW_ALL_TIERS=0
declare -- OUTPUT_FORMAT='text'  # text, json, markdown

# Colors (conditional on TTY)
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

# Usage information
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] CODE_OR_FILE [CODE_OR_FILE ...]

Interrogate/inspect BCS rules - query rule information by BCS code or file path.

ARGUMENTS:
  CODE_OR_FILE            BCS code (e.g., BCS0102, BCS010201) or file path

OPTIONS:
  -h, --help              Show this help message
  -q, --quiet             Quiet mode (errors only)
  -v, --verbose           Verbose mode (default)
  -p, --print             Print rule content to stdout
  -m, --metadata          Show metadata only (default)
  --all-tiers             Show all three tiers (complete, summary, abstract)
  --format FORMAT         Output format: text (default), json, markdown
  --no-metadata           Suppress metadata, only show content (requires -p)

METADATA DISPLAYED:
  - BCS code
  - File path (all tiers)
  - File size (bytes and lines for all tiers)
  - Last modified timestamp
  - Short name (from filename)
  - Title (extracted from file)

OUTPUT FORMATS:
  text       - Human-readable formatted output (default)
  json       - JSON structured output
  markdown   - Markdown formatted output

EXAMPLES:
  $SCRIPT_NAME BCS0102                    # Show metadata for BCS0102
  $SCRIPT_NAME BCS0102 -p                 # Show metadata + content
  $SCRIPT_NAME BCS0102 --all-tiers        # Show all three tiers metadata
  $SCRIPT_NAME BCS0102 -p --all-tiers     # Show all tiers with content
  $SCRIPT_NAME BCS01 BCS02 BCS03          # Multiple codes
  $SCRIPT_NAME --format json BCS0102      # JSON output
  $SCRIPT_NAME data/02-variables/01-type-specific.complete.md  # By file path

EXIT CODES:
  0 - Success
  1 - Rule not found or invalid code
  2 - Invalid arguments

SEE ALSO:
  bcs decode CODE         - Decode BCS codes to file locations
  bcs codes               - List all BCS codes
EOF
  exit "${1:-0}"
}

# Parse arguments
parse_arguments() {
  local -a codes_or_files=()

  while (($# > 0)); do
    case $1 in
      -h|--help)
        usage 0
        ;;
      -q|--quiet)
        QUIET=1
        VERBOSE=0
        shift
        ;;
      -v|--verbose)
        VERBOSE=1
        QUIET=0
        shift
        ;;
      -p|--print)
        SHOW_CONTENT=1
        shift
        ;;
      -m|--metadata)
        SHOW_METADATA=1
        SHOW_CONTENT=0
        shift
        ;;
      --no-metadata)
        SHOW_METADATA=0
        shift
        ;;
      --all-tiers)
        SHOW_ALL_TIERS=1
        shift
        ;;
      --format)
        (($# > 1)) || die 2 "Missing value for --format"
        OUTPUT_FORMAT=$2
        [[ "$OUTPUT_FORMAT" =~ ^(text|json|markdown)$ ]] || \
          die 2 "Invalid format: $OUTPUT_FORMAT (must be text, json, or markdown)"
        shift 2
        ;;
      -*)
        die 2 "Unknown option: $1"
        ;;
      *)
        codes_or_files+=("$1")
        shift
        ;;
    esac
  done

  # Validate we have at least one code/file
  [[ "${#codes_or_files[@]}" -gt 0 ]] || \
    die 2 "No BCS code or file path specified" "Use --help for usage information"

  # Export to be used by main
  printf '%s\0' "${codes_or_files[@]}"
}

# Extract title from markdown file (first ## or ### heading)
extract_title() {
  local -- file=$1
  local -- title

  title=$(grep -m 1 -E '^##+ ' "$file" 2>/dev/null | sed -E 's/^##+ *//' || echo "")
  [[ -n "$title" ]] && echo "$title" || echo "(No title found)"
}

# Get file metadata
get_file_metadata() {
  local -- file=$1
  local -- basename_file size_bytes lines_count modified_date title

  [[ -f "$file" ]] || return 1

  basename_file=$(basename "$file")
  size_bytes=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
  lines_count=$(wc -l < "$file" 2>/dev/null || echo "0")
  modified_date=$(stat -c%y "$file" 2>/dev/null | cut -d' ' -f1,2 || stat -f%Sm "$file" 2>/dev/null || echo "Unknown")
  title=$(extract_title "$file")

  printf '%s|%s|%s|%s|%s\n' "$basename_file" "$size_bytes" "$lines_count" "$modified_date" "$title"
}

# Interrogate a single rule by BCS code
interrogate_by_code() {
  local -- code=$1
  local -- default_tier file_path
  local -a tier_files=()

  [[ -x "$BCS_CMD" ]] || die 2 "bcs command not executable"

  # Get default tier file
  if ((SHOW_ALL_TIERS)); then
    # Get all three tiers
    for tier in complete summary abstract; do
      file_path=$("$BCS_CMD" decode "$code" "-${tier:0:1}" 2>/dev/null) || {
        warn "Failed to decode $code for tier: $tier"
        continue
      }
      [[ -f "$file_path" ]] && tier_files+=("$tier:$file_path")
    done
  else
    # Get default tier only
    file_path=$("$BCS_CMD" decode "$code" 2>/dev/null) || \
      die 1 "Failed to decode BCS code: $code"
    [[ -f "$file_path" ]] || die 1 "File not found for code $code: $file_path"

    # Determine tier from filename
    if [[ "$file_path" =~ \.complete\.md$ ]]; then
      tier_files+=("complete:$file_path")
    elif [[ "$file_path" =~ \.summary\.md$ ]]; then
      tier_files+=("summary:$file_path")
    elif [[ "$file_path" =~ \.abstract\.md$ ]]; then
      tier_files+=("abstract:$file_path")
    else
      tier_files+=("unknown:$file_path")
    fi
  fi

  [[ "${#tier_files[@]}" -gt 0 ]] || die 1 "No files found for code: $code"

  # Display metadata and/or content
  display_rule_info "$code" tier_files
}

# Interrogate by file path
interrogate_by_file() {
  local -- file_path=$1
  local -- code tier
  local -a tier_files=()

  [[ -f "$file_path" ]] || die 1 "File not found: $file_path"

  # Extract code from file path (simple heuristic)
  # This is a simplified version - could be enhanced
  code=$(basename "$(dirname "$file_path")" | grep -oE '^[0-9]{2}' || echo "")
  code="BCS$code"

  # Determine tier
  if [[ "$file_path" =~ \.complete\.md$ ]]; then
    tier="complete"
  elif [[ "$file_path" =~ \.summary\.md$ ]]; then
    tier="summary"
  elif [[ "$file_path" =~ \.abstract\.md$ ]]; then
    tier="abstract"
  else
    tier="unknown"
  fi

  tier_files=("$tier:$file_path")

  # If all tiers requested, find the other tiers
  if ((SHOW_ALL_TIERS)); then
    local -- base_path="${file_path%.$tier.md}"
    for t in complete summary abstract; do
      [[ "$t" == "$tier" ]] && continue
      [[ -f "$base_path.$t.md" ]] && tier_files+=("$t:$base_path.$t.md")
    done
  fi

  display_rule_info "$code" tier_files
}

# Display rule information
display_rule_info() {
  local -- code=$1
  local -n tiers_ref=$2
  local -- tier_entry tier file_path metadata
  local -a metadata_parts

  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo "{"
    echo "  \"code\": \"$code\","
    echo "  \"tiers\": ["
  elif [[ "$OUTPUT_FORMAT" == "markdown" ]]; then
    echo "# Rule: $code"
    echo ""
  else
    echo "${BOLD}BCS Code:${NC} $code"
    echo ""
  fi

  local -i tier_count=0
  for tier_entry in "${tiers_ref[@]}"; do
    tier="${tier_entry%%:*}"
    file_path="${tier_entry#*:}"

    metadata=$(get_file_metadata "$file_path") || {
      warn "Failed to get metadata for: $file_path"
      continue
    }

    IFS='|' read -r basename_file size_bytes lines_count modified_date title <<< "$metadata"

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
      ((tier_count > 0)) && echo ","
      cat <<EOF
    {
      "tier": "$tier",
      "file": "$file_path",
      "basename": "$basename_file",
      "size_bytes": $size_bytes,
      "lines": $lines_count,
      "modified": "$modified_date",
      "title": "$title"
    }
EOF
      ((tier_count+=1))
    elif [[ "$OUTPUT_FORMAT" == "markdown" ]]; then
      cat <<EOF
## Tier: $tier

- **File:** \`$file_path\`
- **Size:** $size_bytes bytes, $lines_count lines
- **Modified:** $modified_date
- **Title:** $title

EOF
      if ((SHOW_CONTENT)); then
        echo '```markdown'
        cat "$file_path"
        echo '```'
        echo ""
      fi
    else
      # Text format
      if ((SHOW_METADATA)); then
        echo "${CYAN}Tier:${NC} $tier"
        echo "${CYAN}File:${NC} $file_path"
        echo "${CYAN}Size:${NC} $size_bytes bytes, $lines_count lines"
        echo "${CYAN}Modified:${NC} $modified_date"
        echo "${CYAN}Title:${NC} $title"
        echo ""
      fi

      if ((SHOW_CONTENT)); then
        if ((SHOW_METADATA)); then
          echo "${BOLD}Content:${NC}"
          echo "---"
        fi
        cat "$file_path"
        echo ""
        if ((SHOW_ALL_TIERS && tier_count < ${#tiers_ref[@]} - 1)); then
          echo "----------------------------------------"
          echo ""
        fi
      fi
    fi
    ((tier_count+=1))
  done

  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo "  ]"
    echo "}"
  fi
}

# Main function
main() {
  local -a codes_or_files
  local -- item

  # Parse arguments and get codes/files
  mapfile -t -d '' codes_or_files < <(parse_arguments "$@")

  [[ "${#codes_or_files[@]}" -gt 0 ]] || die 2 "No codes or files to process"

  # Process each code or file
  for item in "${codes_or_files[@]}"; do
    if [[ "$item" =~ ^BCS[0-9]+ ]]; then
      # BCS code
      interrogate_by_code "$item"
    elif [[ -f "$item" ]]; then
      # File path
      interrogate_by_file "$item"
    else
      die 1 "Invalid code or file not found: $item"
    fi

    # Add separator between multiple items
    if [[ "${#codes_or_files[@]}" -gt 1 && "$OUTPUT_FORMAT" == "text" ]]; then
      echo ""
      echo "========================================"
      echo ""
    fi
  done
}

main "$@"
#fin
