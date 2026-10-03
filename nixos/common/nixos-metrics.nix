# nixos/common/nixos-metrics.nix
# Optional scrapers behind dashboards/nixos-host-overview.json. Self-contained:
# import this one file into any NixOS config that runs prometheus-node-exporter.
#
# Adds two things to node_exporter:
#   1. the systemd collector     -> node_systemd_unit_state{name,state}, timers
#   2. NixOS textfile metrics    -> nixos_* series (see script below)
#
# Cheap by design: the script only reads symlinks and one small file, no
# `du` or nix evaluation, so it is safe to run every few minutes.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.nixosMetrics;

  collect = pkgs.writeShellApplication {
    name = "nixos-metrics-collect";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      out="${cfg.textfileDirectory}/nixos.prom"
      tmp="$(mktemp "$out.XXXXXX")"
      trap 'rm -f "$tmp"' EXIT

      profile="$(readlink /nix/var/nix/profiles/system)"   # e.g. system-42-link
      gen="''${profile#system-}"; gen="''${gen%-link}"
      gen_time="$(stat -c %Y "/nix/var/nix/profiles/$profile")"

      # Reboot needed when the booted kernel/initrd/modules differ from the
      # current system (the same test nixos-rebuild-ng and system.autoUpgrade use).
      reboot=0
      for f in initrd kernel kernel-modules; do
        [ "$(readlink -f "/run/booted-system/$f")" = "$(readlink -f "/run/current-system/$f")" ] || reboot=1
      done

      version="$(cat /run/current-system/nixos-version 2>/dev/null || echo unknown)"
      switched="$(stat -c %Y /run/current-system)"
      now="$(date +%s)"

      cat > "$tmp" <<EOF
      # HELP nixos_info Running NixOS release string.
      # TYPE nixos_info gauge
      nixos_info{version="$version"} 1
      # HELP nixos_current_generation Generation number of the system profile.
      # TYPE nixos_current_generation gauge
      nixos_current_generation $gen
      # HELP nixos_generation_age_seconds Age of the newest system generation.
      # TYPE nixos_generation_age_seconds gauge
      nixos_generation_age_seconds $((now - gen_time))
      # HELP nixos_last_switch_timestamp_seconds When the running system was last activated.
      # TYPE nixos_last_switch_timestamp_seconds gauge
      nixos_last_switch_timestamp_seconds $switched
      # HELP nixos_reboot_required 1 if booted kernel/initrd/modules differ from the current system.
      # TYPE nixos_reboot_required gauge
      nixos_reboot_required $reboot
      EOF
      chmod 0644 "$tmp"
      mv "$tmp" "$out"
      trap - EXIT
    '';
  };
in {
  options.services.nixosMetrics = {
    enable = lib.mkEnableOption "NixOS-specific Prometheus metrics (systemd collector + textfile metrics)";

    textfileDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/node-exporter-textfile";
      description = "Directory node_exporter's textfile collector reads *.prom files from.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "5min";
      description = "How often to refresh the textfile metrics (systemd time span).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = ["systemd"];
      extraFlags = ["--collector.textfile.directory=${cfg.textfileDirectory}"];
    };

    systemd = {
      tmpfiles.rules = ["d ${cfg.textfileDirectory} 0755 root root -"];

      services.nixos-metrics = {
        description = "Write NixOS metrics for node_exporter's textfile collector";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe collect;
        };
      };

      timers.nixos-metrics = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "30s";
          OnUnitActiveSec = cfg.interval;
        };
      };
    };
  };
}
