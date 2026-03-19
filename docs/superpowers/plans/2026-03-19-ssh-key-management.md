# SSH Key Management Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a secure, reproducible SSH key management system using 1Password SSH agent for interactive auth, agenix for secret distribution, and just recipes for consistency — with no private key material ever unencrypted on disk.

**Architecture:** User private keys live exclusively in the 1Password vault and are accessed via the 1P SSH agent socket. Agenix secrets are re-encrypted to include keys for all managed hosts. A dedicated `home/modules/ssh/` home-manager module configures the SSH client, git signing, and 1P agent integration. New `just ssh-*` recipes cover key generation, rotation, and new-host onboarding.

**Tech Stack:** agenix (age encryption), 1Password SSH agent, home-manager `programs.ssh` + `programs.git.signing`, git/jj SSH signing, NixOS `services.openssh`, `just` recipes.

---

## Context & Threat Model

This repo is public on GitHub. The following must NEVER appear in the repo:
- Private key material (any `-----BEGIN ... PRIVATE KEY-----` blocks)
- Unencrypted secret values

What IS safe to commit:
- Public keys (ed25519 `ssh-ed25519 AAAA...` strings)
- `.age` encrypted files
- `secrets.nix` (contains only public keys)

## Key Architecture

```
┌─────────────────────────────────────────────────────────┐
│  1Password Vault                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │  grue-main (ed25519) ← primary identity key      │   │
│  │  Private key: NEVER leaves vault                 │   │
│  │  Public key: stored in secrets.nix + GitHub      │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
         │ SSH agent socket (no key material transferred)
         ▼
┌─────────────────────────────────────────────────────────┐
│  All machines (NixOS + Windows/Linux via 1P app)        │
│  ~/.ssh/config → IdentityAgent = 1P socket (abs. path) │
│  git → programs.git.signing.key = .pub file in store   │
│  jj  → signing.backend = ssh, key = .pub file in store │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  agenix decryption (nixos-rebuild only)                 │
│  Uses: host key /etc/ssh/ssh_host_ed25519_key           │
│  (system key, generated at install, separate from user) │
│  ALL secrets encrypted to users ++ systems — so host   │
│  key always works even if user key changes              │
└─────────────────────────────────────────────────────────┘
```

**Important distinction:**
- **User identity keys** (`grue`, `grue2` in secrets.nix) = keys for human auth → managed via 1P
- **Host system keys** (`wendigo`, `kushtaka`, `snallygaster` in secrets.nix) = `/etc/ssh/ssh_host_ed25519_key` → generated at install, used by agenix, unchanged by this plan

**Key insight on safe grue2 removal:** All secrets in `secrets.nix` use `publicKeys = users ++ systems`. The host key is always a recipient, so kushtaka can always decrypt secrets via its host key even after `grue2` is removed from `users`. No ordering problem exists.

## File Structure

### New Files
- `home/modules/ssh/default.nix` — SSH client config, 1P agent socket, git/jj signing
- `docs/security/ssh-key-management.md` — Human-readable runbook
- `docs/security/new-host-onboarding.md` — Step-by-step for bootstrapping a new machine (covers NixOS, Windows, non-NixOS Linux)

### Modified Files
- `secrets/secrets.nix` — Replace `grue`/`grue2` device-specific keys with single 1P-synced key
- `nixos/common/users.nix` — Update `openssh.authorizedKeys.keys` for grue user
- `home/users/grue.nix` — Import new ssh module
- `justfile` — Add `[group('ssh')]` section
- `nixos/profiles/base.nix` — Harden `services.openssh` settings

---

## Chunk 1: SSH Client Module + 1Password Agent

### Task 1: Create the SSH home-manager module

**Files:**
- Create: `home/modules/ssh/default.nix`

This module configures:
1. `programs.ssh` with 1Password agent as `IdentityAgent` (using absolute path via `config.home.homeDirectory`)
2. Git SSH signing via home-manager's typed `programs.git.signing` options (not raw settings keys)
3. jj SSH signing

