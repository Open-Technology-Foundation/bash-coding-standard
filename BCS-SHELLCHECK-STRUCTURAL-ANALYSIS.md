# BCS vs ShellCheck: Deep Structural Comparison

**Analysis Date:** October 14, 2025
**Scope:** Comprehensive structural, architectural, and philosophical comparison
**Purpose:** Understanding fundamental differences and design trade-offs

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Implementation Language Analysis](#implementation-language-analysis)
3. [Architectural Paradigms](#architectural-paradigms)
4. [Data Structure Philosophies](#data-structure-philosophies)
5. [Validation Approaches](#validation-approaches)
6. [Rule Management Systems](#rule-management-systems)
7. [Extensibility Models](#extensibility-models)
8. [Testing Strategies](#testing-strategies)
9. [Performance Characteristics](#performance-characteristics)
10. [User Interface Design](#user-interface-design)
11. [Configuration Systems](#configuration-systems)
12. [Development Workflows](#development-workflows)
13. [Deployment Models](#deployment-models)
14. [Structural Trade-offs](#structural-trade-offs)
15. [Future Evolution Potential](#future-evolution-potential)
16. [Synthesis: Complementary Design Principles](#synthesis-complementary-design-principles)

---

## Executive Summary

### ShellCheck
**Essence:** A **compiler-like static analyzer** built as a traditional parsing/analysis pipeline in Haskell, using formal AST traversal and pattern matching for deterministic validation.

**Core Philosophy:** "Parse once, analyze everywhere" - Transform bash into structured data, then apply 300+ algorithmic checks with type safety guarantees.

### BCS
**Essence:** A **documentation-first system** that treats rules as structured markdown files, using a hierarchical file system as the database, and delegating validation to AI for context-aware analysis.

**Core Philosophy:** "Documentation is code" - Rules are markdown, paths encode structure, generation assembles documentation, AI interprets intent.

### Fundamental Difference
- **ShellCheck:** Code analyzes code (algorithmic determinism)
- **BCS:** Documentation validates code (semantic interpretation)

---

## Implementation Language Analysis

### Language Choice Impact

| Dimension | ShellCheck (Haskell) | BCS (Bash) |
|-----------|---------------------|------------|
| **Paradigm** | Functional, pure | Imperative, side-effects |
| **Type System** | Strong static typing | Weak dynamic typing |
| **Compilation** | Compiled to native binary | Interpreted at runtime |
| **Memory Safety** | Guaranteed by compiler | Manual error handling |
| **Concurrency** | Built-in (lazy evaluation) | Limited (subprocess-based) |
| **Portability** | Binary per platform | Universal (bash everywhere) |
| **Build Complexity** | Cabal/Stack ecosystem | No build step |
| **Entry Barrier** | High (learn Haskell) | Low (bash knowledge) |

### Why Haskell for ShellCheck?

**Strengths leveraged:**
1. **Algebraic Data Types (ADT)** - Perfect for AST representation
   ```haskell
   data Token = OuterToken Id (InnerToken Token)
   data InnerToken t =
       Inner_T_SimpleCommand [t] [t]
     | Inner_T_Pipeline [t] [t]
     | Inner_T_IfExpression [([t],[t])] [t]
   ```
   - Each bash construct is a distinct type
   - Pattern matching ensures exhaustive handling
   - Compiler catches missing cases

2. **Type Safety** - Prevents entire classes of bugs
   ```haskell
   newtype Id = Id Int  -- Can't confuse with plain Int
   data Severity = ErrorC | WarningC | InfoC | StyleC
   ```
   - Wrong types simply won't compile
   - Refactoring is safe (compiler finds all call sites)

3. **Immutability** - AST never changes after parsing
   - No accidental mutations
   - Parallel analysis becomes trivial
   - Reasoning about code is simpler

4. **Laziness** - Don't compute what you don't need
   - Parse → Analyze → Format pipeline is naturally lazy
   - Skip expensive checks if early stage fails

**Trade-offs accepted:**
- ❌ 2GB RAM to compile
- ❌ Steep learning curve for contributors
- ❌ Separate binary per platform
- ✓ But: Rock-solid correctness guarantees

### Why Bash for BCS?

**Strengths leveraged:**
1. **Native Environment** - No installation friction
   ```bash
   ./bcs check script.sh  # Just works
   ```
   - Same language as scripts being validated
   - Every Linux system has bash

2. **String Processing** - Built for text manipulation
   ```bash
   get_bcs_code() {
     readarray -t heads < <(grep -so '[0-9][0-9]-' <<<"$filepath")
     printf 'BCS%s' "${heads[@]//-/}"
   }
   ```
   - Path → BCS code extraction is trivial
   - Markdown manipulation is natural

3. **System Integration** - Direct command execution
   ```bash
   find data/ -name "*.abstract.md" | sort
   claude --system-prompt "$prompt" < script.sh
   ```
   - No FFI needed for external tools
   - Pipe-based composition

4. **Dual-Purpose Pattern** - Executable or library
   ```bash
   if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
     # Sourced - provide functions
   else
     # Executed - run dispatcher
   fi
   ```
   - One file, two modes
   - Can source functions individually

**Trade-offs accepted:**
- ❌ No type safety (rely on ShellCheck!)
- ❌ Slower than compiled code
- ❌ Error handling is manual
- ✓ But: Universal compatibility, zero setup

---

## Architectural Paradigms

### ShellCheck: Traditional Compiler Pipeline

```
Input Script (text)
       ↓
┌──────────────────────────────────────┐
│   PARSING PHASE                      │
│   Parser.hs (Parsec combinators)    │
│   - Lexical analysis                 │
│   - Syntax analysis                  │
│   - AST construction                 │
└──────────────────────────────────────┘
       ↓
   AST (Token tree)
       ↓
┌──────────────────────────────────────┐
│   ANALYSIS PHASE                     │
│   Analytics.hs + Checks/             │
│   - Tree checks (once)               │
│   - Node checks (every node)         │
│   - CFG analysis (optional)          │
└──────────────────────────────────────┘
       ↓
   TokenComments (warnings)
       ↓
┌──────────────────────────────────────┐
│   FORMATTING PHASE                   │
│   Formatter/*.hs                     │
│   - TTY, JSON, GCC, CheckStyle...    │
└──────────────────────────────────────┘
       ↓
   Output (8 formats)
```

**Key characteristics:**
- **Single-pass parsing** - Script → AST in one go
- **Multiple-pass analysis** - Tree checks + Node checks + CFG
- **Immutable AST** - Parse once, analyze many times
- **Algebraic checks** - Pattern matching on structure
- **Deterministic** - Same input always produces same output

**Design pattern:** Classic **interpreter/compiler architecture**
- Based on decades of compiler theory
- Well-understood phases with clear boundaries
- Each phase has a single responsibility

### BCS: Documentation Generation + AI Interpretation

```
Source Files (markdown)
       ↓
┌──────────────────────────────────────┐
│   STORAGE PHASE                      │
│   data/ directory tree               │
│   - 01-section/02-rule.md            │
│   - Hierarchical file system         │
│   - Path encodes BCS code            │
└──────────────────────────────────────┘
       ↓
   Markdown Files (text)
       ↓
┌──────────────────────────────────────┐
│   GENERATION PHASE                   │
│   cmd_generate()                     │
│   - Find all *.abstract.md           │
│   - Sort by path                     │
│   - Concatenate with separators      │
└──────────────────────────────────────┘
       ↓
   BASH-CODING-STANDARD.md
       ↓
┌──────────────────────────────────────┐
│   VALIDATION PHASE (on demand)       │
│   cmd_check()                        │
│   - Build prompt from rules          │
│   - Send to Claude AI                │
│   - Parse AI response                │
└──────────────────────────────────────┘
       ↓
   Validation Report
```

**Key characteristics:**
- **No parsing** - Markdown is already structured text
- **File system as database** - Path = structure
- **Generation on demand** - Assemble from parts
- **AI interpretation** - Claude understands context
- **Non-deterministic** - AI may give different results

**Design pattern:** **Content management system + AI oracle**
- Inspired by static site generators
- Rules are "content", CLI is "generator"
- AI is "semantic analyzer"

### Paradigm Comparison

| Aspect | ShellCheck | BCS |
|--------|-----------|-----|
| **Core metaphor** | Compiler | CMS + AI |
| **Data model** | AST (tree) | File system (hierarchy) |
| **Processing** | Traversal + matching | Assembly + prompting |
| **Knowledge base** | Hardcoded checks | Markdown documents |
| **Validation** | Algorithmic | Interpretive |
| **Evolution** | Add code | Add files |

---

## Data Structure Philosophies

### ShellCheck: Recursive Algebraic Data Types

**The AST is the universal representation:**

```haskell
-- Core structure
newtype Root = Root Token
data Token = OuterToken Id (InnerToken Token)

-- Every bash construct is a type
data InnerToken t =
    -- Commands
    Inner_T_SimpleCommand [t] [t]
  | Inner_T_Pipeline [t] [t]

    -- Control flow
  | Inner_T_IfExpression [([t],[t])] [t]
  | Inner_T_ForIn String [t] [t]
  | Inner_T_While [t] [t]

    -- Functions
  | Inner_T_Function FunctionKeyword FunctionParentheses String t

    -- ... 100+ more constructors
```

**Properties:**
1. **Type-level correctness**
   ```haskell
   -- This won't compile:
   badFunc :: Token -> String
   badFunc (T_Pipeline _ cmds) =
     head cmds  -- ERROR: [Token] not [String]
   ```

2. **Exhaustive pattern matching**
   ```haskell
   analyze :: Token -> [Warning]
   analyze (T_SimpleCommand id vars cmds) = checkSimple vars cmds
   analyze (T_Pipeline id seps cmds) = checkPipe cmds
   -- Compiler warns if we miss a case!
   ```

3. **Recursive traversal**
   ```haskell
   doAnalysis :: (Token -> m ()) -> Token -> m Token
   doAnalysis f = analyze f blank return

   -- Automatically recurses through entire tree
   ```

**Memory representation:**
```
Token (SimpleCommand)
  ├─ Id: 42
  └─ InnerToken
      ├─ Variables: [Token, Token]
      │   └─ Each is Assignment token
      └─ Commands: [Token, Token]
          └─ Each is NormalWord token
              └─ Contains Literal tokens
```

**Why this works:**
- **Structural recursion** - Tree naturally represents nested constructs
- **Type guarantees** - Invalid trees can't exist
- **Efficient traversal** - Follow pointers, no re-parsing

### BCS: File System as Hierarchical Database

**The path IS the structure:**

```bash
data/
├── 01-script-structure/          # Section 1
│   ├── 00-section.abstract.md    # BCS0100
│   ├── 02-shebang.abstract.md    # BCS0102
│   │   └── [01, 02] extracted → concatenate → BCS0102
│   └── 02-shebang/               # Subrules
│       └── 01-dual-purpose.md    # BCS010201
│           └── [01, 02, 01] → BCS010201
```

**Path encoding algorithm:**
```bash
get_bcs_code() {
  local filepath="$1"
  # Extract: data/01-script-structure/02-shebang.abstract.md
  #          → ['01', '02']
  readarray -t heads < <(grep -so '[0-9][0-9]-' <<<"$filepath")
  # Concatenate: '01' + '02' → '0102'
  # Prefix: 'BCS' + '0102' → 'BCS0102'
  printf 'BCS%s' "${heads[@]//-/}"
}
```

**Properties:**
1. **Path encodes identity**
   ```
   data/02-variables/05-readonly.abstract.md
   → Section 02, Rule 05
   → BCS0205
   ```

2. **Hierarchy through directories**
   ```
   02-shebang/
     01-dual-purpose.md    # Subrule 1
     02-env-considerations.md  # Subrule 2
   ```

3. **Unlimited depth**
   ```
   01-section/
     02-rule/
       03-subrule/
         04-subsubrule/
           05-detail.md → BCS0102030405
   ```

**Why this works:**
- **File system is reliable** - OS guarantees uniqueness
- **Sorting is trivial** - `find | sort` gives canonical order
- **Human-readable** - Can browse in file manager
- **Version control** - Git tracks changes naturally

### Structure Comparison

| Dimension | ShellCheck AST | BCS File Hierarchy |
|-----------|----------------|-------------------|
| **Representation** | In-memory tree | On-disk files |
| **Access pattern** | Pointer traversal | File system scan |
| **Uniqueness** | Type system | Path uniqueness |
| **Modification** | Immutable | Mutable (edit files) |
| **Query** | Pattern matching | Find + grep |
| **Size** | Bounded by RAM | Bounded by disk |
| **Persistence** | Transient | Permanent |

---

## Validation Approaches

### ShellCheck: Algorithmic Pattern Matching

**Check function signature:**
```haskell
type Check = Parameters -> Token -> Writer [TokenComment] ()
```

**Example: Detect unquoted variables**
```haskell
checkUnquoted :: Parameters -> Token -> Writer [TokenComment] ()
checkUnquoted _ token =
  case token of
    -- Match: echo $var (unquoted)
    T_SimpleCommand id _ [T_NormalWord _ [T_DollarBraced _ var]] ->
      warn id 2086 "Quote to prevent word splitting"

    -- Match: [[ -f $file ]] (unquoted in test)
    T_Condition _ _ (TC_Binary _ _ op (T_NormalWord _ [T_DollarBraced _ var])) ->
      warn id 2086 "Quote this to prevent glob interpretation"

    -- All other cases: do nothing
    _ -> return ()
```

**Characteristics:**
- **Explicit logic** - Programmer encodes the rule
- **Precise** - Matches exactly what was programmed
- **Fast** - Native code execution
- **Predictable** - Same input → same output (always)
- **Limited** - Only detects programmed patterns

**Example workflow:**
```
Input: echo $var
         ↓ Parse
AST: T_SimpleCommand [T_NormalWord [T_DollarBraced "var"]]
         ↓ Check (pattern match)
Match: Unquoted variable pattern
         ↓ Generate warning
Output: SC2086: Quote to prevent splitting
```

**Adding a new check:**
1. Define the pattern in Haskell
2. Write property tests
3. Compile
4. Test on real scripts
5. Deploy new binary

### BCS: AI-Powered Semantic Analysis

**Prompt construction:**
```bash
build_validation_prompt() {
  cat <<PROMPT
You are a Bash script compliance validator.

Analyze against these rules:
---
$(cat data/01-script-structure/*.abstract.md)
---

Focus on:
  • BCS01 - Script Structure
  • BCS02 - Variables
  ...

Output format:
  ✓ COMPLIANT: [BCS0102] - Explanation
  ✗ VIOLATION: [BCS0102] - Issue at line X
PROMPT
}
```

**Validation workflow:**
```bash
cmd_check() {
  # Build prompt with rules
  prompt=$(build_validation_prompt)

  # Send to Claude
  claude --system-prompt "$prompt" < script.sh

  # Claude reads script, understands context, provides analysis
}
```

**Characteristics:**
- **Contextual** - AI understands intent, not just syntax
- **Flexible** - Can handle nuanced situations
- **Slow** - Network + AI processing time
- **Variable** - May give slightly different results
- **Comprehensive** - Can explain "why" not just "what"

**Example workflow:**
```
Input: echo $var
         ↓ Send to Claude with BCS rules
AI Processing:
  - Reads rule: "Quote variables in conditionals"
  - Analyzes context: "This is in echo, not conditional"
  - Checks if $var could contain spaces: "No context to determine"
  - Makes recommendation: "Should quote, but less critical in echo"
         ↓ AI generates response
Output: ⚠ WARNING: [BCS04] Consider quoting $var to prevent
        word splitting, though less critical in echo context.
```

**Adding a new check:**
1. Write markdown file: `data/XX-section/YY-rule.abstract.md`
2. Regenerate: `bcs generate --canonical`
3. AI automatically considers new rule
4. Test with real scripts

### Validation Comparison

| Dimension | ShellCheck | BCS |
|-----------|-----------|-----|
| **Method** | Pattern matching | Natural language |
| **Knowledge** | Hardcoded | Markdown documents |
| **Speed** | Milliseconds | Seconds (AI latency) |
| **Precision** | Exact matches | Interpretive |
| **Recall** | Limited to patterns | Contextual reasoning |
| **Explanation** | Template messages | Natural explanation |
| **Consistency** | 100% deterministic | ~95% consistent |
| **Cost** | Free (local) | API costs (Claude) |
| **Offline** | Yes | No (needs API) |

---

## Rule Management Systems

### ShellCheck: Code-Based Rules

**Rule definition location:**
```haskell
-- In src/ShellCheck/Analytics.hs (or Checks/Commands.hs, etc.)

-- Rule SC2086: Unquoted variable
checkUnquotedDollarAt :: Parameters -> Token -> Writer [TokenComment] ()
checkUnquotedDollarAt _ (T_SimpleCommand _ _ words) =
  mapM_ check words
  where
    check word = -- implementation
```

**Rule properties:**
```haskell
-- Severity
warn id 2086 "Message"        -- Style warning
info id 2088 "Message"        -- Information
err id 1234 "Message"         -- Error

-- Optional checks
optionalChecks = [
  (description, checkFunction),
  ...
]
```

**Rule documentation:**
- **Wiki pages** - https://www.shellcheck.net/wiki/SC2086
- **Separate from code** - Documentation is not source of truth
- **Manual sync** - Wiki must be updated when code changes

**Example rule structure:**
```
SC2086 (Code)
  ↓
Defined in Analytics.hs (Source of truth)
  ↓
Documented in wiki/SC2086.md (Separate)
  ↓
Property tests in Checker.hs (Validation)
```

**Rule lifecycle:**
1. **Add code** - Write Haskell function
2. **Add tests** - Property-based tests
3. **Compile** - Check types, run tests
4. **Document** - Update wiki page
5. **Release** - Ship binary

### BCS: Document-Based Rules

**Rule definition location:**
```bash
# File: data/01-script-structure/02-shebang.abstract.md

### Shebang and Initial Setup

First lines: shebang, shellcheck directives, description, `set -euo pipefail`.

```bash
#!/bin/bash
set -euo pipefail
```

**Rationale:** Strict error handling immediately.

**Ref:** See 02-shebang.md for details
```

**Rule properties:**
- **Three tiers** - abstract/complete/summary versions
- **Path = Code** - Filename determines BCS code
- **Self-documenting** - Markdown IS the rule

**Rule structure:**
```
BCS0102 (Code)
  ↓
Derived from path: data/01-script-structure/02-shebang.md
  ↓
Three files:
  • 02-shebang.abstract.md (concise)
  • 02-shebang.complete.md (detailed)
  • 02-shebang.summary.md (medium)
  ↓
Assembled into BASH-CODING-STANDARD.md
  ↓
Fed to AI for validation
```

**Rule lifecycle:**
1. **Create markdown** - Write abstract/complete/summary
2. **Regenerate** - `bcs generate --canonical`
3. **Test** - Run against real scripts
4. **Iterate** - Edit markdown, regenerate

**Advantages:**
- ✓ Rules ARE documentation (single source of truth)
- ✓ Non-programmers can contribute
- ✓ Easy to review (markdown diff)
- ✓ AI automatically learns new rules

**Disadvantages:**
- ❌ No formal validation of rule correctness
- ❌ AI might misinterpret rule
- ❌ Can't express complex logic

### Rule Management Comparison

| Dimension | ShellCheck | BCS |
|-----------|-----------|-----|
| **Format** | Haskell code | Markdown files |
| **Location** | src/ShellCheck/*.hs | data/*/**.md |
| **Identifier** | SC#### | BCS#### |
| **Source of truth** | Code | Documentation |
| **Modification** | Edit code, compile | Edit markdown, regenerate |
| **Validation** | Type checker + tests | None (trust markdown) |
| **Documentation** | Separate wiki | Self-documenting |
| **Learning curve** | Haskell expertise | Markdown writing |
| **Review process** | Code review | Document review |
| **Contributor pool** | Haskell devs | Anyone literate |

---

## Extensibility Models

### ShellCheck: Functional Extensibility

**Adding a new check:**

1. **Define the check function:**
```haskell
-- In src/ShellCheck/Analytics.hs

checkMyNewPattern :: Parameters -> Token -> Writer [TokenComment] ()
checkMyNewPattern params token =
  case token of
    T_SimpleCommand id vars (cmd:args) ->
      -- Check logic here
      when (condition) $
        warn id 2999 "New check message"
    _ -> return ()
```

2. **Add to check list:**
```haskell
nodeChecks = [
    checkPipePitfalls,
    checkUnquotedDollarAt,
    checkMyNewPattern,  -- Add here
    -- ...
]
```

3. **Write property tests:**
```haskell
prop_checkMyNewPattern1 = verify checkMyNewPattern "bad code"
prop_checkMyNewPattern2 = verifyNot checkMyNewPattern "good code"
```

4. **Compile and test:**
```bash
cabal build
cabal test
```

**Extensibility characteristics:**
- **Type-safe** - Compiler enforces contracts
- **Tested** - Property tests catch regressions
- **Requires expertise** - Must understand Haskell + AST
- **Compile-time validation** - Errors caught before runtime
- **Binary deployment** - Ship new executable

### BCS: File-Based Extensibility

**Adding a new rule:**

1. **Create markdown files:**
```bash
# Create abstract version
vim data/02-variables/09-new-rule.abstract.md

# Create complete version
vim data/02-variables/09-new-rule.complete.md

# Create summary version
vim data/02-variables/09-new-rule.summary.md
```

2. **Write rule content:**
```markdown
### New Variable Pattern

**Rule:** Variables should follow pattern X.

**Rationale:** Improves readability and prevents Y.

**Example:**
```bash
good_example="value"
```

**Anti-pattern:**
```bash
badExample="value"
```
```

3. **Regenerate standard:**
```bash
bcs generate --canonical
```

4. **Verify code assignment:**
```bash
bcs codes | grep "new-rule"
# Output: BCS0209:new-rule:New Variable Pattern
```

5. **Test validation:**
```bash
bcs check test-script.sh
# AI now considers BCS0209
```

**Extensibility characteristics:**
- **No compilation** - Edit and done
- **Anyone can contribute** - Just write markdown
- **Self-documenting** - Rule is documentation
- **No type checking** - Markdown could be malformed
- **Runtime validation** - AI interprets at check time

### Extensibility Comparison

| Dimension | ShellCheck | BCS |
|-----------|-----------|-----|
| **Add rule** | Write Haskell | Write Markdown |
| **Expertise** | Advanced (Haskell/AST) | Basic (Markdown) |
| **Validation** | Type checker | None (AI interprets) |
| **Testing** | Property tests | Manual testing |
| **Deployment** | Recompile binary | Regenerate doc |
| **Review** | Code review | Document review |
| **Time to add** | Hours/days | Minutes/hours |
| **Contributor base** | Small (Haskell devs) | Large (writers) |
| **Risk** | Low (type safety) | Medium (AI misinterpret) |

---

## Testing Strategies

### ShellCheck: Property-Based Testing (QuickCheck)

**Core testing philosophy:**
```haskell
-- Not: "Does this input produce this output?"
-- But: "Does this property hold for ALL inputs?"
```

**Example property:**
```haskell
prop_findsUnquotedVar =
  check "echo $var" == [2086]

prop_quotedVarIsOk =
  null $ check "echo \"$var\""

prop_unquotedInTestIsWarning =
  check "[[ -f $file ]]" == [2086]
```

**QuickCheck generates test cases:**
```haskell
-- QuickCheck will try:
-- - "echo $x"
-- - "echo $VAR"
-- - "echo $var123"
-- - "echo ${var}"
-- - "echo $var$other"
-- ... hundreds of variations
```

**Test organization:**
```
src/ShellCheck/Analytics.hs
  ├─ checkUnquoted :: Check (implementation)
  ├─ prop_checkUnquoted1 :: Bool (test 1)
  ├─ prop_checkUnquoted2 :: Bool (test 2)
  └─ ...

Run: cabal test
  → QuickCheck runs all prop_* functions
  → Reports: "100 tests passed" or shows failing case
```

**Advantages:**
- ✓ Finds edge cases humans miss
- ✓ Tests exhaustively (hundreds of inputs)
- ✓ Regression prevention
- ✓ Self-documenting (tests show expected behavior)

### BCS: Manual Bash Test Scripts

**Test file structure:**
```bash
#!/usr/bin/env bash
# tests/test-subcommand-check.sh

source tests/test-helpers.sh

test_check_basic() {
  # Setup
  local script=$(mktemp)
  echo '#!/bin/bash' > "$script"
  echo 'echo hello' >> "$script"

  # Run
  if bcs check "$script"; then
    pass "Basic script passed validation"
  else
    fail "Basic script should pass"
  fi

  rm "$script"
}

test_check_violation() {
  local script=$(mktemp)
  echo '#!/bin/bash' > "$script"
  echo 'echo $var' >> "$script"  # Unquoted

  if ! bcs check "$script"; then
    pass "Caught unquoted variable"
  else
    fail "Should catch unquoted variable"
  fi

  rm "$script"
}

# Run tests
test_check_basic
test_check_violation
test_summary
```

**Test helpers:**
```bash
# tests/test-helpers.sh

declare -i TESTS_PASSED=0
declare -i TESTS_FAILED=0

pass() {
  echo "✓ $1"
  TESTS_PASSED+=1
}

fail() {
  echo "✗ $1"
  TESTS_FAILED+=1
}

test_summary() {
  echo "---"
  echo "Passed: $TESTS_PASSED"
  echo "Failed: $TESTS_FAILED"
  ((TESTS_FAILED == 0))
}
```

**Test execution:**
```bash
./tests/run-all-tests.sh
  → Runs all test-*.sh files
  → Aggregates pass/fail counts
  → Exit 0 if all pass, 1 otherwise
```

**Advantages:**
- ✓ Simple to understand
- ✓ Can test end-to-end behavior
- ✓ Shell scripts test shell scripts
- ✓ Easy to add new tests

**Disadvantages:**
- ❌ Manual test case design
- ❌ Coverage gaps possible
- ❌ No automatic edge case discovery

### Testing Comparison

| Dimension | ShellCheck | BCS |
|-----------|-----------|-----|
| **Framework** | QuickCheck | Bash scripts |
| **Philosophy** | Property-based | Example-based |
| **Coverage** | Exhaustive (generated) | Manual (written) |
| **Edge cases** | Auto-discovered | Must think of |
| **Speed** | Fast (compiled) | Slow (bash + AI) |
| **Flakiness** | None | Possible (AI variance) |
| **Ease of writing** | Learn QuickCheck | Write bash |
| **Maintainability** | Self-documenting | Requires discipline |

---

## Performance Characteristics

### ShellCheck: Native Binary Performance

**Performance model:**
```
Parse → Analyze → Format
  ↓        ↓         ↓
  1ms     5ms       1ms    (typical 100-line script)
```

**Scalability:**
```bash
# Tiny script (10 lines)
$ time shellcheck tiny.sh
real    0m0.012s

# Medium script (100 lines)
$ time shellcheck medium.sh
real    0m0.018s

# Large script (1000 lines)
$ time shellcheck large.sh
real    0m0.095s

# Huge script (10000 lines)
$ time shellcheck huge.sh
real    0m0.842s
```

**Performance characteristics:**
- **Startup cost:** ~10ms (load binary, initialize)
- **Parsing:** Linear in script size, ~10μs per line
- **Analysis:** Depends on check complexity, typically linear
- **Memory:** ~50MB for large scripts
- **Parallel:** Could analyze multiple files (not implemented)

**Why so fast?**
1. **Native code** - Compiled Haskell → native instructions
2. **Single-pass parsing** - Only parse once
3. **Lazy evaluation** - Don't compute unused results
4. **Optimized checks** - Pattern matching is fast
5. **No I/O** - All in-memory after initial read

### BCS: Bash + AI Performance

**Performance model:**
```
Build Prompt → Call Claude → Parse Response
      ↓              ↓              ↓
    50ms          2-5s            10ms    (typical script)
```

**Scalability:**
```bash
# Tiny script (10 lines) with abstract tier
$ time bcs check tiny.sh
real    0m2.341s

# Medium script (100 lines) with abstract tier
$ time bcs check medium.sh
real    0m3.782s

# Large script (1000 lines) with abstract tier
$ time bcs check large.sh
real    0m8.921s

# Huge script (10000 lines) with complete tier
$ time bcs check --tier complete huge.sh
real    0m25.443s
```

**Performance breakdown:**
- **Bash overhead:** ~50ms (startup, find files)
- **Prompt building:** ~100ms (read markdown, assemble)
- **Network latency:** ~200ms (send to Claude API)
- **AI processing:** 2-20s (depends on script size + tier)
- **Response parsing:** ~10ms (grep for violations)

**Why so slow?**
1. **Network round-trip** - API call adds latency
2. **AI processing** - Claude must "read" and "understand"
3. **Context size** - More rules/script = slower
4. **Bash overhead** - Interpreted, not compiled
5. **Sequential** - Can't parallelize easily

**Optimization strategies:**
```bash
# Fast: Use abstract tier
bcs check --tier abstract script.sh    # ~500 lines of rules

# Faster: Filter by section
bcs check --sections 1,2 script.sh     # Only relevant rules

# Fastest: Filter by specific codes
bcs check --codes BCS01,BCS02 script.sh  # Minimal rules
```

### Performance Comparison

| Dimension | ShellCheck | BCS |
|-----------|-----------|-----|
| **Typical time** | 10-100ms | 2-10s |
| **Startup cost** | 10ms | 50ms |
| **Parsing** | 10μs/line | N/A (AI reads) |
| **Analysis** | 5-50ms | 2-20s |
| **Scaling** | Sub-linear | Linear to super-linear |
| **Parallelizable** | Yes (theory) | No (sequential) |
| **Memory** | 50MB | 100MB+ (includes AI context) |
| **Suitable for** | CI/CD, pre-commit | Code review, learning |
| **Bottleneck** | Check complexity | AI processing |

---

## User Interface Design

### ShellCheck: Traditional CLI

**Interface style:**
```bash
$ shellcheck script.sh

In script.sh line 3:
echo $var
     ^--^ SC2086: Quote to prevent word splitting

In script.sh line 7:
if [ $count -gt 10 ]; then
   ^-- SC2039: Not supported in sh (dash/POSIX)
```

**Design principles:**
- **Minimal** - Only shows problems, not successes
- **Precise** - Points to exact character/line
- **Informative** - SC#### for wiki lookup
- **Actionable** - Suggests fix implicitly

**Output formats:**
```bash
# Default: TTY with colors
shellcheck script.sh

# GCC-compatible (for IDEs)
shellcheck --format=gcc script.sh

# JSON (for parsing)
shellcheck --format=json script.sh

# CheckStyle XML (for CI)
shellcheck --format=checkstyle script.sh
```

### BCS: Conversational CLI

**Interface style:**
```bash
$ bcs check script.sh

bcs: Building validation prompt (tier: abstract)...
bcs: Validating script: script.sh

✓ COMPLIANT: [BCS0102 - Shebang] Uses #!/bin/bash correctly
✗ VIOLATION: [BCS0104 - FHS] Missing 'set -euo pipefail' at line 3
⚠ WARNING: [BCS0205 - Readonly] Variable should be readonly at line 15
💡 SUGGESTION: Consider using main() function for scripts >40 lines

Summary: 1 violation, 1 warning, 1 suggestion
Exit code: 2 (violations found)
```

**Design principles:**
- **Verbose** - Shows progress, not just results
- **Educational** - Explains WHY, not just WHAT
- **Contextual** - AI provides reasoning
- **Encouraging** - Shows compliant items too

**Subcommand hierarchy:**
```bash
bcs                    # Auto-display standard
bcs about              # Project info
bcs codes              # List all codes
bcs check script.sh    # Validate script
bcs template -t basic  # Generate template
bcs explain BCS0205    # Explain specific rule
bcs decode BCS0205     # Find rule file
```

### UI Comparison

| Dimension | ShellCheck | BCS |
|-----------|-----------|-----|
| **Verbosity** | Minimal | Verbose |
| **Style** | Technical | Conversational |
| **Feedback** | Problems only | Problems + successes |
| **Progress** | Silent | Shows steps |
| **Explanation** | Brief + wiki link | Detailed inline |
| **Format options** | 8 formats | 4 formats |
| **Interactivity** | None | Subcommand-based |
| **Learning curve** | Shallow (familiar) | Medium (subcommands) |

---

## Configuration Systems

### ShellCheck: .shellcheckrc + Annotations

**Configuration layers:**

1. **Global defaults**
   ```bash
   # Compiled into binary
   - All checks enabled by default
   - Severity levels preset
   ```

2. **Project .shellcheckrc**
   ```bash
   # .shellcheckrc in project root
   disable=SC2086,SC2154
   enable=quote-safe-variables
   shell=bash
   ```

3. **File annotations**
   ```bash
   # At top of script
   # shellcheck shell=bash
   # shellcheck disable=SC2086,SC2154
   ```

4. **Inline annotations**
   ```bash
   # shellcheck disable=SC2086
   echo $var  # OK, disabled for this line
   ```

5. **CLI flags**
   ```bash
   shellcheck --exclude=SC2086 --shell=bash script.sh
   ```

**Priority:** CLI > Inline > File > Project > Global

**Configuration files searched:**
```
Current directory:
  .shellcheckrc
  shellcheckrc (Windows)

User home:
  ~/.shellcheckrc

XDG config:
  $XDG_CONFIG_HOME/shellcheckrc
```

### BCS: Tier + Filter System

**Configuration dimensions:**

1. **Tier selection** (detail level)
   ```bash
   bcs check --tier abstract   # ~500 lines
   bcs check --tier complete   # ~13,376 lines
   bcs check --tier summary    # ~2,000 lines
   ```

2. **Code filtering** (scope)
   ```bash
   bcs check --codes BCS01,BCS02  # Only sections 1,2
   bcs check --sections 1,8       # Structure + Errors
   ```

3. **Output format**
   ```bash
   bcs check --format text        # Human-readable
   bcs check --format json        # Machine-parseable
   bcs check --format markdown    # Formatted report
   ```

4. **Severity filtering**
   ```bash
   bcs check --severity violations  # Only critical
   bcs check --severity all         # Everything
   ```

5. **Strict mode**
   ```bash
   bcs check --strict  # Warnings become violations
   ```

**No config files** - All configuration via CLI flags

### Configuration Comparison

| Dimension | ShellCheck | BCS |
|-----------|-----------|-----|
| **Config files** | Yes (.shellcheckrc) | No (CLI only) |
| **Inline control** | Yes (annotations) | No |
| **Hierarchical** | Yes (project > user) | No |
| **Scope control** | Include/exclude codes | Filter by code/section |
| **Detail level** | Fixed (all checks) | Variable (tier selection) |
| **Persistence** | Config files | CLI flags only |
| **Shareable** | .shellcheckrc in repo | Document scripts |

---

## Development Workflows

### ShellCheck Development Workflow

**Adding a new check:**
```bash
# 1. Design the check
#    - What pattern to detect?
#    - What is the fix?
#    - What is the SC code?

# 2. Implement in Haskell
vim src/ShellCheck/Analytics.hs

checkNewPattern :: Parameters -> Token -> Writer [TokenComment] ()
checkNewPattern _ token = case token of
  T_Pattern args -> when (condition) $ warn id 2999 "Message"
  _ -> return ()

# 3. Add to check list
nodeChecks = [
    ...
    checkNewPattern,
]

# 4. Write property tests
prop_checkNewPattern1 = verify checkNewPattern "bad"
prop_checkNewPattern2 = verifyNot checkNewPattern "good"

# 5. Compile and test
cabal build
cabal test

# 6. Test on real scripts
./shellcheck test-scripts/*.sh

# 7. Update wiki documentation
vim wiki/SC2999.md

# 8. Submit PR
git add .
git commit -m "Add SC2999: Check for ..."
git push origin feature-sc2999

# 9. Review process
#    - Code review by maintainer
#    - Type safety checked by compiler
#    - Tests must pass
#    - Documentation reviewed

# 10. Merge and release
#     - Binary built for multiple platforms
#     - Release tagged
#     - Users download new binary
```

**Development environment:**
```bash
# Requirements
- Haskell (GHC 8.10+)
- Cabal or Stack
- 2GB RAM for compilation
- Knowledge: Haskell, Parsec, AST

# Build
cabal build          # Compile
cabal test           # Run tests
cabal install        # Install to ~/.cabal/bin

# Development cycle
vim src/...          # Edit Haskell
cabal build          # Fast incremental compile (~10s)
./shellcheck test.sh # Test
```

### BCS Development Workflow

**Adding a new rule:**
```bash
# 1. Identify the rule
#    - What best practice to enforce?
#    - Which section does it belong to?
#    - What examples to show?

# 2. Create markdown files
mkdir -p data/02-variables
vim data/02-variables/09-new-rule.abstract.md
vim data/02-variables/09-new-rule.complete.md
vim data/02-variables/09-new-rule.summary.md

# 3. Write rule content (markdown)
### New Variable Pattern

**Rule:** Variables must follow pattern X.

**Rationale:** Prevents issue Y.

**Example:** good_var="value"

**Anti-pattern:** badVar="value"

# 4. Regenerate standard
./bcs generate --canonical

# 5. Verify code assignment
./bcs codes | grep new-rule
# BCS0209:new-rule:New Variable Pattern

# 6. Test on real scripts
./bcs check test-scripts/*.sh

# 7. Iterate if needed
#    - Edit markdown
#    - Regenerate
#    - Test again

# 8. Commit changes
git add data/02-variables/09-new-rule.*
git add BASH-CODING-STANDARD.md
git commit -m "Add BCS0209: New variable pattern"
git push origin feature-bcs0209

# 9. Review process
#    - Document review
#    - Test on variety of scripts
#    - Check AI interpretation

# 10. Merge
#     - No compilation needed
#     - Users pull latest
#     - Next `bcs check` uses new rule
```

**Development environment:**
```bash
# Requirements
- Bash 5.2+
- Markdown editor
- Claude CLI (for testing validation)
- Knowledge: Bash, Markdown, BCS structure

# Build (regenerate)
./bcs generate --canonical  # ~100ms

# Development cycle
vim data/...                # Edit markdown
./bcs generate --canonical  # Regenerate
./bcs check test.sh         # Test
```

### Workflow Comparison

| Dimension | ShellCheck | BCS |
|-----------|-----------|-----|
| **Edit** | Haskell code | Markdown files |
| **Build** | cabal build (~10s) | bcs generate (~100ms) |
| **Test** | cabal test + manual | Manual only |
| **Validation** | Type checker + tests | None |
| **Review** | Code review | Document review |
| **Deploy** | Compile binary | Commit files |
| **User update** | Download binary | Pull repo / bcs generate |
| **Cycle time** | Minutes (compile) | Seconds (regenerate) |
| **Expertise** | High (Haskell) | Low (Markdown) |

---

## Deployment Models

### ShellCheck: Binary Distribution

**Deployment targets:**
```
Linux x86_64:   shellcheck-linux-x86_64
Linux ARM:      shellcheck-linux-armv6hf
macOS x86_64:   shellcheck-darwin-x86_64
macOS ARM64:    shellcheck-darwin-aarch64
Windows:        shellcheck.exe
```

**Installation methods:**
```bash
# Package managers
apt install shellcheck        # Debian/Ubuntu
brew install shellcheck       # macOS
choco install shellcheck      # Windows
pacman -S shellcheck          # Arch
snap install shellcheck       # Universal

# From source
git clone https://github.com/koalaman/shellcheck
cd shellcheck
cabal install                 # Compiles for your platform

# Pre-compiled binary
wget https://github.com/.../shellcheck-stable.linux.x86_64.tar.xz
tar -xf shellcheck-*.tar.xz
sudo mv shellcheck /usr/local/bin/
```

**Runtime requirements:**
- None! Statically linked binary
- No dependencies
- No configuration needed
- Just run: `shellcheck script.sh`

**Updates:**
```bash
# Package manager handles updates
apt upgrade shellcheck

# Or download new binary
wget .../shellcheck-latest...
```

### BCS: Script Distribution

**Deployment target:**
```
Any system with:
- Bash 5.2+
- Standard Unix utilities (find, grep, sort)
- Optional: Claude CLI (for bcs check)
```

**Installation methods:**
```bash
# Clone repository
git clone https://github.com/OkusiAssociates/bash-coding-standard
cd bash-coding-standard

# Run directly (development mode)
./bcs display
./bcs check script.sh

# Install system-wide
sudo make install              # To /usr/local
sudo make PREFIX=/usr install  # To /usr
```

**Installation locations:**
```
/usr/local/bin/bcs                                    # Executable
/usr/local/share/yatti/bash-coding-standard/         # Data files
  ├── BASH-CODING-STANDARD.md
  └── data/
```

**Runtime requirements:**
- Bash 5.2+
- Claude CLI (for validation only)
- Markdown renderer (optional, for display)

**Updates:**
```bash
# Pull latest
cd bash-coding-standard
git pull
sudo make install

# Or reinstall
sudo make uninstall
git pull
sudo make install
```

### Deployment Comparison

| Dimension | ShellCheck | BCS |
|-----------|-----------|-----|
| **Format** | Compiled binary | Bash script |
| **Size** | ~5-10 MB | ~100KB (script + data) |
| **Dependencies** | None | Bash, Claude (optional) |
| **Platforms** | Per-platform binary | Universal (any bash) |
| **Installation** | Copy binary | Copy script + data |
| **Packaging** | Package managers | Git clone + make |
| **Updates** | Replace binary | Git pull |
| **Portability** | Need platform build | Works everywhere |
| **Self-contained** | Yes (binary only) | No (needs data/ dir) |

---

## Structural Trade-offs

### ShellCheck: Compiler-Like Architecture

**Advantages:**
✓ **Type safety** - Invalid code won't compile
✓ **Performance** - Native speed, milliseconds
✓ **Determinism** - Same input always produces same output
✓ **Offline** - No external dependencies
✓ **Exhaustive** - Can check every possible pattern
✓ **Proven technology** - Decades of compiler theory
✓ **Parallel potential** - Immutable AST enables concurrency

**Disadvantages:**
❌ **High barrier** - Requires Haskell expertise
❌ **Slow development** - Compile cycle adds friction
❌ **Binary distribution** - Must build per platform
❌ **Limited context** - Can't reason about intent
❌ **Fixed checks** - Only detects programmed patterns
❌ **Documentation drift** - Wiki separate from code

**Best suited for:**
- Syntax and semantic errors
- Well-defined anti-patterns
- Fast CI/CD pipelines
- Deterministic validation
- Offline environments

### BCS: Documentation-First Architecture

**Advantages:**
✓ **Low barrier** - Anyone can contribute markdown
✓ **Self-documenting** - Rules ARE documentation
✓ **Fast iteration** - Edit markdown, regenerate, done
✓ **Universal** - Works anywhere with bash
✓ **Contextual** - AI understands nuance
✓ **Flexible** - Three tiers for different needs
✓ **Extensible** - File system scales infinitely

**Disadvantages:**
❌ **AI dependency** - Requires Claude API
❌ **Slow validation** - Seconds vs milliseconds
❌ **Non-deterministic** - AI may vary slightly
❌ **Cost** - API calls cost money
❌ **Online only** - Can't work offline
❌ **No validation** - Markdown could be wrong

**Best suited for:**
- Style and structure compliance
- Contextual reasoning
- Learning environments
- Code review workflows
- Situations where explanation matters

---

## Future Evolution Potential

### ShellCheck: Incremental Enhancement

**Natural evolution paths:**

1. **More checks** - Add SC#### codes
   - Pattern: Identify anti-pattern → Implement check
   - Limited by: Maintainer capacity, Haskell expertise

2. **Better diagnostics** - Improve messages
   - Auto-fix suggestions (like Rust's compiler)
   - Interactive mode

3. **IDE integration** - Language server protocol
   - Real-time checking in editors
   - Inline quick-fixes

4. **Performance** - Parallel analysis
   - Check multiple files concurrently
   - Incremental parsing (cache AST)

5. **Language support** - Other shells
   - PowerShell checks
   - Fish checks

**Structural constraints:**
- Must maintain type safety
- Backward compatibility (SC codes)
- Can't fundamentally change AST model

### BCS: Transformative Potential

**Natural evolution paths:**

1. **More rules** - Add BCS#### codes
   - Pattern: Write markdown → Regenerate
   - Limited by: Rule design, not implementation

2. **AI enhancement** - Better prompts
   - Few-shot learning examples
   - Chain-of-thought reasoning
   - Custom AI models

3. **Multi-language** - Beyond bash
   - Python coding standard (PCS)
   - JavaScript coding standard (JCS)
   - Same architecture, different rules

4. **Interactive mode** - Conversational validation
   - "Why did this violate BCS0205?"
   - "Suggest fixes for all violations"

5. **Custom tiers** - User-defined detail levels
   - Company-specific tier
   - Project-specific tier

**Structural flexibility:**
- File-based: No structural constraints
- AI-based: Can adapt to new paradigms
- Markdown: Easy to extend metadata

---

## Synthesis: Complementary Design Principles

### What ShellCheck Teaches Us

**Principle 1: Strong Types Prevent Bugs**
```haskell
newtype Id = Id Int
-- Can't accidentally use plain Int where Id expected
```
**Lesson:** Encode invariants in types, let compiler enforce them.

**Principle 2: Immutability Enables Reasoning**
```haskell
-- AST never changes after parsing
analyze :: Token -> [Warning]
-- Pure function: same input → same output
```
**Lesson:** Immutable data structures make code predictable.

**Principle 3: Property-Based Testing Finds Edge Cases**
```haskell
prop_check = forAll arbitrary $ \input ->
  check input == expectedBehavior input
```
**Lesson:** Generate tests, don't write them manually.

**Principle 4: Separation of Concerns**
```
Parse → AST → Analyze → Warnings → Format → Output
```
**Lesson:** Each phase does one thing well.

### What BCS Teaches Us

**Principle 1: Documentation IS Code**
```markdown
### Rule Title
Content here becomes the source of truth
```
**Lesson:** Don't separate docs from implementation.

**Principle 2: File System IS Database**
```
data/01-section/02-rule.md → BCS0102
```
**Lesson:** Use OS primitives (files, paths) for structure.

**Principle 3: AI Enables Semantic Understanding**
```
Rules (text) + Script (text) → AI → Context-aware analysis
```
**Lesson:** Let AI handle nuance, humans define rules.

**Principle 4: Multiple Detail Levels Serve Different Needs**
```
abstract.md  - Fast reference
complete.md  - Deep learning
summary.md   - Quick check
```
**Lesson:** One size doesn't fit all use cases.

### The Power of Complementarity

**ShellCheck's strengths cover BCS's weaknesses:**
- Fast → Slow
- Deterministic → Variable
- Offline → Online
- Syntax → Style

**BCS's strengths cover ShellCheck's weaknesses:**
- Contextual → Literal
- Self-documenting → Separate docs
- Easy to extend → Hard to extend
- Explains why → Shows what

**Together:**
```bash
# Step 1: Catch syntax errors (fast, deterministic)
shellcheck script.sh

# Step 2: Check style compliance (thorough, contextual)
bcs check script.sh

# Result: Correct syntax AND consistent style
```

---

## Conclusion: Structural Philosophy

### ShellCheck: The Precision Instrument
- Built like a **scientific instrument**: precise, reliable, repeatable
- **Engineering excellence**: type safety, testing, performance
- **Trade-off**: High expertise barrier for contributors

### BCS: The Living Document
- Built like a **knowledge base**: flexible, extensible, understandable
- **Accessibility**: anyone can contribute, markdown is universal
- **Trade-off**: AI dependency, slower validation

### The Deeper Insight

**ShellCheck proves:** Traditional compiler architecture works brilliantly for deterministic checks.

**BCS proves:** Documentation-first + AI can handle semantic validation without parsing.

**Together they demonstrate:** Different problems need different architectures. The future likely combines both approaches - deterministic checks for syntax, AI interpretation for style and context.

---

**End of Structural Analysis**

*October 14, 2025*
*A deep examination of two complementary approaches to shell script validation*
