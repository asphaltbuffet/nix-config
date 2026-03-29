# Secrets Management: agenix + 1Password

**Date**: 2026-03-29
**Status**: Draft
**Replaces**: `op inject` / `secrets.env` approach (removed); opnix migration (abandoned — see Decision Log)

---

## Overview

This spec defines the secrets management architecture for `nix-config` using
**agenix** (ryantm/agenix) for runtime secret delivery and **1Password + `op`
CLI** for bootstrap key distribution. The design eliminates the manual key
ceremony that made the previous agenix setup painful while preserving per-user
privacy and offline secret availability.

---

## Problem Statement

Previous approaches and why they were rejected:

| Approach | Problem |
|---|---|
| `op inject` + `secrets.env` | Secrets unavailable on remote SSH sessions without interactive 1Password approval; no offline availability |
| opnix (brizzbuzz/opnix) | 1Password service accounts cannot access personal vaults (`Private`, `Shared`) — only team vaults. Per-user secrets (API keys tied to individuals) can't use SAs without destroying privacy. |
| agenix (original) | Secret delivery worked well, but adding a new host required: rekeying on an existing host, manual file transfer, push, pull on new host during bootstrap — too much friction |

The core insight: **agenix's delivery model is correct**; only the bootstrap
key ceremony was painful. 1Password eliminates the ceremony by acting as the
distribution mechanism for host keys — not as the runtime secret store.

---

## Architecture

### Tool Responsibilities

| Tool | Role |
|---|---|
| **agenix** | Encrypt secrets to age recipients; decrypt to files on disk at activation time |
| **1Password + `op`** | Store host SSH keypairs; distribute private keys during bootstrap/prep |
| **`load-secrets`** | Shell script (Nix-generated) that reads decrypted agenix files and exports env vars at zsh startup |

### Age Recipients

Each secret is encrypted to the specific keys that need to decrypt it:

| Secret category | Encrypted to |
|---|---|
| System secrets (e.g. `hcPingKey`) | Host SSH keys for hosts that use the secret |
| User secrets (e.g. API keys) | That user's SSH key only |

User SSH keys follow the naming convention `<username>-main` and live in each
user's `Private` vault in 1Password. Example: `grue-main` in `grue`'s Private
vault, `jsquats-main` in `jsquats`'s Private vault.

This ensures:
- `jsquats` cannot decrypt `grue`'s secrets even on the same host
- Secrets are accessible in SSH sessions via SSH agent forwarding (the user's
  key in the 1Password SSH agent is forwarded automatically)
- No service account or team vault required for per-user secrets

### 1Password Storage

| Vault | Contents |
|---|---|
| `Service` | Host SSH keypairs (items: `host-wendigo`, `host-kushtaka`, `host-snallygaster`); each item has `private_key` and `public_key` fields. Also: `ping_key` (healthchecks.io). |
| Each user's `Private` | Their SSH keypair (`grue-main`, etc.) and personal API key items |

### Secret Inventory

**System secrets** (encrypted to relevant host SSH keys, root-readable):

| Secret file | 1Password reference | Used by |
|---|---|---|
| `secrets/hcPingKey.age` | `op://Service/ping_key/credential` | `nixos/common/autodeploy.nix` |

**User secrets** (encrypted to user SSH key, user-readable):

| Secret file | 1Password reference | Env var |
|---|---|---|
| `secrets/grue/goreleaser.age` | `op://Private/GoReleaser/credential` | `GORELEASER_KEY` |
| `secrets/grue/anthropic.age` | `op://Private/Anthropic/credential` | `ANTHROPIC_API_KEY` |
| `secrets/grue/context7.age` | `op://Private/Context7/credential` | `CONTEXT7_API_KEY` |
| `secrets/grue/github.age` | `op://Private/GitHub/token` | `GH_TOKEN` |
| `secrets/grue/githubMcp.age` | `op://Private/claude-github-mcp/token` | `GITHUB_PERSONAL_ACCESS_TOKEN` |
| `secrets/grue/protonmailHost.age` | `op://Private/proton_mail_bridge/server` | `POP_SMTP_HOST` |
| `secrets/grue/protonmailPort.age` | `op://Private/proton_mail_bridge/port` | `POP_SMTP_PORT` |
| `secrets/grue/protonmailUsername.age` | `op://Private/proton_mail_bridge/username` | `POP_SMTP_USERNAME` |
| `secrets/grue/protonmailPassword.age` | `op://Private/proton_mail_bridge/password` | `POP_SMTP_PASSWORD` |
| `secrets/grue/resend.age` | `op://Private/Resend/api_key_full` | `RESEND_API_KEY` |

