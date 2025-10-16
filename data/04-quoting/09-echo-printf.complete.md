### Echo and Printf Statements

\`\`\`bash
# Static strings - single quotes
echo 'Installation complete'
printf '%s\n' 'Processing files'

# With variables - double quotes
echo "$SCRIPT_NAME $VERSION"
echo "Installing to $PREFIX/bin"
printf 'Found %d files in %s\n' "$count" "$dir"

# Mixed content
echo "  • Binary: $BIN_DIR/mailheader"
echo "  • Version: $VERSION (released $(date))"
\`\`\`
