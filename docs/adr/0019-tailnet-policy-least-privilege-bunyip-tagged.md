# Tailnet policy is least-privilege; bunyip is `tag:server`

The tailnet moves from the default allow-all (`*` → `*:*`) to an explicit default-deny policy, kept in `tailscale/policy.hujson` and pasted into the admin console by hand. The console is authoritative; the file is the reviewed copy. Emails in it are placeholders because the repo is public.

NixOS trusts `tailscale0` in the host firewall (`nixos/common/tailscale.nix`), so the policy is the only access control on tailnet traffic. Under allow-all, wherefolk's 443-only grant would have been decorative: every device could reach every port, including the app's 8080, which bypasses Serve's TLS.

## Decisions

- **bunyip is tagged `tag:server`.** Rules cannot otherwise tell it from the operator's laptops, so "only bunyip may scrape the fleet" is inexpressible. The cost: a tagged device is no longer user-owned, so `autogroup:self` stops covering it (the policy adds explicit SSH and grant rules for `group:operator` → `tag:server`), and a one-time retag in the console. Its key no longer expires, which suits an always-on host.
- **`grants`, not `acls`.** Current syntax, greenfield policy, no migration cost.
- **Flows are enumerated:** operator → own devices (all); operator → bunyip (22, 3000); bunyip → operator devices (9100, 9633, Prometheus scrapes only); operator → `192.168.86.0/24` via bunyip's subnet router, route auto-approved for `tag:server`; wherefolk users → `tag:wherefolk` (443 only). No rule gives the sidecar outbound access.
- **The Editor joins as a member of the tailnet**, not by node sharing. Sharing would put access under the Editor's own tailnet policy, which this policy cannot scope or test.
- **Device approval on, Tailnet Lock off.** The wherefolk node uses `preauthorized=true` and skips approval by design. Lock would need a signing node and risks locking the operator out of re-adding devices; not worth it for a one-person fleet.

## Considered Options

- **Minimal patch (keep allow-all, add the wherefolk grant)** — rejected. The grant would do nothing.
- **Leave bunyip untagged and use a `hosts` alias with its IP** — rejected. Hardcoded IP in the policy, and bunyip keeps a 180-day key expiry.
- **Tailscale GitOps Action** — rejected for now. It puts a policy-write credential in CI, so anyone who can merge to `main` can rewrite network access. It can be added later without changing the file.
- **Policy only in the console** — rejected. No history or review.

## Consequences

- Any new flow between hosts needs a grant before it works. A "connection times out" after adding a service is a policy question first.
- The repo copy and live policy can drift; the console's `tests` guard the live one, nothing checks the repo copy.
