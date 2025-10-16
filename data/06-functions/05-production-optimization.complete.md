### Production Script Optimization
Once a script is mature and ready for production:
- Remove unused utility functions (e.g., if `yn()`, `decp()`, `trim()`, `s()` are not used)
- Remove unused global variables (e.g., `PROMPT`, `DEBUG` if not referenced)
- Remove unused messaging functions that your script doesn't call
- Keep only the functions and variables your script actually needs
- This reduces script size, improves clarity, and eliminates maintenance burden

Example: A simple script may only need `error()` and `die()`, not the full messaging suite.