> **Why `programs.git.signing` over raw `settings`?** Home-manager provides typed options for git signing that generate correct `.gitconfig` output. Using raw `settings` with a key name like `"gpg \"ssh\""` is fragile — alejandra can mangle quoted attribute keys, causing `just check` to fail. Always prefer the typed home-manager options when available.

- [ ] **Step 1: Verify the 1Password SSH agent socket path**

```bash
ls -la ~/.1password/agent.sock
```
Expected: a socket file exists when 1Password is running and SSH agent is enabled in Settings → Developer.

- [ ] **Step 2: Write the SSH module**

Create `home/modules/ssh/default.nix`:

```nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  # The public key used for git/jj commit signing.
  # Update this value after generating the key in 1Password (Task 2).
  # Format: "ssh-ed25519 AAAA... comment"
  signingKeyPub = "REPLACE_WITH_PUBLIC_KEY_FROM_1PASSWORD";

  # Write the public key to a file in the Nix store.
  # git and jj need a file path, not a string, to reference the signing key.
  signingKeyFile = pkgs.writeText "grue-signing.pub" signingKeyPub;
in {
  # SSH client configuration
  programs.ssh = {
    enable = true;

    # Route all SSH auth through 1Password agent.
    # Uses absolute path via config.home.homeDirectory to ensure correct
    # expansion in all contexts (interactive and non-interactive git operations).
    # Note: IdentityAgent with 1P means no key files on disk — 1P holds the private key.
    extraConfig = ''
      Host *
        IdentityAgent ${config.home.homeDirectory}/.1password/agent.sock
        ServerAliveInterval 60
        ServerAliveCountMax 3
    '';

    matchBlocks = {};
  };

  # Git SSH commit signing.
  # Using programs.git.signing (typed home-manager options) rather than
  # raw settings keys to avoid alejandra formatting issues with quoted attr names.
  programs.git = {
    signing = {
      format = "ssh";
      # The .pub file path tells git which key to request from the SSH agent.
      # The agent (1Password) performs the actual signing; no private key on disk.
      key = "${signingKeyFile}";
      sshCommand = "${lib.getExe' pkgs.openssh "ssh-keygen"}";
      signByDefault = true;
    };
  };

  # jujutsu commit signing via SSH
  programs.jujutsu.settings = {
    signing = {
      sign-all = true;
      backend = "ssh";
      key = "${signingKeyFile}";
    };
  };
}
```

- [ ] **Step 3: Track the new file with jj**

```bash
jj file track home/modules/ssh/default.nix
```

- [ ] **Step 4: Import the ssh module in grue's user config**

Modify `home/users/grue.nix` — add to the `imports` list:
```nix
../modules/ssh
```

- [ ] **Step 5: Format**

```bash
just fmt
```
Expected: alejandra runs silently (exit 0).

- [ ] **Step 6: Build all three hosts to verify no Nix errors**

```bash
just build wendigo && just build kushtaka && just build snallygaster
```
Expected: all three build successfully (signing key is a placeholder — fine for now).

- [ ] **Step 7: Commit**

```bash
jj commit -m "feat(ssh): add ssh client module with 1password agent integration"
```

---

### Task 2: Generate key in 1Password and update config

**Files:**
- Modify: `home/modules/ssh/default.nix` (replace placeholder)
- Modify: `secrets/secrets.nix` (replace grue/grue2 with single 1P key)
- Modify: `nixos/common/users.nix` (update authorized_keys)

This task requires manual interaction with the 1Password app.

- [ ] **Step 1: Generate SSH key in 1Password**

In the 1Password desktop app:
1. Open any vault → click `+` → New Item → SSH Key
2. Title: `grue-main`
3. Key type: `Ed25519` (fastest, most secure, smallest)
4. Click "Add Private Key" → "Generate"
5. Copy the **public key** (shown in the item, format: `ssh-ed25519 AAAA... grue-main`)

- [ ] **Step 2: Update the SSH module with the real public key**

Edit `home/modules/ssh/default.nix`, replace:
```nix
signingKeyPub = "REPLACE_WITH_PUBLIC_KEY_FROM_1PASSWORD";
```
with the actual public key string from 1Password.

- [ ] **Step 3: Update secrets.nix**

