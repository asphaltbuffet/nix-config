{
  curl,
  jq,
  nix,
  sd,
  writeShellApplication,
}:
writeShellApplication {
  name = "update-claude-code";
  runtimeInputs = [
    curl
    jq
    nix
    sd
  ];
  text = ''
    flake_root="''${1:-$PWD}"
    target="$flake_root/pkgs/claude-code/default.nix"

    if [ ! -f "$target" ]; then
      echo "error: cannot find $target — run from the flake root or pass the root as \$1" >&2
      exit 1
    fi

    NPM_URL="https://registry.npmjs.org/@anthropic-ai/claude-code/latest"
    BASE_URL="https://downloads.claude.ai/claude-code-releases"
    PLATFORMS=(darwin-arm64 darwin-x64 linux-x64 linux-arm64)

    latest=$(curl -sf --max-time 10 "$NPM_URL" | jq -r '.version')
    [ -n "$latest" ] || { echo "error: failed to fetch latest version from npm" >&2; exit 1; }

    # shellcheck disable=SC2016
    current=$(grep 'version = "' "$target" | head -1 | sd '.*version = "([^"]+)".*' '$1')
    [ -n "$current" ] || { echo "error: could not parse current version from $target" >&2; exit 1; }
    echo "current: $current"
    echo "latest:  $latest"
    [ "$current" = "$latest" ] && { echo "already up to date"; exit 0; }

    original=$(cat "$target")
    restore() { printf '%s' "$original" > "$target"; }

    sd -F "version = \"$current\"" "version = \"$latest\"" "$target"

    for p in "''${PLATFORMS[@]}"; do
      echo "prefetching $p..."
      hash=$(nix-prefetch-url "$BASE_URL/$latest/$p/claude" 2>/dev/null | tail -1)
      [ -n "$hash" ] || { echo "error: failed to fetch hash for $p" >&2; restore; exit 1; }
      sd "(\"$p\" = )\"[^\"]+\"" "\$1\"$hash\"" "$target"
    done

    echo "updated $current -> $latest"
  '';
}
