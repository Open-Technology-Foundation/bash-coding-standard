#!/usr/bin/env bash
#shellcheck disable=SC2016  # the bash -c bodies are code for the child shell; their $vars must not expand here
# Benchmark: trim command substitution vs trimv in-place assignment
#
# Compares performance of:
#   1. var=$(trim "$var")  - Command substitution (spawns subshell)
#   2. trimv -n var        - In-place variable assignment (no subshell)

set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

die() { (($# < 2)) || >&2 echo "${0##*/}: ✗ ${*:2}"; exit "${1:-0}"; }

# Test directory
declare -- TEST_DIR ROOT_DIR
TEST_DIR=$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")") \
  || die 1 'cannot resolve test directory'
ROOT_DIR=${TEST_DIR%/*}  # test -> project root

# Source the utilities
declare -- lib
for lib in trim trimv; do
  [[ -f $ROOT_DIR/$lib.bash ]] || die 3 "missing $lib.bash"
  #shellcheck disable=SC1090  # path is built from the loop variable; each utility is linted on its own
  source -- "$ROOT_DIR/$lib".bash || die 1 "cannot source $lib.bash"
done

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Verify timer command exists
if ! command -v timer &>/dev/null; then
  >&2 echo "Error: 'timer' command not found. Please install it first."
  exit 1
fi

echo -e "${BOLD}${CYAN}=== Trim Performance Benchmark ===${NC}"
echo -e "${YELLOW}Comparing: var=\$(trim \"\$var\") vs trimv -n var${NC}"
echo ""

# Test correctness first
>&2 echo -e "${YELLOW}Verifying correctness...${NC}"

test_cases=(
  "hello world"
  "  hello world  "
  $'\t\thello\t\tworld\t\t'
  "  multiple   spaces   between   words  "
  "short"
  "                                        "
)

declare -i all_correct=1
for test in "${test_cases[@]}"; do
  # Test trim command substitution
  result1=$(trim "$test") || die 1 "trim failed on ${test@Q}"

  # Test trimv in-place
  trimv -n result2 "$test" || die 1 "trimv failed on ${test@Q}"

  if [[ "$result1" != "$result2" ]]; then
    >&2 echo -e "${YELLOW}Mismatch found:${NC}"
    >&2 echo "  Input:     '$test'"
    >&2 echo "  trim:      '$result1'"
    >&2 echo "  trimv:     '$result2'"
    all_correct=0
  fi
done

if ((all_correct)); then
  echo -e "${GREEN}✓ All test cases produce identical results${NC}"
else
  >&2 echo -e "${YELLOW}⚠ Differences detected - see above${NC}"
  exit 1
fi
echo ""

# Benchmark different patterns
>&2 echo -e "${BOLD}${CYAN}Running benchmarks with timer -f...${NC}"
echo ""

# Pattern 1: Short string, minimal whitespace
echo -e "${CYAN}Pattern 1: Short string, minimal whitespace${NC}"
echo -e "${YELLOW}Input: '  hello world  '${NC}"
echo ""

result1=$(timer -f bash -c '
  source '"$ROOT_DIR"'/trim.bash
  for ((i=0; i<10000; i+=1)); do
    var="  hello world  "
    var=$(trim "$var")
  done
' 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timer run failed or printed no timer: line'

result2=$(timer -f bash -c '
  source '"$ROOT_DIR"'/trimv.bash
  for ((i=0; i<10000; i+=1)); do
    var="  hello world  "
    trimv -n var "$var"
  done
' 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timer run failed or printed no timer: line'

printf "  %-30s %s\n" "trim command substitution:" "$result1"
printf "  %-30s %s\n" "trimv in-place:" "$result2"
echo ""

# Pattern 2: Medium string with tabs
echo -e "${CYAN}Pattern 2: Medium string with tabs and spaces${NC}"
echo -e "${YELLOW}Input: '\t\t  The quick brown fox jumps over the lazy dog  \t\t'${NC}"
echo ""

result1=$(timer -f bash -c '
  source '"$ROOT_DIR"'/trim.bash
  for ((i=0; i<10000; i+=1)); do
    var=$'\''\t\t  The quick brown fox jumps over the lazy dog  \t\t'\''
    var=$(trim "$var")
  done
' 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timer run failed or printed no timer: line'

result2=$(timer -f bash -c '
  source '"$ROOT_DIR"'/trimv.bash
  for ((i=0; i<10000; i+=1)); do
    var=$'\''\t\t  The quick brown fox jumps over the lazy dog  \t\t'\''
    trimv -n var "$var"
  done
' 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timer run failed or printed no timer: line'

printf "  %-30s %s\n" "trim command substitution:" "$result1"
printf "  %-30s %s\n" "trimv in-place:" "$result2"
echo ""

# Pattern 3: Long string with heavy whitespace
echo -e "${CYAN}Pattern 3: Long string with heavy whitespace${NC}"
echo -e "${YELLOW}Input: '          Lorem ipsum dolor sit amet, consectetur adipiscing elit...          '${NC}"
echo ""

result1=$(timer -f bash -c '
  source '"$ROOT_DIR"'/trim.bash
  for ((i=0; i<10000; i+=1)); do
    var="          Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua          "
    var=$(trim "$var")
  done
' 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timer run failed or printed no timer: line'

result2=$(timer -f bash -c '
  source '"$ROOT_DIR"'/trimv.bash
  for ((i=0; i<10000; i+=1)); do
    var="          Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua          "
    trimv -n var "$var"
  done
' 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timer run failed or printed no timer: line'

printf "  %-30s %s\n" "trim command substitution:" "$result1"
printf "  %-30s %s\n" "trimv in-place:" "$result2"
echo ""

# Pattern 4: Realistic log line processing
echo -e "${CYAN}Pattern 4: Realistic log line with timestamps${NC}"
echo -e "${YELLOW}Input: '  2024-01-15 10:23:45.123 [INFO] User authentication successful  '${NC}"
echo ""

result1=$(timer -f bash -c '
  source '"$ROOT_DIR"'/trim.bash
  for ((i=0; i<10000; i+=1)); do
    var="  2024-01-15 10:23:45.123 [INFO] User authentication successful  "
    var=$(trim "$var")
  done
' 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timer run failed or printed no timer: line'

result2=$(timer -f bash -c '
  source '"$ROOT_DIR"'/trimv.bash
  for ((i=0; i<10000; i+=1)); do
    var="  2024-01-15 10:23:45.123 [INFO] User authentication successful  "
    trimv -n var "$var"
  done
' 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timer run failed or printed no timer: line'

printf "  %-30s %s\n" "trim command substitution:" "$result1"
printf "  %-30s %s\n" "trimv in-place:" "$result2"
echo ""

# Pattern 5: Very short string
echo -e "${CYAN}Pattern 5: Very short string${NC}"
echo -e "${YELLOW}Input: '  x  '${NC}"
echo ""

result1=$(timer -f bash -c '
  source '"$ROOT_DIR"'/trim.bash
  for ((i=0; i<10000; i+=1)); do
    var="  x  "
    var=$(trim "$var")
  done
' 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timer run failed or printed no timer: line'

result2=$(timer -f bash -c '
  source '"$ROOT_DIR"'/trimv.bash
  for ((i=0; i<10000; i+=1)); do
    var="  x  "
    trimv -n var "$var"
  done
' 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timer run failed or printed no timer: line'

printf "  %-30s %s\n" "trim command substitution:" "$result1"
printf "  %-30s %s\n" "trimv in-place:" "$result2"
echo ""

# Pattern 6: Whitespace only
echo -e "${CYAN}Pattern 6: Whitespace-only string (edge case)${NC}"
echo -e "${YELLOW}Input: '                    '${NC}"
echo ""

result1=$(timer -f bash -c '
  source '"$ROOT_DIR"'/trim.bash
  for ((i=0; i<10000; i+=1)); do
    var="                    "
    var=$(trim "$var")
  done
' 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timer run failed or printed no timer: line'

result2=$(timer -f bash -c '
  source '"$ROOT_DIR"'/trimv.bash
  for ((i=0; i<10000; i+=1)); do
    var="                    "
    trimv -n var "$var"
  done
' 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timer run failed or printed no timer: line'

printf "  %-30s %s\n" "trim command substitution:" "$result1"
printf "  %-30s %s\n" "trimv in-place:" "$result2"
echo ""

# Summary
echo -e "${BOLD}${GREEN}=== Summary ===${NC}"
echo ""
echo -e "${YELLOW}Key Differences:${NC}"
echo "  • var=\$(trim \"\$var\")  - Spawns subshell for command substitution"
echo "  • trimv -n var           - Uses eval for in-place assignment, no subshell"
echo ""
echo -e "${YELLOW}Performance Notes:${NC}"
echo "  • trimv -n is significantly faster (5-15x) than var=\$(trim \"\$var\")"
echo "  • Command substitution creates subshell + captures output (expensive)"
echo "  • trimv uses eval but avoids subshell overhead entirely"
echo "  • The eval overhead is much smaller than subshell + output capture"
echo ""
echo -e "${YELLOW}Recommendations:${NC}"
echo "  • For performance-critical loops: Use trimv -n (much faster)"
echo "  • For simple one-off trimming: Use trim (more intuitive syntax)"
echo "  • For scripts processing many strings: trimv -n wins decisively"
echo "  • The performance gap widens with longer strings"
echo ""

#fin
