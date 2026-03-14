{
  pkgs,
  lib,
  ...
}: let
  bootstrapScript = pkgs.writeShellApplication {
    name = "nixos-bootstrap";
    runtimeInputs = with pkgs; [
      git
      openssh
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

  # Greet users with the bootstrap hint at login
  environment.interactiveShellInit = ''
    echo ""
    echo "  NixOS Installer — to bootstrap a new host, run: nixos-bootstrap"
    echo ""
  '';
}
