# nix-config

NixOS and home-manager configuration for a personal fleet of machines, managed as a single flake.

## Language

### Machines and identity

**Host**:
A physical machine managed by this flake. Each host has a directory under `nixos/hosts/<name>/` and is auto-discovered by the flake.
_Avoid_: node, machine, system, box

**Profile**:
A reusable NixOS-level bundle of system services and settings imported by one or more hosts. Lives in `nixos/profiles/`.
_Avoid_: preset, template, base config

**Role**:
A reusable home-manager-level bundle of user tools and settings imported by a user config. Lives in `home/roles/`.
_Avoid_: profile (reserved for the NixOS layer), preset

**Module**:
A single-tool home-manager configuration. Lives in `home/modules/<tool>/default.nix`. Imported from roles, never directly from user files.
_Avoid_: plugin, package config, dotfiles

### Users and secrets

**User config**:
The per-user home-manager entry point at `home/users/<name>.nix`. Imports roles, sets identity overrides (git name, email), and declares secret mappings.
_Avoid_: dotfile, home config, user profile

**Secret**:
A credential (API key, auth token) that lives exclusively in 1Password and never touches disk as a file. Injected into the shell environment at session start via `op inject`.
_Avoid_: key (overloaded), credential (use for the concept; secret for the managed artifact), env var (that's the injection mechanism, not the thing itself)

**Host key**:
The ed25519 SSH keypair that identifies a host to other SSH clients. Private key lives on the host at `/etc/ssh/ssh_host_ed25519_key`; public key is committed to the repo at `nixos/hosts/<name>/ssh_host_ed25519_key.pub` for agenix recipient lists and known-hosts management.
_Avoid_: machine key, SSH key (overloaded — also means user identity key)

### Deployment

**Bootstrap**:
The one-time process of installing NixOS on a new host from the installer ISO, generating the host key, and wiring the host into the flake. Executed by running `nixos-bootstrap` on the live ISO.
_Avoid_: provision, install, onboard

**Switch**:
Applying a new NixOS configuration to a running host and making it the boot default. User-only operation — never run by agents.
_Avoid_: deploy (use only for auto-deploy), apply, rebuild

**Auto-deploy**:
The automated pipeline where CI builds host closures and pushes store paths to a URL that opted-in hosts poll and apply on a timer. Distinct from a manual switch.
_Avoid_: auto-update, auto-upgrade, auto-switch

**Artifact dir**:
The directory `/home/nixos/bootstrap-<hostname>/` on the live ISO where `nixos-bootstrap` saves generated files (hardware config, host pubkey, instructions) for transfer to an existing host.
_Avoid_: output dir, bootstrap files

### Example dialogue

> **Dev:** I want to add bunyip as a new host. Do I create a profile for it?
>
> **Domain expert:** No — a profile is a reusable NixOS bundle shared across multiple hosts. What you want is a host directory under `nixos/hosts/bunyip/`. If bunyip needs the same system services as your other servers, you import the `server` profile from there.
>
> **Dev:** Got it. And for grue's shell tools on bunyip — I add those to the host config?
>
> **Domain expert:** No, those live in the user config at `home/users/grue.nix` via roles and modules. The host config only knows about system-level things. Home-manager wires the user config to the host through `nixos/common/users.nix`.
>
> **Dev:** Last one — after bootstrap, I need to get the hardware config back to my existing machine. Do I scp it?
>
> **Domain expert:** You transfer it from the artifact dir on the live ISO to your existing host. With kitty, use `kitten transfer` — it rides the SSH session so you don't need a separate connection.
