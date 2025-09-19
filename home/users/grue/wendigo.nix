# .../home/users/grue/wendigo.nix
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
      asciinema
      bottom # better top
      broot
      choose # cut/awk
      delta # better git-diff
      doggo # dig
      duf # better df
      dust # du + rust
      fping # ping for mult
      git-absorb
      glow # markdown viewer
      gum # fancy cli snippets
      ijq # interactive jq
      iperf
      mcfly # history search
      pop # email from cli
      presenterm # presentations
      taplo # toml
      tig # git TUI
      tmux
      tmux-xpanes
      vhs # terminal gifs
      vlc
      viddy # better watch
      zellij

      _1password-gui
      discord
      kitty
      signal-desktop
      obsidian
    ];
  };

  xdg.enable = true;

  fonts.fontconfig.enable = true;

  programs.home-manager.enable = true;
  programs.firefox.enable = true;

}
