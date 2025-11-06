# nixos/profiles/gaming.nix
{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.steam = {
    enable = true;

    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = false;
  };

  programs.gamemode.enable = true;

  # These can be overridden by a laptop profile if needed
  hardware.graphics.enable = true;
}
