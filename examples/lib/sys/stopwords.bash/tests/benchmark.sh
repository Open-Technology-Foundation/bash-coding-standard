#!/bin/bash
# Performance benchmark: Bash vs Python stopwords implementation
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

# Script metadata (error() is not defined yet, so the failure message is inline)
SCRIPT_PATH=$(readlink -en -- "${BASH_SOURCE[0]}") \
  || { >&2 echo 'benchmark.sh: cannot resolve script path'; exit 1; }
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

# Temporary test files; the trap is set before mktemp runs, and cleanup()
# reads a global because main()'s locals are gone when the EXIT trap fires
declare -- TEMP_DIR=''
cleanup() {
  local -i exitcode=${1:-$?}
  trap - EXIT
  [[ -z $TEMP_DIR ]] || rm -rf -- "$TEMP_DIR"
  exit "$exitcode"
}
trap 'cleanup $?' EXIT

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

# Generate test data
generate_test_data() {
  local -i size=$1
  local -- output_file=$2

  # Generate random text with some stopwords
  local -a words=(
    "the" "quick" "brown" "fox" "jumps" "over" "lazy" "dog"
    "a" "an" "and" "or" "but" "if" "then" "else" "when" "where"
    "data" "processing" "analysis" "algorithm" "performance" "benchmark"
    "system" "application" "function" "implementation" "optimization"
    "test" "result" "output" "input" "process" "execute" "run"
  )

  local -i word_count=${#words[@]}
  local -i i

  {
    for ((i=0; i<size; i+=1)); do
      printf '%s ' "${words[RANDOM % word_count]}"
      if ((i % 20 == 19)); then
        printf '\n'
      fi
    done
  } > "$output_file"
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
  print_header "Stopwords Performance Benchmark: Bash vs Python"
  echo ""

  # Test parameters
  local -a test_sizes=(100 500 1000 2000 5000 10000)
  local -i iterations=10

  TEMP_DIR=$(mktemp -d) || { error 'Cannot create a temporary directory'; return 1; }

  printf "%-15s %-15s %-15s %-15s %-10s\n" \
    "Test Size" "Bash (ms)" "Python (ms)" "Difference" "Winner"
  printf "%s\n" "--------------------------------------------------------------------------------"

  local -i test_size bash_time python_time diff
  local -- winner diff_str test_file

  for test_size in "${test_sizes[@]}"; do
    test_file="$TEMP_DIR/test_${test_size}.txt"

    # Generate test data
    generate_test_data "$test_size" "$test_file"

    # Run benchmarks
    bash_time=$(benchmark_bash "$test_file" "$iterations") \
      || { error "Bash benchmark failed at $test_size words"; return 1; }
    python_time=$(benchmark_python "$test_file" "$iterations") \
      || { error "Python benchmark failed at $test_size words"; return 1; }

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

    printf "%-15s %-15s %-15s %-15b %-10s\n" \
      "${test_size} words" \
      "$bash_time" \
      "$python_time" \
      "$diff_str" \
      "$winner"
  done

  echo ""
  print_header "Test Configuration:"
  printf "  Iterations per test: %d\n" "$iterations"
  printf "  Python version: %s\n" "$(python3 --version 2>&1 | cut -d' ' -f2)"
  printf "  Bash version: %s\n" "$BASH_VERSION"
  echo ""
  # A status line, not part of the report
  >&2 print_result 'Benchmark complete!'
}

main "$@"

#fin
