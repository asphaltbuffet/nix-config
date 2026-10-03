# nixos/common/smartd.nix
# Fleet-wide disk-health monitoring.
#
# smartd watches every disk (-a: health status, error log, self-test log,
# pre-fail attributes, pending/offline-uncorrectable sector counts) and, on a
# problem, runs smartd-alert, which pushes a priority-4 Alert
# "<host>: smartd <failtype> on <device>" (ADR-0018). Only those two fields
# are sent — never SMARTD_MESSAGE or SMARTD_DEVICEINFO (serials); the topic
# is public. Problems only: no heartbeat, so laptops that sleep don't page.
# -M daily repeats the alert while the problem persists; nothing to clear
# after fixing a disk.
#
# Self-tests: Always-on hosts (host.alwaysOn) run a weekly short + monthly
# long test overnight; other hosts a weekly short test at midday, skipped if
# the disk is in standby (-n standby,q; ATA-only, no effect on NVMe-only
# laptops), and -d removable tolerates a removable/USB disk disappearing on
# these non-always-on hosts. No -W temperature thresholds, but on NVMe -H
# includes the critical-warning temperature bit, so an NVMe drive reporting
# over-temperature in its health status WILL alert (intended); temperature
# trends are visible in Grafana via smartctl-exporter.
{
  config,
  pkgs,
  ...
}: let
  smartdAlert = pkgs.writeShellApplication {
    name = "smartd-alert";
    text = ''
      exec ${config.alerts.package}/bin/alert --priority 4 --tag smartd -- \
        smartd "''${SMARTD_FAILTYPE:-unknown}" on "''${SMARTD_DEVICE:-unknown}"
    '';
  };

  # Notify hook only. smartd directives are additive, so anything on the
  # DEFAULT line can't be dropped by an explicit device entry; checks live on
  # DEVICESCAN (and on each explicit device) instead.
  notify = "-m <nomailer> -M exec ${smartdAlert}/bin/smartd-alert -M daily";

  schedule =
    if config.host.alwaysOn
    then "-s (S/../../7/03|L/../01/./04)"
    else "-d removable -n standby,q -s S/../../7/12";
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
      # DEFAULT line: inherited by every following line, including explicit
      # services.smartd.devices entries (which pick their own checks)
      monitored = notify;
      # DEVICESCAN line: full checks plus the self-test schedule
      autodetected = "-a -o on -S on ${schedule}";
    };
  };

  # SMART metrics for Grafana; scraped by bunyip over tailscale0 (port 9633)
  services.prometheus.exporters.smartctl.enable = true;
}
