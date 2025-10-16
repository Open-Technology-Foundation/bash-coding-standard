### Readonly Declaration
Use `readonly` for constants to prevent accidental modification.

```bash
readonly -a REQUIRED=(pandoc git md2ansi)
#shellcheck disable=SC2155 # acceptable; if realpath fails then we have much bigger problems
readonly -- SCRIPT_PATH="$(realpath -- "$0")"
```
