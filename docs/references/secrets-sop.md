# Secrets & Agenix SOP

## Overview

Secrets are managed with **agenix**. `.age` files are ciphertext (safe to commit). `secrets.nix` maps files to age recipient public keys.

- System secrets decrypt to `/run/agenix/` (root-owned)
- User secrets decrypt to `/run/agenix/` (user-owned)
- The `secretEnvs` list in `home/users/<name>.nix` is the single source of truth for user secret → env var mappings. `age.secrets` entries and `zsh.initContent` shell exports are both derived from it automatically — no other files need editing for a new user secret.

## Adding a New User Secret

1. Add the secret path + recipient keys to `secrets/secrets.nix`:
   ```nix
   "grue/mysecret.age".publicKeys = [grue] ++ allHosts;
   ```
2. Add to the `secretEnvs` list in `home/users/grue.nix`:
   ```nix
   { secret = "mysecret"; env = "MY_ENV_VAR"; }
   ```
3. Encrypt the `.age` file: `agenix -e secrets/grue/mysecret.age`
4. Track with jj: `jj file track secrets/grue/mysecret.age`

## Rekeying

Run `just rekey` after adding a new recipient to `secrets.nix`. Requires agenix CLI and your SSH key loaded in the agent.

## New Host Preparation

`just prep-host <hostname>` fetches the host pubkey from 1Password `Service` vault, saves to `nixos/hosts/<hostname>/ssh_host_ed25519_key.pub`, and prints instructions to update `secrets.nix`.

## SSH Module

`home/modules/ssh/default.nix` configures 1Password SSH agent via `programs.ssh.matchBlocks."*"` (not `extraConfig`). Set `enableDefaultConfig = false` to suppress the deprecated default Host * block warning. Use `programs.git.signing` (typed options) not raw `settings` keys for git signing.

**`programs.ssh.extraConfig` + assertion**: Setting `extraConfig` to a non-empty string requires `matchBlocks."*"` to exist, or home-manager throws an assertion. Always use `matchBlocks."*"` for default host config instead.
