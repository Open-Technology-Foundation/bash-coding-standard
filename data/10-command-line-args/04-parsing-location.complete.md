### Argument Parsing Location

**Recommendation:** Place argument parsing inside the \`main()\` function rather than at the top level.

**Benefits:**
- Better testability (can test \`main()\` with different arguments)
- Cleaner variable scoping (parsing vars are local to \`main()\`)
- Encapsulation (argument handling is part of main execution flow)
- Easier to mock/test in unit tests

\`\`\`bash
# Recommended: Parsing inside main()
main() {
  # Parse command-line arguments
  while (($#)); do
    case $1 in
      --builtin)    INSTALL_BUILTIN=1
                    BUILTIN_REQUESTED=1
                    ;;
      --no-builtin) SKIP_BUILTIN=1
                    ;;
      --prefix)     shift
                    PREFIX="$1"
                    # Update derived paths
                    BIN_DIR="$PREFIX"/bin
                    LOADABLE_DIR="$PREFIX"/lib/bash/loadables
                    ;;
      -h|--help)    show_help
                    exit 0
                    ;;
      -*)           die 22 "Invalid option '$1'"
                    ;;
      *)            >&2 show_help
                    die 2 "Unknown option '$1'"
                    ;;
    esac
    shift
  done

  # Proceed with main logic
  check_prerequisites
  build_components
  install_components
}

main "$@"
#fin
\`\`\`

**Alternative:** For very simple scripts (< 40 lines) without a \`main()\` function, top-level parsing is acceptable:

\`\`\`bash
#!/bin/bash
set -euo pipefail

# Simple scripts can parse at top level
while (($#)); do case $1 in
  -v|--verbose) VERBOSE=1 ;;
  -h|--help)    show_help; exit 0 ;;
  -*)           die 22 "Invalid option '$1'" ;;
  *)            FILES+=("$1") ;;
esac; shift; done

# Rest of simple script logic
\`\`\`
