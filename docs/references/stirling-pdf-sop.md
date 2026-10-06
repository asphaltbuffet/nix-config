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
| New node every restart (`stirling-pdf-1`, `-2`…) | `stirling-ts-state` volume lost or `TS_STATE_DIR` unset | Restore volume; delete stale nodes in console |
| `stirling-pdf` restarts in a loop, logs stop after the "Binary Versions" block | The init script lacks a capability it needs | `docker inspect -f "{{.State.ExitCode}}" stirling-pdf` and `journalctl -u docker-stirling-pdf`; add only the capability the error names |
| Sidecar will not start after the baseline change | `--read-only` is untested for containerboot | Remove `--read-only` and the two `--tmpfs` lines from `stirling-ts` |
| App OOM-killed during large conversion | 2 GB cap | Raise `--memory` after checking bunyip's free RAM |

## Upgrade / rollback
Renovate PRs bump `image = "repo:tag@sha256:…"`. Merge → autodeploy (ADR-0004). Roll back by reverting the commit; the previous digest comes back with the previous generation.

Never `docker volume rm stirling-ts-state` casually: it re-registers the node under a new name.
