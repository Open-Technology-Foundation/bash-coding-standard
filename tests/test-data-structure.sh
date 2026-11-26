#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-data-structure.sh - Validate data directory structure and BCS codes
set -euo pipefail
shopt -s inherit_errexit

declare -rx PATH=~/.local/bin:/usr/local/bin:/usr/bin:/bin

#shellcheck source-path=SCRIPTDIR source=test-helpers.sh
source -- "$(dirname -- "$0")"/test-helpers.sh

echo 'Testing: data structure validation'

# Test: all 12 section files exist
begin_test 'all 12 section files exist'
declare -i found=0
for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
  for f in "$DATA_DIR"/"$i"-*.md; do
    [[ -f "$f" ]] && found+=1 && break
  done
done
assert_equal 12 "$found" 'all 12 section files present' || true

# Test: BASH-CODING-STANDARD.md exists
begin_test 'BASH-CODING-STANDARD.md exists'
assert_file_exists "$DATA_DIR"/BASH-CODING-STANDARD.md || true

# Test: examples/templates directory exists
begin_test 'templates directory exists'
if [[ -d "$PROJECT_DIR"/examples/templates ]]; then
  printf '  %s✓%s templates directory exists\n' "$GREEN" "$NC"
  TESTS_PASSED+=1
else
  printf '  %s✗%s templates directory missing\n' "$RED" "$NC"
  TESTS_FAILED+=1
fi

# Test: all 4 template types exist
for type in minimal basic complete library; do
  begin_test "template $type exists"
  assert_file_exists "$PROJECT_DIR"/examples/templates/"$type".sh.template "$type template exists" || true
done

# Documentation-only sections that intentionally contribute no BCS codes
# (e.g. section 13 documents environment variables, not coding rules).
declare -a NO_CODE_SECTIONS=(13)

_is_no_code_section() {
  local -- needle=$1 item
  for item in "${NO_CODE_SECTIONS[@]}"; do
    [[ $item == "$needle" ]] && return 0
  done
  return 1
}

