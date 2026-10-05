# Container services use `oci-containers` with a Tailnet sidecar

New containerised services on bunyip (first: Stirling-PDF) are declared with `virtualisation.oci-containers`, each paired with a Tailscale sidecar that gives it its own tailnet identity. wherefolk stays on its upstream compose file until it is next touched; the inconsistency is deliberate, because wherefolk ships its own compose file and a second compose-wrapping systemd unit per service would cost more to migrate later than to avoid now.

## Decisions

- **`oci-containers`, not compose.** Images, dependencies and secrets are Nix options; each container is its own systemd unit, so ordering and restarts are systemd's. The sidecar pairing is `--network=container:<sidecar>` plus `dependsOn`.
- **One policy tag and one OAuth client per service** (`tag:stirling`, `secrets/stirling-env.age`). A leaked client can mint nodes only under that tag, which reaches nothing. Reusing wherefolk's credential would let a leak mint `tag:wherefolk` nodes. Each tag gets a deny-all entry in the policy `tests`.
- **Access is `autogroup:member` → the service tag, 443 only.** The app's own port stays on the sidecar's shared loopback and is never granted, so Serve's TLS cannot be bypassed.
- **Images pinned by digest, bumped by Renovate** through a regex manager on the `.nix` image strings. Dependabot cannot read image strings in Nix, so it stays for GitHub Actions only. A `latest` tag would make two identical deploys run different code and make rollback a no-op.
- **App container is confined:** read-only root with `tmpfs` scratch, all capabilities dropped, `no-new-privileges`, memory and CPU limits. It processes untrusted uploads from any member and shares a network namespace with a tailnet node.

## Considered Options

- **Compose plus a systemd oneshot, mirroring `wherefolk.nix`** — rejected. Consistent today, but images are outside Nix and migrating later is more work than starting idiomatic.
- **Reuse wherefolk's OAuth client / auth key** — rejected. Wider blast radius; an auth key also expires (≤90 days), which bites if the sidecar state volume is wiped.
- **Dockerfile stub so Dependabot can bump images** — rejected as a hack.

## Consequences

- bunyip has two container idioms until wherefolk is migrated.
- Creating the OAuth client and pasting the updated `tailscale/policy.hujson` into the console are manual steps the repo cannot do (ADR-0019).
- Renovate is a second dependency bot alongside Dependabot.
