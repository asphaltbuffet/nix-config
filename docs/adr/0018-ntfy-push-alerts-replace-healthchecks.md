# ntfy.sh push alerts replace healthchecks.io; the topic is public

Fleet monitoring moves from healthchecks.io to **push-on-error Alerts** on a single public ntfy.sh topic. healthchecks.io is a dead-man's switch: auto-deploy sent `/start` and exit-status pings, and a check went down when no ping arrived in time. Laptops and desktops that sleep for days tripped those timeouts constantly, burying real failures in noise. smartd had already worked around this by sending `/fail` only and never a heartbeat, at the cost of manually pausing checks in the UI to "clear" them. With ntfy, a host sends an Alert when it detects a problem and nothing otherwise — there is no check state to time out or clear.

A shared `alert` CLI and an `alert@.service` template live in `nixos/common/alerts.nix`; any systemd unit opts in with `onFailure = ["alert@%n.service"]`. One fleet-wide topic; titles are `<host>: <source>`, tags carry source and host, and severity rides on priority (smartd 4, auto-deploy 3) so a failing disk can break through Do Not Disturb and a failed deploy can't.

## The topic is in plaintext, and that is deliberate

On public ntfy.sh the topic name *is* the credential — anyone who knows it can subscribe and can publish. It sits in plaintext in this public repo anyway. This is not critical infrastructure; the worst case is spoofed or snooped alerts, which is annoying, not harmful. If that happens, the topic moves into agenix (it is one Nix binding, so that is a one-module change plus a rekey). Do not "fix" this by encrypting it pre-emptively.

Because the topic is world-readable, **Alerts never carry log content or other free-form text.** There is no way to guarantee a journal excerpt is free of secrets, so the logs stay on the host and the alert says where to find them. The body is structured `key: value` lines whose values are closed-set values, opaque IDs, or commands: `alert@.service` sends systemd's `MONITOR_SERVICE_RESULT`/`MONITOR_EXIT_STATUS` and a `journalctl --invocation=<id>` command for exactly the failed run; smartd sends a `smartctl -a <device>` command; every alert ends with a `config:` line (short `/run/current-system` store hash + nixos version, read at send time — not `self.rev`, which would make every commit a new generation on every host). smartd's title adds only fields drawn from closed value sets — device path and `SMARTD_FAILTYPE` — and omits `SMARTD_DEVICEINFO` (serial numbers) and the free-form `SMARTD_MESSAGE`.

## Consequences

- **Silent failures are no longer detected.** A disabled timer, a wedged host, or CI that stopped publishing produces no Alert. For laptops and desktops this is permanent and intended — their silence is normal. **Always-on hosts** (bunyip, arcade) get Liveness checks later via Prometheus/Alertmanager; until then, "bunyip stopped auto-deploying" is a known, accepted gap.
- Removing `hcPingKey` does not take any host out of agenix — `grafanaKey` and the `grue/*` secrets are still encrypted to all hosts. The secret reduction is incidental; the driver is ending timeout noise and having one reusable failure hook.
- Alertmanager, when added, posts to the same topic with the same title convention.

## Considered Options

- **Public ntfy.sh, plaintext topic** — chosen. Zero infrastructure, works from any network a laptop is on.
- **Self-hosted ntfy on bunyip over tailscale** — rejected for now. Network-scoped access would make a plaintext topic genuinely safe, but bunyip becomes a single point of failure for alerting and laptops off-tailnet can't send.
- **ntfy.sh with an unguessable topic or access token** — rejected. The topic or token is a secret again, which removes one of the reasons to switch.
- **Keep healthchecks.io for always-on hosts only** — rejected. Two alerting systems for a five-host fleet; Alertmanager will cover always-on liveness.
- **Journal excerpts in alert bodies** — rejected. Makes alerts actionable from a phone, but publishes arbitrary logs to a public topic.
