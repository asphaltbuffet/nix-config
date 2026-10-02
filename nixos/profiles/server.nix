# nixos/profiles/server.nix
# Headless server profile. Import alongside base.nix for home-lab nodes.
# Do NOT import laptop/ with this profile — they are mutually exclusive.
{...}: {
  imports = [
    ../common/ssh-hardened.nix
    ../common/tailscale-subnet-router.nix
    ../common/monitoring.nix
  ];

  # bunyip and future home-lab nodes run 24/7 (CONTEXT.md: Always-on host)
  host.alwaysOn = true;

  # CUPS print server — serve printers to the network via mDNS/Bonjour
  services = {
    printing.enable = true;
    avahi = {
      enable = true;
      nssmdns4 = true;
    };
  };
}
