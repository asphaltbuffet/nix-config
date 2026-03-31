# nixos/common/tailscale-subnet-router.nix
#
# Configures this host as a Tailscale subnet router.
# Advertises LAN routes so non-Tailscale devices are reachable from
# any node on the tailnet.
#
# After deploying, approve the advertised routes in the Tailscale admin
# console: https://login.tailscale.com/admin/machines
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.tailscaleSubnetRouter;
  routesStr = lib.concatStringsSep "," cfg.routes;
in {
  options.services.tailscaleSubnetRouter = {
    routes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["192.168.86.0/24"];
      description = "CIDR subnets to advertise as Tailscale routes.";
    };
  };

  config = {
    # useRoutingFeatures = "server" sets the required kernel sysctl flags
    # (net.ipv4.ip_forward and net.ipv6.conf.all.forwarding) automatically.
    services.tailscale.useRoutingFeatures = "server";

    # One-shot service that advertises routes after tailscaled is running.
    # Idempotent: running it again on reboot is safe.
    systemd.services.tailscale-advertise-routes = {
      description = "Advertise Tailscale subnet routes";
      after = ["tailscaled.service" "network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.tailscale}/bin/tailscale set --advertise-routes=${routesStr}";
      };
    };
  };
}
