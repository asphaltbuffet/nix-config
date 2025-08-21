# .../home/users/jsquats/kushtaka.nix
{ lib, pkgs, ... }: {

  imports = [
    ../../common
  ];

  targets.genericLinux.enable = true;
  systemd.user.startServices = "sd-switch";

  home = {
    username = "jsquats";
    homeDirectory = "/home/jsquats";
    stateVersion = "25.05";
    shell.enableZshIntegration = true;

    packages = with pkgs; [
      _1password-cli
      bat        # better cat
      delta      # better git-diff
      fd         # better find
      just
      lnav
      moreutils
      ncdu
      ripgrep
      tmux
      tmux-xpanes
      trippy     # tui network tool
      viddy      # better watch
      xh         # better curl

      _1password-gui
      discord
      kitty
      obsidian
      prismlauncher
      signal-desktop
    ];
  };

  xdg.enable = true;

  fonts.fontconfig.enable = true;

  programs.home-manager.enable = true;
  programs.firefox.enable = true;
}
