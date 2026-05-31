# Installer ISO embeds a read-only snapshot of the repo

The installer ISO includes a read-only copy of the flake at `/etc/nix-config` via `environment.etc."nix-config".source = self`. This means the current config is always available on the live ISO without a network connection — useful for inspecting module options, copy-pasting host templates, or running `nixos-bootstrap` in an air-gapped environment.

The snapshot is read-only (Nix store path). `nixos-bootstrap` still clones a writable copy from GitHub when network is available, using the snapshot only as a fallback reference. The cost is ISO size; the benefit is that the ISO is self-contained for the common case where the operator is consulting the config while partitioning.
