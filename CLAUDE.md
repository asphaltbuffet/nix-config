# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. You may edit this file without asking permission.

## Build & Development Commands

All commands use `just` (a command runner) and `nh` (a Nix helper) under the hood:

```bash
just build              # Build config without activating (current host)
just build <host>       # Build for a specific host
just switch             # Build and activate (makes it boot default)
just test               # Build and activate without making it boot default
just fmt                # Format all .nix files with alejandra
just check              # Run nix flake check (includes formatting check)
just update             # Update flake.lock inputs
just update-switch      # Update inputs and switch in one step
```

```bash
nix run .#benchmark     # Run phoronix benchmark suite (compress, ram, fio, blake2, openssl)
```

Dev shell: `nix develop` provides nixd (Nix LSP), alejandra, statix, deadnix, and just.

## Architecture

This is a NixOS + home-manager flake for three hosts (wendigo, kushtaka, snallygaster). The config is layered:

**System side** (`nixos/`):
- `hosts/<name>/configuration.nix` — Per-host entry point. Hosts are **auto-discovered** from directory names in `nixos/hosts/`.
- `profiles/` — Shared system profiles (base.nix, server.nix, gaming.nix, laptop/). `base.nix` imports home-manager and all common modules. `server.nix` is the headless overlay for home-lab nodes (disables GUI/desktop services). See **Host type matrix** below.
- `common/` — Reusable NixOS modules (users.nix, tailscale.nix, firefox.nix, 1password.nix).

**User side** (`home/`):
- `users/<name>.nix` — Per-user config. Imports roles and sets user-specific overrides (git identity, secrets, extra packages).
- `roles/` — Composable bundles (base, admin, dev, player). Each role imports relevant modules.
- `modules/<tool>/` — Individual tool configurations (zsh, git, nvim, jj, mise, etc). Each is a directory with `default.nix`.

**Binding layer**: `nixos/common/users.nix` defines system users AND maps `home-manager.users.<name>` to `home/users/<name>.nix`.

**Flake** (`flake.nix`): `mkHost` builds a NixOS system by composing `nixos/hosts/<name>/configuration.nix` with NUR overlays and system packages. All flake inputs are passed to modules via `specialArgs`.
- `shell.nix` — Dev shell definition (imported by `flake.nix`; also usable as a legacy `nix-shell`)
- `apps/benchmark.nix` — Phoronix benchmark app (imported by `flake.nix`)

## Preferred CLI Tools

When running shell commands, prefer these modern alternatives:
- `fd` instead of `find`
- `rg` instead of `grep`
- `sd` instead of `sed` (for in-place substitution)
- `jq` instead of Python scripts for JSON processing

## Key Conventions

