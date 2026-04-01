# nixos/common/monitoring.nix
#
# Prometheus + Grafana monitoring stack for bunyip.
#
# Prometheus scrapes node_exporter (port 9100) from all NixOS hosts via
# Tailscale MagicDNS FQDNs. Non-NixOS devices without Tailscale are added
# to the "node-unmanaged" job by bare IP.
#
# Grafana binds to 0.0.0.0:3000 but is only reachable via the tailscale0
# interface (trusted in nixos/common/tailscale.nix).
{...}: {
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
        static_configs = [
          {
            targets = [
              "bunyip.armadillo-toad.ts.net:9100"
              "wendigo.armadillo-toad.ts.net:9100"
              "kushtaka.armadillo-toad.ts.net:9100"
              "snallygaster.armadillo-toad.ts.net:9100"
            ];
          }
        ];
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
