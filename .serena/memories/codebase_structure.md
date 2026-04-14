# Codebase Structure

```
flake.nix                   # mkHost, mkPkgs, devShell, formatter, checks
justfile                    # All dev commands
shell.nix                   # Dev shell (also usable as legacy nix-shell)
secrets/                    # agenix encrypted secrets (.age files + secrets.nix)

nixos/
  hosts/<name>/             # Per-host entry point (auto-discovered)
    configuration.nix
    hardware-configuration.nix
  profiles/
    base.nix                # Imports home-manager + all common modules
    server.nix              # Headless overlay (disables GUI) — mutually exclusive with laptop/
    gaming.nix              # Gaming overlay
    installer.nix           # Installer profile
    laptop/                 # Laptop/desktop with KDE Plasma 6
  common/                   # Reusable NixOS modules
    users.nix               # System users + home-manager.users.<name> mappings
    agenix.nix              # System-level secrets
    tailscale.nix
    1password.nix
    firefox.nix
    monitoring.nix, nas.nix, autodeploy.nix, tailscale-subnet-router.nix

home/
  users/<name>.nix          # Per-user config, imports roles, sets overrides
  roles/
    base.nix                # Base role (sd, etc.)
    dev.nix                 # Dev tools: nixd, claude, jj, nvim, mise
    admin.nix               # Admin tools
    player.nix              # Gaming/media tools
  modules/<tool>/           # Individual tool configs (default.nix each)
    agenix/                 # User secrets → env var mappings (userSecrets attrset)
    git/, jj/, nvim/, vim/
    zsh/, starship/, kitty/, tmux/
    ssh/, 1password/, gh/
    mise/, go/, direnv/, fzf/, zoxide/
    eza/, delta/, claude/, crush/
    firefox/, mullvad/, protonmail/, pop/, wishlist/
```

## Binding Layer
`nixos/common/users.nix` defines system users AND maps `home-manager.users.<name>` to `home/users/<name>.nix`.

## Secrets
- `secrets/secrets.nix` — declares secrets + authorized recipient keys
- `*.age` files — encrypted ciphertext (safe to commit)
- System secrets: `nixos/common/agenix.nix`
- User secrets: `home/modules/agenix/default.nix` (`userSecrets` attrset = source of truth for user secret → env var mappings)
- Tailscale persistent state: `/var/lib/tailscale/` (no auth key in config)
