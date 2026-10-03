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
