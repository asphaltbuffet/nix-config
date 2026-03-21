---
name: deploy
description: Safe NixOS deployment workflow for local or remote hosts. Use when deploying config changes, with pre-flight checks, diff preview, and rollback guidance.
---

# Deploy NixOS Config

Safe deployment workflow with pre-flight checks, preview, and rollback guidance.

## Step 1: Pre-flight — format check

```bash
just fmt
```

Formatting must pass before anything else. Alejandra is enforced by `nix flake check` — a formatting failure will cause the build to fail.

## Step 2: Build validation

```bash
just build <host>
```

This builds the config without activating it. If this fails, fix evaluation errors before continuing.

Available hosts: **wendigo**, **kushtaka**, **snallygaster**. Omit `<host>` to build for the current machine.

## Step 3: Preview changes

```bash
just diff <host>
```

Review the diff before activating. Pay attention to:
- Service restarts (look for `systemd` unit changes)
- Package removals
- Config file changes to critical services (SSH, tailscale)

**Do not proceed if the diff looks unexpected.**

## Step 4: Deploy — choose your safety level

Ask the user which activation mode they want:

### Option A: `just test <host>` — reversible

Activates the new config immediately but does **not** set it as the boot default. The previous generation remains the boot default.

- Safe for testing changes
- **Rollback**: reboot the machine — it will boot the previous generation automatically

### Option B: `just switch <host>` — permanent

Activates the new config and sets it as the boot default.

- Use when you're confident the change is correct
- **Rollback**: run `sudo nixos-rebuild switch --rollback` or select the previous generation in the bootloader

## Step 5: Confirm generation bumped

After activation, confirm the new generation is active:

```bash
just generation
```

Verify the generation number incremented from what it was before.

## Rollback reference

| Scenario | Recovery |
|---|---|
| Config applied with `just test`, system is broken | Reboot — old generation boots automatically |
| Config applied with `just switch`, system is broken | `sudo nixos-rebuild switch --rollback` |
| SSH locked out after config switch | Boot from NixOS installer, mount system, run `nixos-enter` then `nixos-rebuild switch --rollback` |
| Host unreachable via tailscale after deploy | Likely tailscale config change broke reconnection — use local access or IPMI |

## Notes

- Never deploy to an offline host — check `tailscale status` first (or use the `homelab-status` agent)
- Changes to SSH authorized keys or tailscale auth take effect immediately on `just test`
- If deploying a new kernel, a reboot is required for it to take effect
