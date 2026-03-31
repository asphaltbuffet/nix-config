# Server Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clean up `base.nix` into a true universal base, expand `server.nix` with CUPS/monitoring/subnet-router capabilities, and scaffold the new host `bunyip`.

**Architecture:** Laptop-specific config migrates from `base.nix` into `laptop/default.nix`; `server.nix` becomes additive-only; two new common modules (`tailscale-subnet-router.nix`, `monitoring.nix`) are created and imported by `server.nix`; host `bunyip` is auto-discovered by the flake once its directory exists.

**Tech Stack:** NixOS modules, home-manager, Prometheus + node_exporter, Grafana, Tailscale MagicDNS, CUPS, Avahi, alejandra (formatter), `just build` (build verification).

---

## File Map

| File | Action |
|---|---|
| `nixos/profiles/base.nix` | Remove 5 laptop-specific items; add `node_exporter` |
| `nixos/profiles/laptop/default.nix` | Add fonts, xkb, udev, vim, printing (moved from base) |
| `nixos/profiles/server.nix` | Remove all `mkForce` overrides; add CUPS/Avahi; import new modules |
| `nixos/common/tailscale-subnet-router.nix` | New — subnet router with configurable routes option |
| `nixos/common/monitoring.nix` | New — Prometheus + Grafana with Tailscale FQDN scrape targets |
| `nixos/hosts/bunyip/configuration.nix` | New — host entry point |
| `nixos/hosts/bunyip/hardware-configuration.nix` | New — placeholder (replaced at install time) |
| `TODO.md` | New — deferred items from design session |

---

## Task 1: Clean up `base.nix` — remove laptop-specific config

**Files:**
- Modify: `nixos/profiles/base.nix`

Remove five items that belong in the laptop profile. The laptop hosts will temporarily lose these until Task 2, so build verification for laptop hosts happens after Task 2.

- [ ] **Step 1: Remove `fonts.packages` from `base.nix`**

Delete these lines from `nixos/profiles/base.nix`:

```nix
  fonts.packages = with pkgs; [
    fira-code
    roboto-mono
  ];
```

- [ ] **Step 2: Remove `services.xserver.xkb` from `base.nix`**

Delete these lines:

```nix
  services.xserver.xkb = {
    layout = "us";
    options = "caps:swapescape";
    variant = "";
  };
```

- [ ] **Step 3: Remove `services.udev.extraRules` from `base.nix`**

Delete these lines:

```nix
  # Grant the active console user access to the PC speaker evdev node without
  # adding them to the broad `input` group (which would expose all input devices).
  services.udev.extraRules = ''
    SUBSYSTEM=="input", ATTRS{name}=="PC Speaker", TAG+="uaccess"
  '';
```

- [ ] **Step 4: Remove `programs.vim` block from `base.nix`**

Delete these lines (the full block from `programs.vim = {` through its closing `};`):

```nix
  programs.vim = {
    enable = true;
    defaultEditor = true;
    package = (pkgs.vim-full.override {}).customize {
      name = "vim";
      # Install plugins for example for syntax highlighting of nix files
      vimrcConfig.packages.myplugins = with pkgs.vimPlugins; {
        start = [
          vim-sensible
          vim-nix
          vim-lastplace
          vim-surround
          vim-commentary
          vim-repeat
          vim-unimpaired
        ];
        opt = [];
      };
      vimrcConfig.customRC = ''
        set gcr=a:blinkon0
        let mapleader=','
        set hlsearch
        set fileformats=unix,dos,mac

        noremap <leader>h :<C-u>split<CR>
        noremap <leader>v :<C-u>vsplit<CR>
      '';
    };
  };
```

- [ ] **Step 5: Remove `services.printing.enable` from `base.nix`**

Delete this line:

```nix
  services.printing.enable = lib.mkDefault true;
```

- [ ] **Step 6: Add `node_exporter` to `base.nix`**

Add after `services.envfs.enable = true;`:

```nix
  services.prometheus.exporters.node.enable = true;
```

- [ ] **Step 7: Remove unused `lib` from `base.nix` function args if no longer needed**

Check the remaining uses of `lib` in `base.nix`. The file still uses `lib.mkDefault` in `services.tailscale.enable`, `services.openssh`, and `programs.nh.clean.extraArgs`, so `lib` stays. No change needed.

- [ ] **Step 8: Format**

```bash
just fmt
```

