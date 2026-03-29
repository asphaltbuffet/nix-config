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
  # Only active when autodeploy is enabled. The ping key is decrypted by agenix
  # to /run/agenix/hcPingKey at activation time (see nixos/common/agenix.nix).
  # The "-" prefixes allow the service to continue if monitoring fails.
  # https://healthchecks.io/docs/monitoring_systemd_tasks/
  systemd.services.nixos-autodeploy = lib.mkIf config.system.autoDeploy.enable (
    let
      host = config.networking.hostName;
      # Only ping healthchecks when triggered by the timer, not by the activation
      # script (which fires after every nixos-rebuild switch/test). Systemd sets
      # TRIGGER_TIMER_REALTIME_USEC when a service is started by a timer; it is
      # unset for all other invocations.
      hcPingStart = pkgs.writeShellApplication {
        name = "hc-ping-start";
        runtimeInputs = [pkgs.curl];
        text = ''
          [[ -n "''${TRIGGER_TIMER_REALTIME_USEC:-}" ]] || exit 0
          [[ -r /run/agenix/hcPingKey ]] \
            || { echo "hc-ping-start: /run/agenix/hcPingKey not readable, skipping ping" >&2; exit 0; }
          PING_KEY=$(< /run/agenix/hcPingKey)
          export PING_KEY
          curl -fsS --retry 3 "https://hc-ping.com/$PING_KEY/nixos-autodeploy-${host}/start" > /dev/null
          unset PING_KEY
        '';
      };
      hcPingDone = pkgs.writeShellApplication {
        name = "hc-ping-done";
        runtimeInputs = [pkgs.curl];
        text = ''
          [[ -n "''${TRIGGER_TIMER_REALTIME_USEC:-}" ]] || exit 0
          EXIT_STATUS="''${EXIT_STATUS:-0}"
          [[ -r /run/agenix/hcPingKey ]] \
            || { echo "hc-ping-done: /run/agenix/hcPingKey not readable, skipping ping" >&2; exit 0; }
          PING_KEY=$(< /run/agenix/hcPingKey)
          export PING_KEY
          curl -fsS --retry 3 "https://hc-ping.com/$PING_KEY/nixos-autodeploy-${host}/$EXIT_STATUS" > /dev/null
          unset PING_KEY
        '';
      };
    in {
      serviceConfig = {
        Environment = "HOME=/root";
        # "-" prefix means failure is non-fatal; service continues regardless.
        ExecStartPre = "-${hcPingStart}/bin/hc-ping-start";
        ExecStopPost = "-${hcPingDone}/bin/hc-ping-done";
      };
    }
  );
}
