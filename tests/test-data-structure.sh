#!/usr/bin/env bash
# Tests for data/ directory structure and BCS code integrity

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Load test helpers
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=tests/test-helpers.sh
source "$SCRIPT_DIR"/test-helpers.sh

PROJECT_DIR="$SCRIPT_DIR"/..
DATA_DIR="$PROJECT_DIR"/data

test_data_directory_exists() {
  test_section "Data Directory Existence Tests"

  if [[ -d "$DATA_DIR" ]]; then
    pass "data/ directory exists"
  else
    fail "data/ directory not found"
    return 1
  fi
}

test_tier_file_completeness() {
  test_section "Tier File Completeness Tests"

  # Find all .complete.md files
  local -a complete_files=()
  while IFS= read -r -d '' file; do
    complete_files+=("$file")
  done < <(find "$DATA_DIR" -type f -name "*.complete.md" -print0 | sort -z)

  local -- missing_count=0
  local -- file basename_without_tier

  for file in "${complete_files[@]}"; do
    basename_without_tier="${file%.complete.md}"

    # Check for corresponding .abstract.md
    if [[ ! -f "$basename_without_tier.abstract.md" ]]; then
      fail "Missing abstract tier for: $(basename "$file")"
      ((missing_count+=1))
    fi

    # Check for corresponding .summary.md
    if [[ ! -f "$basename_without_tier.summary.md" ]]; then
      fail "Missing summary tier for: $(basename "$file")"
      ((missing_count+=1))
    fi
  done

  if [[ "$missing_count" -eq 0 ]]; then
    pass "All complete tier files have corresponding abstract and summary tiers"
  else
    fail "$missing_count tier files missing"
  fi
}

test_numeric_prefixes_zero_padded() {
  test_section "Numeric Prefix Zero-Padding Tests"

  # Check that all numbered files/dirs use zero-padding (01- not 1-)
  local -a non_padded=()
  while IFS= read -r -d '' item; do
    if [[ $(basename "$item") =~ ^[0-9]- ]]; then
      # Single digit without zero padding
      non_padded+=("$item")
    fi
  done < <(find "$DATA_DIR" -type f -o -type d -print0 | sort -z)

  if [[ "${#non_padded[@]}" -eq 0 ]]; then
    pass "All numeric prefixes are zero-padded"
  else
    fail "Found ${#non_padded[@]} items without zero-padding:"
    for item in "${non_padded[@]}"; do
      >&2 echo "  - $(basename "$item")"
    done
  fi
}

test_section_directories_have_section_files() {
  test_section "Section Directory Structure Tests"

  # Find all numbered section directories
  local -a section_dirs=()
  while IFS= read -r -d '' dir; do
    if [[ $(basename "$dir") =~ ^[0-9]{2}- ]]; then
      section_dirs+=("$dir")
    fi
  done < <(find "$DATA_DIR" -maxdepth 1 -type d -print0 | sort -z)

  local -- missing_count=0
  local -- dir

  for dir in "${section_dirs[@]}"; do
    # Check for 00-section.{tier}.md files
    if [[ ! -f "$dir/00-section.complete.md" ]]; then
      fail "Missing 00-section.complete.md in $(basename "$dir")"
      ((missing_count+=1))
    fi

    if [[ ! -f "$dir/00-section.abstract.md" ]]; then
      fail "Missing 00-section.abstract.md in $(basename "$dir")"
      ((missing_count+=1))
    fi

    if [[ ! -f "$dir/00-section.summary.md" ]]; then
      fail "Missing 00-section.summary.md in $(basename "$dir")"
      ((missing_count+=1))
    fi
  done

  if [[ "$missing_count" -eq 0 ]]; then
    pass "All section directories have required 00-section files"
  else
    fail "$missing_count section files missing"
  fi
}

test_bcs_code_uniqueness() {
  test_section "BCS Code Uniqueness Tests"

  # Get all BCS codes from bcs codes command
  local -- codes_output
  codes_output=$("$PROJECT_DIR"/bash-coding-standard codes 2>&1)

  # Extract just the codes
  local -a all_codes=()
  while IFS= read -r line; do
    if [[ "$line" =~ ^(BCS[0-9]+): ]]; then
      all_codes+=("${BASH_REMATCH[1]}")
    fi
  done <<< "$codes_output"

  # Check for duplicates
  local -A seen_codes=()
  local -- code
  local -i duplicate_count=0

  for code in "${all_codes[@]}"; do
    if [[ -n "${seen_codes[$code]:-}" ]]; then
      fail "Duplicate BCS code detected: $code"
      ((duplicate_count+=1))
    else
      seen_codes[$code]=1
    fi
  done

  if [[ "$duplicate_count" -eq 0 ]]; then
    pass "All BCS codes are unique (${#all_codes[@]} codes)"
  else
    fail "$duplicate_count duplicate codes found"
  fi
}

