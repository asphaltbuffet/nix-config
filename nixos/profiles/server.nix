# nixos/profiles/server.nix
# Headless server profile. Import alongside base.nix for home-lab nodes.
# Do NOT import laptop/ with this profile — they are mutually exclusive.
{...}: {
  imports = [
    ../common/tailscale-subnet-router.nix
    ../common/monitoring.nix
  ];

  # Harden SSH for server use
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };

  # CUPS print server — serve printers to the network via mDNS/Bonjour
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };
}
