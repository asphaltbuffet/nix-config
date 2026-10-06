# home/roles/desktop.nix
# The `cli` shell foundation plus the desktop daily-driver applications.
# Baseline for a person's workstation login — not for a kiosk (see cli.nix).
{pkgs, ...}: {
  imports = [
    ./cli.nix

    # GUI stuff
    ../modules/firefox
    ../modules/1password
    ../modules/kitty
    ../modules/micasa
    ../modules/mullvad
    ../modules/signal
    ../modules/vivaldi
  ];

  home.packages = with pkgs; [
    # GUI stuff
    discord
    vlc
  ];
}
