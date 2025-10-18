## Summary Reference

| Content Type | Quote Style | Example |
|--------------|-------------|---------|
| Static string | Single \`'...'\` | \`info 'Starting process'\` |
| One-word literal (assignment) | Optional quotes | \`VAR=value\` or \`VAR='value'\` |
| One-word literal (conditional) | Optional quotes | \`[[ $x == value ]]\` or \`[[ $x == 'value' ]]\` |
| String with variable | Double \`"..."\` | \`info "Processing $file"\` |
| Variable in string | Double \`"..."\` | \`echo "Count: $count"\` |
| Literal quotes in string | Double with nested single | \`die 1 "Unknown '$1'"\` |
| Command substitution | Double \`"..."\` | \`echo "Time: $(date)"\` |
| Variables in conditionals | Double \`"$var"\` | \`[[ -f "$file" ]]\` |
| Static in conditionals | Single \`'...'\` or unquoted | \`[[ "$x" == 'value' ]]\` or \`[[ "$x" == value ]]\` |
| Array expansion | Double \`"${arr[@]}"\` | \`for i in "${arr[@]}"\` |
| Here doc (no expansion) | Single on delimiter | \`cat <<'EOF'\` |
| Here doc (with expansion) | No quotes on delimiter | \`cat <<EOF\` |
