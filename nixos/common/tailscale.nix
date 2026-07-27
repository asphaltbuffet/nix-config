{config, ...}: {
  services.tailscale.enable = true;

  # Enable Tailscale SSH fleet-wide: authorize SSH via tailnet identity + ACLs
  # instead of ~/.ssh/authorized_keys. Applied on every rebuild via `tailscale
  # set`, so new hosts get it without a manual `tailscale up --ssh`.
  services.tailscale.extraSetFlags = ["--ssh"];

  networking = {
    firewall = {
      checkReversePath = "loose";
      allowedUDPPorts = [config.services.tailscale.port];
      trustedInterfaces = ["tailscale0"];
    };
  };
}
