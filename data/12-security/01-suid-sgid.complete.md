## SUID/SGID

**Never use SUID (Set User ID) or SGID (Set Group ID) bits on Bash scripts. This is a critical security prohibition with no exceptions.**

```bash
# ✗ NEVER do this - catastrophically dangerous
chmod u+s /usr/local/bin/myscript.sh  # SUID
chmod g+s /usr/local/bin/myscript.sh  # SGID

# ✓ Correct - use sudo for elevated privileges
sudo /usr/local/bin/myscript.sh

# ✓ Correct - configure sudoers for specific commands
# In /etc/sudoers:
# username ALL=(ALL) NOPASSWD: /usr/local/bin/myscript.sh
```

**Rationale:**

- **IFS Exploitation**: Attacker can set `IFS` to control word splitting, causing commands to execute with elevated privileges
- **PATH Manipulation**: Even if you set `PATH` in the script, the kernel uses the caller's `PATH` to find the interpreter, allowing trojan attacks
- **Library Injection**: `LD_PRELOAD` and `LD_LIBRARY_PATH` can inject malicious code before script execution
- **Shell Expansion**: Bash performs multiple expansions (brace, tilde, parameter, command substitution, glob) that can be exploited
- **Race Conditions**: TOCTOU (Time Of Check, Time Of Use) vulnerabilities in file operations
- **Interpreter Vulnerabilities**: Bugs in bash itself can be exploited when running with elevated privileges
- **No Compilation**: Unlike compiled programs, script source is readable and modifiable, increasing attack surface

**Why SUID/SGID bits are dangerous on shell scripts:**

SUID/SGID bits change the effective user/group ID to the file owner's UID/GID during execution. For compiled binaries, the kernel loads and executes machine code directly. For shell scripts, the kernel:

1. Reads the shebang (`#!/bin/bash`)
2. Executes the interpreter (`/bin/bash`) with the script as argument
3. The interpreter inherits SUID/SGID privileges
4. The interpreter then processes the script, performing expansions and executing commands

This multi-step process creates numerous attack vectors that don't exist for compiled programs.

**Specific attack examples:**

**1. IFS Exploitation:**

```bash
# Vulnerable SUID script (owned by root)
#!/bin/bash
# /usr/local/bin/vulnerable.sh (SUID root)
set -euo pipefail

# Intended: Check if service is running
service_name="$1"
status=$(systemctl status "$service_name")
echo "$status"
```

**Attack:**
```bash
# Attacker sets IFS to slash
export IFS='/'
./vulnerable.sh "../../etc/shadow"

# With IFS='/', the path is split into words
# systemctl status "../../etc/shadow" might be interpreted as:
# systemctl status ".." ".." "etc" "shadow"
# Depending on systemctl's argument parsing, this could expose sensitive files
```

**2. PATH Attack (interpreter resolution):**

```bash
# SUID script: /usr/local/bin/backup.sh (owned by root)
#!/bin/bash
set -euo pipefail
PATH=/usr/bin:/bin  # Script sets secure PATH

tar -czf /backup/data.tar.gz /var/data
```

**Attack:**
```bash
# Attacker creates malicious bash
mkdir /tmp/evil
cat > /tmp/evil/bash << 'EOF'
#!/bin/bash
# Copy root's SSH keys
cp -r /root/.ssh /tmp/stolen_keys
# Now execute the real script
exec /bin/bash "$@"
EOF
chmod +x /tmp/evil/bash

# Attacker manipulates PATH before executing SUID script
export PATH=/tmp/evil:$PATH
/usr/local/bin/backup.sh

# The kernel uses the caller's PATH to find the interpreter!
# It executes /tmp/evil/bash with SUID privileges
# Attacker's code runs as root BEFORE the script's PATH is set
```

**3. Library Injection Attack:**

```bash
# SUID script: /usr/local/bin/report.sh
#!/bin/bash
set -euo pipefail

# Generate system report
echo "System Report" > /root/report.txt
df -h >> /root/report.txt
```

**Attack:**
```bash
# Attacker creates malicious shared library
cat > /tmp/evil.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void __attribute__((constructor)) init(void) {
    // Runs before main() / script execution
    if (geteuid() == 0) {
        system("cp /etc/shadow /tmp/shadow_copy");
        system("chmod 644 /tmp/shadow_copy");
    }
}
EOF

gcc -shared -fPIC -o /tmp/evil.so /tmp/evil.c

# Execute SUID script with malicious library preloaded
LD_PRELOAD=/tmp/evil.so /usr/local/bin/report.sh

# The malicious library runs with root privileges before the script
```

**4. Command Injection via Unquoted Variables:**

```bash
# Vulnerable SUID script
#!/bin/bash
# /usr/local/bin/cleaner.sh (SUID root)

directory="$1"
# Intended to clean old files
find "$directory" -type f -mtime +30 -delete
```

**Attack:**
```bash
# Attacker injects commands through directory name
/usr/local/bin/cleaner.sh "/tmp -o -name 'shadow' -exec cat /etc/shadow > /tmp/shadow_copy \;"

# The injected find command becomes:
# find /tmp -o -name 'shadow' -exec cat /etc/shadow > /tmp/shadow_copy \; -type f -mtime +30 -delete
# This bypasses the intended logic and exfiltrates /etc/shadow
```

**5. Symlink Race Condition:**

