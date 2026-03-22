# Remove Stale agenix References from Docs and Bootstrap Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove all remaining agenix/secret-rekey references from user-facing documentation and the live bootstrap script, replacing them with the current 1Password + persistent Tailscale state workflow.

**Architecture:** Three independent edits across four files. Each task is self-contained and can be reviewed independently. No new files are created — only targeted edits to existing content. Planning docs (`iso_plan.md`, old superpowers plans) are intentionally left as historical record.

**Tech Stack:** bash (bootstrap.sh), Markdown (docs), jujutsu (jj) for commits.

---

## Scope & Files

| File | Change |
|------|--------|
| `nixos/installer/bootstrap.sh` | Replace the entire "KEY CONCEPT: why rekeying" heredoc block and `secrets/secrets.nix` editing/rekeying instructions with post-install Tailscale + 1Password steps |
| `docs/security/new-host-onboarding.md` | Remove `just secret-rekey` and agenix references from the NixOS host steps |
| `docs/security/ssh-key-management.md` | Remove the agenix architecture table row and the entire "Adding a New NixOS Host to agenix" section |
| `README.md` | Fix one line: remove "before secrets are re-encrypted" from the bootstrap helper bullet |

---

## Context: What the New Workflow Is

After the agenix → 1Password migration, adding a new host requires:

1. Boot ISO, run `nixos-bootstrap` (generates hardware config and host SSH key)
2. On an existing machine: SCP the host files, commit, push (no `secrets/secrets.nix`, no `secret-rekey`)
3. On the live ISO: `nixos-install --flake github:asphaltbuffet/nix-config#<hostname> && reboot`
4. First boot: `sudo tailscale up --auth-key <key>` (one-time only; state persists thereafter)
5. Sign in to 1Password — API keys (`GORELEASER_KEY`, `ANTHROPIC_API_KEY`) inject automatically in new shells

There is no longer a requirement to pre-generate the host SSH key for secrets decryption. The host SSH key is still generated (for SSH access to the machine), but it plays no role in secrets management.

---

## Task 1: Fix `bootstrap.sh` — Replace agenix heredoc block

**Files:**
- Modify: `nixos/installer/bootstrap.sh` (the `build_instructions()` function, lines ~256–324)

The stale content lives in two places:
- **File header comments** (lines 8 and 13) — the top-of-file description mentions rekeying
- **`cat <<INSTRUCTIONS` heredoc** in `build_instructions()` — the bulk of the stale content

Changes required:
1. Fix line 8: `(pubkey needed before rekeying)` → `(for SSH access to the installed system)`
2. Fix line 13: remove mention of editing `secrets.nix` and rekeying
3. Remove the entire "KEY CONCEPT: why rekeying needs an existing machine" block
4. Remove the `$EDITOR secrets/secrets.nix` instruction and its surrounding comments
5. Remove the `just secret-rekey` line
6. Remove the "Do NOT wipe /mnt/etc/ssh/... agenix can decrypt secrets on first boot" warning
7. Add a short post-install section explaining Tailscale auth and 1Password

- [ ] **Step 1: Read the current `build_instructions()` function and file header**

```bash
grep -n "KEY CONCEPT\|secret-rekey\|secrets\.nix\|agenix\|rekeying" nixos/installer/bootstrap.sh
```

Confirm all lines that need changing before editing.

- [ ] **Step 2: Fix file header comments (lines 8 and 13)**

Replace line 8:
```bash
#   4. Pre-generates the host SSH keypair (pubkey needed before rekeying)
```
With:
```bash
#   4. Pre-generates the host SSH keypair (for SSH access to the installed system)
```

Replace line 13:
```bash
#      to edit secrets.nix, rekey, commit, and push
```
With:
```bash
#      to commit and push
```

- [ ] **Step 3: Replace the heredoc content**

In `nixos/installer/bootstrap.sh`, find the `cat <<INSTRUCTIONS` heredoc in `build_instructions()`. Make the following targeted replacements:

