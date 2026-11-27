# get_pubkey — SSH Public Key Utilities

## Purpose

A pair of small Bash utilities for retrieving and validating SSH public keys. Part of the `/ai/scripts/lib/` shared library collection. Intended for use by other scripts that need SSH key operations — e.g., identity verification, key-based authentication workflows, or remote provisioning.

## Scripts

### `get-pubkey`

Prints the current user's first available SSH public key, checking in preference order: `ed25519` → `ecdsa` → `rsa`.

- **Function**: `get_pubkey()`
- **Exit 0**: Key found and printed to stdout
- **Exit 1**: No readable public key found
- **Exit 2**: USER not found
- **Exit 22**: Invalid option or too many arguments
- **Dual-mode**: Sourceable as a library (`source get-pubkey`) or executable directly

### `is-authorized-pubkey`

Checks whether a given public key exists in an `authorized_keys` file. Validates the key type and base64 key data, then looks for that exact `type blob` pair of words in each non-comment line.

- **Function**: `is_authorized_pubkey(payload)`
- **Input**: A string containing a public key (optionally prefixed with a MAC header separated by `|`)
- **Exit 0**: Key found in authorized_keys
- **Exit 1**: Key not found, or authorized_keys unreadable
- **Exit 22**: Invalid option, missing or malformed PUBKEY
- **Configurable**: `AUTHORIZED_KEYS_FILE` env var (default: `~/.ssh/authorized_keys`)
- **Dual-mode**: Sourceable or executable

## Usage

```bash
# Direct — check if current user's key is authorized
is-authorized-pubkey "$(get-pubkey)"

# With custom authorized_keys (e.g., root's)
AUTHORIZED_KEYS_FILE=/root/.ssh/authorized_keys sudo is-authorized-pubkey "$(get-pubkey)"

# As a library
source get-pubkey
source is-authorized-pubkey
key=$(get_pubkey) && is_authorized_pubkey "$key"
```

## Structure

| File                  | Description                              |
|-----------------------|------------------------------------------|
| `get-pubkey`          | Retrieve current user's SSH public key   |
| `is-authorized-pubkey`| Verify key exists in authorized_keys     |
| `.symlink`            | Installs both scripts to `/usr/local/bin`|

## Dependencies

- Bash 5.2+
- `getent` (for user lookup in `get-pubkey`)
- Standard SSH key files in `~/.ssh/`

## Notes

- Both scripts use the BCS dual-mode pattern: `declare -fx` exports the function, and the `BASH_SOURCE` guard separates library mode from script mode.
- Key matching compares the key type and base64 blob exactly (ignores comments and options prefixes), which is the correct way to match SSH keys regardless of trailing comment differences. Partial or empty blobs are rejected rather than matched as substrings.
- The `is-authorized-pubkey` input format supports a `mac|pubkey` payload convention, stripping the MAC prefix before matching.
