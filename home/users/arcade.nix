# /home/users/arcade.nix
{...}: {
  imports = [
    ../roles/arcade.nix
  ];

  home = {
    username = "arcade";
    homeDirectory = "/home/arcade";

    shell.enableZshIntegration = true;

    packages = [];
  };
}
