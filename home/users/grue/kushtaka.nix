# .../home/users/grue/kushtaka.nix
{ lib, pkgs, ... }:
{

  imports = [
    ../../common
  ];

  targets.genericLinux.enable = true;
  systemd.user.startServices = "sd-switch";

  home = {
    username = lib.mkDefault "grue";
    homeDirectory = lib.mkDefault "/home/grue";
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
      vlc
      viddy # better watch
      xh # better curl

      _1password-gui
      discord
      flameshot
      kitty
      signal-desktop
    ];
  };

  xdg.enable = true;

  fonts.fontconfig.enable = true;

  programs.home-manager.enable = true;
  programs.firefox.enable = true;

}
