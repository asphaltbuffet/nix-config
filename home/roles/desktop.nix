# home/roles/desktop.nix
# The `cli` shell foundation plus the desktop daily-driver applications.
# Baseline for a person's workstation login — not for a kiosk (see cli.nix).
# The `cli` half applies on every host; the desktop applications only on a
# Workstation (ADR-0026). `osConfig` is a home-manager specialArg, so it may
# be read while `imports` are resolved.
{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  inherit (osConfig.host) workstation;
in {
  imports =
    [./cli.nix]
    ++ lib.optionals workstation [
      ../modules/firefox
      ../modules/1password
      ../modules/kitty
      ../modules/micasa
      ../modules/mullvad
      ../modules/signal
      ../modules/vivaldi
    ];

  home.packages = lib.optionals workstation (with pkgs; [
    discord
    vlc
  ]);
}