In `secrets/secrets.nix`, replace the device-specific `grue` and `grue2` entries
with a single key (1Password syncs it across all your machines):

```nix
let
  # User identity keys (managed via 1Password SSH agent — synced to all devices)
  grue = "ssh-ed25519 AAAA...";  # 1Password: grue-main

  # Remove grue2 — it was kushtaka-specific. 1P now serves all machines.
  # Safe to remove: all secrets use `users ++ systems`, so kushtaka's host
  # key (/etc/ssh/ssh_host_ed25519_key) can always decrypt secrets independently.

  jsquats = "ssh-ed25519 ...";  # unchanged
  sukey = "ssh-ed25519 ...";    # unchanged

  users = [
    grue
    jsquats
    sukey
  ];

  # systems block unchanged
  wendigo = "...";
  kushtaka = "...";
  snallygaster = "...";

  systems = [wendigo kushtaka snallygaster];
in {
  # secret definitions unchanged
}
```

- [ ] **Step 4: Update authorized_keys in users.nix**

Edit `nixos/common/users.nix`, update `openssh.authorizedKeys.keys` for grue:
```nix
openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAA... grue-main"  # 1Password: grue-main
];
```

- [ ] **Step 5: Re-encrypt all secrets with updated keys**

```bash
just secret-rekey
```
Expected: agenix re-encrypts all `.age` files with the new key set. Verify the `.age` files changed:
```bash
jj diff secrets/
```

- [ ] **Step 6: Add the public key to GitHub**

In GitHub Settings → SSH and GPG keys:
1. Add the public key as an **Authentication Key** (for git push/clone/SSH)
2. Add the same public key as a **Signing Key** (for verified commit badges)

- [ ] **Step 7: Build all three hosts**

```bash
just build wendigo && just build kushtaka && just build snallygaster
```

- [ ] **Step 8: Commit**

```bash
jj commit -m "feat(ssh): replace device-specific keys with 1password-managed identity key"
```

---

## Chunk 2: OpenSSH Server Hardening

### Task 3: Harden sshd configuration

**Files:**
- Modify: `nixos/profiles/base.nix` — add hardened openssh settings

Currently `base.nix` only sets `services.openssh.enable = lib.mkDefault true`. This task adds security hardening: disable password auth, disable root login, restrict to ed25519 host keys only.

> **Why `lib.mkDefault` on `enable` but not on the settings?** `lib.mkDefault` gives a setting the lowest priority, allowing per-host config to override without `lib.mkForce`. The security settings below use plain assignment — they apply everywhere and a host must explicitly use `lib.mkForce` to override. This is intentional: security hardening should be the default that requires deliberate effort to relax.

- [ ] **Step 1: Add hardened openssh config to base.nix**

In `nixos/profiles/base.nix`, replace:
```nix
services.openssh.enable = lib.mkDefault true;
```
with:
```nix
services.openssh = {
  enable = lib.mkDefault true;
  settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
  };
  # Restrict to ed25519 only — removes weaker RSA/ECDSA/DSA host keys.
  # NixOS generates this key automatically on first boot.
  hostKeys = [
    {
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];
};
```

- [ ] **Step 2: Build all three hosts**

```bash
just build wendigo && just build kushtaka && just build snallygaster
```
Expected: clean builds.

- [ ] **Step 3: Apply and verify you can still SSH in**

```bash
just test wendigo
ssh -o BatchMode=yes localhost echo "SSH works"
```
Expected: `SSH works` (if running locally), or verify from another terminal that SSH connections succeed.

- [ ] **Step 4: Commit**

```bash
jj commit -m "feat(security): harden openssh — keys only, no root, ed25519 host key"
```

---

## Chunk 3: just Recipes for SSH Key Management

### Task 4: Add ssh-* recipe group to justfile

**Files:**
- Modify: `justfile` — add `[group('ssh')]` section after the secrets group

Notes on recipe design:
- `ssh-pubkey`: uses `op item get` with `label=` syntax (field name case-insensitive workaround)
- `ssh-verify`: uses `git config gpg.format` (not `--global`) to read effective merged value — avoids legacy `~/.gitconfig` shadowing home-manager's config
- `ssh-add-host`: is intentionally advisory (prints instructions) — it cannot safely automate edits to `secrets.nix` without risking parse errors

