### STDOUT vs STDERR
- All error messages should go to \`STDERR\`
- Place \`>&2\` at the *beginning* commands for clarity

\`\`\`bash
# Preferred format
somefunc() {
  >&2 echo "[$(date -Ins)]: $*"
}

# Also acceptable
somefunc() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}
\`\`\`
