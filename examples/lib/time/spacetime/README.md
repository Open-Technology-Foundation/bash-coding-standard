# spacetime

Time formatting utility with template placeholder support for Bash, PHP, and Python.

## Usage

### Bash

```bash
# Direct execution
./spacetime
# Output: Monday 2026-04-06 14:23:45 +0700 Asia/Jakarta

./spacetime "{{date}} at {{time}}"
# Output: 2026-04-06 at 14:23:45

# Get help
./spacetime --help

# Source as function
source spacetime
spacetime "Log: {{dow}} {{date}} {{time}}"
echo "$EPOCHSPACETIME"  # Access stored result
```

### PHP

```php
require_once 'spacetime.php';

echo spacetime();
// Output: Monday 2026-04-06 14:23:45 +0700 Asia/Jakarta

echo spacetime("{{date}} at {{time}}");
// Output: 2026-04-06 at 14:23:45

// Access stored result
echo $GLOBALS['EPOCHSPACETIME'];
```

**Direct execution:**
```bash
php spacetime.php
php spacetime.php "{{date}} at {{time}}"
php spacetime.php --help
```

### Python

```python
import spacetime

print(spacetime.spacetime())
# Output: Monday 2026-04-06 14:23:45 +0700 Asia/Jakarta

print(spacetime.spacetime("{{date}} at {{time}}"))
# Output: 2026-04-06 at 14:23:45

# Access stored result
print(spacetime.EPOCHSPACETIME)
```

**Direct execution:**
```bash
./spacetime.py
./spacetime.py "{{date}} at {{time}}"
./spacetime.py --help
```

Requires Python 3.12+ (stdlib only — no external dependencies).

## Placeholders

- `{{dow}}` - Day of week (e.g., Monday)
- `{{date}}` - Date in YYYY-MM-DD format
- `{{time}}` - Time in HH:MM:SS format
- `{{tz}}` - Timezone offset (e.g., +0000)
- `{{timezone}}` - Timezone name (e.g., UTC, America/New_York)

## Features

- **Template support**: Custom formatting with placeholder replacement
- **TZ env var**: Honours `TZ` environment variable (including `TZ=''` for UTC)
- **Timezone caching**: System timezone is cached on first call for performance
- **Global storage**: Result stored in `EPOCHSPACETIME` (Bash), `$GLOBALS['EPOCHSPACETIME']` (PHP), or `spacetime.EPOCHSPACETIME` (Python)
- **Version/help flags**: All implementations support `-V`/`--version` and `-h`/`--help`
- **Dash-leading templates**: a template beginning with `-` must follow `--` (`./spacetime -- "-{{date}}"`); any other `-*` argument is rejected as an invalid option (exit 22). Identical across all implementations
- **Dual usage**: Bash script can be sourced as a function; Python file can be imported as a module; both can also be executed directly

## Environment

Set the `TZ` environment variable to override the system timezone:

```bash
TZ=America/New_York ./spacetime
TZ=UTC ./spacetime "{{timezone}} {{time}}"
TZ='' ./spacetime                          # POSIX: empty TZ means UTC
```

## Files

- `spacetime` - Main Bash script (executable or sourceable)
- `spacetime.php` - PHP implementation
- `spacetime.py` - Python implementation (importable module or executable)

#fin