### Nix Module Structure

```
secrets/                          # Encrypted .age files (committed to repo)
  hcPingKey.age
  grue/
    anthropic.age
    ...
secrets.nix                       # agenix recipients map (committed to repo)
nixos/common/agenix.nix           # System-level agenix NixOS module + system secrets
home/modules/agenix/default.nix   # User-level secret declarations + load-secrets script
home/roles/base.nix               # Imports home/modules/agenix
```

**`secrets.nix`** maps each `.age` file to its age recipient public keys:

```nix
let
  # Host SSH public keys
  wendigo  = "ssh-ed25519 AAAA...";
  kushtaka = "ssh-ed25519 AAAA...";
  snallygaster = "ssh-ed25519 AAAA...";
  allHosts = [ wendigo kushtaka snallygaster ];

  # User SSH public keys
  grue = "ssh-ed25519 AAAA...";
in {
  "secrets/hcPingKey.age".publicKeys     = allHosts;
  "secrets/grue/anthropic.age".publicKeys = [ grue ];
  # ... etc
}
```

**`home/modules/agenix/default.nix`** is the single source of truth for user
secrets. A `userSecrets` attrset drives both the agenix path declarations and
the generated `load-secrets` script:

```nix
userSecrets = {
  anthropic = {
    path = config.age.secrets.anthropic.path;
    envVar = "ANTHROPIC_API_KEY";
  };
  # ...
};
```

The `load-secrets` script reads each decrypted file and exports the env var,
skipping gracefully if a file is missing:

```bash
if [[ -r "/run/agenix/anthropic" ]]; then
  ANTHROPIC_API_KEY="$(< /run/agenix/anthropic)"
  export ANTHROPIC_API_KEY
fi
```

---

## Workflows

### New Host Prep (on any existing managed host)

This workflow runs **before** the new host exists. It can be performed from
any host with an active `op` session and a working `nix-config` checkout.

1. Create an SSH keypair for the new host in 1Password:
   - Vault: `Service`
   - Item name: `host-<hostname>` (e.g. `host-newmachine`)
   - Fields: `public_key`, `private_key`

2. Run `just prep-host <hostname>`:
   - Fetches `op://Service/host-<hostname>/public_key`
   - Saves to `nixos/hosts/<hostname>/ssh_host_ed25519_key.pub`
   - Adds host to `secrets.nix` recipients for all system secrets
   - Runs `agenix rekey` to re-encrypt system secrets for the new host
   - Commits and pushes via `jj`

3. Merge the PR (or push directly to main if permitted by CI)

4. **New host is now ready** — no further prep needed on the ISO

### ISO Bootstrap (on new host)

1. Preflight: `op whoami` — exit immediately with clear error if no active session
2. Fetch host private key:
   ```bash
   op read "op://Service/host-<hostname>/private_key" \
     > /etc/ssh/ssh_host_ed25519_key
   chmod 0600 /etc/ssh/ssh_host_ed25519_key
   ```
3. Partition disk and run:
   ```bash
   nixos-install --flake "github:asphaltbuffet/nix-config#<hostname>"
   ```
4. Reboot — agenix activates on first boot; system secrets are immediately available

### Adding a New User Secret

