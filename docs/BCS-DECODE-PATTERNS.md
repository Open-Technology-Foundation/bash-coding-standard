# BCS Decode - Comprehensive Usage Patterns

This document provides detailed usage patterns for the `bcs decode` command, including advanced workflows, scripting techniques, and real-world examples.

For basic decode usage, see the README.md. This document is for users who want to master advanced decode patterns for complex workflows.

## Table of Contents

- [Usage Pattern 1: Editor Integration](#usage-pattern-1-editor-integration)
- [Usage Pattern 2: Content Viewing](#usage-pattern-2-content-viewing)
- [Usage Pattern 3: Tier Comparison](#usage-pattern-3-tier-comparison)
- [Usage Pattern 4: Batch Processing](#usage-pattern-4-batch-processing)
- [Usage Pattern 5: Scripting & Validation](#usage-pattern-5-scripting--validation)
- [Usage Pattern 6: Path Manipulation](#usage-pattern-6-path-manipulation)
- [Usage Pattern 7: Documentation Building](#usage-pattern-7-documentation-building)
- [Usage Pattern 8: Learning Workflows](#usage-pattern-8-learning-workflows)
- [Usage Pattern 9: Code Review Integration](#usage-pattern-9-code-review-integration)
- [Real-World Examples](#real-world-examples)

---

## Usage Pattern 1: Editor Integration

Open rules directly in your editor for quick reference or editing:

```bash
# Open single rule (abstract tier by default)
vim $(bcs decode BCS0102)                    # Default editor (abstract)
code $(bcs decode BCS0205)                   # VSCode (abstract)
nano $(bcs decode BCS0103)                   # nano (abstract)

# Open complete version (with all examples)
vim $(bcs decode BCS0102 -c)

# Open section overview
vim $(bcs decode BCS01)                      # Section 1 overview

# Open multiple related rules (NEW: multiple codes support)
vim $(bcs decode BCS01 BCS0102 BCS0103 --basename | xargs -I {} realpath data/*/{}*)

# Open with line number (if you know the section)
vim +20 $(bcs decode BCS0205)

# Edit and reload
vim $(bcs decode BCS0102) && bcs generate --canonical
```

**Use cases:**
- Quick reference while coding
- Editing rules directly in your preferred editor
- Opening related rules in tabs
- Jumping to specific sections

---

## Usage Pattern 2: Content Viewing

View rule content directly without opening files:

```bash
# Quick reference - print to stdout (abstract by default)
bcs decode BCS0102 -p                        # View abstract rule (quick reference)
bcs decode BCS0102 -s -p                     # View summary (medium detail)
bcs decode BCS0102 -c -p                     # View complete (all examples)

# View section overview (NEW: section codes)
bcs decode BCS01 -p                          # Section 1 overview (abstract)
bcs decode BCS01 -c -p                       # Section 1 complete details

# View multiple codes (NEW: multiple codes support)
bcs decode BCS01 BCS02 BCS08 -p              # Multiple sections with separators
bcs decode BCS0102 BCS0103 BCS0104 -s -p     # Multiple rules (summary tier)

# View with pager
bcs decode BCS0102 -p | less                 # Scrollable view
bcs decode BCS0102 -p | more                 # Simple pager

# View all tiers for comprehensive understanding
bcs decode BCS0102 --all -p                  # All three tiers with separators
bcs decode BCS0102 --all -p | less           # Browse all tiers

# Extract specific sections
bcs decode BCS0102 -p | grep -A 10 "Rationale"     # Find rationale section
bcs decode BCS0102 -p | awk '/^```bash/,/^```/'    # Extract code blocks only
bcs decode BCS0102 -p | sed -n '1,20p'             # First 20 lines
```

**Use cases:**
- Terminal-based quick reference
- Piping content to other tools
- Extracting specific information
- Viewing multiple tiers side-by-side

---

## Usage Pattern 3: Tier Comparison

Compare different documentation tiers to understand detail levels:

```bash
# Side-by-side comparison
diff -y <(bcs decode BCS0102 -a -p) <(bcs decode BCS0102 -s -p)
diff -y <(bcs decode BCS0102 -s -p) <(bcs decode BCS0102 -c -p)

# Unified diff
diff -u <(bcs decode BCS0102 -a -p) <(bcs decode BCS0102 -c -p)

# Show only differences
diff --suppress-common-lines -y <(bcs decode BCS0102 -a -p) <(bcs decode BCS0102 -c -p)

# Compare different rules
diff <(bcs decode BCS0102 -p) <(bcs decode BCS0103 -p)

# Word-level comparison
wdiff <(bcs decode BCS0102 -a -p) <(bcs decode BCS0102 -c -p)
```

**Use cases:**
- Understanding what each tier includes
- Deciding which tier to use for documentation
- Analyzing compression effectiveness
- Finding differences between rules

---

## Usage Pattern 4: Batch Processing

Process multiple rules programmatically:

```bash
# Loop through specific codes
for code in BCS0102 BCS0103 BCS0104; do
  echo "=== $code ==="
  bcs decode "$code" -s -p | head -5
  echo
done

# Process all codes in a section
bcs codes | grep "^BCS01" | while IFS=: read -r code name desc; do
  echo "Processing: $code - $desc"
  bcs decode "$code" --exists && echo "  ✓ Exists"
done

# Extract and save all rules
bcs codes | while IFS=: read -r code rest; do
  bcs decode "$code" -p > "docs/$code.md"
done

# Find rules containing specific patterns
bcs codes | while IFS=: read -r code rest; do
  if bcs decode "$code" -p | grep -q "readonly"; then
    echo "$code contains readonly pattern"
  fi
done

# Build searchable index
bcs codes | while IFS=: read -r code name desc; do
  printf '%s\t%s\t%s\n' "$code" "$desc" "$(bcs decode "$code" --relative)"
done > bcs-index.tsv
```

**Use cases:**
- Automated documentation generation
- Building custom rule indexes
- Searching for patterns across all rules
- Extracting rules for offline use

---

## Usage Pattern 5: Scripting & Validation

Use in scripts for validation and conditional logic:

```bash
# Check if code exists (silent)
if bcs decode BCS0102 --exists; then
  echo "Rule BCS0102 exists"
fi

# Exit immediately if code doesn't exist
bcs decode BCS9999 --exists || { echo "Invalid code"; exit 1; }

# Validate multiple codes
declare -a codes=(BCS0102 BCS0103 BCS0104 BCS0105)
for code in "${codes[@]}"; do
  bcs decode "$code" --exists || echo "Missing: $code"
done

# Conditional processing
if bcs decode BCS0205 --exists; then
  # Extract readonly pattern examples
  bcs decode BCS0205 -p | awk '/^```bash/,/^```/' > readonly-examples.txt
fi

# Build validation report
{
  echo "BCS Code Validation Report"
  echo "=========================="
  echo
  for code in BCS{01..14}00; do
    if bcs decode "$code" --exists; then
      printf '%-8s ✓ Present\n' "$code"
    else
      printf '%-8s ✗ Missing\n' "$code"
    fi
  done
} > validation-report.txt
```

**Use cases:**
- Script validation before execution
- CI/CD pipeline checks
- Automated testing
- Error handling in scripts

---

## Usage Pattern 6: Path Manipulation

Work with file paths in various formats:

```bash
# Absolute paths (default) - for editor commands
file=$(bcs decode BCS0102)
echo "$file"  # /full/path/to/data/01-script-structure/02-shebang.complete.md

# Relative paths - for documentation and portability
bcs decode BCS0102 --relative
# Output: data/01-script-structure/02-shebang.complete.md

# Basename only - for file lists
bcs decode BCS0102 --basename
# Output: 02-shebang.complete.md

# Build documentation with relative paths
bcs codes | while IFS=: read -r code name desc; do
  echo "- [$code - $desc]($(bcs decode "$code" --relative))"
done > RULES-INDEX.md

# Get all basenames for a section
bcs codes | grep "^BCS01" | while IFS=: read -r code rest; do
  bcs decode "$code" --basename
done

# Create symlinks with basenames
cd /tmp/bcs-rules
bcs codes | while IFS=: read -r code rest; do
  ln -s "$(bcs decode "$code")" "$(bcs decode "$code" --basename)"
done
```

**Use cases:**
- Building portable documentation
- Creating file lists
- Generating symlinks
- Path manipulation in scripts

---

## Usage Pattern 7: Documentation Building

Generate custom documentation from BCS rules:

```bash
# Create quick reference guide
{
  echo "# BCS Quick Reference"
  echo
  bcs codes | head -20 | while IFS=: read -r code name desc; do
    echo "## $code: $desc"
    echo
    bcs decode "$code" -a -p | head -15
    echo
    echo "---"
    echo
  done
} > BCS-QUICK-REF.md

# Extract all code examples
mkdir -p examples
bcs codes | while IFS=: read -r code name rest; do
  bcs decode "$code" -p | awk '/^```bash/,/^```/' | sed '1d;$d' > "examples/$code-$name.sh"
done

# Build searchable HTML (requires markdown processor)
bcs codes | while IFS=: read -r code name desc; do
  {
    echo "# $desc"
    echo
    echo "**Code:** $code"
    echo
    bcs decode "$code" -p
  } | markdown > "html/$code.html"
done

# Create table of contents with links
{
  echo "# BCS Rules Index"
  echo
  echo "| Code | Rule | File |"
  echo "|------|------|------|"
  bcs codes | while IFS=: read -r code name desc; do
    file=$(bcs decode "$code" --relative)
    printf '| %s | %s | `%s` |\n' "$code" "$desc" "$file"
  done
} > RULES-TOC.md
```

**Use cases:**
- Creating custom quick references
- Generating searchable HTML documentation
- Building TOCs and indexes
- Extracting code examples for tutorials

---

## Usage Pattern 8: Learning Workflows

Use decode for learning and reference:

```bash
# Study specific rule
bcs decode BCS0102 -p | less          # Read full explanation

# Quick lookup during coding
bcs decode BCS0205 -s -p              # Fast summary reference

# Understand rule hierarchy
bcs decode BCS01 -a -p                # Section overview
bcs decode BCS0102 -a -p              # Rule details
bcs decode BCS010201 -a -p            # Subrule specifics

# Compare learning materials
bcs decode BCS0102 -s -p > /tmp/summary.txt
bcs decode BCS0102 -c -p > /tmp/complete.txt
diff /tmp/summary.txt /tmp/complete.txt

# Extract examples for practice
bcs decode BCS0205 -p | grep -A 20 "^```bash" | head -25 > practice.sh

# Build personal cheat sheet
for code in BCS0102 BCS0205 BCS0810 BCS1301; do
  echo "=== $(bcs codes | grep "^$code:" | cut -d: -f3) ==="
  bcs decode "$code" -s -p | head -10
  echo
done > my-cheatsheet.txt
```

**Use cases:**
- Learning the standard progressively
- Creating personal reference materials
- Practicing with extracted examples
- Understanding rule relationships

---

## Usage Pattern 9: Code Review Integration

Reference rules during code reviews:

```bash
# Check if script follows specific rule
bcs decode BCS0102 -p > /tmp/rule.txt
grep -A 5 "set -euo pipefail" myscript.sh
cat /tmp/rule.txt | grep -A 5 "set -euo pipefail"

# Compare script pattern with standard
diff <(grep -A 10 "readonly" myscript.sh) <(bcs decode BCS0205 -p | grep -A 10 "readonly")

# Get rule reference for review comment
echo "Please follow $(bcs codes | grep "^BCS0205:" | cut -d: -f3)"
echo "Reference: $(bcs decode BCS0205 --relative)"
echo
bcs decode BCS0205 -a -p

# Build review checklist
{
  echo "Code Review Checklist"
  echo "===================="
  for code in BCS0102 BCS0103 BCS0201 BCS0301 BCS0401; do
    desc=$(bcs codes | grep "^$code:" | cut -d: -f3)
    echo "- [ ] $code: $desc"
  done
} > review-checklist.md
```

**Use cases:**
- Creating review checklists
- Referencing rules in review comments
- Comparing code against standard
- Generating review guidelines

---

## Real-World Examples

Practical examples from actual usage:

```bash
# Example 1: Quick rule reference while coding (abstract by default)
$ bcs decode BCS0102 -p
## Shebang and Initial Setup
First lines: shebang, optional shellcheck directives, brief description...

# Example 2: Open rule in editor (abstract by default)
$ vim $(bcs decode BCS0205)
# Opens: data/02-variables/05-readonly-after-group.abstract.md

# Example 3: View section overview (NEW: section codes)
$ bcs decode BCS01 -p
## Script Structure & Layout
Mandatory 13-step layout: (1) Shebang, (2) ShellCheck directives...

# Example 4: Multiple codes at once (NEW: multiple codes)
$ bcs decode BCS01 BCS02 BCS08 -p
[Shows BCS01 content]
=========================================
[Shows BCS02 content]
=========================================
[Shows BCS08 content]

# Example 5: Compare abstract vs complete
$ diff -y <(bcs decode BCS0102 -a -p) <(bcs decode BCS0102 -c -p) | less

# Example 6: Validate code existence
$ bcs decode BCS9999 --exists || echo "Code not found"
Code not found

# Example 7: Build documentation with multiple codes
$ bcs decode BCS01 BCS02 BCS03 BCS04 BCS05 -s -p > sections-summary.md

# Example 8: Extract code examples
$ bcs decode BCS0205 -c -p | awk '/^```bash/,/^```/' | sed '1d;$d' > readonly-examples.sh

# Example 9: BCS prefix optional
$ bcs decode 0102 -p                  # Works without BCS prefix
$ bcs decode BCS0102 -p               # Also works with prefix

# Example 10: View all tiers
$ bcs decode BCS0102 --all -p | less
### Complete tier (BCS0102)
[complete content]
---
### Abstract tier (BCS0102)
[abstract content]
---
### Summary tier (BCS0102)
[summary content]
```

---

## Summary

The `bcs decode` command is a powerful tool for working with BCS rules:

**Key capabilities:**
- **Tier selection**: Choose abstract (quick), summary (medium), or complete (detailed)
- **Output modes**: File paths (default) or content (-p)
- **Path formats**: Absolute (default), relative, or basename only
- **Multiple codes**: Process several codes in one command (v1.0.0+)
- **Section codes**: 2-digit codes return section overviews (v1.0.0+)
- **Silent validation**: Check existence without output (--exists)

**Default behavior:**
- Default tier is determined by the BASH-CODING-STANDARD.md symlink (currently abstract)
- Change project-wide: `ln -sf BASH-CODING-STANDARD.{tier}.md BASH-CODING-STANDARD.md`

**Inverse operation:**
- `bcs codes` lists all codes from files
- `bcs decode` resolves codes to file locations

**For more information:**
- Basic usage: See README.md "decode" section
- All BCS codes: Run `bcs codes`
- Help: Run `bcs decode --help`

---

*Version: 1.0.0*
*Last updated: 2025-10-17*
