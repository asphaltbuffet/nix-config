# /home/users/sukey.nix
{ pkgs, ... }:
{

  imports = [
    ../roles/base.nix
  ];

  home = {
    username = "sukey";
    homeDirectory = "/home/sukey";
    stateVersion = "25.05";
    shell.enableZshIntegration = true;

    packages = with pkgs; [
      signal-desktop
    ];
  };

}
