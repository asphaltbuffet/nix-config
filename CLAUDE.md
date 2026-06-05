# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. You may edit this file without asking permission.

## Information Recording Principles (Claude must read)

This document uses **progressive disclosure** to optimize LLM working efficiency.

### Level 1 (this file) records only

| Type | Examples |
|------|---------|
| Core command table | `just build`, `just switch` |
| Iron rules / prohibitions | Never use `git add`; always `jj file track` |
| Common error diagnosis | symptom → cause → fix (complete flow) |
| Code patterns | directly-copyable code blocks |
| Directory navigation | function → file mapping |
| Trigger index tables | pointers to Level 2 |

### Level 2 (`docs/references/`) records

| Type | Examples |
|------|---------|
| Detailed SOP workflows | Complete multi-step procedures |
| Edge case handling | Rare error diagnosis |
| Full configuration examples | All parameters explained |
| Historical decision records | Why things are designed this way |

### When a user asks to record information

1. **Is it high-frequency?** → write to CLAUDE.md (Level 1)
2. **Is it a detailed SOP or edge case?** → write to `docs/references/` (Level 2) with a trigger entry in the index tables below

---

## Reference Index (check here first when encountering problems)

| Trigger scenario | Document | Core content |
|---|---|---|
| Adding/editing secrets, `.age` files, agenix, SSH module, git signing | `docs/references/secrets-sop.md` | agenix workflow, rekeying, SSH matchBlocks, host prep |
| Editing GitHub Actions workflows, CI permissions errors, matrix outputs, force-push on CI | `docs/references/ci-github-actions-sop.md` | permissions ceiling, build-hosts.yaml callers, autodeploy |

---

## Build & Development Commands

All commands use `just` (a command runner) and `nh` (a Nix helper) under the hood. Run `just help` to see all available recipes.

```bash
just build              # Verify changes compile before deploying; use to catch eval errors early
just build <host>       # Same, for a specific host (e.g. when editing host-specific config)
just test               # Apply changes to running system WITHOUT touching bootloader — use this to verify a build activates correctly; ask user before running
# just switch           # NEVER run as agent — permanently alters boot default on the live system; user-only
just fmt                # Always run before committing; fixes formatting, lint, and dead code
just lint               # Read-only check — use in CI or to verify before running fmt
just precommit          # Full pre-commit gate: lint + flake check (slower than lint alone)
just update             # Bump all flake inputs to latest; run when you want upstream changes
just rekey              # Must run after adding a host or user key to secrets/secrets.nix
just prep-host <name>   # First step when onboarding a new host — fetches its pubkey from 1Password
```

Dev shell: `nix develop` provides nixd (Nix LSP), alejandra, statix, deadnix, and just.

---

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

---

## Preferred CLI Tools

When running shell commands, prefer these modern alternatives:
- `fd` instead of `find`
- `rg` instead of `grep`
- `sd` instead of `sed` (for in-place substitution)
- `jq` instead of Python scripts for JSON processing

---

## Key Conventions

### VCS & Formatting (always apply)

- **Formatter**: alejandra (enforced in `nix flake check`). Always run `just fmt` before committing.
- **Linter**: statix (available in dev shell).
- **VCS**: jujutsu (jj) colocated with git. Main branch is `main`. For isolated workspaces use `jj workspace add <path> --name <name>` (not `git worktree add`); no `.gitignore` entry needed.
- **Parallel subagents + jj**: Do NOT dispatch multiple subagents in parallel when they need to commit — jj has a single mutable working copy (`@`) and parallel agents conflict. Execute sequentially.

### Shell & YAML (always apply)

- **Shell `#` quoting**: Any argument containing `#` (e.g. `nix run "nixpkgs#nvd"`) must be double-quoted in zsh — unquoted `#` starts a comment. This applies in Bash tool calls too.
- **YAML validation**: Use `yq -e '.' file.yaml` to validate YAML syntax. Never use `python3 -c "import yaml..."` — python3 is not reliably on PATH.

### Nix-specific gotchas (iron rules)

- **New files + Nix flake**: The flake copies sources via `self`, so new files must be tracked before `just build` can see them. Use `jj file track <path>` (never `git add`).
- **`pkgs.system` deprecated**: Use `pkgs.stdenv.hostPlatform.system` instead. `pkgs.system` triggers `evaluation warning: 'system' has been renamed to/replaced by 'stdenv.hostPlatform.system'`.
- **nix.settings binary caches**: Use `extra-substituters` / `extra-trusted-public-keys` to append a cache without replacing the default `cache.nixos.org`. Bare `substituters` / `trusted-public-keys` are replacement lists.
- **GC already automated**: `programs.nh.clean.enable = true` in `base.nix` creates a systemd GC timer — no need to add a custom `nix-gc` timer.
- **KDE Plasma + TLP**: `services.desktopManager.plasma6.enable` implicitly enables `power-profiles-daemon`. Use `lib.mkForce false` to disable it before enabling TLP (they are mutually exclusive).
- **logind config**: Use `services.logind.settings.Login` (attrset), not the removed `services.logind.extraConfig` (string).

