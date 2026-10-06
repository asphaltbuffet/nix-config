#!/usr/bin/env bash
# Verifies nixos/common/restic-backup/excludes.txt against a fixture tree.
# Needs restic + jq: nix shell "nixpkgs#restic" "nixpkgs#jq" -c bash scripts/test-restic-excludes.sh
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

mkdir -p "$root"/home/alice/{nas,Downloads,.cache,keep,.local/share/Trash,.local/share/Steam,.local/share/containers,.docker,dev/proj/node_modules,dev/proj/target,dev/proj/src,dev/deep/a/b/target}
for f in nas/a Downloads/b .cache/c keep/d .local/share/Trash/t .local/share/Steam/s \
  .local/share/containers/c .docker/d dev/proj/node_modules/e dev/proj/target/f \
  dev/proj/src/g dev/deep/a/b/target/h dev/proj/result; do
  echo x > "$root/home/alice/$f"
done

# Patterns are absolute (/home/*/...); re-root them onto the fixture.
sed "s|^/home|$root/home|" "$here/nixos/common/restic-backup/excludes.txt" > "$root/ex.txt"

export RESTIC_PASSWORD=test RESTIC_REPOSITORY="$root/repo"
restic init -q
got=$(restic backup --dry-run --json -v --one-file-system --exclude-caches \
  --exclude-file "$root/ex.txt" "$root/home" |
  jq -r 'select(.message_type=="verbose_status" and .action=="new" and (.item|test("/(a|b|c|d|e|f|g|h|s|t|result)$"))) | .item' |
  sed "s|^$root||" | sort)
want=$'/home/alice/dev/proj/src/g\n/home/alice/keep/d'

if [ "$got" != "$want" ]; then
  echo "FAIL: unexpected backed-up files" >&2
  echo "want:" >&2; echo "$want" >&2
  echo "got:" >&2; echo "$got" >&2
  exit 1
fi
echo "PASS"
