## Version Output Format

**Standard format:** \`<script_name> <version_number>\`

The \`--version\` option should output the script name followed by a space and the version number. Do **not** include the word "version" between them.

\`\`\`bash
# ✓ Correct
-V|--version)   echo "$SCRIPT_NAME $VERSION"; exit 0 ;;
# Output: myscript 1.2.3

# ✗ Wrong - do not include the word "version"
-V|--version)   echo "$SCRIPT_NAME version $VERSION"; exit 0 ;;
# Output: myscript version 1.2.3  (incorrect)
\`\`\`

**Rationale:** This format follows GNU standards and is consistent with most Unix/Linux utilities (e.g., \`bash --version\` outputs "GNU bash, version 5.2.15", not "GNU bash version version 5.2.15").
