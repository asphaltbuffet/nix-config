# NixOS Host Overview (Grafana)

`nixos-host-overview.json` — one dashboard for any fleet of NixOS machines.
It has no hard-coded hosts, jobs, or domains: pick a **Prometheus datasource**
and a **Host** (multi-select) at the top. Hosts are discovered from
`node_uname_info`; the port is stripped so node (`:9100`) and smartctl
(`:9633`) series line up per host.

Import via *Dashboards → New → Import → Upload JSON*, or provision the
directory (`services.grafana.provision.dashboards`).

## Set the datasource's scrape interval

Rate panels (CPU, network, disk IO, PSI, OOM) use `$__rate_interval`. Grafana
derives it from the Prometheus datasource's **Scrape interval** setting
(default 15s). If Prometheus actually scrapes less often (NixOS default: 1m),
the window is too short for `rate()` and those panels show **No data**. Set the
datasource's scrape interval to match yours (`jsonData.timeInterval` when
provisioning).

## What needs which scraper

Everything degrades to **No data** (the panel description says why) if a
scraper is missing.

| Section | Scraper | Provides |
|---|---|---|
| Fleet status, CPU, Memory, Disk, Network, Hardware | `node_exporter` defaults | CPU/mem/disk/net, PSI pressure, hwmon temps/fans, battery |
| Failed units, units by state | node_exporter **systemd collector** | `node_systemd_unit_state{name,state}` — shows what's broken, e.g. a failed `autodeploy.service` |
| Generation, age, reboot pending, release | **NixOS textfile metrics** | `nixos_current_generation`, `nixos_generation_age_seconds`, `nixos_last_switch_timestamp_seconds`, `nixos_reboot_required`, `nixos_info{version}` |
| SMART | `smartctl_exporter` | health, NVMe wear/spare/media errors, temperature, power-on hours, SATA bad-sector counters |

### Enable on NixOS

`nixos/common/nixos-metrics.nix` is self-contained. Import it and:

```nix
services.nixosMetrics.enable = true;   # turns on node_exporter + systemd collector + textfile metrics
services.prometheus.exporters.smartctl.enable = true;   # optional, for the SMART row
```

The textfile script runs every 5 minutes and only reads symlinks
(`/nix/var/nix/profiles/system`, `/run/{booted,current}-system`); it does no
`du` or evaluation. Reboot-pending compares the kernel, initrd, and
kernel-modules of the booted vs. current system.

### Without the module

- systemd collector: `--collector.systemd` on node_exporter.
- NixOS metrics: have any timer write `nixos_*` series to a `*.prom` file in the
  directory given by `--collector.textfile.directory`.

Prometheus only needs to scrape ports 9100 (and 9633 for SMART) with the same
host in `instance`.

## Backups (`backups.json`)

Restic backup health (ADR-0022). Needs the `restic_*` textfile metrics written by
`nixos/common/restic-backup.nix` (hosts with `services.resticBackup.*.enable`).
"Restore size" is the logical size of a source's latest snapshot; repository
size is physical. Freshness panels are informational: a laptop that was off the
home network legitimately ages, and nothing alerts on it.

## Power (`power.json`)

bunyip's UPS via NUT (`nixos/common/ups.nix`). Needs the `nut` Prometheus job
(`prometheus-nut-exporter` on `127.0.0.1:9199`, path `/ups_metrics?ups=cyberpower`)
and, for the Self-test panel, the `ups_selftest_*` textfile metrics. Draw is
UPS load % × `ups.realpower.nominal`. "Last mains failure" and the monthly
figure are bounded by Prometheus retention (15 days), so the month is projected
from the last 7 days.

## Tailnet (`tailnet.json`)

Every **Tailnet device** and the problems among them (ADR-0023). Needs the
`tailscale` Prometheus job (`prometheus-tailscale-exporter` on `127.0.0.1:9250`,
`monitoring.nix`) and the `tailnet_expected_always_on` recording rules it also
defines. View-only: nothing alerts. "Expected devices" are Always-on hosts
(`host.alwaysOn`) plus Tailnet sidecars (`host.tailnetSidecars`); sleeping
laptops are shown with last-seen age and never flagged. The exporter's OAuth
client is read-only (`devices:core:read`, `devices:routes:read`,
`auth_keys:read`, `feature_settings:read`); unused collectors failing for
lack of scope is expected. History is bounded by Prometheus retention.
