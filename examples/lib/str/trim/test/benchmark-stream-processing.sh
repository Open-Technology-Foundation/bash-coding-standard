#!/usr/bin/env bash
#shellcheck disable=SC2016  # the bash -c bodies are code for the child shell; their $vars must not expand here
# Benchmark: Stream processing comparison
#
# Compares performance of:
#   1. trim < input           - Direct line-by-line processing
#   2. trimv < input          - Direct line-by-line processing (same as trim)
#   3. trimv -n var < input   - Uses temp file (expensive!)

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
  #shellcheck disable=SC1090  # path is built from the loop variable; its existence is checked above
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

echo -e "${BOLD}${CYAN}=== Stream Processing Benchmark ===${NC}"
echo ""

# Create test data files; the trap goes in first so no exit path leaks the dir
declare -- WORK_DIR=''
trap '[[ -z $WORK_DIR ]] || rm -rf -- "$WORK_DIR"' EXIT
WORK_DIR=$(mktemp -d) || die 1 'Failed to create temp dir'

# Create small test file (100 lines)
{
  for ((i=0; i<100; i+=1)); do
    echo "  Line $i with some text and trailing spaces  "
  done
} > "$WORK_DIR/small.txt" || die 1 'cannot write small.txt'

# Create medium test file (1000 lines)
{
  for ((i=0; i<1000; i+=1)); do
    echo "  Line $i with some text and trailing spaces  "
  done
} > "$WORK_DIR/medium.txt" || die 1 'cannot write medium.txt'

# Create large test file (10000 lines)
{
  for ((i=0; i<10000; i+=1)); do
    echo "  Line $i with some text and trailing spaces  "
  done
} > "$WORK_DIR/large.txt" || die 1 'cannot write large.txt'

echo -e "${YELLOW}Test Data Created:${NC}"
echo "  Small:  100 lines"
echo "  Medium: 1,000 lines"
echo "  Large:  10,000 lines"
echo ""

# Test 1: Small file (100 lines)
echo -e "${BOLD}${CYAN}Test 1: Small file (100 lines)${NC}"
echo ""

