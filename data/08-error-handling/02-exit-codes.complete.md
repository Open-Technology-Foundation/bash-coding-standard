## Exit Codes

**Standard implementation:**
```bash
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }
die 0                    # Success (or use `exit 0`)
die 1                    # Exit 1 with no error message
die 1 'General error'    # General error
die 2 'Missing argument' # Missing argument
die 22 'Invalid option'  # Invalid argument
```

**Standard exit codes and their meanings:**

| Code | Meaning | When to Use |
|------|---------|-------------|
| 0 | Success | Command completed successfully |
| 1 | General error | Catchall for general errors |
| 2 | Misuse of shell builtin | Missing keyword/command, permission denied |
| 22 | Invalid argument | Invalid option provided (EINVAL) |
| 126 | Command cannot execute | Permission problem or not executable |
| 127 | Command not found | Possible typo or PATH issue |
| 128+n | Fatal error signal n | e.g., 130 = Ctrl+C (128+SIGINT) |
| 255 | Exit status out of range | Use 0-255 only |

**Common custom codes:**
```bash
die 0 'Success message'         # Success (informational)
die 1 'Generic failure'         # General failure
die 2 'Missing required file'   # Usage error
die 3 'Configuration error'     # Config file issue
die 4 'Network error'           # Connection failed
die 5 'Permission denied'       # Insufficient permissions
die 22 "Invalid option '$1'"    # Bad argument (EINVAL)
```

**Rationale:**
- **0 = success**: Universal convention across all Unix/Linux tools
- **1 = general error**: Safe catchall when specific code doesn't matter
- **2 = usage error**: Matches bash built-in behavior for argument errors
- **22 = EINVAL**: Standard errno for "Invalid argument"
- **Avoid high numbers**: Use 1-125 for custom codes to avoid signal conflicts

**Best practices:**
```bash
# Define exit codes as constants for readability
readonly -i SUCCESS=0
readonly -i ERR_GENERAL=1
readonly -i ERR_USAGE=2
readonly -i ERR_CONFIG=3
readonly -i ERR_NETWORK=4

die "$ERR_CONFIG" 'Failed to load configuration file'
```

**Checking exit codes:**
```bash
if command; then
  echo "Success"
else
  exit_code=$?
  case $exit_code in
    1) echo "General failure" ;;
    2) echo "Usage error" ;;
    *) echo "Unknown error: $exit_code" ;;
  esac
fi
```
