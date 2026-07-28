# /home/users/arcade.nix
{...}: {
  imports = [
    ../roles/arcade
  ];

  home = {
    username = "arcade";
    homeDirectory = "/home/arcade";

    shell.enableZshIntegration = true;

    packages = [];
  };
}
