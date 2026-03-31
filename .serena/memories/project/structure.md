# Code Structure

## Top-Level Layout
```
flake.nix              # Entry point: mkHost, mkPkgs, devShell, formatter, checks
shell.nix              # Dev shell (nixd LSP, alejandra, statix, deadnix, just)
justfile               # Task runner commands
secrets/               # agenix-encrypted .age files + secrets.nix recipients map
nixos/                 # NixOS system-side config
home/                  # home-manager user-side config
apps/                  # Flake apps (benchmark.nix)
docs/                  # Documentation
```

## System Side (nixos/)
```
nixos/hosts/<name>/configuration.nix       # Per-host entry point (auto-discovered)
nixos/hosts/<name>/hardware-configuration.nix
nixos/profiles/base.nix                    # Imports home-manager + all common modules
nixos/profiles/server.nix                  # Headless overlay (mutually exclusive with laptop/)
nixos/profiles/laptop/                     # KDE Plasma 6, display, power
nixos/profiles/gaming.nix                  # Gaming overlay
nixos/common/                              # Reusable NixOS modules (users.nix, tailscale.nix, etc.)
```

## User Side (home/)
```
home/users/<name>.nix                      # Per-user config, imports roles
home/roles/                                # Composable bundles: base, admin, dev, player
home/modules/<tool>/default.nix            # Individual tool configs (zsh, git, nvim, jj, mise, claude, ssh, etc.)
```

## Key Binding Points
- `nixos/common/users.nix` — maps system users to home-manager users
- `flake.nix` mkHost — composes host configuration with NUR overlays
- `home/modules/agenix/default.nix` — `userSecrets` attrset: source of truth for secret→env var mappings
