# home/roles/base.nix
# The `cli` shell foundation plus the desktop daily-driver applications.
# Baseline for a person's workstation login — not for a kiosk (see cli.nix).
{pkgs, ...}: {
  imports = [
    ./cli.nix

    # GUI stuff
    ../modules/firefox
    ../modules/1password
    ../modules/kitty
    ../modules/mullvad
    ../modules/signal
  ];

  home.packages = with pkgs; [
    # GUI stuff
    discord
    vlc
  ];
}