- [ ] **Step 1: Add recipes to justfile**

Add after the `# Secrets (agenix)` section:

```just
# ─────────────────────────────────────────────────────────────────────────────
# SSH Key Management
# ─────────────────────────────────────────────────────────────────────────────

# Show the current SSH public key from 1Password (for adding to servers/GitHub)
[group('ssh')]
ssh-pubkey:
    @op item get "grue-main" --fields label="public key" 2>/dev/null || \
        echo "Error: 1Password CLI not authenticated. Run: op signin"

# Verify 1Password SSH agent is running and keys are available
[group('ssh')]
ssh-agent-check:
    #!/usr/bin/env bash
    set -euo pipefail
    socket="$HOME/.1password/agent.sock"
    if [[ -S "$socket" ]]; then
        echo "✓ 1Password SSH agent socket exists"
        if SSH_AUTH_SOCK="$socket" ssh-add -l &>/dev/null; then
            echo "✓ Agent is responding with keys"
        else
            echo "✗ Agent socket exists but no keys returned"
            echo "  Is 1Password unlocked? Is SSH agent enabled in Settings → Developer?"
            exit 1
        fi
    else
        echo "✗ Agent socket not found at $socket"
        echo "  Start 1Password and enable SSH agent in Settings → Developer"
        exit 1
    fi

# Guided SSH key rotation workflow
[group('ssh')]
ssh-rotate:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== SSH Key Rotation Guide ==="
    echo ""
    echo "Step 1: Generate a new SSH key in 1Password:"
    echo "  New Item → SSH Key → name: grue-main-$(date +%Y%m) → Ed25519 → Generate"
    echo "  Copy the public key."
    echo ""
    echo "Step 2: Update home/modules/ssh/default.nix:"
    echo "  Replace signingKeyPub with the new public key string."
    echo ""
    echo "Step 3: Update secrets/secrets.nix:"
    echo "  Replace the grue public key entry."
    echo ""
    echo "Step 4: Update nixos/common/users.nix:"
    echo "  Replace openssh.authorizedKeys.keys entry for grue."
    echo ""
    echo "Step 5: just secret-rekey"
    echo "Step 6: just switch (on all hosts)"
    echo "Step 7: Update GitHub SSH keys (auth + signing)."
    echo "Step 8: Update authorized_keys on any external servers."
    echo ""
    echo "Verify with: just ssh-verify"

# Verify SSH + signing setup end-to-end
[group('ssh')]
ssh-verify:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== SSH Setup Verification ==="
    echo ""

    # Agent check
    socket="$HOME/.1password/agent.sock"
    if [[ -S "$socket" ]] && SSH_AUTH_SOCK="$socket" ssh-add -l &>/dev/null; then
        echo "✓ 1Password SSH agent: OK"
    else
        echo "✗ 1Password SSH agent: NOT RESPONDING"
    fi

    # GitHub auth
    echo -n "  GitHub SSH auth: "
    if SSH_AUTH_SOCK="$socket" ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        echo "✓ OK"
    else
        echo "✗ FAILED (debug: SSH_AUTH_SOCK=$socket ssh -T git@github.com)"
    fi

    # Git signing config — use 'git config' (no --global) to read effective merged value.
    # This avoids a legacy ~/.gitconfig from shadowing home-manager's config.
    echo -n "  Git signing: "
    if git config gpg.format 2>/dev/null | grep -q "ssh"; then
        echo "✓ SSH signing configured"
    else
        echo "✗ Not configured (check home/modules/ssh/default.nix)"
    fi

    echo ""
    echo "Done."

# Print instructions for adding a new host's public key to secrets.nix
# Usage: just ssh-add-host <hostname> <pubkey>
# Example: just ssh-add-host myserver "ssh-ed25519 AAAA..."
# NOTE: This recipe is advisory — it prints instructions but does not edit files.
[group('ssh')]
ssh-add-host hostname pubkey:
    @echo "1. Add to secrets/secrets.nix in the 'let' block:"
    @echo "     {{ hostname }} = \"{{ pubkey }}\";"
    @echo ""
    @echo "2. Add '{{ hostname }}' to the systems = [...] list."
    @echo ""
    @echo "3. Run: just secret-rekey && just switch"
```

