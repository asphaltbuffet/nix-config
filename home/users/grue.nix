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

    ../modules/ssh
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

  # Agenix secrets
  age.secrets.goreleaser.file = ../../secrets/goreleaser.age;
  age.secrets.anthropic.file = ../../secrets/anthropic.age;
  # Set API keys from decrypted secrets at shell init
  programs.zsh.initContent = ''
    [[ -f "${config.age.secrets.goreleaser.path}" ]] && export GORELEASER_KEY="$(cat "${config.age.secrets.goreleaser.path}")"
    [[ -f "${config.age.secrets.anthropic.path}" ]] && export ANTHROPIC_API_KEY="$(cat "${config.age.secrets.anthropic.path}")"
  '';

  # Personal touches
  home.packages = with pkgs; [
    obsidian
    signal-desktop
  ];
}
