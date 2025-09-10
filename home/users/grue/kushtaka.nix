# .../home/users/grue/kushtaka.nix
{ lib, pkgs, ... }:
{

  imports = [
    ../../common
  ];

  targets.genericLinux.enable = true;
  systemd.user.startServices = "sd-switch";

  home = {
    username = "grue";
    homeDirectory = "/home/grue";
    stateVersion = "25.05";
    shell.enableZshIntegration = true;

    packages = with pkgs; [
      _1password-cli
      bat # better cat
      bottom # better top
      delta # better git-diff
      doggo # dig
      duf # better df
      dust # du + rust
      fd # better find
      git-absorb
      glow # markdown viewer
      gum # fancy cli snippets
      ijq # interactive jq
      jq
      just
      lnav
      moreutils
      ncdu
      ripgrep
      tmux
      tmux-xpanes
      trippy # tui network tool
      viddy # better watch
      xh # better curl

      _1password-gui
      discord
      flameshot
      kitty
      prismlauncher
      signal-desktop
      vlc
    ];
  };

  xdg.enable = true;

  fonts.fontconfig.enable = true;

  programs.home-manager.enable = true;
  programs.firefox.enable = true;

}
