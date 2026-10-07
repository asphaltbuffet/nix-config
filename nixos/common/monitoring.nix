# nixos/common/monitoring.nix
#
# Prometheus + Grafana monitoring stack for bunyip.
#
# Prometheus scrapes node_exporter (9100) and smartctl_exporter (9633) from
# every host in nixos/hosts/ (auto-discovered, ADR-0003) via Tailscale
# MagicDNS FQDNs. Non-NixOS devices without Tailscale are added to the
# "node-unmanaged" job by bare IP. Tailnet devices come from the Tailscale API
# exporter on localhost (ADR-0023).
#
# Laptops/desktops that sleep will show up == 0; before alerting on `up`,
# filter to Always-on hosts (CONTEXT.md, host.alwaysOn).
#
# Grafana binds to 0.0.0.0:3000 but is only reachable via the tailscale0
# interface (trusted in nixos/common/tailscale.nix).
{
  config,
  lib,
  self,
  ...
}: let
  hosts = lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../hosts));
  targetsOn = port: map (h: "${h}.armadillo-toad.ts.net:${toString port}") hosts;

  # Shared by Prometheus and the Grafana datasource: Grafana derives
  # $__rate_interval from it, and rate() over a window of one scrape interval
  # returns nothing (Grafana assumes 15s unless told otherwise).
  scrapeInterval = "1m";

  rendererToken = config.age.secrets.grafanaRendererToken.path;

  # Tailnet devices expected to be online around the clock (ADR-0023): every
  # Always-on host plus every Tailnet sidecar. Other hosts are read through the
  # flake; this host reads its own `config`, so it is not evaluated twice.
  otherHosts = lib.filterAttrs (n: _: n != config.networking.hostName) self.nixosConfigurations;
  alwaysOnHosts =
    lib.optional config.host.alwaysOn config.networking.hostName
    ++ lib.attrNames (lib.filterAttrs (_: h: h.config.host.alwaysOn) otherHosts);
  sidecars =
    config.host.tailnetSidecars
    ++ lib.concatMap (h: h.config.host.tailnetSidecars) (lib.attrValues otherHosts);
  expectedAlwaysOn = lib.unique (alwaysOnHosts ++ sidecars);
in {
  age.secrets = {
    grafanaKey = {
      file = ../../secrets/grafanaKey.age;
      owner = "grafana";
      mode = "0400";
    };

    # Grafana 13 refuses to start with the default renderer_token, so Grafana
    # and grafana-image-renderer read one shared token from this env file
    # (GF_RENDERING_RENDERER_TOKEN= for Grafana, AUTH_TOKEN= for the renderer).
    # EnvironmentFile is read by systemd as root, so the DynamicUser renderer
    # needs no file access.
    grafanaRendererToken = {
      file = ../../secrets/grafanaRendererToken.age;
      mode = "0400";
    };

    # Read-only OAuth client for the Tailscale API exporter (ADR-0023).
    tailscale-exporter-env = {
      file = ../../secrets/tailscale-exporter-env.age;
      mode = "0400";
    };
  };

  systemd.services = {
    grafana.serviceConfig.EnvironmentFile = rendererToken;
    grafana-image-renderer.serviceConfig.EnvironmentFile = rendererToken;
  };

  services = {
    prometheus = {
      enable = true;
      port = 9090;
      globalConfig.scrape_interval = scrapeInterval;

      exporters.tailscale = {
        enable = true;
        listenAddress = "127.0.0.1";
        environmentFile = config.age.secrets.tailscale-exporter-env.path;
      };

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
        {
          # Control-plane API view of every Tailnet device (ADR-0023). The
          # exporter calls Tailscale over the internet, not the tailnet.
          job_name = "tailscale";
          static_configs = [{targets = ["127.0.0.1:9250"];}];
        }
      ];

      # One constant series per expected device, so the dashboard learns the
      # expectation from Nix rather than from Tailscale (which carries no tag
      # label on its device series). Join on `hostname`.
      rules = [
        (builtins.toJSON {
          groups = [
            {
              name = "tailnet-expectation";
              rules =
                map (h: {
                  record = "tailnet_expected_always_on";
                  expr = "vector(1)";
                  labels.hostname = h;
                })
                expectedAlwaysOn;
            }
          ];
        })
      ];
    };

    # Headless-Chromium renderer so dashboards/panels can be rendered to PNG
    # (Grafana API / MCP get_panel_image). Listens on localhost:8081 only.
    grafana-image-renderer = {
      enable = true;
      provisionGrafana = true;
    };

    grafana = {
      enable = true;

      settings.server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
        domain = "bunyip.armadillo-toad.ts.net";
      };

      # Read secret_key from agenix-decrypted file at runtime using Grafana's
      # built-in file interpolation syntax.
      settings.security.secret_key = "$__file{/run/agenix/grafanaKey}";

      # Dashboard JSON lives in dashboards/ (portable; also importable by hand).
      provision.dashboards.settings.providers = [
        {
          name = "nix-config";
          options.path = ../../dashboards;
        }
      ];

      provision.datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://localhost:9090";
          isDefault = true;
          jsonData.timeInterval = scrapeInterval;
        }
      ];
    };
  };
}
