# Concise Version Template (.concise.md)

This template shows the ultra-compressed format for .concise.md files.
**Target:** 765 bytes average, 75KB total across all 98 files

---

## High-Priority File Format (20-25 lines, ~1,500 bytes)

```markdown
### Example Rule Name

**One-sentence core rule statement.**

**Rationale:**
- **Point 1**: Most critical technical reason
- **Point 2**: Second critical reason
- **Point 3**: Third critical reason (optional)

```bash
# Minimal example (5-8 lines)
declare -i flag=0
((flag)) && action
```

**Anti-pattern:** unquoted variable → word splitting/glob expansion
**Anti-pattern:** missing set -euo pipefail → silent failures

**Ref:** See comprehensive version for complete examples and edge cases
```

**Actual example byte count:** ~380 bytes (can fit 2-3 anti-patterns)

---

## Medium-Priority File Format (10-12 lines, ~800 bytes)

```markdown
### Example Rule Name

**One-sentence rule statement.**

**Rationale:**
- **Critical reason**: Most important technical point

```bash
# Minimal example (3-5 lines)
code_here
```

**Anti-pattern:** critical_mistake → consequence

**Ref:** See comprehensive version for details
```

**Actual example byte count:** ~200 bytes

---

## Low-Priority File Format (4-6 lines, ~285 bytes)

```markdown
### Example Rule Name

**Rule:** One-sentence statement with inline example: `use_this` not `avoid_that`

**Rationale:** Single most important reason

**Ref:** See comprehensive version
```

**Actual example byte count:** ~150 bytes

---

## Concise Version Guidelines

**Absolute priorities - include ONLY:**
1. Title (always)
2. Core rule statement (1-2 lines max)
3. Top 2-3 rationale points (most technical/measurable)
4. One minimal example (most illustrative)
5. 1-2 most critical anti-patterns (changes behavior)
6. Reference line to comprehensive version

**Never include:**
- Exposition or explanation paragraphs
- Multiple examples showing same concept
- Edge cases (unless they're THE defining issue)
- Summary sections (rule statement IS the summary)
- Historical context or background
- Formatting variations
- "Nice to know" information

**Content selection criteria:**

**For rationale - keep if it:**
- States measurable performance difference (10-100x faster)
- Identifies critical safety issue (data loss, security hole)
- Prevents common catastrophic error

**For examples - keep if it:**
- Shows the absolute simplest form
- Demonstrates the one pattern everyone must know
- Is ≤8 lines

**For anti-patterns - keep if it:**
- Prevents silent failures or data corruption
- Fixes the most common mistake (>50% of errors)
- Has severe consequences (security, data loss)

**Compression techniques:**
1. **Inline everything** - No separate sections unless necessary
2. **No elaboration** - State fact, move on
3. **Use → notation** - `cause → effect` instead of sentences
4. **Remove obvious** - If "of course", don't say it
5. **One example only** - The most representative one
6. **Combine anti-patterns** - Multiple in one code block if possible

**Critical rule:** Every word must change behavior or understanding. If removing it doesn't lose information, remove it.

---

## Size Allocation

**Budget:** 75KB total (76,800 bytes)

**Allocation:**
- 26 high-priority files × 1,500 bytes = 39,000 bytes (51%)
- 30 medium-priority files × 800 bytes = 24,000 bytes (31%)
- 42 low-priority files × 285 bytes = 11,970 bytes (16%)
- **Reserve:** 1,830 bytes (2%) for critical overages

**Enforcement:**
- No single file >3KB (outlier detection)
- Each tier must stay within allocation
- Rebalance if needed: take from low, give to high

---

## Quality Checklist for .concise.md

Before finalizing, verify:
- [ ] File size ≤ allocated bytes for tier
- [ ] Title present
- [ ] Rule statement in bold
- [ ] 1-3 rationale points (technical/measurable)
- [ ] One minimal example present
- [ ] 1-2 critical anti-patterns shown
- [ ] Reference to comprehensive version
- [ ] No exposition paragraphs
- [ ] No redundant information
- [ ] Salient points preserved (compare to comprehensive)
- [ ] Every line adds unique value

**Salient points check:**
- Would removing this line change understanding? No → remove it
- Is this the most critical piece of information? No → consider cutting
- Does this prevent a catastrophic error? Yes → keep it

---

## Examples of Good Compression

**Too verbose (50 lines):**
```markdown
### Variable Expansion

Variables in bash can be expanded in different ways. The most common
way is to use the dollar sign followed by the variable name...

[continues for many lines]
```

**Properly concise (12 lines):**
```markdown
### Variable Expansion

**Use `"$var"` by default. Use `"${var}"` only when syntactically required (parameter expansion, concatenation, arrays).**

**Rationale:**
- **Clarity**: Braces add noise when not needed
- **Convention**: Makes necessary cases stand out

```bash
"$var"              # ✓ Default
"${var##*/}"        # ✓ Parameter expansion requires braces
"${var:-default}"   # ✓ Default value requires braces
"${PREFIX}/bin"     # ✗ Unnecessary braces
"$PREFIX/bin"       # ✓ Separator makes braces unnecessary
```

**Ref:** See comprehensive version for complete expansion operator table
```

**Byte count:** ~450 bytes (within budget for high-priority file)

---

## Working Within the Budget

**If file is over budget:**
1. Remove least critical rationale point
2. Shorten example (fewer lines)
3. Reduce to 1 anti-pattern (most critical)
4. Combine anti-patterns into one code block
5. Remove reference line (if desperate)

**If file is significantly under budget:**
- Leave it - don't artificially inflate
- Budget can be reallocated to files that need it
- Simplicity is a feature, not a bug

**Reallocation strategy:**
- Sum all .concise.md files
- If total <70KB, reallocate spare bytes to complex topics
- If total >75KB, cut from least critical files first

#fin
