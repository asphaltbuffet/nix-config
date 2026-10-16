# atuin sync server: upstream image, open registration, AI stays on the hosted Hub

Shell history syncs to a self-hosted atuin server on bunyip instead of atuin's hosted service. The server is a Tailnet service under ADR-0020 and ADR-0024 (`tailnetServices.atuin`, `tag:atuin`, member → 443 only, own OAuth client, container baseline). Its Postgres follows ADR-0021: a separate `atuin-postgres` on an `--internal` `atuin-db` network, in the named volume `atuin-pgdata`, with no backup. The server holds only ciphertext, and every device keeps its full history and the key, so the devices are the backup. This ADR records only the choices those ADRs do not settle.

## Decisions

- **The server image is upstream's `ghcr.io/atuinsh/atuin`, pinned by digest and bumped by Renovate.** This is the ADR-0020 default. micasa builds its relay with Nix only because upstream publishes no relay image (ADR-0021). atuin does publish one, so the exception does not apply.
- **Registration is open.** Any Tailnet member can create an account, because other people in the household use atuin. The tailnet grant is the trust boundary, as with micasa's unset `BLOB_QUOTA`.
- **Clients sync to bunyip fleet-wide.** `sync_address = "https://atuin.armadillo-toad.ts.net"` is set in `home/modules/atuin`, so it applies to every cli-role login, the arcade cabinet included. Sync does nothing until a user logs in. bunyip is tagged `tag:server`, so the member grant does not cover it; a separate `tag:server` → `tag:atuin` 443 grant lets users on bunyip sync too, as an exception to bunyip not being a general-purpose peer.
- **AI stays on atuin's hosted Hub.** In atuin v18.23 the AI endpoint resolves from `ai.endpoint`, which defaults to `hub.atuin.sh`, and never from `sync_address`. A custom `sync_address` makes sync use the Legacy protocol, so the AI's Hub login does not turn hosted sync back on. `ai.endpoint` stays unset. Each device holds two logins: a server account on bunyip for sync and a Hub session for AI.
- **The hosted atuin account is kept.** AI authenticates with it. After cutover, the history synced to it before cutover is deleted by hand if Hub can delete history alone, and left in place otherwise. `atuin account delete` is never run, because it would remove AI too.

## Considered Options

- **Native `services.atuin` with `database.createLocally`** — rejected. It is much less code, but it listens on bunyip's own tailnet IP with no tag or Serve TLS of its own, so it would need a separate reverse proxy and certificate.
- **Nix-built image from `pkgs.atuin`** (the micasa pattern), which would keep server and clients on one version — rejected in favour of the upstream image.
- **A reverse proxy (nginx, Caddy, Traefik)** — rejected. The sidecar's Tailscale Serve already terminates TLS on 443 and proxies to the loopback.
- **Share `micasa-postgres`** — rejected. Two policy tags would share one failure domain and one network.
- **Registration open only for bootstrap** — rejected, because more than one person will use the server.

## Consequences

- The server can run ahead of the clients, which come from nixpkgs (18.21.0 when this was written; upstream was at 18.23.0). atuin's v18 sync protocol has stayed backwards-compatible, so a Renovate bump that jumps a client-breaking major version is the case to watch.
- Losing the server means each user registers again and runs `atuin sync` from their most complete device. A user who loses every device and their Home backup loses their history whatever the server does, because the key goes with them. Keep the key in 1Password.
- AI depends on a third-party service and an account the repo does not manage.
- Any Tailnet member can fill the server's disk. There is no quota.
- Cutover is a per-device manual step: log out, log in or register against bunyip with the existing key, then sync.