### Module & host patterns

- **Module pattern**: Home-manager tool configs live in `home/modules/<tool>/default.nix`. Import them from roles, not directly from user files.
- **Adding a host**: Create `nixos/hosts/<name>/` with `configuration.nix` and `hardware-configuration.nix`. It will be auto-discovered by both the flake and CI (`.github/workflows/build-hosts.yaml` discovers hosts from `nixos/hosts/` at runtime).
- **Adding a user**: Create `home/users/<name>.nix`, add user definition and home-manager mapping in `nixos/common/users.nix`.
- **NUR packages**: Accessed via `pkgs.nur.repos.<owner>.<pkg>` after overlay in flake.nix.
- **Editor**: Neovim is the primary editor (`home/modules/nvim/`). Lua-based config with Nix-managed plugins, LSP (gopls, nixd, pyright, lua_ls), and carbonfox theme. The legacy vim module (`home/modules/vim/`) is still present but `defaultEditor` is disabled.

### Secrets & SSH

See `docs/references/secrets-sop.md` when touching secrets, agenix, or the SSH module.

- **Secrets**: Managed with agenix. `.age` files are ciphertext (safe to commit). `secrets.nix` maps files to age recipient public keys. The `secretEnvs` list in `home/users/<name>.nix` is the single source of truth for user secret → env var mappings; `age.secrets` and `zsh.initContent` exports are derived from it automatically. See `docs/references/secrets-sop.md` for the full workflow.
- **Rekeying**: Run `just rekey` after adding a new recipient to `secrets.nix`.

---

## Host Type Matrix

| Profile combination | Use case |
|---|---|
| `base.nix` + `server.nix` | Headless home-lab server (no GUI, hardened SSH) |
| `base.nix` + `laptop/` | Laptop or desktop with KDE Plasma 6 |
| `base.nix` + `laptop/` + `gaming.nix` | Gaming desktop |
| `base.nix` + `laptop/` + `laptop/t14.nix` | Lenovo ThinkPad T14 |
| `base.nix` + `laptop/` + `laptop/x1carbon.nix` | Lenovo ThinkPad X1 Carbon |

`server.nix` and `laptop/` are mutually exclusive — never import both.

---

## Before You Edit (task-oriented lookup)

| You are about to… | Read this first | Key pitfall |
|---|---|---|
| Add or rotate a secret / edit `.age` file | `docs/references/secrets-sop.md` | Run `just rekey` after adding recipient |
| Edit `home/modules/ssh/` | `docs/references/secrets-sop.md` | Use `matchBlocks."*"`, not `extraConfig`; set `enableDefaultConfig = false` |
| Edit any GitHub Actions workflow | `docs/references/ci-github-actions-sop.md` | Permissions ceiling applies to all callers of `build-hosts.yaml` |
| Add a step to `build-hosts.yaml` | `docs/references/ci-github-actions-sop.md` | Gate behind boolean input with `default: false` |
| Add a new host | Host type matrix above + `just prep-host <hostname>` | `server.nix` and `laptop/` are mutually exclusive |
| Add a new home-manager module | Module pattern: `home/modules/<tool>/default.nix`, import from roles | Never import directly from user files |
| Create any new file | `jj file track <path>` before `just build` | Flake won't see untracked files |

---

## Workflow Skills

Use these slash commands for guided workflows:

- `/add-host` — Add a new NixOS host (prompts for host type, provides templates)
- `/add-module` — Add a new home-manager module and wire it into a role
- `/deploy` — Safe deployment workflow: fmt → build → diff → test/switch → verify
- `/nix-build-check` — Build and optionally activate config for any host

---

## Reference Trigger Index (long-conversation reminder)

| Trigger scenario | Document | Core content |
|---|---|---|
| Secrets, agenix, `.age` files, SSH module, git signing, host prep | `docs/references/secrets-sop.md` | agenix workflow, rekeying, SSH matchBlocks |
| GitHub Actions permissions errors, CI matrix outputs, `build-hosts.yaml` callers, autodeploy, `force-with-lease` on CI | `docs/references/ci-github-actions-sop.md` | permissions ceiling, shared workflow gate pattern |

---

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues (`gh` CLI); VCS uses `jj` not `git`. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context repo — one `CONTEXT.md` and `docs/adr/` at the root. See `docs/agents/domain.md`.
