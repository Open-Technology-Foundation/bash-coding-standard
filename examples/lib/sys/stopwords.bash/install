#!/bin/bash
# install.sh - Installation script for stopwords.bash
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob
# The caller's PATH is kept only to report where they will find the installed
# script; every command here runs under the system PATH (this script may sudo)
declare -r USER_PATH=${PATH:-}
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

# Script metadata (no messaging functions yet, so the failure message is inline)
declare -r VERSION=1.2.0
declare -r PROJECT_NAME=stopwords
declare -- SCRIPT_PATH
SCRIPT_PATH=$(realpath -- "$0") \
  || { >&2 echo "${0##*/}: cannot resolve script path"; exit 1; }
readonly SCRIPT_PATH
declare -r SCRIPT_DIR=${SCRIPT_PATH%/*} SCRIPT_NAME=${SCRIPT_PATH##*/}

# Installation configuration
declare -- PREFIX="${PREFIX:-/usr/local}"
declare -- BIN_DIR="$PREFIX/bin"
declare -- DOC_DIR="$PREFIX/share/doc/$PROJECT_NAME"
declare -- DATA_DIR="$PREFIX/share/$PROJECT_NAME"
readonly PREFIX BIN_DIR DOC_DIR DATA_DIR
# Where earlier versions put the bundled data, whatever PREFIX was
readonly LEGACY_DATA_DIR=/usr/share/stopwords

# Fewest language files (README excluded) that count as a usable data set
declare -ri MIN_DATA_FILES=30

readonly SOURCE_SCRIPT="$SCRIPT_DIR/stopwords"
readonly SOURCE_DATA="$SCRIPT_DIR/stopwords_data"
readonly SOURCE_README="$SCRIPT_DIR/README.md"
readonly SOURCE_LICENSE="$SCRIPT_DIR/LICENSE"

# Colour only when both streams are terminals (BCS0105), so redirected
# output never carries escape codes
if [[ -t 1 && -t 2 ]]; then
  declare -r RED=$'\033[1;31m' GREEN=$'\033[1;32m' YELLOW=$'\033[1;33m' BLUE=$'\033[1;34m' NC=$'\033[0m'
else
  declare -r RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# Messaging: status text goes to stderr, keeping stdout for usage and
# version output. _msg takes its icon and colour from the calling wrapper.
# No script-name prefix: these lines read as a progress log, not as errors
# from a tool in a pipeline
_msg() {
  local -- prefix=''
  case ${FUNCNAME[1]} in
    info)    prefix="$BLUE◉$NC " ;;
    success) prefix="$GREEN✓$NC " ;;
    warn)    prefix="$YELLOW▲$NC " ;;
    error)   prefix="$RED✗$NC " ;;
    msg|*)   ;;
  esac
  >&2 printf '%s%s\n' "$prefix" "$*"
}
msg()     { _msg "$@"; }
info()    { _msg "$@"; }
success() { _msg "$@"; }
warn()    { _msg "$@"; }
error()   { _msg "$@"; }

