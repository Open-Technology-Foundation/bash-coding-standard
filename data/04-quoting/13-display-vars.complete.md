## Display Declared Variables
\`\`\`bash
decp() { declare -p "$@" | sed 's/^declare -[a-zA-Z-]* //'; }
\`\`\`
