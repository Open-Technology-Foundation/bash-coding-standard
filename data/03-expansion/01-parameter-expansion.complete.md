### Parameter Expansion
```bash
SCRIPT_NAME=${SCRIPT_PATH##*/} # Remove longest prefix pattern
SCRIPT_DIR=${SCRIPT_PATH%/*}   # Remove shortest suffix pattern
${var:-default}                # Default value
${var:0:1}                     # Substring
${#array[@]}                   # Array length
${var,,}                       # Lowercase conversion
"${@:2}"                       # All args starting from 2nd
```
