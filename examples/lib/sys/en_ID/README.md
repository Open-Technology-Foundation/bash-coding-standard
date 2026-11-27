# English Locale for Indonesia (en_ID)

A locale definition for English language users in Indonesia, combining international English standards with Indonesian regional conventions.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage](#usage)
- [Testing](#testing)
- [Design Decisions](#design-decisions)
- [Building from Source](#building-from-source)
- [Uninstalling](#uninstalling)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
- [Author](#author)
- [See Also](#see-also)

## Overview

The `en_ID` locale provides English language support tailored for Indonesia. It combines:
- **British English** spelling conventions (inherited from `en_GB`)
- **Indonesian** currency format (IDR/Rp)
- **International** business standards (ISO 8601 dates, Anglo number formatting, 24-hour time)

### Who needs this?

- International businesses operating in Indonesia
- Indonesian professionals working in English
- Software systems requiring English UI with Indonesian regional settings
- Educational institutions using English as medium of instruction

## Features

| Category | Setting | Example |
|----------|---------|---------|
| **Language** | English (British spelling) | colour, centre |
| **Currency** | Indonesian Rupiah | Rp1,234,567.89 |
| **Numbers** | Decimal point, comma separator | 1,234,567.89 |
| **Date** | ISO 8601 format | 2024-01-15 |
| **DateTime** | ISO with weekday | Mon 2024-01-15 14:30:45 |
| **Time** | 24-hour default, 12-hour available | 14:30:45 / 02:30:45 PM |
| **Week** | ISO 8601 numbering, Monday start | Week 1 contains first Thursday |
| **Paper** | A4 (297×210mm) | - |
| **Measurement** | Metric | - |
| **Country Code** | +62, RI | - |

## Quick Start

Install en_ID as your system default locale with one command:

### Ubuntu/Debian
```bash
wget -O- https://raw.githubusercontent.com/Open-Technology-Foundation/en_ID/v2.3.1/install-ubuntu.sh | sudo bash
```

### Fedora/RHEL/CentOS/Rocky/AlmaLinux
```bash
wget -O- https://raw.githubusercontent.com/Open-Technology-Foundation/en_ID/v2.3.1/install-fedora.sh | sudo bash
```

### Arch Linux
```bash
curl -fsSL https://raw.githubusercontent.com/Open-Technology-Foundation/en_ID/v2.3.1/install-arch.sh | sudo bash
```

Each installer installs the release it belongs to: the script at the `v2.3.1` URL clones tag `v2.3.1`.

### Ensure Persistence (All Distributions)

If en_ID is already installed and you want to make sure it survives system updates:

```bash
wget https://raw.githubusercontent.com/Open-Technology-Foundation/en_ID/v2.3.1/ensure-persistence.sh
sudo bash ensure-persistence.sh
```

## Installation

### Automated Installation

Each installation script:
- Installs the packages it needs (`git`, `make` and the distribution's locale tools)
- Clones the release that matches the script and runs `make install-persistent`, which installs and compiles the locale and makes it survive package updates
- Backs up the existing default-locale file the first time it runs (`/etc/default/locale` on Ubuntu and Debian, `/etc/locale.conf` elsewhere)
- Sets `LANG=en_ID.UTF-8` as the system default, and adds the same line to `/etc/environment` for programs that read only that file

The default is set through `LANG` alone. Releases up to 2.2.1 also wrote twelve `LC_*` lines, and up to 2.1.0 `LC_ALL` as well; the installer removes those, so a per-category setting such as `LC_TIME` can again override the default. Running an installer twice changes nothing the second time.

To install from a fork or mirror, set `EN_ID_REPO_URL` on the `sudo` side of the pipe, because `sudo` drops variables from the calling environment:

```bash
wget -O- https://raw.githubusercontent.com/Open-Technology-Foundation/en_ID/v2.3.1/install-ubuntu.sh \
  | sudo EN_ID_REPO_URL=https://example.org/your/en_ID.git bash
```

The URL must start with `https://` (or `file:///` for a local clone), and the repository must carry the tag the script names.

### Manual Installation

You need `git`, `make` and your distribution's locale sources: `locales` on Ubuntu and Debian, `glibc-locale-source` on Fedora and RHEL (Arch's `glibc` includes them).

```bash
git clone --branch v2.3.1 https://github.com/Open-Technology-Foundation/en_ID.git
cd en_ID
sudo make install-persistent
locale -a | grep en_ID
```

`sudo make install` alone also installs the locale, but the next glibc or locale package update may remove it; see [Troubleshooting](#troubleshooting). To make en_ID the system default, see [Set as System Default](#set-as-system-default).

**Note**: Systems may display the locale as `en_ID.utf8` or `en_ID.UTF-8`. Both refer to the same locale.

## Usage

### Set as System Default
```bash
# Ubuntu/Debian
sudo update-locale LANG=en_ID.UTF-8

# Fedora/RHEL
sudo localectl set-locale LANG=en_ID.UTF-8

# Arch Linux
echo "LANG=en_ID.UTF-8" | sudo tee /etc/locale.conf
```

### Use in Current Session
```bash
export LANG=en_ID.UTF-8
export LC_ALL=en_ID.UTF-8
```

### Use for Single Application
```bash
LC_ALL=en_ID.UTF-8 your-application
```

**Important**: `LC_ALL` is best reserved for transient, per-command use (as above) — set persistently system-wide it overrides *every* per-category variable. For a lasting default, set `LANG` (plus any specific `LC_*` categories you need), which is what the installers do.

## Testing

### Run Full Test Suite

```bash
# Compile, test the build (59 tests across 12 categories), then check the scripts
make test

# Test the locale installed on this system instead of the build
make test-installed

# Test specific categories (against the build; run 'make compile' first)
./tests/test_en_ID.sh LC_TIME
./tests/test_en_ID.sh LC_TIME_EXT    # Extended: week, am_pm, datetime, 12-hour time
./tests/test_en_ID.sh LC_MONETARY
./tests/test_en_ID.sh LC_NUMERIC
./tests/test_en_ID.sh LC_MESSAGES
./tests/test_en_ID.sh LC_PAPER
./tests/test_en_ID.sh LC_ADDRESS
./tests/test_en_ID.sh LC_TELEPHONE
./tests/test_en_ID.sh LC_NAME
./tests/test_en_ID.sh LC_MEASUREMENT
./tests/test_en_ID.sh LC_CTYPE
./tests/test_en_ID.sh LC_COLLATE
```

`make test` always tests the locale compiled from this tree, even where en_ID is installed: the suite points glibc at that build through `LOCPATH`, which takes precedence over the installed locales.

The installers, `ensure-persistence.sh` and `uninstall.sh` change system files, so they are tested as root in disposable containers (Ubuntu, Debian, Fedora, Rocky Linux and Arch) by `tests/test_install.sh` in CI. To run it locally:

```bash
docker run --rm -e EN_ID_TEST_DISPOSABLE=1 -v "$PWD":/src:ro fedora:latest bash /src/tests/test_install.sh
```

### Manual Verification

```bash
# Check if installed
locale -a | grep en_ID

# Test date format (should show: 2024-01-15)
LC_ALL=en_ID.UTF-8 date +%x

# Test datetime format (should show: Mon 2024-01-15 14:30:45)
LC_ALL=en_ID.UTF-8 date -d "2024-01-15 14:30:45" +%c

# Test time format (should show: 14:30:45)
LC_ALL=en_ID.UTF-8 date +%X

# Test 12-hour format (should show: 02:30:45 PM)
LC_ALL=en_ID.UTF-8 date -d "14:30:45" +%r

# Test number formatting (thousands grouping; driven by LC_NUMERIC)
LC_NUMERIC=en_ID.UTF-8 printf "%'.2f\n" 1234567.89
# Output: 1,234,567.89

# Test full date with day name
LC_ALL=en_ID.UTF-8 date +"%x = %A, %d %B %Y"
# Output: 2024-01-15 = Monday, 15 January 2024

# Show all locale settings
LC_ALL=en_ID.UTF-8 locale
```

## Design Decisions

### LC_NAME: Minimal Definition

The LC_NAME category uses a minimal definition because Indonesian naming conventions don't map well to Western name formatting:

- **Single names** are common (Sukarno, Suharto, Junarti)
- **Name origins** vary widely (Javanese, Balinese, Chinese, Arabic)
- **Titles** like Pak/Bu are Indonesian, not English

Only `name_fmt` is defined. The salutation fields (`name_mr`, `name_ms` and the rest) are deliberately left undefined rather than guessed.

### Indonesian Standards Adopted

The en_ID locale adopts these standards from Indonesia:

- **Currency**: Indonesian Rupiah (IDR/Rp) with standard positioning
- **Country Codes**: ID (alpha-2), IDN (alpha-3), 360 (numeric), RI (vehicle registration)
- **Telephone**: +62 country code, international access through the operator prefixes 001, 007, 008 and 009 (as in glibc's `id_ID`), domestic format with area codes
- **Address**: Indonesian postal format with full country and language metadata
- **Paper Size**: A4 (297×210mm)
- **Measurement**: Metric system
- **Week Start**: Monday (ISO 8601 week numbering)

### International Standards Used

Rather than traditional Indonesian formats, en_ID uses:
- **Dates**: ISO 8601 (YYYY-MM-DD) instead of Indonesian DD/MM/YYYY
- **DateTime**: ISO 8601 date with weekday prefix (Mon 2024-01-15 14:30:45)
- **Time**: 24-hour format by default; 12-hour format available via `%r` for compatibility
- **Week Numbering**: ISO 8601 (week 1 contains the first Thursday)
- **Numbers**: Anglo format (1,234.56) instead of Indonesian (1.234,56)
- **Language**: English (inherited from en_GB)

This design prioritizes international compatibility for English-language business and technical contexts.

### British vs American English

British English was chosen because:
- It's the standard in Indonesian education
- Used by neighboring Singapore and Malaysia
- Common in Commonwealth countries

### Modern UTF-8 Format

The locale definition uses direct UTF-8 text format instead of legacy Unicode code points:
- **Direct text**: `currency_symbol "Rp"` instead of `<U0052><U0070>`
- **Improved readability**: Day names like `"Monday"` are immediately recognizable
- **Easier maintenance**: No need to look up Unicode tables
- **Consistent with modern locales**: Follows the same format as en_GB, en_US, etc.

### Locale Categories Reference

| Category | Description |
|----------|-------------|
| LC_CTYPE | Character classification (inherited from en_GB) |
| LC_COLLATE | String collation order (ISO 14651) |
| LC_MONETARY | Currency: IDR/Rp, decimal point, comma grouping |
| LC_NUMERIC | Numbers: decimal point, comma separator |
| LC_TIME | Date/time: ISO 8601, 24h default, 12h available, ISO week numbering |
| LC_MESSAGES | Yes/no expressions (inherited from en_GB) |
| LC_PAPER | A4 paper size (297x210mm) |
| LC_NAME | Minimal name formatting for English contexts |
| LC_ADDRESS | Indonesian country codes (ID, IDN, RI), English language codes |
| LC_TELEPHONE | +62 prefix, operator access codes 001/007/008/009, domestic format |
| LC_MEASUREMENT | Metric system |

## Building from Source

```bash
# Clone the repository
git clone https://github.com/Open-Technology-Foundation/en_ID.git
cd en_ID

# Check syntax and compile
make

# Run tests
make test

# Install system-wide (requires sudo)
sudo make install

# Install with persistence (prevents removal on system updates)
sudo make install-persistent

# Uninstall the locale and revert the system default
sudo make uninstall

# Clean build artifacts
make clean

# Show available make targets
make help

# Display locale information
make info
```

## Uninstalling

From a clone of the repository:

```bash
sudo make uninstall
```

The one-line installers keep no clone; download the uninstaller instead:

```bash
curl -fsSLO https://raw.githubusercontent.com/Open-Technology-Foundation/en_ID/v2.3.1/uninstall.sh
sudo bash uninstall.sh
```

`uninstall.sh` reverts what the installers changed:

- restores the default-locale file from the backup the installer made, or sets `LANG=C.UTF-8` where there is no backup. A default you have changed since the install no longer names en_ID, so it is left alone, and so is its backup
- removes the en_ID lines from `/etc/environment` and `/etc/locale.gen`
- deletes the compiled locale, its source, and any package-manager hook files left by releases up to 2.2.1

It leaves `/etc/ssh/sshd_config` alone. Releases up to 2.2.1 may have appended `AcceptEnv LANG LC_*` to it; most distributions ship that line anyway. Log out and back in afterwards.

## Troubleshooting

### Locale disappears after system updates

An error such as `cannot change locale (en_ID.UTF-8): No such file or directory` after an update means the compiled locale was removed. Updates to glibc or the locale packages rebuild the compiled locales, and en_ID survives only where the system knows to rebuild or keep it:

- **Debian, Ubuntu, Arch**: en_ID is listed in `/etc/locale.gen`. The `locales` package (Debian, Ubuntu) and the `glibc` package (Arch) rebuild every locale listed there.
- **Fedora, RHEL**: en_ID is compiled as a directory, `/usr/lib/locale/en_ID.utf8`. Updates replace the packaged locale archive but leave the directory alone.
- **Debian and Ubuntu with `locales-all`**, which deletes the locale archive on every update, or with `/etc/locale.gen` linked to the packaged list of all locales: en_ID is compiled as a directory as well, as on Fedora.

The installers set this up. For an installation made by hand, or by a release before 2.3.0, run this from a clone:

```bash
sudo make install-persistent
```

It also deletes the package-manager hooks that releases up to 2.2.1 created, none of which ever regenerated the locale, and recompiles en_ID if it has already gone.

### Locale not taking effect

If you've installed the locale but it's not taking effect:

1. **Log out and log back in** - Session variables need to be reloaded
2. **For SSH sessions** - Disconnect and reconnect. Your SSH client may send its own `LANG` and `LC_*` values; the server uses them instead of its default when its `sshd_config` has `AcceptEnv LANG LC_*`, which most distributions ship
3. **Check your shell configuration** - Ensure no conflicting LANG/LC_* variables in `~/.bashrc` or `~/.profile`
4. **Verify with**: `locale` command should show en_ID.UTF-8

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes to `localedata/en_ID`
4. Run `make test` to verify your changes
5. Submit a pull request

### Reporting Issues

Please report bugs or suggestions via [GitHub Issues](https://github.com/Open-Technology-Foundation/en_ID/issues).

## License

Copyright (C) 2024 Yayasan Teknologi Terbuka Indonesia

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

The full licence text is in [LICENSE](LICENSE).

## Author

Created and maintained by [Yayasan Teknologi Terbuka Indonesia](https://yatti.id) (Indonesian Open Technology Foundation).

Contact: admin@yatti.id

## See Also

- [GNU C Library Locales](https://www.gnu.org/software/libc/manual/html_node/Locales.html)
- [ISO 639 Language Codes](https://www.loc.gov/standards/iso639-2/)
- [ISO 3166 Country Codes](https://www.iso.org/iso-3166-country-codes.html)
- [Unicode CLDR](http://cldr.unicode.org/)
