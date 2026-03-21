---
name: add-host
description: Guide through adding a new NixOS host to the flake. Use when adding a new machine (laptop, desktop, or server) to the nix-config repo.
---

# Add NixOS Host

Follow these steps to add a new host to the flake.

## Step 1: Determine host type

Ask the user what kind of machine this is:

- **laptop** — portable machine; import `profiles/laptop/` (KDE Plasma + SDDM + bluetooth + power management)
- **desktop** — stationary workstation with GUI; import `profiles/laptop/` + optionally `profiles/gaming.nix`
- **server** — headless home-lab node; import `profiles/server.nix` (no GUI, no desktop services)

## Step 2: Create host directory and configuration

Create `nixos/hosts/<name>/configuration.nix` using the appropriate template below.

### Template: laptop or desktop

```nix
# nixos/hosts/<name>/configuration.nix
{
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../profiles/base.nix
    ../../profiles/laptop  # omit for server; add ../../profiles/gaming.nix for gaming desktop
  ];

  networking.hostName = "<name>";

  # Add any host-specific overrides here
}
```

### Template: server

```nix
# nixos/hosts/<name>/configuration.nix
{
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../profiles/base.nix
    ../../profiles/server.nix
  ];

  networking.hostName = "<name>";

  # Add any host-specific overrides here
}
```

## Step 3: Generate hardware configuration

**hardware-configuration.nix must be generated on the target hardware** — it captures disk layout, CPU, and hardware-specific kernel modules.

On the target machine, run:
```bash
nixos-generate-config --show-hardware-config > /tmp/hardware-configuration.nix
```

Then copy the output to `nixos/hosts/<name>/hardware-configuration.nix` in this repo.

## Step 4: Add users

Edit `nixos/common/users.nix` to:
1. Add the system user definition under `users.users.<username>`
2. Add the home-manager mapping: `home-manager.users.<username> = import ../../home/users/<username>.nix`

If this user doesn't have a `home/users/<username>.nix` yet, create it (see `/add-module` for the home-manager side).

## Step 5: Track new files

The flake copies sources via `self` — new files must be tracked before `just build` can see them:

```bash
jj file track nixos/hosts/<name>/configuration.nix
jj file track nixos/hosts/<name>/hardware-configuration.nix
```

**Never use `git add`** — this is a jujutsu repo.

## Step 6: Build to verify

```bash
just build <name>
```

Fix any evaluation errors before proceeding. Common issues:
- Missing `hardware-configuration.nix` — placeholder it if building before hardware is available
- Hardware-specific modules (e.g., `hardware.cpu.intel.updateMicrocode`) that don't match your hardware

## Host type matrix

| Profile combo | Use case |
|---|---|
| `base.nix` + `server.nix` | Headless home-lab server |
| `base.nix` + `laptop/` | Laptop or desktop with GUI |
| `base.nix` + `laptop/` + `gaming.nix` | Gaming desktop |
| `base.nix` + `laptop/` + `laptop/t14.nix` | Lenovo ThinkPad T14 |
| `base.nix` + `laptop/` + `laptop/x1carbon.nix` | Lenovo ThinkPad X1 Carbon |
