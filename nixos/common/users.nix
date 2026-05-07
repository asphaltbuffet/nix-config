{pkgs, ...}: {
  users = {
    groups = {
      grue.gid = 2001;
      jsquats.gid = 2003;
      sukey.gid = 2004;
    };

    users = {
      grue = {
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
