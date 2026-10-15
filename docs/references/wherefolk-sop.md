# wherefolk SOP

wherefolk is a Tailnet service on bunyip (ADR-0024): `wherefolk-ts` sidecar
(uid 61003, state `/var/lib/wherefolk-ts`) + `wherefolk` app (uid 65532,
Directory at `/srv/wherefolk`, covered by the Data-disk backup).

## Bumping the version

Renovate opens a PR against the `image =` line in `nixos/common/wherefolk.nix`.
An older binary refuses a document written by a newer schema, so roll back by
restoring the Directory from a snapshot, not by reverting the pin alone.

## One-time cutover from compose (2026-10)

Run on bunyip as root, in order. Never `docker compose down -v`.

0. Pause auto-deploy so the published (old) closure cannot switch back mid-cutover
   and restart compose on the old volumes: `systemctl stop nixos-autodeploy.timer`
1. Stop the old stack: `systemctl stop wherefolk.service`
   (its ExecStop is `compose stop`; containers and volumes stay).
2. Copy the sidecar's node state:
       install -d -m 0700 -o 61003 -g 61003 /var/lib/wherefolk-ts
       cp -a /var/lib/docker/volumes/wherefolk-tailscale-state/_data/. /var/lib/wherefolk-ts/
       chown -R 61003:61003 /var/lib/wherefolk-ts
3. Pre-flight — must print a file, or STOP (a new node would register as wherefolk-1):
       ls -l /var/lib/wherefolk-ts/tailscaled.state
4. Copy the Directory:
       install -d -m 0700 -o 65532 -g 65532 /srv/wherefolk
       cp -a /var/lib/docker/volumes/wherefolk-data/_data/. /srv/wherefolk/
       chown -R 65532:65532 /srv/wherefolk
       stat -c '%U:%G %a %n' /srv/wherefolk/directory.json   # expect 65532:65532 600
5. Activate the new generation in test mode (from wendigo):
       nh os test -H bunyip --target-host bunyip .   # prints /nix/store/…-nixos-system-bunyip-…, then fails on sudo TTY
       ssh bunyip "sudo -n <that path>/bin/switch-to-configuration test"
   After verification, merge to main and let CI publish; once the published closure
   is this one, `systemctl start nixos-autodeploy.timer` (its next run switches).
   Until that switch the boot default is still the compose generation: a reboot
   (including a UPS low-battery shutdown) brings the old stack back on the old
   volumes. If bunyip reboots mid-cutover, run `systemctl stop wherefolk.service`
   at once and repeat step 5; `/srv/wherefolk` stays the authoritative copy.
6. Verify (see below). On failure, before switching: return to the boot default
   (test mode never changed it) and restart the old stack on its untouched volumes:
       sudo /nix/var/nix/profiles/system/bin/switch-to-configuration test
       systemctl start wherefolk.service
   Edits made on the new stack since step 5 exist only in `/srv/wherefolk`.
7. After a week of normal use: `docker rm wherefolk-wherefolk-1 wherefolk-tailscale-1`,
   then `docker volume rm wherefolk-data wherefolk-tailscale-state`.

## Verify

- `tailscale status | rg wherefolk` shows one `wherefolk` device, no `wherefolk-1`.
- The Editor's bookmark loads over HTTPS.
- A Full-tier export succeeds (exercises Typst under `--read-only`).
- `docker inspect wherefolk-ts --format '{{json .Config.Env}}' | rg -c WHEREFOLK || echo 0` prints 0.
- `systemctl start restic-backup-bunyip-srv` then the latest srv snapshot lists `/srv/wherefolk/directory.json`.
