## Naming Conventions

Follow these naming conventions to maintain consistency and avoid conflicts with shell built-ins.

| Type | Convention | Example |
|------|------------|---------|
| Constants | UPPER_CASE | `readonly MAX_RETRIES=3` |
| Global variables | UPPER_CASE or CamelCase | `VERBOSE=1` or `ConfigFile='/etc/app.conf'` |
| Local variables | lower_case with underscores | `local file_count=0` |
|  | CamelCase acceptable for important locals | `local ConfigData` |
| Internal/private functions | prefix with _ | `_validate_input()` |
| Environment variables | UPPER_CASE with underscores | `export DATABASE_URL` |

**Examples:**
```bash
# Constants
readonly -- SCRIPT_VERSION='1.0.0'
readonly -- MAX_CONNECTIONS=100

# Global variables
declare -i VERBOSE=1
declare -- ConfigFile='/etc/myapp.conf'

# Local variables
process_data() {
  local -i line_count=0
  local -- temp_file
  local -- CurrentSection  # CamelCase for important variable
}

# Private functions
_internal_helper() {
  # Used only by other functions in this script
}
```

**Rationale:**
- **UPPER_CASE for globals/constants**: Immediately visible as script-wide scope, matches shell conventions
- **lower_case for locals**: Distinguishes from globals, prevents accidental shadowing
- **Underscore prefix for private functions**: Signals "internal use only", prevents namespace conflicts
- **Avoid lowercase single-letter names**: Reserved for shell (`a`, `b`, `n`, etc.)
- **Avoid all-caps shell variables**: Don't use `PATH`, `HOME`, `USER`, etc. as your variable names
