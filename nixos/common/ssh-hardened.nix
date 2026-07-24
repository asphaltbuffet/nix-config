# nixos/common/ssh-hardened.nix
# The fleet's baseline SSH server hardening. Import from any profile that
# exposes SSH (server, arcade). Deliberately independent of the CUPS/Avahi/
# monitoring bundle in server.nix so single-purpose hosts can harden SSH
# without pulling in a print server.
_: {
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };
}
