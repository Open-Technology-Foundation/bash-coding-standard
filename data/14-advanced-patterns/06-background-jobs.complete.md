## Background Job Management

Managing background processes and jobs.

\`\`\`bash
# Start background job and track PID
long_running_command &
PID=$!

# Check if process is still running
if kill -0 "$PID" 2>/dev/null; then
  info "Process $PID is still running"
fi

# Wait with timeout
if timeout 10 wait "$PID"; then
  success 'Process completed successfully'
else
  warn 'Process timed out or failed'
  kill "$PID" 2>/dev/null || true
fi

# Multiple background jobs
declare -a PIDS=()
for file in *.txt; do
  process_file "$file" &
  PIDS+=($!)
done

# Wait for all background jobs
for pid in "${PIDS[@]}"; do
  wait "$pid"
done

# Job control with error handling
run_with_timeout() {
  local -i timeout="$1"; shift
  local -- command="$*"

  timeout "$timeout" bash -c "$command" &
  local -i pid=$!

  if wait "$pid"; then
    return 0
  else
    local -i exit_code=$?
    if ((exit_code == 124)); then
      error "Command timed out after ${timeout}s"
    fi
    return "$exit_code"
  fi
}
\`\`\`
