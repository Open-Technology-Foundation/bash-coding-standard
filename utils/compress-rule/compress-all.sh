#!/usr/bin/env bash
# Automated BCS rule compression using Claude Code CLI
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# ============================================================================
# Script Metadata
# ============================================================================

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
PROJECT_DIR=${SCRIPT_DIR/\/utils*/}
DATAPATH="$PROJECT_DIR/data"
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME PROJECT_DIR DATAPATH

# Source bash-coding-standard to access get_bcs_code() function
#shellcheck source=../../bash-coding-standard
source "$PROJECT_DIR/bash-coding-standard" || {
  echo "$SCRIPT_NAME: ERROR: Cannot source bash-coding-standard" >&2
  exit 1
}

# ============================================================================
# Global Variable Declarations
# ============================================================================

# Configuration (modifiable via arguments)
declare -- CLAUDE_CMD='claude'
declare -- TIER=''  # '' = both, 'summary', 'abstract'

# Runtime flags
declare -i DRY_RUN=0
declare -i REGENERATE=0
declare -i VERBOSE=1
declare -i REPORT_ONLY=1  # Default mode (backward compatible)

# Size limits
declare -A data_size_limit=(
  [complete]=20000
  [summary]=10000
  [abstract]=1500
)
readonly -A data_size_limit

# Statistics tracking
declare -i total_processed=0
declare -i summary_success=0
declare -i summary_oversized=0
declare -i summary_failed=0
declare -i abstract_success=0
declare -i abstract_oversized=0
declare -i abstract_failed=0

# ============================================================================
# Color Definitions
# ============================================================================

if [[ -t 1 && -t 2 ]]; then
  readonly -- RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' BOLD=$'\033[1m' NC=$'\033[0m'
else
  readonly -- RED='' GREEN='' YELLOW='' CYAN='' BOLD='' NC=''
fi

# ============================================================================
# Utility Functions
# ============================================================================

_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case ${FUNCNAME[1]} in
    vecho)   : ;;
    info)    prefix+=" ${CYAN}◉${NC}" ;;
    warn)    prefix+=" ${YELLOW}⚡${NC}" ;;
    success) prefix+=" ${GREEN}✓${NC}" ;;
    error)   prefix+=" ${RED}✗${NC}" ;;
    *)       ;;
  esac
  for msg in "$@"; do printf '%s %s\n' "$prefix" "$msg"; done
}

