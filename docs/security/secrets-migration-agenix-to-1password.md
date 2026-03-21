# Secrets Migration: agenix → 1Password

## Background

This config previously used [agenix](https://github.com/ryantm/agenix) to manage three secrets:

- `tailscale.age` — Tailscale auth key (system-level, all hosts)
- `goreleaser.age` — GoReleaser API key (user-level, grue only)
- `anthropic.age` — Anthropic API key (user-level, grue only)

## Why Replace agenix?

- 1Password is already the SSH agent and git signing provider; consolidating avoids a second secret store
- agenix requires SSH private keys to decrypt at activation — a bootstrapping dependency
- User-session secrets (API keys) are more naturally scoped to an interactive user session than to system activation
- The Tailscale secret is only needed for fresh-node provisioning; once a node is registered, the auth key is never consumed again

## Approach

### Tailscale
Tailscale authentication state persists in `/var/lib/tailscale/tailscaled.state`. On a standard NixOS install, this file survives `nixos-rebuild switch`. Nodes are authenticated once interactively:

```bash
sudo tailscale up --auth-key <paste key here>
```

After that, the built-in `services.tailscale` reconnect logic will find state = `Running` and skip re-authentication.

**No auth key is needed in the Nix config at all.**

### API Keys (goreleaser, anthropic)
These are user-session secrets that only make sense when grue is interactively logged in. They are injected into the zsh environment at shell startup via:

```bash
eval "$(op inject --in-file ~/.config/op/secrets.env 2>/dev/null)" || true
```

The template file `~/.config/op/secrets.env` (managed by home-manager) contains:

```
export GORELEASER_KEY="op://Personal/GoReleaser/credential"
export ANTHROPIC_API_KEY="op://Personal/Anthropic/credential"
```

If 1Password is locked, `op inject` fails silently (stderr suppressed, `|| true` prevents shell startup failure). The env vars are simply unset until the user unlocks 1Password and opens a new shell.

## opnix Assessment

Two opnix projects were evaluated (`mrjones2014/opnix`, `brizzbuzz/opnix`). Both use a **service account token** model — not the desktop app agent. A service account token must be stored as a plain file on disk with 0400 permissions. This means:

- A secret is still stored on disk (the service account token), just a different one
- The system has a hard network dependency on the 1Password API at every boot
- No fallback or cached credential if the API is unreachable

For this config's use case (user-session API keys + a one-time Tailscale auth), opnix adds complexity without benefit. The `op inject` pattern and persistent Tailscale state are sufficient.

## Failure Modes

| Scenario | Result |
|----------|--------|
| 1Password locked at shell startup | API keys not set; shell opens normally |
| 1Password app not running | Same as above |
| `op` binary not on PATH | Guard condition prevents error; shell opens normally |
| Tailscale node state lost | `sudo tailscale up` required once; no secrets in config needed |
| Host reinstall (fresh `/var/lib`) | Manual `sudo tailscale up` on first boot |

## Removed Infrastructure

- `agenix` flake input
- `inputs.agenix.nixosModules.default` import in `nixos/profiles/base.nix`
- `inputs.agenix.homeManagerModules.default` import in `home/users/grue.nix`
- All `age.secrets.*` declarations
- `secrets/tailscale.age`, `secrets/goreleaser.age`, `secrets/anthropic.age`
- `secrets/secrets.nix`
- `nixos/common/tailscale.nix` `tailscale-autoconnect` custom systemd service
- `run-agenix.d.mount` dependency from tailscale service

## Bootstrap / ISO Impact

This migration significantly simplifies new host bootstrapping. Previously, provisioning a new host required:

1. Adding the host's SSH public key to `secrets/secrets.nix`
2. Running `just secret-rekey` to re-encrypt all secrets to the new key
3. Committing and pushing the rekeyed secrets
4. Ensuring the installer ISO had the host's private SSH key available to decrypt at activation

After this migration:

1. Install NixOS normally (no secrets infrastructure needed)
2. Run `sudo tailscale up --auth-key <key>` once interactively
3. Sign in to 1Password — env vars are available immediately in new shells

The ISO/installer no longer needs any agenix tooling. The `secrets/` directory and `secrets.nix` key management ceremony disappear entirely.
