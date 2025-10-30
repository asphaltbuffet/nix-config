# home/roles/player.nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    mangohud      # FPS/metrics overlay
    prismlauncher
  ];
}
