## Wildcard Expansion
Always use explicit path when doing wildcard expansion to avoid issues with filenames starting with \`-\`.

\`\`\`bash
# ✓ Correct - explicit path prevents flag interpretation
rm -v ./*
for file in ./*.txt; do
  process "$file"
done

# ✗ Incorrect - filenames starting with - become flags
rm -v *
\`\`\`
