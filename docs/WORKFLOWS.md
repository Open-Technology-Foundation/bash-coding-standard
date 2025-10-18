# BCS Workflows Guide

Comprehensive guide to BCS (Bash Coding Standard) user workflows for managing rules, validating data, and checking compliance.

**Version:** 1.0.0
**Last Updated:** 2025-10-17

---

## Table of Contents

1. [Introduction](#introduction)
2. [Quick Start](#quick-start)
3. [Workflow Scripts Overview](#workflow-scripts-overview)
4. [Data Validation Workflow](#data-validation-workflow)
5. [Rule Interrogation Workflow](#rule-interrogation-workflow)
6. [Compliance Checking Workflow](#compliance-checking-workflow)
7. [Rule Compression Workflow](#rule-compression-workflow)
8. [Canonical Generation Workflow](#canonical-generation-workflow)
9. [Adding New Rules](#adding-new-rules)
10. [Modifying Existing Rules](#modifying-existing-rules)
11. [Deleting Rules](#deleting-rules)
12. [Best Practices](#best-practices)
13. [Troubleshooting](#troubleshooting)
14. [CI/CD Integration](#cicd-integration)

---

## Introduction

The BCS workflow system provides automated, testable workflows for common operations when working with the Bash Coding Standard. These workflows ensure consistency, maintain data integrity, and automate repetitive tasks.

### Design Principles

- **Fully Automated** - No manual intervention required
- **BCS Compliant** - All workflow scripts follow BASH-CODING-STANDARD.md
- **Testable** - Comprehensive test coverage with both test-helpers.sh and BATS
- **Idempotent** - Safe to run multiple times
- **Validated** - Built-in validation and error checking

### Prerequisites

- Bash 5.2+
- BCS toolkit installed (`bcs` command available)
- For some workflows:
  - Claude CLI (`claude` command) - for compression and compliance checking
  - Standard Unix utilities (find, stat, grep, etc.)

---

## Quick Start

```bash
# Navigate to project directory
cd /ai/scripts/Okusi/bash-coding-standard

# Validate data/ directory structure
./workflows/validate-data.sh

# Interrogate a specific rule
./workflows/interrogate-rule.sh BCS0102

# Check script compliance (requires Claude CLI)
./workflows/check-compliance.sh myscript.sh

# Generate canonical files (COMING SOON)
./workflows/generate-canonical.sh --all

# Compress rules to summary/abstract tiers (COMING SOON)
./workflows/compress-rules.sh --context-level abstract
```

---

## Workflow Scripts Overview

### Available Workflows (v1.0.0)

| Script | Status | Purpose | Dependencies |
|--------|--------|---------|--------------|
| `validate-data.sh` | ✅ Complete | Validate data/ directory structure | None |
| `interrogate-rule.sh` | ✅ Complete | Inspect rule metadata and content | `bcs decode` |
| `check-compliance.sh` | ✅ Complete | Batch compliance checking | `bcs check`, Claude CLI |
| `compress-rules.sh` | 🚧 In Progress | AI-powered rule compression | `bcs compress`, Claude CLI |
| `generate-canonical.sh` | 🚧 In Progress | Generate canonical BCS files | `bcs generate` |
| `add-rule.sh` | 🚧 In Progress | Add new rule with templates | None |
| `modify-rule.sh` | 🚧 In Progress | Modify existing rules safely | None |
| `delete-rule.sh` | 🚧 In Progress | Delete rules across all tiers | None |

### Workflow Locations

```
bash-coding-standard/
├── workflows/              # Workflow scripts
│   ├── validate-data.sh
│   ├── interrogate-rule.sh
│   ├── check-compliance.sh
│   ├── compress-rules.sh       (COMING SOON)
│   ├── generate-canonical.sh   (COMING SOON)
│   ├── add-rule.sh            (COMING SOON)
│   ├── modify-rule.sh         (COMING SOON)
│   └── delete-rule.sh         (COMING SOON)
├── tests/                  # Workflow tests
│   ├── test-workflow-validate.sh
│   ├── test-workflow-interrogate.sh
│   └── test-workflow-*.sh
└── docs/
    └── WORKFLOWS.md        # This file
```

---

## Data Validation Workflow

### Overview

The **validate-data.sh** workflow performs comprehensive validation of the `data/` directory structure to ensure data integrity and BCS code consistency.

### Usage

```bash
./workflows/validate-data.sh [OPTIONS]

OPTIONS:
  -h, --help              Show help message
  -q, --quiet             Quiet mode (errors only)
  -v, --verbose           Verbose mode (default)
  --exit-on-error         Exit immediately on first error
  --summary-limit BYTES   Max summary file size (default: 10000)
  --abstract-limit BYTES  Max abstract file size (default: 1500)
  --json                  Output results in JSON format
```

### Validation Checks

The workflow performs **11 comprehensive checks**:

1. **Data Directory Existence** - Verify `data/` directory exists
2. **Tier File Completeness** - All `.complete.md` have `.summary.md` and `.abstract.md`
3. **Numeric Prefix Zero-Padding** - Files use `01-` not `1-`
4. **Section Directory Structure** - All sections have `00-section.{tier}.md` files
5. **BCS Code Uniqueness** - No duplicate BCS codes
6. **File Naming Conventions** - Files follow `NN-name.tier.md` pattern
7. **No Alphabetic Suffixes** - No `02a-`, `02b-` patterns (breaks BCS codes)
8. **Section Count Consistency** - `data/` sections match `bcs sections` output
9. **BCS Code Decodability** - All codes can be decoded via `bcs decode`
10. **Header Files Existence** - `00-header.{tier}.md` files present
11. **File Size Limits** - Files within tier size limits

### Examples

```bash
# Basic validation (recommended)
./workflows/validate-data.sh

# Quiet mode (errors only) for CI/CD
./workflows/validate-data.sh --quiet

# Strict mode: exit on first error
./workflows/validate-data.sh --exit-on-error

# Custom size limits
./workflows/validate-data.sh --summary-limit 8000 --abstract-limit 1200

# JSON output for programmatic analysis
./workflows/validate-data.sh --json > validation-report.json
```

### Expected Output

```
validate-data.sh: ◉ BCS Data Directory Validation
validate-data.sh: ◉ Data directory: /ai/scripts/Okusi/bash-coding-standard/data
validate-data.sh: ◉
validate-data.sh: ◉ Checking data directory existence...
validate-data.sh: ✓ data/ directory exists
validate-data.sh: ◉ Checking tier file completeness...
validate-data.sh: ✓ All complete tier files have corresponding abstract and summary tiers (99 rules)
validate-data.sh: ◉ Checking numeric prefix zero-padding...
validate-data.sh: ✓ All numeric prefixes are zero-padded
...
validate-data.sh: ◉
validate-data.sh: ✓ Validation complete: All checks passed
```

### Common Issues and Solutions

**Issue:** Missing tier files
**Solution:** Run `bcs compress --regenerate` to generate missing `.summary.md` and `.abstract.md`

**Issue:** Duplicate BCS codes
**Solution:** Check for duplicate numbered files in same directory, rename or merge

**Issue:** Oversized files
**Solution:** Run `bcs compress --regenerate --context-level abstract` to compress

### Integration with CI/CD

```bash
# .github/workflows/validate.yml
- name: Validate BCS Data
  run: |
    ./workflows/validate-data.sh --quiet --exit-on-error
```

---

## Rule Interrogation Workflow

### Overview

The **interrogate-rule.sh** workflow provides comprehensive rule inspection - query rule information by BCS code or file path, view metadata, and display content across all tiers.

### Usage

```bash
./workflows/interrogate-rule.sh [OPTIONS] CODE_OR_FILE [CODE_OR_FILE ...]

ARGUMENTS:
  CODE_OR_FILE            BCS code (e.g., BCS0102) or file path

OPTIONS:
  -h, --help              Show help message
  -q, --quiet             Quiet mode (errors only)
  -v, --verbose           Verbose mode (default)
  -p, --print             Print rule content to stdout
  -m, --metadata          Show metadata only (default)
  --all-tiers             Show all three tiers
  --format FORMAT         Output format: text (default), json, markdown
  --no-metadata           Suppress metadata (requires -p)
```

### Metadata Displayed

For each rule/tier:
- **BCS Code** - Rule identifier (e.g., BCS0102)
- **File Path** - Absolute path to rule file
- **File Size** - Bytes and line count
- **Last Modified** - Timestamp
- **Short Name** - Extracted from filename
- **Title** - First heading from markdown

### Examples

```bash
# View metadata for a rule (default tier)
./workflows/interrogate-rule.sh BCS0102

# View metadata AND content
./workflows/interrogate-rule.sh BCS0102 -p

# Show all three tiers (complete, summary, abstract)
./workflows/interrogate-rule.sh BCS0102 --all-tiers

# Show all tiers with content
./workflows/interrogate-rule.sh BCS0102 -p --all-tiers

# Multiple rules
./workflows/interrogate-rule.sh BCS01 BCS02 BCS03

# JSON output for programmatic analysis
./workflows/interrogate-rule.sh --format json BCS0102

# Markdown output (great for documentation)
./workflows/interrogate-rule.sh --format markdown BCS0102 > rule-doc.md

# By file path instead of code
./workflows/interrogate-rule.sh data/02-variables/01-type-specific.complete.md

# Content only (no metadata)
./workflows/interrogate-rule.sh BCS0102 -p --no-metadata
```

### Output Example

```
BCS Code: BCS0102

Tier: abstract
File: /ai/scripts/Okusi/bash-coding-standard/data/01-script-structure/02-shebang.abstract.md
Size: 673 bytes, 21 lines
Modified: 2025-10-16 17:21:34
Title: Shebang and Initial Setup
```

### Use Cases

1. **Quick Reference** - Look up rule details without opening files
2. **Documentation** - Export rules to markdown for wikis
3. **Analysis** - JSON output for programmatic rule analysis
4. **Comparison** - View all three tiers side-by-side
5. **Integration** - Embed rule content in other tools

### Integration Examples

```bash
# Open rule in editor
vim $(./workflows/interrogate-rule.sh BCS0102 --no-metadata | head -1)

# Export all section headers to markdown
for code in BCS{01..14}; do
  ./workflows/interrogate-rule.sh "$code" --format markdown -p >> sections-reference.md
done

# Get file sizes for all rules
./workflows/interrogate-rule.sh BCS* --format json | jq '.tiers[].size_bytes'
```

---

## Compliance Checking Workflow

### Overview

The **check-compliance.sh** workflow provides batch script compliance checking using `bcs check`, with support for multiple output formats and automated reporting.

### Usage

```bash
./workflows/check-compliance.sh [OPTIONS] SCRIPT [SCRIPT ...]

ARGUMENTS:
  SCRIPT                  Path to script file(s) to check
                          Supports glob patterns: *.sh, scripts/**/*.sh

OPTIONS:
  -h, --help              Show help message
  -q, --quiet             Quiet mode (errors only)
  -v, --verbose           Verbose mode (default)
  --strict                Exit non-zero on any violation
  --format FORMAT         Output format: text (default), json, markdown
  --report FILE           Save report to file
  --batch                 Batch mode with summary
```

### Examples

```bash
# Check single script
./workflows/check-compliance.sh script.sh

# Check all shell scripts in directory
./workflows/check-compliance.sh *.sh

# Strict mode for CI/CD (exit non-zero on violations)
./workflows/check-compliance.sh --strict deploy.sh

# JSON output for programmatic analysis
./workflows/check-compliance.sh --format json script.sh

# Batch mode with markdown report
./workflows/check-compliance.sh --batch --report compliance-report.md *.sh

# Multiple scripts with summary
./workflows/check-compliance.sh --batch scripts/deploy.sh scripts/backup.sh scripts/monitor.sh
```

### Batch Mode Output

```
Batch Compliance Summary:
  Total scripts: 10
  Passed: 8
  Failed: 2
  Not found: 0

Failed scripts:
  - scripts/old-script.sh
  - scripts/legacy-deploy.sh
```

### Report Formats

**Markdown Report (`--format markdown --report report.md`):**
```markdown
# BCS Compliance Report

Generated: 2025-10-17 12:45:00

## Summary

- **Total scripts:** 10
- **Passed:** 8
- **Failed:** 2

## Results

### Passed Scripts

- ✓ `deploy.sh`
- ✓ `backup.sh`
...

### Failed Scripts

- ✗ `old-script.sh`
- ✗ `legacy-deploy.sh`
```

**JSON Report (`--format json`):**
```json
{
  "generated": "2025-10-17T12:45:00Z",
  "summary": {
    "total": 10,
    "passed": 8,
    "failed": 2,
    "not_found": 0
  },
  "passed_scripts": [
    "deploy.sh",
    "backup.sh"
  ],
  "failed_scripts": [
    "old-script.sh",
    "legacy-deploy.sh"
  ]
}
```

### CI/CD Integration

```yaml
# .github/workflows/compliance.yml
- name: Check Script Compliance
  run: |
    ./workflows/check-compliance.sh --strict --batch \
      --format json --report compliance.json \
      scripts/*.sh

- name: Upload Compliance Report
  uses: actions/upload-artifact@v3
  with:
    name: compliance-report
    path: compliance.json
```

### Use Cases

1. **Pre-commit Checks** - Validate scripts before committing
2. **CI/CD Validation** - Automated compliance checking in pipelines
3. **Batch Auditing** - Check entire codebase for compliance
4. **Regression Testing** - Ensure refactored scripts remain compliant
5. **Onboarding** - Help new developers learn BCS patterns

---

## Rule Compression Workflow

### Overview

**Status:** 🚧 In Development

The **compress-rules.sh** workflow will provide a user-friendly wrapper around `bcs compress` for AI-powered rule compression.

### Planned Features

- Pre-flight checks (Claude CLI available, data/ valid)
- Progress reporting with ETA
- Post-compression validation
- Timestamp synchronization
- Automatic retry on failures
- Compression statistics

### Planned Usage

```bash
./workflows/compress-rules.sh [OPTIONS]

OPTIONS:
  --tier TIER             Compress specific tier (summary or abstract)
  --context-level LEVEL   Context awareness: none, toc, abstract, summary, complete
  --dry-run               Preview without changes
  --force                 Force recompression of all files
```

### Planned Examples

```bash
# Compress with abstract context (recommended)
./workflows/compress-rules.sh --context-level abstract

# Compress only summary tier
./workflows/compress-rules.sh --tier summary

# Dry run to preview
./workflows/compress-rules.sh --dry-run --context-level abstract

# Force recompression
./workflows/compress-rules.sh --force --context-level abstract
```

### Current Workaround

Until this workflow is complete, use `bcs compress` directly:

```bash
# Report oversized files
bcs compress

# Regenerate all tiers with abstract context
bcs compress --regenerate --context-level abstract
```

---

## Canonical Generation Workflow

### Overview

**Status:** 🚧 In Development

The **generate-canonical.sh** workflow will provide comprehensive canonical file generation with validation and statistics.

### Planned Features

- Generate all three canonical files (`.complete.md`, `.summary.md`, `.abstract.md`)
- Rebuild BCS/ index with symlinks
- Validate generated files
- Before/after comparison statistics
- Update symlink optionally
- Backup previous versions

### Planned Usage

```bash
./workflows/generate-canonical.sh [OPTIONS]

OPTIONS:
  --all                   Generate all three tiers
  --tier TIER             Generate specific tier
  --validate              Validate after generation
  --backup                Backup existing files
  --update-symlink        Update BASH-CODING-STANDARD.md symlink
```

### Planned Examples

```bash
# Generate all tiers with validation
./workflows/generate-canonical.sh --all --validate

# Generate specific tier
./workflows/generate-canonical.sh --tier abstract

# Full regeneration with backup
./workflows/generate-canonical.sh --all --backup --update-symlink
```

### Current Workaround

Use `bcs generate` directly:

```bash
# Generate all three canonical files
bcs generate --canonical

# Generate specific tier to stdout
bcs generate -t abstract

# Update canonical and rebuild BCS/ index
bcs generate --canonical
```

---

## Adding New Rules

### Overview

**Status:** 🚧 In Development

The **add-rule.sh** workflow will provide interactive rule creation with templates and automatic validation.

### Planned Features

- Interactive prompts for section, rule number, name
- Auto-generate BCS code based on location
- Validate no duplicate codes
- Create all three tiers from templates
- Update BCS/ index automatically
- Run validation after creation

### Planned Workflow

```bash
./workflows/add-rule.sh [OPTIONS]

OPTIONS:
  --section NUMBER        Section number (01-14)
  --number NUMBER         Rule number within section
  --name NAME             Short descriptive name
  --interactive           Interactive mode (default)
  --template TYPE         Template: minimal, standard, comprehensive
```

### Planned Examples

```bash
# Interactive mode
./workflows/add-rule.sh

# Non-interactive with all parameters
./workflows/add-rule.sh --section 02 --number 06 --name "special-vars" \
  --template standard

# With custom tier templates
./workflows/add-rule.sh --section 08 --number 05 --name "trap-handlers" \
  --template comprehensive
```

### Manual Process (Current)

Until this workflow is complete, add rules manually:

1. **Choose location:**
   ```bash
   # Example: Adding rule 06 to section 02 (variables)
   cd data/02-variables/
   ```

2. **Create template files:**
   ```bash
   # Create all three tiers
   touch 06-new-rule.complete.md
   touch 06-new-rule.summary.md
   touch 06-new-rule.abstract.md
   ```

3. **Edit `.complete.md` (source of truth):**
   ```markdown
   ### New Rule Title

   <!-- BCS0206 -->

   Detailed explanation...

   **Examples:**
   ...
   ```

4. **Compress to other tiers:**
   ```bash
   cd ../..
   bcs compress --regenerate --context-level abstract
   ```

5. **Validate:**
   ```bash
   ./workflows/validate-data.sh
   ```

6. **Regenerate canonical:**
   ```bash
   bcs generate --canonical
   ```

---

## Modifying Existing Rules

### Overview

**Status:** 🚧 In Development

The **modify-rule.sh** workflow will provide safe rule modification with automatic recompression and validation.

### Planned Features

- Identify rule by BCS code or file path
- Edit `.complete.md` in default editor
- Optional automatic recompression
- Preserve or regenerate `.summary.md` and `.abstract.md`
- Validate modifications
- Backup original before changes

### Planned Usage

```bash
./workflows/modify-rule.sh [OPTIONS] CODE_OR_FILE

OPTIONS:
  --editor EDITOR         Editor to use (default: $EDITOR)
  --no-compress           Don't auto-compress after edit
  --validate              Validate after modification
  --backup                Backup original file
```

### Planned Examples

```bash
# Modify rule (opens in editor, then recompresses)
./workflows/modify-rule.sh BCS0206

# Modify without auto-compression
./workflows/modify-rule.sh BCS0206 --no-compress

# Modify with validation
./workflows/modify-rule.sh BCS0206 --validate
```

### Manual Process (Current)

1. **Edit the `.complete.md` file:**
   ```bash
   vim data/02-variables/06-special-vars.complete.md
   ```

2. **Recompress if significant changes:**
   ```bash
   bcs compress --regenerate --context-level abstract
   ```

3. **Validate:**
   ```bash
   ./workflows/validate-data.sh
   ```

4. **Regenerate canonical:**
   ```bash
   bcs generate --canonical
   ```

---

## Deleting Rules

### Overview

**Status:** 🚧 In Development

The **delete-rule.sh** workflow will provide safe rule deletion across all tiers with reference checking.

### Planned Features

- Delete rule across all three tiers
- Update BCS/ index
- Check for references in other rules
- Backup before deletion
- Confirm before irreversible operations
- Optional dry-run mode

### Planned Usage

```bash
./workflows/delete-rule.sh [OPTIONS] CODE

OPTIONS:
  --force                 Skip confirmation prompts
  --backup                Backup deleted files
  --dry-run               Show what would be deleted
  --check-references      Check for references (default)
```

### Planned Examples

```bash
# Delete with confirmation
./workflows/delete-rule.sh BCS0206

# Dry run (preview deletion)
./workflows/delete-rule.sh BCS0206 --dry-run

# Force delete with backup
./workflows/delete-rule.sh BCS0206 --force --backup
```

### Manual Process (Current)

1. **Find all tier files:**
   ```bash
   bcs decode BCS0206 --all
   # Lists: .complete.md, .summary.md, .abstract.md
   ```

2. **Check for references:**
   ```bash
   grep -r "BCS0206" data/
   ```

3. **Delete all tiers:**
   ```bash
   rm data/02-variables/06-special-vars.{complete,summary,abstract}.md
   ```

4. **Update BCS/ index:**
   ```bash
   bcs generate --canonical
   ```

5. **Validate:**
   ```bash
   ./workflows/validate-data.sh
   ```

---

## Best Practices

### General Workflow Principles

1. **Always Validate First**
   ```bash
   ./workflows/validate-data.sh
   ```
   Run validation before and after major changes.

2. **Use Version Control**
   ```bash
   git status
   git diff
   git add -p
   git commit -m "Add new rule BCS0206: Special variables"
   ```

3. **Test Workflows in Isolation**
   ```bash
   # Use temporary directory for testing
   cp -r data/ /tmp/data-test/
   # Test workflow on /tmp/data-test/
   ```

4. **Backup Before Destructive Operations**
   ```bash
   tar -czf data-backup-$(date +%Y%m%d).tar.gz data/
   ```

### Rule Management Best Practices

1. **Edit `.complete.md` as Source of Truth**
   - Never edit `.summary.md` or `.abstract.md` directly
   - Regenerate summary/abstract from complete tier

2. **Use Meaningful Rule Names**
   - Good: `06-special-variables.md`
   - Bad: `06-misc.md`, `06-stuff.md`

3. **Follow BCS Code Structure**
   - Section: `BCS01` (two digits)
   - Rule: `BCS0206` (four digits)
   - Subrule: `BCS020601` (six digits)

4. **Maintain Tier Size Limits**
   - Abstract: ≤ 1500 bytes (concise rules only)
   - Summary: ≤ 10000 bytes (key examples)
   - Complete: ≤ 20000 bytes (comprehensive)

### Validation Best Practices

1. **Run Validation Frequently**
   - After adding rules
   - After modifying rules
   - Before commits
   - In CI/CD pipelines

2. **Use Appropriate Validation Modes**
   - Development: `./workflows/validate-data.sh -v`
   - CI/CD: `./workflows/validate-data.sh -q --exit-on-error`
   - Analysis: `./workflows/validate-data.sh --json`

3. **Address Warnings Promptly**
   - Warnings indicate potential issues
   - Fix oversized files before they grow larger

### Compliance Checking Best Practices

1. **Check Scripts Early and Often**
   - During development
   - Before code review
   - In pre-commit hooks
   - In CI/CD pipelines

2. **Use Strict Mode in CI/CD**
   ```bash
   ./workflows/check-compliance.sh --strict --batch scripts/*.sh
   ```

3. **Generate Reports for Auditing**
   ```bash
   ./workflows/check-compliance.sh --batch --report audit-$(date +%Y%m%d).md scripts/*.sh
   ```

---

## Troubleshooting

### Common Issues

#### Validation Failures

**Issue:** Missing tier files
**Symptom:** `Missing abstract tier for: data/02-variables/06-new-rule.complete.md`
**Solution:**
```bash
bcs compress --regenerate --context-level abstract
```

**Issue:** Duplicate BCS codes
**Symptom:** `Duplicate BCS code detected: BCS0206`
**Solution:**
```bash
# Find duplicates
./workflows/validate-data.sh | grep "Duplicate"
# Rename or merge duplicate files
```

**Issue:** Invalid file naming
**Symptom:** `Found 3 file(s) with invalid names`
**Solution:**
```bash
# Files must match: NN-name.tier.md
# Bad: 6-vars.complete.md
# Good: 06-vars.complete.md
mv data/02-variables/6-vars.complete.md data/02-variables/06-vars.complete.md
```

#### Interrogation Failures

**Issue:** Failed to decode BCS code
**Symptom:** `Failed to decode BCS code: BCS9999`
**Solution:**
```bash
# Verify code exists
bcs codes | grep BCS9999
# If missing, code doesn't exist
```

**Issue:** File not found for code
**Symptom:** `File not found for code BCS0206`
**Solution:**
```bash
# Check if file exists
bcs decode BCS0206 --exists
# Regenerate BCS/ index
bcs generate --canonical
```

#### Compliance Checking Failures

**Issue:** Claude CLI not found
**Symptom:** `'claude' command not found`
**Solution:**
```bash
# Install Claude CLI
# See: https://claude.ai/code

# Verify installation
claude --version
```

**Issue:** Batch mode reports failures
**Symptom:** `Failed: 5` scripts
**Solution:**
```bash
# Review individual failures
./workflows/check-compliance.sh script1.sh script2.sh
# Fix violations based on detailed output
```

### Debugging Tips

1. **Enable Verbose Mode**
   ```bash
   ./workflows/validate-data.sh -v
   ```

2. **Use Dry-Run When Available**
   ```bash
   ./workflows/compress-rules.sh --dry-run  # When implemented
   ```

3. **Check Logs**
   ```bash
   ./workflows/validate-data.sh 2>&1 | tee validation.log
   ```

4. **Test with Single Items First**
   ```bash
   # Before batch
   ./workflows/check-compliance.sh single-script.sh

   # Then batch
   ./workflows/check-compliance.sh --batch *.sh
   ```

### Getting Help

1. **Workflow Help**
   ```bash
   ./workflows/validate-data.sh --help
   ./workflows/interrogate-rule.sh --help
   ./workflows/check-compliance.sh --help
   ```

2. **BCS Command Help**
   ```bash
   bcs help
   bcs help decode
   bcs help compress
   ```

3. **Report Issues**
   - GitHub Issues: https://github.com/OkusiAssociates/bash-coding-standard/issues
   - Include: workflow name, error message, command used

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: BCS Validation and Compliance

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Validate BCS Data Structure
        run: |
          ./workflows/validate-data.sh --quiet --exit-on-error

      - name: Check Script Compliance
        run: |
          ./workflows/check-compliance.sh --strict --batch \
            --format json --report compliance.json \
            scripts/*.sh

      - name: Upload Compliance Report
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: compliance-report
          path: compliance.json
```

### GitLab CI Example

```yaml
# .gitlab-ci.yml
stages:
  - validate
  - compliance

validate-data:
  stage: validate
  script:
    - ./workflows/validate-data.sh --quiet --exit-on-error

check-compliance:
  stage: compliance
  script:
    - ./workflows/check-compliance.sh --strict --batch scripts/*.sh
  artifacts:
    paths:
      - compliance-report.json
    when: always
```

### Pre-commit Hook Example

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Validate data structure
./workflows/validate-data.sh -q || {
  echo "❌ Data validation failed!"
  exit 1
}

# Check compliance of staged .sh files
staged_scripts=$(git diff --cached --name-only --diff-filter=ACM | grep '\.sh$')
if [[ -n "$staged_scripts" ]]; then
  ./workflows/check-compliance.sh --strict $staged_scripts || {
    echo "❌ Compliance check failed!"
    exit 1
  }
fi

echo "✅ All checks passed!"
```

### Continuous Validation

```bash
# Cron job for nightly validation
# /etc/cron.d/bcs-validation

0 2 * * * cd /path/to/bash-coding-standard && \
  ./workflows/validate-data.sh --json > /var/log/bcs/validation-$(date +\%Y\%m\%d).json
```

---

## Summary

The BCS workflow system provides comprehensive, automated tools for managing the Bash Coding Standard:

### Available Now (v1.0.0)
- ✅ **validate-data.sh** - 11 comprehensive validation checks
- ✅ **interrogate-rule.sh** - Rule inspection and metadata extraction
- ✅ **check-compliance.sh** - Batch compliance checking with reporting

### Coming Soon
- 🚧 **compress-rules.sh** - AI-powered rule compression wrapper
- 🚧 **generate-canonical.sh** - Canonical file generation workflow
- 🚧 **add-rule.sh** - Interactive rule creation
- 🚧 **modify-rule.sh** - Safe rule modification
- 🚧 **delete-rule.sh** - Rule deletion with safety checks

### Key Benefits
- **Consistency** - Standardized workflows for all users
- **Automation** - Reduce manual errors and repetitive tasks
- **Validation** - Built-in integrity checks
- **Testing** - Comprehensive test coverage
- **CI/CD Ready** - Designed for automation pipelines

---

**For questions, issues, or contributions:**
GitHub: https://github.com/OkusiAssociates/bash-coding-standard

**Version:** 1.0.0
**Last Updated:** 2025-10-17
**Status:** Living document - updated as workflows evolve

#fin
