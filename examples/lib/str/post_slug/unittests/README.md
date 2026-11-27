# post_slug Testing Suite

Tests for the five post_slug implementations: Python, JavaScript, PHP, Bash
and C.

## Cross-Language Validation (`validate_slug_scripts`)

Checks that every available implementation gives the same slug for each line
of a text file, for each separator and case setting.

```bash
./validate_slug_scripts datasets/headlines.txt
./validate_slug_scripts -q datasets/booktitles.txt       # report mismatches only
./validate_slug_scripts datasets/products.txt 0 '-' 1    # max_len 0, sep '-', preserve case
./validate_slug_scripts datasets/booktitles.txt 0 '_,-,|' 0,1
```

Arguments are positional: `textfile [max_len [seps [cases]]]`. Separators
default to `_,-` and case settings to `0,1`. Each implementation starts once
per combination and reads every line from stdin, so a full run over the
9,828 headlines takes about 7 seconds. The C binary is rebuilt with
`make build` first when its source has changed.

Exit status: 0 when all slugs agree, 1 when any differ (each mismatch is
reported on stderr with every implementation's slug), 2 for a usage error,
3 when the text file is missing, and 22 for an invalid argument. Run from a
terminal, it offers to open the text file in `$EDITOR` at each mismatching
line.

## Command-Line Drivers (`_post_slug.*`)

One small driver per interpreted language. Each loads its module the
documented way (`import`, `require`, `require_once`, `source`) and takes the
same arguments as the C binary:

```bash
./_post_slug.py "Barnes &amp; Noble"        # barnes-noble
./_post_slug.js "Test Case" .               # test.case
./_post_slug.php "Hello, World!" _ 1        # Hello_World
./_post_slug.sh --stdin - 0 0 < datasets/edge_cases.txt   # one slug per line
```

`--stdin` prints exactly one line per input line, empty lines included. The
validator and the unit tests both use these drivers; `../c/_post_slug` is
the C equivalent.

## Unit Tests (`test_post_slug.py`)

Each test runs every implementation on one input and checks that all give
the expected slug. The C binary takes part once built (`cd ../c && make build`).

```bash
python3 -m pytest test_post_slug.py
python3 test_post_slug.py
```

They cover the 255-character limit (in characters, including multibyte and
emoji input), HTML entities, the deletion of characters with no ASCII form,
separators, case preservation, locale independence, invalid UTF-8, and
real-world titles.

## Test Datasets

In `datasets/`:

- **headlines.txt** - News headlines with currency symbols, punctuation and
  double-encoded (mojibake) text
- **booktitles.txt** - Book titles with international characters and complex
  punctuation
- **products.txt** - Product names with technical specifications
- **edge_cases.txt** - The 255-character limit, HTML entities, non-Latin
  scripts, regex metacharacters, empty and whitespace strings

To add a case, add a line to the dataset that fits it, or a method to
`test_post_slug.py`.

## Known Limitations

- Non-Latin scripts (Cyrillic, Chinese, Arabic) give an empty slug.
- The implementations agree on every dataset line, but Python and JavaScript
  (NFKD) and PHP, Bash and C (glibc iconv) still differ on about 700 rare
  Unicode characters. See the main README.
