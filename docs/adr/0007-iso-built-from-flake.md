# Installer ISO is built from the flake itself

The NixOS installer ISO is a flake output (`nixosConfigurations.iso`) defined in `flake.nix`, not a separate repo, Packer template, or pre-built NixOS minimal ISO. `nixos/installer/configuration.nix` and `nixos/profiles/installer.nix` define its contents; `just iso` builds it.

Building the ISO from the same flake as the host configs means the bootstrap tooling (`nixos-bootstrap`, the embedded repo snapshot, the package set) is always in sync with the rest of the config — no separate release process or version pinning. The trade-off is that a broken flake (e.g. a bad host config triggering evaluation failure via auto-discovery) also breaks the ISO build. In practice this is acceptable because CI catches eval failures before merge.