# Execute command with sudo if target_dir is not writable; report a failure
# with the command line
run_install() {
  local -- target_dir=$1
  shift
  local -i rc=0

  # A directory not yet created is writable when its nearest existing
  # ancestor is, so a user-local PREFIX needs no sudo for new directories
  while [[ ! -e $target_dir ]]; do
    target_dir=${target_dir%/*}
    target_dir=${target_dir:-/}
  done

  if [[ ! -w $target_dir ]]; then
    if ((EUID)); then
      info "Requesting sudo privileges for installation to $target_dir"
      sudo -- "$@" || rc=$?
    else
      "$@" || rc=$?
    fi
  else
    "$@" || rc=$?
  fi

  ((rc == 0)) || error "Failed (exit $rc): ${*@Q}"
  return "$rc"
}

# Print the first executable NAME on the caller's PATH, as `command -v` would
find_in_user_path() {
  local -- name=$1 dir
  local -a dirs
  IFS=: read -ra dirs <<< "$USER_PATH"
  for dir in "${dirs[@]}"; do
    # An empty element means the current directory; never report that
    [[ -n $dir ]] || continue
    if [[ -f $dir/$name && -x $dir/$name ]]; then
      echo "$dir/$name"
      return 0
    fi
  done
  return 1
}

# Count the language files in a stopwords data directory (README excluded).
# A relative path (from a relative NLTK_DATA) gets ./ so find cannot read a
# leading '-' as an option
count_data_files() {
  local -- dir=$1
  [[ $dir == /* ]] || dir=./$dir
  find "$dir" -maxdepth 1 -type f ! -name README | wc -l
}

# Print the data directory the given stopwords script uses, by asking the
# script itself, so check cannot disagree with it about the search order.
# Sourcing only defines its functions; the script stops at its source fence
script_data_dir() {
  # shellcheck disable=SC2016  # $1 is for the child shell to expand
  bash -c 'source -- "$1" && _stopwords_find_data' _ "$1" 2>/dev/null
}

usage() {
  cat <<USAGE
$SCRIPT_NAME $VERSION - Installation script for $PROJECT_NAME

Usage: $SCRIPT_NAME [COMMAND] [OPTIONS]

Commands:
  install     Install $PROJECT_NAME (default command)
  uninstall   Remove $PROJECT_NAME installation
  check       Verify installation status

Environment Variables:
  PREFIX      Installation prefix, an absolute path (default: /usr/local)
              For user install: PREFIX=\$HOME/.local
  NLTK_DATA   Optional NLTK data directory, used only when no bundled
              stopwords data is found

Examples:
  # System-wide installation (requires sudo)
  sudo ./install.sh install

  # User-local installation (no sudo needed)
  PREFIX=\$HOME/.local ./install.sh install

  # Check installation status
  ./install.sh check

  # Uninstall
  sudo ./install.sh uninstall

Note:
  - The bundled stopwords data is always installed, and the script uses it
    first; NLTK data is optional
  - uninstall asks before removing the data directory and reads the answer
    from stdin; for unattended runs, pipe it in (echo y | ./install.sh
    uninstall). No answer keeps the data

Current Configuration:
  PREFIX:     $PREFIX
  BIN_DIR:    $BIN_DIR
  DOC_DIR:    $DOC_DIR
  DATA_DIR:   $DATA_DIR
USAGE
}

verify_sources() {
  local -i missing=0

  if [[ ! -f $SOURCE_SCRIPT ]]; then
    error "Source script not found: ${SOURCE_SCRIPT@Q}"
    missing+=1
  fi

  if [[ ! -d $SOURCE_DATA ]]; then
    error "Source data directory not found: ${SOURCE_DATA@Q}"
    missing+=1
  fi

  if [[ ! -f $SOURCE_README ]]; then
    warn 'README.md not found (optional)'
  fi

  if [[ ! -f $SOURCE_LICENSE ]]; then
    warn 'LICENSE not found (optional)'
  fi

  if ((missing)); then
    error 'Missing required source files. Cannot proceed with installation.'
    return 3
  fi

  return 0
}

cmd_check() {
  local -i errors=0

  info "Checking $PROJECT_NAME installation..."
  msg ''

  local -- installed="$BIN_DIR/$PROJECT_NAME"
  if [[ -x $installed ]]; then
    success "Script found: $installed"
  else
    error "Script not found or not executable: ${installed@Q}"
    errors+=1
  fi

  # The copy the caller will actually run, found on their own PATH
  local -- found_path=''
  if found_path=$(find_in_user_path "$PROJECT_NAME"); then
    success "Script in PATH: $found_path"
  else
    warn 'Script not found in PATH'
    if [[ -x $installed ]]; then
      msg "    Script exists but $BIN_DIR not in PATH"
    fi
  fi

  # The data directory the installed script uses, as the script reports it
  local -- data_dir
  local -i file_count=0
  if [[ ! -x $installed ]]; then
    info 'Data check skipped: no installed script to ask'
  elif ! data_dir=$(script_data_dir "$installed"); then
    error "Stopwords data not found by ${installed@Q}"
    errors+=1
  elif ! file_count=$(count_data_files "$data_dir"); then
    error "Cannot read data directory: ${data_dir@Q}"
    errors+=1
  elif ((file_count >= MIN_DATA_FILES)); then
    success "Stopwords data in use: $data_dir ($file_count files)"
  else
    error "Data directory incomplete: ${data_dir@Q} (expected $MIN_DATA_FILES+ files, found $file_count)"
    errors+=1
  fi

  if [[ -n $found_path ]]; then
    info 'Testing basic functionality...'
    if "$found_path" 'the quick brown fox' &>/dev/null; then
      success 'Basic test passed'
    else
      error 'Basic test failed'
      errors+=1
    fi
  fi

  if [[ -d $DOC_DIR ]]; then
    success "Documentation found: $DOC_DIR"
  else
    info 'Documentation not installed'
  fi

  msg ''
  if ((errors)); then
    error "Found $errors error(s)"
    return 1
  else
    success 'All checks passed'
    return 0
  fi
}

cmd_install() {
  info "Installing $PROJECT_NAME $VERSION"
  info "Installation prefix: $PREFIX"
  info "Stopwords data directory: $DATA_DIR"
  msg ''

  verify_sources || return

  info 'Creating installation directories...'

  if [[ ! -d $BIN_DIR ]]; then
    run_install "${BIN_DIR%/*}" mkdir -p -- "$BIN_DIR" || return 1
  fi

  if [[ ! -d $DOC_DIR ]]; then
    run_install "${DOC_DIR%/*}" mkdir -p -- "$DOC_DIR" || return 1
  fi

  if [[ ! -d $DATA_DIR ]]; then
    run_install "${DATA_DIR%/*}" mkdir -p -- "$DATA_DIR" || return 1
  fi

  info "Installing script to $BIN_DIR/$PROJECT_NAME..."
  run_install "$BIN_DIR" install -m 755 -- "$SOURCE_SCRIPT" "$BIN_DIR/$PROJECT_NAME" || return 1
  success 'Script installed'

  info 'Installing stopwords data (32 languages, ~170KB)...'
  local -- file
  local -i count=0
  for file in "$SOURCE_DATA"/*; do
    [[ -f $file ]] || continue
    run_install "$DATA_DIR" cp -- "$file" "$DATA_DIR/" || return 1
    count+=1
  done
  success "Installed $count data files to $DATA_DIR"

  if [[ -f $SOURCE_README ]]; then
    info 'Installing documentation...'
    run_install "$DOC_DIR" cp -- "$SOURCE_README" "$DOC_DIR/" || return 1
    if [[ -f $SOURCE_LICENSE ]]; then
      run_install "$DOC_DIR" cp -- "$SOURCE_LICENSE" "$DOC_DIR/" || return 1
    fi
    success "Documentation installed to $DOC_DIR"
  fi

  msg ''
  success 'Installation complete!'
  msg ''

  if [[ ":$USER_PATH:" != *":$BIN_DIR:"* ]]; then
    warn "Note: $BIN_DIR is not in your PATH"
    msg '    Add this to your ~/.bashrc or ~/.profile:'
    msg "    export PATH=\"$BIN_DIR:\$PATH\""
    msg ''
  fi

  # cmd_check also reports which data directory the script will use
  info 'Verifying installation...'
  if cmd_check; then
    success 'All checks passed!'
  else
    warn 'Some verification checks failed. Please review the output above.'
  fi

  return 0
}

cmd_uninstall() {
  info "Uninstalling $PROJECT_NAME"
  msg ''

  local -i removed=0

  if [[ -f $BIN_DIR/$PROJECT_NAME ]]; then
    info "Removing script from $BIN_DIR..."
    run_install "$BIN_DIR" rm -f -- "$BIN_DIR/$PROJECT_NAME" || return 1
    success 'Script removed'
    removed+=1
  else
    info "Script not found at $BIN_DIR/$PROJECT_NAME (already removed)"
  fi

  if [[ -d $DOC_DIR ]]; then
    info "Removing documentation from $DOC_DIR..."
    run_install "${DOC_DIR%/*}" rm -rf -- "$DOC_DIR" || return 1
    success 'Documentation removed'
    removed+=1
  else
    info 'Documentation not found (already removed)'
  fi

  if [[ -d $DATA_DIR ]]; then
    msg ''
    warn "Stopwords data found at: $DATA_DIR"
    msg '    Remove data directory? [y/N] '
    local -- response
    # No answer (EOF on stdin) means no, rather than aborting under set -e
    read -r response || response=''
    if [[ $response =~ ^[Yy] ]]; then
      info 'Removing stopwords data...'
      run_install "${DATA_DIR%/*}" rm -rf -- "$DATA_DIR" || return 1
      success 'Data removed'
      removed+=1
    else
      info 'Data directory preserved'
    fi
  else
    info 'Data directory not found (already removed)'
  fi

  # Earlier versions installed the data here regardless of PREFIX; point it
  # out rather than delete a system directory this run did not create
  if [[ $LEGACY_DATA_DIR != "$DATA_DIR" && -d $LEGACY_DATA_DIR ]]; then
    info "Data from an earlier install remains at $LEGACY_DATA_DIR"
    msg "    Remove it with: sudo rm -rf -- $LEGACY_DATA_DIR"
  fi

  msg ''
  if ((removed)); then
    success 'Uninstallation complete'
  else
    info 'Nothing to uninstall (already clean)'
  fi

  return 0
}

main() {
  local -- command="${1:-install}"

  # PREFIX comes from the environment and ends up in mkdir/cp/rm operands
  [[ $PREFIX == /* ]] || { error "PREFIX must be an absolute path: ${PREFIX@Q}"; return 22; }

  case $command in
    install)
      cmd_install
      ;;
    uninstall|remove)
      cmd_uninstall
      ;;
    check|verify|test)
      cmd_check
      ;;
    -h|--help|help)
      usage
      return 0
      ;;
    -V|--version|version)
      echo "$SCRIPT_NAME $VERSION"
      return 0
      ;;
    *)
      error "Unknown command: ${command@Q}"
      msg ''
      >&2 usage
      return 22
      ;;
  esac
}

main "$@"
#fin
