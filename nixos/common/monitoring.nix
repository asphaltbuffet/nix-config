# nixos/common/monitoring.nix
#
# Prometheus + Grafana monitoring stack for bunyip.
#
# Prometheus scrapes node_exporter (9100) and smartctl_exporter (9633) from
# every host in nixos/hosts/ (auto-discovered, ADR-0003) via Tailscale
# MagicDNS FQDNs. Non-NixOS devices without Tailscale are added to the
# "node-unmanaged" job by bare IP.
#
# Laptops/desktops that sleep will show up == 0; before alerting on `up`,
# filter to Always-on hosts (CONTEXT.md, host.alwaysOn).
#
# Grafana binds to 0.0.0.0:3000 but is only reachable via the tailscale0
# interface (trusted in nixos/common/tailscale.nix).
{lib, ...}: let
  hosts = lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../hosts));
  targetsOn = port: map (h: "${h}.armadillo-toad.ts.net:${toString port}") hosts;
in {
  age.secrets.grafanaKey = {
    file = ../../secrets/grafanaKey.age;
    owner = "grafana";
    mode = "0400";
  };

  services.prometheus = {
    enable = true;
    port = 9090;

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{targets = targetsOn 9100;}];
      }
      {
        job_name = "smartctl";
        static_configs = [{targets = targetsOn 9633;}];
      }
      {
        # Non-NixOS devices that cannot run Tailscale — add bare IPs here.
        job_name = "node-unmanaged";
        static_configs = [
          {
            targets = [];
          }
        ];
      }
    ];
  };

  services.grafana = {
    enable = true;

    settings.server = {
      http_addr = "0.0.0.0";
      http_port = 3000;
      domain = "bunyip.armadillo-toad.ts.net";
    };

    # Read secret_key from agenix-decrypted file at runtime using Grafana's
    # built-in file interpolation syntax.
    settings.security.secret_key = "$__file{/run/agenix/grafanaKey}";

    provision.datasources.settings.datasources = [
      {
        name = "Prometheus";
        type = "prometheus";
        url = "http://localhost:9090";
        isDefault = true;
      }
    ];
  };
}
