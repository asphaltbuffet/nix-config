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
    url = lib.mkDefault "https://asphaltbuffet.com/nix-config/hosts/${config.networking.hostName}/store-path";

    # "smart" applies immediately for non-kernel updates, waits for reboot on
    # kernel updates — balances staying current with avoiding mid-session disruption.
    switchMode = lib.mkDefault "smart";

    # Stagger deployment across hosts to avoid thundering-herd on Cachix.
    randomizedDelay = lib.mkDefault "30m";

    # Check once a day (systemd OnCalendar format).
    interval = lib.mkDefault "daily";
  };

  # The upstream module hardcodes OnStartupSec = "0sec", which causes the service
  # to fire immediately on boot/resume — freezing laptops as they wake from standby.
  # Override with mkForce to give the system 5 minutes to settle first.
  systemd.timers.nixos-autodeploy.timerConfig.OnStartupSec = lib.mkForce "5min";

  # Push an Alert when a deploy fails (ADR-0018). Failure only — a host that
  # is asleep and never runs the timer stays quiet, which is intended.
  systemd.services.nixos-autodeploy = lib.mkIf config.system.autoDeploy.enable {
    serviceConfig.Environment = "HOME=/root";
    onFailure = ["alert@%n.service"];
  };

  # Upstream records its last deploy in /run/deployed-system, which a reboot
  # wipes; if CI published in the meantime, every later run sees
  # current != deployed != upstream and skips as "deployed manually" forever.
  # Re-seed it at boot so a reboot counts as still being on what was deployed.
  # `L` only creates when missing; the tool atomically replaces it on deploy.
  systemd.tmpfiles.rules = lib.mkIf config.system.autoDeploy.enable [
    "L /run/deployed-system - - - - /run/booted-system"
  ];
}
