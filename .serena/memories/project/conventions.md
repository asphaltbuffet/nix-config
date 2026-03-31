# Conventions & Style

## Nix Style
- Formatter: **alejandra** (enforced in CI via `nix flake check`)
- Always run `just fmt` before committing
- Linters: statix (anti-patterns), deadnix (unused bindings)

## Module Pattern
- Home-manager tool configs: `home/modules/<tool>/default.nix`
- Import modules from roles, NOT directly from user files

## Secrets (agenix)
- `.age` files are ciphertext — safe to commit
- `secrets/secrets.nix` maps files to age recipient public keys
- System secrets → `/run/agenix/` (root-owned)
- User secrets → `/run/agenix/` (user-owned)

## Key Gotchas
- New files must be tracked with `jj file track <path>` before `just build` sees them
- `KDE Plasma 6` + `power-profiles-daemon` conflict with TLP — use `lib.mkForce false`
- `services.logind.settings.Login` (attrset), NOT removed `services.logind.extraConfig`
- `programs.ssh.extraConfig` + assertion: use `matchBlocks."*"` for default host config
- Use `extra-substituters` / `extra-trusted-public-keys` to append binary caches (not bare `substituters`)
- Any arg with `#` must be double-quoted in zsh (e.g. `nix run "nixpkgs#nvd"`)
- Do NOT run parallel subagents that commit — jj has single mutable working copy

## Host Types (mutually exclusive profiles)
- Headless server: `base.nix` + `server.nix`
- Laptop/desktop: `base.nix` + `laptop/`
- Gaming: `base.nix` + `laptop/` + `gaming.nix`
