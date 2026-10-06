# Container services use `oci-containers` with a Tailnet sidecar

New containerised services on bunyip (first: Stirling-PDF) are declared with `virtualisation.oci-containers`, each paired with a Tailscale sidecar that gives it its own tailnet identity. wherefolk stays on its upstream compose file until it is next touched; the inconsistency is deliberate, because wherefolk ships its own compose file and a second compose-wrapping systemd unit per service would cost more to migrate later than to avoid now.

## Decisions

- **`oci-containers`, not compose.** Images, dependencies and secrets are Nix options; each container is its own systemd unit, so ordering and restarts are systemd's. The sidecar pairing is `--network=container:<sidecar>` plus `dependsOn`.
- **One policy tag and one OAuth client per service** (`tag:stirling`, `secrets/stirling-env.age`). A leaked client can mint nodes only under that tag, which reaches nothing. Reusing wherefolk's credential would let a leak mint `tag:wherefolk` nodes. Each tag gets a deny-all entry in the policy `tests`.
- **Access is `autogroup:member` → the service tag, 443 only.** The app's own port stays on the sidecar's shared loopback and is never granted, so Serve's TLS cannot be bypassed.
- **Images pinned by digest, bumped by Renovate** through a regex manager on the `.nix` image strings. Dependabot cannot read image strings in Nix, so it stays for GitHub Actions only. A `latest` tag would make two identical deploys run different code and make rollback a no-op.
- **Container baseline, applied to every container service** (OWASP Docker Security Cheat Sheet rules 2-8, plus digest pins above). Always: no `--privileged`, no `docker.sock` mount, no published host ports, default seccomp/AppArmor left on, `--cap-drop=ALL` plus only capabilities proven necessary, `--security-opt=no-new-privileges`, `--memory`, `--cpus` and `--pids-limit`. Container logs go to journald (the `oci-containers` default), so retention is journald's, and per-container `--log-opt max-size` is rejected by that driver. Required unless the image cannot support it: a non-root `--user`, and `--read-only` with tmpfs scratch. A container that cannot meet the second group records the reason in its module. The shared `baseline` list lives in `nixos/common/container-baseline.nix` (lifted when micasa became the second service, ADR-0021).
- **Stirling-PDF is a documented exception** to non-root and read-only. Its entrypoint starts as root, creates users, edits `/etc/passwd` and writes under `/usr` and `/var/lib` (about 1,100 paths in `docker diff`) before dropping to uid 1000 with `setpriv`; upstream supports neither flag. It gets `SETUID`/`SETGID` for `setpriv` and `CHOWN`/`DAC_OVERRIDE`/`FOWNER` for the `chown -R`/`chmod -R` it runs building the LibreOffice profile template, and nothing else. The app holds no capabilities after the drop. The sidecar meets the full baseline including `--read-only`.
- **Daemon-level hardening is deferred.** `userns-remap` is daemon-wide and moves Docker to a separate storage root, so wherefolk's images and volumes would vanish from view; rootless Docker is a separate daemon. Either needs its own ADR and migration. Podman with `podman.user` is the per-service alternative if root-in-container becomes unacceptable.

## Considered Options

- **Compose plus a systemd oneshot, mirroring `wherefolk.nix`** — rejected. Consistent today, but images are outside Nix and migrating later is more work than starting idiomatic.
- **Reuse wherefolk's OAuth client / auth key** — rejected. Wider blast radius; an auth key also expires (≤90 days), which bites if the sidecar state volume is wiped.
- **Dockerfile stub so Dependabot can bump images** — rejected as a hack.

## Consequences

- bunyip has two container idioms until wherefolk is migrated.
- Creating the OAuth client and pasting the updated `tailscale/policy.hujson` into the console are manual steps the repo cannot do (ADR-0019).
- Renovate is a second dependency bot alongside Dependabot.
