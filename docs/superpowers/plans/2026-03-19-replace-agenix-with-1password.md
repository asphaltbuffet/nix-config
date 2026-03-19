# Replace agenix with 1Password Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove agenix from the flake entirely, replacing it with `op inject` for user-session secrets (goreleaser, anthropic) and persistent Tailscale node state for the auth key.

**Architecture:** The two user-level API keys (`goreleaser`, `anthropic`) are injected into zsh at shell startup via `op inject` reading from a template file in the Nix store. The Tailscale secret is eliminated entirely — each host is authenticated once interactively and relies on `/var/lib/tailscale/` persisting across reboots (standard NixOS behavior). Agenix is then fully removed from the flake, profile, and home-manager config.

**Tech Stack:** 1Password CLI (`op`), NixOS `programs._1password`/`programs._1password-gui` (already configured), home-manager `programs.zsh`, `services.tailscale` (built-in nixpkgs module).

---

## Scope & Files

### Files Modified

| File | Change |
|------|--------|
| `home/users/grue.nix` | Remove `age.secrets.*` declarations and `cat`-based env var sourcing; add `op inject` template path |
| `home/modules/zsh/default.nix` | Add `op inject` call to `initContent` |
| `nixos/common/tailscale.nix` | Remove `age.secrets.tailscale`; remove `tailscale-autoconnect` systemd service; switch to built-in `services.tailscale.authKeyFile = null` (implicit) |
| `nixos/profiles/base.nix` | Remove `inputs.agenix.nixosModules.default` import |
| `flake.nix` | Remove `agenix` input, remove from `specialArgs`, `packages`, `devShell`, `mkInstaller` (8 occurrences total) |
| `secrets/secrets.nix` | Remove `goreleaser.age` and `anthropic.age` entries (keep `tailscale.age` as archive until manual rekey, then delete) |

### Files Deleted

| File | When |
|------|------|
| `secrets/goreleaser.age` | Task 3 |
| `secrets/anthropic.age` | Task 3 |
| `secrets/tailscale.age` | Task 4 (after both hosts confirmed authenticated) |
| `secrets/secrets.nix` | Task 5 (after all .age files deleted) |

### Files Created

| File | Purpose |
|------|---------|
| `home/modules/zsh/secrets.env` | `op inject` template with `op://` references for goreleaser and anthropic keys |
| `docs/security/secrets-migration-agenix-to-1password.md` | Research notes and migration rationale |

---

## Pre-Flight Checks

Before starting, verify on both hosts:

```bash
# 1Password CLI available
op --version

# 1Password desktop app running and unlocked
op account list

# Tailscale currently authenticated
tailscale status
```

If `tailscale status` shows `Running` on both hosts, the persistent-state approach will work without any auth key at all.

---

## Task 1: Write Research Document

**Files:**
- Create: `docs/security/secrets-migration-agenix-to-1password.md`

- [ ] **Step 1: Create the research document**

```markdown
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

After that, the `tailscale-autoconnect` systemd service (or the built-in `services.tailscale` reconnect logic) will find state = `Running` and skip re-authentication.

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
```

- [ ] **Step 2: Commit**

```bash
jj describe -m "docs(security): document agenix → 1Password migration rationale"
jj new
```

---

## Task 2: Add 1Password Items for API Keys

This task is done manually in the 1Password desktop app. The plan records the expected vault/item structure so the Nix config can reference them.

- [ ] **Step 1: Create or locate the GoReleaser item in 1Password**

In the 1Password app:
- Vault: `Personal` (or your preferred vault)
- Item: `GoReleaser`
- Field: `credential` (or `api key`)
- Value: paste the GoReleaser API key (retrieve from `just secret-edit goreleaser` before deleting the .age file)

- [ ] **Step 2: Create or locate the Anthropic item in 1Password**

- Vault: `Personal`
- Item: `Anthropic`
- Field: `credential`
- Value: paste the Anthropic API key (retrieve from `just secret-edit anthropic` before deleting)

- [ ] **Step 3: Note the exact `op://` references**

Run to confirm the reference URIs:

```bash
op item get "GoReleaser" --vault Personal --format json | jq '.fields[] | select(.label | ascii_downcase | contains("credential")) | .reference'
op item get "Anthropic" --vault Personal --format json | jq '.fields[] | select(.label | ascii_downcase | contains("credential")) | .reference'
```

Expected output (adjust if vault/field names differ):
```
"op://Personal/GoReleaser/credential"
"op://Personal/Anthropic/credential"
```

- [ ] **Step 4: Verify injection works**

```bash
echo 'export TEST="op://Personal/GoReleaser/credential"' | op inject
```

Expected: `export TEST="glpat-..."` with the actual key value.

---

## Task 3: Create the zsh secrets template and wire up `op inject`

**Files:**
- Create: `home/modules/zsh/secrets.env`
- Modify: `home/modules/zsh/default.nix`
- Modify: `home/users/grue.nix`

- [ ] **Step 1: Create the `op inject` template**

Create `home/modules/zsh/secrets.env` with the op:// references found in Task 2:

