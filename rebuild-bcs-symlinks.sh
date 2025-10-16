#!/usr/bin/env bash
# Rebuild BCS/ directory with numeric-only structure
# Transforms: data/NN-description/MM-rule.tier.md → BCS/NN/MM.tier.md

set -euo pipefail
shopt -s nullglob extglob

SCRIPT_DIR=$(realpath -- "$(dirname "${BASH_SOURCE[0]}")")
readonly SCRIPT_DIR

DATA_DIR="$SCRIPT_DIR/data"
BCS_DIR="$SCRIPT_DIR/BCS"

# Colors for output
declare -- RED=$'\033[0;31m'
declare -- GREEN=$'\033[0;32m'
declare -- YELLOW=$'\033[0;33m'
declare -- BLUE=$'\033[0;34m'
declare -- RESET=$'\033[0m'

info() { printf '%s\n' "$*"; }
success() { printf '%s%s%s\n' "$GREEN" "$*" "$RESET"; }
warn() { printf '%s%s%s\n' "$YELLOW" "$*" "$RESET"; }
error() { >&2 printf '%s%s%s\n' "$RED" "$*" "$RESET"; }

# Extract numeric prefix from filename/dirname
extract_number() {
  local name=$1
  [[ "$name" =~ ^([0-9]{2}) ]] && echo "${BASH_REMATCH[1]}" || echo ""
}

# Create relative symlink
create_symlink() {
  local target=$1
  local link=$2
  local link_dir
  link_dir=$(dirname "$link")

  # Calculate relative path from link to target
  local rel_path
  rel_path=$(realpath --relative-to="$link_dir" "$target")

  ln -sf "$rel_path" "$link"
}

main() {
  info "Rebuilding BCS/ directory with numeric-only structure..."
  info ""

  # Backup existing BCS/ directory
  if [[ -d "$BCS_DIR" ]]; then
    warn "Removing existing BCS/ directory..."
    rm -rf "$BCS_DIR"
  fi

  # Create fresh BCS/ directory
  mkdir -p "$BCS_DIR"
  success "Created $BCS_DIR/"
  info ""

  # Process header files (00-header.*.md)
  info "${BLUE}Processing header files...${RESET}"
  for tier in complete summary abstract; do
    local src="$DATA_DIR/00-header.$tier.md"
    local dst="$BCS_DIR/00.$tier.md"
    if [[ -f "$src" ]]; then
      create_symlink "$src" "$dst"
      success "  00.$tier.md → data/00-header.$tier.md"
    fi
  done
  info ""

  # Process section directories
  for section_dir in "$DATA_DIR"/+([0-9][0-9])-*/; do
    [[ -d "$section_dir" ]] || continue

    local section_name
    section_name=$(basename "$section_dir")
    local section_num
    section_num=$(extract_number "$section_name")

    [[ -z "$section_num" ]] && continue

    info "${BLUE}Processing section $section_num ($section_name)...${RESET}"

    # Create numeric section directory
    local bcs_section_dir="$BCS_DIR/$section_num"
    mkdir -p "$bcs_section_dir"

    # Process section files (NN-description/MM-rule.tier.md)
    for tier in complete summary abstract; do
      for src_file in "$section_dir"/*."$tier".md; do
        [[ -f "$src_file" ]] || continue

        local base_name
        base_name=$(basename "$src_file" ".$tier.md")
        local rule_num
        rule_num=$(extract_number "$base_name")

        [[ -z "$rule_num" ]] && continue

        local dst="$bcs_section_dir/$rule_num.$tier.md"
        create_symlink "$src_file" "$dst"
        success "  $section_num/$rule_num.$tier.md → data/$section_name/$base_name.$tier.md"
      done
    done

    # Process subrule directories (NN-description/MM-rule/)
    for subrule_dir in "$section_dir"/+([0-9][0-9])-*/; do
      [[ -d "$subrule_dir" ]] || continue

      local subrule_name
      subrule_name=$(basename "$subrule_dir")
      local parent_rule_num
      parent_rule_num=$(extract_number "$subrule_name")

      [[ -z "$parent_rule_num" ]] && continue

      info "  ${BLUE}Subrules for rule $parent_rule_num ($subrule_name)...${RESET}"

      # Create numeric subrule directory
      local bcs_subrule_dir="$bcs_section_dir/$parent_rule_num"
      mkdir -p "$bcs_subrule_dir"

      # Process subrule files
      for tier in complete summary abstract; do
        for src_file in "$subrule_dir"/*."$tier".md; do
          [[ -f "$src_file" ]] || continue

          local base_name
          base_name=$(basename "$src_file" ".$tier.md")
          local subrule_num
          subrule_num=$(extract_number "$base_name")

          [[ -z "$subrule_num" ]] && continue

          local dst="$bcs_subrule_dir/$subrule_num.$tier.md"
          create_symlink "$src_file" "$dst"
          success "    $section_num/$parent_rule_num/$subrule_num.$tier.md → data/$section_name/$subrule_name/$base_name.$tier.md"
        done
      done
    done

    info ""
  done

  success "BCS/ directory rebuilt successfully!"
  info ""
  info "Verification:"
  info "  Total symlinks: $(find "$BCS_DIR" -type l | wc -l)"
  info "  Total directories: $(find "$BCS_DIR" -type d | wc -l)"
  info ""
  info "Example checks:"
  info "  ls -l BCS/00.complete.md"
  info "  ls -l BCS/01/01.complete.md"
  info "  ls -l BCS/01/02/01.complete.md"
}

main "$@"

#fin
