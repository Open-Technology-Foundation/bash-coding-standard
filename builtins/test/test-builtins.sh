#!/usr/bin/env bash
# test-builtins.sh - Comprehensive test suite for bash loadable builtins

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
declare -r RESET='\033[0m'

# Test counters
declare -i TESTS_RUN=0
declare -i TESTS_PASSED=0
declare -i TESTS_FAILED=0

# Test results
declare -a FAILED_TESTS=()

# Test helper functions
pass() {
    echo -e "${GREEN}  ✓${RESET} $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

fail() {
    echo -e "${RED}  ✗${RESET} $1"
    FAILED_TESTS+=("$1")
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

test_group() {
    echo ""
    echo -e "${BLUE}Testing: $1${RESET}"
}

info() {
    echo -e "${BLUE}[INFO]${RESET} $*"
}

# Check if builtin is loaded
check_builtin_loaded() {
    local name=$1
    if type -t "$name" | grep -q builtin; then
        return 0
    else
        return 1
    fi
}

# Load builtins before testing
load_builtins() {
    info "Loading builtins for testing..."

    local -a builtins=(basename dirname realpath head cut)
    local -i loaded=0

    for builtin_name in "${builtins[@]}"; do
        local so_file="$TEST_ROOT/${builtin_name}.so"

        if [[ ! -f "$so_file" ]]; then
            echo -e "${RED}Error: $so_file not found${RESET}"
            echo "Run 'make' to build the builtins first"
            exit 1
        fi

        if enable -f "$so_file" "$builtin_name" 2>/dev/null; then
            ((loaded++))
        else
            echo -e "${RED}Error: Failed to load $builtin_name${RESET}"
            exit 1
        fi
    done

    echo -e "${GREEN}✓ Loaded $loaded builtins${RESET}"
}

# Test basename
test_basename() {
    test_group "basename"

    # Basic usage
    local result
    result=$(basename /usr/local/bin/script.sh)
    [[ "$result" == "script.sh" ]] && pass "Basic path" || fail "Basic path"

    # With suffix removal
    result=$(basename /usr/local/bin/script.sh .sh)
    [[ "$result" == "script" ]] && pass "Suffix removal" || fail "Suffix removal"

    # No directory component
    result=$(basename script.sh)
    [[ "$result" == "script.sh" ]] && pass "No directory" || fail "No directory"

    # Root path
    result=$(basename /)
    [[ "$result" == "/" ]] && pass "Root path" || fail "Root path"

    # Multiple arguments with -a
    result=$(basename -a /path/one /path/two)
    [[ "$result" == $'one\ntwo' ]] && pass "Multiple arguments (-a)" || fail "Multiple arguments (-a)"

    # With -s option
    result=$(basename -s .txt /path/file.txt)
    [[ "$result" == "file" ]] && pass "Suffix with -s" || fail "Suffix with -s"

    # Zero termination
    result=$(basename -z /path/file | od -An -tx1 | tr -d ' \n')
    [[ "$result" == *"00" ]] && pass "Zero termination (-z)" || fail "Zero termination (-z)"
}

# Test dirname
test_dirname() {
    test_group "dirname"

    # Basic usage
    local result
    result=$(dirname /usr/local/bin/script.sh)
    [[ "$result" == "/usr/local/bin" ]] && pass "Basic path" || fail "Basic path"

    # No directory component
    result=$(dirname script.sh)
    [[ "$result" == "." ]] && pass "No directory (current dir)" || fail "No directory (current dir)"

    # Root path
    result=$(dirname /)
    [[ "$result" == "/" ]] && pass "Root path" || fail "Root path"

    # Nested path
    result=$(dirname /a/b/c/d)
    [[ "$result" == "/a/b/c" ]] && pass "Nested path" || fail "Nested path"

    # Multiple arguments
    result=$(dirname /path/one /path/two)
    [[ "$result" == $'/path\n/path' ]] && pass "Multiple arguments" || fail "Multiple arguments"

    # Zero termination
    result=$(dirname -z /path/file | od -An -tx1 | tr -d ' \n')
    [[ "$result" == *"00" ]] && pass "Zero termination (-z)" || fail "Zero termination (-z)"
}

# Test realpath
test_realpath() {
    test_group "realpath"

    # Current directory
    local result
    result=$(realpath .)
    [[ "$result" == "$PWD" ]] && pass "Current directory" || fail "Current directory"

    # Absolute path (should remain unchanged)
    result=$(realpath /usr/bin)
    [[ "$result" == "/usr/bin" ]] && pass "Absolute path" || fail "Absolute path"

    # Relative path
    result=$(realpath .. 2>/dev/null || echo "FAILED")
    [[ "$result" != "FAILED" ]] && pass "Relative path" || fail "Relative path"

    # Non-existent path with -m
    result=$(realpath -m /this/does/not/exist 2>/dev/null || echo "FAILED")
    [[ "$result" != "FAILED" ]] && pass "Non-existent with -m" || fail "Non-existent with -m"

    # Quiet mode
    result=$(realpath -q /nonexistent/path 2>&1)
    [[ -z "$result" ]] && pass "Quiet mode (-q)" || fail "Quiet mode (-q)"
}

# Test head
test_head() {
    test_group "head"

    # Create test file
    local test_file
    test_file=$(mktemp)
    for i in {1..20}; do
        echo "Line $i" >> "$test_file"
    done

    # Default (10 lines)
    local result
    result=$(head "$test_file" | wc -l)
    [[ "$result" -eq 10 ]] && pass "Default 10 lines" || fail "Default 10 lines"

    # Custom line count
    result=$(head -n 5 "$test_file" | wc -l)
    [[ "$result" -eq 5 ]] && pass "Custom line count (-n 5)" || fail "Custom line count (-n 5)"

    # From stdin
    result=$(echo -e "line1\nline2\nline3" | head -n 2 | wc -l)
    [[ "$result" -eq 2 ]] && pass "From stdin" || fail "From stdin"

    # First line content
    result=$(head -n 1 "$test_file")
    [[ "$result" == "Line 1" ]] && pass "First line content" || fail "First line content"

    # Quiet mode (no headers)
    result=$(head -q -n 1 "$test_file" "$test_file" | grep -c "Line 1")
    [[ "$result" -eq 2 ]] && pass "Quiet mode (-q)" || fail "Quiet mode (-q)"

    # Clean up
    rm -f "$test_file"
}

# Test cut
test_cut() {
    test_group "cut"

    # Field extraction
    local result
    result=$(echo "one:two:three" | cut -d: -f2)
    [[ "$result" == "two" ]] && pass "Field extraction (-f2)" || fail "Field extraction (-f2)"

    # Multiple fields
    result=$(echo "a:b:c:d" | cut -d: -f1,3)
    [[ "$result" == "a:c" ]] && pass "Multiple fields (-f1,3)" || fail "Multiple fields (-f1,3)"

    # Field range
    result=$(echo "a:b:c:d:e" | cut -d: -f2-4)
    [[ "$result" == "b:c:d" ]] && pass "Field range (-f2-4)" || fail "Field range (-f2-4)"

    # Character extraction
    result=$(echo "hello" | cut -c1-3)
    [[ "$result" == "hel" ]] && pass "Character range (-c1-3)" || fail "Character range (-c1-3)"

    # Byte extraction
    result=$(echo "hello" | cut -b1,3,5)
    [[ "$result" == "hlo" ]] && pass "Byte selection (-b1,3,5)" || fail "Byte selection (-b1,3,5)"

    # Suppress lines without delimiter
    result=$(echo -e "has:delimiter\nno-delimiter" | cut -d: -f1 -s)
    [[ "$result" == "has" ]] && pass "Suppress no-delim (-s)" || fail "Suppress no-delim (-s)"

    # From stdin
    result=$(echo "field1:field2:field3" | cut -d: -f2)
    [[ "$result" == "field2" ]] && pass "From stdin" || fail "From stdin"
}

# Performance comparison test
test_performance() {
    test_group "Performance Comparison"

    local iterations=1000
    local test_path="/usr/local/bin/test.sh"

    info "Running $iterations iterations..."

    # Test builtin basename
    local start end builtin_time external_time
    start=$(date +%s%N)
    for ((i=0; i<iterations; i++)); do
        basename "$test_path" >/dev/null
    done
    end=$(date +%s%N)
    builtin_time=$((end - start))

    # Temporarily disable builtin
    enable -d basename 2>/dev/null || true

    # Test external basename (if available)
    if command -v /usr/bin/basename >/dev/null 2>&1; then
        start=$(date +%s%N)
        for ((i=0; i<iterations; i++)); do
            /usr/bin/basename "$test_path" >/dev/null
        done
        end=$(date +%s%N)
        external_time=$((end - start))

        # Re-enable builtin
        enable -f "$TEST_ROOT/basename.so" basename

        local speedup=$((external_time / builtin_time))
        echo -e "  ${GREEN}Builtin:${RESET}  ${builtin_time}ns total"
        echo -e "  ${YELLOW}External:${RESET} ${external_time}ns total"
        echo -e "  ${BLUE}Speedup:${RESET}  ${speedup}x faster"

        if ((speedup > 1)); then
            pass "Performance gain verified"
        else
            fail "Performance gain expected but not seen"
        fi
    else
        echo -e "  ${YELLOW}⚠${RESET} External basename not found, skipping comparison"
        ((TESTS_RUN++))
    fi
}

# Builtin status check
test_builtin_status() {
    test_group "Builtin Status"

    local -a builtins=(basename dirname realpath head cut)

    for builtin_name in "${builtins[@]}"; do
        if check_builtin_loaded "$builtin_name"; then
            pass "$builtin_name is loaded as builtin"
        else
            fail "$builtin_name is NOT a builtin"
        fi
    done
}

# Main test runner
main() {
    echo "================================================"
    echo "  Bash Loadable Builtins - Test Suite v$VERSION"
    echo "================================================"

    load_builtins

    test_builtin_status
    test_basename
    test_dirname
    test_realpath
    test_head
    test_cut
    test_performance

    # Print summary
    echo ""
    echo "================================================"
    echo "  Test Summary"
    echo "================================================"
    echo ""
    echo -e "Total tests:   $TESTS_RUN"
    echo -e "${GREEN}Passed:${RESET}        $TESTS_PASSED"
    echo -e "${RED}Failed:${RESET}        $TESTS_FAILED"
    echo ""

    if ((TESTS_FAILED > 0)); then
        echo -e "${RED}Failed tests:${RESET}"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  - $test"
        done
        echo ""
        exit 1
    else
        echo -e "${GREEN}✓ All tests passed!${RESET}"
        exit 0
    fi
}

# Run main function
main "$@"

#fin
