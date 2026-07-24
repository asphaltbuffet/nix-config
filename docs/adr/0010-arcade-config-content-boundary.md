# Arcade cabinet: config is in the flake, ROMs are out-of-band content

The arcade role manages attract-mode's emulator definitions and the X session declaratively, so a freshly imaged cabinet boots fully wired to launch RetroArch and MAME. The ROMs themselves are **not** in the repo or the Nix store — they are mutable content placed on the cabinet at a documented path (e.g. `/home/arcade/roms/<system>/`) out of band (scp/tailscale) and merely referenced by attract-mode config.

This keeps the flake reproducible and free of copyrighted, multi-gigabyte game files that would otherwise be copied into the Nix store and jj history. The consequence a future reader should expect: the config alone produces a correct-but-empty cabinet — an empty game list until ROM files are dropped in. This mirrors the rest of the fleet, where config defines the machine and data lives outside it.

## Consequences

- attract-mode rewrites its own top-level `attract.cfg` at runtime, so that file must not be a read-only Nix-store symlink. Manage the static emulator-definition files declaratively; seed or leave writable the mutable `attract.cfg`.
