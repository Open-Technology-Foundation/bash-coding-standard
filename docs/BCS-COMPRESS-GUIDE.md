# BCS Compress - Comprehensive Guide

This document provides detailed guidance for the `bcs compress` command, including context awareness levels, workflow best practices, and advanced usage patterns.

For basic compress usage, see the README.md. This document is for developers maintaining the multi-tier documentation system.

## Table of Contents

- [Overview](#overview)
- [Context Awareness Levels](#context-awareness-levels)
- [Features](#features)
- [Workflow](#workflow)
- [How It Works](#how-it-works)
- [Size Limits](#size-limits)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## Overview

The `bcs compress` command uses Claude AI to compress `.complete.md` rule files into `.summary.md` and `.abstract.md` tiers. This maintains the multi-tier documentation system that allows users to choose their preferred level of detail.

**Purpose:**
- Compress complete tier files to summary and abstract tiers
- Maintain consistent compression across all rules
- Enable cross-rule deduplication with context awareness
- Ensure all tiers stay within size limits

**Requires:**
- Claude Code CLI (`claude` command must be in PATH)
- Write access to data/ directory
- Source `.complete.md` files in data/ hierarchy

**Use cases:**
- Adding new rules to the standard
- Modifying existing `.complete.md` files
- Adjusting compression parameters
- Maintaining custom forks of the standard

---

## Context Awareness Levels

Understanding context awareness is key to effective compression. Higher context levels enable better deduplication across rules but cost more tokens.

### none (Default, Fastest)

**Description:**
- Each rule compressed in complete isolation
- No awareness of other rules in the standard
- Fastest processing, lowest token cost
- No cross-rule deduplication possible

**Use for:**
- Quick testing and iteration
- Single-rule updates
- When token cost is primary concern
- Initial compression of new rules

**Example:**
```bash
bcs compress --regenerate --context-level none
```

**Characteristics:**
- Processing time: ~2-5 seconds per rule
- Token cost: ~500-2000 tokens per rule
- Deduplication: None
- Quality: Basic compression only

---

### toc (Lightweight)

**Description:**
- Includes table of contents + section summaries (~5-10KB)
- Structural awareness of what exists elsewhere
- Minimal additional token cost over `none`
- Light cross-reference capability

**Use for:**
- Moderate improvement with minimal overhead
- When you want some context but not full standard
- Testing context awareness benefits
- Balancing quality with speed

**Example:**
```bash
bcs compress --regenerate --context-level toc
```

**Characteristics:**
- Processing time: ~3-6 seconds per rule
- Token cost: ~800-2500 tokens per rule
- Deduplication: Light, structural only
- Quality: Better than none, identifies major duplications

---

### abstract (Recommended for Most Cases)

**Description:**
- Includes full BASH-CODING-STANDARD.abstract.md (~83KB)
- Full awareness of all other rules for cross-reference
- Can identify and eliminate cross-rule duplication
- Maintains consistent terminology across standard
- Good balance of context vs token cost

**Use for:**
- Production regeneration and final compression
- Maintaining consistency across rules
- Cross-rule deduplication
- Professional-quality compression

**Example:**
```bash
bcs compress --regenerate --context-level abstract --verbose
```

**Characteristics:**
- Processing time: ~5-10 seconds per rule
- Token cost: ~1500-4000 tokens per rule
- Deduplication: High, comprehensive cross-references
- Quality: Production-grade, consistent terminology

**Benefits:**
- Eliminates duplicated concepts across rules
- Maintains consistent terminology
- Identifies when one rule sufficiently covers a topic
- Produces more coherent compressed output
- Better than summary/complete for most use cases

---

### summary (Detailed Context)

**Description:**
- Includes full BASH-CODING-STANDARD.summary.md (~310KB)
- More detailed context than abstract tier
- Useful when compressing to abstract tier with rich examples
- Higher token cost than abstract context
- Includes medium-detail examples from all rules

**Use for:**
- When abstract context isn't detailed enough
- Complex rules requiring rich examples
- Maintaining example consistency
- Fine-tuning compression quality

**Example:**
```bash
bcs compress --regenerate --context-level summary
```

**Characteristics:**
- Processing time: ~8-15 seconds per rule
- Token cost: ~3000-7000 tokens per rule
- Deduplication: Very high, includes examples
- Quality: Excellent, rich context

---

### complete (Maximum Context)

**Description:**
- Includes full BASH-CODING-STANDARD.complete.md (~520KB)
- Most comprehensive context with all examples and rationale
- Highest token cost, slowest processing
- Maximum awareness of entire standard

**Use for:**
- Complex rules requiring full documentation context
- When other context levels produce unsatisfactory results
- Critical rules needing perfect compression
- Cost-is-no-object scenarios

**Example:**
```bash
bcs compress --regenerate --context-level complete
```

**Characteristics:**
- Processing time: ~12-25 seconds per rule
- Token cost: ~5000-12000 tokens per rule
- Deduplication: Maximum, complete awareness
- Quality: Absolute best, but consider if cost justifies results

**Warning:** Very expensive. Test with abstract first.

---

## Features

### Automatic Retry with Stricter Prompts

When compressed files exceed size limits, the tool automatically retries with stricter prompts:

1. First attempt: Normal compression
2. If oversized: Retry with "more aggressive" prompt
3. If still oversized: Retry with "extremely concise" prompt
4. Reports failures if all attempts exceed limits

This ensures maximum compliance with size limits while minimizing manual intervention.

### File Permissions and Timestamp Syncing

All generated tier files maintain consistent attributes:

- **Permissions:** 664 (rw-rw-r--) for all tiers
- **Timestamps:** Synced from source `.complete.md` file
- **Ownership:** Preserved from source file

This ensures git doesn't show spurious differences and maintains proper access control.

### Deduplication Across Rules

With context awareness (toc/abstract/summary/complete), the tool can:

- Identify concepts explained in other rules
- Reference rather than duplicate explanations
- Maintain consistent terminology across the standard
- Reduce overall documentation size

Example: If readonly pattern is fully explained in BCS0205, other rules can reference it rather than re-explaining.

### Report-Only Mode

Check file sizes without modifying anything:

```bash
bcs compress --report-only
```

Shows:
- Current sizes of all tier files
- Files exceeding size limits
- Recommendations for compression

Perfect for monitoring without changes.

### Regenerate Mode

Full compression pipeline for all rules:

```bash
bcs compress --regenerate
```

- Deletes existing derived tier files (.summary.md, .abstract.md)
- Regenerates from source .complete.md files
- Applies size limits and retries
- Reports statistics (success, oversized, failures)

### Dry-Run Mode

Preview operations without making changes:

```bash
bcs compress --regenerate --dry-run --verbose
```

Shows:
- Which files would be processed
- What operations would be performed
- Expected outcomes

Perfect for testing and verification.

---

## Workflow

### Recommended Production Workflow

Follow this process when adding or updating rules:

#### Step 1: Edit Complete Tier Files

Edit only the `.complete.md` files with full documentation:

```bash
vim data/02-variables/05-readonly-after-group.complete.md
```

**Never edit** `.summary.md` or `.abstract.md` directly - they are generated files.

#### Step 2: Compress with Abstract Context

Run compression with recommended settings:

```bash
bcs compress --regenerate --context-level abstract --verbose
```

**Why abstract context:**
- Best balance of quality and cost
- Cross-rule deduplication
- Consistent terminology
- Production-grade results

#### Step 3: Review Compression Statistics

Check the output for:

```
✓ Compressed: data/02-variables/05-readonly-after-group.complete.md
  → Summary: 8,543 bytes (under 10,000 limit)
  → Abstract: 1,287 bytes (under 1,500 limit)
```

**Look for:**
- Any files marked as "OVERSIZED"
- Retry attempts (indicates borderline sizes)
- Failed compressions (need manual attention)

#### Step 4: Rebuild Main Standard

Regenerate the canonical BASH-CODING-STANDARD.md:

```bash
bcs generate --canonical
```

This assembles all tier files into the unified standard document.

#### Step 5: Commit All Three Tiers

Commit the source and generated files together:

```bash
git add data/02-variables/05-readonly-after-group.*.md
git add BASH-CODING-STANDARD.*.md
git commit -m "Update readonly-after-group rule with examples"
```

**Important:** Always commit all three tiers together to maintain consistency.

---

## How It Works

### Technical Architecture

The compress command follows this process:

#### 1. File Discovery

- Scans data/ directory recursively
- Finds all `.complete.md` source files
- Skips files in .gitignore
- Builds list of files to process

#### 2. Context Preparation

Based on --context-level:

- `none`: No additional context
- `toc`: Reads BASH-CODING-STANDARD.toc.md (if exists, else generates)
- `abstract`: Reads BASH-CODING-STANDARD.abstract.md
- `summary`: Reads BASH-CODING-STANDARD.summary.md
- `complete`: Reads BASH-CODING-STANDARD.complete.md

#### 3. Compression Invocation

For each source file:

```bash
claude \
  --print \
  --dangerously-skip-permissions \
  --append-system-prompt "CONTEXT: [context tier content]" \
  "Compress this to [summary|abstract] tier: ..." \
  < source.complete.md \
  > target.tier.md
```

#### 4. Size Validation

After compression:

- Check file size against limits
- If under limit: Success
- If over limit: Retry with stricter prompt
- If still over after retries: Mark as OVERSIZED

#### 5. File Syncing

For successful compressions:

- Set permissions to 664
- Copy mtime from source .complete.md
- Preserve ownership

#### 6. Statistics Reporting

Reports:

- Total files processed
- Successful compressions
- Oversized files (with paths)
- Failed compressions (with errors)

---

## Size Limits

### Default Limits

- **complete:** 20,000 bytes (informational only, not enforced)
- **summary:** 10,000 bytes (default, adjustable)
- **abstract:** 1,500 bytes (default, adjustable)

### Adjusting Limits

Override defaults:

```bash
bcs compress --regenerate \
  --summary-limit 12000 \
  --abstract-limit 2000
```

### Why These Limits?

**Abstract tier (1,500 bytes):**
- Quick reference must be scannable
- Should fit in terminal without scrolling
- Forces concise, essential information only
- Typical: 15-30 lines of content

**Summary tier (10,000 bytes):**
- Medium detail with key examples
- Balance between completeness and brevity
- Sufficient for most use cases
- Typical: 150-200 lines of content

**Complete tier (20,000 bytes):**
- No hard limit enforced
- Informational threshold for monitoring
- Some rules legitimately exceed this
- Typical: 300-500 lines of content

---

## Best Practices

### When to Use Which Context Level

**Use `none` when:**
- Testing compression for a single new rule
- Making minor edits that don't affect other rules
- Token budget is extremely limited
- Speed is more important than quality

**Use `abstract` when:**
- Doing production regeneration
- Maintaining consistency is important
- Cross-rule deduplication needed
- Standard practice for releases

**Use `summary` or `complete` when:**
- Abstract context produces poor results
- Rule requires rich example context
- Maximum quality needed regardless of cost
- Working on complex, interdependent rules

### Incremental Compression

Don't compress everything at once. Instead:

```bash
# Compress only files modified recently
find data/ -name "*.complete.md" -mtime -7 | while read -r file; do
  base="${file%.complete.md}"
  bcs compress --regenerate --context-level abstract "$file"
done
```

### Monitoring Size Growth

Regular check for size trends:

```bash
# Report current sizes
bcs compress --report-only | grep "OVERSIZED"

# Track over time
bcs compress --report-only > sizes-$(date +%Y%m%d).txt
```

### Handling Oversized Files

When files exceed limits:

1. **Review content:** Is there unnecessary detail?
2. **Check examples:** Can examples be more concise?
3. **Consider splitting:** Should this be multiple rules?
4. **Adjust if justified:** Sometimes larger is legitimate

### Testing Before Committing

Always test compression before committing:

```bash
# Dry run first
bcs compress --regenerate --dry-run --context-level abstract

# If looks good, run for real
bcs compress --regenerate --context-level abstract

# Verify results
bcs compress --report-only

# Test generated standard
bcs generate --stdout | wc -l
```

---

## Troubleshooting

### Claude Command Not Found

**Error:** `claude: command not found`

**Solution:**
```bash
# Verify Claude CLI is installed
which claude

# If not installed, install from: https://claude.ai/code

# Verify it's in PATH
echo $PATH | grep -o '/usr/local/bin'

# If needed, specify full path
bcs compress --claude-cmd /usr/local/bin/claude --regenerate
```

### Permission Denied

**Error:** `Permission denied: data/01-script-structure/01-layout.summary.md`

**Solution:**
```bash
# Check file permissions
ls -la data/01-script-structure/01-layout.summary.md

# If read-only, make writable
chmod 664 data/01-script-structure/*.md

# Or remove derived files and regenerate
rm data/**/*.{summary,abstract}.md
bcs compress --regenerate
```

### Files Still Oversized After Retries

**Error:** `OVERSIZED: data/05-arrays/01-declaration.abstract.md (2,543 bytes, limit 1,500)`

**Solution:**

1. **Review content manually:**
```bash
bcs decode BCS0501 -a -p | less
```

2. **Check if splitting needed:**
```bash
# If rule covers too many concepts, consider splitting into subrules
mkdir -p data/05-arrays/01-declaration
# Move specific topics to subrules
```

3. **Increase limit if justified:**
```bash
bcs compress --regenerate --abstract-limit 3000
```

4. **Edit complete tier to be more compression-friendly:**
```bash
vim data/05-arrays/01-declaration.complete.md
# Remove redundant explanations
# Consolidate similar examples
# Reference other rules instead of duplicating
```

### Inconsistent Terminology Across Tiers

**Issue:** Abstract uses "variable" while summary uses "identifier"

**Solution:**

Use higher context level for consistency:

```bash
# Instead of 'none', use 'abstract' for terminology consistency
bcs compress --regenerate --context-level abstract
```

The abstract context helps maintain consistent terminology across all rules.

### Compression Takes Too Long

**Issue:** Compression taking 5+ minutes per file

**Possible causes:**
- Using `complete` context level (very large context)
- Network latency to Claude API
- Large source files

**Solutions:**

1. **Use lighter context:**
```bash
bcs compress --regenerate --context-level abstract  # Instead of complete
```

2. **Compress in parallel (advanced):**
```bash
# NOT RECOMMENDED - may hit rate limits
# Only use if you understand the implications
find data/ -name "*.complete.md" | xargs -P 4 -I {} bcs compress --regenerate {}
```

3. **Compress only changed files:**
```bash
git diff --name-only | grep ".complete.md$" | while read -r file; do
  bcs compress --regenerate --context-level abstract "$file"
done
```

---

## Summary

The `bcs compress` command is a powerful tool for maintaining the multi-tier documentation system:

**Key capabilities:**
- AI-powered compression with Claude
- Five context awareness levels (none → complete)
- Automatic retry for oversized files
- Cross-rule deduplication with context
- File permission and timestamp syncing
- Report-only and dry-run modes

**Recommended workflow:**
1. Edit only `.complete.md` files
2. Run: `bcs compress --regenerate --context-level abstract`
3. Review statistics and fix oversized files
4. Run: `bcs generate --canonical`
5. Commit all three tiers together

**Default context level:** `abstract` provides the best balance of quality and cost for most use cases.

**For more information:**
- Basic usage: See README.md "compress" section
- Help: Run `bcs compress --help`
- Examples: See this guide's workflow and troubleshooting sections

---

*Version: 1.0.0*
*Last updated: 2025-10-17*
