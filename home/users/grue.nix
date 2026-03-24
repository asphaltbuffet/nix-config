# home/users/grue.nix
{pkgs, ...}: let
  identity = {
    name = "Ben Lechlitner";
    email = "30903912+asphaltbuffet@users.noreply.github.com";
  };
in {
  imports = [
    ../roles/base.nix
    ../roles/admin.nix
    ../roles/dev.nix
    ../roles/player.nix

    ../modules/ssh
  ];

  home.username = "grue";
  home.homeDirectory = "/home/grue";
  home.stateVersion = "25.05";

  programs.git.settings.user = identity;

  programs.jujutsu.settings.user = identity;

  # Personal touches
  home.packages = with pkgs; [
    obsidian
    signal-desktop
  ];
}