**Remove this entire block** (the KEY CONCEPT section, ~lines 257–267):
```
==========================================
  KEY CONCEPT: why rekeying needs an existing machine
==========================================

agenix encrypts each secret to a list of public keys. Re-encrypting (rekeying)
requires DECRYPTING the current secrets first — which needs a private key that
is already authorized (your user SSH key or an existing host key). The new
host's private key is only on /mnt/etc/ssh/ and is not yet trusted, so rekeying
CANNOT be done from the new machine. You add the new host's public key to
secrets.nix, then rekey on an existing machine so the installed system can
decrypt secrets on first boot.
```

**Replace the NEXT STEPS section** — remove the `secrets/secrets.nix` editing block and `just secret-rekey` line. The new NEXT STEPS section should read:

```
==========================================
  NEXT STEPS — run on an existing host
==========================================

  cd ~/nix-config   # or wherever your checkout is

${scp_block}

  # Review/edit the configuration if needed
  \$EDITOR nixos/hosts/${HOSTNAME}/configuration.nix

  # Track and commit (jj — do NOT use git add)
  jj file track nixos/hosts/${HOSTNAME}/configuration.nix
  jj file track nixos/hosts/${HOSTNAME}/hardware-configuration.nix
  jj commit -m 'feat: add host ${HOSTNAME}'
  jj git push -c @-
```

**Replace the "BACK ON THIS LIVE ISO" section** — remove the agenix warning. New content:

```
==========================================
  BACK ON THIS LIVE ISO — after the push completes
==========================================

  # Verify the flake sees the new host (optional sanity check)
  nix flake show ${FLAKE_REPO}

  # Install
  nixos-install --flake ${FLAKE_REPO}#${HOSTNAME}

  # Reboot
```

**Add a new POST-INSTALL section** after the reboot line, before MISC NOTES:

```
==========================================
  POST-INSTALL (first boot)
==========================================

  # Authenticate Tailscale (one-time — state persists across reboots)
  sudo tailscale up --auth-key <your-auth-key>

  # Sign in to 1Password (CLI)
  op signin

  # API keys (GORELEASER_KEY, ANTHROPIC_API_KEY) will be available
  # automatically in new shells once 1Password is unlocked.
```

- [ ] **Step 4: Verify no agenix references remain in the script**

```bash
grep -n "agenix\|secret-rekey\|secrets\.nix\|rekeying" nixos/installer/bootstrap.sh
```

Expected: zero matches.

- [ ] **Step 5: Smoke-test the script is still valid bash**

```bash
bash -n nixos/installer/bootstrap.sh
```

Expected: no syntax errors (silent exit 0).

- [ ] **Step 6: Commit**

```bash
just fmt  # no-op for .sh but harmless
jj describe -m "fix(bootstrap): remove agenix rekeying instructions; add Tailscale + 1Password post-install steps"
jj new
```

---

## Task 2: Fix `docs/security/new-host-onboarding.md`

**Files:**
- Modify: `docs/security/new-host-onboarding.md`

The NixOS host section (steps 3 and 4) references `just secret-rekey` and agenix decryption. Replace with the current workflow.

- [ ] **Step 1: Read the current NixOS section**

Read lines 1–44 of `docs/security/new-host-onboarding.md` to confirm the exact content.

- [ ] **Step 2: Replace step 3**

Replace:
```markdown
**3. Add the host to this repo** (run on an existing managed machine):
```bash
just ssh-add-host <hostname> "<pubkey from step 2>"
# Follow the printed instructions to edit secrets/secrets.nix
just secret-rekey
jj commit -m "feat: add <hostname> to agenix recipients"
```
```

With:
```markdown
**3. Add the host to this repo** (run on an existing managed machine):
```bash
# The nixos-bootstrap script prints the exact scp commands to run.
# After copying files:
jj file track nixos/hosts/<hostname>/configuration.nix
jj file track nixos/hosts/<hostname>/hardware-configuration.nix
jj commit -m "feat: add host <hostname>"
jj git push -c @-
```
```

- [ ] **Step 3: Replace step 4**

Replace:
```markdown
**4. Deploy to the new host:**
```bash
just switch <hostname>
```
agenix decrypts secrets using the host's system key (no user key needed).
```

With:
```markdown
**4. Install and first boot:**
```bash
# On the live ISO, after the push completes:
nixos-install --flake github:asphaltbuffet/nix-config#<hostname>
reboot
```

On first boot, authenticate Tailscale (one-time — state persists across reboots):
```bash
sudo tailscale up --auth-key <your-auth-key>
```
```

