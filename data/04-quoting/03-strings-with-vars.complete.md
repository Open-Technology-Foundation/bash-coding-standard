## Strings with Variables

Use double quotes when the string contains variables that need expansion:

```bash
# Message functions with variables
die 1 "Unknown option '$1'"
error "'$compiler' not found"
info "Installing to $PREFIX/bin"
success "Processed $count files"

# Echo statements with variables
echo "$SCRIPT_NAME $VERSION"
echo "Binary: $BIN_DIR/mailheader"
echo "Completion: $COMPLETION_DIR/mail-tools"

# Multi-line messages with variables
info '[DRY-RUN] Would install:' \
     "  $BIN_DIR/mailheader" \
     "  $BIN_DIR/mailmessage" \
     "  $LIB_DIR/mailheader.so"
```
