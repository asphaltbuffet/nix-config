# Restic backs up to encrypted per-host repositories on the public NAS share

Home directories and bunyip's data disk are backed up with restic, as root-run systemd timers, into **Backup repositories** under `/nas/public/backups/` on the NAS (the mount `nas.nix` already provides on every host). The directory is world-readable by design: restic encrypts client-side, so the per-repo password is the only access control.

## Decisions

- **Location: `/nas/public/backups/<repo>`, no new share.** A dedicated `backups` share and per-user shares were both considered (below). Root writes to `/nas/public` were verified to work (a root-created file arrives as uid 0, so the export does not root-squash); no NAS-side setup is needed.
- **Root-run, one repository per host.** Root can read every home, so a host needs one job. Repositories: `wendigo`, `kushtaka`, `snallygaster`, `bunyip` (homes) and `bunyip-srv` (the old 1.5 TB `/srv` disk, no excludes, separate so a dying disk and home churn never share a repo or a prune). Arcade is not backed up (rebuildable kiosk). Enabled per host via `services.resticBackup.home.enable` / `services.resticBackup.srv.enable`.
- **One snapshot per user** (`/home/<user>`, tagged) inside the host repo, run sequentially in one unit. This is what makes per-user figures possible.
- **One password per repository**, an agenix secret encrypted to that host's key plus the admin key only, so a compromised host cannot decrypt another's repo despite all of them being readable. A recovery copy goes in 1Password at creation; losing agenix keys must not mean losing the backups. `restic init` is manual (documented in the SOP), never automatic, so a bad path cannot mint a stray empty repo.
- **Schedule:** daily ~02:00, `RandomizedDelaySec=2h`, `Persistent=true`. Retention `--keep-daily 7 --keep-weekly 4 --keep-monthly 6` everywhere. A separate weekly unit per repo runs `forget --prune` and `check --read-data-subset=5%`, so a prune failure does not mark the backup failed. Safety against overlap comes from restic's repository lock plus `--retry-lock 1h`, not from scheduling: a backup may run until ~04:00 plus its random delay while prune starts at 04:00 plus its own delay.
- **Excludes (homes):** `~/nas` (mandatory: never back the NAS up onto itself), `~/Downloads`, `.cache`, trash, Steam, container image stores, `node_modules`, `target`, `result` (only under `~/dev/**`; any file or directory with those names there is dropped even if it is not a build output), `--exclude-caches`, `--exclude-if-present .nobackup`, `--one-file-system`. `/srv` excludes only `lost+found`.
- **Failure policy follows ADR-0018.** A backup or prune/check that runs and fails alerts via `alert@%n.service` (check at higher priority: a corrupt repo is worse than a missed night). On laptops/desktops an unreachable NAS is a skip, not a failure, and there is no staleness alert. The probe is retried (up to 6 attempts, 20 s apart) on those hosts before skipping, because a laptop waking at 02:00 races Wi-Fi. Both are decided by a reachability probe at the start of each unit (`timeout 15 test -f <repo>/config`, which triggers the automount) that exits 0 (after retries) on laptops/desktops and 1 (single attempt) on Always-on hosts. `ConditionPathIsMountPoint` cannot be used because an `x-systemd.automount` mount point exists even when the NAS is down. On bunyip, an unreachable NAS or unmounted `/srv` *is* a failure (the probe, plus `RequiresMountsFor=/srv`), so `/srv`'s `nofail` mount cannot yield a snapshot of an empty directory. A backup that never ran at all is left to the planned Alertmanager **Liveness check**.
- **Metrics, not alerts, for freshness.** Each job writes `restic_*` series to node_exporter's textfile directory (the `nixos-metrics.nix` pattern): last-success timestamp and exit status per host/user, **Restore size** per user (from `restic backup --json`'s `total_bytes_processed`), and physical repository size per host (`restic stats --mode raw-data`, computed only in the weekly unit). A new `dashboards/backups.json` shows these. Physical bytes are deliberately not attributed to users; deduplication makes that meaningless.

## Consequences

- Any host holding the NAS mount can delete any repository on it (restic has no append-only mode over a filesystem), and anyone on the LAN can read the ciphertext. Accepted; the threat model is hardware failure, not a hostile LAN.
- Password loss is unrecoverable data loss. The 1Password copy is not optional.
- Backups share the NAS with the data they protect from host failure only; they do not protect against NAS failure. An offsite copy (e.g. Backblaze B2, per `TODO.md`) is a separate future decision.
- A repo that was never `restic init`ed looks identical to an unreachable NAS on a laptop and is skipped silently; the SOP's first-run step and the dashboard's "never" series are the guard.
- A failed `restic check` sends two alerts (priority 4 plus the generic unit-failure one). Accepted.
- When `RequiresMountsFor=/srv` fails as a dependency failure, `OnFailure=` still fires (systemd runs on-failure for jobs ending with result `dependency`), but the alert reads `result=unknown`, the unit is not listed by `systemctl --failed`, and no `backup-fail` metric is written, so the dashboard's "Sources failing" does not reflect it. Accepted.
- Static files only on `/srv` for now. Live-written state (databases, container volumes) moved there later needs a pre-backup dump hook added to the data-disk backup.

## Considered Options

- **Dedicated `/Volume1/backups` share (mounted `/nas/backups`)** — rejected: needs NAS-side setup and a new mount for no gain over a subdirectory of an already-mounted share, given encryption.
- **Per-user jobs into each `~/nas`** — rejected: three jobs per host, bunyip's `/srv` has no natural home, and backups would live where users can delete them.
- **Per-user jobs into the shared directory** — rejected: needs a shared group or world-writable directory, letting any user delete any other's repo.
- **One shared password for all repos** — rejected: one compromised host would unlock every backup.
- **Staleness alerts for laptops** — rejected per ADR-0018: sleeping hosts' silence is normal; freshness is a Grafana metric instead.
