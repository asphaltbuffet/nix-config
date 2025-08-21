# .../home/users/sukey/kushtaka.nix
{ lib, pkgs, ... }: {

  imports = [
    ../../common
  ];

  targets.genericLinux.enable = true;
  systemd.user.startServices = "sd-switch";

  home = {
    username = "sukey";
    homeDirectory = "/home/sukey";
    stateVersion = "25.05";
    shell.enableZshIntegration = true;

    packages = with pkgs; [
      _1password-cli
      bat        # better cat
      fd         # better find
      just
      lnav
      moreutils
      ncdu
      ripgrep
      trippy     # tui network tool
      viddy      # better watch
      xh         # better curl

      _1password-gui
      discord
      kitty
      prismlauncher
      signal-desktop
    ];
  };

  xdg.enable = true;

  fonts.fontconfig.enable = true;

  programs.home-manager.enable = true;
  programs.firefox.enable = true;
}
