# nixos/common/autodeploy.nix
# Configures nixos-autodeploy defaults. Hosts opt in by setting:
#   system.autoDeploy.enable = true;
{
  inputs,
  config,
  lib,
  ...
}: {
  imports = [inputs.nixos-autodeploy.nixosModules.default];

  system.autoDeploy = {
    # URL is constructed automatically from the hostname.
    # CI publishes store paths at this location via GitHub Pages.
    url = lib.mkDefault "https://asphaltbuffet.github.io/nix-config/hosts/${config.networking.hostName}/store-path";

    # "boot" applies the new config on next reboot — safer for laptops than
    # "switch" (which activates immediately, potentially mid-session).
    # Override to "switch" in server host configs where instant rollout is preferred.
    switchMode = lib.mkDefault "boot";

    # Stagger deployment across hosts to avoid thundering-herd on Cachix.
    randomizedDelay = lib.mkDefault "30m";

    # Check once a day (systemd OnCalendar format).
    interval = lib.mkDefault "daily";
  };
}
