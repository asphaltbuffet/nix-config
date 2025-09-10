# .../home/users/jsquats/kushtaka.nix
{ lib, pkgs, ... }:
{

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