```bash
# Vulnerable SUID script
#!/bin/bash
# /usr/local/bin/secure_write.sh (SUID root)
set -euo pipefail

output_file="$1"

# Check if file is safe to write
if [[ -f "$output_file" ]]; then
  die 1 'File already exists'
fi

# Race condition window here!
# Write sensitive data
echo "secret data" > "$output_file"
```

**Attack:**
```bash
# Terminal 1: Run script repeatedly
while true; do
  /usr/local/bin/secure_write.sh /tmp/output 2>/dev/null && break
done

# Terminal 2: Create symlink in the race window
while true; do
  rm -f /tmp/output
  ln -s /etc/passwd /tmp/output
done

# If timing is right, the script writes to /etc/passwd!
```

**Safe alternatives to SUID/SGID scripts:**

**1. Use sudo with configured permissions:**

```bash
# /etc/sudoers.d/myapp
# Allow specific user to run specific script as root
username ALL=(root) NOPASSWD: /usr/local/bin/myapp.sh

# Allow group to run script with specific arguments
%admin ALL=(root) /usr/local/bin/backup.sh --backup-only
```

**2. Use capabilities instead of full SUID:**

```bash
# For compiled programs (not scripts), use capabilities
# Grant only specific privileges needed
setcap cap_net_bind_service=+ep /usr/local/bin/myserver

# This allows binding to ports < 1024 without full root
```

**3. Use a setuid wrapper (compiled C program):**

```bash
# Wrapper validates input, then executes script as root
# /usr/local/bin/backup_wrapper.c (compiled and SUID)
int main(int argc, char *argv[]) {
    // Validate arguments
    if (argc != 2) return 1;

    // Sanitize PATH
    setenv("PATH", "/usr/bin:/bin", 1);

    // Clear dangerous environment variables
    unsetenv("LD_PRELOAD");
    unsetenv("LD_LIBRARY_PATH");
    unsetenv("IFS");

    // Execute script with validated environment
    execl("/usr/local/bin/backup.sh", "backup.sh", argv[1], NULL);
    return 1;
}
```

**4. Use PolicyKit (pkexec) for GUI applications:**

```bash
# Define policy action in /usr/share/polkit-1/actions/
# Use pkexec to execute with elevated privileges
pkexec /usr/local/bin/system-config.sh
```

**5. Use systemd service with elevated privileges:**

```bash
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application Service

[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/myapp.sh
RemainAfterExit=no

# User triggers via systemctl (requires appropriate PolicyKit policy)
systemctl start myapp.service
```

**Detection and prevention:**

**Find SUID/SGID shell scripts on your system:**
```bash
# Search for SUID/SGID scripts (should return nothing!)
find / -type f \( -perm -4000 -o -perm -2000 \) -exec file {} \; | grep -i script

# List all SUID files (review carefully)
find / -type f -perm -4000 -ls 2>/dev/null

# List all SGID files
find / -type f -perm -2000 -ls 2>/dev/null
```

**Prevent accidental SUID on scripts:**
```bash
# Modern Linux kernels ignore SUID on scripts, but don't rely on this
# Many Unix variants still honor SUID on scripts

# In your deployment scripts, explicitly ensure no SUID:
install -m 755 myscript.sh /usr/local/bin/
# Never use -m 4755 or chmod u+s on shell scripts
```

**Why sudo is safer:**

```bash
# ✓ Sudo provides multiple safety features:
# 1. Logging: All sudo commands are logged to /var/log/auth.log
# 2. Timeout: Credentials expire after 15 minutes
# 3. Granular control: Specific commands, arguments, users
# 4. Environment sanitization: Clears dangerous variables by default
# 5. Audit trail: Who ran what, when

# Configure specific commands in /etc/sudoers.d/myapp
username ALL=(root) NOPASSWD: /usr/local/bin/backup.sh
username ALL=(root) /usr/local/bin/restore.sh *

# User runs:
sudo /usr/local/bin/backup.sh
# Logged: "username : TTY=pts/0 ; PWD=/home/username ; USER=root ; COMMAND=/usr/local/bin/backup.sh"
```

**Real-world security incident example:**

In the early 2000s, many Unix systems had SUID root shell scripts for system administration tasks. Attackers exploited these through:
- IFS manipulation to execute arbitrary commands
- PATH attacks to substitute malicious interpreters
- Race conditions in temporary file handling
- Command injection through unchecked user input

Modern Linux distributions (since ~2005) ignore SUID bits on scripts by default, but:
- Many Unix variants still honor them
- Legacy systems may be vulnerable
- Scripts deployed to unknown systems may be exploited
- The practice itself is fundamentally unsafe

**Summary:**

- **Never** use SUID or SGID on shell scripts under any circumstances
- Shell scripts have too many attack vectors to be safe with elevated privileges
- Use `sudo` with carefully configured permissions instead
- For compiled programs needing specific privileges, use capabilities
- Use setuid wrappers (compiled C) if you absolutely must execute a script with privileges
- Audit your systems regularly for SUID/SGID scripts: `find / -type f \( -perm -4000 -o -perm -2000 \) -exec file {} \;`
- Remember: Convenience is never worth the security risk of SUID shell scripts

**Key principle:** If you think you need SUID on a shell script, you're solving the wrong problem. Redesign your solution using sudo, PolicyKit, systemd services, or a compiled wrapper.
