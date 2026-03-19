{
  config,
  pkgs,
  ...
}: let
  # The public key used for git/jj commit signing.
  # Update this value after generating the key in 1Password (Task 2).
  # Format: "ssh-ed25519 AAAA... comment"
  signingKeyPub = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOeLAZg365wMtiUxEAXWscq4jSRhXeHH8X3NNcTT0DoP";

  # Write the public key to a file in the Nix store.
  # git and jj need a file path, not a string, to reference the signing key.
  signingKeyFile = pkgs.writeText "grue-signing.pub" signingKeyPub;
in {
  # SSH client configuration
  programs.ssh = {
    enable = true;
  };

  # Route all SSH auth through 1Password agent.
  # Uses absolute path via config.home.homeDirectory to ensure correct
  # expansion in all contexts (interactive and non-interactive git operations).
  # Note: IdentityAgent with 1P means no key files on disk — 1P holds the private key.
  programs.ssh.matchBlocks."*" = {
    identityAgent = "${config.home.homeDirectory}/.1password/agent.sock";
    serverAliveInterval = 60;
    serverAliveCountMax = 3;
  };

  # Git SSH commit signing.
  # Using programs.git.signing (typed home-manager options) rather than
  # raw settings keys — the typed API is validated by home-manager and
  # automatically wires the ssh-keygen binary when format = "ssh".
  programs.git = {
    signing = {
      format = "ssh";
      # The .pub file path tells git which key to request from the SSH agent.
      # The agent (1Password) performs the actual signing; no private key on disk.
      key = "${signingKeyFile}";
      signByDefault = true;
    };
  };

  # jujutsu commit signing via SSH
  programs.jujutsu.settings = {
    signing = {
      sign-all = true;
      backend = "ssh";
      key = "${signingKeyFile}";
    };
  };
}
