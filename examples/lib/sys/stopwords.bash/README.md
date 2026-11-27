# Stopwords Filter

A fast, multilingual text processing utility that filters stopwords from input text. Supports 32 languages with efficient O(1) lookup using Bash associative arrays.

> **Note:** For documents > 2,000 words, consider the **[Python implementation](https://github.com/Open-Technology-Foundation/stopwords)** which offers superior performance on larger datasets. Both use the same NLTK stopwords data.

## Features

- **Multilingual Support**: Filter stopwords in 32 different languages
- **Multiple Output Formats**: Single-line, list, or word frequency counts
- **Flexible Input**: Accept text via command-line arguments or stdin
- **Punctuation Control**: Optionally preserve or remove punctuation marks
- **Case-Insensitive**: Matches stopwords regardless of case
- **Fast Performance**: O(1) stopword lookup using associative arrays
- **Dual Usage**: Use as a standalone script or source as a Bash function

## Installation

### Quick Install

One line, system-wide:
```bash
git clone --depth 1 https://github.com/Open-Technology-Foundation/stopwords.bash && sudo stopwords.bash/install.sh
```

Or for your user only, without sudo:
```bash
git clone --depth 1 https://github.com/Open-Technology-Foundation/stopwords.bash && PREFIX=$HOME/.local stopwords.bash/install.sh
```

This installs the script to `$PREFIX/bin/stopwords` and stopwords data to `$PREFIX/share/stopwords/` (32 languages, ~170KB). NLTK is not needed: the bundled data is always installed, and the script uses it first.

Or skip installing altogether: run `stopwords.bash/stopwords` straight from the clone; it finds the bundled `stopwords_data/` beside itself.

### Upgrade, Verify & Uninstall

Keep the `stopwords.bash` directory; these commands run from the directory that contains it. For a user install, put `PREFIX=$HOME/.local` in front of each instead of `sudo`.

```bash
# Upgrade
git -C stopwords.bash pull && sudo stopwords.bash/install.sh

# Verify installation
stopwords.bash/install.sh check

# Uninstall
sudo stopwords.bash/install.sh uninstall
```

## Usage

### Basic Filtering

```bash
./stopwords 'the quick brown fox jumps over the lazy dog'
# Output: quick brown fox jumps lazy dog
```

### Reading from stdin

```bash
echo 'the quick brown fox' | ./stopwords
cat document.txt | ./stopwords
```

### Language Selection (`-l`)

```bash
./stopwords -l spanish 'el rápido zorro marrón salta sobre el perro perezoso'
# Output: rápido zorro marrón salta perro perezoso
```

### Punctuation Preservation (`-p`)

```bash
./stopwords 'Hello, world!'      # Output: hello world
./stopwords -p 'Hello, world!'   # Output: hello, world!
```

### List Output (`-w`)

```bash
./stopwords -w 'the quick brown fox'
# Output:
# quick
# brown
# fox
```

### Word Frequency Counting (`-c`)

```bash
./stopwords -c 'the fox jumps and the fox runs'
# Output:
# 1 jumps
# 1 runs
# 2 fox

./stopwords -c < document.txt
```

## Supported Languages

albanian, arabic, azerbaijani, basque, belarusian, bengali, catalan, chinese, danish, dutch, english, finnish, french, german, greek, hebrew, hinglish, hungarian, indonesian, italian, kazakh, nepali, norwegian, portuguese, romanian, russian, slovene, spanish, swedish, tajik, tamil, turkish

## Command-Line Options

| Option | Long Form | Description |
|--------|-----------|-------------|
| `-l LANG` | `--language LANG` | Set the language for stopwords (default: english) |
| `-p` | `--keep-punctuation` | Keep punctuation marks (default: remove) |
| `-w` | `--list-words` | Output filtered words as a list (one per line) |
| `-c` | `--count` | Output word frequency counts (sorted ascending) |
| `-V` | `--version` | Show version information |
| `-h` | `--help` | Show help message |

## Using as a Sourced Function

```bash
source stopwords
stopwords 'the quick brown fox'           # Output: quick brown fox
stopwords -l spanish 'el rápido zorro'    # Output: rápido zorro
```

## Practical Examples

```bash
# Extract keywords from a document
cat article.txt | ./stopwords -w | sort | uniq

# Find most common words
./stopwords -c < article.txt | tail -20

# Clean search queries
echo "how to install python on ubuntu" | ./stopwords
# Output: install python ubuntu

# Batch preprocessing
for file in corpus/*.txt; do
  ./stopwords < "$file" > "processed/$(basename "$file")"
done
```

## Exit Codes

- `0`: Success
- `1`: Internal failure (punctuation stripping)
- `2`: Missing argument for option
- `3`: Data directory or stopwords file not found
- `22`: Invalid option

## Troubleshooting

**Stopwords data not found?**

The script uses the first of these locations that exists. The bundled data comes first; NLTK data is optional, used only when no bundled data is found:
1. `<prefix>/share/stopwords/`, where the script is installed as `<prefix>/bin/stopwords` (bundled data, as installed)
2. `stopwords_data/` beside the script (a checkout)
3. `/usr/local/share/stopwords/`
4. `/usr/share/stopwords/` (installs before this layout)
5. `$NLTK_DATA/corpora/stopwords/` (optional NLTK data)
6. `/usr/share/nltk_data/corpora/stopwords/` (optional system NLTK data)

Symlinks to the script are resolved first, so a link in another directory still finds the data.

Solutions:
```bash
# Install this package, which includes the data
sudo ./install.sh install

# OR point NLTK_DATA at existing NLTK data
# (python -m nltk.downloader stopwords puts it in ~/nltk_data)
export NLTK_DATA=$HOME/nltk_data
```

**User-local install not in PATH?**
```bash
# Add to ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"
```

## License

GPL-3. See [LICENSE](LICENSE)

## Contributing

Contributions welcome! Submit issues or pull requests on GitHub.

## Acknowledgments

Stopword lists sourced from the [NLTK corpus](https://www.nltk.org/).
