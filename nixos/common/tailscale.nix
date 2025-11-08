{
  config,
  pkgs,
  ...
}: {
  # mount the auth token file
  age.secrets.tailscale = {
    file = ../../secrets/tailscale.age;
    owner = "root";
    group = "root";
    mode = "0600";
  };

  services.tailscale.enable = true;

  networking = {
    firewall = {
      checkReversePath = "loose";
      allowedUDPPorts = [config.services.tailscale.port];
      trustedInterfaces = ["tailscale0"];
    };
  };

  # create a oneshot job to authenticate to Tailscale
  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";
    path = with pkgs; [jq];

    # make sure tailscale is running before trying to connect to tailscale
    after = [
      "network-pre.target"
      "tailscale.service"
      "run-agenix.d.mount"
    ];
    wants = [
      "network-pre.target"
      "tailscale.service"
      "run-agenix.d.mount"
    ];
    wantedBy = ["multi-user.target"];

    # set this service as a oneshot job
    serviceConfig.Type = "oneshot";

    # have the job run this shell script
    script = with pkgs; ''
      # wait for tailscaled to settle
      sleep 2

      # check if we are already authenticated to tailscale
      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ $status = "Running" ]; then
        exit 0
      fi

      # otherwise authenticate with tailscale
      ${tailscale}/bin/tailscale up --auth-key "$(cat "${config.age.secrets.tailscale.path}")"
    '';
  };
}
