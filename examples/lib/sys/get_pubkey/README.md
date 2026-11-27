# get_pubkey

SSH public key retrieval and validation utilities for Bash.

## Scripts

### get-pubkey

Print the first available SSH public key for a user. Checks key types in order: ed25519, ecdsa, rsa.

```bash
get-pubkey                  # current user
sudo get-pubkey netadmin    # another user (requires read access to their ~/.ssh/)
get-pubkey | ssh-keygen -lf -   # show fingerprint
```

Exit codes: `0` key found, `1` no key found, `2` user not found, `22` invalid option or too many arguments.

### is-authorized-pubkey

Check whether a public key exists in an `authorized_keys` file. Matches the key type and base64 key data exactly, ignoring comments, options prefixes and commented-out lines. Malformed input (unknown key type, truncated or empty key data) is rejected. Accepts an optional `mac|pubkey` prefix which is stripped before matching.

```bash
is-authorized-pubkey "$(get-pubkey)"

# check against a different authorized_keys file
AUTHORIZED_KEYS_FILE=/root/.ssh/authorized_keys sudo is-authorized-pubkey "$(get-pubkey)"
```

Exit codes: `0` key found, `1` key not found or file unreadable, `22` invalid option, missing or malformed PUBKEY.

**Environment:** `AUTHORIZED_KEYS_FILE` — path to authorized_keys (default: `~/.ssh/authorized_keys`).

## Library Mode

Both scripts can be sourced to export their functions:

```bash
source get-pubkey            # exports get_pubkey()
source is-authorized-pubkey  # exports is_authorized_pubkey()

key=$(get_pubkey) && is_authorized_pubkey "$key"
```

## Install

```bash
symlink -S .    # creates /usr/local/bin/get-pubkey and /usr/local/bin/is-authorized-pubkey
```

## Requirements

- Bash 5.2+
- `getent` (for user lookup in `get-pubkey`)
- Standard SSH key files in `~/.ssh/`
