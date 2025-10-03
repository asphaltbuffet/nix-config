# nixos/profiles/gaming.nix
{ config, pkgs, lib, ... }:
{
  #### Steam ####
  programs.steam = {
    enable = true;

    # Open firewall for Remote Play streaming
    remotePlay.openFirewall = true;

    # Open firewall for dedicated server hosting
    dedicatedServer.openFirewall = true;
  };

  #### Gamemode (optional but useful) ####
  programs.gamemode.enable = true;

  #### Extra gaming tools ####
  environment.systemPackages = with pkgs; [
    lutris        # launcher for non-Steam games
    # mangohud      # FPS/metrics overlay
    # protonup      # easy Proton-GE installer
    prismlauncher
  ];

  #### Graphics drivers ####
  # These can be overridden by a laptop profile if needed
  hardware.opengl.enable = true;
}

