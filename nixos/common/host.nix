# nixos/common/host.nix
# Facts about what a host IS, read by other modules to adapt their behaviour.
# Terms are defined in CONTEXT.md ("Machines and identity").
{lib, ...}: {
  options.host = {
    alwaysOn = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether this is an Always-on host (CONTEXT.md): expected to be powered
        and reachable around the clock, unlike laptops and desktops that sleep
        or power off. Scheduled maintenance (e.g. smartd self-tests) and
        liveness expectations key off this.
      '';
    };
    tailnetSidecars = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["micasa"];
      description = ''
        Tailnet device names (the sidecar's TS_HOSTNAME) of the Tailnet sidecars
        (CONTEXT.md) running on this host. Each service module registers its own,
        so the tailnet dashboard's expected-always-on list (monitoring.nix) uses
        the exact name the sidecar registers with Tailscale.
      '';
    };
  };
}
