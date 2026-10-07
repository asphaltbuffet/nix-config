# Restic backups (SOP)

Home and data-disk backups to `/nas/public/backups/<repo>`. Decisions: ADR-0022. Terms: **Backup repository**, **Home backup**, **Data-disk backup**, **Restore size** in `CONTEXT.md`.

| Repo | Host | Source |
|---|---|---|
| `wendigo`, `kushtaka`, `snallygaster`, `bunyip` | same-named host | `/home/<user>` (one snapshot per user) |
| `bunyip-srv` | bunyip | `/srv` (excluding `lost+found`) |

Every host with a repo gets an admin wrapper `restic-<repo>` on PATH (repo, password file and cache dir preset). Use it with `sudo`; no `-r` / `--password-file` needed.

## Add a repository (one-time, per repo)
1. Generate the password: `nix shell "nixpkgs#openssl" -c openssl rand -base64 32` (or `head -c 32 /dev/urandom | base64 -w0`).
2. **Store it in 1Password first** (item `restic-<repo>`). Losing it loses the backups.
3. Add `secrets/restic-<repo>.age` to `secrets/agenix-rules.nix`, encrypted to **that host's key + admin key only**; `cd secrets && agenix -e restic-<repo>.age`; `just rekey`.
4. `jj file track` the new files; set the host's `services.resticBackup.home.enable` / `services.resticBackup.srv.enable`.
5. Deploy, then init by hand on the host: `sudo restic-<repo> init`. Never automated. Autodeploy rolls the change out to all hosts after merge, so bunyip alerts nightly until BOTH its repos (`bunyip`, `bunyip-srv`) are initialised: init them straight after deploying.
6. Trigger the first run: `sudo systemctl start restic-backup-<repo>`, then `journalctl -u restic-backup-<repo> -b` and `cat /var/lib/node-exporter-textfile/restic-<repo>-*.prom` (expect `last_run_success 1`), and check the dashboard. Until init, a laptop skips silently (an uninitialised repo looks like an unreachable NAS). Do the first run of `bunyip-srv` early in the week: a first full 1.5 TB run can outlast Sunday's prune lock wait (`--retry-lock 1h`).

Units per repo: `restic-backup-<repo>` (nightly) and `restic-prune-<repo>` (weekly forget/prune + check); each has a same-named timer.

## Restore drill (do once per repo, then yearly)
`sudo restic-<repo> snapshots`, then `sudo restic-<repo> restore <id> --target /tmp/restore-test --include <path>` and diff against the source.

## Symptoms
| Symptom | Cause | Fix |
|---|---|---|
| Laptop never backs up, no alert | Reachability probe (`test -f <repo>/config`, 15 s, retried up to 6 times 20 s apart on non-Always-on hosts) kept failing: NAS unreachable, or repo never initialised (skip by design, exit 0) | Be on the home network; `ls /nas/public/backups/<repo>/config`; `sudo restic-<repo> init` if new |
| bunyip alert: backup failed, NAS or `/srv` | Probe failed (single attempt, exit 1 on Always-on hosts: NAS down or repo missing) or `/srv` not mounted (`nofail`, `RequiresMountsFor`) | `findmnt /srv /nas/public`; `journalctl -u restic-backup-<repo>`; check disk health in smartd alerts |
| `wrong password or no key found` | Secret empty/rekeyed wrong, or wrong repo path | `/run/agenix/restic-<repo>` must be non-empty (see deploy-stale-cache-sop.md); compare with the 1Password copy |
| `unable to create lock` / repo locked | Interrupted job left a lock | `sudo restic-<repo> unlock` (only stale locks); never while a job runs |
| Backup includes `~/nas` or is huge | Exclude list or `--one-file-system` regressed | Check the flags in `nixos/common/restic-backup.nix` (`homeArgs`) and `nixos/common/restic-backup/excludes.txt` |
| Alert from `restic-prune-<repo>` (check failure sends two: priority 4 + generic) | Repo corruption or NAS bit-rot | `sudo restic-<repo> check --read-data` full run; `sudo restic-<repo> repair index`; restore a test file with `sudo restic-<repo> restore` |
| Dashboard shows "last backup" stale on a laptop | Skipped while off-network (after retries), or timer not firing | `systemctl list-timers 'restic-*'`; expected if away from home |
