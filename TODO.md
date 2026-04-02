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

## GitHub Actions — CI disk space

Fixes #2 and #3 below are available if the `free-disk-space` action (already applied) doesn't fully resolve runner OOM:

- [ ] **Lower `gc-max-store-size`** in `cache-nix-action` — reduce from `2000000000` to ~`1500000000` so more headroom remains after cache restore
- [ ] **`min-free` / `max-free` in `nix.conf`** — add to `install-nix-action`'s `extra_nix_config` so Nix self-GCs mid-build:
  ```yaml
  extra_nix_config: |
    min-free = 1073741824
    max-free = 3221225472
  ```
