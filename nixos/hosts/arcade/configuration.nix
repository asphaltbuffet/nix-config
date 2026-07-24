{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix

    # Brings the cross-host users (grue et al). Intentional on a kiosk: the
    # arcade user has no password/authorized keys, so grue's key from here is
    # the only way to SSH in for admin/rescue. Trade-off: this also builds the
    # other users' home-manager generations into the closure — accepted.
    ../../common/users.nix

    ../../profiles/base.nix
    ../../profiles/arcade.nix
  ];

  networking.hostName = "arcade";

  # Machine-local kiosk user. Defined here (not in common/users.nix) so it
  # exists only on the cabinet. Autologin is wired by the arcade profile.
  users.groups.arcade.gid = 2005;
  users.users.arcade = {
    isNormalUser = true;
    uid = 2005;
    group = "arcade";
    description = "arcade";
    extraGroups = ["audio" "video"];
    shell = pkgs.zsh;
  };

  home-manager.users.arcade = import ../../../home/users/arcade.nix;

  # Before changing this value read the documentation for this option
  # (man configuration.nix or https://nixos.org/nixos/options.html).
  system.stateVersion = "26.11";

  # Pull NixOS updates automatically from CI via cachix + GitHub Pages.
  # Create .autodeploy-skip/arcade to pause without editing this file.
  system.autoDeploy.enable = true;
}
