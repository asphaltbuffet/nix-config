# micasa relay: Nix-built image, internal DB network, devices as backup

micasa is a terminal app; each machine keeps its own SQLite database and syncs end-to-end encrypted operations through a self-hosted **relay** (HTTP, backed by Postgres). The relay runs on bunyip as a Tailnet service under ADR-0020 (`micasa-ts` sidecar, `tag:micasa`, member → 443 only, own OAuth client, container baseline). This ADR records only where it departs from or extends ADR-0020.

## Decisions

- **The relay image is built by Nix, not pulled by digest.** Upstream publishes no relay image (ghcr carries only the TUI; its compose file builds `deploy/relay/Dockerfile` locally), and its flake packages only `cmd/micasa`. The `micasa` flake input (`nixpkgs.follows`), pinned to a release tag in its URL (`github:micasa-dev/micasa/v2.8.0`) so bunyip never runs unreleased `main`, is overridden to `subPackages = ["cmd/relay"]`, `tags = ["selfhosted"]`, wrapped in `dockerTools.streamLayeredImage`, and loaded with `oci-containers`' `imageStream`. A bump is an edit to that tag plus `nix flake update micasa`, not a Renovate PR. The TUI on workstations comes from the same input, so relay and clients never drift apart. Postgres and the sidecar remain digest-pinned registry images under ADR-0020.
- **A stateful dependency sits on an `--internal` Docker network that the sidecar joins, never in the sidecar's namespace.** With `TS_USERSPACE`, tailscaled forwards inbound tailnet connections to the shared loopback, so a Postgres on `127.0.0.1:5432` there would be closed only by the policy grant. On `micasa-db` (internal, no egress) it is unreachable from the tailnet by construction, and the relay, living in the sidecar's namespace, reaches it as `micasa-postgres:5432`. This is the pattern for any later container service with a database.
- **No backup of the relay's Postgres; the devices are the backup.** The relay holds only ciphertext and device-token hashes, and the household key exists only on devices, so a dump is useless without the devices, and if they survive, they hold the full data. Losing the relay means re-initialising the household from the most complete device and re-joining the rest.

## Considered Options

- **Build upstream's Dockerfile in CI, push to our GHCR, Renovate the digest** — rejected: a workflow, package permissions and an image to maintain, to stay uniform with ADR-0020.
- **Postgres in the sidecar's namespace** — rejected: "443 only" would rest on a single ACL line.
- **Native `services.postgresql` on bunyip** — rejected: containers reach it through the bridge gateway, which needs `pg_hba` holes and a host Postgres listening beyond loopback.
- **Serve the TUI over SSH** (upstream's `services.micasa` NixOS module) — rejected: a shell, not HTTPS 443, and not a container service.

## Consequences

- micasa updates are a manual tag edit, not a Renovate PR; rollback is still reverting the commit.
- The sidecar needs egress and the `--internal` network at once, but Docker refuses to combine the default `bridge` with a user-defined network, so it joins a user-defined `micasa-egress` network instead.
- Upstream verified compatible with the full ADR-0020 baseline: Postgres as `--user=70:70` and the relay as `65534`, both `--read-only` with `--cap-drop=ALL`; no exceptions.
- The relay is the first stateful container service, and `micasa-pgdata` the first volume whose loss costs more than a re-registered node.
- `BLOB_QUOTA` is left unset (unlimited): any tailnet member can create a household and store blobs.
