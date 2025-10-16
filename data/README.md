# BASH-CODING-STANDARD.md Data Tree

This directory contains the decomposed source files for `BASH-CODING-STANDARD.md`. The standard is split into a navigable directory tree structure with each subsection in its own file.

## Directory Structure

```
data/
├── 00-header.md                    # Document title, principles, table of contents
├── 01-script-structure/            # Script Structure & Layout
├── 02-variables/                   # Variable Declarations & Constants
├── 03-expansion/                   # Variable Expansion & Parameter Substitution
├── 04-quoting/                     # Quoting & String Literals
├── 05-arrays/                      # Arrays
├── 06-functions/                   # Functions
├── 07-control-flow/                # Control Flow
├── 08-error-handling/              # Error Handling
├── 09-io-messaging/                # Input/Output & Messaging
├── 10-command-line-args/           # Command-Line Arguments
├── 11-file-operations/             # File Operations
├── 12-security/                    # Security Considerations
├── 13-code-style/                  # Code Style & Best Practices
└── 14-advanced-patterns/           # Advanced Patterns
```

## File Naming Convention

Files use numeric prefixes to ensure proper sort order for concatenation:

- `00-section.md` - Section header
- `01-*.md`, `02-*.md`, etc. - Subsections in logical order

This ensures that when sorted alphabetically, files concatenate in the correct sequence to rebuild the complete document.

## Header Levels

- `##` - Main section headers (e.g., "## Script Structure & Layout")
- `###` - Subsection headers (e.g., "### Shebang and Initial Setup")
- `####` - Sub-subsection headers (rare, used in Code Style section)

## Regenerating BASH-CODING-STANDARD.md

To regenerate the complete standard from these files:

```bash
./regenerate-standard.sh
```

This script:
1. Finds all `.md` files in `data/`
2. Sorts them alphabetically (numeric prefixes ensure correct order)
3. Concatenates them into `BASH-CODING-STANDARD.md`
4. Adds `#fin` marker at the end

## Editing the Standard

To modify the coding standard:

1. Edit the relevant `.md` file(s) in the appropriate subdirectory
2. Run `./regenerate-standard.sh` to rebuild `BASH-CODING-STANDARD.md`
3. Review the regenerated file to ensure formatting is correct

## Benefits of This Structure

- **Navigability**: Easy to find and edit specific subsections
- **Modularity**: Each concept in its own file
- **Version control**: Cleaner git diffs when sections change
- **Collaboration**: Multiple contributors can work on different sections
- **Maintainability**: Easy to add, remove, or reorganize content

## Future Enhancements

Planned improvements include:
- JSON metadata for each section (rules, examples, anti-patterns)
- Automated validation of code examples
- Cross-reference checking between sections
- Generation of different output formats (HTML, PDF, man page)

