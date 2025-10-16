### Error Suppression

**Only suppress errors when failure is expected, non-critical, and explicitly safe. Always document WHY with comments.**

**Rationale:**
- Masks real bugs and creates silent failures
- Security risk: ignored errors leave systems in insecure states
- Makes debugging impossible by hiding failure points

**When suppression IS appropriate:**
- Checking optional tools: `command -v optional >/dev/null 2>&1`
- Idempotent operations: `install -d "$dir" 2>/dev/null || true`
- Cleanup: `rm -f /tmp/temp_* 2>/dev/null || true`

**NEVER suppress:**
- File operations: `cp "$critical" "$dest" || die 1 'Copy failed'`
- Data processing: Loss of data is critical
- Security operations: `chmod 600 "$key" || die 1 'Failed to secure'`
- Required dependencies: `command -v git >/dev/null || die 1 'git required'`

**Patterns:**
```bash
# ✓ Suppress with documented reason
# Rationale: temp files may not exist
rm -f /tmp/app_* 2>/dev/null || true

# ✗ Wrong - suppressing critical operation
cp "$important" "$backup" 2>/dev/null || true
```

**Anti-patterns:**
- `set +e` → Disables error checking (dangerous)
- Suppressing without comments → `2>/dev/null || true` with no WHY
- Function-wide suppression → `func() { ... } 2>/dev/null` (extremely dangerous)

**Ref:** See comprehensive version for complete examples and security considerations.
