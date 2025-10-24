# home/users/grue.nix
{ pkgs, ... }:
{
  imports = [
    ../roles/base.nix
    # ../roles/dev.nix
  ];

  home.username = "grue";
  home.homeDirectory = "/home/grue";
  home.stateVersion = "25.05";

  programs.git.settings.user = {
    name = "Ben Lechlitner";
    email = "otherland@gmail.com";
  };

  # Personal touches
  home.packages = with pkgs; [
    obsidian
    signal-desktop
  ];
}
