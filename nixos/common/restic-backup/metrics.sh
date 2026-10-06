# restic-metrics: write restic_* series for node_exporter's textfile collector.
# See ADR-0022. Usage: restic-metrics <cmd> <textfile-dir> <repo> [args...]

usage() {
  echo "usage: restic-metrics backup-ok <dir> <repo> <source> <summary.json>" >&2
  echo "       restic-metrics backup-fail <dir> <repo> <source>" >&2
  echo "       restic-metrics repo-ok <dir> <repo> <raw-data-bytes>" >&2
  echo "       restic-metrics repo-fail <dir> <repo>" >&2
  exit 2
}

write_atomic() { # <file>; content on stdin
  local out=$1 tmp
  tmp=$(mktemp "$out.XXXXXX")
  cat > "$tmp"
  chmod 0644 "$tmp"
  mv "$tmp" "$out"
}

# prev <file> <metric> <default>: value of an existing series, else default.
prev() {
  local line
  line=$(grep -E "^$2\{" "$1" 2> /dev/null | head -n1 || true)
  if [ -n "$line" ]; then echo "${line##* }"; else echo "$3"; fi
}

emit_backup() { # repo source ok ts size added
  cat << EOF
# HELP restic_backup_last_run_success 1 if the last backup run for this source succeeded.
# TYPE restic_backup_last_run_success gauge
restic_backup_last_run_success{repo="$1",source="$2"} $3
# HELP restic_backup_last_success_timestamp_seconds When this source last backed up successfully (0 = never).
# TYPE restic_backup_last_success_timestamp_seconds gauge
restic_backup_last_success_timestamp_seconds{repo="$1",source="$2"} $4
# HELP restic_backup_restore_size_bytes Logical size of the latest snapshot (what a restore would produce).
# TYPE restic_backup_restore_size_bytes gauge
restic_backup_restore_size_bytes{repo="$1",source="$2"} $5
# HELP restic_backup_data_added_bytes New data the latest snapshot added to the repository.
# TYPE restic_backup_data_added_bytes gauge
restic_backup_data_added_bytes{repo="$1",source="$2"} $6
EOF
}

emit_repo() { # repo ok ts raw
  cat << EOF
# HELP restic_repo_maintenance_last_run_success 1 if the last weekly prune+check succeeded.
# TYPE restic_repo_maintenance_last_run_success gauge
restic_repo_maintenance_last_run_success{repo="$1"} $2
# HELP restic_repo_maintenance_last_success_timestamp_seconds When prune+check last succeeded (0 = never).
# TYPE restic_repo_maintenance_last_success_timestamp_seconds gauge
restic_repo_maintenance_last_success_timestamp_seconds{repo="$1"} $3
# HELP restic_repo_raw_data_bytes Physical (deduplicated, compressed) size of the repository.
# TYPE restic_repo_raw_data_bytes gauge
restic_repo_raw_data_bytes{repo="$1"} $4
EOF
}

[ $# -ge 3 ] || usage
cmd=$1 dir=$2 repo=$3
shift 3

case "$cmd" in
  backup-ok)
    [ $# -eq 2 ] || usage
    source=$1 summary=$2
    size=$(jq -er '.total_bytes_processed' "$summary") || {
      echo "restic-metrics: summary lacks total_bytes_processed" >&2
      exit 1
    }
    added=$(jq -er '.data_added' "$summary") || {
      echo "restic-metrics: summary lacks data_added" >&2
      exit 1
    }
    emit_backup "$repo" "$source" 1 "$(date +%s)" "$size" "$added" |
      write_atomic "$dir/restic-$repo-$source.prom"
    ;;
  backup-fail)
    [ $# -eq 1 ] || usage
    source=$1 file="$dir/restic-$repo-$1.prom"
    ts=$(prev "$file" restic_backup_last_success_timestamp_seconds 0)
    size=$(prev "$file" restic_backup_restore_size_bytes 0)
    added=$(prev "$file" restic_backup_data_added_bytes 0)
    emit_backup "$repo" "$source" 0 "$ts" "$size" "$added" | write_atomic "$file"
    ;;
  repo-ok)
    [ $# -eq 1 ] || usage
    emit_repo "$repo" 1 "$(date +%s)" "$1" | write_atomic "$dir/restic-$repo-repo.prom"
    ;;
  repo-fail)
    file="$dir/restic-$repo-repo.prom"
    ts=$(prev "$file" restic_repo_maintenance_last_success_timestamp_seconds 0)
    raw=$(prev "$file" restic_repo_raw_data_bytes 0)
    emit_repo "$repo" 0 "$ts" "$raw" | write_atomic "$file"
    ;;
  *) usage ;;
esac
