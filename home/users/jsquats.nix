# home/users/jsquats.nix
{...}: {
  imports = [
    ../roles/base.nix
    ../roles/player.nix
  ];

  home = {
    username = "jsquats";
    homeDirectory = "/home/jsquats";

    shell.enableZshIntegration = true;

    packages = [];
  };
}
