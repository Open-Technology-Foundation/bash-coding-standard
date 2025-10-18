## Shebang and Initial Setup
First lines of all scripts must include a `#!shebang`, global `#shellcheck` definitions (optional), a brief description of the script, and first command `set -euo pipefail`.

```bash
#!/bin/bash
#shellcheck disable=SC1090,SC1091
# Get directory sizes and report usage statistics
set -euo pipefail
```

**Allowable shebangs:**

1. `#!/bin/bash` - **Most portable**, works on most Linux systems
   - Use when: Script will run on known Linux systems with bash in standard location

2. `#!/usr/bin/bash` - **FreeBSD/BSD systems**
   - Use when: Targeting BSD systems where bash is in /usr/bin

3. `#!/usr/bin/env bash` - **Maximum portability**
   - Use when: Bash location varies (different systems, development environments)
   - Searches PATH for bash, works across diverse environments

**Rationale:** These three shebangs cover all common scenarios while maintaining compatibility. The first command must be `set -euo pipefail` to enable strict error handling immediately, before any other commands execute.