- [ ] **Step 4: Verify no stale references remain**

```bash
grep -n "agenix\|secret-rekey\|secrets\.nix" docs/security/new-host-onboarding.md
```

Expected: zero matches.

- [ ] **Step 5: Commit**

```bash
jj describe -m "docs(onboarding): remove agenix steps; document Tailscale first-boot auth"
jj new
```

---

## Task 3: Fix `docs/security/ssh-key-management.md` and `README.md`

**Files:**
- Modify: `docs/security/ssh-key-management.md`
- Modify: `README.md`

These are two small targeted edits, grouped into one task and one commit.

- [ ] **Step 1: Fix `ssh-key-management.md` — architecture table**

Remove the agenix row from the table. Replace:
```markdown
| Layer | Tool | Where key lives |
|-------|------|-----------------|
| Interactive SSH auth | 1Password SSH agent | 1P vault only |
| Git/jj commit signing | 1Password SSH agent | 1P vault only |
| agenix decryption | Host system key | `/etc/ssh/ssh_host_ed25519_key` |
```

With:
```markdown
| Layer | Tool | Where key lives |
|-------|------|-----------------|
| Interactive SSH auth | 1Password SSH agent | 1P vault only |
| Git/jj commit signing | 1Password SSH agent | 1P vault only |
| API key injection | 1Password CLI (`op inject`) | 1P vault only |
```

- [ ] **Step 2: Fix `ssh-key-management.md` — remove stale "Adding a New NixOS Host to agenix" section**

Remove the entire section:
```markdown
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
```

Replace with a short updated section:
```markdown
## Adding a New NixOS Host

Use the ISO bootstrap process — run `nixos-bootstrap` on the live installer,
then follow the printed instructions. See
[`docs/security/new-host-onboarding.md`](new-host-onboarding.md) for the
full walkthrough.
```

- [ ] **Step 3: Fix the last stale Security Notes bullet in `ssh-key-management.md`**

Remove the final bullet that references agenix:
```
- All secrets are encrypted to both user keys AND host keys, so secrets remain
  accessible via the host key even during user key rotation
```

This no longer applies — there are no encrypted secrets in the repo.

- [ ] **Step 4: Fix `README.md` — one stale comment**

Find and replace (line ~94):
```markdown
- Pre-generate the host SSH key at `/mnt/etc/ssh/ssh_host_ed25519_key`
  (so the public key is known before secrets are re-encrypted)
```

With:
```markdown
- Pre-generate the host SSH key at `/mnt/etc/ssh/ssh_host_ed25519_key`
  (needed for SSH access to the installed system)
```

- [ ] **Step 5: Verify no stale references remain in either file**

```bash
grep -n "agenix\|secret-rekey\|secrets\.nix\|re-encrypted" docs/security/ssh-key-management.md README.md
```

Expected: zero matches.

- [ ] **Step 6: Commit**

```bash
jj describe -m "docs(security): remove stale agenix references from ssh-key-management and README"
jj new
```

---

## Verification

After all three tasks, run a final sweep:

```bash
grep -rn "agenix\|secret-rekey\|secrets\.nix\|just secret-\|rekeying\|re-encrypted" \
  nixos/installer/bootstrap.sh \
  docs/security/ \
  README.md
```

Expected: zero matches (excluding planning docs and the migration rationale doc, which intentionally document what was removed).

The `just ssh-add-host` recipe in `justfile` still exists but no active docs reference it after this plan executes — it becomes a vestigial recipe. It can be removed in a follow-up cleanup pass; it is intentionally out of scope here.

---

## Notes

- **Planning docs** (`iso_plan.md`, `docs/superpowers/plans/2026-03-19-ssh-key-management.md`, `docs/superpowers/plans/2026-03-19-replace-agenix-with-1password.md`) are intentionally left unchanged — they are historical records of decisions made, not active user-facing docs.
- **`bootstrap.sh` is a bash heredoc** — use the Edit tool with exact string matching to replace the stale block. Read the file first to get exact whitespace and quoting before editing.
- **`bash -n`** validates bash syntax without executing the script — always run it after editing `bootstrap.sh`.
- **jj commits**: use `jj describe -m "..."` then `jj new` (never `git commit`). Never use `git add`.