vecho() { ((VERBOSE)) || return 0; _msg "$@"; }
info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
success() { ((VERBOSE)) || return 0; >&2 _msg "$@" || return 0; }
error() { >&2 _msg "$@"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

noarg() {
  (($# > 1)) || die 22 "Option '$1' requires an argument"
}

# ============================================================================
# Business Logic Functions
# ============================================================================

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Automated BCS rule compression using Claude Code CLI.

MODES:
  --report-only          Report oversized files only (default, backward compatible)
  --regenerate           Delete and regenerate all compressed files

OPTIONS:
  --tier TIER            Process specific tier: summary, abstract, or both (default: both)
  --claude-cmd CMD       Claude CLI command path (default: claude)
  -n, --dry-run          Show what would be done without doing it
  -q, --quiet            Quiet mode (less verbose output)
  -v, --verbose          Verbose mode (default)
  -h, --help             Display this help message
  -V, --version          Display version information

EXAMPLES:
  # Report oversized files (current behavior)
  $SCRIPT_NAME
  $SCRIPT_NAME --report-only

  # Regenerate all compressed files
  $SCRIPT_NAME --regenerate

  # Regenerate only summary files (dry-run)
  $SCRIPT_NAME --regenerate --tier summary --dry-run

  # Regenerate using custom Claude command
  $SCRIPT_NAME --regenerate --claude-cmd /usr/local/bin/claude

SIZE LIMITS:
  complete: ${data_size_limit[complete]} bytes
  summary:  ${data_size_limit[summary]} bytes
  abstract: ${data_size_limit[abstract]} bytes

EOF
}

validate_claude_cli() {
  command -v "$CLAUDE_CMD" >/dev/null 2>&1 || \
    die 1 "Claude CLI not found: $CLAUDE_CMD" \
          'Install from: https://claude.ai/code'

  # Test Claude with required flags
  if ! "$CLAUDE_CMD" --help 2>&1 | grep -q 'dangerously-skip-permissions'; then
    die 1 "Claude CLI does not support --dangerously-skip-permissions flag" \
          'Update Claude CLI to latest version'
  fi

  success "Claude CLI validated: $CLAUDE_CMD"
}

build_system_prompt_summary() {
  local -- bcs_code="$1"
  cat <<PROMPT
You are a technical documentation compressor specializing in Bash Coding Standard rules.

TASK: The user will provide a source .complete.md file path and an output file path in their prompt. Use the Read tool to read the source file, compress it to .summary.md format, then use the Write tool to write the compressed result to the output file path.

TARGET SIZE: Maximum 10,000 bytes (strict limit)

CRITICAL REQUIREMENTS (NON-NEGOTIABLE):
1. FIRST LINE: Must be markdown header matching file depth:
   - If file contains "/data/##-section/##-rule/" (3 levels) → Use "###" (subrule)
   - If file contains "/data/##-section/" only (2 levels) → Use "##" (rule)
   - If filename starts with "00-section" → Use "#" (section)
2. NEVER alter, simplify, or change code examples - preserve EXACT syntax
3. NEVER lose salient technical details - accuracy is paramount
4. Keep ALL rationale points (may condense wording, not content)
5. Keep 3-5 most critical anti-patterns with examples
6. Keep 2-3 most important edge cases
7. Preserve all code blocks completely
8. Maintain technical precision in all statements

COMPRESSION APPROACH:
- Remove verbose explanations while keeping technical facts
- Consolidate similar examples (but don't modify their content)
- Keep measurable/specific details (performance numbers, specific errors)
- Remove obvious elaborations
- Maintain structure: title, rationale, examples, anti-patterns, edge cases

CRITICAL FILE WRITING:
- Use the Write tool to write ONLY the compressed markdown content to the output file
- NO meta-commentary about the compression process in the file
- NO "Summary" sections explaining what you did in the file
- NO lists of "Key achievements" or "Compression techniques used" in the file
- The file content will be directly concatenated into the final document
- Think of the file content as the final published content, not a report about compression
- The file should start immediately with the rule title/content (markdown format)

OUTPUT: Use Write tool to create valid markdown file following .summary.md structure, under 10,000 bytes.
PROMPT
}

build_system_prompt_abstract() {
  local -- bcs_code="$1"
  cat <<PROMPT
You are a technical documentation compressor specializing in Bash Coding Standard rules.

TASK: The user will provide a source .complete.md file path and an output file path in their prompt. Use the Read tool to read the source file, compress it to .abstract.md format (ultra-concise), then use the Write tool to write the compressed result to the output file path.

TARGET SIZE: Maximum 1,500 bytes (ultra-compressed, strict limit)

CRITICAL REQUIREMENTS (NON-NEGOTIABLE):
1. FIRST LINE: Must be markdown header matching file depth:
   - If file contains "/data/##-section/##-rule/" (3 levels) → Use "###" (subrule)
   - If file contains "/data/##-section/" only (2 levels) → Use "##" (rule)
   - If filename starts with "00-section" → Use "#" (section)
2. NEVER alter code examples - preserve EXACT syntax (but use minimal examples)
3. Keep only THE MOST critical technical details
4. Top 2-3 rationale points (most measurable/technical)
5. One minimal but ACCURATE code example (5-8 lines max)
6. 1-2 most critical anti-patterns only
7. Extreme brevity - every word must add unique value

COMPRESSION APPROACH:
- One-sentence rule statement in bold
- Inline anti-patterns using \`→\` notation where possible
- Remove all elaboration - state fact, move on
- Keep only information that changes behavior or prevents catastrophic errors
- Use minimal examples showing core pattern only

CRITICAL FILE WRITING:
- Use the Write tool to write ONLY the compressed markdown content to the output file
- NO meta-commentary about the compression process in the file
- NO "Summary" sections explaining what you did in the file
- NO lists of "Key achievements" or "Compression techniques used" in the file
- The file content will be directly concatenated into the final document
- Think of the file content as the final published content, not a report about compression
- The file should start immediately with the rule title/content (markdown format)

OUTPUT: Use Write tool to create ultra-concise markdown file following .abstract.md structure, under 1,500 bytes.
PROMPT
}

build_system_prompt_abstract_strict() {
  local -i current_size=$1
  local -- bcs_code="$2"
  cat <<PROMPT
You are a technical documentation compressor specializing in Bash Coding Standard rules.

TASK: The user will provide a source .complete.md file path and an output file path in their prompt. Use the Read tool to read the source file, compress it to .abstract.md format (ultra-concise), then use the Write tool to write the compressed result to the output file path.

TARGET SIZE: Maximum 1,500 bytes (STRICT - previous attempt was $current_size bytes)

CRITICAL REQUIREMENTS (NON-NEGOTIABLE):
1. FIRST LINE: Must be markdown header matching file depth:
   - If file contains "/data/##-section/##-rule/" (3 levels) → Use "###" (subrule)
   - If file contains "/data/##-section/" only (2 levels) → Use "##" (rule)
   - If filename starts with "00-section" → Use "#" (section)
2. NEVER alter code examples - preserve EXACT syntax
3. RUTHLESSLY remove all non-essential text
4. ONE rationale point only (most critical)
5. ONE minimal code example (3-5 lines max)
6. ONE anti-pattern maximum
7. Ultra-extreme brevity - remove all elaboration

COMPRESSION APPROACH:
- Single sentence rule in bold
- Inline examples using backticks where possible instead of code blocks
- Remove all explanatory text
- Keep ONLY information that prevents critical errors
- Abbreviate aggressively

CRITICAL FILE WRITING:
- Use the Write tool to write ONLY the compressed markdown content to the output file
- NO meta-commentary about the compression process in the file
- NO "Summary" sections explaining what you did in the file
- NO lists of "Key achievements" or "Compression techniques used" in the file
- The file content will be directly concatenated into the final document
- Think of the file content as the final published content, not a report about compression
- The file should start immediately with the rule title/content (markdown format)

OUTPUT: Use Write tool to create ultra-minimal markdown file, MUST be under 1,500 bytes.
PROMPT
}

build_system_prompt_summary_strict() {
  local -i current_size=$1
  local -- bcs_code="$2"
  cat <<PROMPT
You are a technical documentation compressor specializing in Bash Coding Standard rules.

TASK: The user will provide a source .complete.md file path and an output file path in their prompt. Use the Read tool to read the source file, compress it to .summary.md format (balanced version), then use the Write tool to write the compressed result to the output file path.

TARGET SIZE: Maximum 10,000 bytes (STRICT - previous attempt was $current_size bytes)

CRITICAL REQUIREMENTS (NON-NEGOTIABLE):
1. FIRST LINE: Must be markdown header matching file depth:
   - If file contains "/data/##-section/##-rule/" (3 levels) → Use "###" (subrule)
   - If file contains "/data/##-section/" only (2 levels) → Use "##" (rule)
   - If filename starts with "00-section" → Use "#" (section)
2. NEVER alter code examples - preserve EXACT syntax
3. Reduce rationale to 2-3 key points
4. Keep 2-3 most critical anti-patterns only
5. Keep 1-2 most important edge cases
6. Preserve code blocks but remove verbose explanations
7. Remove all redundant elaboration

COMPRESSION APPROACH:
- Remove all verbose explanations and elaboration
- Consolidate similar examples (keep syntax exact)
- Cut non-essential edge cases
- Remove obvious statements
- Keep structure but minimize prose

CRITICAL FILE WRITING:
- Use the Write tool to write ONLY the compressed markdown content to the output file
- NO meta-commentary about the compression process in the file
- NO "Summary" sections explaining what you did in the file
- NO lists of "Key achievements" or "Compression techniques used" in the file
- The file content will be directly concatenated into the final document
- Think of the file content as the final published content, not a report about compression
- The file should start immediately with the rule title/content (markdown format)

OUTPUT: Use Write tool to create concise markdown file following .summary.md structure, MUST be under 10,000 bytes.
PROMPT
}

check_timestamps_match() {
  local -- complete_file=$1
  local -- summary_file=$2
  local -- abstract_file=$3

  # All three files must exist
  [[ -f "$complete_file" && -f "$summary_file" && -f "$abstract_file" ]] || return 1

  # Get modification times
  local -- complete_mtime summary_mtime abstract_mtime
  complete_mtime=$(stat -c '%Y' "$complete_file" 2>/dev/null) || return 1
  summary_mtime=$(stat -c '%Y' "$summary_file" 2>/dev/null) || return 1
  abstract_mtime=$(stat -c '%Y' "$abstract_file" 2>/dev/null) || return 1

  # Check if all three timestamps match
  [[ "$complete_mtime" == "$summary_mtime" && "$summary_mtime" == "$abstract_mtime" ]]
}

compress_rule_to_tier() {
  local -- complete_file=$1
  local -- tier=$2
  local -i target_size=${data_size_limit[$tier]}
  local -i max_retries=3

  # Extract base name: /path/01-layout.complete.md → 01-layout
  local -- basename=${complete_file##*/}
  basename=${basename%.complete.md}

  # Generate target filename
  local -- target_dir=${complete_file%/*}
  local -- target_file="$target_dir/$basename.$tier.md"

  # Calculate BCS code for this file
  local -- bcs_code
  bcs_code=$(get_bcs_code "$complete_file") || bcs_code='BCS????'

  vecho "  → Generating .$tier.md (BCS: $bcs_code)..."

  # Delete existing file if in regenerate mode
  if ((REGENERATE)) && [[ -f "$target_file" ]]; then
    if ((DRY_RUN)); then
      info "  [DRY-RUN] Would delete: $target_file"
    else
      rm -f "$target_file" || warn "Failed to delete: $target_file"
    fi
  fi

  # Skip if file exists and not in regenerate mode
  if [[ -f "$target_file" ]] && ! ((REGENERATE)); then
    vecho "  ✓ Already exists: $target_file"
    return 0
  fi

  if ((DRY_RUN)); then
    info "  [DRY-RUN] Would generate: $target_file"
    return 0
  fi

  # Retry loop for oversized files
  local -i attempt=1
  local -i file_size=0
  local -- temp_file system_prompt

  while ((attempt <= max_retries)); do
    # Build system prompt based on tier and attempt
    if ((attempt == 1)); then
      # First attempt - standard prompt
      if [[ "$tier" == 'summary' ]]; then
        system_prompt=$(build_system_prompt_summary "$bcs_code")
      else
        system_prompt=$(build_system_prompt_abstract "$bcs_code")
      fi
    else
      # Retry with stricter prompt
      if [[ "$tier" == 'summary' ]]; then
        system_prompt=$(build_system_prompt_summary_strict "$file_size" "$bcs_code")
      else
        system_prompt=$(build_system_prompt_abstract_strict "$file_size" "$bcs_code")
      fi
      warn "  ↻ Retry attempt $attempt with stricter compression..."
    fi

    # Create temporary file for atomic write
    temp_file=$(mktemp) || die 1 'Failed to create temporary file'

    # Invoke Claude with file paths as prompt (Read/Write tools enabled)
    if "$CLAUDE_CMD" --print --dangerously-skip-permissions \
       --allowedTools "Read" "Write" \
       --system-prompt "$system_prompt" \
       "Read file: $complete_file | Write compressed output to: $temp_file" \
       2>&1 | tee /dev/stderr; then

      # Check file size
      file_size=$(wc -c < "$temp_file")

      # Check if size is acceptable
      if ((file_size <= target_size)); then
        # Success - move temp file to target
        mv "$temp_file" "$target_file" || die 1 "Failed to write: $target_file"

        # Copy permissions, ownership, and timestamp from source .complete.md file
        chmod --reference="$complete_file" "$target_file" 2>/dev/null || true
        chown --reference="$complete_file" "$target_file" 2>/dev/null || true
        touch --reference="$complete_file" "$target_file" || \
          warn "Failed to sync timestamp for: $target_file"

        success "  ✓ Generated ($file_size bytes): $target_file"
        return 0  # Success
      else
        # Oversized - retry or give up
        if ((attempt < max_retries)); then
          warn "  ⚠ OVERSIZED ($file_size bytes > $target_size) - retrying..."
          rm -f "$temp_file"
          attempt+=1
        else
          # Max retries reached - keep the oversized file
          mv "$temp_file" "$target_file" || die 1 "Failed to write: $target_file"

          chmod --reference="$complete_file" "$target_file" 2>/dev/null || true
          chown --reference="$complete_file" "$target_file" 2>/dev/null || true
          touch --reference="$complete_file" "$target_file" || \
            warn "Failed to sync timestamp for: $target_file"

          warn "  ⚠ OVERSIZED ($file_size bytes > $target_size): $target_file"
          return 2  # Oversized
        fi
      fi
    else
      # Claude invocation failed
      [[ -f "$temp_file" ]] && rm -f "$temp_file"
      error "  ✗ FAILED: Claude invocation failed for $target_file"
      return 1  # Failed
    fi
  done

  # Should not reach here
  return 1
}

process_complete_file() {
  local -- complete_file=$1
  local -- relative_path=${complete_file#"$DATAPATH/"}

  # Extract base name for derived files
  local -- basename=${complete_file##*/}
  basename=${basename%.complete.md}
  local -- target_dir=${complete_file%/*}
  local -- summary_file="$target_dir/$basename.summary.md"
  local -- abstract_file="$target_dir/$basename.abstract.md"

  # Check if all three files have matching timestamps (indicating they're in sync)
  if ((REGENERATE)) && check_timestamps_match "$complete_file" "$summary_file" "$abstract_file"; then
    vecho "⊙ SKIP (timestamps match): $relative_path"
    return 0
  fi

  info "Processing: $relative_path"
  total_processed+=1

  # Process summary tier
  if [[ -z "$TIER" || "$TIER" == 'summary' ]]; then
    local -i result
    compress_rule_to_tier "$complete_file" 'summary'
    result=$?

    case $result in
      0) summary_success+=1 ;;
      1) summary_failed+=1 ;;
      2) summary_oversized+=1 ;;
    esac
  fi

  # Process abstract tier
  if [[ -z "$TIER" || "$TIER" == 'abstract' ]]; then
    local -i result
    compress_rule_to_tier "$complete_file" 'abstract'
    result=$?

    case $result in
      0) abstract_success+=1 ;;
      1) abstract_failed+=1 ;;
      2) abstract_oversized+=1 ;;
    esac
  fi
}

process_all_rules() {
  # Find all complete files
  readarray -t complete_files < <(find "$DATAPATH" -type f -name '[0-9][0-9]-*.complete.md' | sort)

  local -i file_count=${#complete_files[@]}

  if ((file_count == 0)); then
    warn 'No .complete.md files found'
    return 0
  fi

  info "Found $file_count .complete.md files"
  echo

  # Process each file
  local -- file
  for file in "${complete_files[@]}"; do
    process_complete_file "$file"
  done
}

show_statistics() {
  cat <<EOF

${BOLD}Compression Statistics${NC}
$(printf '=%.0s' {1..50})

Files processed: $total_processed complete → compressed

Summary files (.summary.md):
  ${GREEN}✓${NC} Within limit: $summary_success
  ${YELLOW}⚠${NC} Oversized:    $summary_oversized
  ${RED}✗${NC} Failed:       $summary_failed

Abstract files (.abstract.md):
  ${GREEN}✓${NC} Within limit: $abstract_success
  ${YELLOW}⚠${NC} Oversized:    $abstract_oversized
  ${RED}✗${NC} Failed:       $abstract_failed

EOF

  if ((summary_oversized + abstract_oversized > 0)); then
    warn 'Some files exceeded size limits - manual compression recommended'
  fi

  if ((summary_failed + abstract_failed > 0)); then
    error 'Some files failed to generate - check Claude CLI configuration'
  fi
}

report_oversized_files() {
  # Original report-only behavior
  cd "$DATAPATH" || die 2 "Cannot access data directory: $DATAPATH"

  local -- type
  for type in complete summary abstract; do
    readarray -t files < <(find "$DATAPATH" -type f -name "*.${type}.md")
    echo "$type: ${#files[@]}"
    echo "Over ${data_size_limit[$type]} bytes:"
    find "$DATAPATH" -type f -name "*.${type}.md" -exec du -b {} + | \
      awk -v limit="${data_size_limit[$type]}" '$1 > limit {printf "    %6d bytes  %s\n", $1, $2}' | \
      sort -rn | \
      sed "s:$DATAPATH/::"
    echo '---'
  done

  echo
  echo "$SCRIPT_NAME: Target: Reduce all files to ~600-1200 bytes for total ~75KB"
  echo "$SCRIPT_NAME: Strategy: Keep 1 example, 1 anti-pattern, brief principle, ref line"
}

# ============================================================================
# main() Function
# ============================================================================

main() {
  # Verify data directory exists
  [[ -d "$DATAPATH" ]] || die 2 "Data directory not found: $DATAPATH"

  # Parse command-line arguments
  while (($#)); do
    case $1 in
      --report-only)     REPORT_ONLY=1
                         REGENERATE=0
                         ;;

      --regenerate)      REGENERATE=1
                         REPORT_ONLY=0
                         ;;

      --tier)            noarg "$@"
                         shift
                         TIER="$1"
                         [[ "$TIER" =~ ^(summary|abstract)$ ]] || \
                           die 22 "Invalid tier: $TIER (must be 'summary' or 'abstract')"
                         ;;

      --claude-cmd)      noarg "$@"
                         shift
                         CLAUDE_CMD="$1"
                         ;;

      -n|--dry-run)      DRY_RUN=1 ;;
      -v|--verbose)      VERBOSE=1 ;;
      -q|--quiet)        VERBOSE=0 ;;

      -h|--help)         usage
                         exit 0
                         ;;

      -V|--version)      echo "$SCRIPT_NAME $VERSION"
                         exit 0
                         ;;

      -[nvqhV]*)         #shellcheck disable=SC2046
                         set -- '' $(printf -- "-%c " $(grep -o . <<<"${1:1}")) "${@:2}"
                         ;;

      -*)                die 22 "Invalid option: $1 (use --help for usage)" ;;
      *)                 die 2  "Unexpected argument: $1" ;;
    esac
    shift
  done

  # Make configuration readonly after parsing
  readonly -- CLAUDE_CMD TIER

  # Execute appropriate mode
  if ((REPORT_ONLY)); then
    # Original behavior - just report
    report_oversized_files
    exit 0
  fi

  # Regenerate mode
  ((DRY_RUN)) && info 'DRY-RUN mode enabled - no changes will be made'

  if ((REGENERATE)); then
    info 'Regenerate mode: will delete and recreate compressed files'
    validate_claude_cli
    process_all_rules
    show_statistics

    if ((DRY_RUN)); then
      info 'Dry-run complete - review output and run without --dry-run to execute'
    else
      success 'Compression complete!'
      echo
      info 'Next steps:'
      info '  1. Review any oversized files listed above'
      info '  2. Manually compress critical oversized files if needed'
      info '  3. Run: ./bcs generate --canonical'
    fi
  fi
}

# ============================================================================
# Script Invocation
# ============================================================================

main "$@"

# ============================================================================
# End Marker
# ============================================================================

#fin
