#!/usr/bin/env bash
# Test coverage analysis for bash-coding-standard
# Analyzes which functions and commands are covered by tests

set -euo pipefail
shopt -s inherit_errexit shift_verbose

# Script metadata
VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
PROJECT_DIR=${SCRIPT_DIR%/*}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR PROJECT_DIR

# Colors
if [[ -t 1 ]]; then
  readonly GREEN=$'\033[0;32m' RED=$'\033[0;31m' YELLOW=$'\033[0;33m' CYAN=$'\033[0;36m' NC=$'\033[0m'
else
  readonly GREEN='' RED='' YELLOW='' CYAN='' NC=''
fi

BCS_SCRIPT="$PROJECT_DIR"/bash-coding-standard

# Coverage data structures
declare -A function_coverage=()
declare -A command_coverage=()
declare -a all_functions=()
declare -a all_commands=()

analyze_bcs_functions() {
  echo "${CYAN}Analyzing bcs script functions...${NC}"

  # Extract all function definitions from bcs script
  while IFS= read -r line; do
    if [[ "$line" =~ ^([a-z_][a-z0-9_]*)\(\) ]]; then
      local -- func="${BASH_REMATCH[1]}"
      all_functions+=("$func")
      function_coverage["$func"]=0
    fi
  done < "$BCS_SCRIPT"

  echo "Found ${#all_functions[@]} functions in bcs script"
}

analyze_bcs_commands() {
  echo "${CYAN}Analyzing bcs subcommands...${NC}"

  # Get all subcommands from bcs help
  local -- help_output
  help_output=$("$BCS_SCRIPT" help 2>&1 || true)

  # Extract command names
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]+(display|about|template|check|compress|codes|generate|search|decode|sections|help) ]]; then
      local -- cmd="${BASH_REMATCH[1]}"
      all_commands+=("$cmd")
      command_coverage["$cmd"]=0
    fi
  done <<< "$help_output"

  echo "Found ${#all_commands[@]} subcommands"
}

analyze_test_coverage() {
  echo "${CYAN}Analyzing test coverage...${NC}"

  # Find all test files
  local -a test_files=()
  while IFS= read -r -d '' file; do
    test_files+=("$file")
  done < <(find "$SCRIPT_DIR" -name 'test-*.sh' -type f -print0 | sort -z)

  echo "Analyzing ${#test_files[@]} test files..."

  local -- test_file
  for test_file in "${test_files[@]}"; do
    local -- content
    content=$(cat "$test_file")

    # Check function coverage
    local -- func
    for func in "${all_functions[@]}"; do
      if [[ "$content" =~ $func ]]; then
        function_coverage["$func"]=1
      fi
    done

    # Check command coverage
    local -- cmd
    for cmd in "${all_commands[@]}"; do
      # Look for patterns like: bcs <command>, "$SCRIPT" <command>
      if [[ "$content" =~ (bcs|SCRIPT\")\ $cmd ]]; then
        command_coverage["$cmd"]=1
      fi
    done
  done
}

calculate_coverage_percentage() {
  local -i total=$1
  local -i covered=$2

  if [[ "$total" -eq 0 ]]; then
    echo "0"
    return
  fi

  local -i percentage=$(( (covered * 100) / total ))
  echo "$percentage"
}

generate_coverage_report() {
  echo
  echo "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo "${CYAN}║  Test Coverage Report                                          ║${NC}"
  echo "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo

  # Function coverage
  echo "${YELLOW}Function Coverage:${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  local -i covered_functions=0
  local -- func

  for func in "${all_functions[@]}"; do
    if [[ "${function_coverage[$func]}" -eq 1 ]]; then
      ((covered_functions+=1))
    fi
  done

  local -i func_percentage
  func_percentage=$(calculate_coverage_percentage "${#all_functions[@]}" "$covered_functions")

  echo "  Total functions:    ${#all_functions[@]}"
  echo "  Covered functions:  ${GREEN}$covered_functions${NC}"
  echo "  Uncovered functions: ${RED}$((${#all_functions[@]} - covered_functions))${NC}"
  echo "  Coverage:           ${GREEN}${func_percentage}%${NC}"
  echo

  # Show uncovered functions
  if [[ "$((${#all_functions[@]} - covered_functions))" -gt 0 ]]; then
    echo "  ${RED}Uncovered functions:${NC}"
    for func in "${all_functions[@]}"; do
      if [[ "${function_coverage[$func]}" -eq 0 ]]; then
        echo "    - $func"
      fi
    done | head -20
    echo
  fi

  # Command coverage
  echo "${YELLOW}Command Coverage:${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  local -i covered_commands=0
  local -- cmd

  for cmd in "${all_commands[@]}"; do
    if [[ "${command_coverage[$cmd]}" -eq 1 ]]; then
      ((covered_commands+=1))
    fi
  done

  local -i cmd_percentage
  cmd_percentage=$(calculate_coverage_percentage "${#all_commands[@]}" "$covered_commands")

  echo "  Total commands:     ${#all_commands[@]}"
  echo "  Covered commands:   ${GREEN}$covered_commands${NC}"
  echo "  Uncovered commands: ${RED}$((${#all_commands[@]} - covered_commands))${NC}"
  echo "  Coverage:           ${GREEN}${cmd_percentage}%${NC}"
  echo

  # Show command coverage details
  for cmd in "${all_commands[@]}"; do
    if [[ "${command_coverage[$cmd]}" -eq 1 ]]; then
      echo "  ${GREEN}✓${NC} $cmd"
    else
      echo "  ${RED}✗${NC} $cmd"
    fi
  done
  echo

  # Overall assessment
  echo "${YELLOW}Overall Assessment:${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  local -i overall_covered=$((covered_functions + covered_commands))
  local -i overall_total=$((${#all_functions[@]} + ${#all_commands[@]}))
  local -i overall_percentage
  overall_percentage=$(calculate_coverage_percentage "$overall_total" "$overall_covered")

  echo "  Overall coverage:   ${GREEN}${overall_percentage}%${NC}"

  if [[ "$overall_percentage" -ge 80 ]]; then
    echo "  Status:             ${GREEN}✓ EXCELLENT${NC}"
  elif [[ "$overall_percentage" -ge 60 ]]; then
    echo "  Status:             ${YELLOW}⚠ GOOD${NC}"
  elif [[ "$overall_percentage" -ge 40 ]]; then
    echo "  Status:             ${YELLOW}⚠ NEEDS IMPROVEMENT${NC}"
  else
    echo "  Status:             ${RED}✗ POOR${NC}"
  fi
  echo
}

generate_html_report() {
  local -- output_file="${1:-coverage-report.html}"

  echo "${CYAN}Generating HTML report: $output_file${NC}"

  cat > "$output_file" <<'HTML_HEADER'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>BCS Test Coverage Report</title>
  <style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background: #f5f5f5; }
    .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    h1 { color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }
    h2 { color: #555; margin-top: 30px; }
    .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
    .stat-card { background: #f9f9f9; padding: 20px; border-radius: 6px; border-left: 4px solid #4CAF50; }
    .stat-value { font-size: 2em; font-weight: bold; color: #4CAF50; }
    .stat-label { color: #666; margin-top: 5px; }
    .coverage-bar { background: #e0e0e0; height: 30px; border-radius: 15px; overflow: hidden; margin: 10px 0; }
    .coverage-fill { background: #4CAF50; height: 100%; display: flex; align-items: center; justify-content: center; color: white; font-weight: bold; }
    .covered { color: #4CAF50; }
    .uncovered { color: #f44336; }
    ul { list-style: none; padding: 0; }
    li { padding: 8px; margin: 4px 0; background: #f9f9f9; border-radius: 4px; }
    .footer { margin-top: 30px; text-align: center; color: #999; font-size: 0.9em; }
  </style>
</head>
<body>
  <div class="container">
    <h1>📊 BCS Test Coverage Report</h1>
    <p>Generated on $(date)</p>
HTML_HEADER

  # Calculate statistics
  local -i covered_functions=0 covered_commands=0
  for func in "${all_functions[@]}"; do
    [[ "${function_coverage[$func]}" -eq 1 ]] && ((covered_functions+=1))
  done
  for cmd in "${all_commands[@]}"; do
    [[ "${command_coverage[$cmd]}" -eq 1 ]] && ((covered_commands+=1))
  done

  local -i func_percentage cmd_percentage
  func_percentage=$(calculate_coverage_percentage "${#all_functions[@]}" "$covered_functions")
  cmd_percentage=$(calculate_coverage_percentage "${#all_commands[@]}" "$covered_commands")

  cat >> "$output_file" <<HTML_STATS
    <div class="stats">
      <div class="stat-card">
        <div class="stat-value">${func_percentage}%</div>
        <div class="stat-label">Function Coverage</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${cmd_percentage}%</div>
        <div class="stat-label">Command Coverage</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">$covered_functions/${#all_functions[@]}</div>
        <div class="stat-label">Functions Tested</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">$covered_commands/${#all_commands[@]}</div>
        <div class="stat-label">Commands Tested</div>
      </div>
    </div>

    <h2>Function Coverage</h2>
    <div class="coverage-bar">
      <div class="coverage-fill" style="width: ${func_percentage}%">${func_percentage}%</div>
    </div>
HTML_STATS

  # Add function details
  echo "    <ul>" >> "$output_file"
  for func in "${all_functions[@]}"; do
    if [[ "${function_coverage[$func]}" -eq 1 ]]; then
      echo "      <li class=\"covered\">✓ $func</li>" >> "$output_file"
    else
      echo "      <li class=\"uncovered\">✗ $func</li>" >> "$output_file"
    fi
  done
  echo "    </ul>" >> "$output_file"

  # Add command coverage
  cat >> "$output_file" <<HTML_COMMANDS
    <h2>Command Coverage</h2>
    <div class="coverage-bar">
      <div class="coverage-fill" style="width: ${cmd_percentage}%">${cmd_percentage}%</div>
    </div>
    <ul>
HTML_COMMANDS

  for cmd in "${all_commands[@]}"; do
    if [[ "${command_coverage[$cmd]}" -eq 1 ]]; then
      echo "      <li class=\"covered\">✓ $cmd</li>" >> "$output_file"
    else
      echo "      <li class=\"uncovered\">✗ $cmd</li>" >> "$output_file"
    fi
  done

  cat >> "$output_file" <<'HTML_FOOTER'
    </ul>
    <div class="footer">
      <p>Generated by bash-coding-standard test coverage analyzer</p>
    </div>
  </div>
</body>
</html>
HTML_FOOTER

  echo "${GREEN}✓${NC} HTML report generated: $output_file"
}

main() {
  echo "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo "${CYAN}║  BCS Test Coverage Analyzer v$VERSION${NC}"
  echo "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo

  analyze_bcs_functions
  analyze_bcs_commands
  analyze_test_coverage
  generate_coverage_report

  # Generate HTML report
  generate_html_report "$PROJECT_DIR/coverage-report.html"

  echo
  echo "${GREEN}✓ Coverage analysis complete${NC}"
}

main "$@"

#fin
