# nixos/common/smartd.nix
# Fleet-wide disk-health monitoring.
#
# smartd watches every disk (-a: health status, error log, self-test log,
# pre-fail attributes, pending/reallocated sectors) and, on a problem, runs
# hc-smartd-notify, which sends a /fail ping to the healthchecks.io check
# `smartd-<host>` (auto-created via ?create=1). Problems only: no heartbeat,
# so laptops that sleep don't page. -M daily repeats the ping while the
# problem persists. Clear a check after fixing a disk: `just hc-clear smartd-<host>`.
#
# Self-tests: Always-on hosts (host.alwaysOn) run a weekly short + monthly
# long test overnight; other hosts a weekly short test at midday, skipped if
# the disk is in standby. No temperature alerts: laptop NVMe runs hot by
# design; temperatures are visible in Grafana via smartctl-exporter.
{
  config,
  pkgs,
  ...
}: let
  host = config.networking.hostName;

  hcSmartdNotify = pkgs.writeShellApplication {
    name = "hc-smartd-notify";
    runtimeInputs = [pkgs.curl];
    text = ''
      [[ -r /run/agenix/hcPingKey ]] \
        || { echo "hc-smartd-notify: /run/agenix/hcPingKey not readable, skipping ping" >&2; exit 0; }
      PING_KEY=$(< /run/agenix/hcPingKey)
      slug="''${HC_SLUG:-smartd-${host}}"
      printf 'host: %s\ndevice: %s\nfailtype: %s\n\n%s\n' \
        "${host}" \
        "''${SMARTD_DEVICEINFO:-''${SMARTD_DEVICE:-unknown}}" \
        "''${SMARTD_FAILTYPE:-unknown}" \
        "''${SMARTD_MESSAGE:-}" \
        | curl -fsS --retry 3 --data-binary @- \
            "https://hc-ping.com/$PING_KEY/$slug/fail?create=1" > /dev/null
      unset PING_KEY
    '';
  };

  monitored = "-a -o on -S on -m <nomailer> -M exec ${hcSmartdNotify}/bin/hc-smartd-notify -M daily";

  schedule =
    if config.host.alwaysOn
    then "-s (S/../../7/03|L/../01/./04)"
    else "-n standby,q -s S/../../7/12";
in {
  services.smartd = {
    enable = true;

    # Disable every nixpkgs notifier: any of them injects its own
    # `-M exec smartd-notify.sh` ahead of ours.
    notifications = {
      mail.enable = false;
      wall.enable = false;
      x11.enable = false;
    };

    defaults = {
      # DEFAULT line: inherited by explicit services.smartd.devices entries
      inherit monitored;
      # DEVICESCAN line: DEFAULT directives already apply to it (repeating
      # -m/-M here only makes smartd log "ignoring previous"), so add just
      # the self-test schedule.
      autodetected = schedule;
    };
  };

  # SMART metrics for Grafana; scraped by bunyip over tailscale0 (port 9633)
  services.prometheus.exporters.smartctl.enable = true;
}
