### Exception: One-Word Literals

**Literal one-word values containing only safe characters (alphanumeric, underscore, hyphen, dot, or slash) may be left unquoted in variable assignments and simple conditionals. However, using quotes is more defensive, consistent, and recommended for all but the simplest cases. This exception exists to acknowledge common practice, but when in doubt, quote everything.**

**Rationale:**

- **Common Practice**: Unquoted one-word literals are widely used in shell scripts
- **Readability**: Less visual noise for simple literal values
- **Historical Precedent**: Long-standing shell scripting convention
- **Safety Threshold**: Only truly safe when value contains no special characters
- **Defensive Programming**: Quoting is safer - prevents future bugs if value changes
- **Consistency**: Always quoting eliminates mental overhead of "should I quote this?"
- **Team Preference**: Choice between brevity and defensive programming

**What qualifies as a one-word literal:**

A one-word literal is a value that:
- Contains **only** alphanumeric characters (`a-zA-Z0-9`)
- May include underscores (`_`), hyphens (`-`), dots (`.`), forward slashes (`/`)
- Does **not** contain spaces, tabs, or newlines
- Does **not** contain shell special characters: `*`, `?`, `[`, `]`, `{`, `}`, `$`, `` ` ``, `"`, `'`, `\`, `;`, `&`, `|`, `<`, `>`, `(`, `)`, `!`, `#`
- Does **not** start with a hyphen (in conditionals, could be mistaken for option)

**Examples of one-word literals:**

```bash
# ✓ Safe to leave unquoted (but quoting is better)
ORGANIZATION=Okusi
LOG_LEVEL=INFO
STATUS=success
VERSION=1.0.0
PATH_SUFFIX=/usr/local
FILE_EXT=.tmp
FLAG=true
COUNT=42

# ✗ Must be quoted (contain special characters or spaces)
MESSAGE='Hello world'           # Contains space
ERROR='File not found'          # Contains spaces
PATTERN='*.txt'                 # Contains wildcard
COMMAND='ls -la'                # Contains space
EMAIL='user@domain.com'         # Contains @
NAME='O'\''Reilly'              # Contains apostrophe
```

**Variable assignments:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ Acceptable - one-word literals unquoted
declare -- ORGANIZATION=Okusi
declare -- LOG_LEVEL=INFO
declare -- DEFAULT_PATH=/usr/local/bin
declare -- FILE_EXT=.tmp

# ✓ Better - always quote (defensive programming)
declare -- ORGANIZATION='Okusi'
declare -- LOG_LEVEL='INFO'
declare -- DEFAULT_PATH='/usr/local/bin'
declare -- FILE_EXT='.tmp'

# ✓ MANDATORY - quote multi-word or special values
declare -- APP_NAME='My Application'
declare -- ERROR_MSG='File not found'
declare -- PATTERN='*.log'
declare -- EMAIL='admin@example.com'

# ✗ Wrong - special characters unquoted
declare -- EMAIL=admin@example.com      # @ is special!
declare -- PATTERN=*.log                 # * will glob!
declare -- MESSAGE=Hello world           # Syntax error!

#fin
```

**Conditionals:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

declare -- status='success'
declare -- level='INFO'
declare -- organization='Okusi'

# ✓ Acceptable - one-word literal values unquoted
[[ "$status" == success ]]
[[ "$level" == INFO ]]
[[ "$organization" == Okusi ]]

# ✓ Better - always quote (more consistent)
[[ "$status" == 'success' ]]
[[ "$level" == 'INFO' ]]
[[ "$organization" == 'Okusi' ]]

# ✓ MANDATORY - quote multi-word values
[[ "$message" == 'File not found' ]]
[[ "$pattern" == '*.txt' ]]

# ✗ Wrong - multi-word unquoted
[[ "$message" == File not found ]]      # Syntax error!
[[ "$pattern" == *.txt ]]                # Glob expansion!

# Note: ALWAYS quote the variable being tested
[[ "$status" == success ]]     # ✓ Variable quoted
[[ $status == success ]]       # ✗ Variable unquoted - dangerous!

#fin
```

**Case statement patterns:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ Acceptable - case patterns can be unquoted literals
handle_action() {
  local -- action="$1"

  case "$action" in
    start) start_service ;;      # ✓ One-word literal
    stop) stop_service ;;        # ✓ One-word literal
    restart) restart_service ;;  # ✓ One-word literal
    *) die 22 "Invalid action: $action" ;;
  esac
}

