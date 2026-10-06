# Stirling-PDF on bunyip (SOP)

Tailnet service on bunyip: `stirling-ts` (Tailscale sidecar) + `stirling-pdf` (app). Decisions: ADR-0020. Module: `nixos/common/stirling-pdf.nix`.

## One-time console prerequisites
1. Paste `tailscale/policy.hujson` into Access controls (the console runs `tests`; it refuses a failing policy). Replace placeholder emails first.
2. Settings → OAuth clients → new client, scope **Auth Keys: Write**, tag `tag:stirling`.
3. `cd secrets && agenix -e stirling-env.age`, one line: `TS_AUTHKEY=tskey-client-<secret>?ephemeral=false&preauthorized=true`.

## Verify
- `https://stirling-pdf.armadillo-toad.ts.net` loads from a tailnet device.
- `curl --max-time 5 http://stirling-pdf.armadillo-toad.ts.net:8080` fails.
- LAN host: `curl --max-time 5 http://192.168.86.<bunyip>:8080` fails.
- `ssh bunyip docker ps` shows both containers; `docker logs stirling-pdf` shows no permission errors.

## Symptoms
| Symptom | Cause | Fix |
|---|---|---|
| Connection times out from a member device | Policy not pasted, or tag missing in console | Re-paste policy; check the node is tagged `tag:stirling` |
| Sidecar logs "invalid key" / node never appears | Empty or wrong `stirling-env.age` | Check `/run/agenix/stirling-env` is non-empty; re-create OAuth client |
| New node every restart (`stirling-pdf-1`, `-2`…) | `/var/lib/stirling-ts` lost or wrong owner, or `TS_STATE_DIR` unset | Restore the dir; delete stale nodes in console |
| `stirling-pdf` restarts in a loop, logs stop after the "Binary Versions" block | The init script lacks a capability it needs | `docker inspect -f "{{.State.ExitCode}}" stirling-pdf` and `journalctl -u docker-stirling-pdf`; add only the capability the error names |
| Sidecar logs `chmod /var/lib/tailscale: operation not permitted` / "in-memory store" | State dir ownership wrong | `ls -ln /var/lib/stirling-ts` must show 61002; `systemd-tmpfiles --create` |
| App OOM-killed during large conversion | 4 GB cap | Raise `--memory` (bunyip has 23 GiB; the cap is 4 GB) |

## One-time migration to the non-root sidecar (2026-10)
Run on bunyip BEFORE the deploy that switches `stirling-ts` to `/var/lib/stirling-ts`, or Stirling re-registers as a new node (`stirling-pdf-1`).

```bash
sudo install -d -m 0700 -o 61002 -g 61002 /var/lib/stirling-ts
sudo docker run --rm --entrypoint cp \
  -v stirling-ts-state:/from:ro -v /var/lib/stirling-ts:/to \
  tailscale/tailscale:v1.102.5@sha256:c507f3a2a6ab1cabd8d809b98edeb41edbd5c3fb6ad9632ffd098b4c7d0b4065 \
  -a /from/. /to/
sudo chown -R 61002:61002 /var/lib/stirling-ts
sudo ls -ln /var/lib/stirling-ts   # tailscaled.state present, owner 61002
```

Keep the `stirling-ts-state` volume until the node is verified unchanged after deploy (same name and IP in `tailscale status`); then `docker volume rm stirling-ts-state`.

## Upgrade / rollback
Renovate PRs bump `image = "repo:tag@sha256:…"`. Merge → autodeploy (ADR-0004). Roll back by reverting the commit; the previous digest comes back with the previous generation.

Never delete `/var/lib/stirling-ts` casually: it re-registers the node under a new name.
