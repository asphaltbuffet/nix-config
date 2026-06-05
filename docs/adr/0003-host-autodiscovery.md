# Hosts are auto-discovered from nixos/hosts/ directory names

The flake does not maintain an explicit list of hosts. Instead, `builtins.readDir` scans `nixos/hosts/` at evaluation time and builds a `nixosConfigurations` entry for every subdirectory found there. CI (`.github/workflows/build-hosts.yaml`) independently discovers the same list at runtime by reading the directory.

This means adding a host requires only creating `nixos/hosts/<name>/configuration.nix` and tracking it — no edits to `flake.nix` or CI config. The trade-off is that a partially-created host directory (e.g. created but not yet valid Nix) will cause `nix flake check` to fail for all hosts, not just the new one. The discoverability benefit outweighs this: it's impossible to add a host to the filesystem and forget to register it in the flake.
