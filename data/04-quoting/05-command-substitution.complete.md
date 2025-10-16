### Command Substitution in Strings

Use double quotes when including command substitution:

```bash
# Command substitution requires double quotes
echo "Current time: $(date +%T)"
info "Found $(wc -l "$file") lines"
die 1 "Checksum failed: expected $expected, got $(sha256sum "$file")"

# Assign with command substitution
VERSION="$(git describe --tags 2>/dev/null || echo 'unknown')"
TIMESTAMP="$(date -Ins)"
```
