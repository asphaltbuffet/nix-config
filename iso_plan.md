# Plan: NixOS Installer ISO with Bootstrap Helper

## Context

The flake currently manages two ThinkPad T14 hosts. New machines are coming: a
server and several laptops including 10+ year old Microsoft Surfaces. Adding
each machine manually is friction-heavy; the goal is a single bootable ISO that
handles arbitrary hardware (x86_64), captures hardware config + host SSH key,
and walks through adding them to the flake so `nixos-install --flake
.#<newhost>` just works.

## Key Constraints

- Auto-discovery problem: `builtins.readDir ./nixos/hosts` auto-discovers ALL
  host subdirectories. The installer config must live under `nixos/installer/`
  (NOT `nixos/hosts/installer/`) to avoid being picked up by mkHost, which
  would fail without a hardware-configuration.nix.
- No nixos-generators input needed: `nixpkgs` ships
  `nixos/modules/installer/cd-dvd/installation-cd-minimal.nix` which handles
  all ISO plumbing. The ISO derivation is at `.config.system.build.isoImage`.
- `installation-cd-minimal.nix` already provides: `hardware.enableAllHardware =
  true` (all kernel modules → broad hardware support including Surfaces), git,
  rsync, SSH, a nixos user with passwordless sudo, EFI+USB boot.
- Surface-specific note: Older Surfaces need Secure Boot disabled to boot
  custom ISOs. Mainline Linux has Surface WiFi/touch drivers; nixos-hardware
  has a microsoft/surface module. The bootstrap template should offer it as a
  commented import.
- New files need `jj file track` before `just build` can see them (flake copies
  sources via self). This is included in verification steps.

## Files to Create/Modify

 ┌───────────────────────────────────┬──────────────────────────────────────────────────┐
 │               File                │                      Action                      │
 ├───────────────────────────────────┼──────────────────────────────────────────────────┤
 │ flake.nix                         │ Add mkInstaller function + packages output       │
 ├───────────────────────────────────┼──────────────────────────────────────────────────┤
 │ nixos/installer/configuration.nix │ Installer entry point                            │
 ├───────────────────────────────────┼──────────────────────────────────────────────────┤
 │ nixos/installer/bootstrap.sh      │ Interactive bootstrap script                     │
 ├───────────────────────────────────┼──────────────────────────────────────────────────┤
 │ nixos/profiles/installer.nix      │ Minimal live system profile (tools, compression) │
 ├───────────────────────────────────┼──────────────────────────────────────────────────┤
 │ justfile                          │ Add iso recipe under [group('build')]            │
 └───────────────────────────────────┴──────────────────────────────────────────────────┘

## Implementation

1. flake.nix changes

Add `mkInstaller` in the let block after `mkHost` (line ~97):

```nix
mkInstaller = system:
   (nixpkgs.lib.nixosSystem {
     inherit system;
     specialArgs = {
       inherit self inputs nixpkgs agenix;
     };
     modules = [
       "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
       {environment.systemPackages = [agenix.packages.${system}.default];}
       ./nixos/installer/configuration.nix
     ];
   }).config.system.build.isoImage;
```

Add packages output after nixosConfigurations (line ~108):

```nix
packages = forAllSystems (system: {
  installer = mkInstaller system;
});
```

Note: `forAllSystems` already only covers "x86_64-linux", correct for now.

2. nixos/profiles/installer.nix

```nix
{pkgs, ...}: {
    nix.settings.experimental-features = ["nix-command" "flakes"];

    # Faster compression (default is zstd level 19; level 6 is ~3x faster to build)
    isoImage.squashfsCompression = "zstd -Xcompression-level 6";
    isoImage.isoName = "nixos-installer.iso";

    environment.systemPackages = with pkgs; [
        parted
        gptfdisk
        neovim
        curl
        wget
    ];
}
```

3. nixos/installer/configuration.nix

```nix
{pkgs, lib, ...}: let
  bootstrapScript = pkgs.writeShellApplication {
    name = "nixos-bootstrap";
    runtimeInputs = with pkgs; [git openssh];
    text = builtins.readFile ./bootstrap.sh;
  };
in {
  imports = [../profiles/installer.nix];

  networking.hostName = "nixos-installer";

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  users.users.nixos.initialPassword = "nixos";

  environment.systemPackages = [bootstrapScript];

  environment.interactiveShellInit = ''
    echo ""
    echo "  NixOS Installer — run: nixos-bootstrap"
    echo ""
  '';
}
```

4. nixos/installer/bootstrap.sh

Interactive script that:
1. Prompts for `hostname`
2. Checks `/mnt` is mounted
3. Runs `nixos-generate-config --root /mnt`
4. Pre-generates host SSH key at `/mnt/etc/ssh/ssh_host_ed25519_key` (so the
   pubkey is known before `secrets.nix` is updated; key survives
   `nixos-install` since it's already on the target fs)
5. Saves artifacts to /root/bootstrap-<hostname>/ (hardware-config + pubkey)
6. Prints step-by-step instructions:
  - Create `nixos/hosts/<name>/hardware-configuration.nix` (from generated file)
  - Create `nixos/hosts/<name>/configuration.nix` from template (see below)
  - Add host pubkey to `secrets/secrets.nix`
  - `just secret-rekey`
  - `jj file track new files`, commit and push
  - `nixos-install --flake github:asphaltbuffet/nix-config#<name>`

Template for new host configuration.nix (printed by the script):

```nix
{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../common/users.nix
    ../../profiles/base.nix
    # Uncomment for ThinkPad T14:
    # ../../profiles/laptop/t14.nix
    # Uncomment for Microsoft Surface:
    # nixos-hardware.nixosModules.microsoft-surface-common
    # Uncomment for gaming:
    # ../../profiles/gaming.nix
  ];

  networking.hostName = "<HOSTNAME>";
  system.stateVersion = "<VERSION>";
}
```

The `microsoft-surface-common` module from `nixos-hardware` configures Surface
WiFi (mwifiex/ath10k), touch, pen, and the surface-aggregator kernel module.

5. `justfile` — add iso recipe

After the build recipe (line ~16), add:

```just
# Build the installer ISO
[group('build')]
iso:
    nix build {{ flake }}#installer
    @echo "ISO: $(ls -1 result/iso/*.iso 2>/dev/null || echo 'build failed')"
```

## Verification

```sh
# Track new files (required — flake copies sources via `self`)
jj file track nixos/installer/configuration.nix
jj file track nixos/installer/bootstrap.sh
jj file track nixos/profiles/installer.nix

# Format
just fmt

# Evaluate flake (catches Nix syntax/type errors without full build)
just check

# Build ISO (~5-15 min first time; cached after that)
just iso
# or: nix build .#installer

# Verify
ls -lh result/iso/*.iso

# Flash: dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress
```

## Surface-Specific Notes (for README or bootstrap script output)

- Disable Secure Boot in UEFI firmware before booting the ISO
- Surface Pro 3/4 may need USB-A adapter for USB boot
- After install, add `nixos-hardware.nixosModules.microsoft-surface-common`
  import and pass `nixos-hardware` in the host's `specialArgs` (already
  provided via `mkHost`)
- `nixos-hardware` input is already in `flake.nix` and passed via `specialArgs` to
  all hosts — no flake change needed to use Surface modules