# ✓ Also correct - quote for consistency
handle_action_quoted() {
  local -- action="$1"

  case "$action" in
    'start') start_service ;;
    'stop') stop_service ;;
    'restart') restart_service ;;
    *) die 22 "Invalid action: $action" ;;
  esac
}

# ✓ MANDATORY - quote patterns with special characters
handle_email() {
  local -- email="$1"

  case "$email" in
    'admin@example.com') echo 'Admin user' ;;    # Must quote @
    'user@example.com') echo 'Regular user' ;;   # Must quote @
    *) echo 'Unknown user' ;;
  esac
}

main() {
  handle_action 'start'
  handle_email 'admin@example.com'
}

main "$@"

#fin
```

**Path construction:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ✓ Acceptable - literal path segments unquoted
declare -- temp_file="$PWD"/.foobar.tmp
declare -- config_dir="$HOME"/.config/myapp
declare -- backup="$filename".bak
declare -- log_path=/var/log/myapp.log

# ✓ Better - quote for consistency (recommended)
declare -- temp_file="$PWD/.foobar.tmp"
declare -- config_dir="$HOME/.config/myapp"
declare -- backup="$filename.bak"
declare -- log_path='/var/log/myapp.log'

# ✓ MANDATORY - quote paths with spaces
declare -- docs_dir="$HOME/My Documents"
declare -- app_path='/Applications/My App.app'

# ✗ Wrong - unquoted paths with spaces
declare -- docs_dir=$HOME/My Documents     # Word splitting!
declare -- app_path=/Applications/My App.app  # Syntax error!

#fin
```

**Complete example - Configuration script:**

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# ============================================================================
# Configuration - Mix of quoted and unquoted
# ============================================================================

# Simple one-word values - technically could be unquoted
declare -- APP_NAME='MyApp'           # Single word, but quote for safety
declare -- ENVIRONMENT='production'   # Single word
declare -- LOG_LEVEL='INFO'           # Single word

# Values that MUST be quoted
declare -- DISPLAY_NAME='My Application'  # Contains space
declare -- COPYRIGHT='Copyright © 2025'   # Contains ©
declare -- ERROR_MSG='Operation failed'   # Contains space

# Paths - quote for safety
declare -- CONFIG_DIR='/etc/myapp'
declare -- LOG_DIR='/var/log/myapp'
declare -- DATA_DIR='/var/lib/myapp'

# Derived paths
declare -- CONFIG_FILE="$CONFIG_DIR/config.conf"
declare -- LOG_FILE="$LOG_DIR/app.log"
declare -- PID_FILE='/var/run/myapp.pid'

readonly -- APP_NAME ENVIRONMENT LOG_LEVEL DISPLAY_NAME COPYRIGHT ERROR_MSG
readonly -- CONFIG_DIR LOG_DIR DATA_DIR CONFIG_FILE LOG_FILE PID_FILE

# ============================================================================
# Messaging Functions
# ============================================================================

_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case "${FUNCNAME[1]}" in
    info) prefix+=" ◉" ;;
    warn) prefix+=" ⚠" ;;
    error) prefix+=" ✗" ;;
    success) prefix+=" ✓" ;;
    *) ;;
  esac
  for msg in "$@"; do
    printf '%s %s\n' "$prefix" "$msg"
  done
}

info() { >&2 _msg "$@"; }
warn() { >&2 _msg "$@"; }
error() { >&2 _msg "$@"; }
success() { >&2 _msg "$@"; }

die() {
  local -i exit_code=${1:-1}
  shift
  (($#)) && error "$@"
  exit "$exit_code"
}

# ============================================================================
# Validation Functions
# ============================================================================

# Validate environment - one-word literals in conditionals
validate_environment() {
  local -- env="$1"

  # ✓ Acceptable - one-word literals unquoted in pattern
  case "$env" in
    development|staging|production)
      success "Valid environment: $env"
      return 0
      ;;

    *)
      error "Invalid environment: $env"
      error 'Valid: development, staging, production'
      return 1
      ;;
  esac
}

# Validate log level
validate_log_level() {
  local -- level="$1"

  # ✓ Acceptable - one-word comparisons
  if [[ "$level" == DEBUG || "$level" == INFO || "$level" == WARN || "$level" == ERROR ]]; then
    success "Valid log level: $level"
    return 0
  else
    error "Invalid log level: $level"
    error 'Valid: DEBUG, INFO, WARN, ERROR'
    return 1
  fi
}

# ============================================================================
# Configuration Functions
# ============================================================================

