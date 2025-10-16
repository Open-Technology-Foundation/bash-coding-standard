# ShellCheck & BCS: Comprehensive Architecture Analysis

**Document Date:** October 14, 2025
**Analysis Scope:** ShellCheck v0.11.0 & Bash Coding Standard v1.0.0
**Purpose:** Complete architectural understanding of both systems

---

## Table of Contents

### Part 1: ShellCheck Architecture
1. [ShellCheck Overview](#part-1-shellcheck-architecture)
2. [Project Structure](#shellcheck-project-structure)
3. [How ShellCheck Works](#how-shellcheck-works)
4. [AST Structure](#ast-structure)
5. [Analysis Phase](#analysis-phase)
6. [Check Implementation Pattern](#check-implementation-pattern)
7. [Optional Checks](#optional-checks)
8. [Data Flow](#data-flow)
9. [Advanced Features](#advanced-features)
10. [Testing Infrastructure](#testing-infrastructure)
11. [Output Formats](#output-formats)
12. [Key Design Patterns](#key-design-patterns)
13. [Performance Characteristics](#performance-characteristics)

### Part 2: BCS Architecture
1. [BCS System Overview](#part-2-bcs-system-architecture)
2. [System Architecture](#bcs-system-architecture-1)
3. [Three-Tier Documentation System](#three-tier-documentation-system)
4. [BCS Code System](#bcs-code-system)
5. [Directory Structure](#directory-structure-data-organization)
6. [The bcs Script](#the-bcs-script-11-subcommands)
7. [Key Helper Functions](#key-helper-functions)
8. [Generation Process](#generation-process)
9. [Template System](#template-system)
10. [AI-Powered Validation](#ai-powered-validation-bcs-check)
11. [Dual-Purpose Design](#dual-purpose-design)
12. [Statistics](#bcs-statistics)
13. [Key Design Patterns](#bcs-key-design-patterns)

### Part 3: Comparative Analysis
1. [Side-by-Side Comparison](#part-3-comparative-analysis)
2. [Complementary Nature](#complementary-nature)
3. [Combined Workflow](#combined-workflow)

---

# Part 1: ShellCheck Architecture

## ShellCheck Overview

ShellCheck is a sophisticated static analysis tool for shell scripts written in **Haskell** (~19,000 lines of code). It's a mature, production-ready tool with v0.11.0 released in August 2025.

## ShellCheck Project Structure

### Core Components

```
shellcheck/
├── src/ShellCheck/          # Main source code (27 modules)
│   ├── AST.hs              # Abstract Syntax Tree definitions (~280 lines)
│   ├── Parser.hs           # Bash script parser
│   ├── Analytics.hs        # Core analysis checks (largest file)
│   ├── Analyzer.hs         # Analysis orchestration
│   ├── Checker.hs          # Main checking logic
│   ├── Interface.hs        # Public API definitions
│   ├── Formatter/          # Output formatters (8 formats)
│   │   ├── TTY.hs         # Terminal output
│   │   ├── JSON.hs        # JSON output
│   │   ├── GCC.hs         # GCC-compatible
│   │   └── ...
│   └── Checks/             # Specialized check modules
│       ├── Commands.hs     # Command-specific checks
│       ├── ControlFlow.hs  # Control flow analysis
│       └── Custom.hs       # Custom checks
├── shellcheck.hs           # Main entry point (~636 lines)
├── ShellCheck.cabal        # Build configuration
├── test/                   # Test infrastructure
└── builders/               # Various build systems
```

---

## How ShellCheck Works

### 1. Parsing Phase (`Parser.hs`)
- Parses bash/sh scripts into an **Abstract Syntax Tree (AST)**
- Uses **Parsec** parser combinator library
- Handles multiple shell dialects: `sh`, `bash`, `dash`, `ksh`, `busybox`
- Detects shell type from:
  - Shebang line (`#!/bin/bash`)
  - File extension (`.bash`, `.ksh`, `.sh`)
  - Explicit override (`--shell bash`)
  - In-file annotation (`# shellcheck shell=bash`)

### 2. AST Structure

The AST uses a **recursive token structure**:

```haskell
newtype Root = Root Token
data Token = OuterToken Id (InnerToken Token)

-- 100+ token types representing bash constructs:
data InnerToken t =
    Inner_T_SimpleCommand ...
  | Inner_T_Pipeline ...
  | Inner_T_IfExpression ...
  | Inner_T_ForIn ...
  | Inner_T_Function ...
  | Inner_T_Assignment ...
  -- ... many more
```

Key features:
- Each token has a unique **Id** for position tracking
- Recursive structure allows nested analysis
- Pattern synonyms provide clean matching (`T_SimpleCommand`, `T_Pipeline`, etc.)

### 3. Analysis Phase

ShellCheck runs **two categories of checks**:

#### Tree Checks (run once on AST root):
```haskell
treeChecks = [
    subshellAssignmentCheck,
    checkQuotesInLiterals,
    checkUnusedAssignments,
    checkUnassignedReferences,
    checkUncheckedCdPushdPopd,
    checkUseBeforeDefinition,
    checkArrayValueUsedAsIndex,
    -- ... 14 tree-level checks
]
```

#### Node Checks (run on each AST node):
```haskell
nodeChecks = [
    checkPipePitfalls,
    checkForInQuoted,
    checkUnquotedDollarAt,
    checkNumberComparisons,
    checkConstantIfs,
    checkQuotedCondRegex,
    checkGlobsAsOptions,
    -- ... 100+ node-level checks
]
```

### 4. Check Implementation Pattern

Each check follows this pattern:

```haskell
-- Pattern matching on specific AST nodes
checkUuoc _ (T_Pipeline _ _ (T_Redirecting _ _ cmd:_:_)) =
    checkCommand "cat" (const f) cmd
  where
    f [word] | not (mayBecomeMultipleArgs word || isOption word) =
        style (getId word) 2002
          "Useless cat. Consider 'cmd < file | ..' or 'cmd file | ..' instead."
    f _ = return ()
    isOption word = "-" `isPrefixOf` onlyLiteralString word
checkUuoc _ _ = return ()  -- Pattern doesn't match

-- Property-based testing
prop_checkUuoc1 = verify checkUuoc "cat foo | grep bar"
prop_checkUuoc2 = verifyNot checkUuoc "cat * | grep bar"
```

**Key aspects:**
1. **Pattern matching** on AST structure
2. **Error codes** (SC2002, SC2086, etc.)
3. **Severity levels**: `error`, `warning`, `info`, `style`
4. **Property-based tests** using QuickCheck
5. **Fallback patterns** (`_ _`) to ignore non-matching nodes

### 5. Optional Checks

ShellCheck includes **10 optional checks** that can be enabled:
- `quote-safe-variables` - Quote even safe variables
- `avoid-nullary-conditions` - Require explicit `-n`
- `require-variable-braces` - Always use `${var}`
- `require-double-brackets` - Use `[[` instead of `[`
- `check-set-e-suppressed` - Detect masked `set -e`
- `useless-use-of-cat` - UUOC detection
- And 4 more...

---

## Data Flow

```
Input Script
    ↓
[Parser] → ParseResult {
             prComments: [PositionedComment],  -- Parse errors
             prTokenPositions: Map Id Position,
             prRoot: Maybe Token              -- AST
           }
    ↓
[Analyzer] → AnalysisResult {
               arComments: [TokenComment]     -- Analysis warnings
             }
    ↓
[Checker] → CheckResult {
              crFilename: String,
              crComments: [PositionedComment]  -- All issues
            }
    ↓
[Formatter] → Output (TTY/JSON/GCC/CheckStyle/etc.)
```

---

## Advanced Features

### 1. Source File Tracking
ShellCheck can follow `source` and `.` commands:
```bash
# In main.sh:
source lib.sh
echo "$VAR"  # Will check if VAR is defined in lib.sh
```

Controlled by:
- `--check-sourced` flag
- `# shellcheck source=path` annotations
- `--source-path` directories

### 2. Control Flow Analysis (CFG)
- `ShellCheck.CFG` - Control Flow Graph construction
- `ShellCheck.CFGAnalysis` - Data flow analysis
- Detects: unreachable code, unassigned variables, dead code
- Can be disabled with `--extended-analysis=false`

### 3. Configuration System
Multiple configuration layers:
1. `.shellcheckrc` files (searched up directory tree)
2. Command-line flags
3. In-file annotations (`# shellcheck disable=SC2086`)
4. XDG config directory

Priority: CLI flags > file annotations > .shellcheckrc

### 4. Comment-Based Control
```bash
# shellcheck disable=SC2086
echo $var  # Won't warn about unquoted variable

# shellcheck shell=bash
# Override detected shell type

# shellcheck source=/path/to/file
source "$dynamicfile"  # Tell it where to look
```

---

## Testing Infrastructure

### Property-Based Testing
Uses **QuickCheck** extensively:
```haskell
prop_findsAnalysisIssue = check "echo $1" == [2086]
prop_commentDisablesAnalysisIssue =
    null $ check "#shellcheck disable=SC2086\necho $1"
```

Every check has:
- **Positive tests** - Should detect issue
- **Negative tests** - Should NOT detect issue
- **Edge case tests** - Boundary conditions

Running tests:
```bash
cabal test           # Run all QuickCheck properties
./test/buildtest     # Integration tests
```

---

## Output Formats

ShellCheck supports **8 output formats**:

1. **TTY** (default) - Colorized terminal output
2. **JSON** - Machine-readable JSON
3. **JSON1** - Alternative JSON format
4. **GCC** - GCC-compatible warnings
5. **CheckStyle** - XML format for CI tools
6. **Diff** - Shows suggested fixes
7. **Quiet** - Minimal output
8. **Custom** (via formatters)

---

## Key Design Patterns

### 1. Monad-Based Analysis
```haskell
checkSomething :: Parameters -> Token -> Writer [TokenComment] ()
```
Uses `Writer` monad to collect warnings without explicit state passing.

### 2. Visitor Pattern
```haskell
doAnalysis :: Monad m => (Token -> m ()) -> Token -> m Token
doAnalysis f = analyze f blank return
```
Traverses entire AST, applying checks to each node.

### 3. Type Safety
Strong typing prevents many bugs:
- `Id` is a `newtype` (can't confuse with `Int`)
- `Severity`, `Shell`, `ExecutionMode` are distinct types
- Pattern synonyms provide exhaustive matching

### 4. Modularity
- Checks are independent functions
- Can be enabled/disabled individually
- Easy to add new checks
- Formatters are pluggable

---

## Performance Characteristics

- **Fast**: Parses and analyzes most scripts in milliseconds
- **Memory**: Requires ~2GB RAM to compile (Haskell), but runtime is lightweight
- **Scalable**: Can handle large scripts (10K+ lines)
- **Parallel**: Could analyze multiple files concurrently (not implemented in CLI)

---

## Summary: What Makes ShellCheck Special

1. **Comprehensive Coverage**: 300+ checks covering syntax, semantics, style, security
2. **Shell-Aware**: Understands differences between sh/bash/dash/ksh
3. **Context-Sensitive**: Tracks variable assignments, control flow, data flow
4. **Helpful Messages**: Explains WHY something is wrong, not just WHAT
5. **Configurable**: Multiple ways to customize behavior
6. **Well-Tested**: Extensive property-based testing with QuickCheck
7. **Multiple Dialects**: Handles portability between shells
8. **Integration-Friendly**: Multiple output formats for CI/CD

---

# Part 2: BCS System Architecture

## BCS System Overview

The Bash Coding Standard is an elegantly designed **multi-tier documentation generation system** with **99 rules** organized hierarchically, featuring an **11-subcommand CLI toolkit** and AI-powered validation.

## BCS System Architecture

### Core Components

```
bash-coding-standard/
├── bcs (bash-coding-standard)     # 2,247-line multi-command CLI (63KB)
├── data/                           # Source rule files (396 files)
│   ├── 00-header.{3-tiers}.md     # Document header
│   ├── 01-script-structure/        # Section 1 (21 rules)
│   ├── 02-variables/               # Section 2 (12 rules)
│   ├── ...                         # Sections 3-13
│   ├── 14-advanced-patterns/       # Section 14 (6 rules)
│   └── templates/                  # 4 script templates
├── BASH-CODING-STANDARD.md        # Generated canonical standard (13,376 lines)
└── tests/                          # Comprehensive test suite
```

---

## Three-Tier Documentation System

Every rule exists in **three versions** (detail levels):

### 1. Abstract Tier (`.abstract.md`) - **Fast, Concise**
- Rules only, minimal explanation
- ~500-800 lines total
- **Use case:** Quick validation, AI prompts (token efficiency)
- **Example:** "Use `set -euo pipefail`. Rationale: Strict error handling."

### 2. Complete Tier (`.complete.md`) - **Comprehensive**
- Full explanations with examples, rationale, anti-patterns
- ~13,376 lines (current standard)
- **Use case:** Learning, reference, thorough validation
- **Example:** Detailed shebang selection criteria with edge cases

### 3. Summary Tier (`.summary.md`) - **Medium Detail**
- Key rules with essential examples
- ~2,000-3,000 lines
- **Use case:** Quick reference, refreshers

---

## BCS Code System

### Hierarchical Code Format

```
BCS{catNo}{ruleNo}{subruleNo}...
   └─2─┘ └─2─┘  └──2──┘
```

All numbers are **zero-padded to 2 digits**.

### Code Calculation: Path → BCS Code

The system extracts numeric prefixes from file paths:

```
data/01-script-structure/02-shebang.abstract.md
     └──01──┘            └─02─┘

→ BCS0102  (Section 1, Rule 2)
```

```
data/01-script-structure/02-shebang/01-dual-purpose.abstract.md
     └──01──┘            └─02─┘   └──01──┘

→ BCS010201  (Section 1, Rule 2, Subrule 1)
```

### BCS Code Examples

| Code | File Path | Description |
|------|-----------|-------------|
| `BCS00` | `data/00-header.*.md` | Document header |
| `BCS0100` | `data/01-script-structure/00-section.*.md` | Section 1 intro |
| `BCS0101` | `data/01-script-structure/01-layout.*.md` | Script layout rule |
| `BCS0102` | `data/01-script-structure/02-shebang.*.md` | Shebang rule |
| `BCS010201` | `data/01-script-structure/02-shebang/01-dual-purpose.*.md` | Dual-purpose subrule |
| `BCS0205` | `data/02-variables/05-readonly-after-group.*.md` | Readonly pattern |

**Total codes:** 99 (98 abstract + 98 complete + 99 summary = ~296 files)

---

## Directory Structure: Data Organization

```
data/
├── 00-header.{abstract,complete,summary}.md     # Header (3 files)
├── 01-script-structure/                         # Section 1
│   ├── 00-section.{3-tiers}.md                 # Section intro
│   ├── 01-layout.{3-tiers}.md                  # BCS0101
│   ├── 02-shebang.{3-tiers}.md                 # BCS0102
│   ├── 02-shebang/                             # Subrules directory
│   │   └── 01-dual-purpose.{3-tiers}.md        # BCS010201
│   ├── 03-metadata.{3-tiers}.md                # BCS0103
│   └── ...                                      # More rules
├── 02-variables/                                # Section 2
│   ├── 00-section.{3-tiers}.md
│   ├── 01-type-specific.{3-tiers}.md           # BCS0201
│   └── ...
└── templates/                                   # Script templates
    ├── minimal.sh.template      (14 lines)
    ├── basic.sh.template        (27 lines)
    ├── complete.sh.template     (112 lines)
    └── library.sh.template      (39 lines)
```

**Key principles:**
1. **Two-digit padding:** Always `01-`, `02-`, never `1-`, `2-`
2. **No alphabetic suffixes:** Never `02a-`, `02b-` (breaks code system)
3. **Subrules use directories:** Not `02a-rule.md`, but `02-rule/01-subrule.md`
4. **Unlimited nesting:** `BCS01020301...` supported

---

## The `bcs` Script: 11 Subcommands

### 1. Command Dispatcher Architecture

```bash
# Pattern: bcs SUBCOMMAND [OPTIONS] [ARGS]
bcs display                    # View standard
bcs check script.sh            # AI validation
bcs template -t complete       # Generate template
```

**Dispatcher logic:**
```bash
case "$subcommand" in
  display|show)        cmd_display "$@" ;;
  about|info)          cmd_about "$@" ;;
  template|new)        cmd_template "$@" ;;
  check|validate)      cmd_check "$@" ;;
  codes|list-codes)    cmd_codes "$@" ;;
  generate|regen)      cmd_generate "$@" ;;
  search|grep)         cmd_search "$@" ;;
  explain|show-rule)   cmd_explain "$@" ;;
  decode|resolve)      cmd_decode "$@" ;;
  sections|toc)        cmd_sections "$@" ;;
  help)                cmd_help "$@" ;;
  *)                   error "Unknown command" ;;
esac
```

### 2. Core Subcommands

#### **`display / show`** (lines 2013-2140)
- Auto-detects best viewer: `md2ansi` (colored) or `cat` (plain)
- Supports: `--cat`, `--json`, `--bash`, `--md2ansi`, `--squeeze`
- Default behavior: Auto-detect terminal, use markdown rendering

#### **`about / info`** (lines 1088-1314)
- Project information and statistics
- Options: `--stats`, `--links`, `--verbose`, `--quote`, `--json`
- Outputs: Philosophy, principles, contributors, statistics

#### **`template / new`** (lines 1317-1485)
- Generates BCS-compliant script templates
- 4 types: `minimal` (14L), `basic` (27L), `complete` (112L), `library` (39L)
- Placeholders: `{{NAME}}`, `{{DESCRIPTION}}`, `{{VERSION}}`
- Options: `-t TYPE`, `-n NAME`, `-d DESC`, `-v VERSION`, `-o FILE`, `-x` (executable), `-f` (force)

#### **`check / validate`** (lines 1488-1918) - **★ Most Complex**
- **AI-powered validation** using Claude CLI
- **Token optimization:**
  - Abstract tier (~500 lines) - Fast validation
  - Complete tier (~13,376 lines) - Thorough validation
  - Filtered (--codes/--sections) - Custom scope
- Options:
  - `-s, --strict` - Warnings become violations
  - `-f, --format` - text|json|markdown|bcs-json
  - `--codes CODE1,CODE2` - Validate specific rules
  - `--sections N1,N2` - Validate specific sections
  - `--tier TIER` - abstract|complete|summary
  - `--severity LEVEL` - all|violations|warnings
- **Exit codes:** 0 (compliant), 1 (warnings), 2 (violations)
- **Builds Claude prompt** dynamically with filtered rules

#### **`codes / list-codes`** (lines 74-133)
- Lists all BCS rule codes with titles
- Output format: `BCS{code}:{shortname}:{title}`
- Example: `BCS010201:dual-purpose:Dual-Purpose Scripts`
- Scans `data/` directory for `.abstract.md` files

#### **`generate / regen`** (lines 136-330)
- **Regenerates** BASH-CODING-STANDARD.md from `data/` tree
- Types: `complete`, `abstract`, `summary`, `abstract-complete`
- Options:
  - `-t, --type` - Which tier to generate
  - `-o, --output` - Output file
  - `--canonical` - Overwrite BASH-CODING-STANDARD.md (requires explicit flag)
- **Default:** Outputs to stdout (safe, non-destructive)
- **Inserts formfeed** (`\f`) separators between rules for clean page breaks

#### **`search / grep`** (lines 333-406)
- Searches within BASH-CODING-STANDARD.md
- Options: `-i` (ignore case), `-C NUM` (context lines)
- Uses `grep` with color and line numbers

#### **`explain / show-rule`** (lines 971-1040)
- Shows detailed explanation of specific BCS code
- Options: `-a` (abstract), `-c` (complete), `-s` (summary)
- Example: `bcs explain BCS010201` → Shows dual-purpose pattern

#### **`decode / resolve`** (lines 785-968)
- **Inverse of `get_bcs_code()`** - Converts code to file path
- Options:
  - `-a, -s, -c` - Which tier
  - `-p, --print` - Print contents instead of path
  - `--all` - Show all three tiers
  - `--relative`, `--basename` - Path format
  - `--exists` - Check existence (exit code only)
- Use cases:
  - `vim $(bcs decode BCS0205)` - Edit rule file
  - `bcs decode BCS0102 -p | less` - View with pager
  - `diff <(bcs decode BCS0102 -a -p) <(bcs decode BCS0102 -c -p)` - Compare tiers

#### **`sections / toc`** (lines 1043-1085)
- Lists all 14 sections with titles
- Extracts `## ` headers from BASH-CODING-STANDARD.md

#### **`help`** (lines 1921-2011)
- Shows general help or command-specific help
- `bcs help` - Top-level help
- `bcs help check` - Check command help
- `bcs check --help` - Also works

---

## Key Helper Functions

### **`find_bcs_file()`** (lines 15-29)
- Searches for BASH-CODING-STANDARD.md in FHS locations:
  1. Script directory (development mode)
  2. `/usr/local/share/yatti/bash-coding-standard/`
  3. `/usr/share/yatti/bash-coding-standard/`

### **`get_bcs_code()`** (lines 34-50)
- Extracts BCS code from file path
- Algorithm:
  1. Find all `##-` patterns in path
  2. Extract numeric prefixes: `['01', '02', '01']`
  3. Concatenate and prefix with "BCS": `BCS010201`

### **`find_bcs_file_by_code()`** (lines 409-447)
- **Inverse operation** of `get_bcs_code()`
- Given `BCS0205`, finds `data/02-variables/05-readonly-after-group.abstract.md`
- Supports all three tiers

### **`build_validation_prompt()`** (lines 592-742)
- Constructs Claude AI validation prompt
- Embeds full or filtered BCS rules
- Supports multiple output formats (text, JSON, markdown)
- **Token optimization:** Only includes requested rules/sections

### **`load_filtered_rules()`** (lines 517-589)
- Loads BCS rules filtered by codes or sections
- Supports prefix matching (e.g., `BCS01` matches all Section 1 rules)

### **`parse_codes_option()`** (lines 449-482)
- Parses comma-separated BCS codes
- Validates each code exists
- Normalizes format (adds BCS prefix, uppercase)

### **`parse_sections_option()`** (lines 484-514)
- Converts section numbers (1-14) to BCS code prefixes
- Example: `1` → `BCS01`, `2` → `BCS02`

---

## Generation Process

### How `bcs generate` Works

```bash
$ bcs generate --canonical
```

**Steps:**
1. **Find all files:** `find data/ -name "*.abstract.md" | sort`
2. **Iterate and concatenate:**
   ```bash
   for file in "${md_files[@]}"; do
     echo "**Rule: $(get_bcs_code "$file")**"
     echo
     cat "$file"
     echo -e "\n\n---\n\n\f\n"  # Formfeed separator
   done > BASH-CODING-STANDARD.md
   ```
3. **Append footer:** `echo '#fin'`

**Output:** 13,376-line BASH-CODING-STANDARD.md with 99 rules

---

## Template System

### Placeholder Substitution

Templates use `{{PLACEHOLDER}}` format:

```bash
#!/usr/bin/env bash
# {{DESCRIPTION}}
set -euo pipefail

# Script name: {{NAME}}
# Version: {{VERSION}}
```

**Processing:**
```bash
content="${content//\{\{NAME\}\}/$script_name}"
content="${content//\{\{DESCRIPTION\}\}/$description}"
content="${content//\{\{VERSION\}\}/$version}"
```

### Template Types & Use Cases

| Template | Lines | Use Case |
|----------|-------|----------|
| `minimal` | 14 | Quick scripts, throwaway automation |
| `basic` | 27 | Most production scripts (recommended) |
| `complete` | 112 | Complex scripts, user-facing tools |
| `library` | 39 | Shared functions, sourceable modules |

**Key differences:**
- **Minimal:** Just `error()`, `die()`, `main()`
- **Basic:** Adds metadata (VERSION, SCRIPT_PATH, SCRIPT_DIR, SCRIPT_NAME)
- **Complete:** Full toolkit (colors, messaging suite, argument parsing, `yn()` prompt)
- **Library:** No `set -e`, namespace-prefixed, exported functions

---

## AI-Powered Validation (`bcs check`)

### Architecture

```
Script → [bcs check] → [Build Prompt] → [Claude CLI] → Analysis
                            ↓
                    Load BCS Rules
                  (filtered or full)
                            ↓
                    Validation Prompt
                      (abstract tier
                       or complete)
```

### Token Optimization Strategy

| Tier | Lines | Tokens (est.) | Use Case |
|------|-------|---------------|----------|
| Abstract | ~500 | ~1,500 | Fast validation, CI/CD |
| Complete | ~13,376 | ~40,000 | Thorough learning checks |
| Filtered (--codes) | Variable | Depends | Specific rule validation |
| Filtered (--sections) | Variable | Depends | Section-specific checks |

**Example commands:**
```bash
# Fast validation (abstract tier)
bcs check myscript.sh

# Thorough validation
bcs check --tier complete myscript.sh

# Validate only script structure (Section 1)
bcs check --sections 1 myscript.sh

# Validate specific rules
bcs check --codes BCS01,BCS08 myscript.sh

# CI/CD mode
bcs check --strict --quiet --severity violations deploy.sh
```

### Output Formats

#### Text Format (default):
```
✓ COMPLIANT: [BCS0102 - Shebang] - Uses #!/bin/bash
✗ VIOLATION: [BCS0104 - FHS] - Missing set -euo pipefail at line 3
⚠ WARNING: [BCS0205 - Readonly] - Variable should be readonly at line 15
💡 SUGGESTION: [Best practice] - Consider using main() function
```

#### BCS-JSON Format:
```json
{
  "file": "myscript.sh",
  "validation_scope": {
    "codes": ["BCS01", "BCS02"],
    "tier": "abstract",
    "timestamp": "2025-10-14T06:00:00Z"
  },
  "findings": {
    "violations": [
      {"line": 15, "code": "BCS0104", "severity": "critical", "message": "..."}
    ],
    "warnings": [],
    "suggestions": []
  },
  "summary": {
    "violations_count": 1,
    "compliance_percentage": 95,
    "assessment": "needs_work"
  }
}
```

---

## Dual-Purpose Design

The `bcs` script works as **both executable and library**:

### Executed Mode:
```bash
$ ./bcs display
$ bcs codes
$ bcs check script.sh
```

**Behavior:**
- Sets `set -euo pipefail`
- Finds BASH-CODING-STANDARD.md in FHS locations
- Dispatches to subcommands

### Sourced Mode:
```bash
$ source bcs
$ cmd_display
$ cmd_codes
```

**Behavior:**
- Skips `set -e` (doesn't modify caller's shell)
- Pre-loads `BCS_MD` variable with file content
- Makes all variables readonly
- Exports all `cmd_*` functions

**Detection:**
```bash
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  # Sourced mode
  return
fi

# Executed mode
set -euo pipefail
# ... dispatcher logic
```

---

## BCS Statistics

| Metric | Value |
|--------|-------|
| **Sections** | 14 |
| **Total Rules** | 99 BCS codes |
| **Rule Files** | 98 abstract + 98 complete + 99 summary = 296 files |
| **Generated Standard** | 13,376 lines (complete tier) |
| **BCS Script** | 2,247 lines, 63KB |
| **Subcommands** | 11 (with aliases: 22 names) |
| **Templates** | 4 types (minimal, basic, complete, library) |
| **Test Files** | 15+ comprehensive test scripts |
| **Data Files** | 396 markdown files in data/ |

---

## BCS Key Design Patterns

### 1. Hierarchical Code System
- **Path-based:** BCS codes derived from file paths
- **Deterministic:** Same path always generates same code
- **Scalable:** Unlimited nesting depth
- **Reversible:** `get_bcs_code()` ↔ `find_bcs_file_by_code()`

### 2. Three-Tier Documentation
- **Separation of concerns:** Abstract (rules), Complete (learning), Summary (reference)
- **Token optimization:** Choose tier based on use case
- **Consistent structure:** All rules have all three tiers
- **Generation flexibility:** Can generate any tier or combination

### 3. Subcommand Dispatcher
- **Modular:** Each command is self-contained function
- **Exportable:** Functions can be sourced individually
- **Testable:** Each function has dedicated test file
- **Extensible:** Easy to add new commands
- **Help-aware:** Each command has `--help` built-in

### 4. FHS Compliance
- **Development mode:** `./bcs` from repo
- **System-wide:** `bcs` after `make install`
- **Search paths:** Script dir → `/usr/local/share` → `/usr/share`

### 5. Template Substitution
- **Simple placeholders:** `{{NAME}}`, `{{DESCRIPTION}}`, `{{VERSION}}`
- **Bash string replacement:** No external dependencies
- **Type-specific:** Different templates for different use cases

### 6. AI Integration
- **Prompt construction:** Dynamic based on filters and tier
- **Token efficiency:** Only load needed rules
- **Output parsing:** Supports multiple formats for different consumers
- **Exit codes:** Meaningful return values for CI/CD

---

# Part 3: Comparative Analysis

## Side-by-Side Comparison: BCS vs. ShellCheck

| Aspect | BCS | ShellCheck |
|--------|-----|------------|
| **Language** | Bash (2,247 lines) | Haskell (~19,000 lines) |
| **Approach** | AI-powered validation | AST-based static analysis |
| **Rules** | 99 hierarchical codes | 300+ checks (SC####) |
| **Customization** | Filter by code/section/tier | Include/exclude codes |
| **Output** | Human-focused explanations | Technical warnings |
| **Use Case** | Coding standard compliance | Syntax/semantic errors |
| **Architecture** | Multi-tier documentation + CLI | Parser + Analyzer + Formatters |
| **Extensibility** | Add markdown files | Add Haskell check functions |
| **Learning Curve** | Markdown + Bash | Haskell + AST + Parsec |
| **Generation** | Assembles from `data/` | Compiles from source |
| **Performance** | Depends on AI (Claude) | Milliseconds (native) |
| **Configuration** | Tier + filter system | .shellcheckrc + annotations |
| **Testing** | Bash test scripts | QuickCheck properties |
| **Deployment** | Single bash script | Compiled binary |

---

## Complementary Nature

**ShellCheck and BCS are complementary, not competing:**

### ShellCheck Validates:
- ✓ **Syntax errors** - Invalid bash constructs
- ✓ **Semantic issues** - Logic errors, type mismatches
- ✓ **Common pitfalls** - Unquoted variables, globbing issues
- ✓ **Portability** - sh/bash/dash/ksh differences
- ✓ **Security** - Injection vulnerabilities, unsafe practices

### BCS Validates:
- ✓ **Structure compliance** - 13-step layout, function organization
- ✓ **Style consistency** - Naming, indentation, comments
- ✓ **Best practices** - Readonly usage, error handling patterns
- ✓ **Metadata requirements** - VERSION, SCRIPT_PATH, etc.
- ✓ **Documentation quality** - WHY vs WHAT comments

### Perfect Together:
```bash
# Step 1: Syntax and semantic validation
shellcheck -x script.sh

# Step 2: Style and structure validation
bcs check script.sh

# Combined CI/CD:
shellcheck -x script.sh && bcs check --strict script.sh
```

---

## Combined Workflow

### Development Workflow
```bash
# 1. Generate template
bcs template -t complete -n deploy -o deploy.sh -x

# 2. Develop script
vim deploy.sh

# 3. Quick syntax check
shellcheck deploy.sh

# 4. Fix syntax issues
vim deploy.sh

# 5. Quick BCS validation
bcs check deploy.sh

# 6. Fix structure issues
vim deploy.sh

# 7. Thorough validation
shellcheck -x deploy.sh
bcs check --tier complete deploy.sh

# 8. Ready for commit
```

### CI/CD Pipeline
```yaml
# .github/workflows/validate.yml
name: Script Validation

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Install ShellCheck
        run: sudo apt-get install shellcheck

      - name: Install BCS
        run: |
          git clone https://github.com/OkusiAssociates/bash-coding-standard
          cd bash-coding-standard
          sudo make install

      - name: Syntax validation (ShellCheck)
        run: |
          find . -name "*.sh" -exec shellcheck -x {} +

      - name: Style validation (BCS)
        run: |
          find . -name "*.sh" -exec bcs check --strict {} \;
```

### Pre-commit Hook
```bash
#!/bin/bash
# .git/hooks/pre-commit

set -euo pipefail

# Find staged shell scripts
mapfile -t scripts < <(git diff --cached --name-only --diff-filter=ACM | grep '\.sh$')

if ((${#scripts[@]} == 0)); then
  exit 0
fi

echo "Validating ${#scripts[@]} shell scripts..."

# Run ShellCheck
echo "Running ShellCheck..."
shellcheck -x "${scripts[@]}" || {
  echo "ShellCheck failed. Fix syntax errors before committing."
  exit 1
}

# Run BCS check
echo "Running BCS validation..."
for script in "${scripts[@]}"; do
  bcs check --strict "$script" || {
    echo "BCS validation failed for $script"
    exit 1
  }
done

echo "✓ All validations passed"
exit 0
```

---

## Architectural Lessons

### From ShellCheck:
1. **Strong typing prevents bugs** - Use newtypes and distinct types
2. **Property-based testing scales** - QuickCheck finds edge cases
3. **Monad composition is powerful** - Writer monad for collecting warnings
4. **Pattern matching on AST** - Clean, exhaustive analysis
5. **Modular checks** - Independent functions, easy to test

### From BCS:
1. **Three-tier approach** - Abstract/Complete/Summary serves different needs
2. **Path-based codes** - Deterministic, reversible, scalable
3. **AI integration** - Context-aware validation without AST parsing
4. **Token optimization** - Choose detail level based on use case
5. **Dual-purpose scripts** - Executable or library pattern

### Combined Strengths:
- **ShellCheck:** Fast, deterministic, comprehensive syntax/semantic analysis
- **BCS:** Flexible, context-aware, structure/style validation
- **Together:** Complete validation pipeline from syntax to style

---

## Conclusion

**ShellCheck** excels at **catching bugs** - syntax errors, semantic issues, common pitfalls.

**BCS** excels at **enforcing consistency** - structure, style, documentation, best practices.

**Used together**, they provide:
- ✓ **Correctness** (ShellCheck)
- ✓ **Consistency** (BCS)
- ✓ **Maintainability** (both)
- ✓ **Security** (both)
- ✓ **Portability** (ShellCheck)
- ✓ **Documentation** (BCS)

The ideal bash development workflow uses both tools at different stages, leveraging ShellCheck's speed and precision for syntax/semantic validation, and BCS's flexibility and context-awareness for structure/style compliance.

---

**End of Document**

*Generated: October 14, 2025*
*Analysis by: Claude (Anthropic)*
*Purpose: Comprehensive architectural understanding of ShellCheck and BCS systems*
