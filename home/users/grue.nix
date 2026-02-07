# home/users/grue.nix
{
  pkgs,
  config,
  inputs,
  ...
}: {
  imports = [
    inputs.agenix.homeManagerModules.default

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

  # Goreleaser Pro key for releases
  age.secrets.goreleaser.file = ../../secrets/goreleaser.age;

  # Set GORELEASER_KEY from decrypted secret at shell init
  programs.zsh.initContent = ''
    [[ -f "${config.age.secrets.goreleaser.path}" ]] && export GORELEASER_KEY="$(cat "${config.age.secrets.goreleaser.path}")"
  '';

  # Personal touches
  home.packages = with pkgs; [
    obsidian
    signal-desktop
  ];
}