- [ ] **Step 9: Verify server build passes (laptop build expected to fail until Task 2)**

```bash
just build bunyip
```

Note: `bunyip` doesn't exist yet — skip this for now. Instead verify the file is syntactically valid:

```bash
nix-instantiate --parse nixos/profiles/base.nix
```

Expected: no errors printed.

- [ ] **Step 10: Commit**

```bash
jj describe -m "refactor(base): extract laptop-specific config; add node_exporter to all hosts"
jj new
```

---

## Task 2: Move laptop-specific config into `laptop/default.nix`

**Files:**
- Modify: `nixos/profiles/laptop/default.nix`

Add all five items removed from `base.nix`. After this task, laptop builds must pass again.

- [ ] **Step 1: Add `fonts.packages` to `laptop/default.nix`**

Add to `nixos/profiles/laptop/default.nix` (inside the top-level attrset, after the existing content):

```nix
  fonts.packages = with pkgs; [
    fira-code
    roboto-mono
  ];
```

- [ ] **Step 2: Add `services.xserver.xkb` to `laptop/default.nix`**

```nix
  services.xserver.xkb = {
    layout = "us";
    options = "caps:swapescape";
    variant = "";
  };
```

- [ ] **Step 3: Add `services.udev.extraRules` to `laptop/default.nix`**

```nix
  # Grant the active console user access to the PC speaker evdev node without
  # adding them to the broad `input` group (which would expose all input devices).
  services.udev.extraRules = ''
    SUBSYSTEM=="input", ATTRS{name}=="PC Speaker", TAG+="uaccess"
  '';
```

- [ ] **Step 4: Add `programs.vim` to `laptop/default.nix`**

```nix
  programs.vim = {
    enable = true;
    defaultEditor = true;
    package = (pkgs.vim-full.override {}).customize {
      name = "vim";
      vimrcConfig.packages.myplugins = with pkgs.vimPlugins; {
        start = [
          vim-sensible
          vim-nix
          vim-lastplace
          vim-surround
          vim-commentary
          vim-repeat
          vim-unimpaired
        ];
        opt = [];
      };
      vimrcConfig.customRC = ''
        set gcr=a:blinkon0
        let mapleader=','
        set hlsearch
        set fileformats=unix,dos,mac

        noremap <leader>h :<C-u>split<CR>
        noremap <leader>v :<C-u>vsplit<CR>
      '';
    };
  };
```

- [ ] **Step 5: Add `services.printing.enable` to `laptop/default.nix`**

```nix
  services.printing.enable = true;
```

