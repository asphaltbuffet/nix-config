{pkgs, ...}: {
  users = {
    # GID/UID allocation policy — read before adding either.
    #
    # NFS shares are mounted with sec=sys (nixos/common/nas.nix), which sends
    # raw numeric ids with no name mapping. The NAS therefore shares one id
    # space with these hosts, but cannot be managed by Nix — its allocations
    # are facts to design around, not values we control. The NAS is known to
    # use low gids (100, 1000 observed on its own files).
    #
    # Ranges, to keep the two sides from colliding:
    #
    #   2000-2099  per-user groups (one per user, gid == uid by convention)
    #   3000-3099  shared resource groups (cross-user access to a data set)
    #
    # Both sit above the NAS's low allocations and below nixpkgs' static ids.
    # When adding a shared group, take the next free number in 3000-3099 and
    # check `misc/ids.nix` in nixpkgs plus `getent group` on a running host.
    groups = {
      grue.gid = 2001;
      jsquats.gid = 2003;
      sukey.gid = 2004;

      # Shared ownership for game content (ROMs, artwork, media) so the user
      # who syncs files and the kiosk user that reads them can both access
      # them without sudo or a chown after every transfer. Deliberately not
      # named `arcade` — that is the cabinet's kiosk *user*, whereas this is
      # about the data and applies to any host holding a game library.
      games.gid = 3000;
    };

    users = {
      grue = {
        isNormalUser = true;
        uid = 2001;
        group = "grue";
        description = "grue";
        extraGroups = [
          "docker"
          "games"
          "networkmanager"
          "wheel"
        ];
        shell = pkgs.zsh;

        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOeLAZg365wMtiUxEAXWscq4jSRhXeHH8X3NNcTT0DoP"
        ];
      };

      jsquats = {
        isNormalUser = true;
        uid = 2003;
        group = "jsquats";
        description = "jasper";
        extraGroups = ["networkmanager"];
        shell = pkgs.bash;
      };

      sukey = {
        isNormalUser = true;
        uid = 2004;
        group = "sukey";
        description = "sukey";
        extraGroups = ["networkmanager"];
        shell = pkgs.zsh;
      };
    };
  };

  # Attach Home-Manager configs
  home-manager.users = {
    grue = import ../../home/users/grue.nix;
    jsquats = import ../../home/users/jsquats.nix;
    sukey = import ../../home/users/sukey.nix;
  };
}
