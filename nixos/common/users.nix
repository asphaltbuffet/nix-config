{pkgs, ...}: {
  users.users.grue = {
    isNormalUser = true;
    description = "grue";
    extraGroups = [
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
    description = "jasper";
    extraGroups = ["networkmanager"];
    shell = pkgs.bash;
  };

  # users.users.sukey = {
  #   isNormalUser = true;
  #   description = "sukey";
  #   extraGroups = [ "networkmanager" ];
  #   shell = pkgs.bash;
  # };

  # Attach Home-Manager configs
  home-manager.users.grue = import ../../home/users/grue.nix;
  home-manager.users.jsquats = import ../../home/users/jsquats.nix;
  # home-manager.users.sukey = import ../../home/users/sukey.nix;
}
