# home/roles/player.nix
# Gaming applications. Workstation-only (ADR-0026).
{
  pkgs,
  lib,
  osConfig,
  ...
}: {
  home.packages = lib.optionals osConfig.host.workstation (with pkgs; [
    mangohud # FPS/metrics overlay
    prismlauncher
  ]);
}
