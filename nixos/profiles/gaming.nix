# nixos/profiles/gaming.nix
{pkgs, ...}: {
  programs.steam = {
    enable = true;

    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = false;

    extraCompatPackages = [pkgs.proton-ge-bin];
  };

  programs.gamemode.enable = true;

  # These can be overridden by a laptop profile if needed
  hardware.graphics.enable = true;
}