- [ ] **Step 2: Verify just syntax**

```bash
just --list
```
Expected: `ssh` group appears with five new recipes.

- [ ] **Step 3: Test ssh-agent-check (requires 1Password running)**

```bash
just ssh-agent-check
```
Expected: `✓ 1Password SSH agent: OK` and `✓ Agent is responding with keys`.

- [ ] **Step 4: Commit**

```bash
jj commit -m "feat(ssh): add just ssh-* recipe group for key management"
```

---

## Chunk 4: Documentation

### Task 5: Write security runbook and onboarding docs

**Files:**
- Create: `docs/security/ssh-key-management.md`
- Create: `docs/security/new-host-onboarding.md`

> The `docs/security/` directory must be created first since it is new:
> ```bash
> mkdir -p docs/security
> ```

- [ ] **Step 1: Create the directory**

```bash
mkdir -p docs/security
```

- [ ] **Step 2: Write the main SSH runbook**

Create `docs/security/ssh-key-management.md`:

```markdown
# SSH Key Management

## Architecture

This repo uses a hybrid SSH key model:

| Layer | Tool | Where key lives |
|-------|------|-----------------|
| Interactive SSH auth | 1Password SSH agent | 1P vault only |
| Git/jj commit signing | 1Password SSH agent | 1P vault only |
| agenix decryption | Host system key | `/etc/ssh/ssh_host_ed25519_key` |

Private key material for user identity **never exists as a file on disk**.
The 1Password agent signs operations without exposing key material.

## Daily Use

### SSH to a server
```bash
ssh user@server
# 1Password prompts for biometric/password approval
```

### See git/jj commit signatures
```bash
jj log -r @ --template 'if(signature, "signed", "unsigned") ++ "\n"'
```

### Add your key to a new server
```bash
just ssh-pubkey          # prints your public key
ssh-copy-id user@server  # or paste manually into authorized_keys
```

## Key Rotation
```bash
just ssh-rotate
```
Follow the guided steps. The old key stays valid until you remove it from servers and GitHub.

## Verifying Your Setup
```bash
just ssh-verify
```

## Adding a New NixOS Host to agenix

```bash
# 1. On the new host, get its system SSH public key:
cat /etc/ssh/ssh_host_ed25519_key.pub

# 2. In this repo, follow the guided instructions:
just ssh-add-host <hostname> "<pubkey from step 1>"

# 3. Re-encrypt and deploy:
just secret-rekey
just switch
```

## Security Notes

- Only ed25519 keys are used (RSA and ECDSA host keys are disabled in `nixos/profiles/base.nix`)
- Password authentication is disabled on all hosts (SSH keys only)
- Root login is disabled
- All secrets are encrypted to both user keys AND host keys, so secrets remain
  accessible via the host key even during user key rotation
```

- [ ] **Step 3: Write new-host onboarding doc (covers NixOS, Windows, Linux)**

Create `docs/security/new-host-onboarding.md`:

```markdown
# New Host Onboarding

## NixOS Hosts (managed by this flake)

### Prerequisites
- Access to this repo on an existing managed machine

### Steps

**1. Install NixOS** using the installer ISO:
```bash
just iso    # build the ISO
just vm     # test it in QEMU (optional)
# Flash with: dd if=result/iso/*.iso of=/dev/sdX bs=4M
```
The installer generates `/etc/ssh/ssh_host_ed25519_key` automatically.

**2. Get the new host's public key** (run on the new machine):
```bash
cat /etc/ssh/ssh_host_ed25519_key.pub
```

**3. Add the host to this repo** (run on an existing managed machine):
```bash
just ssh-add-host <hostname> "<pubkey from step 2>"
# Follow the printed instructions to edit secrets/secrets.nix
just secret-rekey
jj commit -m "feat: add <hostname> to agenix recipients"
```

**4. Deploy to the new host:**
```bash
just switch <hostname>
```
agenix decrypts secrets using the host's system key (no user key needed).

**5. Install 1Password and enable SSH agent:**
- Download from https://1password.com/downloads/linux/
- Sign in → Settings → Developer → Enable SSH Agent
- Your `grue-main` key appears automatically (synced from vault)

**6. Verify:**
```bash
just ssh-verify
```

---

## Windows Hosts (non-managed)

**1. Install 1Password for Windows** from https://1password.com/downloads/windows/

**2. Enable the SSH agent:**
- Settings → Developer → Use the SSH agent
- This creates a named pipe: `\\.\pipe\openssh-ssh-agent`

**3. Configure OpenSSH client** (Windows 10/11 has OpenSSH built in):

Edit or create `%USERPROFILE%\.ssh\config`:
```
Host *
    IdentityAgent \\.\pipe\openssh-ssh-agent
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

