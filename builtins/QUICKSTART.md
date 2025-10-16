# Bash Loadable Builtins - Quick Start

## Installation (Choose One)

### Option 1: User Installation (No Root Required)
```bash
./install.sh --user
source ~/.config/bash-builtins/bash-builtins-loader.sh ~/.config/bash-builtins
```

### Option 2: System-Wide Installation (Requires Root)
```bash
sudo ./install.sh --system
source /etc/profile.d/bash-builtins.sh
```

## Verify Installation

```bash
check_builtins
```

Expected output:
```
✓ basename (builtin)
✓ dirname (builtin)
✓ realpath (builtin)
✓ head (builtin)
✓ cut (builtin)

Summary: 5/5 loaded as builtins
```

## Common Commands

```bash
# Check if installed
check_builtins

# Reload builtins
reload_builtins

# Run tests
make test

# Uninstall
./uninstall.sh --user              # User installation
sudo ./uninstall.sh --system       # System installation
```

## Troubleshooting

**Builtins not found?**
```bash
# Install bash-builtins package first
sudo apt-get install bash-builtins build-essential

# Then try again
./install.sh --user
```

**Not working in current shell?**
```bash
# For user installation
source ~/.config/bash-builtins/bash-builtins-loader.sh ~/.config/bash-builtins

# For system installation
source /etc/profile.d/bash-builtins.sh
```

## What You Get

- **basename** - 20x faster than external command
- **dirname** - No more fork/exec overhead
- **realpath** - Instant path resolution
- **head** - Built-in file reading
- **cut** - Lightning-fast field extraction

All automatically available in every new bash session!

## Next Steps

- Read [README.md](README.md) for complete documentation
- See [CREATING-BASH-BUILTINS.md](CREATING-BASH-BUILTINS.md) to create your own
- Run `make help` for all build options
