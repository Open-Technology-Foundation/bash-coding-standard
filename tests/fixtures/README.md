# Test Fixtures

This directory contains test fixtures used by the BCS test suite.

## Directory Structure

### `valid-scripts/`
BCS-compliant test scripts that should pass validation:
- `minimal-compliant.sh` - Minimal BCS-compliant script
- `complete-compliant.sh` - Full-featured BCS-compliant script
- `dual-purpose-compliant.sh` - Dual-purpose (sourceable/executable) script

### `invalid-scripts/`
Non-compliant scripts for negative testing:
- `no-shebang.sh` - Missing shebang
- `no-set-options.sh` - Missing set -euo pipefail
- `no-fin-marker.sh` - Missing #fin end marker
- `wrong-quotes.sh` - Incorrect quoting patterns

### `test-rules/`
Sample BCS rule files for testing data structure:
- `sample-rule.complete.md` - Complete tier rule
- `sample-rule.abstract.md` - Abstract tier rule
- `sample-rule.summary.md` - Summary tier rule

### `templates/`
Expected template outputs for verification:
- `expected-minimal.sh` - Expected minimal template output
- `expected-basic.sh` - Expected basic template output
- `expected-complete.sh` - Expected complete template output
- `expected-library.sh` - Expected library template output

## Usage in Tests

```bash
# Load fixture
source "$(dirname "${BASH_SOURCE[0]}")/fixtures/valid-scripts/minimal-compliant.sh"

# Test against fixture
./bcs check tests/fixtures/valid-scripts/minimal-compliant.sh

# Compare output with expected
diff <(./bcs template -t minimal) tests/fixtures/templates/expected-minimal.sh
```

## Maintenance

- Keep fixtures synchronized with BCS standard updates
- Add new fixtures when new test cases are needed
- Document any special characteristics of fixtures in comments
