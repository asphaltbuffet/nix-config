# Server Profile Design

**Date:** 2026-03-31
**Scope:** Clean up `base.nix`, harden `server.nix` with server-specific capabilities, scaffold new host `bunyip`.

---

## Goals

1. Make `base.nix` a true universal base — no laptop-specific defaults.
2. Move all laptop-only config into `nixos/profiles/laptop/default.nix`.
3. Expand `server.nix` with additive-only server capabilities (no more `mkForce` overrides).
4. Add two new common modules: `tailscale-subnet-router.nix` and `monitoring.nix`.
5. Scaffold host `bunyip` (first home-lab server, cryptid naming convention).

---

## 1. `base.nix` Cleanup

### What moves out → `nixos/profiles/laptop/default.nix`

| Item | Reason |
|---|---|
| `fonts.packages` (Fira Code, Roboto Mono) | GUI/display only |
| `services.xserver.xkb` (layout, caps→escape, variant) | X11-specific |
| `services.udev.extraRules` (PC Speaker evdev) | Desktop peripheral |
| `programs.vim` block (full system vim config) | Desktop ergonomic default |
| `services.printing.enable = lib.mkDefault true` | Laptop/desktop default; server sets this explicitly |

### What stays in `base.nix`

All remaining items: SSH, Tailscale, Docker, Nix settings, home-manager wiring, locale/i18n, zsh, nix-ld, networking, `services.envfs`, `programs.nh`, boot loader, `environment.systemPackages` (curl, git, wget, etc.), `boot.supportedFilesystems = ["nfs"]`.

### New addition to `base.nix`

```nix
services.prometheus.exporters.node.enable = true;
```

All hosts (laptops + servers) expose node metrics on port 9100. This allows the monitoring server to scrape every host uniformly without per-host config.

---

## 2. `nixos/profiles/laptop/default.nix` Additions

Receives everything listed in the "moves out" table above. No behavioral change for existing laptop hosts — the items are just co-located in the right profile.

---

## 3. `nixos/profiles/server.nix` Redesign

`server.nix` becomes **additive only** — no `mkForce` overrides needed since `base.nix` no longer sets laptop defaults.

### Kept (already present)

Hardened SSH settings: `PasswordAuthentication = false`, `KbdInteractiveAuthentication = false`, `PermitRootLogin = "no"`, `X11Forwarding = false`.

### Added: CUPS print server

```nix
services.printing.enable = true;
services.avahi = {
  enable = true;
  nssmdns4 = true;  # Bonjour/mDNS discovery for network clients
};
```

Laptops auto-discover the print server via mDNS. No static IP configuration required on clients.

### Added: new module imports

```nix
imports = [
  ../common/tailscale-subnet-router.nix
  ../common/monitoring.nix
];
```

### Removed

All `lib.mkForce false` overrides (bluetooth, printing, xserver, sddm, plasma6, fwupd) — no longer needed.

---

## 4. New Module: `nixos/common/tailscale-subnet-router.nix`

Configures the host as a Tailscale subnet router, advertising the local LAN so non-Tailscale devices (e.g., the NAS at `192.168.86.22`) are reachable from any Tailscale node.

### Design

- Enables kernel IP forwarding via `boot.kernel.sysctl`
- Sets `services.tailscale.useRoutingFeatures = "server"` (NixOS handles the required kernel flags)
- Exposes a NixOS option `services.tailscaleSubnetRouter.routes` (list of strings, default `["192.168.86.0/24"]`) so future hosts can override the advertised subnet
- Adds a one-shot systemd service (`tailscale-advertise-routes`) that runs after `tailscaled.service` and executes:
  ```
  tailscale set --advertise-routes=<routes>
  ```
  The service is idempotent — re-running it on boot is safe.

### Note

Route advertisement also requires approval in the Tailscale admin console (one-time manual step, not automated).

---

## 5. New Module: `nixos/common/monitoring.nix`

Runs Prometheus (metrics collection) and Grafana (visualization) on the server. All scrape targets use Tailscale MagicDNS FQDNs (`<host>.armadillo-toad.ts.net`) — never bare IPs for NixOS hosts.

### Prometheus

```nix
services.prometheus = {
  enable = true;
  port = 9090;
  scrapeConfigs = [
    {
      job_name = "node";
      static_configs = [{
        targets = [
          "bunyip.armadillo-toad.ts.net:9100"
          "wendigo.armadillo-toad.ts.net:9100"
          "kushtaka.armadillo-toad.ts.net:9100"
          "snallygaster.armadillo-toad.ts.net:9100"
        ];
      }];
    }
  ];
};
```

Non-NixOS devices that cannot run Tailscale are added as additional scrape targets using bare IPs. These are managed as a separate `job_name = "node-unmanaged"` list in the module for clarity.

### Grafana

```nix
services.grafana = {
  enable = true;
  settings.server = {
    http_addr = "0.0.0.0";
    http_port = 3000;
    domain = "bunyip.armadillo-toad.ts.net";
  };
};
```

Grafana binds to all interfaces but is only reachable via Tailscale (the existing `tailscale.nix` firewall config trusts `tailscale0`). No reverse proxy required in this scope.

A Prometheus datasource is provisioned automatically:

```nix
services.grafana.provision.datasources.settings.datasources = [{
  name = "Prometheus";
  type = "prometheus";
  url = "http://localhost:9090";
  isDefault = true;
}];
```

---

## 6. New Host: `bunyip`

### `nixos/hosts/bunyip/configuration.nix`

```nix
{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../common/users.nix
    ../../profiles/base.nix
    ../../profiles/server.nix
  ];

  networking.hostName = "bunyip";
  system.stateVersion = "25.05";
  system.autoDeploy.enable = true;
}
```

### `nixos/hosts/bunyip/hardware-configuration.nix`

Generated on the physical machine with `nixos-generate-config`, then committed here. A placeholder file is added to the repo so the flake auto-discovers the host immediately; it is replaced at install time.

### User access

The existing `grue` user (defined in `nixos/common/users.nix`) is used as-is. No new users required.

---

## 7. Tailscale Firewall Considerations

`nixos/common/tailscale.nix` already marks `tailscale0` as a trusted interface and opens the Tailscale UDP port. No changes needed. Grafana (3000) and Prometheus (9090) are reachable from any authenticated Tailscale device without additional firewall rules.

---

## 8. Out of Scope (Deferred)

The following were categorized as **Later** and are tracked in `TODO.md`:

- Persistent tmux/zellij user sessions
- Reverse proxy (nginx/Caddy) for self-hosted apps
- Container workloads (Podman/NixOS containers)
- Automated backups (restic)
- CI/build runner (top priority for next iteration)
- Media server (Jellyfin)

---

## File Change Summary

| File | Action |
|---|---|
| `nixos/profiles/base.nix` | Remove laptop-specific items; add `node_exporter` |
| `nixos/profiles/laptop/default.nix` | Add fonts, xkb, udev, vim, printing |
| `nixos/profiles/server.nix` | Remove `mkForce` overrides; add CUPS/Avahi; import new modules |
| `nixos/common/tailscale-subnet-router.nix` | New |
| `nixos/common/monitoring.nix` | New |
| `nixos/hosts/bunyip/configuration.nix` | New |
| `nixos/hosts/bunyip/hardware-configuration.nix` | New (placeholder) |
| `TODO.md` | Add deferred items |