```
export GORELEASER_KEY="op://Personal/GoReleaser/credential"
export ANTHROPIC_API_KEY="op://Personal/Anthropic/credential"
```

Adjust vault/item/field names to match what you created in Task 2.

- [ ] **Step 2: Track the new file with jj**

```bash
jj file track home/modules/zsh/secrets.env
```

- [ ] **Step 3: Read `home/modules/zsh/default.nix` to find the `initContent` location**

Look for `programs.zsh.initContent`. Note the exact current content.

- [ ] **Step 4: Add `op inject` to zsh `initContent`**

In `home/modules/zsh/default.nix`, add to `programs.zsh.initContent` (this is the option used in this codebase — not `initExtra`):

```nix
programs.zsh.initContent = ''
  # existing content...

  # Inject 1Password secrets if op is available and signed in
  if command -v op &>/dev/null; then
    eval "$(op inject --in-file ${./secrets.env} 2>/dev/null)" || true
  fi
'';
```

The `${./secrets.env}` Nix path interpolation makes home-manager copy the template to the Nix store and substitute the store path at activation. The actual secret values are fetched at runtime, never stored in the Nix store.

- [ ] **Step 5: Remove `age.secrets` from `home/users/grue.nix`**

In `home/users/grue.nix`, remove these lines:

```nix
# Remove:
age.secrets.goreleaser.file = ../../secrets/goreleaser.age;
age.secrets.anthropic.file = ../../secrets/anthropic.age;
```

And remove from `programs.zsh.initContent` (wherever the `cat` calls appear):

```bash
# Remove:
export GORELEASER_KEY="$(cat "${config.age.secrets.goreleaser.path}")"
export ANTHROPIC_API_KEY="$(cat "${config.age.secrets.anthropic.path}")"
```

Also remove the agenix home-manager module import from `home/users/grue.nix`:

```nix
# Remove:
inputs.agenix.homeManagerModules.default
```

- [ ] **Step 6: Build and test (do not switch yet)**

```bash
just build
```

Expected: build succeeds with no agenix references in the home-manager config for grue.

- [ ] **Step 7: Test injection manually before switching**

```bash
op inject --in-file home/modules/zsh/secrets.env
```

Expected: both `export` lines with real values substituted.

- [ ] **Step 8: Format and commit**

```bash
just fmt
jj file track home/modules/zsh/secrets.env  # if not already tracked
jj describe -m "feat(secrets): inject goreleaser and anthropic keys via op inject in zsh"
jj new
```

---

## Task 4: Simplify Tailscale — Remove the Custom Autoconnect Service

**Files:**
- Modify: `nixos/common/tailscale.nix`

**Pre-condition:** Both hosts must currently show `tailscale status` as `Running`. Verify before proceeding. If either host shows `NeedsLogin`, authenticate it first:

```bash
sudo tailscale up --auth-key <key>  # one-time only
```

- [ ] **Step 1: Read current `nixos/common/tailscale.nix`**

Note the full current content before editing.

- [ ] **Step 2: Rewrite `nixos/common/tailscale.nix`**

Replace the entire file with the simplified version (no agenix secret, no custom systemd service):

```nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  services.tailscale.enable = true;

  networking = {
    firewall = {
      checkReversePath = "loose";
      allowedUDPPorts = [config.services.tailscale.port];
      trustedInterfaces = ["tailscale0"];
    };
  };
}
```

The built-in `services.tailscale` module handles reconnect logic automatically. Since the node state persists in `/var/lib/tailscale/`, no auth key is needed.

- [ ] **Step 3: Build (do not switch yet)**

```bash
just build
```

Expected: build succeeds, no references to `run-agenix.d.mount` in the tailscale unit.

- [ ] **Step 4: Format and commit**

```bash
just fmt
jj describe -m "feat(tailscale): remove agenix auth key; rely on persistent node state"
jj new
```

---

## Task 5: Remove agenix from the NixOS Profile and Flake

**Files:**
- Modify: `nixos/profiles/base.nix`
- Modify: `flake.nix`

- [ ] **Step 1: Read `nixos/profiles/base.nix`**

Find the line `inputs.agenix.nixosModules.default` in the imports list.

- [ ] **Step 2: Remove agenix module from base.nix**

Remove the agenix module import:

```nix
# Remove from imports:
inputs.agenix.nixosModules.default
```

- [ ] **Step 3: Read `flake.nix`**

Search for every agenix occurrence before editing:

```bash
grep -n "agenix" flake.nix
```

There are **eight** agenix references across three locations: the input block, the `mkHost` wiring, and the `mkInstaller` block. Do not miss the `mkInstaller` occurrences — omitting them will cause a build-breaking undefined binding error.

- [ ] **Step 4: Remove agenix from flake.nix**

Remove all eight agenix references. The changes are:

1. Remove the input block:
```nix
# Remove:
agenix = {
  url = "github:ryantm/agenix";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.darwin.follows = "";
};
```

2. Remove `agenix` from the outputs destructuring (where inputs are unpacked).

3. Remove `agenix` from `mkHost` `specialArgs`.

4. Remove from `mkHost` system packages:
```nix
# Remove:
agenix.packages.${system}.default
```

