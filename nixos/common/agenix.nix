# nixos/common/agenix.nix
# System-level agenix secret declarations.
# Secrets are decrypted to /run/agenix/ at activation time.
# Each secret is encrypted to the host's SSH key in secrets.nix.
{...}: {
  age.secrets = {
    hcPingKey = {
      file = ../../secrets/hcPingKey.age;
      owner = "root";
      mode = "0400";
    };
  };
}