# Display configuration
show_config() {
  info "$APP_NAME Configuration:"
  info "  Display Name: $DISPLAY_NAME"
  info "  Environment: $ENVIRONMENT"
  info "  Log Level: $LOG_LEVEL"
  info "  Config File: $CONFIG_FILE"
  info "  Log File: $LOG_FILE"
  info "  Data Directory: $DATA_DIR"
}

# Validate directories exist
check_directories() {
  local -a required_dirs=(
    "$CONFIG_DIR"
    "$LOG_DIR"
    "$DATA_DIR"
  )

  local -- dir
  local -i missing=0

  for dir in "${required_dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      error "Directory not found: $dir"
      ((missing+=1))
    fi
  done

  ((missing == 0))
}

# ============================================================================
# Main Function
# ============================================================================

main() {
  info "$DISPLAY_NAME v$VERSION"
  info "$COPYRIGHT"
  echo ''

  # Validate environment
  if ! validate_environment "$ENVIRONMENT"; then
    die 1 'Invalid environment configuration'
  fi

  # Validate log level
  if ! validate_log_level "$LOG_LEVEL"; then
    die 1 'Invalid log level configuration'
  fi

  # Show configuration
  show_config
  echo ''

  # Check directories
  if ! check_directories; then
    die 1 'Required directories missing'
  fi

  success 'Configuration valid'
}

main "$@"

#fin
```

**When quotes are mandatory:**

```bash
# ✗ NEVER unquote these:

# 1. Values with spaces
MESSAGE=Hello world                 # Syntax error!
MESSAGE='Hello world'               # ✓ Correct

# 2. Values with wildcards
PATTERN=*.txt                       # Glob expansion!
PATTERN='*.txt'                     # ✓ Correct

# 3. Values with special characters
EMAIL=user@domain.com               # @ is special!
EMAIL='user@domain.com'             # ✓ Correct

# 4. Empty strings
VALUE=                              # Unquoted empty
VALUE=''                            # ✓ Correct

# 5. Values starting with hyphen (in conditionals)
[[ "$arg" == -h ]]                  # Could be option!
[[ "$arg" == '-h' ]]                # ✓ Correct

# 6. Values with parentheses
FILE=test(1).txt                    # () are special!
FILE='test(1).txt'                  # ✓ Correct

# 7. Values with dollar signs
LITERAL='$100'                      # Contains $
# Note: Use single quotes to prevent expansion

# 8. Values with backslashes
PATH='C:\Users\Name'                # Contains \
# Note: Use single quotes to preserve backslashes

# 9. Values with quotes
MESSAGE='It'\''s working'           # Contains apostrophe
MESSAGE="He said \"hello\""         # Contains quotes

# 10. Variable expansions (always quote)
FILE="$basename.txt"                # ✓ Variable quoted
BACKUP="$file.bak"                  # ✓ Variable quoted
```

**Anti-patterns to avoid:**

```bash
# ✗ Wrong - unquoting values that need quotes

# Spaces
MESSAGE=File not found              # Syntax error!
MESSAGE='File not found'            # ✓ Correct

# Special characters
EMAIL=admin@example.com             # @ is special!
EMAIL='admin@example.com'           # ✓ Correct

# Wildcards
PATTERN=*.log                       # Glob expansion!
PATTERN='*.log'                     # ✓ Correct

# Empty values
VAR=                                # Confusing
VAR=''                              # ✓ Clear

# ✗ Wrong - inconsistent quoting
OPTION1=value1                      # Unquoted
OPTION2='value2'                    # Quoted
OPTION3=value3                      # Unquoted
# Pick one style and be consistent!

# ✓ Better - consistent quoting (recommended)
OPTION1='value1'
OPTION2='value2'
OPTION3='value3'

# ✗ Wrong - unquoted paths with spaces
DIR=/home/user/My Documents         # Word splitting!
DIR='/home/user/My Documents'       # ✓ Correct

# ✗ Wrong - unquoted variable concatenation
FILE=$basename.txt                  # Dangerous!
FILE="$basename.txt"                # ✓ Correct

# ✗ Wrong - unquoted in arrays
array=(one two three)               # Each becomes separate element
# This is actually correct for word splitting
# But if you meant literal "two three":
array=('one' 'two three')           # ✓ Correct

# ✗ Wrong - unquoted heredoc delimiter
cat <<EOF                           # Unquoted - variables expand
$VAR
EOF

cat <<'EOF'                         # ✓ Quoted - literal
$VAR
EOF

# ✗ Wrong - unquoted command substitution result
result=$(command)
echo $result                        # Word splitting!
echo "$result"                      # ✓ Correct
```

**Edge cases:**

**1. Numeric values:**

```bash
# Numbers are technically one-word literals
COUNT=42                # ✓ Acceptable (but quoting is safer)
COUNT='42'              # ✓ Better

