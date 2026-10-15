# Tailnet services share one sidecar module; wherefolk leaves compose and its Directory moves to /srv

Every Tailnet service declares its Tailscale sidecar through one option module, `tailnetServices.<key>`, instead of hand-writing it. The duplication was already causing hazards: stirling-pdf and micasa carried near-identical sidecar containers with uids chosen by hand, the same image pin written out twice, and no failure Alerts. wherefolk is migrated off its upstream compose file to `oci-containers` so that it uses the same module. This is the "next touched" point ADR-0020 deferred to.

## Decisions

- **Option module, not a helper function.** Only a module can see every service at once. That lets it assert that uids, tags and device names are unique, and it registers `host.tailnetSidecars` itself.
- **The key is the identity.** The attribute key fixes the sidecar container name (`<key>-ts`), its state dir (`/var/lib/<key>-ts`) and its tag (`tag:<key>`). `hostname` (the tailnet device name) defaults to the key and may be overridden, as stirling-pdf does. Renaming a device must never move a state dir, because an empty state dir means a new node.
- **uids are explicit and asserted unique.** If uids were derived from service order or a hash, adding a service could change the owner of an existing state dir.
- **The module joins apps; it does not harden them.** It adds `--network=container:<key>-ts`, `dependsOn` and `onFailure` to the app containers a service names. Image, user, capabilities and limits stay in the service's own module, so ADR-0020's rule that each baseline exception is justified next to its container still holds.
- **One sidecar image string**, kept in the literal `image = "repo:tag@sha256:…";` form that Renovate's regex manager matches.
- **wherefolk on `oci-containers`.** Its image is digest-pinned and bumped by Renovate. `WHEREFOLK_VERSION` and the `wherefolk` flake input are removed. The secret is split into `wherefolk-ts-env` and `wherefolk-app-env`, because `environmentFiles` would otherwise give the sidecar the Full-tier passphrase, which upstream requires the sidecar never sees.
- **wherefolk's Directory moves to `/srv/wherefolk`**, a bind mount owned by uid 65532. It was in the named volume `wherefolk-data` under `/var/lib/docker`, which no Backup repository covered. On `/srv` the Data-disk backup picks it up with no further configuration.
- **The sidecar node is carried over, not re-registered.** At cutover, the contents of `wherefolk-tailscale-state` are copied into `/var/lib/wherefolk-ts` and given the sidecar's uid. Re-registering would mint a second node (`wherefolk-1`) while the old device still holds the name, and the Editor's bookmark would break.

## Consequences

- bunyip has a single container idiom. This supersedes ADR-0020's first consequence.
- wherefolk's version is now bumped through a Renovate PR in this repo, not through a flake-lock update. Upstream's warning that an older binary refuses a document written by a newer schema still applies to rollbacks.
- The cutover is a one-time manual procedure (stop the old unit, copy both volumes, switch). It lives in `docs/references/wherefolk-sop.md`. The old named volumes are kept until the new stack has been verified, and `docker compose down -v` is never run.
