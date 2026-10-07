# The tailnet dashboard reads the control-plane API and judges against a Nix-derived expectation

A Grafana dashboard (`dashboards/tailnet.json`) gives an overview of every **Tailnet device** and surfaces problems. Its data comes from Tailscale's control-plane API through the packaged `prometheus-tailscale-exporter` (`services.prometheus.exporters.tailscale`) on bunyip, scraped on localhost. No exporter runs on any other host or device.

## Decisions

- **Control-plane API, not per-node client metrics.** Only the API sees phones, shared-in devices and **Tailnet sidecars**, and only it reports key expiry, update-available and advertised-versus-approved routes. Per-node `tailscale metrics` would need a scraper reachable on every device and would see only flake-managed ones. The cost: no relay-versus-direct data (only per-DERP-region latency). That can be added later by scraping Hosts, without changing this design.
- **The exporter reaches Tailscale over the internet, so the policy is untouched.** ADR-0019's default-deny only governs tailnet flows; no tag or grant is added.
- **Least-privilege OAuth client.** Four read-only scopes: `devices:core:read`, `devices:routes:read`, `auth_keys:read`, `feature_settings:read`. The exporter has no flag to disable collectors, so the unused ones (users, DNS, services, posture, policy) will fail their calls; this is acceptable only if `tailscale_up` stays 1 and the other collectors keep reporting. If a missing scope breaks the whole scrape, fall back to all nine read scopes the exporter documents. The client ID, secret and tailnet name live in an agenix env file.
- **"Expected always-on" is derived from Nix, not from Tailscale.** The exporter's device series carry no tag label, so the dashboard cannot tell a server from a laptop. `monitoring.nix` generates one Prometheus recording rule per expected device, `tailnet_expected_always_on{hostname}`, and the dashboard joins on the exporter's `hostname` label. Hosts are those whose `host.alwaysOn` is true, read through `self.nixosConfigurations`. Sidecar names come from a new `host`-level option that each service module sets (`micasa`, `stirling-pdf`, wherefolk), so the name that registers with Tailscale and the name Prometheus expects are the same value. If reading other Hosts' config makes bunyip's evaluation too slow, fall back to a hand-kept list in `monitoring.nix`.
- **View-only.** No alerts and no Alertmanager. The glossary's **Alert** is host-pushed (ADR-0018); this dashboard is a place to look. A "Problems" row stays empty when healthy. Pushing a notification for the one case that matters (a key about to expire) is a separate later decision.

## Consequences

- A name collision makes Tailscale suffix a device (`micasa-1`), after which the expectation join silently stops matching. The dashboard's "unrecognised device" and "expected device offline" panels both fire in that case, which is how it is caught.
- `tailscale_devices_online` means "seen in the last five minutes", so sleeping laptops read as offline; they are shown with last-seen age and never flagged, matching the **Liveness check** rule.
- History is bounded by Prometheus retention (15 days).
- Creating the OAuth client is a manual console step, and the exporter lags upstream API changes (nixpkgs pins 0.7.0).

## Considered Options

- **Textfile script with `curl` and `jq`** — rejected: reimplements what the packaged exporter and its NixOS module already do, and makes this repo own metric names and API paging.
- **Hard-coded device list in the dashboard JSON** — rejected: breaks the existing dashboards' "no hard-coded hosts" rule.
- **All nine OAuth scopes** — kept only as the fallback: it would let a bunyip compromise read members and the full policy file.