(No `mkDefault` needed — this is the laptop profile's explicit choice.)

- [ ] **Step 6: Ensure `laptop/default.nix` function args include `pkgs` and `lib`**

The file already has `{pkgs, lib, ...}:` — confirm it's still there. No change needed.

- [ ] **Step 7: Format**

```bash
just fmt
```

- [ ] **Step 8: Build all three laptop hosts to verify no regression**

```bash
just build wendigo
just build kushtaka
just build snallygaster
```

Expected: all three succeed.

- [ ] **Step 9: Commit**

```bash
jj describe -m "feat(laptop): absorb fonts, xkb, udev, vim, printing from base"
jj new
```

---

## Task 3: Rewrite `server.nix` — additive only, CUPS, module imports

**Files:**
- Modify: `nixos/profiles/server.nix`

Replace the entire file content. The `mkForce` overrides are gone; CUPS/Avahi are added; new module imports are added. The new modules don't exist yet (Tasks 4–5), so build verification happens after Task 5.

- [ ] **Step 1: Replace `server.nix` with the new content**

Replace the full content of `nixos/profiles/server.nix` with:

```nix
# nixos/profiles/server.nix
# Headless server profile. Import alongside base.nix for home-lab nodes.
# Do NOT import laptop/ with this profile — they are mutually exclusive.
{...}: {
  imports = [
    ../common/tailscale-subnet-router.nix
    ../common/monitoring.nix
  ];

  # Harden SSH for server use
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };

  # CUPS print server — serve printers to the network via mDNS/Bonjour
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };
}
```

- [ ] **Step 2: Format**

```bash
just fmt
```

- [ ] **Step 3: Parse check (full build deferred to Task 5)**

```bash
nix-instantiate --parse nixos/profiles/server.nix
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
jj describe -m "refactor(server): drop mkForce overrides; add CUPS/Avahi; wire new module imports"
jj new
```

---

## Task 4: Create `tailscale-subnet-router.nix`

**Files:**
- Create: `nixos/common/tailscale-subnet-router.nix`

Advertises LAN subnet routes via Tailscale so non-Tailscale devices (NAS, printers, etc.) are reachable from all Tailscale nodes. Exposes a configurable `routes` option.

- [ ] **Step 1: Create the module**

Create `nixos/common/tailscale-subnet-router.nix`:

```nix
# nixos/common/tailscale-subnet-router.nix
#
# Configures this host as a Tailscale subnet router.
# Advertises LAN routes so non-Tailscale devices are reachable from
# any node on the tailnet.
#
# After deploying, approve the advertised routes in the Tailscale admin
# console: https://login.tailscale.com/admin/machines
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.tailscaleSubnetRouter;
  routesStr = lib.concatStringsSep "," cfg.routes;
in {
  options.services.tailscaleSubnetRouter = {
    routes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["192.168.86.0/24"];
      description = "CIDR subnets to advertise as Tailscale routes.";
    };
  };

  config = {
    # useRoutingFeatures = "server" sets the required kernel sysctl flags
    # (net.ipv4.ip_forward and net.ipv6.conf.all.forwarding) automatically.
    services.tailscale.useRoutingFeatures = "server";

    # One-shot service that advertises routes after tailscaled is running.
    # Idempotent: running it again on reboot is safe.
    systemd.services.tailscale-advertise-routes = {
      description = "Advertise Tailscale subnet routes";
      after = ["tailscaled.service" "network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.tailscale}/bin/tailscale set --advertise-routes=${routesStr}";
      };
    };
  };
}
```

- [ ] **Step 2: Track the new file in jj**

```bash
jj file track nixos/common/tailscale-subnet-router.nix
```

- [ ] **Step 3: Format**

```bash
just fmt
```

- [ ] **Step 4: Parse check**

```bash
nix-instantiate --parse nixos/common/tailscale-subnet-router.nix
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
jj describe -m "feat(common): add tailscale-subnet-router module"
jj new
```

---

## Task 5: Create `monitoring.nix`

**Files:**
- Create: `nixos/common/monitoring.nix`

Runs Prometheus (scrapes all four NixOS hosts by Tailscale FQDN) and Grafana (visualization, auto-provisioned Prometheus datasource). A placeholder job for non-Tailscale devices is included for future use.

- [ ] **Step 1: Create the module**

Create `nixos/common/monitoring.nix`:

```nix
# nixos/common/monitoring.nix
#
# Prometheus + Grafana monitoring stack for bunyip.
#
# Prometheus scrapes node_exporter (port 9100) from all NixOS hosts via
# Tailscale MagicDNS FQDNs. Non-NixOS devices without Tailscale are added
# to the "node-unmanaged" job by bare IP.
#
# Grafana binds to 0.0.0.0:3000 but is only reachable via the tailscale0
# interface (trusted in nixos/common/tailscale.nix).
{...}: {
  services.prometheus = {
    enable = true;
    port = 9090;

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [
              "bunyip.armadillo-toad.ts.net:9100"
              "wendigo.armadillo-toad.ts.net:9100"
              "kushtaka.armadillo-toad.ts.net:9100"
              "snallygaster.armadillo-toad.ts.net:9100"
            ];
          }
        ];
      }
      {
        # Non-NixOS devices that cannot run Tailscale — add bare IPs here.
        job_name = "node-unmanaged";
        static_configs = [
          {
            targets = [];
          }
        ];
      }
    ];
  };

  services.grafana = {
    enable = true;

    settings.server = {
      http_addr = "0.0.0.0";
      http_port = 3000;
      domain = "bunyip.armadillo-toad.ts.net";
    };

    provision.datasources.settings.datasources = [
      {
        name = "Prometheus";
        type = "prometheus";
        url = "http://localhost:9090";
        isDefault = true;
      }
    ];
  };
}
```

- [ ] **Step 2: Track the new file in jj**

```bash
jj file track nixos/common/monitoring.nix
```

- [ ] **Step 3: Format**

```bash
just fmt
```

- [ ] **Step 4: Parse check**

```bash
nix-instantiate --parse nixos/common/monitoring.nix
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
jj describe -m "feat(common): add monitoring module (Prometheus + Grafana)"
jj new
```

---

## Task 6: Scaffold host `bunyip`

**Files:**
- Create: `nixos/hosts/bunyip/configuration.nix`
- Create: `nixos/hosts/bunyip/hardware-configuration.nix` (placeholder)

The flake auto-discovers hosts from directory names in `nixos/hosts/`. Once these files exist and are tracked, `just build bunyip` exercises the full stack.

- [ ] **Step 1: Create `nixos/hosts/bunyip/configuration.nix`**

```nix
{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../common/users.nix
    ../../profiles/base.nix
    ../../profiles/server.nix
  ];

  networking.hostName = "bunyip";

  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  # Pull NixOS updates automatically from CI via cachix + GitHub Pages.
  # Create .autodeploy-skip/bunyip to pause without editing this file.
  system.autoDeploy.enable = true;
}
```

- [ ] **Step 2: Create placeholder `hardware-configuration.nix`**

This file will be replaced by `nixos-generate-config` output at install time. The placeholder is the minimal valid NixOS hardware config that allows the flake to evaluate:

```nix
# nixos/hosts/bunyip/hardware-configuration.nix
#
# PLACEHOLDER — replace with output of `nixos-generate-config` run on the
# physical machine before deploying.
{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
```

- [ ] **Step 3: Track both new files in jj**

```bash
jj file track nixos/hosts/bunyip/configuration.nix nixos/hosts/bunyip/hardware-configuration.nix
```

- [ ] **Step 4: Format**

```bash
just fmt
```

- [ ] **Step 5: Build `bunyip` — this is the full integration build**

```bash
just build bunyip
```

Expected: succeeds. This validates `base.nix`, `server.nix`, `tailscale-subnet-router.nix`, and `monitoring.nix` all evaluate correctly together.

If it fails with an evaluation error, read the error carefully — most common causes:
- Missing `lib` in a function arg (`{lib, ...}:` forgotten)
- Option type mismatch in `tailscaleSubnetRouter.routes`
- Grafana `provision.datasources` path wrong for your nixpkgs version (check with `nixd` or `nix repl`)

- [ ] **Step 6: Build all laptop hosts to confirm no regression**

```bash
just build wendigo && just build kushtaka && just build snallygaster
```

Expected: all three succeed.

- [ ] **Step 7: Commit**

```bash
jj describe -m "feat(hosts): add bunyip server host (placeholder hardware config)"
jj new
```

---

## Task 7: Create `TODO.md` with deferred items

**Files:**
- Create: `TODO.md`

- [ ] **Step 1: Create `TODO.md`**

```markdown
# TODO

Items deferred from the home-lab server design session (2026-03-31).
Implement in separate design → plan cycles.

## bunyip — future capabilities

- [ ] **Persistent dev sessions** — tmux or zellij running as a user service so SSH sessions survive disconnects
- [ ] **Reverse proxy** — nginx or Caddy for self-hosted apps behind local HTTPS
- [ ] **Container workloads** — Podman or NixOS declarative containers for service isolation
- [ ] **Automated backups** — restic with systemd timers to local disk or Backblaze B2
- [ ] **CI / build runner** *(top priority)* — Forgejo runner or Nix remote builder to offload flake builds from laptops
- [ ] **Media server** — Jellyfin for local video/audio streaming
```

- [ ] **Step 2: Track the file in jj**

```bash
jj file track TODO.md
```

- [ ] **Step 3: Commit**

```bash
jj describe -m "docs: add TODO with deferred home-lab server features"
jj new
```

---

## Self-Review

**Spec coverage:**
- ✓ `base.nix` cleanup (Task 1)
- ✓ `laptop/default.nix` additions (Task 2)
- ✓ `server.nix` rewrite (Task 3)
- ✓ `tailscale-subnet-router.nix` (Task 4)
- ✓ `monitoring.nix` (Task 5)
- ✓ `bunyip` host scaffolding (Task 6)
- ✓ `TODO.md` deferred items (Task 7)

**Placeholder scan:** No TBD/TODO in code steps. Placeholder hardware-configuration.nix is explicitly labeled as such with instructions. Empty `node-unmanaged` targets list is intentional and documented inline.

**Type consistency:**
- `services.tailscaleSubnetRouter.routes` defined in Task 4, only used internally in that module — no cross-task type dependencies.
- `services.prometheus.exporters.node.enable` added in Task 1, consumed by `monitoring.nix` in Task 5 — consistent: both are boolean enables on the NixOS option.
- Grafana provisioning path `provision.datasources.settings.datasources` used consistently.
