### Environment Variable Best Practices

Proper handling of environment variables.

\`\`\`bash
# Required environment validation (script exits if not set)
: "${REQUIRED_VAR:?Environment variable REQUIRED_VAR not set}"
: "${DATABASE_URL:?DATABASE_URL must be set}"

# Optional with defaults
: "${OPTIONAL_VAR:=default_value}"
: "${LOG_LEVEL:=INFO}"

# Export with validation
export DATABASE_URL="${DATABASE_URL:-localhost:5432}"
export API_KEY="${API_KEY:?API_KEY environment variable required}"

# Check multiple required variables
declare -a REQUIRED=(DATABASE_URL API_KEY SECRET_TOKEN)
#...
check_required_env() {
  local -- var
  for var in "${REQUIRED[@]}"; do
    [[ -n "${!var:-}" ]] || {
      error "Required environment variable '$var' not set"
      return 1
    }
  done
  return 0
}
\`\`\`
