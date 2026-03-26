# nixos/common/autodeploy.nix
# Configures nixos-autodeploy defaults. Hosts opt in by setting:
#   system.autoDeploy.enable = true;
{
  inputs,
  config,
  lib,
  pkgs,
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

  # Wire nixos-autodeploy into healthchecks.io so failed or missed runs are visible.
  # Only active when autodeploy is enabled. The 1Password service account token is
  # read from a root-only file provisioned manually on each host
  # (see README — provisioning steps after first boot).
  # The "-" prefix on EnvironmentFile silently skips the file if absent
  # (e.g. on hosts where autodeploy is disabled or the file hasn't been provisioned).
  systemd.services.nixos-autodeploy = lib.mkIf config.system.autoDeploy.enable {
    onSuccess = [ "nixos-autodeploy-healthcheck-success.service" ];
    onFailure = [ "nixos-autodeploy-healthcheck-failure.service" ];
  };

  systemd.services.nixos-autodeploy-healthcheck-success = lib.mkIf config.system.autoDeploy.enable {
    description = "Ping healthchecks.io — nixos-autodeploy succeeded";
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "-/etc/op/1password-service-account-token";
      StandardOutput = "null";
      NoNewPrivileges = true;
      PrivateTmp = true;
      DynamicUser = true;
      ExecStart = "${pkgs.writeShellApplication {
        name = "hc-ping-success";
        runtimeInputs = [ pkgs.onepassword-cli pkgs.curl ];
        text = ''
          PING_KEY=$(op read "op://Service/ping_key/credential")
          curl -fsS --retry 3 "https://hc-ping.com/$PING_KEY/nixos-autodeploy-${config.networking.hostName}" > /dev/null
        '';
      }}/bin/hc-ping-success";
    };
  };

  systemd.services.nixos-autodeploy-healthcheck-failure = lib.mkIf config.system.autoDeploy.enable {
    description = "Ping healthchecks.io — nixos-autodeploy failed";
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = "-/etc/op/1password-service-account-token";
      StandardOutput = "null";
      NoNewPrivileges = true;
      PrivateTmp = true;
      DynamicUser = true;
      ExecStart = "${pkgs.writeShellApplication {
        name = "hc-ping-failure";
        runtimeInputs = [ pkgs.onepassword-cli pkgs.curl ];
        text = ''
          PING_KEY=$(op read "op://Service/ping_key/credential")
          curl -fsS --retry 3 "https://hc-ping.com/$PING_KEY/nixos-autodeploy-${config.networking.hostName}/fail" > /dev/null
        '';
      }}/bin/hc-ping-failure";
    };
  };
}
