# nixos-bootstrap uses pkgs.writeShellApplication for shellcheck and sealed PATH

The bootstrap script is wrapped with `pkgs.writeShellApplication` in `nixos/installer/configuration.nix` rather than being a plain shell script added to `environment.systemPackages`. This wrapper runs shellcheck at build time (a shellcheck failure is a Nix build failure), injects `set -euo pipefail` automatically, and provides `runtimeInputs` as a sealed `PATH` — the script can only call tools explicitly listed there, with no reliance on ambient PATH entries from the live ISO environment.

The sealed PATH is particularly valuable here: the ISO's PATH is determined by `nixos-install-tools` and may vary across NixOS versions. Listing tools in `runtimeInputs` makes the script's dependencies explicit and reproducible. shellcheck at build time catches issues before the ISO is flashed to USB, where iterating on script bugs is expensive.
