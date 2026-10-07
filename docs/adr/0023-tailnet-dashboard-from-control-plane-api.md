# The tailnet dashboard reads the control-plane API and judges against a Nix-derived expectation

A Grafana dashboard (`dashboards/tailnet.json`) gives an overview of every **Tailnet device** and surfaces problems. Its data comes from Tailscale's control-plane API through the packaged `prometheus-tailscale-exporter` (`services.prometheus.exporters.tailscale`) on bunyip, scraped on localhost. No exporter runs on any other host or device.

## Decisions

- **Control-plane API, not per-node client metrics.** Only the API sees phones, shared-in devices and **Tailnet sidecars**, and only it reports key expiry, update-available and advertised-versus-approved routes. Per-node `tailscale metrics` would need a scraper reachable on every device and would see only flake-managed ones. The cost: no relay-versus-direct data (only per-DERP-region latency). That can be added later by scraping Hosts, without changing this design.
- **The exporter reaches Tailscale over the internet, so the policy is untouched.** ADR-0019's default-deny only governs tailnet flows; no tag or grant is added.
- **OAuth client with all nine read scopes.** The exporter requests every read scope in its token call (`devices:core:read`, `devices:posture_attributes:read`, `devices:routes:read`, `services:read`, `users:read`, `dns:read`, `auth_keys:read`, `feature_settings:read`, `policy_file:read`), so the client carries all nine; with fewer it exits at startup ("failed to obtain OAuth token") and the unit restart-loops. A four-scope client was planned and dropped for that reason. The accepted cost: the credential on bunyip can read members and the policy file, read-only. The client ID, secret and tailnet name live in an agenix env file.
- **"Expected always-on" is derived from Nix, not from Tailscale.** The exporter's device series carry no tag label, so the dashboard cannot tell a server from a laptop. `monitoring.nix` generates one Prometheus recording rule per expected device, `tailnet_expected_always_on{hostname}`, and the dashboard joins on the exporter's `hostname` label. Hosts are those whose `host.alwaysOn` is true, read through `self.nixosConfigurations`. Sidecar names come from a new `host`-level option that each service module sets (`micasa`, `stirling-pdf`, wherefolk), so the name that registers with Tailscale and the name Prometheus expects are the same value. If reading other Hosts' config makes bunyip's evaluation too slow, fall back to a hand-kept list in `monitoring.nix`.
- **View-only.** No alerts and no Alertmanager. The glossary's **Alert** is host-pushed (ADR-0018); this dashboard is a place to look. A "Problems" row stays empty when healthy. The "Exporter down" tile keys off `tailscale_scrape_collector_success{collector="devices"}` because `tailscale_up` is a constant 1. Pushing a notification for the one case that matters (a key about to expire) is a separate later decision.

## Consequences

- A name collision makes Tailscale suffix a device's MagicDNS name (`micasa-1`), but the exporter's `hostname` label is the device-reported hostname, so the expectation join can keep matching and mask a stale duplicate. It is caught by the "New devices (7d)" tile and by duplicate rows in the device table.
- `tailscale_devices_online` means "seen in the last five minutes", so sleeping laptops read as offline; they are shown with last-seen age and never flagged, matching the **Liveness check** rule.
- History is bounded by Prometheus retention (15 days).
- Creating the OAuth client is a manual console step, and the exporter lags upstream API changes (nixpkgs pins 0.7.0).

## Considered Options

- **Textfile script with `curl` and `jq`** — rejected: reimplements what the packaged exporter and its NixOS module already do, and makes this repo own metric names and API paging.
- **Hard-coded device list in the dashboard JSON** — rejected: breaks the existing dashboards' "no hard-coded hosts" rule.
- **Four-scope OAuth client** — rejected: the exporter requests all nine scopes at token time and exits without them.
