# nixos/common/nas.nix
#
# NFS v4.1 mounts for terra-nas (TerraMaster F4-423, TOS 6).
#
# NAS UID mapping (must match NixOS UIDs in users.nix):
#   grue (2001) / jsquats (2003) / sukey (2004)
{...}: let
  nasHost = "192.168.86.22"; # TODO: at some point change this to an fqdn
  nfsOptions = [
    "vers=4.1"
    "soft"
    "timeo=30"
    "retrans=3"
    "_netdev"
    "nofail"
    "x-systemd.automount"
    "x-systemd.idle-timeout=600"
    "x-systemd.mount-timeout=10"
  ];

  mkNfsMount = nasPath: {
    device = "${nasHost}:${nasPath}";
    fsType = "nfs";
    options = nfsOptions;
  };
in {
  boot.supportedFilesystems = ["nfs"];
  services.rpcbind.enable = true;

  fileSystems = {
    # Per-user private shares
    "/home/grue/nas" = mkNfsMount "/Volume1/grue";
    "/home/jsquats/nas" = mkNfsMount "/Volume1/jsquats";
    "/home/sukey/nas" = mkNfsMount "/Volume1/sukey";

    # Shared area accessible by all users
    "/nas/public" = mkNfsMount "/Volume1/public";
  };

  # Create mount point directories before mounts are attempted
  systemd.tmpfiles.rules = [
    "d /home/grue/nas 0700 grue users -"
    "d /home/jsquats/nas 0700 jsquats users -"
    "d /home/sukey/nas 0700 sukey users -"
    "d /nas/public 0755 root root -"
  ];
}