# But for arithmetic, unquoted is standard
declare -i count=42     # ✓ Correct for integers
((count = 10))          # ✓ Correct in arithmetic context

# In conditionals, quote for consistency
[[ "$count" -eq 42 ]]   # ✓ Variable quoted
[[ "$count" -eq '42' ]] # ✓ Value quoted (pedantic)
```

**2. Boolean-style values:**

```bash
# true/false as strings
ENABLED=true            # ✓ Acceptable
ENABLED='true'          # ✓ Better

# Testing boolean values
[[ "$ENABLED" == true ]]    # ✓ Acceptable
[[ "$ENABLED" == 'true' ]]  # ✓ Better

# As integers (preferred for booleans)
declare -i ENABLED=1
((ENABLED)) && echo 'Enabled'
```

**3. URLs and email addresses:**

```bash
# ✗ Wrong - unquoted (@ and : are special)
URL=https://example.com/path
EMAIL=user@domain.com

# ✓ Correct - must quote
URL='https://example.com/path'
EMAIL='user@domain.com'
```

**4. Version numbers:**

```bash
# Version with dots
VERSION=1.0.0           # ✓ Acceptable (only dots)
VERSION='1.0.0'         # ✓ Better

# Version with hyphen
VERSION=1.0.0-beta      # ✓ Acceptable (alphanumeric, dots, hyphen)
VERSION='1.0.0-beta'    # ✓ Better
```

**5. Paths:**

```bash
# Simple paths
PATH=/usr/local/bin     # ✓ Acceptable
PATH='/usr/local/bin'   # ✓ Better

# Paths with spaces - MUST quote
PATH='/Applications/My App.app'     # ✓ Correct
PATH=/Applications/My App.app       # ✗ Wrong!

# Path construction
CONFIG="$HOME/.config"  # ✓ Variable quoted
CONFIG=$HOME/.config    # ✗ Dangerous - quote the variable!
```

**6. File extensions:**

```bash
# Extensions
EXT=.txt                # ✓ Acceptable
EXT='.txt'              # ✓ Better

# Pattern matching extensions - MUST quote
[[ "$file" == *.txt ]]      # ✓ Glob pattern
[[ "$file" == '*.txt' ]]    # ✓ Literal match
```

**7. Environment detection:**

```bash
# OS detection
OS=Linux                # ✓ Acceptable
OS='Linux'              # ✓ Better

# Testing
[[ "$OS" == Linux ]]    # ✓ Acceptable
[[ "$OS" == 'Linux' ]]  # ✓ Better

# Multiple values
if [[ "$OS" == Linux || "$OS" == Darwin ]]; then
  echo 'Unix-like system'
fi
```

**Recommendation summary:**

**When unquoted is acceptable:**
- Single-word alphanumeric values: `value`, `INFO`, `true`, `42`
- Simple paths with no spaces: `/usr/local/bin`, `/etc/config`
- File extensions: `.txt`, `.log`
- Version numbers: `1.0.0`, `2.5.3-beta`

**When quotes are mandatory:**
- Any value with spaces: `'hello world'`
- Any value with special characters: `'admin@example.com'`, `'*.txt'`
- Empty strings: `''`
- Values with quotes or backslashes: `'don'\''t'`, `'C:\path'`

**Best practice:**
**Always quote everything except the most trivial cases.** When in doubt, quote it. The small reduction in visual noise from omitting quotes on one-word literals is not worth the mental overhead of deciding "should I quote this?" or the risk of bugs when values change.

**Summary:**

- **One-word literals** - alphanumeric, underscore, hyphen, dot, slash only
- **Acceptable unquoted** - in assignments and conditionals (simple cases)
- **Better to quote** - more defensive, prevents future bugs
- **Mandatory quoting** - spaces, special characters, wildcards, empty strings
- **Always quote variables** - `"$var"` not `$var`
- **Consistency matters** - pick quoted or unquoted, stick with it
- **Default to quoting** - when in doubt, quote everything
- **Team preference** - some teams forbid unquoted, others allow for simple cases

**Key principle:** The one-word literal exception exists to acknowledge common practice, not to recommend it. Unquoted literals are a source of subtle bugs when values change. The safest, most consistent approach is to quote everything. Use unquoted literals sparingly, only for the most trivial cases, and never for values that might change or contain special characters. When establishing team standards, consider requiring quotes everywhere - it eliminates an entire category of quoting decisions and makes scripts more robust.
