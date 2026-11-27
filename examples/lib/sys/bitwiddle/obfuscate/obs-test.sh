#!/bin/bash
#shellcheck source-path=SCRIPTDIR
# obs sender
set -euo pipefail
shopt -s inherit_errexit
declare -rx PATH=/usr/local/bin:/usr/bin:/bin

die() { (($# < 2)) || >&2 echo "${0##*/}: ✗ ${*:2}"; exit "${1:-0}"; }

#shellcheck source=obs-common.sh
source obs-common || die 1 'Failed to source obs-common'
#shellcheck source=obs-receive.sh
source obs-receive || die 1 'Failed to source obs-receive'
#shellcheck source=../../get_pubkey/is-authorized-pubkey
source is-authorized-pubkey || die 1 'Failed to source is-authorized-pubkey'

#shellcheck source=../../../HTML/url-en-decode/urlencode.bash
source urlencode || die 1 'Failed to source urlencode'
#shellcheck source=../../../HTML/url-en-decode/urldecode.bash
source urldecode || die 1 'Failed to source urldecode'

declare -i i=50
declare -i SLEEP=OBS_WINDOW

declare -- mac pubkey string send='' receive=''

declare -- user="${1:-sysadmin}"

mac=$(get_mac) || die 1 'No network interface MAC found'
pubkey=$(get_pubkey "$user") || die 1 "No public key for ${user@Q}"

string="$mac|$pubkey"
declare -p mac pubkey string

declare -- r_mac

while ((i--)); do
  >&2 echo "$i"
  send=$(obs_send "$string") || die 1 'obs_send failed'
  send=$(urlencode "$send") || die 1 'urlencode failed'

  #...
  sleep $((RANDOM % SLEEP))
  #...

  send=$(urldecode "$send") || die 1 'urldecode failed'
  receive=$(obs_receive "$send" ||:)
  [[ $string == "$receive" ]] || { >&2 echo "error: $SLEEP ${string@Q} != ${receive@Q}"; continue; }

  # extract mac and pubkey from received payload
  r_mac=${receive%%|*}
  is_approved_mac "$r_mac" || { >&2 echo "error: unapproved mac ${r_mac@Q}"; break; }

#  is_authorized_pubkey "$receive" || { >&2 echo "error: pubkey not in authorized_keys ${AUTHORIZED_KEYS_FILE@Q}"; break; }
done

#fin
