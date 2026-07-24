# /home/users/sukey.nix
{...}: {
  imports = [
    ../roles/desktop.nix
  ];

  home = {
    username = "sukey";
    homeDirectory = "/home/sukey";

    shell.enableZshIntegration = true;

    packages = [];
  };
}