**4. Add your public key to any servers** you need to access:
- In 1Password, open the `grue-main` item and copy the public key
- Paste into `~/.ssh/authorized_keys` on the target server

**5. Configure git signing** (optional — if using git on this machine):
```bash
git config --global gpg.format ssh
git config --global user.signingkey "ssh-ed25519 AAAA..."  # your public key
git config --global commit.gpgsign true
```

---

## Non-NixOS Linux Hosts (non-managed)

**1. Install 1Password for Linux** from https://1password.com/downloads/linux/

**2. Enable the SSH agent:**
- Settings → Developer → Use the SSH agent
- Socket path: `~/.1password/agent.sock`

**3. Configure SSH client:**

Edit or create `~/.ssh/config`:
```
Host *
    IdentityAgent ~/.1password/agent.sock
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

**4. Add your public key to servers** you need to access (same as Windows step 4).

**5. Configure git signing** (same as Windows step 5).

**6. Verify:**
```bash
SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l  # should show your key
ssh -T git@github.com                              # should authenticate
```
```

- [ ] **Step 4: Track new files with jj**

```bash
jj file track docs/security/ssh-key-management.md docs/security/new-host-onboarding.md
```

- [ ] **Step 5: Commit**

```bash
jj commit -m "docs(security): add ssh key management runbook and multi-platform onboarding guide"
```

---

## Chunk 5: Integration and Final Verification

### Task 6: End-to-end verification

**Files:** None (verification only)

- [ ] **Step 1: Full format + flake check**

```bash
just fmt && just check
```
Expected: alejandra runs silently, `nix flake check` passes (includes all three hosts).

- [ ] **Step 2: Switch to new config**

```bash
just switch
```

- [ ] **Step 3: Run all ssh-* verifications**

```bash
just ssh-agent-check
just ssh-verify
```

- [ ] **Step 4: Verify GitHub SSH auth**

```bash
ssh -T git@github.com
```
Expected: `Hi asphaltbuffet! You've successfully authenticated...`

- [ ] **Step 5: Test signed commit then abandon**

```bash
# In the nix-config repo:
jj commit -m "test: verify ssh signing end-to-end"
jj log -r @ --template 'commit_id ++ " " ++ if(signature, "SIGNED", "UNSIGNED") ++ "\n"'
# Expected: SIGNED
jj abandon @
```

- [ ] **Step 6: Final commit**

```bash
jj commit -m "feat: complete ssh key management system with 1password agent integration"
```

---

## Out of Scope (Documented Decisions)

- **Per-device user keys**: Rejected in favor of 1Password vault sync. One key = one identity = easier revocation. Less key sprawl.
- **YubiKey/FIDO2**: More secure than software vault for high-value targets (no network attack surface), but adds hardware dependency. Can be layered on top later if needed.
- **SSH CA (Certificate Authority)**: Overkill for a personal homelab with 3 hosts. Revisit if the fleet grows beyond ~10 or if short-lived cert issuance becomes valuable.
- **Separate signing vs auth keys**: GitHub supports distinct keys for these roles, but it doubles key management burden. 1P agent handles both cleanly with one key.
- **`allowed_signers` file for jj verification**: jj can validate signatures against a trusted set if `signing.allowed-signers` is configured. Skipped here as this is a personal repo with a single signing identity — verification is implied. Add it if collaboration or auditability requirements grow.
