# Bash Coding Standard

A comprehensive coding standard for modern Bash 5.2+ scripts, designed for consistency, robustness, and maintainability.

Bash is a battle-tested, sophisticated programming language deployed on virtually every Unix-like system on Earth -- from supercomputers to smartphones, from cloud servers to embedded devices.

Despite persistent misconceptions that it's merely "glue code" or unsuitable for serious development, Bash possesses powerful constructs for complex data structures, robust error handling, and elegant control flow. When wielded with discipline and proper engineering principles -- rather than as ad-hoc command sequences -- Bash delivers production-grade solutions for system automation, data processing, and infrastructure orchestration. This standard codifies that discipline, transforming Bash from a loose scripting tool into a reliable programming platform.

## Overview

This repository contains the canonical Bash coding standards developed by [Okusi Associates](https://okusiassociates.com) and adopted by the [Indonesian Open Technology Foundation (YaTTI)](https://yatti.id). These standards define precise patterns for writing production-grade Bash scripts that are both human-readable and machine-parseable.

## Purpose

Modern software development increasingly relies on automated refactoring, AI-assisted coding, and static analysis tools. This standard provides:

- **Deterministic patterns** that enable reliable automated code transformation
- **Strict structural requirements** that facilitate computer-aided programming and refactoring
- **Consistent conventions** that reduce cognitive load for both human developers and language models
- **Security-first practices** that prevent common shell scripting vulnerabilities

## Key Features

- Targets Bash 5.2+ exclusively (not a compatibility standard)
- Enforces strict error handling with `set -euo pipefail`
- Requires explicit variable declarations with type hints
- Mandates ShellCheck compliance
- Defines standard utility functions for consistent messaging
- Specifies precise file structure and naming conventions
- 14 comprehensive sections covering all aspects of Bash scripting

## Table of Contents

- [Quick Start](#quick-start)
  - [Installation](#installation)
  - [Using the BCS Toolkit](#using-the-bcs-toolkit)
  - [Subcommands Reference](#subcommands-reference)
  - [Validate Your Scripts](#validate-your-scripts)
- [Workflows](#workflows)
  - [Available Workflows](#available-workflows)
  - [Real-World Examples](#real-world-examples)
  - [Comprehensive Documentation](#comprehensive-documentation)
  - [Testing](#testing)
- [Core Principles](#core-principles)
- [Minimal Example](#minimal-example)
- [Repository Structure](#repository-structure)
- [BCS Code Structure](#bcs-code-structure)
- [Performance Enhancement: Bash Builtins](#performance-enhancement-bash-builtins)
- [Documentation](#documentation)
- [Usage Guidance](#usage-guidance)
- [Validation Tools](#validation-tools)
- [Recent Changes](#recent-changes)
- [Conclusions](#conclusions)
- [Contributing](#contributing)
- [Related Resources](#related-resources)
- [Troubleshooting](#troubleshooting)
- [License](#license)
- [Acknowledgments](#acknowledgments)

## Quick Start

### Installation

Clone this repository and optionally install system-wide:

```bash
# Clone the repository
git clone https://github.com/OkusiAssociates/bash-coding-standard.git
cd bash-coding-standard

# Run from cloned directory (development mode)
./bash-coding-standard          # Main script
./bcs                           # Convenience symlink (shorter)

# Or install system-wide (recommended for system use)
sudo make install

# Or install manually
sudo mkdir -p /usr/local/bin
sudo mkdir -p /usr/local/share/yatti/bash-coding-standard
sudo cp bash-coding-standard /usr/local/bin/
sudo chmod +x /usr/local/bin/bash-coding-standard
sudo cp BASH-CODING-STANDARD.md /usr/local/share/yatti/bash-coding-standard/
```

**Uninstall:**
```bash
sudo make uninstall

# Or manually
sudo rm /usr/local/bin/bash-coding-standard
sudo rm -rf /usr/local/share/yatti/bash-coding-standard
```

### Using the BCS Toolkit

The `bcs` script (symlink to `bash-coding-standard`) provides a comprehensive toolkit with multiple subcommands:

```bash
# View the standard (default command)
./bcs                           # Auto-detect best viewer
./bcs display                   # Explicit display command

# Display with options
./bcs display --cat             # Force plain text output
./bcs display --json            # Export as JSON
./bcs display --bash            # Export as bash variable
./bcs display --squeeze         # Squeeze consecutive blank lines

# Legacy compatibility (still works)
./bcs -c                        # Same as: ./bcs display --cat
./bcs --json                    # Same as: ./bcs display --json

# Project information and statistics
./bcs about                     # Show project information
./bcs about --stats             # Statistics only
./bcs about --links             # Links and references only
./bcs about --json              # JSON output for scripting

# Generate BCS-compliant script templates
./bcs template                  # Generate basic template (stdout)
./bcs template -t complete -o script.sh -x   # Complete template, executable
./bcs template -t minimal       # Minimal template
./bcs template -t library -n mylib       # Library template

# AI-powered compliance checker (requires Claude Code CLI)
./bcs check myscript.sh         # Comprehensive compliance check
./bcs check --strict deploy.sh  # Strict mode for CI/CD
./bcs check --format json script.sh      # JSON output
./bcs check --format markdown script.sh  # Markdown report

# List all BCS rule codes (replaces getbcscode.sh)
./bcs codes                     # List all 99 BCS codes

# Regenerate the standard (replaces regenerate-standard.sh)
./bcs generate                  # Generate complete standard to stdout
./bcs generate --canonical      # Regenerate canonical file
./bcs generate -t abstract      # Generate abstract version
./bcs generate -t summary       # Generate summary version

# Search within the standard
./bcs search "readonly"         # Basic search
./bcs search -i "SET -E"        # Case-insensitive
./bcs search -C 5 "declare -fx" # With context lines

# Decode BCS codes to file locations or view content
./bcs decode BCS010201          # Show file location (default tier via symlink)
./bcs decode BCS010201 -p       # Print rule content to stdout
./bcs decode BCS01              # Section codes supported (returns 00-section file)
./bcs decode BCS01 BCS02 BCS08  # Multiple codes supported
./bcs decode BCS0102 --all      # Show all three tiers
./bcs decode BCS01 BCS0102 -p   # Print contents of multiple codes

# List all sections
./bcs sections                  # Show all 14 sections

# Get help
./bcs help                      # General help
./bcs help check                # Help for specific subcommand
./bcs --version                 # Show version: bcs 1.0.0

# If installed globally
bcs codes | head -10            # First 10 BCS codes
bcs check deploy.sh > compliance-report.txt
```

**Toolkit Features:**
- **11 Subcommands**: display, about, template, check, compress, codes, generate, search, decode, sections, help
- **No command aliases** - Simplified UX with canonical names only (v1.0.0+)
- **Symlink-based tier detection** - Default tier from BASH-CODING-STANDARD.md symlink
- **AI-powered validation**: Leverage Claude for comprehensive compliance checking
- **AI-powered compression**: Automatically compress rules to summary/abstract tiers with context awareness
- **Template generation**: Create BCS-compliant scripts instantly
- **Comprehensive help**: `bcs help [subcommand]`
- **Backward compatible**: Legacy options still work
- **Dual-purpose**: Can be executed or sourced for functions
- **FHS-compliant**: Searches standard locations

### Subcommands Reference

The `bcs` toolkit provides eleven powerful subcommands for working with the Bash Coding Standard:

#### display (Default)

View the coding standard document with multiple output formats:

```bash
bcs                          # Auto-detect (md2ansi if available)
bcs display                  # Explicit

# Output formats
bcs display --cat            # Plain text (no formatting)
bcs display --json           # JSON export
bcs display --bash           # Bash variable declaration
bcs display --squeeze        # Squeeze blank lines

# Backward compatible (legacy)
bcs -c                       # Same as display --cat
bcs -j                       # Same as display --json
bcs -b                       # Same as display --bash
```

**Purpose:** View the complete BASH-CODING-STANDARD.md document
**Use case:** Reference while writing scripts, studying patterns

#### codes

List all BCS rule codes from the data/ directory tree:

```bash
bcs codes                    # List all codes

# Output format: BCS{code}:{shortname}:{title}
# Example output:
#   BCS010201:dual-purpose:Dual-Purpose Scripts (Executable and Sourceable)
#   BCS0103:metadata:Script Metadata
#   BCS0205:readonly-after-group:Readonly After Group Declaration
```

**Purpose:** Catalog all 99 BCS rule codes with their descriptions
**Replaces:** `getbcscode.sh` script
**Use case:** Finding specific rules, building documentation indexes

#### generate

Regenerate BASH-CODING-STANDARD.md from the data/ directory:

```bash
bcs generate                 # Generate complete standard
bcs generate -t abstract     # Abstract version (rules only)
bcs generate -t summary      # Summary version (medium detail)
bcs generate -t complete     # Complete version (default, all examples)

bcs generate -o FILE         # Output to specific file
bcs generate --stdout        # Output to stdout

# Examples
bcs generate -t abstract -o BASH-CODING-STANDARD-SHORT.md
bcs generate --stdout | wc -l
```

**Purpose:** Build the standard document from source files
**Replaces:** `regenerate-standard.sh` script
**Use case:** Creating custom versions, updating after rule edits

**Tier types:**
- `complete` - Complete standard with all examples (21,431 lines)
- `summary` - Medium detail, key examples only (12,666 lines)
- `abstract` - Minimal version, rules and patterns only (3,794 lines)

#### search

Search within the coding standard document:

```bash
bcs search PATTERN           # Basic search
bcs search -i PATTERN        # Case-insensitive
bcs search -C NUM PATTERN    # Show NUM context lines

# Examples
bcs search "readonly"
bcs search -i "SET -E"
bcs search -C 10 "declare -fx"
bcs search "BCS0205"         # Search for specific code
```

**Purpose:** Quickly find patterns, rules, or examples
**Use case:** Looking up specific syntax, finding rule references

#### decode

Resolve BCS codes to file locations or print rule content directly.

**Options:**
```bash
# Tier selection
bcs decode BCS####              # Default tier (symlink-based, currently abstract)
bcs decode BCS#### -c           # Complete tier  -s summary  -a abstract  --all (all three)

# Output modes
bcs decode BCS####              # Show file path
bcs decode BCS#### -p           # Print content to stdout

# Path formatting
bcs decode BCS#### --relative   # Relative path  --basename (filename only)
bcs decode BCS#### --exists     # Silent validation (exit 0 if exists)

# Multiple codes (v1.0.0+)
bcs decode BCS01 BCS02 -p       # Print multiple codes with separators
```

**Quick examples:**
```bash
# View rule content
bcs decode BCS0102 -p | less

# Open in editor
vim $(bcs decode BCS0205)

# Validate existence
bcs decode BCS0102 --exists && echo "Exists"

# Multiple section overviews
bcs decode BCS01 BCS08 BCS13 -p
```

**Purpose:** Resolve BCS codes to file locations or view rule content
**Default tier:** Symlink-based (currently abstract)
**New in v1.0.0:** Section codes, multiple codes, symlink-based defaults

**See also:** `docs/BCS-DECODE-PATTERNS.md` for 9 advanced usage patterns (editor integration, tier comparison, batch processing, etc.)

#### sections

List all 14 sections in the standard:

```bash
bcs sections                 # List all sections

# Output:
#   1. Coding Principles
#   2. Contents
#   3. Script Structure & Layout
#   4. Variable Declarations & Constants
#   ...
#   16. Advanced Patterns
```

**Purpose:** Quick overview of standard structure
**Use case:** Navigation, understanding organization

#### about

Display project information, statistics, and metadata:

```bash
bcs about                    # Default: project info + philosophy + quick stats

# Focused outputs
bcs about --stats            # Detailed statistics only
bcs about --links            # Documentation links and references
bcs about --quote            # Philosophy and coding principles
bcs about --json             # JSON output for scripting
bcs about --verbose          # Comprehensive (all information)

# Example outputs
bcs about --stats
#   Repository Statistics:
#   - Sections: 14
#   - Total rules: 99
#   - Lines of standard: 3,794 (abstract tier, canonical symlink)
#   - Complete tier: 21,431 lines
#   - Summary tier: 12,666 lines
#   - Source files: 99 (.complete.md files)
#   - Test files: 19
```

**Purpose:** Get project metadata and repository statistics
**Use case:** Understanding scope, documentation links, CI/CD integration
**Output modes:** text (default), stats, links, quote, json, verbose

#### template

Generate BCS-compliant script templates instantly:

```bash
bcs template                 # Generate basic template to stdout

# Template types
bcs template -t minimal      # Minimal (~13 lines): set -e, error(), die(), main()
bcs template -t basic        # Basic (~27 lines): + metadata, messaging functions
bcs template -t complete     # Complete (~104 lines): + colors, arg parsing, all utilities
bcs template -t library      # Library (~38 lines): sourceable script pattern

# Output options
bcs template -o script.sh    # Write to file
bcs template -o script.sh -x # Make executable
bcs template -o script.sh -f # Force overwrite existing file

# Customization
bcs template -n myapp        # Set script name (replaces {{NAME}})
bcs template -d "Deploy script" # Set description
bcs template -v "2.0.0"      # Set version number

# Complete example
bcs template -t complete -n deploy -d "Production deployment script" \
             -v "1.5.0" -o deploy.sh -x
```

**Purpose:** Bootstrap new BCS-compliant scripts instantly
**Replaces:** Manual copying and adapting example scripts
**Use case:** Starting new scripts, learning patterns, rapid prototyping
**Templates include:** All mandatory structure, standard functions, proper patterns

**Template types:**
- `minimal` - Bare essentials: shebang, set -e, error/die functions, main()
- `basic` - Standard script: + metadata (VERSION, SCRIPT_PATH), messaging functions
- `complete` - Complete toolkit: + colors, verbose/quiet/debug flags, argument parsing, all utilities
- `library` - Sourceable library: proper export patterns, namespace prefixes, init function

**Placeholders:**
- `{{NAME}}` - Script/library name (auto-inferred from output filename)
- `{{DESCRIPTION}}` - Brief description comment
- `{{VERSION}}` - Version string (default: 1.0.0)

#### check

AI-powered compliance checking using Claude Code CLI:

```bash
bcs check SCRIPT             # Comprehensive compliance check

# Output formats
bcs check --format text script.sh     # Human-readable report (default)
bcs check --format json script.sh     # JSON for CI/CD integration
bcs check --format markdown script.sh # Markdown report

# Strict mode for CI/CD
bcs check --strict script.sh  # Exit non-zero on any violation
bcs check --strict *.sh       # Check multiple scripts

# Custom Claude command
bcs check --claude-cmd /path/to/claude script.sh

# Example CI/CD integration
bcs check --strict --format json deploy.sh > compliance-report.json
```

**Purpose:** Validate scripts against all 14 sections of BASH-CODING-STANDARD.md
**Requires:** Claude Code CLI (`claude` command must be available)
**Use case:** Pre-commit checks, code review, CI/CD validation, learning compliance

**Validation coverage (all 14 sections):**
1. Script structure and layout compliance
2. Variable declarations and constants
3. Variable expansion patterns
4. Quoting rules (single vs double quotes)
5. Array usage and iteration
6. Function definitions and organization
7. Control flow patterns
8. Error handling (set -e, traps, return values)
9. Messaging functions and output
10. Command-line argument parsing
11. File operations and testing
12. Security considerations
13. Code style and best practices
14. Advanced patterns usage

**How it works:**
- Embeds entire BASH-CODING-STANDARD.md (3,525 lines, abstract tier) as Claude's system prompt
- Claude analyzes script with full context of all rules
- Returns natural language explanations (not cryptic error codes)
- Understands intent, context, and legitimate exceptions
- Evaluates comment quality (WHY vs WHAT)

**Benefits over static analysis:**
- Context-aware (understands why rules exist)
- Natural language feedback
- Recognizes legitimate exceptions mentioned in standard
- Evaluates comment quality and documentation
- No false positives from regex patterns
- Automatically updates as standard evolves

#### compress (Developer Mode)

AI-powered compression of BCS rule files using Claude Code CLI.

**Basic usage:**
```bash
bcs compress                              # Report oversized files
bcs compress --regenerate                 # Regenerate all tiers
bcs compress --regenerate --context-level abstract   # Recommended (deduplication across rules)
```

**Common options:**
```bash
--tier summary|abstract               # Compress specific tier only
--context-level none|toc|abstract|summary|complete  # Context awareness (default: none)
--summary-limit 10000                 # Max summary size (bytes)
--abstract-limit 1500                 # Max abstract size (bytes)
--dry-run                             # Preview without changes
```

**Purpose:** Compress .complete.md files to .summary.md and .abstract.md tiers using AI
**Requires:** Claude Code CLI (`claude` command must be available)
**Use case:** Maintaining multi-tier documentation, compressing custom rules

**Context levels:**
- `none` - Fastest, each rule in isolation (default)
- `abstract` - Recommended, cross-rule deduplication (~83KB context)
- `toc`, `summary`, `complete` - Increasing context awareness

**Size limits:**
- summary: 10000 bytes (adjustable)
- abstract: 1500 bytes (adjustable)

**Note:** Developer-mode feature for maintaining the multi-tier system. Most users don't need this - the repository already contains compressed tiers. See `docs/BCS-COMPRESS-GUIDE.md` for detailed guide.

### Unified Toolkit Benefits

The `bcs` script provides a unified command interface with multiple benefits:

- Single command interface (`bcs`) with 11 specialized subcommands
- Consistent help system (`bcs help <subcommand>`)
- Better error messages and validation
- Backward compatibility with legacy options (e.g., `bcs -c`, `bcs --json`)
- Additional features (search, decode, sections, compress)
- Comprehensive test coverage (19 test files)

### Validate Your Scripts

```bash
# All scripts must pass ShellCheck
shellcheck -x your-script.sh

# For scripts with documented exceptions
shellcheck -x your-script.sh
# Use #shellcheck disable=SCxxxx with explanatory comments
```

## Workflows

**NEW:** The `workflows/` directory provides production-ready scripts for common BCS maintenance and development tasks. These 8 comprehensive workflow scripts (2,700+ lines) automate rule management, data validation, and compliance checking.

**Quick Overview:**
- 🔍 **validate-data.sh** - 11 validation checks for data integrity
- 📊 **interrogate-rule.sh** - Inspect rules by BCS code or file path
- ✅ **check-compliance.sh** - Batch compliance checking with reports
- 📝 **generate-canonical.sh** - Generate canonical BCS files
- 🗜️ **compress-rules.sh** - AI-powered rule compression
- ➕ **add-rule.sh** - Create new rules interactively
- ✏️ **modify-rule.sh** - Safely edit existing rules
- 🗑️ **delete-rule.sh** - Delete rules with safety checks

All workflows include dry-run modes, backup options, and comprehensive error handling.

### Available Workflows

#### validate-data.sh
Comprehensive validation of the `data/` directory structure:

```bash
./workflows/validate-data.sh              # Run all 11 validation checks
./workflows/validate-data.sh --check tier-completeness  # Specific check
./workflows/validate-data.sh --quiet      # Minimal output
```

**Validation checks:**
1. Tier file completeness (.complete, .summary, .abstract all present)
2. BCS code uniqueness (no duplicate codes)
3. File naming conventions (NN-name.tier.md pattern)
4. BCS code format validation
5. Section directory naming
6. File size limits (summary ≤10KB, abstract ≤1.5KB)
7. BCS code markers in files
8. #fin markers present
9. Markdown structure validity
10. Cross-reference validation
11. Sequential numbering checks

#### interrogate-rule.sh
Inspect rules by BCS code or file path:

```bash
./workflows/interrogate-rule.sh BCS0102              # Show rule info
./workflows/interrogate-rule.sh BCS0102 --show-tiers # Show all three tiers
./workflows/interrogate-rule.sh BCS0102 --format json  # JSON output
./workflows/interrogate-rule.sh data/01-script-structure/03-metadata.complete.md
```

#### check-compliance.sh
Batch compliance checking with multiple output formats:

```bash
./workflows/check-compliance.sh script.sh           # Check single script
./workflows/check-compliance.sh *.sh                # Batch checking
./workflows/check-compliance.sh --format json script.sh
./workflows/check-compliance.sh --strict deploy.sh  # CI/CD mode
```

#### generate-canonical.sh
Generate canonical BASH-CODING-STANDARD files from data/:

```bash
./workflows/generate-canonical.sh                   # Generate all tiers
./workflows/generate-canonical.sh --tier complete   # Specific tier
./workflows/generate-canonical.sh --backup          # Backup before generating
./workflows/generate-canonical.sh --validate        # Validate after generation
```

#### compress-rules.sh
AI-powered wrapper for rule compression:

```bash
./workflows/compress-rules.sh                       # Check for oversized files
./workflows/compress-rules.sh --regenerate          # Regenerate all tiers
./workflows/compress-rules.sh --context-level abstract  # With context awareness
./workflows/compress-rules.sh --dry-run             # Preview changes
```

#### add-rule.sh
Add new BCS rules interactively:

```bash
./workflows/add-rule.sh                             # Interactive mode
./workflows/add-rule.sh --section 02 --number 10 --name new-rule
./workflows/add-rule.sh --no-interactive --section 08 --number 05 --name trap-handlers
```

#### modify-rule.sh
Modify existing rules safely:

```bash
./workflows/modify-rule.sh BCS0206                  # Edit by code
./workflows/modify-rule.sh data/02-variables/06-special-vars.complete.md
./workflows/modify-rule.sh BCS0206 --no-compress   # Skip auto-compression
./workflows/modify-rule.sh BCS0206 --validate      # Validate after edit
```

#### delete-rule.sh
Delete rules with safety checks:

```bash
./workflows/delete-rule.sh BCS9999                  # Delete with confirmation
./workflows/delete-rule.sh BCS9999 --dry-run        # Preview deletion
./workflows/delete-rule.sh BCS9999 --force --no-backup  # Skip confirmation and backup
./workflows/delete-rule.sh BCS9999 --no-check-refs  # Skip reference checking
```

### Real-World Examples

The `examples/` directory contains three production-ready BCS-compliant scripts demonstrating real-world patterns:

**production-deploy.sh** (305 lines)
- Production deployment with backup and rollback
- Environment validation, health checks
- Dry-run mode, confirmation prompts
- Demonstrates: Complete BCS compliance, error handling, user interaction

**data-processor.sh** (184 lines)
- CSV file processing with validation
- Field validation, statistics tracking
- Demonstrates: Array operations, file I/O, validation patterns

**system-monitor.sh** (380 lines)
- System resource monitoring with alerts
- CPU, memory, disk usage tracking
- Email alerts, continuous monitoring mode
- Demonstrates: Thresholds, logging, colorized output

### Comprehensive Documentation

See **[docs/WORKFLOWS.md](docs/WORKFLOWS.md)** (1132 lines) for:
- Detailed workflow guides
- Usage examples and patterns
- Best practices
- Troubleshooting
- CI/CD integration examples

### Testing

All workflow scripts have comprehensive test coverage:
- `tests/test-workflow-validate.sh` - 16 tests
- `tests/test-workflow-interrogate.sh` - 10 tests
- `tests/test-workflow-check-compliance.sh` - 10 tests
- `tests/test-workflow-generate.sh` - 9 tests
- `tests/test-workflow-compress.sh` - 10 tests
- `tests/test-workflow-add.sh` - 8 tests
- `tests/test-workflow-modify.sh` - 10 tests
- `tests/test-workflow-delete.sh` - 11 tests

Run all workflow tests:
```bash
./tests/run-all-tests.sh  # Includes all 27 test files
```

## Core Principles

### Script Structure Requirements

Every script must follow this structure:

1. Shebang: `#!/usr/bin/env bash` (or `#!/bin/bash`)
2. ShellCheck directives (if needed)
3. Brief description comment
4. `set -euo pipefail`
5. `shopt` settings (strongly recommended: `inherit_errexit`, `shift_verbose`)
6. Script metadata (`SCRIPT_PATH`, `SCRIPT_DIR`, `SCRIPT_NAME`)
7. Global declarations
8. Color definitions (if terminal output)
9. Utility functions (messaging, helpers)
10. Business logic functions
11. `main()` function (for scripts >40 lines)
12. Script invocation: `main "$@"`
13. End marker: `#fin`

### Essential Patterns

**Variable Declarations:**
```bash
declare -i INTEGER_VAR=1      # Integers
declare -- STRING_VAR=''      # Strings
declare -a ARRAY_VAR=()       # Indexed arrays
declare -A HASH_VAR=()        # Associative arrays
readonly -- CONSTANT='val'    # Constants
local -i local_var=0          # Function locals
```

**Quoting Rules:**
```bash
# Use single quotes for static strings
info 'Processing files...'

# Use double quotes when variables are needed
info "Processing $count files"

# Always quote variables in conditionals
[[ -f "$file" ]] && process "$file"
```

**Error Handling:**
```bash
set -euo pipefail             # Mandatory
shopt -s inherit_errexit      # Strongly recommended

# Standard error functions
error() { >&2 _msg "$@"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }
```

## Minimal Example

A simple script following the standard:

```bash
#!/usr/bin/env bash
# Count files in directories
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Script metadata
SCRIPT_PATH=$(realpath -- "$0")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Global variables
declare -i VERBOSE=1

# Colors
[[ -t 1 && -t 2 ]] && declare -- GREEN=$'\033[0;32m' NC=$'\033[0m' || declare -- GREEN='' NC=''
readonly -- GREEN NC

# Messaging functions
_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  [[ "${FUNCNAME[1]}" == success ]] && prefix+=" ${GREEN}✓${NC}"
  for msg in "$@"; do printf '%s %s\n' "$prefix" "$msg"; done
}
success() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
error() { >&2 _msg "$@"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

# Business logic
count_files() {
  local -- dir="$1"
  local -i count
  [[ -d "$dir" ]] || die 1 "Not a directory: $dir"

  count=$(find "$dir" -maxdepth 1 -type f | wc -l)
  success "Found $count files in $dir"
}

main() {
  local -- dir

  # Validate arguments
  (($# > 0)) || die 1 'No directory specified'

  # Process each directory
  for dir in "$@"; do
    count_files "$dir"
  done
}

main "$@"
#fin
```

## Repository Structure

```
bash-coding-standard/
├── BASH-CODING-STANDARD.md          # Symlink to default tier (currently abstract, 3,794 lines)
├── BASH-CODING-STANDARD.complete.md # Complete tier (21,431 lines)
├── BASH-CODING-STANDARD.summary.md  # Summary tier (12,666 lines)
├── BASH-CODING-STANDARD.abstract.md # Abstract tier (3,794 lines)
├── bash-coding-standard             # Main toolkit script (v1.0.0)
├── bcs                              # Symlink to bash-coding-standard (convenience)
├── README.md                        # This file
├── ACTION-ITEMS.md                  # Consolidated action items from archived planning docs
├── TESTING-SUMMARY.md               # Test suite documentation (19 files, 600+ tests, 74% pass)
├── LICENSE                          # CC BY-SA 4.0 license
├── Makefile                         # Installation/uninstallation helper
├── docs/                            # Comprehensive usage guides
│   ├── BCS-DECODE-PATTERNS.md       # Advanced decode patterns and workflows (481 lines)
│   └── BCS-COMPRESS-GUIDE.md        # Complete compression guide (665 lines)
├── .gudang/                         # Archived analysis and planning documents
├── data/                            # Canonical rule source files (generates standard)
│   ├── 01-script-structure/         # Section 1 rules
│   │   ├── 02-shebang/              # Shebang subsection
│   │   │   └── 01-dual-purpose.md   # BCS010201 - Dual-purpose scripts
│   │   ├── 03-metadata.md           # BCS0103 - Script metadata
│   │   └── ...
│   ├── 02-variables/                # Section 2 rules
│   └── ...
├── workflows/                       # User workflow scripts for typical BCS operations
│   ├── validate-data.sh             # Validate data/ directory (11 checks)
│   ├── interrogate-rule.sh          # Inspect rules by BCS code or file path
│   ├── check-compliance.sh          # Batch compliance checking with reports
│   ├── generate-canonical.sh        # Generate canonical BCS files from data/
│   ├── compress-rules.sh            # AI-powered rule compression wrapper
│   ├── add-rule.sh                  # Add new BCS rule interactively
│   ├── modify-rule.sh               # Modify existing rule safely
│   └── delete-rule.sh               # Delete rule with safety checks
├── examples/                        # Real-world BCS-compliant example scripts
│   ├── production-deploy.sh         # Production deployment with backup/rollback
│   ├── data-processor.sh            # CSV processing with validation
│   └── system-monitor.sh            # System resource monitoring with alerts
├── tests/                           # Test suite (27 test files, 650+ tests)
│   ├── test-helpers.sh              # Test helper functions (12 enhanced helpers)
│   ├── coverage.sh                  # Test coverage analyzer
│   ├── run-all-tests.sh             # Run entire test suite
│   ├── fixtures/                    # Test fixture scripts
│   │   ├── sample-minimal.sh        # Minimal BCS-compliant script
│   │   ├── sample-complete.sh       # Full-featured BCS-compliant script
│   │   └── sample-non-compliant.sh  # Non-compliant script for testing
│   ├── test-bash-coding-standard.sh # Core functionality tests
│   ├── test-argument-parsing.sh     # Argument parsing tests
│   ├── test-data-structure.sh       # Data directory integrity validation
│   ├── test-integration.sh          # End-to-end workflow tests
│   ├── test-self-compliance.sh      # BCS compliance self-validation
│   ├── test-subcommand-dispatcher.sh # Command routing tests
│   ├── test-subcommand-display.sh   # Display subcommand tests
│   ├── test-subcommand-about.sh     # About subcommand tests
│   ├── test-subcommand-codes.sh     # Codes subcommand tests
│   ├── test-subcommand-generate.sh  # Generate subcommand tests
│   ├── test-subcommand-search.sh    # Search subcommand tests
│   ├── test-subcommand-decode.sh    # Decode subcommand tests
│   ├── test-subcommand-sections.sh  # Sections subcommand tests
│   ├── test-subcommand-template.sh  # Template subcommand tests
│   ├── test-subcommand-check.sh     # Check subcommand tests
│   ├── test-subcommand-compress.sh  # Compress subcommand tests
│   ├── test-workflow-validate.sh    # Workflow validation tests
│   ├── test-workflow-interrogate.sh # Workflow interrogation tests
│   ├── test-workflow-check-compliance.sh # Workflow compliance tests
│   ├── test-workflow-generate.sh    # Workflow generation tests
│   ├── test-workflow-compress.sh    # Workflow compression tests
│   ├── test-workflow-add.sh         # Workflow add-rule tests
│   ├── test-workflow-modify.sh      # Workflow modify-rule tests
│   └── test-workflow-delete.sh      # Workflow delete-rule tests
└── builtins/                        # High-performance loadable builtins (separate sub-project)
    ├── README.md                    # Complete user guide
    ├── QUICKSTART.md                # Fast-start installation
    ├── CREATING-BASH-BUILTINS.md   # Developer guide
    ├── PERFORMANCE.md               # Benchmark results
    ├── Makefile                     # Build system
    ├── install.sh / uninstall.sh   # Installation scripts
    ├── src/                         # C source code (basename, dirname, realpath, head, cut)
    └── test/                        # Builtin test suite
```

## BCS Code Structure

Each rule in the Bash Coding Standard is identified by a unique BCS code derived from its location in the directory structure.

**Format:** `BCS{catNo}[{ruleNo}][{subruleNo}]`

All numbers are **two-digit zero-padded** (e.g., BCS1401, BCS0402, BCS010201).

**Directory-to-Code Mapping:**
```
data/
├── 01-script-structure/              → BCS01 (Section)
│   ├── 02-shebang.md                → BCS0102 (Rule)
│   ├── 02-shebang/                  → (Subrule container)
│   │   └── 01-dual-purpose.md       → BCS010201 (Subrule)
│   ├── 03-metadata.md               → BCS0103 (Rule)
│   └── 07-function-organization.md  → BCS0107 (Rule)
├── 02-variables/                     → BCS02 (Section)
│   ├── 01-type-specific.md          → BCS0201 (Rule)
│   └── 05-readonly-after-group.md   → BCS0205 (Rule)
└── 14-advanced-patterns/             → BCS14 (Section)
    └── 03-temp-files.md             → BCS1403 (Rule)
```

**Key Principles:**

- **Numeric prefixes define codes**: `01-script-structure/02-shebang/01-dual-purpose.md` → BCS010201
- **Never use non-numeric prefixes**: `02a-`, `02b-` breaks the code system
- **Use subdirectories for subrules**: Not alphabetic suffixes
- **System supports unlimited nesting**: BCS01020304... is valid
- **Code extraction**: Use `bcs codes` to automatically extract codes from file paths

**Example:**
```bash
./bcs codes
# Output:
# BCS010201:dual-purpose:Dual-Purpose Scripts (Executable and Sourceable)
# BCS0103:metadata:Script Metadata
# BCS0201:type-specific:Type-Specific Declarations
# ...
```

**Legacy:** The `getbcscode.sh` script is still available but replaced by `bcs codes`.

The BCS code system ensures:
- **Unique identification**: Every rule has a distinct code
- **Hierarchical organization**: Codes reflect section/rule/subrule relationships
- **Deterministic generation**: File path directly determines code
- **Machine-parseable references**: Tools can link rules to specific file locations

### BCS Rules Filename Structure

Understanding the filename structure is critical for adding or modifying rules.

**Filename Format:**
```
[0-9][0-9]-{short-rule-desc}.{tier}.md
```

Where:
- `[0-9][0-9]` = Two-digit zero-padded number (01, 02, 03, etc.)
- `{short-rule-desc}` = Brief descriptive name (e.g., `layout`, `shebang`, `readonly-after-group`)
- `{tier}` = One of: `complete`, `summary`, or `abstract`

**Example:**
```
01-script-structure/
├── 01-layout.complete.md       # BCS0101 - Complete tier
├── 01-layout.summary.md        # BCS0101 - Summary tier
├── 01-layout.abstract.md       # BCS0101 - Abstract tier
├── 02-shebang.complete.md      # BCS0102 - Complete tier
├── 02-shebang.summary.md       # BCS0102 - Summary tier
├── 02-shebang.abstract.md      # BCS0102 - Abstract tier
```

**Critical Filename Rules:**

1. **Unique numbers**: Each two-digit number must be unique within its directory
   - `01-layout.complete.md` ✓
   - `01-shebang.complete.md` ✗ (01 already used)
   - `02-shebang.complete.md` ✓

2. **Three tiers always together**: Every rule must have all three versions with identical numbers and base names
   - `05-example.complete.md`
   - `05-example.summary.md`
   - `05-example.abstract.md`

3. **Short description flexibility**: The descriptive name can be modified slightly without changing the BCS code
   - `01-layout.complete.md` → BCS0101
   - `01-script-layout.complete.md` → Still BCS0101 (same number)

4. **No duplicate numbers**: If you rename a rule and the number stays the same, delete the old files first
   - Renaming `03-old-name.complete.md` → `03-new-name.complete.md`
   - Must delete all `03-old-name.*.md` files before creating `03-new-name.*.md` files

**Source-Generated Hierarchy:**

**`.complete.md` is the CANONICAL source** - the other two tiers are derivatives:

```
01-layout.complete.md  (SOURCE - manually written)
    ↓ generates
01-layout.summary.md   (DERIVED - compressed version)
    ↓ generates
01-layout.abstract.md  (DERIVED - minimal version)
```

**Workflow:**
1. Edit the `.complete.md` file (the authoritative version)
2. Generate `.summary.md` and `.abstract.md` from it using compression tools
3. Never edit `.summary.md` or `.abstract.md` directly - regenerate them from `.complete.md`
4. Run `./bcs generate --canonical` to rebuild the final BASH-CODING-STANDARD.md

## Performance Enhancement: Bash Builtins

The `builtins/` subdirectory contains a **separate sub-project** that provides high-performance bash loadable builtins to replace common external utilities. These builtins run directly inside the bash process, providing **10-158x performance improvements** by eliminating fork/exec overhead.

### Available Builtins

- **basename** (101x faster) - Strip directory from paths
- **dirname** (158x faster) - Extract directory component
- **realpath** (20-100x faster) - Resolve absolute paths
- **head** (10-30x faster) - Output first lines of files
- **cut** (15-40x faster) - Field/character extraction

### Quick Start

```bash
# Install for current user (no root required)
cd builtins
./install.sh --user

# Or install system-wide
sudo ./install.sh --system

# Verify installation
check_builtins
```

### When to Use

Maximum benefit when scripts:
- Call these utilities in loops (1000+ iterations)
- Process many files in batch operations
- Run in CI/CD pipelines or containers
- Require performance optimization

**Example performance gain:**
```bash
# Processing 100 files: 30 seconds → 2 seconds (15x faster)
for file in *.sh; do
    dir=$(dirname "$file")      # 158x faster than /usr/bin/dirname
    base=$(basename "$file")    # 101x faster than /usr/bin/basename
    # ... process files
done
```

### Documentation

- **[builtins/README.md](builtins/README.md)** - Complete user guide and installation
- **[builtins/QUICKSTART.md](builtins/QUICKSTART.md)** - Fast-start installation guide
- **[builtins/CREATING-BASH-BUILTINS.md](builtins/CREATING-BASH-BUILTINS.md)** - Developer guide for creating custom builtins
- **[builtins/PERFORMANCE.md](builtins/PERFORMANCE.md)** - Benchmark results and methodology

**Status:** Production-ready v1.0.0 (separate sub-project, optional enhancement)

**Note:** Builtins are **optional** and not required for BCS compliance. They provide performance enhancements for scripts that frequently call these utilities.

## Documentation

### Primary Documents

- **[BASH-CODING-STANDARD.md](BASH-CODING-STANDARD.md)** - The coding standard (symlink to abstract tier, 3,794 lines, 14 sections)
  - Also available: [Complete tier](BASH-CODING-STANDARD.complete.md) (21,431 lines), [Summary tier](BASH-CODING-STANDARD.summary.md) (12,666 lines)
- **[ACTION-ITEMS.md](ACTION-ITEMS.md)** - Consolidated action items from archived planning documents
- **[TESTING-SUMMARY.md](TESTING-SUMMARY.md)** - Test suite documentation (27 files, 650+ tests)

**Usage Guides:**
- **[docs/WORKFLOWS.md](docs/WORKFLOWS.md)** - **NEW:** Complete workflow automation guide (1,132 lines, 14 sections)
- **[docs/BCS-DECODE-PATTERNS.md](docs/BCS-DECODE-PATTERNS.md)** - Comprehensive decode patterns and workflows (481 lines, 9 usage patterns)
- **[docs/BCS-COMPRESS-GUIDE.md](docs/BCS-COMPRESS-GUIDE.md)** - Complete compression guide with context levels (665 lines)

**Archived Reference:**
- See `.gudang/REBUTTALS-FAQ.md` for responses to common criticisms and FAQs (archived)

### Standard Structure (14 Sections)

1. **Script Structure & Layout** - Complete script organization with full example
2. **Variable Declarations & Constants** - All variable patterns including readonly
3. **Variable Expansion & Parameter Substitution** - When to use braces
4. **Quoting & String Literals** - Single vs double quotes
5. **Arrays** - Declaration, iteration, safe list handling
6. **Functions** - Definition, organization, export
7. **Control Flow** - Conditionals, case, loops, arithmetic
8. **Error Handling** - Consolidated: set -e, exit codes, traps, return value checking
9. **Input/Output & Messaging** - Standard messaging functions, colors, echo vs messaging
10. **Command-Line Arguments** - Parsing patterns, validation
11. **File Operations** - Testing, wildcards, process substitution, here docs
12. **Security Considerations** - SUID, PATH, eval, IFS, input sanitization
13. **Code Style & Best Practices** - Formatting, language practices, development practices
14. **Advanced Patterns** - Dry-run, testing, progressive state management, temp files

## Usage Guidance

### For Human Developers

1. Read [BASH-CODING-STANDARD.md](BASH-CODING-STANDARD.md) thoroughly
2. Use the standard utility functions (`_msg`, `vecho`, `success`, `warn`, `info`, `error`, `die`)
3. Always run `shellcheck -x` before committing
4. Follow the 14-section structure when reading/writing complex scripts
5. Use single quotes for static strings, double quotes for variables

### For AI Assistants

1. All generated scripts must comply with BASH-CODING-STANDARD.md
2. Use the standard messaging functions consistently
3. Include proper error handling in all functions
4. Remove unused utility functions in production scripts (see Section 6: Production Script Optimization)

### Integration with Editors

**VSCode:**
```json
{
  "shellcheck.enable": true,
  "shellcheck.executablePath": "/usr/bin/shellcheck",
  "shellcheck.run": "onSave"
}
```

**Vim/Neovim:**
```vim
" Add to .vimrc or init.vim
let g:syntastic_sh_shellcheck_args = '-x'
```

## Validation Tools

- **ShellCheck** (mandatory): `shellcheck -x script.sh`
- **bash -n** (syntax check): `bash -n script.sh`
- **Test frameworks**: [bats-core](https://github.com/bats-core/bats-core) for testing

## Recent Changes

### v1.1.0 (2025-10-17) - Workflow System Addition

**NEW: Comprehensive Workflow Automation System**
- **8 Production-Ready Workflow Scripts** (2,700+ lines)
  - `validate-data.sh` - 11 validation checks for data/ directory integrity
  - `interrogate-rule.sh` - Rule inspection with multiple output formats
  - `check-compliance.sh` - Batch compliance checking with JSON/markdown reports
  - `generate-canonical.sh` - Canonical file generation with backup/validation
  - `compress-rules.sh` - AI-powered compression with context awareness
  - `add-rule.sh` - Interactive rule creation with templates
  - `modify-rule.sh` - Safe rule modification with auto-backup
  - `delete-rule.sh` - Safe deletion with reference checking

- **Real-World Examples** (3 scripts, 870 lines)
  - `production-deploy.sh` - Production deployment patterns
  - `data-processor.sh` - CSV processing and validation
  - `system-monitor.sh` - System resource monitoring

- **Comprehensive Testing** (8 test suites, 59 tests)
  - Test fixtures for all scenarios
  - Integration with existing test framework
  - All tests use standard test-helpers.sh pattern

- **Documentation**
  - `docs/WORKFLOWS.md` (1,132 lines) - Complete workflow guide
  - README.md updated with workflow section
  - Usage examples and best practices
  - CI/CD integration patterns

**Features:**
- ✅ Complete CRUD operations for BCS rules
- ✅ Data validation and integrity checking
- ✅ Multiple output formats (text, JSON, markdown)
- ✅ Safety features (dry-run, backups, confirmations)
- ✅ AI integration for compression and compliance
- ✅ Fully tested and documented

### v1.0.0 (2025-10-17) - Major Improvements

**Phase 4: Alias Removal & Symlink-Based Configuration**
- **All command aliases removed** for simplification (v1.0.0+)
  - Removed: `show`, `info`, `list-codes`, `regen`, `grep`, `toc`
  - Impact: Cleaner UX, reduced cognitive load, simpler documentation
  - Use canonical names only: `display`, `about`, `codes`, `generate`, `search`, `sections`

- **Symlink-based default tier detection** implemented (v1.0.0+)
  - New function: `get_default_tier()` reads `BASH-CODING-STANDARD.md` symlink
  - Default tier now dynamic based on symlink target (`.complete.md`, `.abstract.md`, `.summary.md`)
  - Commands affected: `generate`, `decode`, `check`
  - Single source of truth for default tier configuration
  - Change default tier project-wide: `ln -sf BASH-CODING-STANDARD.complete.md BASH-CODING-STANDARD.md`

- **Test Suite Enhancements** (see `TESTING-SUMMARY.md`)
  - **19 test files** (was 15), 600+ tests, **74% pass rate** (was 6%)
  - New tests: data structure validation, integration tests, self-compliance
  - Coverage tracking: 39% function coverage, 100% command coverage
  - CI/CD pipelines: Automated testing, shellcheck, releases
  - 12 new test helpers: Enhanced assertions, mocking, fixtures

- **Bugs discovered and fixed:**
  1. Duplicate BCS0206 code (critical - needs resolution)
  2. Missing main() function in bcs script
  3. Missing VERSION variable
  4. Corrupted data file (fixed: `data/01-script-structure/02-shebang/01-dual-purpose.complete.md`)

**BCS Toolkit Enhancements:**
- **Section codes supported** - `BCS01`, `BCS02`, etc. return `00-section.{tier}.md` files
- **Multiple codes supported** in `bcs decode` - process multiple codes in a single command
  - Example: `bcs decode BCS01 BCS02 BCS08 -p` prints all three sections
  - Automatic separators added between codes in print mode
- **Three-tier documentation system** fully implemented:
  - **Complete** (.complete.md) - Full examples and explanations (canonical source, 21,431 lines)
  - **Summary** (.summary.md) - Medium detail with key examples (derived, 12,666 lines)
  - **Abstract** (.abstract.md) - Rules and patterns only (derived, 3,794 lines)
- **New `compress` subcommand** for maintaining multi-tier documentation:
  - AI-powered compression of .complete.md files to .summary.md and .abstract.md tiers
  - Five context awareness levels (none, toc, abstract, summary, complete) for cross-rule deduplication
  - Automatic file permissions (664) and timestamp syncing across tiers

**Documentation:**
- README.md significantly expanded with comprehensive usage patterns
- CLAUDE.md updated with Phase 4 changes and test information
- TESTING-SUMMARY.md created documenting complete test suite revamp
- Clarified section codes, multiple codes, and tier selection
- Updated all examples to reflect symlink-based defaults

### 2025-10-10 Restructuring

The standard was restructured from 15 sections to 14 sections with significant improvements:

- **Reduced**: 2,246 lines → 2,145 lines (4.5% reduction)
- **Split**: "String Operations" into two focused sections:
  - Variable Expansion & Parameter Substitution
  - Quoting & String Literals
- **Consolidated**: Error Handling (previously fragmented across sections)
- **Eliminated**: Incoherent "Calling Commands" section (content redistributed)
- **Organized**: Best Practices into themed subsections
- **Preserved**: ALL rules, ALL examples, ALL security guidelines

## Conclusions

This standard transforms Bash from a loose scripting tool into a reliable programming platform by codifying engineering discipline for production-grade automation, data processing, and infrastructure orchestration.

### Core Philosophy

Modern software development increasingly relies on automated refactoring, AI-assisted coding, and static analysis tools. This standard provides **deterministic patterns**, **strict structural requirements**, **consistent conventions**, and **security-first practices** designed to be equally parseable by humans and AI assistants.

### Key Pillars

The standard is built on four foundational pillars (detailed in Core Principles section):

1. **Structural Discipline**: 13-step mandatory script structure, bottom-up function organization, required `main()` for scripts >40 lines
2. **Safety & Reliability**: Strict error handling (`set -euo pipefail`), safe arithmetic patterns, process substitution over pipes, explicit wildcard paths
3. **Code Clarity**: Explicit variable declarations with type hints, readonly after group pattern, consistent quoting discipline (single for static, double for expansion)
4. **Production Quality**: Standard messaging functions, ShellCheck compliance, security hardening (no SUID/SGID, PATH validation, input sanitization)

### Compliance Requirements

- **Bash 5.2+ exclusive** - Modern features, not a compatibility standard
- **ShellCheck compulsory** - All scripts must pass with documented exceptions
- **FHS (Filesystem Hierarchy Standard)** - Standard installation locations
- **CC BY-SA 4.0 license** - Attribution required, share-alike for derivatives

### Flexibility & Pragmatism

The standard emphasizes **avoiding over-engineering**. Scripts should be as simple as necessary, but no simpler:

- Scripts >40 lines require `main()` function; shorter scripts can be simpler
- Remove unused utility functions in production
- Include only required structures—not every script needs all patterns
- Provides comprehensive patterns for complex scripts while allowing simpler structures for straightforward tasks

**Target audience:** Both human developers building production systems and AI assistants generating/refactoring code. Deterministic patterns enable both to produce consistent, maintainable, secure Bash scripts.

---

**In summary:** This standard codifies professional Bash development as disciplined engineering, providing structure for reliable automation while matching complexity to requirements.

## Contributing

This standard evolves through practical application in production systems. Contributions are welcome:

1. **Propose changes** via GitHub Issues with clear rationale
2. **Submit pull requests** with specific improvements
3. **Document real-world use cases** that demonstrate value
4. **Test thoroughly** with `shellcheck` before submitting

Changes should demonstrate clear benefits for:
- Code reliability
- Maintainability
- Automation capabilities
- Security
- Clarity for both humans and AI assistants

## Related Resources

- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) - Industry reference standard
- [ShellCheck](https://www.shellcheck.net/) - Required static analysis tool (compulsory)
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/bash.html) - Official Bash documentation
- [Advanced Bash-Scripting Guide](https://tldp.org/LDP/abs/html/) - Comprehensive reference
- [Bash Loadable Builtins](builtins/) - High-performance replacements for common utilities (this repository)

## Troubleshooting

### ShellCheck Warnings

If you see ShellCheck warnings:
1. First, try to fix the code to comply with the warning
2. Only disable checks when absolutely necessary
3. Document the reason with a comment:
   ```bash
   #shellcheck disable=SC2046  # Intentional word splitting for flag expansion
   ```

### Script Not Working After Compliance

Common issues:
- Forgot to quote variables in conditionals
- Used `((i++))` instead of `i+=1` or `((i+=1))`
- Forgot `set -euo pipefail` and script is failing on undefined variables
- Missing `shopt -s inherit_errexit` causing subshell issues

### Getting Help

- Open an issue on GitHub for standard clarifications
- Refer to specific sections in BASH-CODING-STANDARD.md

## License

This work is licensed under [Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)](https://creativecommons.org/licenses/by-sa/4.0/).

You are free to:
- Share and redistribute the material
- Fork, adapt, and build upon the material

Under the following terms:
- **Attribution** - You must give appropriate credit to Okusi Associates and YaTTI
- **ShareAlike** - Distribute contributions under the same license

See [LICENSE](LICENSE) for full details.

## Acknowledgments

Developed by **Okusi Associates** for enterprise Bash scripting. Incorporates compatible elements from Google's Shell Style Guide and industry best practices.

Adopted by the **Indonesian Open Technology Foundation (YaTTI)** for standardizing shell scripting across open technology projects.

---

**For production systems requiring consistent, maintainable, and secure Bash scripting.**

*Version: 1.1.0*
*Last updated: 2025-10-17*