1. Add the item to 1Password `Private` vault (human-readable copy for app access)
2. Add entry to `userSecrets` in `home/modules/agenix/default.nix`
3. Add encrypted file: `agenix -e secrets/<username>/<name>.age`
4. Add entry to `secrets.nix` with the user's public key as recipient
5. Commit and push — no rekey needed (it's a new file, not re-encrypting existing)

### Adding a New Host to Existing Secrets

If a new host needs access to a secret it wasn't previously a recipient of:

1. Add host public key to the relevant entry in `secrets.nix`
2. Run `agenix rekey` on any existing host
3. Commit and push

### Rotating a Secret

1. Update the value in 1Password
2. Re-encrypt: `agenix -e secrets/<path>.age` (fetches fresh value via `op read`)
3. Commit and push — agenix will deliver the new value on next `nixos-rebuild`

---

## Implementation Plan

### Phase 1: Foundation
- [ ] Add `agenix` flake input and NixOS module to `flake.nix`
- [ ] Create `secrets.nix` with host and user public keys
- [ ] Create `nixos/common/agenix.nix` (system module)
- [ ] Create `home/modules/agenix/default.nix` (user module + `load-secrets`)
- [ ] Update `home/roles/base.nix` to import agenix module
- [ ] Update `nixos/profiles/base.nix` to import system agenix module
- [ ] Replace `home/modules/zsh/secrets.env` + `op inject` with `load-secrets` call

### Phase 2: Secrets
- [ ] Encrypt all user secrets for `grue`
- [ ] Encrypt system `hcPingKey` secret
- [ ] Update `nixos/common/autodeploy.nix` to read from agenix path

### Phase 3: Bootstrap tooling
- [ ] Create `just prep-host <hostname>` recipe
- [ ] Create `bootstrap-secrets` script for ISO use
- [ ] Remove `home/modules/zsh/secrets.env` file

### Phase 4: Review & Verification
- [ ] **Code review**: verify agenix module wiring, path references, no secrets leaked in Nix store
- [ ] **Security review**: confirm file permissions (0400 user secrets, 0400 system secrets), recipient lists (no over-sharing), secret files not world-readable
- [ ] **Documentation audit**: update `README.md` secrets section; update `CLAUDE.md` with new bootstrap steps and module patterns; update `docs/security/new-host-onboarding.md`
- [ ] **Env var tests**: verify `load-secrets` correctly exports all env vars from decrypted files; test graceful skip when files are missing; test that `jsquats` cannot read `grue`'s secrets

---

## Testing

### Env var loading tests

A NixOS test (or a simple shell script run in CI) should verify:

1. **Happy path**: given a populated agenix secret file, `load-secrets` exports
   the correct env var with the correct value
2. **Missing file**: `load-secrets` exits 0 and does not set the env var when
   the secret file is absent (e.g. on a host without the user's key)
3. **Empty file**: `load-secrets` exports an empty string rather than crashing
4. **No cross-user leakage**: a process running as `jsquats` cannot read files
   owned by `grue` (verified by file permissions)

These can be implemented as a NixOS VM test in `checks` or as a standalone
`pkgs.writeShellApplication` test script invoked via `just test-secrets`.

---

## Security Review Checklist

- [ ] No secret values appear in the Nix store (`.age` files are ciphertext;
  decrypted files live in `/run/agenix/` which is tmpfs, not the store)
- [ ] System secret files: owner `root`, mode `0400`
- [ ] User secret files: owner `<username>`, mode `0400`
- [ ] `secrets.nix` recipient lists are minimal — no host has access to another
  user's secrets
- [ ] SSH private keys fetched during bootstrap are written to tmpfs or
  immediately to their final path; never committed or logged
- [ ] `load-secrets` uses `VAR="$(...)"\nexport VAR` pattern (SC2155-safe)
- [ ] `bootstrap-secrets` script fails fast on missing `op` session; no partial
  state left on failure

---

## Documentation Audit

Files requiring updates after implementation:

| File | Required changes |
|---|---|
| `README.md` | Rewrite Secrets Management section: describe agenix + 1Password split, bootstrap workflow, `load-secrets` |
| `CLAUDE.md` | Add: agenix module pattern, `secrets.nix` conventions, `just prep-host` command, note that `secrets/` contains ciphertext (safe to commit) |
| `docs/security/new-host-onboarding.md` | Replace `op inject` references; add `prep-host` step; update bootstrap flow |

---

## Decision Log

**Why not opnix?**
1Password service accounts cannot access personal vaults (`Private`, `Shared`).
Per-user secrets require individual authentication — a service account is a
system actor, not a user proxy. opnix is the right tool for system-level shared
secrets in a team/org context; it's the wrong tool here.

**Why not keep `op inject`?**
Requires an interactive 1Password session at every shell startup. Fails silently
on SSH sessions to remote hosts unless the desktop app is running and approves
the biometric prompt. Not viable for headless dev work on remote hosts.

**Why agenix over alternatives (sops-nix, etc.)?**
agenix uses plain SSH keys as age identities — the same keys already in use for
SSH auth and in 1Password. No additional key material to manage. sops-nix
supports more backends but adds complexity not needed here.

**Why host keys in 1Password?**
Eliminates the bootstrap chicken-and-egg: the host's public key is known before
the host exists, so `agenix rekey` can run on any existing machine. The ISO only
needs `op read` — no repo write access, no jj, no existing host cooperation.
