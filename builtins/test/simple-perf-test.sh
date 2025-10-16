#!/usr/bin/env bash
# Simple performance test to verify builtins work

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "Loading builtins..."
for builtin in basename dirname realpath head cut; do
    if [[ -f "./${builtin}.so" ]]; then
        enable -f "./${builtin}.so" "${builtin}" && echo "  ✓ ${builtin} loaded"
    fi
done

echo ""
echo "Running quick performance test (1000 iterations)..."

# Test basename
echo -n "basename: "
start=$(date +%s%N)
for ((i=0; i<1000; i++)); do
    basename /usr/local/bin/test.sh >/dev/null
done
end=$(date +%s%N)
builtin_time=$((end - start))
echo "builtin=${builtin_time}ns"

enable -d basename || true
if command -v /usr/bin/basename >/dev/null 2>&1; then
    echo -n "         "
    start=$(date +%s%N)
    for ((i=0; i<1000; i++)); do
        /usr/bin/basename /usr/local/bin/test.sh >/dev/null
    done
    end=$(date +%s%N)
    external_time=$((end - start))
    speedup=$(awk "BEGIN {printf \"%.2f\", $external_time/$builtin_time}")
    echo " external=${external_time}ns (${speedup}x speedup)"
fi

# Re-enable
enable -f ./basename.so basename

# Test dirname
echo -n "dirname:  "
start=$(date +%s%N)
for ((i=0; i<1000; i++)); do
    dirname /usr/local/bin/test.sh >/dev/null
done
end=$(date +%s%N)
builtin_time=$((end - start))
echo "builtin=${builtin_time}ns"

enable -d dirname || true
if command -v /usr/bin/dirname >/dev/null 2>&1; then
    echo -n "         "
    start=$(date +%s%N)
    for ((i=0; i<1000; i++)); do
        /usr/bin/dirname /usr/local/bin/test.sh >/dev/null
    done
    end=$(date +%s%N)
    external_time=$((end - start))
    speedup=$(awk "BEGIN {printf \"%.2f\", $external_time/$builtin_time}")
    echo " external=${external_time}ns (${speedup}x speedup)"
fi

echo ""
echo "✓ Quick performance test complete"

#fin
