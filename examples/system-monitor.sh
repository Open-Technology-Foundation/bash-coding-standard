#!/usr/bin/env bash
# System monitoring script - demonstrates BCS patterns
# Real-world example: Monitor system resources and generate alerts

set -euo pipefail
shopt -s inherit_errexit shift_verbose nullglob

# Script metadata
declare -x VERSION='1.0.0'
SCRIPT_PATH=$(realpath -- "${BASH_SOURCE[0]}")
SCRIPT_DIR=${SCRIPT_PATH%/*}
SCRIPT_NAME=${SCRIPT_PATH##*/}
readonly -- VERSION SCRIPT_PATH SCRIPT_DIR SCRIPT_NAME

# Configuration
declare -i CPU_THRESHOLD=80 MEM_THRESHOLD=80 DISK_THRESHOLD=90
declare -i CHECK_INTERVAL=5 MAX_ITERATIONS=12
declare -- LOG_FILE='/var/log/system-monitor.log'
declare -- ALERT_EMAIL=''

# Global variables
declare -i VERBOSE=1 DEBUG=0 CONTINUOUS=0 ALERT_MODE=0
declare -i ITERATION=0

# Colors (conditional on TTY)
if [[ -t 1 && -t 2 ]]; then
  declare -- RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m'
  declare -- CYAN=$'\033[0;36m' MAGENTA=$'\033[0;35m' BOLD=$'\033[1m' NC=$'\033[0m'
else
  declare -- RED='' GREEN='' YELLOW='' CYAN='' MAGENTA='' BOLD='' NC=''
fi
readonly -- RED GREEN YELLOW CYAN MAGENTA BOLD NC

# Messaging functions
_msg() {
  local -- prefix="$SCRIPT_NAME:" msg
  case ${FUNCNAME[1]} in
    vecho)   ;;
    info)    prefix+=" ${CYAN}◉${NC}" ;;
    warn)    prefix+=" ${YELLOW}⚡${NC}" ;;
    success) prefix+=" ${GREEN}✓${NC}" ;;
    error)   prefix+=" ${RED}✗${NC}" ;;
    alert)   prefix+=" ${MAGENTA}⚠${NC}" ;;
    debug)   prefix+=" ${BOLD}DEBUG:${NC}" ;;
    *)       ;;
  esac
  for msg in "$@"; do printf '%s %s\n' "$prefix" "$msg"; done
}

vecho() { ((VERBOSE)) || return 0; _msg "$@"; }
info() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
warn() { >&2 _msg "$@"; }
success() { ((VERBOSE)) || return 0; >&2 _msg "$@"; }
error() { >&2 _msg "$@"; }
alert() { >&2 _msg "$@"; }
debug() { ((DEBUG)) || return 0; >&2 _msg "$@"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

# Log to file
log_msg() {
  local -- timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $*" >> "$LOG_FILE"
}

# Usage
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

System resource monitoring with threshold-based alerts.

OPTIONS:
  -h, --help              Show this help message
  -v, --verbose           Verbose output (default)
  -q, --quiet             Quiet mode (alerts only)
  -d, --debug             Debug mode
  -c, --continuous        Continuous monitoring
  -i, --interval SECONDS  Check interval in seconds (default: 5)
  -n, --iterations NUM    Max iterations for continuous mode (default: 12)
  --cpu-threshold PCT     CPU threshold percentage (default: 80)
  --mem-threshold PCT     Memory threshold percentage (default: 80)
  --disk-threshold PCT    Disk threshold percentage (default: 90)
  --alert-email EMAIL     Email for alerts
  --log-file FILE         Log file path (default: /var/log/system-monitor.log)
  -V, --version           Show script version

EXAMPLES:
  $SCRIPT_NAME                                    # Single check
  $SCRIPT_NAME --continuous                       # Continuous monitoring
  $SCRIPT_NAME --continuous --interval 10 -n 6    # Monitor for 1 minute
  $SCRIPT_NAME --cpu-threshold 90 --alert-email admin@example.com

THRESHOLDS:
  CPU:   ${CPU_THRESHOLD}% (alerts when exceeded)
  Memory: ${MEM_THRESHOLD}% (alerts when exceeded)
  Disk:   ${DISK_THRESHOLD}% (alerts when exceeded)

EXIT CODES:
  0 - All metrics within thresholds
  1 - One or more metrics exceeded thresholds
  2 - Invalid arguments or system error
EOF
  exit "${1:-0}"
}

