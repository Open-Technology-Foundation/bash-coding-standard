# Balanced Version Template (.balanced.md)

This template shows the format for .balanced.md files (40-60% of comprehensive version).

---

### Example Rule Name

**Bold opening statement that captures the core rule in 1-2 sentences.**

**Rationale:**
- **Point 1**: Most critical reason (performance/safety/clarity)
- **Point 2**: Second most important reason
- **Point 3**: Third reason
- **Point 4**: Fourth reason (if needed for complex topics)

**Basic example:**

```bash
# Demonstrate the rule with minimal working code
declare -i flag=0
((flag)) && echo 'Enabled'
```

**When to use this pattern:**

```bash
# Show primary use case (40-60 lines max)
#!/usr/bin/env bash
set -euo pipefail

# Practical example demonstrating the rule
main() {
  # Concise but complete
  validate_input "$@"
  process_data
}

main "$@"
#fin
```

**Anti-patterns:**

```bash
# ✗ Wrong - most critical mistake
bad_pattern_here

# ✓ Correct - proper approach
good_pattern_here

# ✗ Wrong - second critical mistake
another_bad_pattern

# ✓ Correct - proper approach
another_good_pattern

# ✗ Wrong - third mistake (if needed)
third_bad_pattern

# ✓ Correct - proper approach
third_good_pattern
```

**Edge cases:**

**Case 1: Most important gotcha**
```bash
# Show surprising behavior
unexpected_behavior

# Solution
correct_approach
```

**Case 2: Second important gotcha** (if needed)
```bash
# Show the issue
issue_demonstration

# Solution
fix_demonstration
```

**Summary:**
- **Key point 1**: Core takeaway
- **Key point 2**: Second takeaway
- **Key point 3**: Third takeaway

---

## Balanced Version Guidelines

**Target size:** 200-400 lines for complex topics, 100-200 for simple topics

**What to keep:**
- Title and bold opening
- Top 4-5 rationale points (most technical/specific)
- 1-2 working examples (40-80 lines total)
- 3-5 most critical anti-patterns
- 2-3 most important edge cases
- Summary with key points

**What to remove:**
- Complete example scripts >200 lines
- Redundant explanations
- Verbose introductions
- Less common edge cases
- Extensive variations (keep most illustrative)
- Repetitive anti-patterns (consolidate)

**Compression techniques:**
1. **Consolidate examples** - Merge similar examples into one
2. **Tighten rationale** - Remove elaboration, keep facts
3. **Condense anti-patterns** - Show pattern, not full context
4. **Remove redundancy** - If it's obvious, don't explain
5. **Keep technical details** - Preserve specific/measurable info

**Balance goal:** Enough detail for understanding, little enough for quick reference

#fin