# Test: each section file starts with # Section N:
begin_test 'section files have proper headers'
declare -i good_headers=0 expected_sections=0
declare -- first_line line f
for f in "$DATA_DIR"/[0-9]*.md; do
  [[ -f $f ]] || continue
  [[ "${f##*/}" == BASH-CODING-STANDARD.md ]] && continue
  [[ "${f##*/}" == 00-* || "${f##*/}" == 99-* ]] && continue
  expected_sections+=1
  # First non-empty, non-SPDX-comment line must be a "# Section N:" header.
  first_line=''
  while IFS= read -r line; do
    [[ -z $line ]] && continue
    [[ $line == '<!--'*'SPDX-License-Identifier:'*'-->' ]] && continue
    first_line=$line
    break
  done < "$f"
  if [[ "$first_line" =~ ^#\ Section\ [0-9]+: ]]; then
    good_headers+=1
  else
    printf '    bad header in %s: %s\n' "${f##*/}" "$first_line"
  fi
done
assert_equal "$expected_sections" "$good_headers" 'all section files have proper headers' || true

# Test: every rule section has at least one BCS code (documentation-only sections excluded)
begin_test 'every rule section has BCS codes'
declare -i sections_with_codes=0 expected_code_sections=0
declare -- section_num
for f in "$DATA_DIR"/[0-9]*.md; do
  [[ -f $f ]] || continue
  [[ "${f##*/}" == BASH-CODING-STANDARD.md ]] && continue
  [[ "${f##*/}" == 00-* || "${f##*/}" == 99-* ]] && continue
  section_num=${f##*/}
  section_num=${section_num:0:2}
  _is_no_code_section "$section_num" && continue
  expected_code_sections+=1
  if grep -q -- '^## BCS[0-9]' "$f"; then
    sections_with_codes+=1
  else
    printf '    no BCS codes in %s\n' "${f##*/}"
  fi
done
assert_equal "$expected_code_sections" "$sections_with_codes" 'all rule sections have BCS codes' || true

# Test: BCS codes are well-formed (BCS followed by 4 digits)
begin_test 'BCS codes are well-formed'
declare -i malformed=0
while IFS= read -r line; do
  if [[ "$line" =~ ^##\ BCS ]] && ! [[ "$line" =~ ^##\ BCS[0-9]{4}\ .+ ]]; then
    printf '    malformed code: %s\n' "$line"
    malformed+=1
  fi
done < <(grep -h -- '^## BCS' "$DATA_DIR"/[0-9]*.md)
assert_equal 0 "$malformed" 'no malformed BCS codes' || true

# Test: no duplicate BCS codes
begin_test 'no duplicate BCS codes'
declare -i duplicates
duplicates=$(grep -h -- '^## BCS[0-9]' "$DATA_DIR"/[0-9]*.md | sort | uniq -d | wc -l) \
  || { printf '    cannot read the section files\n'; duplicates=-1; }
assert_equal 0 "$duplicates" 'no duplicate BCS codes' || true

# Test: BCS codes are sequential within sections
begin_test 'BCS codes follow section numbering'
declare -i mismatched=0
declare -- basename_f section_num code code_section line
for f in "$DATA_DIR"/[0-9]*.md; do
  [[ -f $f ]] || continue
  basename_f=${f##*/}
  [[ "$basename_f" == BASH-CODING-STANDARD.md ]] && continue
  [[ "$basename_f" == 00-* || "$basename_f" == 99-* ]] && continue
  section_num=${basename_f:0:2}
  while IFS= read -r line; do
    if [[ "$line" =~ ^##\ (BCS[0-9]{4}) ]]; then
      code=${BASH_REMATCH[1]}
      code_section=${code:3:2}
      if [[ "$code_section" != "$section_num" ]]; then
        printf '    %s in %s (expected section %s)\n' "$code" "$basename_f" "$section_num"
        mismatched+=1
      fi
    fi
  done < "$f"
done
assert_equal 0 "$mismatched" 'all BCS codes match their section file' || true

# Test: standard document line count is in range
begin_test 'standard document line count in range'
declare -i std_lines
std_lines=$(wc -l < "$DATA_DIR"/BASH-CODING-STANDARD.md) \
  || { printf '    cannot read %s\n' "$DATA_DIR"/BASH-CODING-STANDARD.md; std_lines=0; }
if ((std_lines >= 1500 && std_lines <= 4500)); then
  printf '  %s✓%s line count %d in range [1500-4500]\n' "$GREEN" "$NC" "$std_lines"
  TESTS_PASSED+=1
else
  printf '  %s✗%s line count %d outside range [1500-4500]\n' "$RED" "$NC" "$std_lines"
  TESTS_FAILED+=1
fi

# ---- Fixture manifest ----
# Fixture labels live in tests/fixtures/EXPECT.tsv (path, codes, description),
# never in the fixture: a label inside the file is an answer shown to the model.
declare -r FIXTURES_DIR="$TEST_DIR"/fixtures
declare -r MANIFEST="$FIXTURES_DIR"/EXPECT.tsv
declare -- ON_DISK='' LISTED='' ALL_CODES='' M_PATH='' M_CODES='' M_DESC='' M_CODE='' M_LINE=''
declare -a M_BAD=() M_LIST=()

begin_test 'fixture manifest matches the files one-to-one'
assert_file_exists "$MANIFEST" ||:
ON_DISK=$(cd -- "$FIXTURES_DIR" && printf '%s\n' ./*.sh ./*/*.sh | sed 's|^\./||' | sort) \
  || ON_DISK='(cannot list the fixtures)'
LISTED=$(grep -v -- '^#' "$MANIFEST" | cut -f1 | sort) \
  || LISTED='(cannot read the manifest)'
assert_equal "$ON_DISK" "$LISTED" 'every fixture listed once, every entry a file' ||:
assert_equal '' "$(grep -v -- '^#' "$MANIFEST" | awk -F'\t' 'NF != 3' ||:)" \
  'every entry has three tab-separated fields' ||:

begin_test 'fixture manifest codes'
ALL_CODES=$("$BCS_CMD" codes -p | grep -oE '^BCS[0-9]{4}' ||:)
# Split by hand: tab is IFS whitespace, so `read` would merge the two tabs
# round an empty codes field and shift the description into its place.
while IFS= read -r M_LINE; do
  [[ $M_LINE != '#'* ]] || continue
  M_PATH=${M_LINE%%$'\t'*}
  M_DESC=${M_LINE##*$'\t'}
  M_CODES=${M_LINE#*$'\t'}
  M_CODES=${M_CODES%$'\t'*}
  [[ -n $M_DESC ]] || M_BAD+=("$M_PATH: no description")
  if [[ $M_PATH == clean/* ]]; then
    [[ -z $M_CODES ]] || M_BAD+=("$M_PATH: a clean fixture expects nothing")
    continue
  fi
  [[ -n $M_CODES ]] || M_BAD+=("$M_PATH: no expected code")
  read -ra M_LIST <<< "$M_CODES"
  for M_CODE in "${M_LIST[@]}"; do
    grep -qx -- "$M_CODE" <<< "$ALL_CODES" || M_BAD+=("$M_PATH: $M_CODE is not a rule")
  done
done < "$MANIFEST"
assert_equal '' "${M_BAD[*]}" 'clean entries empty, the rest name real rules' ||:

begin_test 'no label inside a fixture'
assert_equal '' "$(grep -l -- 'bcs-fixture-' "$FIXTURES_DIR"/*.sh "$FIXTURES_DIR"/*/*.sh ||:)" \
  'no bcs-fixture- pragma survives in any fixture' ||:

print_summary 'data-structure'
#fin
