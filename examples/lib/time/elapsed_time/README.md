# elapsed_time

Utility functions for formatting elapsed time durations in a human-readable format. Available in both Python and Bash.

```bash
git clone https://github.com/Open-Technology-Foundation/elapsed_time.git && cd elapsed_time && sudo make install
```

## Features

- Format time durations with intelligent unit display
- Automatically shows/hides days, hours, minutes based on duration
- Always displays seconds with millisecond precision
- Zero dependencies in both implementations
- Can be imported as a module or used directly

## Usage

### Python

```python
import time
from elapsed_time import elapsed_time

# Start timing
start = time.perf_counter()

# Do something...
time.sleep(1.5)  # Simulate work

# Print elapsed time
print(elapsed_time(start))  # Output: "1.500s"

# Or with explicit start/end times
print(elapsed_time(0, 3661.123))  # Output: "01h 01m 1.123s"
```

### Bash

Requires Bash 5.0+ (uses `$EPOCHREALTIME`).

```bash
# As a script
elapsed_time 0 3661.123           # Output: "01h 01m 1.123s"
elapsed_time --version             # Output: "elapsed_time 1.2.0"

# As a sourced function
source elapsed_time

start=$EPOCHREALTIME
sleep 1.5
elapsed_time "$start"              # Output: "1.500s"

# Explicit start/end
elapsed_time 0 90061.456           # Output: "1d 01h 01m 1.456s"
```

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show usage |
| `-V`, `--version` | Show version |

## Installation

```bash
git clone https://github.com/Open-Technology-Foundation/elapsed_time.git
cd elapsed_time
sudo make install
```

For user-local install (no sudo):

```bash
make install-user
```

Run `make help` to see all targets.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

