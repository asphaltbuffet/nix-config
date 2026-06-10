# pkgs

Custom package derivations not (yet) in nixpkgs.

| Package | Description |
| --- | --- |
| [`claude-code`](./claude-code) | Claude Code — Anthropic's AI coding assistant in your terminal |

## claude-code

A self-contained derivation that fetches Anthropic's prebuilt `claude` binary
from their CDN and wraps it with the runtime tools it expects on `PATH`
(`ripgrep`, `procps`, and on Linux `bubblewrap` + `socat`). The wrapper also
disables the auto-updater and installation checks so the Nix store copy stays
immutable.

Supported platforms: `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`,
`aarch64-darwin`.

> **Note:** the binary is unfree (`lib.licenses.unfree`). `nixpkgs.config.allowUnfree = true`
> must be set when consuming it — this flake already sets it globally.

### How it's wired in

An overlay in `flake.nix` shadows `pkgs.claude-code` with this local derivation:

```nix
(final: _prev: {
  claude-code = final.callPackage ./pkgs/claude-code {};
})
```

The home-manager module at `home/modules/claude/default.nix` continues to
reference `pkgs.claude-code` unchanged — the overlay makes the substitution
transparent.

### Use it by copying the folder

The derivation has no dependency on the rest of this repo, so you can drop
`pkgs/claude-code/` into any tree and call it directly:

```nix
home.packages = [ (pkgs.callPackage ./pkgs/claude-code { }) ];
```

`binName` can be overridden if you want the binary installed under a different
name: `pkgs.callPackage ./pkgs/claude-code { binName = "claude-code"; }`.

### Updating

```sh
nix run .#update-claude-code
```

Bumps to the latest version published on npm and refreshes the per-platform
`sha256` hashes by prefetching from Anthropic's CDN. Run from the repo root.
The updater is defined in `pkgs/claude-code/update.nix` and exposed as a flake
package output so it has all required tools (`curl`, `jq`, `nix`, `sd`) on
`PATH` and is shellcheck-validated at build time.