5. Remove from dev shell packages.

6. Remove `agenix` from `mkInstaller` `specialArgs` (lines ~103):
```nix
# Remove from specialArgs:
inherit ... agenix ...;
```

7. Remove from `mkInstaller` module packages (lines ~107):
```nix
# Remove:
{environment.systemPackages = [agenix.packages.${system}.default];}
```

8. Remove the `echo "  agenix     - secrets management"` line from the `devShell` shellHook if present.

- [ ] **Step 5: Remove justfile secret commands**

Audit and clean up all agenix/secrets references in `justfile`:

```bash
grep -n "agenix\|secret" justfile
```

Remove or delete:
- `secret-list` recipe
- `secret-edit` recipe
- `secret-rekey` recipe

Also update the `ssh-add-host` recipe: find any `echo` line that references `just secret-rekey` and remove or update that instruction line (the migration eliminates the need for rekeying after adding hosts).

- [ ] **Step 6: Prune stale `flake.lock` entry**

After removing the input, prune the now-unused agenix entry from `flake.lock`:

```bash
nix flake update agenix
```

If that fails (because the input no longer exists in flake.nix), run:

```bash
nix flake lock
```

This regenerates `flake.lock` without the removed input.

- [ ] **Step 7: Build**

```bash
just build
```

Expected: clean build with no agenix references. If `nix flake check` complains about undefined `agenix` bindings, re-run `grep -n "agenix" flake.nix` to find any missed occurrence.

- [ ] **Step 8: Format and commit**

```bash
just fmt
jj describe -m "feat(flake): remove agenix input and all references"
jj new
```

---

## Task 6: Delete the Secret Files

**Pre-condition:** Task 3, 4, and 5 must be complete and both hosts switched to the new config. API keys must be verified working via `op inject`.

- [ ] **Step 1: Verify API keys are accessible via 1Password**

```bash
op inject --in-file home/modules/zsh/secrets.env
```

Expected: both exports with real values.

- [ ] **Step 2: Delete the .age files**

```bash
rm secrets/goreleaser.age secrets/anthropic.age secrets/tailscale.age
```

- [ ] **Step 3: Delete or simplify `secrets/secrets.nix`**

If all three secrets are removed, delete the file entirely:

```bash
rm secrets/secrets.nix
```

If the `secrets/` directory is now empty:

```bash
rmdir secrets/
```

- [ ] **Step 4: Remove the `secrets` directory reference from flake.nix (if any)**

Check if `flake.nix` references `./secrets/secrets.nix` anywhere:

```bash
grep -n "secrets" flake.nix
```

Remove any stale references.

- [ ] **Step 5: Run `just fmt` and `just check`**

```bash
just fmt
just check
```

Expected: all checks pass, no agenix-related errors.

- [ ] **Step 6: Commit**

```bash
just fmt
just check
jj describe -m "chore(secrets): delete agenix secret files and secrets.nix"
jj new
```

---

## Task 7: Switch Both Hosts

- [ ] **Step 1: Switch wendigo**

On wendigo:
```bash
just switch
```

- [ ] **Step 2: Verify wendigo**

```bash
# Tailscale still connected
tailscale status

# Open a new shell and verify env vars are set
zsh -ic 'echo GORELEASER_KEY=${GORELEASER_KEY:0:6}...'
zsh -ic 'echo ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:0:7}...'

# agenix CLI is gone
which agenix  # should fail
```

- [ ] **Step 3: Switch kushtaka**

On kushtaka:
```bash
just switch
```

- [ ] **Step 4: Verify kushtaka**

Same verification as wendigo.

- [ ] **Step 5: Verify migration is complete**

```bash
# No agenix references remain in nix files
grep -r "agenix\|age\.secrets" --include="*.nix" .

# flake.lock has no agenix entry
grep "agenix" flake.lock || echo "clean"
```

---

## Rollback Plan

If any task fails mid-migration:

1. The `goreleaser.age` and `anthropic.age` files and `secrets/secrets.nix` are not deleted until Task 6, so agenix can be re-enabled by reverting `home/users/grue.nix` and `nixos/profiles/base.nix`.
2. Tailscale node state is persistent — removing the custom autoconnect service does not disconnect an already-connected node.
3. If the flake.nix agenix removal causes build failures, `git revert` the flake commit and re-add the input.

---

## Notes

- **`snallygaster`** host: The host key is defined in `secrets/secrets.nix` but the host does not appear in `nixos/hosts/`. If it's not actively used, its key entry can be removed along with `secrets.nix`. If it's used, it still benefits from persistent Tailscale state (same approach, no special handling).
- **jj tracking**: Any new file (`secrets.env`) must be tracked with `jj file track` before building.
- **Parallel agents**: Do NOT dispatch multiple subagents in parallel for tasks that involve commits — jj has a single mutable working copy.

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

The ISO/installer no longer needs any agenix tooling (`mkInstaller` can drop its agenix package and specialArgs entirely). The `secrets/` directory and `secrets.nix` key management ceremony disappear entirely. New users (jsquats, sukey) need no special secret setup since they had no agenix secrets anyway.
