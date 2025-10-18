## Argument Validation
\`\`\`bash
noarg() { (($# > 1)) && [[ ${2:0:1} != '-' ]] || die 2 "Missing argument for option '$1'"; }
\`\`\`
