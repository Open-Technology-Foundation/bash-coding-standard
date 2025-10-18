# Action Items - Bash Coding Standard

**Generated:** 2025-10-17
**Source:** Consolidated from archived planning documents

This document captures actionable items extracted from archived planning and analysis documents (now in `.gudang/`).

---

## High Priority Items

### 1. Rule File Quality Improvements

**Status:** 59 of 76 rule files need enhancement (17 already improved)
**Source:** DEFICIENT-RULES-REPORT.md, IMPROVEMENTS-NEEDED.md (archived)
**Reference Standard:** rule-mdfile-format.md (archived)

**Required improvements:**
- Add rationale sections (3-7 bullet points explaining WHY)
- Include anti-patterns (3-5 wrong/correct pairs)
- Add technical explanations (not vague "it's better" statements)
- Document edge cases and gotchas
- Provide practical real-world examples
- Ensure adequate length (50-100+ lines depending on complexity)

**High Priority Files (26 most critically deficient):**
- See DEFICIENT-RULES-REPORT.md in .gudang/ for complete list
- Focus on files with minimal content or missing rationale

**Action:** Systematically enhance rule files following rule-mdfile-format.md standards

---

### 2. Test Suite Completion

**Status:** 74% pass rate (14/19 tests passing)
**Source:** TESTING-SUMMARY.md (current)

**Known bugs requiring fixes:**
1. **CRITICAL:** Duplicate BCS0206 code (needs resolution)
2. Missing main() function in bcs script
3. Missing VERSION variable
4. ✓ Fixed: Corrupted data file (01-dual-purpose.complete.md)

**Action:** Address remaining test failures and structural issues

---

## Future Subcommand Development

**Source:** FUTURE-SUBCOMMANDS.md (archived)

### Already Implemented (v1.0.0)
- ✓ `template` - Generate BCS-compliant script templates
- ✓ `check` - AI-powered compliance validation

### Planned Future Subcommands

#### 1. `init` - Initialize New Project (Priority: Medium)
**Purpose:** Bootstrap new BCS-compliant projects
**Features:**
- Create project structure with templates
- Generate .bashrc/.profile integrations
- Set up testing framework
- Project types: script, library, toolkit, deployment

#### 2. `validate` - Comprehensive Validation (Priority: Medium)
**Purpose:** Multi-tool validation suite
**Features:**
- ShellCheck integration
- BCS compliance checking
- TODO/FIXME/HACK comment detection
- Security vulnerability scanning
- CI/CD integration support

#### 3. `format` - Auto-Format Scripts (Priority: Low)
**Purpose:** Automatically reformat scripts to BCS standards
**Features:**
- Indent correction (2 spaces)
- Quote normalization
- Variable expansion cleanup
- Function organization enforcement
**Note:** High complexity, use with caution

#### 4. `profile` - Runtime Profiling (Priority: Low)
**Purpose:** Performance analysis for bash scripts
**Features:**
- Execution time per function
- Command call frequency
- Bottleneck identification
- Memory usage tracking

#### 5. `doc` - Generate Documentation (Priority: Low)
**Purpose:** Auto-generate docs from script comments
**Features:**
- Parse function headers
- Extract usage examples
- Generate man pages
- Create API reference

---

## Coding System Evolution

**Source:** DEVELOPMENT.md (archived)

### Current System: BCS Hierarchical Codes
- Format: BCS{catNo}{ruleNo}{subruleNo}
- Example: BCS010201 (Section 1, Rule 2, Subrule 1)
- Status: Working well, no changes planned

### Alternative Proposals (archived for reference)
The following proposals were considered but **not recommended for implementation**:
- Two-tier system (Priority.Category##)
- Semantic descriptive codes (E.V2, S.F3)
- Hybrid minimal approach
- Rules vs Patterns split

**Decision:** Keep current BCS hierarchical system. Alternative proposals archived for historical reference.

---

## Documentation Enhancements

### 1. Rule Quality Standards
**Source:** rule-mdfile-format.md (archived to .gudang/)
**Key principles preserved:**
- Rationale sections required
- Anti-patterns with wrong/correct pairs
- Technical explanations over vague statements
- Edge cases and gotchas documented
- Practical real-world examples
- Adequate length guidelines

**Action:** Use as reference when improving rule files

### 2. Integration Documentation
**Source:** BCS-SHELLCHECK-*.md files (archived to .gudang/)
**Status:** ShellCheck integration analysis completed
**Action:** Reference archived docs if resuming ShellCheck integration work

---

## Medium-Priority Items

### 1. ShellCheck Integration Enhancement
**Source:** BCS-SHELLCHECK-INTEGRATION.md (archived)
**Status:** Analysis completed, implementation deferred
**Action:** Consult archived analysis if/when resuming this work

### 2. Adoption Strategy Development
**Source:** DEVELOPMENT.md (archived)
**Components:**
- Quick reference card creation
- Migration guide for existing codebases
- Tiered adoption strategy (Essential → Standard → Advanced)
- Template infrastructure expansion

### 3. Structural Improvements
**Source:** RESTRUCTURE-VALIDATION.md (archived)
**Status:** 15→14 section restructuring completed and validated
**Action:** No further action needed

---

## Low-Priority / Future Considerations

### 1. FAQ and Philosophy
**Source:** REBUTTALS-FAQ.md (archived)
**Content:** Responses to common criticisms of comprehensive bash standards
**Status:** Useful reference material, archived
**Action:** Consider publishing as blog post or documentation appendix

### 2. Builtins Performance Optimization
**Status:** Current builtins provide 10-158x speedup
**Action:** Monitor for additional optimization opportunities

### 3. Multi-tier Documentation Refinement
**Status:** Three-tier system (complete, abstract, summary) working
**Action:** Ensure all new rules include all three tiers

---

## Notes

- **Archived Documents Location:** `.gudang/`
- **Current Active Documentation:** README.md, CLAUDE.md, TESTING-SUMMARY.md
- **Rule Standard Reference:** `.gudang/rule-mdfile-format.md`
- **Test Coverage:** See TESTING-SUMMARY.md for current status

---

## Tracking Progress

To track work on these items:
1. Create individual issues/tasks as needed
2. Reference this document for context
3. Update TESTING-SUMMARY.md for test-related work
4. Update CLAUDE.md for architectural changes
5. Archive completed planning docs to .gudang/

---

**Last Updated:** 2025-10-17
