# nix-config

NixOS and home-manager configuration for personal systems.

## Structure

```
.
├── flake.nix                 # Flake definition with inputs and outputs
├── justfile                  # Build commands (run `just help`)
│
├── nixos/
│   ├── hosts/                # Per-host configurations
│   │   ├── wendigo/          # ThinkPad T14 #1
│   │   └── kushtaka/         # ThinkPad T14 #2
│   ├── profiles/             # Shared system profiles
│   │   ├── base.nix          # All systems
│   │   ├── gaming.nix        # Steam, gamemode
│   │   └── laptop/           # Laptop-specific (KDE, power mgmt)
│   └── common/               # Shared modules
│       ├── users.nix         # User definitions
│       ├── tailscale.nix     # VPN configuration
│       └── ...
│
├── home/
│   ├── users/                # Per-user home-manager configs
│   │   ├── grue.nix          # Primary user (all roles)
│   │   ├── jsquats.nix       # Secondary user
│   │   └── sukey.nix         # Additional user
│   ├── roles/                # Composable role sets
│   │   ├── base.nix          # Core CLI tools, shell config
│   │   ├── admin.nix         # Network/sysadmin tools
│   │   ├── dev.nix           # Development tools
│   │   └── player.nix        # Gaming tools
│   └── modules/              # Per-tool configurations
│       ├── zsh/
│       ├── vim/
│       ├── git/
│       └── ...
│
└── secrets/                  # Agenix encrypted secrets
    ├── secrets.nix           # Secret definitions and keys
    └── *.age                 # Encrypted secret files
```

## Quick Start

```bash
# Build without activating
just build

# Build and switch to new configuration
just switch

# Update flake inputs and switch
just update-switch

# See all commands
just help
```

## Adding a New Host

1. Create `nixos/hosts/<hostname>/` directory
2. Add `configuration.nix` with imports and hostname
3. Add `hardware-configuration.nix` (generate with `nixos-generate-config`)
4. The host will be auto-discovered by the flake

## Adding a New User

1. Create `home/users/<username>.nix` with role imports
2. Add user definition to `nixos/common/users.nix`
3. Add `home-manager.users.<username>` mapping

## Secrets Management

Secrets are managed with [agenix](https://github.com/ryantm/agenix).

```bash
# List secrets
just secret-list

# Edit a secret
just secret-edit <name>

# Re-encrypt after adding keys
just secret-rekey
```

## Development

Enter the dev shell for nix tooling:

```bash
nix develop
```

The dev shell includes:
- `nvim` - Neovim configured for nix (LSP, formatting)
- `nil` - Nix language server
- `alejandra` - Nix formatter
- `statix` - Nix linter
- `agenix` - Secret management

## Roles

Users import roles to compose their environment:

| Role | Description |
|------|-------------|
| `base` | Core utilities, shell, fonts, CLI tools |
| `admin` | Network tools, system monitoring |
| `dev` | Development tools, editors, git config |
| `player` | Gaming tools (mangohud, etc.) |

Example user configuration:

```nix
# home/users/example.nix
{pkgs, ...}: {
  imports = [
    ../roles/base.nix
    ../roles/dev.nix
  ];

  home.username = "example";
  home.homeDirectory = "/home/example";
  home.stateVersion = "25.05";
}
```
