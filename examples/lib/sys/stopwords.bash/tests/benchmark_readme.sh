#!/bin/bash
# Performance benchmark using README.md as real-world input
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

# Script metadata (error() is not defined yet, so the failure message is inline)
SCRIPT_PATH=$(readlink -en -- "${BASH_SOURCE[0]}") \
  || { >&2 echo 'benchmark_readme.sh: cannot resolve script path'; exit 1; }
SCRIPT_NAME=${SCRIPT_PATH##*/}
SCRIPT_DIR=${SCRIPT_PATH%/*}
LIB_DIR=${SCRIPT_DIR%/*}

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Source the bash stopwords function
# error() is not defined yet, so the failure messages are inline
declare -r STOPWORDS_LIB="$LIB_DIR"/stopwords
[[ -f $STOPWORDS_LIB ]] \
  || { >&2 echo "$SCRIPT_NAME: missing library ${STOPWORDS_LIB@Q}"; exit 3; }
# shellcheck source=/dev/null
source -- "$STOPWORDS_LIB" \
  || { >&2 echo "$SCRIPT_NAME: cannot source ${STOPWORDS_LIB@Q}"; exit 1; }

# Error message to stderr
error() {
  local -- msg
  for msg in "$@"; do
    >&2 printf '%s: %s\n' "$SCRIPT_NAME" "$msg"
  done
}

# Print colored output
print_header() {
  printf "${BLUE}%s${NC}\n" "$1"
}

print_result() {
  printf "${GREEN}%s${NC}\n" "$1"
}

# Benchmark bash implementation
benchmark_bash() {
  local -- test_file=$1
  local -i iterations=$2

  local -i start end elapsed
  # EPOCHREALTIME has six decimal places: its digits are microseconds
  start=${EPOCHREALTIME//[!0-9]/}

  local -i i
  for ((i=0; i<iterations; i+=1)); do
    # Called as $(...) || ..., where set -e is off: check each run explicitly
    stopwords < "$test_file" > /dev/null || return
  done

  end=${EPOCHREALTIME//[!0-9]/}
  elapsed=$((end - start))

  # Microseconds to milliseconds
  printf '%d' $((elapsed / 1000))
}

# Benchmark python implementation
benchmark_python() {
  local -- test_file=$1
  local -i iterations=$2

  local -i start end elapsed
  # EPOCHREALTIME has six decimal places: its digits are microseconds
  start=${EPOCHREALTIME//[!0-9]/}

  local -i i
  for ((i=0; i<iterations; i+=1)); do
    python3 -- "$SCRIPT_DIR/stopwords_python.py" < "$test_file" > /dev/null || return
  done

  end=${EPOCHREALTIME//[!0-9]/}
  elapsed=$((end - start))

  # Microseconds to milliseconds
  printf '%d' $((elapsed / 1000))
}

# Main benchmark
main() {
  local -- readme_file="$LIB_DIR/README.md"

  if [[ ! -f "$readme_file" ]]; then
    error "README.md not found at $readme_file"
    return 1
  fi

  print_header "Stopwords Performance Benchmark: README.md"
  echo ""

  # File info
  local -- counts
  local -i line_count word_count byte_count
  # wc prints lines, words and bytes in that order, whatever the flag order
  counts=$(wc -lwc < "$readme_file") || { error "Cannot read ${readme_file@Q}"; return 1; }
  read -r line_count word_count byte_count <<< "$counts"

  printf "Input file: %s\n" "$readme_file"
  printf "File size: %d bytes\n" "$byte_count"
  printf "Word count: %d words\n" "$word_count"
  printf "Line count: %d lines\n" "$line_count"
  echo ""

  # Test parameters
  local -i iterations=50

  printf "%-20s %-15s %-15s %-15s %-10s\n" \
    "Test" "Bash (ms)" "Python (ms)" "Difference" "Winner"
  printf "%s\n" "--------------------------------------------------------------------------------"

  local -i bash_time python_time diff
  local -- winner diff_str

  # Run benchmarks
  bash_time=$(benchmark_bash "$readme_file" "$iterations") \
    || { error 'Bash benchmark failed'; return 1; }
  python_time=$(benchmark_python "$readme_file" "$iterations") \
    || { error 'Python benchmark failed'; return 1; }

  # Calculate difference
  diff=$((bash_time - python_time))

  if ((bash_time < python_time)); then
    winner="Bash"
    diff_str="${GREEN}-${diff#-} ms${NC}"
  elif ((python_time < bash_time)); then
    winner="Python"
    diff_str="${RED}+${diff#-} ms${NC}"
  else
    winner="Tie"
    diff_str="${YELLOW}0 ms${NC}"
  fi

  printf "%-20s %-15s %-15s %-15b %-10s\n" \
    "README.md" \
    "$bash_time" \
    "$python_time" \
    "$diff_str" \
    "$winner"

  # Calculate per-iteration time
  local -i bash_per_iter python_per_iter
  bash_per_iter=$((bash_time / iterations))
  python_per_iter=$((python_time / iterations))

  echo ""
  print_header "Per-Iteration Performance:"
  printf "  Bash: %d ms/iteration\n" "$bash_per_iter"
  printf "  Python: %d ms/iteration\n" "$python_per_iter"

  echo ""
  print_header "Test Configuration:"
  printf "  Iterations: %d\n" "$iterations"
  printf "  Python version: %s\n" "$(python3 --version 2>&1 | cut -d' ' -f2)"
  printf "  Bash version: %s\n" "$BASH_VERSION"
  echo ""
  # A status line, not part of the report
  >&2 print_result 'Benchmark complete!'
}

main "$@"

#fin
