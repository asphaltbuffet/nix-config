# /home/users/sukey.nix
{...}: {
  imports = [
    ../roles/base.nix
  ];

  home = {
    username = "sukey";
    homeDirectory = "/home/sukey";

    shell.enableZshIntegration = true;

    packages = [];
  };
}
