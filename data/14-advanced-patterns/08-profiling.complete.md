## Performance Profiling

Simple performance measurement patterns.

\`\`\`bash
# Using SECONDS builtin
profile_operation() {
  local -- operation="$1"
  SECONDS=0

  # Run operation
  eval "$operation"

  info "Operation completed in ${SECONDS}s"
}

# High-precision timing with EPOCHREALTIME
timer() {
  local -- start end runtime
  start=$EPOCHREALTIME

  "$@"

  end=$EPOCHREALTIME
  runtime=$(awk "BEGIN {print $end - $start}")
  info "Execution time: ${runtime}s"
}
\`\`\`
