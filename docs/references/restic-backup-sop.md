# Restic backups (SOP)

Home and data-disk backups to `/nas/public/backups/<repo>`. Decisions: ADR-0022. Terms: **Backup repository**, **Home backup**, **Data-disk backup**, **Restore size** in `CONTEXT.md`.

| Repo | Host | Source |
|---|---|---|
| `wendigo`, `kushtaka`, `snallygaster`, `bunyip` | same-named host | `/home/<user>` (one snapshot per user) |
| `bunyip-srv` | bunyip | `/srv` (excluding `lost+found`) |

## Add a repository (one-time, per repo)
1. Generate the password: `openssl rand -base64 32`.
2. **Store it in 1Password first** (item `restic-<repo>`). Losing it loses the backups.
3. Add `secrets/restic-<repo>.age` to `secrets/secrets.nix`, encrypted to **that host's key + admin key only**; `cd secrets && agenix -e restic-<repo>.age`; `just rekey`.
4. `jj file track` the new files; set the host's `services.restic-home.enable` / `services.restic-srv.enable`.
5. Deploy, then init by hand on the host: `sudo restic -r /nas/public/backups/<repo> --password-file /run/agenix/restic-<repo> init`. Never automated.
6. Trigger the first run: `sudo systemctl start restic-backups-<repo>` and check the dashboard.

## Restore drill (do once per repo, then yearly)
`sudo restic -r /nas/public/backups/<repo> --password-file /run/agenix/restic-<repo> snapshots`, then `restore <id> --target /tmp/restore-test --include <path>` and diff against the source.

## Symptoms
| Symptom | Cause | Fix |
|---|---|---|
| Laptop never backs up, no alert | NAS unreachable (skip by design) | Be on the home network; `findmnt /nas/public` |
| bunyip alert: backup failed, NAS or `/srv` | NAS down or `/srv` not mounted (`nofail`) | `findmnt /srv /nas/public`; check disk health in smartd alerts |
| `wrong password or no key found` | Secret empty/rekeyed wrong, or wrong repo path | `/run/agenix/restic-<repo>` must be non-empty (see deploy-stale-cache-sop.md); compare with the 1Password copy |
| `unable to create lock` / repo locked | Interrupted job left a lock | `restic unlock` (only stale locks); never while a job runs |
| Backup includes `~/nas` or is huge | Exclude list or `--one-file-system` regressed | Check the unit's `ExecStart` flags |
| Alert from the weekly check unit | Repo corruption or NAS bit-rot | `restic check --read-data` full run; `restic repair index`; restore a test file |
| Dashboard shows "last backup" stale on a laptop | Skipped while off-network, or timer not firing | `systemctl list-timers 'restic-*'`; expected if away from home |