result1=$(timer -f bash -c '
  source -- "$1"/trim.bash
  for ((i=0; i<100; i+=1)); do
    trim < "$2"/small.txt >/dev/null
  done
' _ "$ROOT_DIR" "$WORK_DIR" 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timing trim on the small file failed'

result2=$(timer -f bash -c '
  source -- "$1"/trimv.bash
  for ((i=0; i<100; i+=1)); do
    trimv < "$2"/small.txt >/dev/null
  done
' _ "$ROOT_DIR" "$WORK_DIR" 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timing trimv on the small file failed'

result3=$(timer -f bash -c '
  source -- "$1"/trimv.bash
  for ((i=0; i<100; i+=1)); do
    trimv -n result < "$2"/small.txt
  done
' _ "$ROOT_DIR" "$WORK_DIR" 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timing trimv -n on the small file failed'

printf "  %-30s %s\n" "trim < file:" "$result1"
printf "  %-30s %s\n" "trimv < file:" "$result2"
printf "  %-30s %s (uses temp file!)\n" "trimv -n var < file:" "$result3"
echo ""

# Test 2: Medium file (1000 lines)
echo -e "${BOLD}${CYAN}Test 2: Medium file (1,000 lines)${NC}"
echo ""

result1=$(timer -f bash -c '
  source -- "$1"/trim.bash
  for ((i=0; i<10; i+=1)); do
    trim < "$2"/medium.txt >/dev/null
  done
' _ "$ROOT_DIR" "$WORK_DIR" 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timing trim on the medium file failed'

result2=$(timer -f bash -c '
  source -- "$1"/trimv.bash
  for ((i=0; i<10; i+=1)); do
    trimv < "$2"/medium.txt >/dev/null
  done
' _ "$ROOT_DIR" "$WORK_DIR" 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timing trimv on the medium file failed'

result3=$(timer -f bash -c '
  source -- "$1"/trimv.bash
  for ((i=0; i<10; i+=1)); do
    trimv -n result < "$2"/medium.txt
  done
' _ "$ROOT_DIR" "$WORK_DIR" 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timing trimv -n on the medium file failed'

printf "  %-30s %s\n" "trim < file:" "$result1"
printf "  %-30s %s\n" "trimv < file:" "$result2"
printf "  %-30s %s (uses temp file!)\n" "trimv -n var < file:" "$result3"
echo ""

# Test 3: Large file (10000 lines)
echo -e "${BOLD}${CYAN}Test 3: Large file (10,000 lines)${NC}"
echo ""

result1=$(timer -f bash -c '
  source -- "$1"/trim.bash
  trim < "$2"/large.txt >/dev/null
' _ "$ROOT_DIR" "$WORK_DIR" 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timing trim on the large file failed'

result2=$(timer -f bash -c '
  source -- "$1"/trimv.bash
  trimv < "$2"/large.txt >/dev/null
' _ "$ROOT_DIR" "$WORK_DIR" 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timing trimv on the large file failed'

result3=$(timer -f bash -c '
  source -- "$1"/trimv.bash
  trimv -n result < "$2"/large.txt
' _ "$ROOT_DIR" "$WORK_DIR" 2>&1 | grep "timer:" | sed 's/# timer: //') || die 1 'timing trimv -n on the large file failed'

printf "  %-30s %s\n" "trim < file:" "$result1"
printf "  %-30s %s\n" "trimv < file:" "$result2"
printf "  %-30s %s (uses temp file!)\n" "trimv -n var < file:" "$result3"
echo ""

# Verify correctness
>&2 echo -e "${YELLOW}Verifying correctness...${NC}"
declare -- trim_result trimv_result var_result=''
trim_result=$(trim < "$WORK_DIR/small.txt") || die 1 'trim failed on the small file'
trimv_result=$(trimv < "$WORK_DIR/small.txt") || die 1 'trimv failed on the small file'
trimv -n var_result < "$WORK_DIR/small.txt" || die 1 'trimv -n failed on the small file'

if [[ "$trim_result" == "$trimv_result" ]] && [[ "$trim_result" == "$var_result" ]]; then
  echo -e "${GREEN}✓ All methods produce identical output${NC}"
else
  >&2 echo -e "${YELLOW}⚠ Output mismatch detected${NC}"
fi
echo ""

# Summary
echo -e "${BOLD}${GREEN}=== Summary ===${NC}"
echo ""
echo -e "${YELLOW}Stream Processing Modes:${NC}"
echo ""
echo "  1. trim < file"
echo "     • Processes line-by-line directly to stdout"
echo "     • Fast and efficient"
echo "     • Use for: Piping data through filters"
echo ""
echo "  2. trimv < file (without -n)"
echo "     • Identical to trim for stream processing"
echo "     • Same performance characteristics"
echo "     • Use for: Alternative syntax, same behavior"
echo ""
echo "  3. trimv -n var < file"
echo "     • Creates temp file with mktemp"
echo "     • Writes all lines to temp file"
echo "     • Reads entire file into variable"
echo "     • Deletes temp file"
echo "     • Much slower due to file I/O overhead"
echo "     • Use for: Capturing multi-line output in a variable"
echo ""
echo -e "${YELLOW}Key Takeaways:${NC}"
echo "  • For stream processing to stdout: Use 'trim' or 'trimv' (equivalent)"
echo "  • For capturing streams in variables: Use 'trimv -n var' but expect overhead"
echo "  • The temp file approach in trimv -n is necessary for variable assignment"
echo "  • For large streams, avoid 'trimv -n' if possible - use direct piping instead"
echo ""
echo -e "${YELLOW}Example Usage:${NC}"
echo "  # Fast: Process and output directly"
echo "  cat logfile.txt | trim > cleaned.txt"
echo ""
echo "  # Slow: Capture in variable (creates temp file)"
echo "  source trimv.bash"
echo "  trimv -n content < logfile.txt"
echo "  echo \"\$content\""
echo ""

#fin
