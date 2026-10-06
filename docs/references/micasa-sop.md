# micasa relay on bunyip (SOP)

Tailnet service on bunyip: `micasa-ts` (sidecar) + `micasa-relay` (shares its namespace) + `micasa-postgres` (internal network `micasa-db`). Decisions: ADR-0020, ADR-0021. Module: `nixos/common/micasa.nix`. Client: `home/modules/micasa/`.

## One-time prerequisites
1. Paste `tailscale/policy.hujson` into Access controls (real emails restored).
2. OAuth client, scope **Auth Keys: Write**, tag `tag:micasa`.
3. Two hex values: `nix shell "nixpkgs#openssl" -c openssl rand -hex 32` (password, encryption key).
4. `cd secrets` and `agenix -e` each file:
   - `micasa-ts-env.age`: `TS_AUTHKEY=tskey-client-<secret>?ephemeral=false&preauthorized=true`
   - `micasa-db-env.age`: `POSTGRES_PASSWORD=<pw>`
   - `micasa-relay-env.age`: `DATABASE_URL=postgres://micasa:<pw>@micasa-postgres:5432/micasa?sslmode=disable` and `RELAY_ENCRYPTION_KEY=<key>`

The password is in two files by design. Changing it after first boot also needs an `ALTER USER` inside Postgres (`POSTGRES_PASSWORD` only applies when the volume is initialised): `docker exec -it micasa-postgres psql -U micasa -c "ALTER USER micasa PASSWORD '<pw>'"`.

## Join machines to the household
First machine: `micasa pro init --relay-url https://micasa.armadillo-toad.ts.net`.
Each other machine: on a joined machine run `micasa pro invite` (code valid 4 h), then on the new one `micasa pro join <code> --relay-url https://micasa.armadillo-toad.ts.net`. The inviting machine must be running micasa to complete the key exchange (15 min window).

## Verify
- `curl -s https://micasa.armadillo-toad.ts.net/health` → `{"status":"ok"}` from a tailnet device.
- `curl --max-time 5 http://micasa.armadillo-toad.ts.net:8080` and `:5432` fail.
- `ssh bunyip docker ps` shows all three; `ssh bunyip docker logs micasa-relay 2>&1 | rg 'in-memory'` prints nothing.

## Symptoms
| Symptom | Cause | Fix |
|---|---|---|
| Data gone after relay restart; log says "using in-memory store" | `micasa-relay-env` empty or missing `DATABASE_URL` | Check `/run/agenix/micasa-relay-env` is non-empty; re-create the secret |
| Relay restarts in a loop, "open postgres" / auth failed | Password differs between db-env and relay-env, or Postgres still initialising | Wait 30 s on first boot; otherwise make the two match (see `ALTER USER` above) |
| Relay logs "RELAY_ENCRYPTION_KEY is required" | Key missing from relay-env | Add it; only in-flight invites are affected by changing it |
| Sidecar or Postgres unit fails, "network micasa-db not found" | `docker-network-micasa` did not run | `systemctl status docker-network-micasa`; restart it, then the containers |
| Connection times out from a member device | Policy not pasted, or node not tagged `tag:micasa` | Re-paste policy; check the node's tag |
| New node every restart (`micasa-1`, `-2`…) | `/var/lib/micasa-ts` lost or wrong owner | Restore the dir; `ls -ln /var/lib/micasa-ts` must show 61001, else `systemd-tmpfiles --create`; delete stale nodes in the console |
| Relay unit `failed`, `start-limit-hit` | Restarted too fast while Postgres initialised | `systemctl reset-failed docker-micasa-relay && systemctl start docker-micasa-relay` |
| Serve returns 502 after the sidecar crashed or restarted on its own | Relay still in the dead namespace (only an explicit sidecar restart restarts it) | `systemctl restart docker-micasa-relay` (rejoins the new namespace) |
| Sidecar logs `chmod /var/lib/tailscale: operation not permitted` / "in-memory store" | State dir ownership wrong | `ls -ln /var/lib/micasa-ts` must show 61001; `systemd-tmpfiles --create` |

## Relay lost (volume gone, bunyip rebuilt)
No backup by design (ADR-0021): every device holds the full data, and a dump is useless without the devices' keys. Pick the device with the most complete data, run `micasa pro init --relay-url …` there to create a new household, then re-join the others with `invite`/`join`. Check what the other devices' local data looks like after joining before discarding anything.

Never delete `/var/lib/micasa-ts` or `docker volume rm micasa-pgdata` casually.

## Upgrade / rollback
Edit the tag in `flake.nix` (`github:micasa-dev/micasa/vX.Y.Z`), `nix flake update micasa`, build, merge → autodeploy. TUI and relay move together. Postgres and the sidecar are bumped by Renovate digest PRs. Roll back by reverting the commit. A major Postgres bump (17 → 18) needs a dump/restore, not just a digest change.
