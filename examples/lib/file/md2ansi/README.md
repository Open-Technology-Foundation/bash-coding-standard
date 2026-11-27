# MD2ANSI (Bash Implementation)

![Version](https://img.shields.io/badge/version-1.0.2-blue.svg)
![License](https://img.shields.io/badge/license-GPL--3.0-green.svg)
![Shell](https://img.shields.io/badge/bash-5.2+-orange.svg)
![Status](https://img.shields.io/badge/status-stable-brightgreen.svg)

A **zero-dependency Bash implementation** of md2ansi that converts Markdown to ANSI-colored terminal output.

## Overview

This is a pure Bash implementation of the md2ansi markdown-to-ANSI formatter, designed to be compatible with the [Python version](https://github.com/Open-Technology-Foundation/md2ansi) while following strict Bash coding standards. The implementation is completely self-contained in a single executable file with no external dependencies beyond standard POSIX tools.

**Key Features:**
- ✓ Zero installation dependencies
- ✓ Single-file monolithic design
- ✓ Full markdown support (headers, lists, tables, code blocks, formatting)
- ✓ 256-color ANSI output
- ✓ Syntax highlighting for Python, JavaScript, and Bash
- ✓ Security features (file size limits, input sanitization)
- ✓ Compatible with Python version's command-line interface
- ✓ Browser-based markdown preview with pandoc (`mdview`)

## Quick Start

### Installation

#### Quick Start (No Installation Required)

```bash
# Clone the repository
git clone https://github.com/Open-Technology-Foundation/md2ansi.bash.git
cd md2ansi.bash

# Make scripts executable
chmod +x md2ansi md ansi-info md-link-extract mdview

# Test it
md2ansi --version
md2ansi README.md
```

#### Method 1: Using Makefile (Recommended)

**System-wide installation** (requires sudo):

```bash
make install
```

This installs to `/usr/local` by default:
- Executables → `$(PREFIX)/bin/` (`/usr/local/bin/`)
- Man page → `$(PREFIX)/share/man/man1/`
- Bash completion → `/etc/bash_completion.d/md2ansi` (system completion dir; only installed if the directory exists)
- mdview data → `$(PREFIX)/share/mdview/` (config, Lua filter, themes)

**User-local installation** (no sudo required):

```bash
make install PREFIX=$HOME/.local
```

This installs to `~/.local`:
- Executables → `~/.local/bin/`
- Man page → `~/.local/share/man/man1/`
- mdview data → `~/.local/share/mdview/`
- Bash completion is skipped (the `/etc/bash_completion.d` check fails for non-root installs — set `COMPDIR=$HOME/.local/share/bash-completion/completions` to override)

**Custom installation prefix**:

```bash
make install PREFIX=/opt/md2ansi
```

**Other Makefile targets**:

```bash
make uninstall      # Remove installed files
make check          # Verify md2ansi/mdview are on $PATH after install
make test           # Run the test/run_tests suite
make clean          # Remove backup/temp files (*~ *.bak *.tmp)
make help           # Show target list
```

#### Method 2: Manual Installation

For complete control over the installation:

```bash
# Install executables
sudo install -m 0755 md2ansi /usr/local/bin/
sudo install -m 0755 md /usr/local/bin/
sudo install -m 0755 ansi-info /usr/local/bin/
sudo install -m 0755 md-link-extract /usr/local/bin/
sudo install -m 0755 mdview /usr/local/bin/

# Install manpage
sudo install -m 0644 md2ansi.1 /usr/local/share/man/man1/
sudo mandb  # Update man database

# Install bash completion (Makefile uses /etc/bash_completion.d when present)
sudo install -m 0644 md2ansi.bash_completion /etc/bash_completion.d/md2ansi

# Install mdview data (config + Lua filter + themes)
sudo mkdir -p /usr/local/share/mdview/themes
sudo install -m 0644 mdview.conf /usr/local/share/mdview/
sudo install -m 0644 rewrite-md-links.lua /usr/local/share/mdview/
sudo install -m 0644 themes/*.css themes/*.theme /usr/local/share/mdview/themes/

# Verify installation
md2ansi --version
man md2ansi
```

#### Post-Installation

**View the manual page:**

```bash
man md2ansi
```

**For user-local installation**, ensure `~/.local/bin` is in your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Add to `~/.bashrc` or `~/.bash_profile` to make permanent.

**Enable bash completion** (user-local only):

System install drops the completion file in `/etc/bash_completion.d/md2ansi` (sourced automatically by login shells). For a user-local install, override `COMPDIR` and source it from `~/.bashrc`:

```bash
make install PREFIX=$HOME/.local COMPDIR=$HOME/.local/share/bash-completion/completions

# Add to ~/.bashrc
if [ -f ~/.local/share/bash-completion/completions/md2ansi ]; then
  . ~/.local/share/bash-completion/completions/md2ansi
fi
```

### Basic Usage

```bash
# View a markdown file
md2ansi README.md

# With pagination (recommended for long files)
md README.md

# Process from stdin
cat README.md | md2ansi
echo "# Hello **World**" | md2ansi

# Multiple files
md2ansi file1.md file2.md file3.md

# Preview in browser (requires pandoc)
mdview README.md

# View the manual
man md2ansi
```

### Common Use Cases

```bash
# Read documentation in color
md /usr/share/doc/bash/README

# Preview your markdown before committing
md2ansi CHANGELOG.md | less -R

# View remote markdown files
curl -s https://raw.githubusercontent.com/user/repo/main/README.md | md2ansi

# Check how your documentation will render
./md README.md
```

## Features

### Fully Implemented

**Headers** (H1-H6) with distinct color gradients
- Bright yellow (H1) to dark gray (H6)
- Inline formatting supported within headers

**Inline Formatting:**
- ✓ Bold (`**text**`)
- ✓ Italic (`*text*`)
- ✓ Combined bold+italic (`***text***`)
- ✓ Strikethrough (`~~text~~`)
- ✓ Inline code (`` `code` ``)
- ✓ Links (`[text](url)`) with underline formatting
- ✓ Images (`![alt](url)`) displayed as placeholders

**Lists:**
- ✓ Unordered lists (`-` or `*`)
- ✓ Ordered lists (`1.`, `2.`, etc.)
- ✓ Task lists (`- [ ]` and `- [x]`)
- ✓ Nested lists with proper indentation
- ✓ Inline formatting within list items

**Tables:**
- ✓ Pipe-delimited tables with alignment support
- ✓ Left, center, and right alignment (`:---`, `:---:`, `---:`)
- ✓ Inline formatting in cells
- ✓ Proper borders and spacing
- ✓ Auto-sizing columns

**Code Blocks:**
- ✓ Fenced code blocks (` ``` ` and `~~~`)
- ✓ Syntax highlighting for Python, JavaScript, and Bash
- ✓ Language detection and aliases (py, js, sh)
- ✓ Comment and keyword highlighting

**Additional Elements:**
- ✓ Blockquotes (`>`)
- ✓ Horizontal Rules (`---`, `===`, `___`)
- ✓ Footnotes (`[^1]` references and `[^1]: text` definitions)

**Advanced Features:**
- ✓ ANSI-aware text wrapping
- ✓ Terminal width auto-detection
- ✓ Feature toggles (--no-tables, --no-syntax-highlight, etc.)
- ✓ Plain mode (--plain): every feature toggle off at once
- ✓ Colorless output with TERM=dumb (log files, non-ANSI terminals)
- ✓ Debug mode with detailed traces

**Security:**
- ✓ File size limits (10MB maximum)
- ✓ Input sanitization (ANSI escape removal)
- ✓ Proper signal handling

## Utility Scripts

### `md` - Paginated Viewer

The `md` script wraps `md2ansi` output with `less` for comfortable viewing of long markdown files:

```bash
md README.md              # View with pagination and color
md documentation/*.md     # Browse multiple files sequentially
```

**Features:**
- Automatic pagination using `less -FXRS`
- Auto-exit if content fits on one screen (-F)
- No terminal initialization (-X)
- Raw ANSI color support (-R)
- No line wrapping (-S)

**Usage:**
- `SPACE` - Next page
- `b` - Previous page
- `q` - Quit
- `/pattern` - Search
- `n` - Next search result

### `ansi-info` - ANSI Palette & Terminal Capability Report

Renders a four-section report covering the full ANSI colour picture for the active terminal:

```bash
ansi-info             # Display full report (paged via less -FXRS)
ansi-info | cat       # Dump raw escape codes (bypass pager)
```

**Sections:**

1. **256-colour palette** — Standard 16 (0-15), 6×6×6 cube (16-231), and grayscale ramp (232-255), with `#RRGGBB` labels beneath every swatch.
2. **SGR text attributes** — bold, dim, italic, underline, double-underline, blink, reverse, strike, overline, plus combined attribute+colour demos.
3. **24-bit truecolor ramps** — red, green, blue, HSV hue sweep, and grayscale gradients via `\e[38;2;R;G;Bm`.
4. **Terminal capability footer** — named codes for indices 0-15, plus `TERM`, `COLORTERM`, `tput colors`, and truecolor detection.

**Useful for:**
- Verifying terminal 256-colour and truecolor support
- Cross-referencing palette indices with hex/RGB values
- Testing SGR attribute rendering
- Diagnosing terminal capability mismatches

### `md-link-extract` - Link Extractor

Extract and list all URLs from markdown files:

```bash
md-link-extract README.md              # Extract all links
md-link-extract docs/*.md | sort -u    # Deduplicated links from multiple files
md-link-extract *.md | wc -l          # Count total links
```

**Features:**
- ✓ Extracts inline links `[text](url)`
- ✓ Extracts bare URLs `<http://example.com>`
- ✓ Extracts reference-style links `[text][ref]`
- ✓ Automatic URL deduplication
- ✓ One URL per line for easy processing

**Use cases:**
- Link validation before publishing
- Finding broken documentation links
- Creating link inventories
- SEO analysis

### `mdview` - Browser-Based Markdown Preview

View markdown files as styled HTML in a browser window. Converts markdown via pandoc with configurable themes and syntax highlighting:

```bash
mdview README.md                          # Open in browser with default theme
mdview --theme github-dark doc.md         # Specify theme
mdview --window-size 1200x900 README.md   # Custom browser window size
mdview --browser /usr/bin/firefox doc.md  # Override browser
```

**Requires:** `pandoc` (the only external dependency in the project)

**Features:**
- Recursive inter-file link resolution (`.md` links rewritten to `.html`)
- [← Back] navigation links on child pages
- Automatic browser detection (Google Chrome, Chromium, or xdg-open fallback)
- Configurable themes via CSS + highlight-style pairs
- XDG-compliant configuration hierarchy
- Safe for sourcing as a Bash library (`source mdview`)
- Scaled temp file cleanup (30s base + 2s per converted file; or `--preserve-tmp`)
- `--app` mode for Chrome/Chromium (clean window without browser chrome)

**Configuration:**

| Level | Config File | Theme Directory |
|:------|:------------|:----------------|
| System | `<prefix>/share/mdview/mdview.conf` | `<prefix>/share/mdview/themes/` |
| User | `${XDG_CONFIG_HOME:-~/.config}/mdview/mdview.conf` | `${XDG_DATA_HOME:-~/.local/share}/mdview/themes/` |

Precedence: CLI flags > user config > system config > defaults

Each theme requires two files: `<name>.css` (page styling) and `<name>.theme` (pandoc syntax highlight style).

**Options:**

| Option | Description | Default |
|:-------|:------------|:--------|
| `-t, --theme NAME` | Theme name | `github-dark` |
| `-s, --window-size WxH` | Browser window dimensions | `960x1080` |
| `-b, --browser PATH` | Browser executable | auto-detect |
| `-P, --preserve-tmp` | Keep session directory and print its path | |
| `-V, --version` | Show version | |
| `-h, --help` | Show help | |

**Sourced mode:**

```bash
source mdview           # Import mdview() function
mdview README.md        # Call directly
```

When sourced, `mdview` does not impose `set -e` or modify the caller's shell traps.

## Command-Line Options

### Basic Options

```bash
# Show help
md2ansi --help
md2ansi -h

# Show version
md2ansi --version
md2ansi -V

# Enable debug mode (output to stderr)
md2ansi --debug README.md 2>debug.log
md2ansi -D file.md

# Force specific terminal width
md2ansi --width 100 README.md
md2ansi -w 80 file.md

# Plain mode: every feature toggle off (colors remain)
md2ansi --plain README.md
md2ansi -t file.md

# No ANSI codes at all (colors and styles off)
TERM=dumb md2ansi README.md
```

### Feature Toggles

Selectively disable specific features:

```bash
# Disable table formatting
md2ansi --no-tables doc.md

# Disable syntax highlighting
md2ansi --no-syntax-highlight code-heavy.md

# Disable footnotes
md2ansi --no-footnotes academic.md

# Disable task lists (checkboxes)
md2ansi --no-task-lists todo.md

# Disable image placeholders
md2ansi --no-images doc.md

# Disable link formatting
md2ansi --no-links plain.md

# Combine multiple toggles
md2ansi --no-tables --no-syntax-highlight --no-footnotes simple.md
```

### Examples with Options

```bash
# Process file with custom width for narrow terminals
md2ansi -w 60 README.md

# Debug table parsing issues
md2ansi -D tables.md 2>&1 | grep -i table

# No ANSI codes when appending to log files
TERM=dumb md2ansi CHANGELOG.md >> release-notes.txt

# Disable heavy features for faster processing
md2ansi --no-syntax-highlight --no-tables large-file.md
```

## Expanded Examples

### Headers and Formatting

**Input:**
```markdown
# Main Title
## Subtitle
### Section Header

This is **bold**, *italic*, and ***bold italic*** text.

This is ~~strikethrough~~ and `inline code`.

Visit [GitHub](https://github.com) for more.
```

**Command:**
```bash
echo "..." | md2ansi
```

**Result:** Colored terminal output with distinct header colors, formatted text, and underlined links.

### Lists and Task Lists

**Input:**
```markdown
Shopping List:
- Apples
- Oranges
  - Valencia oranges
  - Blood oranges
- Bananas

Todo:
- [x] Write documentation
- [ ] Add tests
- [ ] Review code
```

**Command:**
```bash
md2ansi shopping.md
```

**Result:** Nested bullets with proper indentation, checked and unchecked task boxes.

### Tables with Alignment

**Input:**
```markdown
| Feature | Status | Priority |
|:--------|:------:|---------:|
| Headers | ✓      | High     |
| Tables  | ✓      | Medium   |
| Code    | ✓      | High     |
```

**Command:**
```bash
md2ansi features.md
```

**Result:** Bordered table with left, center, and right aligned columns.

### Code Blocks with Syntax Highlighting

**Input:**
````markdown
```python
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)
```
````

**Command:**
```bash
md2ansi code-example.md
```

**Result:** Color-highlighted Python code with keywords, functions, and comments colored appropriately.

### Blockquotes

**Input:**
```markdown
> This is a blockquote.
> It can span multiple lines.
>
> It can even have multiple paragraphs.
```

**Command:**
```bash
md2ansi quote.md
```

**Result:** Indented quoted text with distinct background color.

### Footnotes

**Input:**
```markdown
This statement needs a citation[^1].

Another fact[^2] worth noting.

[^1]: Source: Academic Journal, 2024
[^2]: See documentation for details
```

**Command:**
```bash
md2ansi academic.md
```

**Result:** Footnote references inline, definitions rendered at bottom of document.

### Real-World Usage

```bash
# Preview your project README
md README.md

# Check documentation before deployment
find ./docs -name "*.md" -exec md {} \;

# View system documentation in color
md /usr/share/doc/bash/README

# Quick reference for command output
man bash | col -b > bash.txt && md bash.txt

# Compare markdown rendering
diff <(md2ansi version1.md) <(md2ansi version2.md)
```

## Comparison Table

### vs Python md2ansi

| Aspect | Bash Version | Python Version | Notes |
|:-------|:-------------|:---------------|:------|
| **Installation** | Copy one file | `pip install` | Bash: zero dependencies |
| **Startup Time** | ~50ms | ~30ms | Bash slightly slower |
| **Processing Speed** | 2-3x slower | Baseline | Python faster for large files |
| **File Size** | 1,223 lines (36KB) | ~800 lines | Bash more verbose (md2ansi only) |
| **Dependencies** | None (coreutils only) | Python 3.7+ | Bash more portable |
| **Design** | Monolithic single file | Single module | Both self-contained |
| **Features** | 100% compatible | Full feature set | Identical CLI |
| **Syntax Highlighting** | Line-based regex | Token-based parser | Python more sophisticated |
| **Error Handling** | `set -e` + trap | try/except | Different paradigms |
| **ReDoS Protection** | None (no regex timeout) | `multiprocessing` timeout | Python only |
| **Memory Usage** | Very low | Low | Both efficient |
| **Platform** | Linux/Unix/macOS | Cross-platform | Python more portable |
| **Security** | Built-in limits | Built-in limits | Python adds a regex timeout |

**Recommendation:**
- **Use Bash version**: Quick installation, zero dependencies, system integration
- **Use Python version**: Larger files (>5MB), complex syntax highlighting, Windows support

### vs Other Markdown Renderers

| Feature | md2ansi.bash | bat | glow | mdcat | rich |
|:--------|:-------------|:----|:-----|:------|:-----|
| **Zero Install** | ✓ | ✗ | ✗ | ✗ | ✗ |
| **Dependencies** | None | Rust | Go | Rust | Python |
| **Tables** | ✓ | ✗ | ✓ | ✓ | ✓ |
| **Syntax Highlight** | Basic | ✓✓ | ✓ | ✓ | ✓✓ |
| **Footnotes** | ✓ | ✗ | ✗ | ✗ | ✓ |
| **File Size** | 45KB | ~5MB | ~10MB | ~2MB | varies |
| **Startup** | 50ms | 100ms | 200ms | 80ms | 150ms |
| **Portable** | ✓✓ | ✓ | ✓ | ✓ | ✓ |
| **Customizable** | ✓ | ✓✓ | ✓ | ✓ | ✓✓ |

**md2ansi.bash advantages:**
- Truly zero dependencies (only coreutils)
- Single file deployment
- Full markdown spec support
- Footnote support
- Smallest file size
- Fast startup

**When to use alternatives:**
- **bat**: Need advanced syntax highlighting, line numbers, git integration
- **glow**: Want TUI navigation, emoji support, glamorous styling
- **mdcat**: Need image rendering in iTerm2/Kitty
- **rich**: Python ecosystem integration, complex formatting

## Architecture

### Design Philosophy

md2ansi follows a **monolithic single-file design** for maximum portability and zero installation friction. All core functionality is embedded in one executable file (`md2ansi`, 1,223 lines) with no external libraries or modules. The `mdview` browser preview utility (297 lines) is a separate companion script.

**Design Benefits:**

| Benefit | Description |
|:--------|:------------|
| **Zero Installation Issues** | No broken paths, missing dependencies, or version conflicts |
| **Single File Deployment** | Copy to `/usr/local/bin/` and it works immediately |
| **Faster Startup** | No overhead from sourcing multiple files (~50ms) |
| **Simpler Debugging** | All code in one place for easy tracing and modification |
| **Clean Architecture** | Well-organized internal sections with clear markers |
| **Maximum Portability** | Works on any system with Bash 5.2+ and coreutils |

### Project Structure

```
md2ansi.bash/
├── md2ansi               # Main executable (1,223 lines, 36KB)
│                         # ◉ All functionality in single file
├── md2ansi.bash          # Symlink → md2ansi
├── md                    # Pagination wrapper (53 lines)
├── ansi-info             # ANSI palette + terminal capability report (318 lines)
├── md-link-extract       # Link extractor (66 lines)
├── mdview                # Browser-based markdown preview (297 lines)
├── mdview.conf           # Default mdview configuration
├── rewrite-md-links.lua  # Pandoc Lua filter: .md → .html link rewriting
├── themes/               # mdview theme files
│   ├── github-dark.css   # Page styling (dark theme)
│   ├── github-dark.theme # Pandoc syntax highlight style (dark)
│   ├── github-light.css  # Page styling (light theme)
│   └── github-light.theme # Pandoc syntax highlight style (light)
├── md2ansi.1             # Man page
├── md2ansi.bash_completion # Bash completion (195 lines)
├── Makefile              # Build/install targets
├── LICENSE               # GPL-3.0 license
├── README.md             # This file
└── test/
    ├── run_tests              # Test suite runner (181 lines)
    ├── test_ansi_info.sh      # ansi-info capability report (58 lines)
    ├── test_basic.sh          # Basic features (128 lines)
    ├── test_code.sh           # Code blocks (168 lines)
    ├── test_edge_cases.sh     # Edge cases (208 lines)
    ├── test_footnotes.sh      # Footnotes (105 lines)
    ├── test_gaps.sh           # Audit gap coverage (163 lines)
    ├── test_md.sh             # md pagination wrapper (45 lines)
    ├── test_md_link_extract.sh # md-link-extract URL extraction (136 lines)
    ├── test_mdview.sh         # mdview utility tests (173 lines)
    ├── test_options.sh        # Feature toggles (106 lines)
    ├── test_security.sh       # Security features (133 lines)
    ├── test_tables.sh         # Tables (96 lines)
    └── test_wrapping.sh       # Text wrapping (182 lines)
```

**Total Project Size:**
- Main executable: 1,223 lines
- Utility scripts: 734 lines (md, ansi-info, md-link-extract, mdview)
- Test suite: 1,882 lines (13 test files + runner)
- **Total: 3,839 lines**

### Internal Code Organization

The `md2ansi` script is organized into clearly marked sections:

| Section | Lines | Purpose |
|:--------|:------|:--------|
| **Script Header** | 1-38 | Shebang, strict mode, metadata, global variables, state tracking |
| **Utility Functions** | 39-150 | Messaging, terminal detection, file validation, signal handling, string manipulation |
| **ANSI Color Definitions** | 151-246 | Color constants, ANSI escape sequences, color detection, strip/sanitize functions |
| **Rendering Functions** | 247-551 | Bold, italic, strikethrough, links, inline code, text wrapping, header/list/blockquote rendering |
| **Table Rendering Functions** | 552-794 | Table parsing, alignment detection, column width calculation, table output rendering |
| **Markdown Parser Functions** | 795-1010 | Main parser, code blocks, tables, headers, lists, footnotes, regular text processing |
| **Main Script Functions** | 1011-1223 | Argument parsing, file processing, main entry point, program invocation |

Section line numbers drift as the file grows; verify with `grep -n -A1 '^# ---' md2ansi`.

Each section opens with an 80-dash divider and a short title. These six are the
only dividers in the file; functions inside a section carry their own doc comments:
```bash
# --------------------------------------------------------------------------------
# ANSI color definitions
```

### State Management

**Global State Variables:**

```bash
# Configuration
TERM_WIDTH=0              # Auto-detected terminal width
MAX_FILE_SIZE=10485760    # 10MB file size limit

# Feature Flags
OPTIONS[footnotes]=1
OPTIONS[syntax_highlight]=1
OPTIONS[tables]=1
OPTIONS[task_lists]=1
OPTIONS[images]=1
OPTIONS[links]=1

# Parsing State
IN_CODE_BLOCK=0           # Are we inside a code fence?
CODE_FENCE_TYPE=''        # ``` or ~~~
CODE_LANG=''              # Language identifier
FOOTNOTES=()              # Associative array of footnote definitions
FOOTNOTE_REFS=()          # Array tracking footnote reference order
```

### Key Functions

**Core Processing Pipeline:**
1. `main()` - Entry point, argument parsing
2. `process_file()` - Read file/stdin into line array
3. `parse_markdown()` - Main parsing loop (block-level)
4. `colorize_line()` - Inline formatting (bold, italic, links)
5. `wrap_text()` - ANSI-aware text wrapping
6. Output to stdout

**Rendering Functions:**
- `render_header()` - H1-H6 with color gradients
- `render_list_item()` - Unordered lists
- `render_ordered_item()` - Numbered lists
- `render_task_item()` - Checkboxes
- `render_table()` - Complete table parsing and rendering
- `render_code_line()` - Code with syntax highlighting
- `render_blockquote()` - Quoted text
- `render_hr()` - Horizontal rules
- `render_footnotes()` - Footnote section at end

## Testing

### Test Suite

The project includes a comprehensive test suite with 13 test files covering all features:

| Test File | Lines | Coverage |
|:----------|:------|:---------|
| **run_tests** | 181 | Test runner with assertion framework |
| **test_ansi_info.sh** | 58 | `ansi-info` four-section capability report, --help/--version, paged output |
| **test_basic.sh** | 128 | Headers, inline formatting, lists, links, images, horizontal rules |
| **test_code.sh** | 168 | Fenced code blocks, syntax highlighting, language detection, code fence types |
| **test_edge_cases.sh** | 208 | Empty files, malformed input, edge cases, error handling |
| **test_footnotes.sh** | 105 | Footnote references, definitions, ordering, missing definitions |
| **test_gaps.sh** | 163 | Audit gap coverage, combined flag parsing, fence mismatch handling |
| **test_md.sh** | 45 | `md` pagination wrapper, its own --help/--version, less flag passthrough |
| **test_md_link_extract.sh** | 136 | Inline / reference / bare-URL extraction, dedupe, multi-file |
| **test_mdview.sh** | 173 | mdview CLI options, argument validation, sourced mode, full pipeline |
| **test_options.sh** | 106 | Feature toggles, --no-* options, plain mode, option combinations |
| **test_security.sh** | 133 | File size limits, line length limits, input sanitization, pathological regex input |
| **test_tables.sh** | 96 | Table parsing, alignment (left/center/right), borders, inline formatting in cells |
| **test_wrapping.sh** | 182 | Text wrapping, ANSI-aware wrapping, terminal width handling |

**Total test coverage: 1,882 lines**

### Running Tests

```bash
# Run complete test suite
./test/run_tests

# Run individual test files
./test/test_ansi_info.sh
./test/test_basic.sh
./test/test_code.sh
./test/test_edge_cases.sh
./test/test_footnotes.sh
./test/test_gaps.sh
./test/test_md.sh
./test/test_md_link_extract.sh
./test/test_mdview.sh
./test/test_options.sh
./test/test_security.sh
./test/test_tables.sh
./test/test_wrapping.sh
```

### Test Framework

The test suite uses a simple assertion-based framework:

```bash
# Example assertions
assert_equals "expected" "actual" "test name"
assert_contains "haystack" "needle" "test name"
assert_not_empty "$value" "test name"
assert_exit_code 0 "command" "test name"
```

### Manual Testing

```bash
# Test basic rendering
echo "# Test\n\nThis is **bold** text." | ./md2ansi

# Test with real README
./md README.md

# Test color support
./ansi-info

# Test link extraction
./md-link-extract README.md

# Test browser preview (requires pandoc)
./mdview README.md

# Test with debug output
./md2ansi -D README.md 2>debug.log
cat debug.log

# Test different terminal widths
./md2ansi -w 60 README.md
./md2ansi -w 120 README.md

# Test feature toggles
./md2ansi --no-tables --no-syntax-highlight README.md
./md2ansi --plain README.md
```

## Development

### Code Standards

This implementation strictly adheres to the Bash Coding Standard:

| Standard | Implementation |
|:---------|:---------------|
| **Error Handling** | `set -euo pipefail` at start |
| **Shell Options** | `shopt -s inherit_errexit shift_verbose extglob nullglob` |
| **Indentation** | 2 spaces throughout (no tabs) |
| **Variables** | Type-specific declarations (`declare -i`, `declare -a`, `declare -A`) |
| **Constants** | `readonly` for immutable values |
| **Scoping** | `local` for all function variables |
| **Conditionals** | `[[ ]]` for tests, `(( ))` for arithmetic |
| **Quoting** | All variable expansions quoted (except in `[[ ]]` or `(( ))`) |
| **Messaging** | Standard functions: `error`, `warn`, `info`, `debug`, `die` |
| **Cleanup** | Signal handling with `trap` |
| **EOF Marker** | All scripts end with `#fin` followed by blank line |
| **Increment** | Standalone `var+=1` — never `((var++))` or `((var+=1))` |

### Adding New Features

Since md2ansi is monolithic, all edits are made to the single `md2ansi` file.

**To add inline formatting:**

Edit the `colorize_line()` function in the Rendering Functions section:

```bash
# Example: Add underline support for __text__
sed -E "s/__([^_]+)__/${ANSI_UNDERLINE}\1${ANSI_RESET}/g"
```

**To add block-level elements:**

Edit the `parse_markdown()` function in the Markdown Parser Functions section:

```bash
# Example: Add definition lists
if [[ $line =~ ^:\ (.*)$ ]]; then
  render_definition "${BASH_REMATCH[1]}"
  continue
fi
```

**To add syntax highlighting for new language:**

Edit the `render_code_line()` and add a highlighting function:

```bash
highlight_ruby() {
  local -- code="$1"
  # Add Ruby-specific patterns
  sed -E "s/\b(def|class|end|if|else)\b/${COLOR_KEYWORD}\1${COLOR_CODEBLOCK}/g" <<<"$code"
}
```

### Debug Mode

```bash
# Enable debug output (to stderr)
./md2ansi -D file.md 2>debug.log

# View debug output
cat debug.log

# Real-time debug viewing
./md2ansi -D file.md 2>&1 | grep DEBUG

# Debug specific features
./md2ansi -D tables.md 2>&1 | grep -i table
```

**Debug output includes:**
- ◉ Terminal width detection
- ◉ File size validation
- ◉ Table parsing steps (column count, alignment)
- ◉ Feature flag states

### Code Review Checklist

Before submitting changes:

- [ ] Follows Bash Coding Standard strictly
- [ ] All variables properly declared with types (`declare -i`, `declare -a`, etc.)
- [ ] Functions use `local` for all variables
- [ ] No shellcheck warnings (`shellcheck md2ansi`)
- [ ] Proper error handling with meaningful exit codes
- [ ] Scripts end with `#fin` marker
- [ ] Comments for complex logic
- [ ] Test coverage for new features
- [ ] Documentation updated in README
- [ ] No performance regressions

## Performance

### Benchmarks

| File Size | Processing Time | Notes |
|:----------|:----------------|:------|
| Small (<10KB) | ~100ms | ◉ Fast, instant feedback |
| Medium (100KB) | ~500ms | ◉ Good, responsive |
| Large (1MB) | ~3-5s | ◉ Acceptable for terminal viewing |
| Very Large (5-10MB) | ~15-30s | ◉ Slow but within limits |

**Optimization target:** Terminal viewing responsiveness, not batch processing speed.

### Performance Characteristics

| Metric | Value | Notes |
|:-------|:------|:------|
| **Startup time** | ~50ms | Single-file load, no library sourcing |
| **Processing speed** | ~2-3x slower than Python | Acceptable for terminal use |
| **Memory usage** | Very low | Efficient line-by-line processing |
| **File size limit** | 10MB | Configurable via `MAX_FILE_SIZE` |
| **Terminal width** | 20-500 columns | Bounds checking |

### Comparison to Python Version

For reference, processing a 1MB markdown file:
- **Python version:** ~2 seconds
- **Bash version:** ~5 seconds
- **Difference:** Acceptable for interactive terminal use

**Optimization notes:**
- Single `sed` invocation with multiple patterns in `colorize_line()`
- Minimal subprocess spawning
- Efficient regex patterns
- ANSI-aware text wrapping without repeated strip operations

## Security Features

| Feature | Implementation | Limit/Behavior |
|:--------|:---------------|:---------------|
| **File Size Limits** | Pre-processing validation with `stat -c %s` | 10MB maximum (configurable) |
| **Input Sanitization** | Escape/control sequence removal | All input cleaned at read time via `sanitize_input()` (CSI, OSC, C0/C1 controls) |
| **Injection Prevention** | Proper variable quoting throughout | All expansions quoted |
| **Signal Handling** | `trap` cleanup handlers | Graceful Ctrl-C, proper exit |
| **Bounds Checking** | Terminal width validation | 20-500 column range |
| **Directory Protection** | Explicit file checks | Rejects directories |
| **Permission Checks** | Read permission validation | Clear error messages |

### Security Best Practices

```bash
# File size is checked before processing
validate_file_size "$filepath" "$MAX_FILE_SIZE"

# Input is sanitized once, as it is read (file or stdin)
done < <(sanitize_input "$filepath")

# All variables are quoted
printf '%s\n' "$variable"

# Signal handlers ensure cleanup
trap 'cleanup $?' EXIT
trap 'cleanup 130' INT
```

## FAQ

### General Usage

**Q: Why use md2ansi.bash instead of the Python version?**

A: The Bash version has zero installation dependencies and can be deployed as a single file. Perfect for system integration, minimal environments, or when you can't install Python packages.

**Q: Will this work on macOS?**

A: Yes, as long as you have Bash 5.2+ installed. macOS ships with Bash 3.2, so install via `brew install bash`.

**Q: Can I use this in scripts and automation?**

A: Absolutely. For log files use `TERM=dumb md2ansi file.md`, which writes no ANSI codes (`--plain` only turns off formatting features and keeps colors). For interactive viewing, pipe to `less -R`.

**Q: How do I check if my terminal supports 256 colors?**

A: Run `tput colors`. Should return 256 or higher. Also try `./ansi-info` to see all colors.

### Troubleshooting

**Q: Colors not showing?**

A: Check terminal color support: `tput colors` (should be ≥256). Try setting `TERM=xterm-256color`.

**Q: Script not found error?**

A: Make sure you're in the repository directory or use the full path. Check that scripts are executable: `chmod +x md2ansi md`.

**Q: Permission denied error?**

A: Run `chmod +x md2ansi md ansi-info md-link-extract mdview` to make scripts executable.

**Q: Output is garbled?**

A: Your terminal may not support ANSI codes. Turn them off with `TERM=dumb md2ansi file.md` (`--plain` keeps colors).

**Q: Tables not rendering correctly?**

A: Check that your table has proper alignment row (second row with `---`, `:---:`, `---:`). Or disable tables: `--no-tables`.

**Q: Slow performance on large files?**

A: For files >5MB, consider using the Python version. Or disable heavy features: `--no-syntax-highlight --no-tables`.

### Features

**Q: Can I customize the colors?**

A: Yes, edit the ANSI color constants in the `md2ansi` file (around lines 183-229). Look for `COLOR_H1`, `COLOR_KEYWORD`, etc.

**Q: Does it support GitHub-flavored markdown?**

A: Most GFM features are supported: tables, task lists, strikethrough, fenced code blocks. Some advanced features (e.g., emoji shortcodes) are not implemented.

**Q: Can I add syntax highlighting for other languages?**

A: Yes, add a `highlight_<language>()` function in the Inline Rendering section and update the language case statement in `render_code_line()`.

**Q: What about nested formatting like bold italic in tables?**

A: Supported. Inline formatting works within table cells, list items, headers, and blockquotes.

**Q: Can I process from a URL?**

A: Yes, pipe from `curl`: `curl -s https://example.com/file.md | md2ansi`

### Development

**Q: How do I run the test suite?**

A: Run `./test/run_tests` from the project directory. Individual tests can be run directly: `./test/test_basic.sh`.

**Q: How do I contribute?**

A: Follow the Bash Coding Standard strictly, run `shellcheck`, add tests, and update documentation.

**Q: Why monolithic instead of modular?**

A: Zero installation friction. One file to copy, no broken dependencies. The code is still well-organized with clear section markers.

**Q: Can I use this as a library?**

A: `md2ansi` is designed as a standalone executable, but you can source it and call `parse_markdown` directly if needed. The `mdview` utility is explicitly designed to work in both script and sourced modes.

## Known Limitations

| Limitation | Impact | Workaround |
|:-----------|:-------|:-----------|
| **Syntax Highlighting** | Simpler than Python (line-based vs token-based) | Use Python version for complex code |
| **Unicode Width** | Depends on terminal Unicode support | Ensure UTF-8 terminal locale |
| **Performance** | ~2-3x slower than Python for large files | Use Python version for files >5MB |
| **Nested Formatting** | Some edge cases may render differently | Test with actual content |
| **Windows Support** | Requires WSL or Cygwin | Use Python version on native Windows |
| **Emoji Rendering** | No emoji shortcode expansion | Use actual emoji characters |
| **Math Rendering** | No LaTeX/MathJax support | Not planned for terminal renderer |

## Contributing

### Contribution Guidelines

| Requirement | Tool/Process |
|:------------|:-------------|
| **Code Style** | Follow Bash Coding Standard strictly |
| **Linting** | Run `shellcheck -x md2ansi md ansi-info md-link-extract mdview test/*.sh` with zero warnings |
| **Testing** | Add tests for new features, all tests must pass |
| **Compatibility** | Maintain CLI compatibility with Python version |
| **Documentation** | Update README for new features, keep accurate |
| **Performance** | No regressions, benchmark large files if changing parser |

### Development Workflow

```bash
# 1. Make changes to code
vim md2ansi

# 2. Run shellcheck (must pass with zero warnings)
shellcheck -x md2ansi md ansi-info md-link-extract mdview test/*.sh

# 3. Run test suite (all tests must pass)
./test/run_tests

# 4. Test manually with real files
./md README.md
./md2ansi -D test-file.md 2>debug.log

# 5. Commit changes
git add md2ansi test/*.sh README.md
git commit -m "Add feature: description"
git push
```

### Code Review Requirements

All changes must:
- ✓ Follow Bash Coding Standard
- ✓ Pass shellcheck with zero warnings
- ✓ Pass all existing tests
- ✓ Include new tests for new features
- ✓ Update README documentation
- ✓ Use proper variable declarations and quoting
- ✓ Include error handling with meaningful messages
- ✓ End with `#fin` marker

## External Tools Used

All tools are standard and available on any modern Linux/Unix system:

| Tool | Package | Purpose |
|:-----|:--------|:--------|
| `tput` | ncurses | Terminal capability detection, color support |
| `stat` | coreutils | File size validation |
| `sed` | coreutils | Regex substitution for formatting |
| `awk` | coreutils | Text processing (minimal usage) |
| `grep` | coreutils | Pattern matching (minimal usage) |
| `less` | util-linux | Pagination in `md` wrapper |
| `stty` | coreutils | Terminal size detection fallback |
| `pandoc` | pandoc | Markdown-to-HTML conversion (`mdview` only) |

**Zero additional dependencies** for `md2ansi`, `md`, `ansi-info`, and `md-link-extract` — only standard POSIX/GNU utilities.

The `mdview` utility additionally requires `pandoc` for HTML conversion. All other tools are installed by default on Linux, macOS (with Homebrew), and BSD systems.

## License

**GPL-3.0** - Same as parent Python project

See [LICENSE](LICENSE) file for full text.

## Acknowledgments

- Based on the [Python md2ansi](https://github.com/Open-Technology-Foundation/md2ansi) implementation
- Designed for maximum portability and zero dependencies
- Built with readability and maintainability in mind

## Project Statistics

| Metric | Value |
|:-------|:------|
| **md2ansi Lines** | 1,223 lines (36KB) |
| **Total Scripts** | 5 main + 1 test runner + 13 test files |
| **Test Coverage** | 1,882 lines across 13 test files |
| **Total Project** | 3,839 lines |
| **Features** | 15+ markdown elements |
| **Dependencies** | 0 (zero) |
| **Installation** | Single file copy (md2ansi); mdview adds themes |
| **Architecture** | Monolithic single-file design |
| **Languages Highlighted** | Python, JavaScript, Bash |
| **Security Features** | 7+ protections |

---

## Support & Links

- **Repository**: https://github.com/Open-Technology-Foundation/md2ansi.bash
- **Issues**: https://github.com/Open-Technology-Foundation/md2ansi.bash/issues
- **Python Version**: https://github.com/Open-Technology-Foundation/md2ansi
- **License**: GPL-3.0

---

**Status**: ✓ Core implementation complete and functional

**Version**: 1.0.2

#fin
