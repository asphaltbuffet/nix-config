{
  pkgs,
  lib,
  self,
  ...
}: let
  bootstrapScript = pkgs.writeShellApplication {
    name = "nixos-bootstrap";
    # All tools the script calls — no ambient PATH required
    runtimeInputs = with pkgs; [
      coreutils # mountpoint, mkdir, chmod, cp, cat, cut, tee
      openssh # ssh-keygen, scp
      nixos-install-tools # nixos-generate-config, nixos-install
      util-linux # mount helpers used by mountpoint
      less # pager for instructions
      git # clone the repo if network available
      curl # network availability probe
      iproute2 # `ip addr` to show live machine IP in instructions
    ];
    text = builtins.readFile ./bootstrap.sh;
  };
in {
  imports = [../profiles/installer.nix];

  networking.hostName = "nixos-installer";

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  # Override the empty initialHashedPassword set by installation-cd-minimal.nix
  # so the live session has a usable password for SSH access
  users.users.nixos.initialHashedPassword = lib.mkForce null;
  users.users.nixos.initialPassword = "nixos";

  environment.systemPackages = [bootstrapScript];

  # Bundle a read-only snapshot of the repo into the ISO.
  # Available at /etc/nix-config for reference; nixos-install should still
  # pull from GitHub after commits are pushed (or from a USB-mounted checkout).
  environment.etc."nix-config".source = self;

  # Greet users with the bootstrap hint at login
  environment.interactiveShellInit = ''
    echo ""
    echo "  NixOS Installer — to bootstrap a new host, run: nixos-bootstrap"
    echo "  Repo snapshot available at: /etc/nix-config (read-only)"
    echo ""
  '';
}
