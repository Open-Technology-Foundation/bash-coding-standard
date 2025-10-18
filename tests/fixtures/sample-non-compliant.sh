#!/bin/bash
# Non-compliant script for testing (intentional violations)

# Missing: set -euo pipefail
# Missing: shopt settings
# Missing: script metadata

# Violation: using 'function' keyword
function bad_function() {
  echo "This uses function keyword"  # Violation: bare echo
}

# Violation: unquoted variable
process_file() {
  local file=$1
  if [ -f $file ]; then  # Violations: [ instead of [[, unquoted $file
    cat $file  # Violation: using cat when read could be better
  fi
}

# Violation: no explicit variable declarations
counter=0
items="foo bar baz"  # Violation: space-separated list instead of array

# Violation: using deprecated syntax
for item in $items; do  # Violation: unquoted variable expansion
  counter=$((counter + 1))  # Could use ((counter+=1))
  echo "Item: $item"  # Violation: bare echo
done

# Violation: no main function
# Violation: no error handling
# Violation: no #fin marker
