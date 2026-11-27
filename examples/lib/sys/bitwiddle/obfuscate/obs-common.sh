#!/bin/bash
#shellcheck source-path=SCRIPTDIR

[[ ${BASH_SOURCE[0]} != "$0" ]] || {
  >&2 echo "Error: ${0@Q} must be sourced"
  exit 1
}

#shellcheck source=../bitwiddle
source bitwiddle || return 1
#shellcheck source=../../get_mac/get-mac
source get-mac || return 1
#shellcheck source=../../get_pubkey/get-pubkey
source get-pubkey || return 1

# common obs settings
declare -rx OBS_MARKER=${OBS_MARKER:-'OK:'}
# OBS_WINDOW may come from the environment; an integer declaration evaluates
# it as arithmetic and obs_send divides by it, so only 1 or more may pass, and
# few enough digits that it cannot overflow 64 bits and wrap round to 0
[[ ${OBS_WINDOW:-3} =~ ^[1-9][0-9]{0,5}$ ]] || {
  >&2 echo "obs-common: ✗ Invalid OBS_WINDOW ${OBS_WINDOW@Q} (use 1-999999 seconds)"
  return 22
}
declare -irx OBS_WINDOW=${OBS_WINDOW:-3}

obs_send() {
  printf '%s' "${OBS_MARKER}${1}" \
      | bitwiddle - xor "$((EPOCHSECONDS / OBS_WINDOW % 255 + 1))" \
      | base64 --wrap=0 | rev
}
declare -fx obs_send


#fin
