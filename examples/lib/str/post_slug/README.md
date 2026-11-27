# post_slug

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
[![PHP 8.0+](https://img.shields.io/badge/php-8.0+-777BB4.svg)](https://www.php.net/)
[![Bash 5.1+](https://img.shields.io/badge/bash-5.1+-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![Node 12.2+](https://img.shields.io/badge/node-12.2+-339933.svg)](https://nodejs.org/)
[![C C11](https://img.shields.io/badge/c-c11-A8B9CC.svg)](https://en.wikipedia.org/wiki/C11_(C_standard_revision))

> A consistent, cross-language slug generator for creating URL-safe and filename-safe strings from any text input.

## 🎯 Overview

**post_slug** converts any text into clean, readable slugs that are safe for URLs, filenames, and other contexts where only ASCII alphanumeric characters are allowed. With identical implementations in **Python**, **JavaScript**, **PHP**, **Bash**, and **C**, it ensures consistent output across your entire stack.

### Key Features

- 🌐 **Cross-language consistency** - Identical output across Python, JavaScript, PHP, and Bash
- 🛡️ **Security-focused** - Input sanitization with 255-character limit to prevent DoS attacks
- 🔧 **Flexible configuration** - Customizable separator, case preservation, and length limits
- 📦 **Zero dependencies** - Uses only built-in language features
- ⚡ **Fast and lightweight** - Optimized for performance
- 🧪 **Thoroughly tested** - Comprehensive test suite with cross-language validation

### Quick Example

```python
from post_slug import post_slug

# Convert a complex title to a clean slug
title = "The Ŝtřãņġę (Inner) Life! of the \"Outsider\""
slug = post_slug(title)
# Output: "the-strange-inner-life-of-the-outsider"
```

## 📦 Installation

### Python

```bash
# Install from PyPI (coming soon)
pip install post-slug

# Or install from source
python -m pip install .
```

### JavaScript/Node.js

```bash
# Install from npm (coming soon)
npm install post-slug

# Or use directly
const { post_slug } = require('./post_slug.js');
```

### PHP

```bash
# Install via Composer (coming soon)
composer require open-technology-foundation/post-slug

# Or include directly
require_once 'post_slug.php';
```

### Bash

```bash
# Source the function
source post_slug.bash

# Or add to your .bashrc
echo 'source /path/to/post_slug.bash' >> ~/.bashrc
```

### C

```bash
# Build the static library + CLI binary ('make' alone only prints help)
cd c && make build

# Install the CLI globally (optional)
sudo make install                # -> /usr/local/bin/post_slug

# Link against the static library
cc -O2 -Ic -o myapp myapp.c c/libpost_slug.a
```

## 🚀 Usage

### Basic Usage

All implementations share the same API:

```
post_slug(input_str, [sep_char], [preserve_case], [max_len])
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `input_str` | string | required | The text to convert into a slug |
| `sep_char` | string | `'-'` | Character to replace non-alphanumeric characters |
| `preserve_case` | bool/int | `false`/`0` | Whether to preserve the original case |
| `max_len` | int | `0` | Maximum length (0 = no limit beyond 255 chars) |

### Language-Specific Examples

<details>
<summary><b>Python</b></summary>

```python
from post_slug import post_slug

# Basic usage
slug = post_slug("Hello, World!")
print(slug)  # "hello-world"

# With underscore separator
slug = post_slug("Hello, World!", "_")
print(slug)  # "hello_world"

# Preserve case
slug = post_slug("Hello, World!", "-", True)
print(slug)  # "Hello-World"

# With max length
slug = post_slug("This is a very long title that needs truncation", "-", False, 20)
print(slug)  # "this-is-a-very-long"

# HTML entities are replaced
slug = post_slug("Barnes &amp; Noble")
print(slug)  # "barnes-noble"

# Special characters and Unicode
slug = post_slug("Über die Universitäts-Philosophie — Schopenhauer, 1851")
print(slug)  # "uber-die-universitats-philosophie-schopenhauer-1851"
```
</details>

<details>
<summary><b>JavaScript</b></summary>

```javascript
const { post_slug } = require('./post_slug.js');

// Basic usage
let slug = post_slug("Hello, World!");
console.log(slug);  // "hello-world"

// With underscore separator
slug = post_slug("Hello, World!", "_");
console.log(slug);  // "hello_world"

// Preserve case
slug = post_slug("Hello, World!", "-", true);
console.log(slug);  // "Hello-World"

// With max length
slug = post_slug("This is a very long title that needs truncation", "-", false, 20);
console.log(slug);  // "this-is-a-very-long"

// Works with modern JavaScript
const titles = [
    "The Great Gatsby",
    "Pride & Prejudice",
    "1984"
];
const slugs = titles.map(title => post_slug(title));
// ["the-great-gatsby", "pride-prejudice", "1984"]
```
</details>

<details>
<summary><b>PHP</b></summary>

```php
<?php
require_once 'post_slug.php';

// Basic usage
$slug = post_slug("Hello, World!");
echo $slug;  // "hello-world"

// With underscore separator
$slug = post_slug("Hello, World!", "_");
echo $slug;  // "hello_world"

// Preserve case
$slug = post_slug("Hello, World!", "-", true);
echo $slug;  // "Hello-World"

// With max length
$slug = post_slug("This is a very long title that needs truncation", "-", false, 20);
echo $slug;  // "this-is-a-very-long"

// In a WordPress context
function my_custom_slug($title) {
    return post_slug($title, '-', false, 200);
}
add_filter('sanitize_title', 'my_custom_slug');
```
</details>

<details>
<summary><b>Bash</b></summary>

```bash
# Source the function
source post_slug.bash

# Basic usage
slug=$(post_slug "Hello, World!")
echo "$slug"  # "hello-world"

# With underscore separator
slug=$(post_slug "Hello, World!" "_")
echo "$slug"  # "hello_world"

# Preserve case
slug=$(post_slug "Hello, World!" "-" 1)
echo "$slug"  # "Hello-World"

# With max length
slug=$(post_slug "This is a very long title that needs truncation" "-" 0 20)
echo "$slug"  # "this-is-a-very-long"

# Batch processing files
for file in *.txt; do
    new_name="$(post_slug "${file%.txt}").txt"
    mv "$file" "$new_name"
done
```
</details>

<details>
<summary><b>C</b></summary>

```c
#include "post_slug.h"
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    /* Basic usage */
    char *s = post_slug("Hello, World!", '-', 0, 0);
    if (s) { puts(s); free(s); }            /* "hello-world" */

    /* Underscore separator */
    s = post_slug("Hello, World!", '_', 0, 0);
    if (s) { puts(s); free(s); }            /* "hello_world" */

    /* Preserve case */
    s = post_slug("Hello, World!", '-', 1, 0);
    if (s) { puts(s); free(s); }            /* "Hello-World" */

    /* Max length 20, cuts at last separator */
    s = post_slug("This is a very long title that needs truncation",
                  '-', 0, 20);
    if (s) { puts(s); free(s); }            /* "this-is-a-very-long" */
    return 0;
}
```

CLI:

```bash
./c/_post_slug "Hello, World!"                  # hello-world
./c/_post_slug "Hello, World!" _ 1              # Hello_World
./c/_post_slug "A title with Ŝtřãņġę chars"    # a-title-with-strange-chars
./c/_post_slug --stdin _ < titles.txt           # one slug per line, one process
```
</details>

## 🛠️ Advanced Features

### Batch File Renaming

The included `slugify-files` utility renames files to slugs, keeping each
extension. It lists nothing in advance, but asks once for confirmation
(`-f` skips the question):

```bash
# Rename all .txt files in a directory
./slugify-files *.txt

# With custom separator and preserved case
./slugify-files -s _ -p /path/to/files/*

# Skip a file whose slug name already exists (by default it is overwritten)
./slugify-files -n *.pdf
```

The separator must be one of `- _ . + ~ , = @`. Every operand is checked
before anything is renamed, and a file whose slug names an existing
directory is skipped, not moved into it. `slugify-files --help` lists all
options.

### Command-Line Usage

The C binary installs as `post_slug`, with `slugify` as a symlink to it
(`cd c && sudo make install`). An existing `slugify` symlink is replaced; a
real file of that name, such as another package's `slugify`, is left alone,
and `make check` reports when an earlier PATH entry shadows the link. The
install also puts in a manpage, `man post_slug` (or `man slugify`). The
Bash script takes the same arguments and runs as `./post_slug.bash`.

```bash
ln -s /path/to/slugify-files /usr/local/bin/slugify-files

post_slug "My Document Title!"    # my-document-title
slugify "My Document Title!"      # my-document-title
slugify --stdin < titles.txt      # one slug per line
```

## 🔧 How It Works

The slug generation process follows these steps:

1. **Input validation** - Truncates input to 255 characters for filesystem safety
2. **Character normalization** - Applies language-specific transliteration fixes
3. **HTML entity removal** - Replaces entities like `&amp;` with the separator
4. **ASCII transliteration** - Converts Unicode to closest ASCII equivalents
5. **Quote removal** - Strips quotes, apostrophes, and backticks
6. **Case conversion** - Optionally converts to lowercase
7. **Character replacement** - Replaces non-alphanumeric chars with separator
8. **Cleanup** - Removes duplicate/leading/trailing separators
9. **Length truncation** - Optionally truncates to specified length

### Transliteration Details

Different languages use different transliteration methods:

- **Python/JavaScript**: `unicodedata.normalize('NFKD')`
- **PHP/Bash/C**: `iconv('UTF-8', 'ASCII//TRANSLIT')` (glibc)

To ensure consistency, manual transliteration tables ("kludges") handle edge cases:

```python
# Example kludges
'€' → 'EUR'  # Euro symbol
'£' → 'GBP'  # Pound sign
'©' → 'C'    # Copyright
'®' → 'R'    # Registered trademark
'™' → '-TM'  # Trademark
```

The rules every implementation follows:

- A character with no ASCII form is **deleted**, not replaced by the
  separator: `x♠y` → `xy`. This includes emoji (U+1F300–U+1FAFF), for which
  iconv would otherwise give forms such as `:-D` or `<3`.
- An HTML entity runs from `&` to the **first** `;` before a space or tab:
  `&lt;Test&gt;` → `test`.
- The 255-character input limit counts characters (code points), not bytes
  or UTF-16 units.
- Output does not depend on the locale: Bash, PHP and C run iconv under
  `C.UTF-8` and restore the caller's locale afterwards.

## 🧪 Testing

### Running Tests

```bash
# Run cross-language validation
cd unittests
./validate_slug_scripts datasets/headlines.txt

# Test with specific parameters
./validate_slug_scripts datasets/booktitles.txt 0 '-,_' '0,1'

# Quiet mode (errors only)
./validate_slug_scripts -q datasets/products.txt
```

The validator runs each implementation once per separator and case setting
(about 7 seconds for the 9,828 headlines), rebuilds the C binary when its
source has changed, and exits 1 if any slugs differ.

### Test Datasets

The package includes extensive test datasets:

- `headlines.txt` - News headlines with special characters
- `booktitles.txt` - Book titles with Unicode and punctuation
- `products.txt` - Product names with symbols and numbers
- `edge_cases.txt` - Boundary conditions and special cases

### Unit Tests

```bash
# Python unit tests
python -m pytest unittests/test_post_slug.py

# Run all language tests
python unittests/test_post_slug.py
```

## ⚠️ Important Notes

### Character Set Limitations

Some character sets cannot be transliterated to ASCII and will result in empty strings:

```python
# Cyrillic text returns empty string
post_slug("Привет мир")  # ""

# Use with Latin-based alphabets for best results
post_slug("Café résumé")  # "cafe-resume"
```

The implementations agree on every line of the test datasets, but not on
every Unicode character. Python and JavaScript transliterate with NFKD; PHP,
Bash and C with glibc iconv. About 700 of the 149,000 assigned code points
still differ between the two groups, nearly all rare: Latin letters with
hooks or strokes (`ƀ`, `ȡ`), enclosed and squared letters (`Ⓐ`, `㎂`),
mathematical brackets, and a few space characters.

Invalid UTF-8 gives an empty string in PHP, Bash and C. Python and
JavaScript never see invalid bytes: the caller decodes the text first.

### Security Considerations

- Input is automatically limited to 255 characters
- All implementations include error handling
- Safe for user-generated content
- No external command execution (except Bash `iconv`)

### Version Compatibility

| Language | Minimum Version | Tested Version |
|----------|----------------|----------------|
| Python | 3.10 | 3.12 |
| PHP | 8.0 | 8.3 |
| Bash | 5.1 | 5.2 |
| Node.js | 12.2 | 20.x |
| C | C11 + glibc iconv | gcc 13.3 / glibc 2.39 |

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

1. **Consistency is key** - Changes must be applied to all language implementations
2. **Test thoroughly** - Run `validate_slug_scripts` to ensure cross-language compatibility
3. **Update kludge tables** - Submit PRs for new transliteration cases
4. **Follow conventions** - Match the coding style of each language

### Development Setup

```bash
# Clone the repository
git clone https://github.com/Open-Technology-Foundation/post_slug.git
cd post_slug

# Run tests
cd unittests
./validate_slug_scripts datasets/headlines.txt

# Make changes and verify
# ... edit files ...
./validate_slug_scripts -q datasets/booktitles.txt
```

## 📄 License

This project is licensed under the GNU General Public License v3.0 or later - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by various slug generation libraries across different languages
- Test datasets compiled from real-world content
- Special thanks to all contributors

## 📚 See Also

- [CLAUDE.md](CLAUDE.md) - AI assistant guidelines
- [AUDIT-EVALUATE.md](AUDIT-EVALUATE.md) - Security and code quality audit
- [PURPOSE-FUNCTIONALITY-USAGE.md](docs/PURPOSE-FUNCTIONALITY-USAGE.md) - Detailed documentation

---

**Repository**: https://github.com/Open-Technology-Foundation/post_slug  
**Author**: Gary Dean <garydean@okusi.id>  
**Version**: 1.1.0