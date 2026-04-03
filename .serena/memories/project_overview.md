# Project Overview

**Purpose**: Personal NixOS + home-manager flake configuration for multiple machines.

**Tech Stack**:
- Nix flakes (NixOS + home-manager)
- agenix for secrets management
- jujutsu (jj) as VCS, colocated with git
- alejandra formatter, statix + deadnix linters
- `just` command runner, `nh` Nix helper

**Hosts** (auto-discovered from `nixos/hosts/`):
- `wendigo` — ThinkPad T14 + gaming (laptop + gaming profiles)
- `kushtaka` — ThinkPad T14 (laptop profile)
- `snallygaster` — ThinkPad X1 Carbon (laptop profile)
- `bunyip` — (newer host, type TBD)

**Users**: grue (primary, all roles), jsquats, sukey

**Main branch**: `main`
