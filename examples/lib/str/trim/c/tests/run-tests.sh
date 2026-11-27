#!/usr/bin/env bash
# Run all C-version unit tests. Aggregates pass/fail.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BIN_DIR="$(cd "$TEST_DIR/.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

tests=(
  test-ltrim.sh
  test-rtrim.sh
  test-trim.sh
  test-squeeze.sh
  test-trimall.sh
)

pass=0; fail=0
failed_tests=()

for t in "${tests[@]}"; do
  echo -e "${YELLOW}=== Running $t ===${NC}"
  if bash "$TEST_DIR/$t"; then
    ((pass++))
  else
    ((fail++))
    failed_tests+=("$t")
  fi
  echo
done

echo "===================="
echo -e "Passed: ${GREEN}$pass${NC}"
echo -e "Failed: ${RED}$fail${NC}"
if ((fail)); then
  echo "Failing tests:"
  for f in "${failed_tests[@]}"; do echo "  - $f"; done
  exit 1
fi
echo -e "${GREEN}All test suites passed.${NC}"
exit 0
#fin
