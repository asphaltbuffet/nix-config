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

Secrets management (agenix):
```bash
just secret-list        # List available secrets
just secret-edit <name> # Edit an encrypted secret
just secret-rekey       # Re-encrypt after adding keys
```

Dev shell: `nix develop` provides nil (Nix LSP), alejandra, statix, and agenix.

## Architecture

This is a NixOS + home-manager flake for two hosts (wendigo, kushtaka). The config is layered:

**System side** (`nixos/`):
- `hosts/<name>/configuration.nix` — Per-host entry point. Hosts are **auto-discovered** from directory names in `nixos/hosts/`.
- `profiles/` — Shared system profiles (base.nix, gaming.nix, laptop/). `base.nix` imports home-manager, agenix, and all common modules.
- `common/` — Reusable NixOS modules (users.nix, tailscale.nix, firefox.nix, 1password.nix).

**User side** (`home/`):
- `users/<name>.nix` — Per-user config. Imports roles and sets user-specific overrides (git identity, secrets, extra packages).
- `roles/` — Composable bundles (base, admin, dev, player). Each role imports relevant modules.
- `modules/<tool>/` — Individual tool configurations (zsh, git, nvim, jj, mise, etc). Each is a directory with `default.nix`.

**Binding layer**: `nixos/common/users.nix` defines system users AND maps `home-manager.users.<name>` to `home/users/<name>.nix`.

**Flake** (`flake.nix`): `mkHost` builds a NixOS system by composing `nixos/hosts/<name>/configuration.nix` with NUR overlays and system packages. All flake inputs are passed to modules via `specialArgs`.

## Preferred CLI Tools

When running shell commands, prefer these modern alternatives:
- `fd` instead of `find`
- `rg` instead of `grep`
- `sd` instead of `sed` (for in-place substitution)
- `jq` instead of Python scripts for JSON processing

## Key Conventions

- **Formatter**: alejandra (enforced in `nix flake check`). Always run `just fmt` before committing.
- **Linter**: statix (available in dev shell).
- **VCS**: jujutsu (jj) colocated with git. Main branch is `main`.
- **Secrets**: agenix. Keys defined in `secrets/secrets.nix`, encrypted files in `secrets/*.age`.
- **Editor**: Neovim is the primary editor (`home/modules/nvim/`). Lua-based config with Nix-managed plugins, LSP (gopls, nixd, pyright, lua_ls), and carbonfox theme. The legacy vim module (`home/modules/vim/`) is still present but `defaultEditor` is disabled.
- **Module pattern**: Home-manager tool configs live in `home/modules/<tool>/default.nix`. Import them from roles, not directly from user files.
- **Adding a host**: Create `nixos/hosts/<name>/` with `configuration.nix` and `hardware-configuration.nix`. It will be auto-discovered.
- **Adding a user**: Create `home/users/<name>.nix`, add user definition and home-manager mapping in `nixos/common/users.nix`.
- **NUR packages**: Accessed via `pkgs.nur.repos.<owner>.<pkg>` after overlay in flake.nix.
- **New files + Nix flake**: The flake copies sources via `self`, so new files must be tracked before `just build` can see them. Use `jj file track <path>` (never `git add`).
- **KDE Plasma + TLP**: `services.desktopManager.plasma6.enable` implicitly enables `power-profiles-daemon`. Use `lib.mkForce false` to disable it before enabling TLP (they are mutually exclusive).
- **logind config**: Use `services.logind.settings.Login` (attrset), not the removed `services.logind.extraConfig` (string).
- **GC already automated**: `programs.nh.clean.enable = true` in `base.nix` creates a systemd GC timer — no need to add a custom `nix-gc` timer.
