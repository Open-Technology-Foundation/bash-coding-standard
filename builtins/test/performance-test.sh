#!/usr/bin/env bash
# performance-test.sh - Performance comparison tests for bash loadable builtins vs external commands
#
# Tests builtin implementations against external commands in realistic script scenarios

set -euo pipefail

# Script metadata
VERSION='1.0.0'
SCRIPT_PATH=$(readlink -en -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
TEST_ROOT=${SCRIPT_DIR%/*}
readonly VERSION SCRIPT_PATH SCRIPT_DIR TEST_ROOT

# Colors for output
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[0;33m'
declare -r BLUE='\033[0;34m'
declare -r CYAN='\033[0;36m'
declare -r MAGENTA='\033[0;35m'
declare -r RESET='\033[0m'

# Test configuration
declare -i ITERATIONS=10000  # Number of iterations for each test
declare -i QUICK_TEST=0      # Quick test mode (fewer iterations)

# Results storage
declare -A BUILTIN_TIMES
declare -A EXTERNAL_TIMES
declare -A SPEEDUPS

# Messaging functions
info() {
    echo -e "${BLUE}[INFO]${RESET} $*"
}

success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $*"
}

warn() {
    echo -e "${YELLOW}[WARNING]${RESET} $*"
}

error() {
    >&2 echo -e "${RED}[ERROR]${RESET} $*"
}

section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${CYAN}  $*${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# Load builtins for testing
load_builtins() {
    info "Loading builtins from $TEST_ROOT..."

    local -a builtins=(basename dirname realpath head cut)
    local -i loaded=0

    for builtin_name in "${builtins[@]}"; do
        local so_file="$TEST_ROOT/${builtin_name}.so"

        if [[ ! -f "$so_file" ]]; then
            error "$so_file not found"
            return 1
        fi

        if enable -f "$so_file" "$builtin_name" 2>/dev/null; then
            ((loaded++))
        else
            error "Failed to load $builtin_name"
            return 1
        fi
    done

    success "Loaded $loaded builtins"
}

# Get high-resolution time in nanoseconds
get_time_ns() {
    date +%s%N
}

# Format nanoseconds to human-readable
format_time() {
    local -i ns=$1
    local -i ms=$((ns / 1000000))
    local -i sec=$((ns / 1000000000))

    if ((sec > 0)); then
        printf "%.3f sec" "$(awk "BEGIN {print $ns/1000000000}")"
    elif ((ms > 0)); then
        printf "%.2f ms" "$(awk "BEGIN {print $ns/1000000}")"
    else
        printf "%d ns" "$ns"
    fi
}

# Calculate speedup
calculate_speedup() {
    local -i external_time=$1
    local -i builtin_time=$2

    if ((builtin_time == 0)); then
        echo "N/A"
    else
        awk "BEGIN {printf \"%.2f\", $external_time/$builtin_time}"
    fi
}

# Test basename performance
test_basename_performance() {
    section "basename Performance Test"

    local test_path="/usr/local/bin/test-file-with-long-name.sh"
    local -i start end builtin_time external_time

    info "Testing basename with $ITERATIONS iterations..."

    # Test builtin version
    echo -n "  Builtin:  "
    start=$(get_time_ns)
    for ((i=0; i<ITERATIONS; i++)); do
        basename "$test_path" >/dev/null
    done
    end=$(get_time_ns)
    builtin_time=$((end - start))
    echo -e "${GREEN}$(format_time $builtin_time)${RESET}"

    # Disable builtin
    enable -d basename 2>/dev/null || true

    # Test external version
    echo -n "  External: "
    if command -v /usr/bin/basename >/dev/null 2>&1; then
        start=$(get_time_ns)
        for ((i=0; i<ITERATIONS; i++)); do
            /usr/bin/basename "$test_path" >/dev/null
        done
        end=$(get_time_ns)
        external_time=$((end - start))
        echo -e "${YELLOW}$(format_time $external_time)${RESET}"

        local speedup
        speedup=$(calculate_speedup "$external_time" "$builtin_time")
        echo -e "  ${MAGENTA}Speedup:  ${speedup}x faster${RESET}"

        BUILTIN_TIMES[basename]=$builtin_time
        EXTERNAL_TIMES[basename]=$external_time
        SPEEDUPS[basename]=$speedup
    else
        warn "External basename not found, skipping comparison"
    fi

    # Re-enable builtin
    enable -f "$TEST_ROOT/basename.so" basename
}

# Test dirname performance
test_dirname_performance() {
    section "dirname Performance Test"

    local test_path="/usr/local/bin/very/long/path/to/some/deeply/nested/file.txt"
    local -i start end builtin_time external_time

    info "Testing dirname with $ITERATIONS iterations..."

    # Test builtin version
    echo -n "  Builtin:  "
    start=$(get_time_ns)
    for ((i=0; i<ITERATIONS; i++)); do
        dirname "$test_path" >/dev/null
    done
    end=$(get_time_ns)
    builtin_time=$((end - start))
    echo -e "${GREEN}$(format_time $builtin_time)${RESET}"

    # Disable builtin
    enable -d dirname 2>/dev/null || true

    # Test external version
    echo -n "  External: "
    if command -v /usr/bin/dirname >/dev/null 2>&1; then
        start=$(get_time_ns)
        for ((i=0; i<ITERATIONS; i++)); do
            /usr/bin/dirname "$test_path" >/dev/null
        done
        end=$(get_time_ns)
        external_time=$((end - start))
        echo -e "${YELLOW}$(format_time $external_time)${RESET}"

        local speedup
        speedup=$(calculate_speedup "$external_time" "$builtin_time")
        echo -e "  ${MAGENTA}Speedup:  ${speedup}x faster${RESET}"

        BUILTIN_TIMES[dirname]=$builtin_time
        EXTERNAL_TIMES[dirname]=$external_time
        SPEEDUPS[dirname]=$speedup
    else
        warn "External dirname not found, skipping comparison"
    fi

    # Re-enable builtin
    enable -f "$TEST_ROOT/dirname.so" dirname
}

# Test realpath performance
test_realpath_performance() {
    section "realpath Performance Test"

    local test_path="."
    local -i start end builtin_time external_time

    info "Testing realpath with $ITERATIONS iterations..."

    # Test builtin version
    echo -n "  Builtin:  "
    start=$(get_time_ns)
    for ((i=0; i<ITERATIONS; i++)); do
        realpath "$test_path" >/dev/null
    done
    end=$(get_time_ns)
    builtin_time=$((end - start))
    echo -e "${GREEN}$(format_time $builtin_time)${RESET}"

    # Disable builtin
    enable -d realpath 2>/dev/null || true

    # Test external version
    echo -n "  External: "
    if command -v /usr/bin/realpath >/dev/null 2>&1; then
        start=$(get_time_ns)
        for ((i=0; i<ITERATIONS; i++)); do
            /usr/bin/realpath "$test_path" >/dev/null
        done
        end=$(get_time_ns)
        external_time=$((end - start))
        echo -e "${YELLOW}$(format_time $external_time)${RESET}"

        local speedup
        speedup=$(calculate_speedup "$external_time" "$builtin_time")
        echo -e "  ${MAGENTA}Speedup:  ${speedup}x faster${RESET}"

        BUILTIN_TIMES[realpath]=$builtin_time
        EXTERNAL_TIMES[realpath]=$external_time
        SPEEDUPS[realpath]=$speedup
    else
        warn "External realpath not found, skipping comparison"
    fi

    # Re-enable builtin
    enable -f "$TEST_ROOT/realpath.so" realpath
}

# Test head performance
test_head_performance() {
    section "head Performance Test"

    local -i start end builtin_time external_time
    local test_file

    # Create test file
    test_file=$(mktemp)
    for i in {1..100}; do
        echo "This is test line number $i with some additional text content" >> "$test_file"
    done

    info "Testing head with $ITERATIONS iterations..."

    # Test builtin version
    echo -n "  Builtin:  "
    start=$(get_time_ns)
    for ((i=0; i<ITERATIONS; i++)); do
        head -n 10 "$test_file" >/dev/null
    done
    end=$(get_time_ns)
    builtin_time=$((end - start))
    echo -e "${GREEN}$(format_time $builtin_time)${RESET}"

    # Disable builtin
    enable -d head 2>/dev/null || true

    # Test external version
    echo -n "  External: "
    if command -v /usr/bin/head >/dev/null 2>&1; then
        start=$(get_time_ns)
        for ((i=0; i<ITERATIONS; i++)); do
            /usr/bin/head -n 10 "$test_file" >/dev/null
        done
        end=$(get_time_ns)
        external_time=$((end - start))
        echo -e "${YELLOW}$(format_time $external_time)${RESET}"

        local speedup
        speedup=$(calculate_speedup "$external_time" "$builtin_time")
        echo -e "  ${MAGENTA}Speedup:  ${speedup}x faster${RESET}"

        BUILTIN_TIMES[head]=$builtin_time
        EXTERNAL_TIMES[head]=$external_time
        SPEEDUPS[head]=$speedup
    else
        warn "External head not found, skipping comparison"
    fi

    # Re-enable builtin
    enable -f "$TEST_ROOT/head.so" head

    # Cleanup
    rm -f "$test_file"
}

# Test cut performance
test_cut_performance() {
    section "cut Performance Test"

    local -i start end builtin_time external_time
    local test_data="field1:field2:field3:field4:field5:field6:field7:field8:field9:field10"

    info "Testing cut with $ITERATIONS iterations..."

    # Test builtin version
    echo -n "  Builtin:  "
    start=$(get_time_ns)
    for ((i=0; i<ITERATIONS; i++)); do
        echo "$test_data" | cut -d: -f5 >/dev/null
    done
    end=$(get_time_ns)
    builtin_time=$((end - start))
    echo -e "${GREEN}$(format_time $builtin_time)${RESET}"

    # Disable builtin
    enable -d cut 2>/dev/null || true

    # Test external version
    echo -n "  External: "
    if command -v /usr/bin/cut >/dev/null 2>&1; then
        start=$(get_time_ns)
        for ((i=0; i<ITERATIONS; i++)); do
            echo "$test_data" | /usr/bin/cut -d: -f5 >/dev/null
        done
        end=$(get_time_ns)
        external_time=$((end - start))
        echo -e "${YELLOW}$(format_time $external_time)${RESET}"

        local speedup
        speedup=$(calculate_speedup "$external_time" "$builtin_time")
        echo -e "  ${MAGENTA}Speedup:  ${speedup}x faster${RESET}"

        BUILTIN_TIMES[cut]=$builtin_time
        EXTERNAL_TIMES[cut]=$external_time
        SPEEDUPS[cut]=$speedup
    else
        warn "External cut not found, skipping comparison"
    fi

    # Re-enable builtin
    enable -f "$TEST_ROOT/cut.so" cut
}

# Realistic scenario: File processing script
test_file_processing_scenario() {
    section "Realistic Scenario: File Processing"

    info "Simulating a script that processes file paths..."

    # Create test directory structure
    local test_dir
    test_dir=$(mktemp -d)
    mkdir -p "$test_dir/src/"{lib,bin,tests}
    touch "$test_dir/src/lib/module1.sh"
    touch "$test_dir/src/lib/module2.sh"
    touch "$test_dir/src/bin/script1.sh"
    touch "$test_dir/src/bin/script2.sh"
    touch "$test_dir/src/tests/test1.sh"

    local -i start end builtin_time external_time
    local -i iterations=$((ITERATIONS / 10))  # Fewer iterations for complex scenario

    info "Running with builtins ($iterations iterations)..."

    # Test with builtins
    start=$(get_time_ns)
    for ((i=0; i<iterations; i++)); do
        while IFS= read -r file; do
            local dir base name
            dir=$(dirname "$file")
            base=$(basename "$file")
            name=$(basename "$file" .sh)
            realpath "$file" >/dev/null 2>&1
        done < <(find "$test_dir" -type f -name "*.sh" 2>/dev/null)
    done
    end=$(get_time_ns)
    builtin_time=$((end - start))
    echo -e "  ${GREEN}Builtin time:  $(format_time $builtin_time)${RESET}"

    # Disable builtins
    enable -d basename dirname realpath 2>/dev/null || true

    info "Running with external commands ($iterations iterations)..."

    # Test with external commands
    start=$(get_time_ns)
    for ((i=0; i<iterations; i++)); do
        while IFS= read -r file; do
            local dir base name
            dir=$(/usr/bin/dirname "$file")
            base=$(/usr/bin/basename "$file")
            name=$(/usr/bin/basename "$file" .sh)
            /usr/bin/realpath "$file" >/dev/null 2>&1
        done < <(find "$test_dir" -type f -name "*.sh" 2>/dev/null)
    done
    end=$(get_time_ns)
    external_time=$((end - start))
    echo -e "  ${YELLOW}External time: $(format_time $external_time)${RESET}"

    local speedup
    speedup=$(calculate_speedup "$external_time" "$builtin_time")
    echo -e "  ${MAGENTA}Scenario speedup: ${speedup}x faster${RESET}"

    # Re-enable builtins
    enable -f "$TEST_ROOT/basename.so" basename
    enable -f "$TEST_ROOT/dirname.so" dirname
    enable -f "$TEST_ROOT/realpath.so" realpath

    # Cleanup
    rm -rf "$test_dir"

    SPEEDUPS[scenario]=$speedup
}

# Realistic scenario: Log processing
test_log_processing_scenario() {
    section "Realistic Scenario: Log Processing"

    info "Simulating a log processing script..."

    # Create test log file
    local log_file
    log_file=$(mktemp)

    for i in {1..1000}; do
        echo "2025-10-13 12:34:56|INFO|user$i|/var/log/app/service$((i%10)).log|Processing request|field1:field2:field3:field4" >> "$log_file"
    done

    local -i start end builtin_time external_time
    local -i iterations=$((ITERATIONS / 100))  # Even fewer for I/O heavy scenario

    info "Processing log file with builtins ($iterations iterations)..."

    # Test with builtins
    start=$(get_time_ns)
    for ((i=0; i<iterations; i++)); do
        while IFS='|' read -r timestamp level user logfile message data; do
            local log_dir log_name field2
            log_dir=$(dirname "$logfile")
            log_name=$(basename "$logfile" .log)
            field2=$(echo "$data" | cut -d: -f2)
        done < "$log_file"
    done
    end=$(get_time_ns)
    builtin_time=$((end - start))
    echo -e "  ${GREEN}Builtin time:  $(format_time $builtin_time)${RESET}"

    # Disable builtins
    enable -d basename dirname cut 2>/dev/null || true

    info "Processing log file with external commands ($iterations iterations)..."

    # Test with external commands
    start=$(get_time_ns)
    for ((i=0; i<iterations; i++)); do
        while IFS='|' read -r timestamp level user logfile message data; do
            local log_dir log_name field2
            log_dir=$(/usr/bin/dirname "$logfile")
            log_name=$(/usr/bin/basename "$logfile" .log)
            field2=$(echo "$data" | /usr/bin/cut -d: -f2)
        done < "$log_file"
    done
    end=$(get_time_ns)
    external_time=$((end - start))
    echo -e "  ${YELLOW}External time: $(format_time $external_time)${RESET}"

    local speedup
    speedup=$(calculate_speedup "$external_time" "$builtin_time")
    echo -e "  ${MAGENTA}Scenario speedup: ${speedup}x faster${RESET}"

    # Re-enable builtins
    enable -f "$TEST_ROOT/basename.so" basename
    enable -f "$TEST_ROOT/dirname.so" dirname
    enable -f "$TEST_ROOT/cut.so" cut

    # Cleanup
    rm -f "$log_file"

    SPEEDUPS[log_processing]=$speedup
}

# Generate performance report
generate_report() {
    section "Performance Test Summary"

    echo ""
    echo "Test Configuration:"
    echo "  Iterations per test: $ITERATIONS"
    echo "  Test date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "  Bash version: $BASH_VERSION"
    echo ""

    echo -e "${CYAN}Individual Builtin Performance:${RESET}"
    echo "┌─────────────┬──────────────┬──────────────┬──────────────┐"
    echo "│   Builtin   │   Builtin    │   External   │   Speedup    │"
    echo "├─────────────┼──────────────┼──────────────┼──────────────┤"

    for builtin in basename dirname realpath head cut; do
        if [[ -n "${BUILTIN_TIMES[$builtin]:-}" ]]; then
            printf "│ %-11s │ %12s │ %12s │ %10sx │\n" \
                "$builtin" \
                "$(format_time "${BUILTIN_TIMES[$builtin]}")" \
                "$(format_time "${EXTERNAL_TIMES[$builtin]}")" \
                "${SPEEDUPS[$builtin]}"
        fi
    done

    echo "└─────────────┴──────────────┴──────────────┴──────────────┘"

    # Calculate average speedup
    local -i total_speedup=0
    local -i count=0
    for builtin in basename dirname realpath head cut; do
        if [[ -n "${SPEEDUPS[$builtin]:-}" ]]; then
            total_speedup=$(awk "BEGIN {printf \"%.0f\", $total_speedup + ${SPEEDUPS[$builtin]}}")
            ((count++))
        fi
    done

    if ((count > 0)); then
        local avg_speedup
        avg_speedup=$(awk "BEGIN {printf \"%.2f\", $total_speedup/$count}")
        echo ""
        echo -e "${MAGENTA}Average speedup: ${avg_speedup}x faster${RESET}"
    fi

    # Realistic scenarios
    if [[ -n "${SPEEDUPS[scenario]:-}" ]] || [[ -n "${SPEEDUPS[log_processing]:-}" ]]; then
        echo ""
        echo -e "${CYAN}Realistic Scenario Performance:${RESET}"

        if [[ -n "${SPEEDUPS[scenario]:-}" ]]; then
            echo -e "  File processing:  ${MAGENTA}${SPEEDUPS[scenario]}x faster${RESET}"
        fi

        if [[ -n "${SPEEDUPS[log_processing]:-}" ]]; then
            echo -e "  Log processing:   ${MAGENTA}${SPEEDUPS[log_processing]}x faster${RESET}"
        fi
    fi

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}  Performance tests completed successfully!${RESET}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# Usage information
usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Performance testing for bash loadable builtins vs external commands.

OPTIONS:
    -q, --quick         Quick test mode (1000 iterations instead of 10000)
    -i, --iterations N  Set number of iterations (default: 10000)
    -h, --help          Show this help message
    -V, --version       Show version information

EXAMPLES:
    # Run full performance test
    $SCRIPT_NAME

    # Quick test
    $SCRIPT_NAME --quick

    # Custom iterations
    $SCRIPT_NAME --iterations 50000

EOF
}

# Main function
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -q|--quick)
                QUICK_TEST=1
                ITERATIONS=1000
                shift
                ;;
            -i|--iterations)
                ITERATIONS=$2
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -V|--version)
                echo "$SCRIPT_NAME $VERSION"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Header
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║  Bash Loadable Builtins - Performance Test Suite v$VERSION        ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""

    if ((QUICK_TEST)); then
        warn "Running in QUICK TEST mode ($ITERATIONS iterations)"
    fi

    # Load builtins
    load_builtins

    # Run individual builtin tests
    test_basename_performance
    test_dirname_performance
    test_realpath_performance
    test_head_performance
    test_cut_performance

    # Run realistic scenario tests
    test_file_processing_scenario
    test_log_processing_scenario

    # Generate report
    generate_report
}

# Run main function
main "$@"

#fin
