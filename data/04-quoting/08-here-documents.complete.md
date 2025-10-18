## Here Documents

Use appropriate quoting for here documents based on whether expansion is needed:

\`\`\`bash
# No expansion - single quotes on delimiter
cat <<'EOF'
This text is literal.
$VAR is not expanded.
$(command) is not executed.
EOF

# With expansion - no quotes on delimiter
cat <<EOF
Script: $SCRIPT_NAME
Version: $VERSION
Time: $(date)
EOF

# With expansion - double quotes on delimiter (same as no quotes)
cat <<"EOF"     # Note: double quotes same as no quotes for here docs
Script: $SCRIPT_NAME
EOF
\`\`\`
