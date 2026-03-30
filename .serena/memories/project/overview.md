# nix-config — Project Overview

## Purpose
Personal NixOS + home-manager flake configuration for three hosts. Manages system configuration, user environments, secrets, and dotfiles declaratively in Nix.

## Hosts
- **wendigo** — ThinkPad T14 (gaming desktop profile)
- **kushtaka** — ThinkPad T14 (laptop profile)
- **snallygaster** — ThinkPad X1 Carbon (laptop profile)

All hosts are laptops/desktops with graphical sessions (KDE Plasma 6). No headless servers.

## Users
- **grue** — primary user, all roles (base, admin, dev, player)
- jsquats, sukey — secondary users

## Tech Stack
- **Language**: Nix (pure functional, lazy)
- **Formatter**: alejandra
- **Linter**: statix, deadnix
- **Secret manager**: agenix (`.age` encrypted files, recipients in `secrets/secrets.nix`)
- **VCS**: jujutsu (jj) colocated with git, main branch is `main`
- **Command runner**: just
- **Nix helper**: nh
