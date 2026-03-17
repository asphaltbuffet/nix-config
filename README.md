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

## Installing on a New Machine

A bootable installer ISO is available for provisioning new hosts without manual
NixOS setup.

### Build the ISO

```bash
just iso
# ISO will be at result/iso/*.iso
```

Flash it to a USB drive:

```bash
dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress
```

### Boot and Bootstrap

1. Boot the target machine from the USB drive (disable Secure Boot if needed)
2. Log in as `nixos` (password: `nixos`)
3. Partition and mount your target disk at `/mnt` (see partition example below)
4. Run the bootstrap helper:

```bash
nixos-bootstrap
```

The helper will:
- Prompt for a hostname
- Generate `/mnt/etc/nixos/hardware-configuration.nix`
- Pre-generate the host SSH key at `/mnt/etc/ssh/ssh_host_ed25519_key`
  (so the public key is known before secrets are re-encrypted)
- Save all artifacts to `/home/nixos/bootstrap-<hostname>/`
- Display step-by-step instructions in a scrollable pager (`q` to exit)
- Save instructions to `/home/nixos/bootstrap-<hostname>/INSTRUCTIONS.txt`

A read-only snapshot of this repo is embedded in the ISO at `/etc/nix-config`
for reference — no network required to inspect the config.

### Disk Partitioning Example

```bash
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart root ext4 512MB 100%
parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 512MB
parted /dev/nvme0n1 -- set 2 esp on
mkfs.ext4 -L nixos /dev/nvme0n1p1
mkfs.fat -F 32 -n boot /dev/nvme0n1p2
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
```

### Add the Host to the Flake

`nixos-bootstrap` automates most of this. When network is available it clones
the repo and writes the host files directly. You then SSH into an **existing
machine** (wendigo/kushtaka) to pull those files, rekey secrets, commit, and
push — because rekeying requires a private key that's already authorized (see
[Secrets Management](#secrets-management) below for why).

**On wendigo or kushtaka** (the exact commands are printed by `nixos-bootstrap`):

```bash
cd ~/nix-config

# Pull new host files from the live ISO (its IP is shown in the bootstrap output)
mkdir -p nixos/hosts/<hostname>
scp nixos@<live-ip>:/home/nixos/nix-config/nixos/hosts/<hostname>/hardware-configuration.nix \
    nixos/hosts/<hostname>/hardware-configuration.nix
scp nixos@<live-ip>:/home/nixos/nix-config/nixos/hosts/<hostname>/configuration.nix \
    nixos/hosts/<hostname>/configuration.nix

# Edit secrets/secrets.nix: add the new host pubkey and include it in systems[]
# (pubkey is printed by nixos-bootstrap and saved to /home/nixos/bootstrap-<hostname>/)
$EDITOR secrets/secrets.nix

# Rekey on THIS machine — decrypts with your existing key, re-encrypts for new host
just secret-rekey

# Track and commit (jj — do NOT use git add)
jj file track nixos/hosts/<hostname>/configuration.nix
jj file track nixos/hosts/<hostname>/hardware-configuration.nix
jj commit -m 'feat: add host <hostname>'
jj git push
```

**Back on the live ISO** — after the push completes:

```bash
nixos-install --flake github:asphaltbuffet/nix-config#<hostname>
reboot
```

> **Important**: Do not wipe `/mnt/etc/ssh/` before running `nixos-install`.
> The pre-generated host key must survive to the installed system so agenix
> can decrypt secrets on first boot.

### Surface-Specific Notes

- Disable Secure Boot in UEFI firmware before booting the ISO
- Surface Pro 3/4 may need a USB-A adapter for USB boot
- After install, enable the hardware module in the host config:
  ```nix
  imports = [ inputs.nixos-hardware.nixosModules.microsoft-surface-common ];
  ```

## Adding a New Host (Manual)

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

Each secret is encrypted to a list of public keys (user SSH keys + host SSH
keys). When you add a new host, you add its public key to `secrets/secrets.nix`
and run `just secret-rekey` **on an existing trusted machine** — agenix decrypts
each secret using your current SSH identity and re-encrypts it so the new host
can also decrypt it after installation. The new machine cannot perform rekeying
itself because it isn't yet an authorized decryptor.

```bash
# List secrets
just secret-list

# Edit a secret
just secret-edit <name>

# Re-encrypt after adding keys
just secret-rekey
```

## Development

Enter the dev shell for nix tooling (includes everything needed to build,
format, lint, manage secrets, and version-control the config):

```bash
nix develop
```

| Tool | Purpose |
|------|---------|
| `just` | Command runner — `just help` lists all recipes |
| `nh` | Nix helper used by `just build/switch/test` |
| `jj` | Jujutsu version control (`jj log`, `jj commit`, `jj git push`) |
| `nixd` | Nix language server (LSP for editors) |
| `alejandra` | Nix formatter — run `just fmt` before committing |
| `statix` | Nix linter |
| `deadnix` | Detects unused Nix bindings |
| `agenix` | Secret management — used by `just secret-*` recipes |

> **Note**: `jj` and `nh` are also needed on a blank machine (e.g. after first
> install) to run `just switch`. Both are in the dev shell so `nix develop`
> is sufficient without any pre-existing system configuration.

### Testing the Installer ISO in a VM

Before flashing to USB, you can validate the bootstrap process in a local QEMU VM:

```bash
just iso    # build the ISO first
just vm     # boot it — serial console in your terminal
```

The VM:
- Attaches a 20 GB scratch disk (`vm-disk.qcow2`) as the install target
- Forwards SSH to `localhost:2222` — log in with `ssh -p 2222 nixos@localhost`
- Boots from the ISO (disk is blank, like a real machine)

Inside the VM the install disk is `/dev/vda` (virtio), not `/dev/nvme0n1` —
substitute accordingly when partitioning.

To `scp` artifacts from the VM back to this host, use port 2222:

```bash
scp -P 2222 nixos@localhost:/home/nixos/bootstrap-<hostname>/ssh_host_ed25519_key.pub \
    nixos/hosts/<hostname>/ssh_host_ed25519_key.pub
```

Delete `vm-disk.qcow2` to start fresh on the next run. Run multiple VMs with
different disk names: `just vm disk=vm2.qcow2`.

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
