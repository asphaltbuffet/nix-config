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
