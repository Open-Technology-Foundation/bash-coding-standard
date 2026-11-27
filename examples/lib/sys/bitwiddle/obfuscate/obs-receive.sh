#!/bin/bash
#shellcheck source-path=SCRIPTDIR

[[ ${BASH_SOURCE[0]} != "$0" ]] || {
  >&2 echo "Error: ${0@Q} must be sourced"
  exit 1
}

# Guard on a function only obs-common defines: OBS_MARKER may come from the
# environment, and skipping obs-common would skip its OBS_WINDOW validation
#shellcheck source=obs-common.sh
declare -F obs_send >/dev/null || source obs-common || return 1

obs_receive() {
  # --- receiver (within OBS_WINDOW seconds) ---
  local -i twiddle=$((EPOCHSECONDS / OBS_WINDOW % 255 + 1))
  local -- tbase
  tbase=$(printf '%s' "$1" | rev) || return 1

  # Validate via hex output (null-safe) then decode with correct key
  local -- marker_hex trial result
  marker_hex=$(printf '%s' "$OBS_MARKER" | od -An -tx1 -v | tr -d ' \n') || return 1
  # Without pipefail only tr's status is seen; an empty marker would match anything
  [[ -n $marker_hex ]] || return 1

  # A payload that fails to decode is simply invalid: let the marker test reject it
  trial=$(printf '%s' "$tbase" | base64 -d | bitwiddle -x - xor "$twiddle" | tr -d ' \n') || trial=''
  if [[ $trial != "${marker_hex}"* ]]; then
    twiddle=$(((EPOCHSECONDS / OBS_WINDOW - 1) % 255 + 1))
    #>&2 echo 'retry'
    trial=$(printf '%s' "$tbase" | base64 -d | bitwiddle -x - xor "$twiddle" | tr -d ' \n') || trial=''
  fi

  if [[ $trial == "${marker_hex}"* ]]; then
    # Correct key — decode (original text is printable, no nulls)
    result=$(printf '%s' "$tbase" | base64 -d | bitwiddle - xor "$twiddle") || return 1
    printf '%s' "${result#"$OBS_MARKER"}"
    return 0
  fi

  >&2 echo "${FUNCNAME[0]}: Invalid Marker"
  return 1
}
declare -fx obs_receive

#fin
