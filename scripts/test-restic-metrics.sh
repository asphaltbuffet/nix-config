#!/usr/bin/env bash
# Fixture test for nixos/common/restic-backup/metrics.sh.
# Needs jq: nix shell "nixpkgs#jq" -c bash scripts/test-restic-metrics.sh
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
m() { bash -euo pipefail "$here/nixos/common/restic-backup/metrics.sh" "$@"; }
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
has() { grep -Fxq -- "$2" "$1" || { cat "$1" >&2; fail "missing line: $2"; }; }

# Real shape of `restic backup --json`'s summary line (trimmed).
echo '{"message_type":"summary","data_added":4476,"total_bytes_processed":123456,"snapshot_id":"abc"}' > "$dir/sum.json"

f="$dir/restic-wendigo-grue.prom"
m backup-ok "$dir" wendigo grue "$dir/sum.json"
has "$f" 'restic_backup_last_run_success{repo="wendigo",source="grue"} 1'
has "$f" 'restic_backup_restore_size_bytes{repo="wendigo",source="grue"} 123456'
has "$f" 'restic_backup_data_added_bytes{repo="wendigo",source="grue"} 4476'
ts=$(grep '^restic_backup_last_success_timestamp_seconds' "$f" | sed 's/.* //')
[ "$ts" -gt 1700000000 ] || fail "timestamp not set: $ts"

# A failed run keeps the last good values and flips only the success flag.
m backup-fail "$dir" wendigo grue
has "$f" 'restic_backup_last_run_success{repo="wendigo",source="grue"} 0'
has "$f" "restic_backup_last_success_timestamp_seconds{repo=\"wendigo\",source=\"grue\"} $ts"
has "$f" 'restic_backup_restore_size_bytes{repo="wendigo",source="grue"} 123456'

# A failure with no history reports "never" (0), not an error.
m backup-fail "$dir" wendigo sukey
has "$dir/restic-wendigo-sukey.prom" 'restic_backup_last_success_timestamp_seconds{repo="wendigo",source="sukey"} 0'

# Repo-level maintenance metrics.
r="$dir/restic-wendigo-repo.prom"
m repo-ok "$dir" wendigo 987654321
has "$r" 'restic_repo_raw_data_bytes{repo="wendigo"} 987654321'
has "$r" 'restic_repo_maintenance_last_run_success{repo="wendigo"} 1'
m repo-fail "$dir" wendigo
has "$r" 'restic_repo_maintenance_last_run_success{repo="wendigo"} 0'
has "$r" 'restic_repo_raw_data_bytes{repo="wendigo"} 987654321'

# No temp files left behind.
[ -z "$(find "$dir" -name '*.prom.*')" ] || fail "temp files leaked"
echo "PASS"
