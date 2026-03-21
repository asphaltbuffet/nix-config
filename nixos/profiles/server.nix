# nixos/profiles/server.nix
# Lightweight headless server profile. Import alongside base.nix for home-lab nodes.
# Do NOT import laptop/ with this profile — they are mutually exclusive.
{lib, ...}: {
  # Explicitly disable all desktop/GUI services
  services.xserver.enable = lib.mkForce false;
  services.displayManager.sddm.enable = lib.mkForce false;
  services.desktopManager.plasma6.enable = lib.mkForce false;

  # No bluetooth on headless servers
  hardware.bluetooth.enable = lib.mkForce false;

  # No print spooler on servers (base.nix sets mkDefault true)
  services.printing.enable = lib.mkForce false;

  # Harden SSH for server use (stricter than base.nix defaults)
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };

  # Disable firmware update service — servers are not AC-only and rarely need fwupd
  services.fwupd.enable = lib.mkForce false;
}
