# Style & Conventions

## Formatting
- **Formatter**: alejandra (enforced in CI via `nix flake check`)
- Always run `just fmt` before committing
- **Linter**: statix, deadnix

## Nix Conventions
- Module pattern: `home/modules/<tool>/default.nix`, imported from roles (never directly from user files)
- New hosts: create `nixos/hosts/<name>/` with `configuration.nix` + `hardware-configuration.nix` — auto-discovered
- New users: create `home/users/<name>.nix`, add definition + home-manager mapping in `nixos/common/users.nix`
- NUR packages: `pkgs.nur.repos.<owner>.<pkg>` after overlay in flake.nix
- Use `pkgs.stdenv.hostPlatform.system` (not deprecated `pkgs.system`)
- Use `extra-substituters` / `extra-trusted-public-keys` (not bare `substituters`)

## Iron Rules
- **New files**: must `jj file track <path>` before `just build` (flake uses `self` to copy sources)
- **Never use `git add`** — always `jj file track`
- **Never use `git worktree add`** — use `jj workspace add`
- **No parallel subagents for commits** — jj has single mutable working copy
- **Shell `#` quoting**: always double-quote args containing `#` in zsh (e.g. `"nixpkgs#nvd"`)
- **YAML validation**: `yq -e '.' file.yaml` (not python3)
- **`server.nix` and `laptop/` are mutually exclusive**

## Profile Combinations
| Profile | Use case |
|---|---|
| `base.nix` + `server.nix` | Headless server |
| `base.nix` + `laptop/` | Laptop/desktop with KDE Plasma 6 |
| `base.nix` + `laptop/` + `gaming.nix` | Gaming desktop |
| `base.nix` + `laptop/` + `laptop/t14.nix` | ThinkPad T14 |
| `base.nix` + `laptop/` + `laptop/x1carbon.nix` | ThinkPad X1 Carbon |

## Gotchas
- `logind` config: use `services.logind.settings.Login` (attrset), not removed `services.logind.extraConfig`
- KDE Plasma + TLP: use `lib.mkForce false` on `power-profiles-daemon` before enabling TLP
- GC already automated via `programs.nh.clean.enable = true` in `base.nix`
