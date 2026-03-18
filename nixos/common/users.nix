{pkgs, ...}: {
  users.groups.grue.gid = 2001;
  users.groups.jsquats.gid = 2003;
  users.groups.sukey.gid = 2004;

  users.users.grue = {
    isNormalUser = true;
    uid = 2001;
    group = "grue";
    description = "grue";
    extraGroups = [
      "docker"
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.zsh;

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBCNN0FY6PqVhfejv10JDfq56G1DTR4RWNjPpt/LSNRN"
    ];
  };

  users.users.jsquats = {
    isNormalUser = true;
    uid = 2003;
    group = "jsquats";
    description = "jasper";
    extraGroups = ["networkmanager"];
    shell = pkgs.bash;
  };

  users.users.sukey = {
    isNormalUser = true;
    uid = 2004;
    group = "sukey";
    description = "sukey";
    extraGroups = ["networkmanager"];
    shell = pkgs.zsh;
  };

  # Attach Home-Manager configs
  home-manager.users.grue = import ../../home/users/grue.nix;
  home-manager.users.jsquats = import ../../home/users/jsquats.nix;
  home-manager.users.sukey = import ../../home/users/sukey.nix;
}
