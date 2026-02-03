# home/users/grue.nix
{pkgs, ...}: {
  imports = [
    ../roles/base.nix

    ../roles/admin.nix
    ../roles/dev.nix
    ../roles/player.nix
  ];

  home.username = "grue";
  home.homeDirectory = "/home/grue";
  home.stateVersion = "25.05";

  programs.git.settings.user = {
    name = "Ben Lechlitner";
    email = "30903912+asphaltbuffet@users.noreply.github.com";
  };

  programs.jujutsu.settings = {
    user = {
      name = "Ben Lechlitner";
      email = "30903912+asphaltbuffet@users.noreply.github.com";
    };
  };

  # Personal touches
  home.packages = with pkgs; [
    obsidian
    signal-desktop
  ];
}
