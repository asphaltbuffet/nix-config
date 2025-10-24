# home/users/jsquats.nix
{ pkgs, ... }:
{
  imports = [
    ../roles/base.nix
  ];

  home = {
    username = "jsquats";
    homeDirectory = "/home/jsquats";
    stateVersion = "25.05";
    shell.enableZshIntegration = true;

    packages = with pkgs; [
    ];
  };

}
