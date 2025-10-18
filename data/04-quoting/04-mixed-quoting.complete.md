## Mixed Quoting

When a string contains both static text and variables, use double quotes with single quotes nested for literal protection:

```bash
# Protect literal quotes around variables
die 2 "Unknown option '$1'"              # Single quotes are literal
die 1 "'gcc' compiler not found."        # 'gcc' shows literally with quotes
warn "Cannot access '$file_path'"        # Path shown with quotes

# Complex messages
info "Would remove: '$old_file' → '$new_file'"
error "Permission denied for directory '$dir_path'"
```
