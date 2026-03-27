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
│   │   ├── kushtaka/         # ThinkPad T14 #2
│   │   └── snallygaster/     # ThinkPad X1 Carbon
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
└── docs/                     # Documentation and research notes
```

## Quick Start

```bash
# Build without activating
just build

# Preview what would change (build + closure diff vs current system)
just diff

# Build and switch to new configuration
just switch

# Check formatting, linting, and dead code
just lint

# Apply formatting and linting fixes
just fix

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
  (needed for SSH access to the installed system)
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
machine** to pull those files, commit, and push.

**On any existing host** (the exact commands are printed by `nixos-bootstrap`):

```bash
cd ~/nix-config

# Pull new host files from the live ISO (its IP is shown in the bootstrap output)
mkdir -p nixos/hosts/<hostname>
scp nixos@<live-ip>:/home/nixos/nix-config/nixos/hosts/<hostname>/hardware-configuration.nix \
    nixos/hosts/<hostname>/hardware-configuration.nix
scp nixos@<live-ip>:/home/nixos/nix-config/nixos/hosts/<hostname>/configuration.nix \
    nixos/hosts/<hostname>/configuration.nix

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

After first boot, authenticate Tailscale interactively:

```bash
sudo tailscale up --auth-key <key>
```

Then sign in to 1Password — API keys will be available in new shells immediately.

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

## SSH Key Management

SSH keys are managed via [1Password SSH agent](https://developer.1password.com/docs/ssh/) — private key material never touches disk.

| Layer | Tool | Where key lives |
|-------|------|-----------------|
| Interactive SSH auth | 1Password SSH agent | 1P vault only |
| Git/jj commit signing | 1Password SSH agent | 1P vault only |
| API key injection | 1Password CLI (`op inject`) | 1P vault only |

```bash
just ssh-verify       # Check agent, GitHub auth, and signing config
just ssh-agent-check  # Verify 1Password agent is running
just ssh-pubkey       # Print public key (for adding to servers)
just ssh-rotate       # Guided key rotation workflow
just ssh-add-host <hostname> "<pubkey>"  # Instructions for adding a new host key
```

See [`docs/security/ssh-key-management.md`](docs/security/ssh-key-management.md) for the full runbook and [`docs/security/new-host-onboarding.md`](docs/security/new-host-onboarding.md) for platform-specific setup (NixOS, Windows, Linux).

## Secrets Management

Secrets are managed via [1Password](https://1password.com) using the `op inject`
CLI pattern — no encrypted files in the repo, no host key ceremony when adding
new machines.

User-session secrets (API keys) are injected into zsh at login via:

```bash
eval "$(op inject --in-file ~/.config/op/secrets.env 2>/dev/null)" || true
```

The template (`home/modules/zsh/secrets.env`) contains `op://` references —
inert without an authenticated 1Password session. If 1Password is locked, the
shell opens normally and env vars are simply unset until you unlock and open a
new shell.

Tailscale authentication state persists in `/var/lib/tailscale/` — no auth key
is stored in the config. On a fresh install, run `sudo tailscale up --auth-key
<key>` once interactively; subsequent reboots reconnect automatically.

See [`docs/security/secrets-migration-agenix-to-1password.md`](docs/security/secrets-migration-agenix-to-1password.md)
for the full rationale and migration notes.

## Auto-Deploy

Hosts that opt in receive automatic NixOS updates via
[nixos-autodeploy](https://github.com/hlsb-fulda/nixos-autodeploy).

**How it works:**

1. On every push to `main`, CI builds all host configurations and pushes closures to
   the [`nix-config-grue` Cachix cache](https://app.cachix.org/cache/nix-config-grue).
2. Each built store path is published to GitHub Pages at:
   `https://asphaltbuffet.github.io/nix-config/hosts/<hostname>/store-path`
3. A systemd timer on each opted-in host fetches its URL and applies the new
   config (on next boot, by default).

**Opting a host in:**

Add to the host's `configuration.nix`:
```nix
system.autoDeploy.enable = true;
```

Then provision the 1Password service account token (requires an authenticated 1Password session):
```bash
just autodeploy-provision-token
```

**Pausing auto-deploy for a host:**

There are two complementary mechanisms:

| Mechanism | Scope | How |
|-----------|-------|-----|
| CI skip file | Stops *publishing* new builds (host stays at last deployed version) | `just autodeploy-skip <hostname>` then commit the file |
| Built-in divergence detection | Suspends *applying* updates after a manual `nixos-rebuild` | Automatic — `nixos-autodeploy` detects the divergence |

```bash
# Pause publishing for a host (stops CI from updating the store-path URL)
just autodeploy-skip wendigo
jj file track .autodeploy-skip/wendigo
jj commit -m "chore: pause auto-deploy for wendigo"

# Resume
just autodeploy-resume wendigo
jj commit -m "chore: resume auto-deploy for wendigo"

# Check what store path is currently published for a host
just autodeploy-status wendigo
```

**Disabling permanently:**

Remove `system.autoDeploy.enable = true` from the host config (or set it to `false`).

## Development

Enter the dev shell for nix tooling (includes everything needed to build,
format, lint, and version-control the config):

```bash
nix develop
```

| Tool | Purpose |
|------|---------|
| `just` | Command runner — `just help` lists all recipes |
| `nh` | Nix helper used by `just build/switch/test` |
| `jj` | Jujutsu version control (`jj log`, `jj commit`, `jj git push`) |
| `nixd` | Nix language server (LSP for editors) |
| `alejandra` | Nix formatter — run `just fmt` or `just fix` |
| `statix` | Nix linter — run `just lint` (check) or `just fix` (apply) |
| `deadnix` | Detects unused Nix bindings — run `just lint` (check) or `just fix` (apply) |

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