# Parse arguments
parse_arguments() {
  while (($# > 0)); do
    case $1 in
      -h|--help) usage 0 ;;
      -v|--verbose) VERBOSE=1; shift ;;
      -q|--quiet) VERBOSE=0; shift ;;
      -d|--debug) DEBUG=1; shift ;;
      -c|--continuous) CONTINUOUS=1; shift ;;
      -i|--interval)
        (($# > 1)) || die 2 "Missing value for --interval"
        CHECK_INTERVAL=$2
        shift 2
        ;;
      -n|--iterations)
        (($# > 1)) || die 2 "Missing value for --iterations"
        MAX_ITERATIONS=$2
        shift 2
        ;;
      --cpu-threshold)
        (($# > 1)) || die 2 "Missing value for --cpu-threshold"
        CPU_THRESHOLD=$2
        shift 2
        ;;
      --mem-threshold)
        (($# > 1)) || die 2 "Missing value for --mem-threshold"
        MEM_THRESHOLD=$2
        shift 2
        ;;
      --disk-threshold)
        (($# > 1)) || die 2 "Missing value for --disk-threshold"
        DISK_THRESHOLD=$2
        shift 2
        ;;
      --alert-email)
        (($# > 1)) || die 2 "Missing value for --alert-email"
        ALERT_EMAIL=$2
        ALERT_MODE=1
        shift 2
        ;;
      --log-file)
        (($# > 1)) || die 2 "Missing value for --log-file"
        LOG_FILE=$2
        shift 2
        ;;
      -V|--version) echo "$SCRIPT_NAME version $VERSION"; exit 0 ;;
      -*) die 2 "Unknown option: $1" ;;
      *) die 2 "Unexpected argument: $1" ;;
    esac
  done
}

# Get CPU usage
get_cpu_usage() {
  local -i cpu_usage

  # Use top to get CPU usage (works on most systems)
  if command -v top >/dev/null; then
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
  else
    # Fallback: read from /proc/stat
    local -a cpu_stats
    IFS=' ' read -ra cpu_stats < <(grep '^cpu ' /proc/stat)
    local -i idle=${cpu_stats[4]} total=0
    for val in "${cpu_stats[@]:1}"; do
      ((total+=val))
    done
    cpu_usage=$((100 * (total - idle) / total))
  fi

  echo "$cpu_usage"
}

# Get memory usage
get_mem_usage() {
  local -i mem_total mem_used mem_usage

  if [[ -f /proc/meminfo ]]; then
    mem_total=$(grep '^MemTotal:' /proc/meminfo | awk '{print $2}')
    local -i mem_free mem_buffers mem_cached
    mem_free=$(grep '^MemFree:' /proc/meminfo | awk '{print $2}')
    mem_buffers=$(grep '^Buffers:' /proc/meminfo | awk '{print $2}')
    mem_cached=$(grep '^Cached:' /proc/meminfo | awk '{print $2}')
    mem_used=$((mem_total - mem_free - mem_buffers - mem_cached))
    mem_usage=$((100 * mem_used / mem_total))
  else
    mem_usage=0
  fi

  echo "$mem_usage"
}

# Get disk usage
get_disk_usage() {
  local -- mount_point=${1:-/}
  local -i disk_usage

  disk_usage=$(df "$mount_point" | awk 'NR==2 {print $5}' | tr -d '%')
  echo "$disk_usage"
}

# Get load average
get_load_average() {
  local -- load_avg

  if [[ -f /proc/loadavg ]]; then
    read -r load_avg _ _ _ _ < /proc/loadavg
  else
    load_avg="0.00"
  fi

  echo "$load_avg"
}

# Check thresholds and alert
check_threshold() {
  local -- metric=$1
  local -i current=$2 threshold=$3
  local -- color status_msg

  if [[ "$current" -ge "$threshold" ]]; then
    color=$RED
    status_msg="CRITICAL"
    alert "$metric: ${color}${current}%${NC} (threshold: ${threshold}%)"
    log_msg "ALERT: $metric at ${current}% (threshold: ${threshold}%)"
    return 1
  elif [[ "$current" -ge $((threshold - 10)) ]]; then
    color=$YELLOW
    status_msg="WARNING"
    warn "$metric: ${color}${current}%${NC} (approaching threshold)"
    return 0
  else
    color=$GREEN
    status_msg="OK"
    debug "$metric: ${color}${current}%${NC}"
    return 0
  fi
}

# Monitor system
monitor_system() {
  local -i cpu_usage mem_usage disk_usage alerts=0
  local -- load_avg timestamp

  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # Get metrics
  cpu_usage=$(get_cpu_usage)
  mem_usage=$(get_mem_usage)
  disk_usage=$(get_disk_usage "/")
  load_avg=$(get_load_average)

  # Display header
  if ((VERBOSE)); then
    echo ""
    echo "${BOLD}System Monitor - Check #$((ITERATION + 1))${NC}"
    echo "Time: $timestamp"
    echo "Load Average: $load_avg"
    echo ""
  fi

  # Check thresholds
  check_threshold "CPU" "$cpu_usage" "$CPU_THRESHOLD" || ((alerts+=1))
  check_threshold "Memory" "$mem_usage" "$MEM_THRESHOLD" || ((alerts+=1))
  check_threshold "Disk" "$disk_usage" "$DISK_THRESHOLD" || ((alerts+=1))

  # Summary
  if ((alerts > 0)); then
    echo ""
    error "${alerts} metric(s) exceeded threshold"

    # Send email alert if configured
    if ((ALERT_MODE)) && [[ -n "$ALERT_EMAIL" ]]; then
      send_alert_email "$timestamp" "$cpu_usage" "$mem_usage" "$disk_usage"
    fi

    return 1
  else
    if ((VERBOSE)); then
      echo ""
      success "All metrics within thresholds"
    fi
    return 0
  fi
}

# Send alert email
send_alert_email() {
  local -- timestamp=$1
  local -i cpu=$2 mem=$3 disk=$4

  if ! command -v mail >/dev/null; then
    warn "Cannot send email: 'mail' command not found"
    return 1
  fi

  local -- subject="System Alert: Resource Threshold Exceeded"
  local -- body
  body=$(cat <<EOF
System Monitor Alert
====================

Time: $timestamp
Host: $(hostname)

Current Metrics:
- CPU:    ${cpu}% (threshold: ${CPU_THRESHOLD}%)
- Memory: ${mem}% (threshold: ${MEM_THRESHOLD}%)
- Disk:   ${disk}% (threshold: ${DISK_THRESHOLD}%)

Please investigate immediately.

---
$SCRIPT_NAME v$VERSION
EOF
)

  echo "$body" | mail -s "$subject" "$ALERT_EMAIL"
  log_msg "Alert email sent to $ALERT_EMAIL"
}

# Main
main() {
  parse_arguments "$@"

  info "${BOLD}System Resource Monitor v$VERSION${NC}"
  info "Thresholds: CPU=${CPU_THRESHOLD}% MEM=${MEM_THRESHOLD}% DISK=${DISK_THRESHOLD}%"
  ((CONTINUOUS)) && info "Continuous mode: ${MAX_ITERATIONS} checks @ ${CHECK_INTERVAL}s interval"

  # Create log file if needed
  if [[ ! -f "$LOG_FILE" ]] && [[ -w "${LOG_FILE%/*}" ]]; then
    touch "$LOG_FILE" || warn "Cannot create log file: $LOG_FILE"
  fi

  # Single check mode
  if ! ((CONTINUOUS)); then
    monitor_system
    exit $?
  fi

  # Continuous monitoring
  local -i exit_code=0
  for ((ITERATION=0; ITERATION<MAX_ITERATIONS; ITERATION++)); do
    if ! monitor_system; then
      exit_code=1
    fi

    # Sleep between checks (except last iteration)
    if [[ "$ITERATION" -lt $((MAX_ITERATIONS - 1)) ]]; then
      sleep "$CHECK_INTERVAL"
    fi
  done

  echo ""
  info "Monitoring complete: $MAX_ITERATIONS checks performed"
  exit "$exit_code"
}

main "$@"
#fin