test_file_naming_conventions() {
  test_section "File Naming Convention Tests"

  # Check that all rule files follow NN-descriptive-name.tier.md pattern
  local -a invalid_names=()
  while IFS= read -r -d '' file; do
    local -- basename_file
    basename_file=$(basename "$file")

    # Skip templates directory
    if [[ "$file" =~ /templates/ ]]; then
      continue
    fi

    # Skip README.md files (documentation)
    if [[ "$basename_file" == "README.md" ]]; then
      continue
    fi

    # Skip 00-header files and 00-section files
    if [[ "$basename_file" =~ ^00-(header|section)\. ]]; then
      continue
    fi

    # Valid pattern: NN-something.{complete|abstract|summary}.md
    if [[ ! "$basename_file" =~ ^[0-9]{2}-[a-z0-9-]+\.(complete|abstract|summary)\.md$ ]]; then
      invalid_names+=("$file")
    fi
  done < <(find "$DATA_DIR" -type f -name "*.md" -print0 | sort -z)

  if [[ "${#invalid_names[@]}" -eq 0 ]]; then
    pass "All rule files follow naming convention"
  else
    fail "Found ${#invalid_names[@]} files with invalid names:"
    local -i count=0
    for file in "${invalid_names[@]}"; do
      >&2 echo "  - $(basename "$file")"
      ((count+=1))
      [[ "$count" -ge 10 ]] && break
    done
  fi
}

test_no_alphabetic_suffixes() {
  test_section "No Alphabetic Suffix Tests"

  # Check that no files use patterns like 02a-, 02b- (breaks BCS code system)
  local -a alpha_suffixes=()
  while IFS= read -r -d '' item; do
    if [[ $(basename "$item") =~ ^[0-9]{2}[a-z]- ]]; then
      alpha_suffixes+=("$item")
    fi
  done < <(find "$DATA_DIR" -print0)

  if [[ "${#alpha_suffixes[@]}" -eq 0 ]]; then
    pass "No files/dirs use alphabetic suffixes (e.g., 02a-, 02b-)"
  else
    fail "Found ${#alpha_suffixes[@]} items with alphabetic suffixes:"
    for item in "${alpha_suffixes[@]}"; do
      >&2 echo "  - $(basename "$item")"
    done
  fi
}

test_section_count() {
  test_section "Section Count Consistency Tests"

  # Count section directories in data/
  local -i data_section_count=0
  while IFS= read -r -d '' dir; do
    if [[ $(basename "$dir") =~ ^[0-9]{2}- ]]; then
      ((data_section_count+=1))
    fi
  done < <(find "$DATA_DIR" -maxdepth 1 -type d -print0)

  # Get count from bcs sections
  local -i sections_cmd_count
  sections_cmd_count=$("$PROJECT_DIR"/bash-coding-standard sections 2>&1 | grep -cE '^[0-9]+\.' || true)

  if [[ "$data_section_count" -eq "$sections_cmd_count" ]]; then
    pass "Section count consistent (data/: $data_section_count, sections cmd: $sections_cmd_count)"
  else
    fail "Section count mismatch (data/: $data_section_count, sections cmd: $sections_cmd_count)"
  fi
}

test_bcs_code_decodability() {
  test_section "BCS Code Decodability Tests"

  # Test that all listed codes can be decoded
  local -- codes_output
  codes_output=$("$PROJECT_DIR"/bash-coding-standard codes 2>&1)

  local -a codes=()
  while IFS= read -r line; do
    if [[ "$line" =~ ^(BCS[0-9]+): ]]; then
      codes+=("${BASH_REMATCH[1]}")
    fi
  done <<< "$codes_output"

  # Sample 20 random codes to test (testing all would be too slow)
  local -a sample_codes=()
  local -i i
  for ((i=0; i<20 && i<${#codes[@]}; i++)); do
    sample_codes+=("${codes[$i]}")
  done

  local -i failed_count=0
  local -- code

  for code in "${sample_codes[@]}"; do
    if ! "$PROJECT_DIR"/bash-coding-standard decode "$code" --exists 2>&1 >/dev/null; then
      fail "BCS code $code cannot be decoded"
      ((failed_count+=1))
    fi
  done

  if [[ "$failed_count" -eq 0 ]]; then
    pass "All sampled BCS codes (${#sample_codes[@]}) are decodable"
  else
    fail "$failed_count codes failed to decode"
  fi
}

test_header_files_exist() {
  test_section "Header File Tests"

  # Check for header files in all three tiers
  if [[ -f "$DATA_DIR/00-header.complete.md" ]]; then
    pass "00-header.complete.md exists"
  else
    fail "00-header.complete.md missing"
  fi

  if [[ -f "$DATA_DIR/00-header.abstract.md" ]]; then
    pass "00-header.abstract.md exists"
  else
    fail "00-header.abstract.md missing"
  fi

  if [[ -f "$DATA_DIR/00-header.summary.md" ]]; then
    pass "00-header.summary.md exists"
  else
    fail "00-header.summary.md missing"
  fi
}

# Run all tests
test_data_directory_exists
test_tier_file_completeness
test_numeric_prefixes_zero_padded
test_section_directories_have_section_files
test_bcs_code_uniqueness
test_file_naming_conventions
test_no_alphabetic_suffixes
test_section_count
test_bcs_code_decodability
test_header_files_exist

print_summary

#fin