- **Formatter**: alejandra (enforced in `nix flake check`). Always run `just fmt` before committing.
- **Linter**: statix (available in dev shell).
- **VCS**: jujutsu (jj) colocated with git. Main branch is `main`. For isolated workspaces use `jj workspace add <path> --name <name>` (not `git worktree add`); no `.gitignore` entry needed.
- **Secrets**: Managed externally via 1Password (`op inject` in zsh). No agenix in this repo.
- **Editor**: Neovim is the primary editor (`home/modules/nvim/`). Lua-based config with Nix-managed plugins, LSP (gopls, nixd, pyright, lua_ls), and carbonfox theme. The legacy vim module (`home/modules/vim/`) is still present but `defaultEditor` is disabled.
- **Module pattern**: Home-manager tool configs live in `home/modules/<tool>/default.nix`. Import them from roles, not directly from user files.
- **Adding a host**: Create `nixos/hosts/<name>/` with `configuration.nix` and `hardware-configuration.nix`. It will be auto-discovered by both the flake and CI (`.github/workflows/build-hosts.yaml` discovers hosts from `nixos/hosts/` at runtime).
- **Adding a user**: Create `home/users/<name>.nix`, add user definition and home-manager mapping in `nixos/common/users.nix`.
- **NUR packages**: Accessed via `pkgs.nur.repos.<owner>.<pkg>` after overlay in flake.nix.
- **New files + Nix flake**: The flake copies sources via `self`, so new files must be tracked before `just build` can see them. Use `jj file track <path>` (never `git add`).
- **KDE Plasma + TLP**: `services.desktopManager.plasma6.enable` implicitly enables `power-profiles-daemon`. Use `lib.mkForce false` to disable it before enabling TLP (they are mutually exclusive).
- **logind config**: Use `services.logind.settings.Login` (attrset), not the removed `services.logind.extraConfig` (string).
- **GC already automated**: `programs.nh.clean.enable = true` in `base.nix` creates a systemd GC timer — no need to add a custom `nix-gc` timer.
- **SSH module**: `home/modules/ssh/default.nix` configures 1Password SSH agent via `programs.ssh.matchBlocks."*"` (not `extraConfig`). Set `enableDefaultConfig = false` to suppress the deprecated default Host * block warning. Use `programs.git.signing` (typed options) not raw `settings` keys for git signing.
- **`programs.ssh.extraConfig` + assertion**: Setting `extraConfig` to a non-empty string requires `matchBlocks."*"` to exist, or home-manager throws an assertion. Always use `matchBlocks."*"` for default host config instead.
- **Parallel subagents + jj**: Do NOT dispatch multiple subagents in parallel when they need to commit — jj has a single mutable working copy (`@`) and parallel agents conflict. Execute sequentially.
- **`just ssh-verify`**: Uses `|| true` to absorb `ssh -T git@github.com`'s exit code 1 (GitHub always returns 1 for non-shell SSH). Without this, `set -euo pipefail` causes false failures.
- **nix.settings binary caches**: Use `extra-substituters` / `extra-trusted-public-keys` to append a cache without replacing the default `cache.nixos.org`. Bare `substituters` / `trusted-public-keys` are replacement lists.
- **Auto-deploy**: `nixos-autodeploy` is active (see `nixos/common/autodeploy.nix`). Hosts opt in with `system.autoDeploy.enable = true`. Store paths are published to GitHub Pages; verify with `just autodeploy-status <host>`. switchMode defaults to `"smart"` (applies immediately for non-kernel updates; kernel updates wait for reboot).
- **GitHub Actions `permissions:` and reusable workflows**: The workflow-level `permissions:` block in a *calling* workflow is a hard ceiling — any permission not listed there is implicitly `none`, and the called workflow's jobs cannot exceed it. Whenever you add or change a permission in a job inside `build-hosts.yaml`, audit ALL callers (`autodeploy.yaml`, `pr-check.yaml`, `update_flake_lock.yaml`) and ensure that permission is present at their workflow level too. Omitting it produces a "nested job is requesting X, but is only allowed none" validation error. Contrast: `permissions:` on a `workflow_call` *job* block (not the workflow itself) IS silently ignored — only the called workflow's own job-level declarations govern.
- **YAML validation**: Use `yq -e '.' file.yaml` to validate YAML syntax. Never use `python3 -c "import yaml..."` — python3 is not reliably on PATH.
- **`git push --force-with-lease` on CI**: Fresh runners have no tracking refs. Run `git fetch origin "$branch" || true` before pushing to establish the tracking ref, or `--force-with-lease` rejects same-day re-runs with "stale info".
- **GitHub Actions matrix outputs**: Matrix job outputs cannot be consumed by downstream jobs directly. Pass per-matrix-leg data via artifact upload/download (e.g., `upload-artifact` per host, `download-artifact` with `pattern:` + `merge-multiple: true` downstream).
- **`build-hosts.yaml` is shared**: Called by `autodeploy.yaml`, `pr-check.yaml`, and `update_flake_lock.yaml`. New steps added there affect all callers — gate them behind a boolean input with `default: false` (see `publish-pages` and `upload-store-path-for-diff` as examples).

## Host Type Matrix

| Profile combination | Use case |
|---|---|
| `base.nix` + `server.nix` | Headless home-lab server (no GUI, hardened SSH) |
| `base.nix` + `laptop/` | Laptop or desktop with KDE Plasma 6 |
| `base.nix` + `laptop/` + `gaming.nix` | Gaming desktop |
| `base.nix` + `laptop/` + `laptop/t14.nix` | Lenovo ThinkPad T14 |
| `base.nix` + `laptop/` + `laptop/x1carbon.nix` | Lenovo ThinkPad X1 Carbon |

`server.nix` and `laptop/` are mutually exclusive — never import both.

## Workflow Skills

Use these slash commands for guided workflows:

- `/add-host` — Add a new NixOS host (prompts for host type, provides templates)
- `/add-module` — Add a new home-manager module and wire it into a role
- `/deploy` — Safe deployment workflow: fmt → build → diff → test/switch → verify
- `/nix-build-check` — Build and optionally activate config for any host
