# home/users/grue.nix
{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  identity = {
    name = "Ben Lechlitner";
    email = "30903912+asphaltbuffet@users.noreply.github.com";
  };

  secretEnvs = [
    {
      secret = "goreleaser";
      env = "GORELEASER_KEY";
    }
    {
      secret = "anthropic";
      env = "ANTHROPIC_API_KEY";
    }
    {
      secret = "context7";
      env = "CONTEXT7_API_KEY";
    }
    {
      secret = "github";
      env = "GH_TOKEN";
    }
    {
      secret = "githubMcp";
      env = "GITHUB_PERSONAL_ACCESS_TOKEN";
    }
    {
      secret = "protonmailUsername";
      env = "POP_SMTP_USERNAME";
    }
    {
      secret = "protonmailPassword";
      env = "POP_SMTP_PASSWORD";
    }
    {
      secret = "resend";
      env = "RESEND_API_KEY";
    }
  ];

  mkSecretExport = {
    secret,
    env,
  }: let
    path = config.age.secrets.${secret}.path;
  in ''
    if [[ -r "${path}" ]]; then
      ${env}="$(< "${path}")"
      export ${env}
    fi
  '';
in {
  imports = [
    inputs.agenix.homeManagerModules.default

    ../roles/base.nix
    ../roles/admin.nix
    ../roles/dev.nix
    ../roles/player.nix

    ../modules/ssh
    ../modules/protonmail
    ../modules/pop
  ];

  home.username = "grue";
  home.homeDirectory = "/home/grue";
  home.stateVersion = "25.05";

  programs.git.settings.user = identity;

  programs.jujutsu.settings.user = identity;

  # Personal touches
  home.packages = with pkgs; [
    obsidian
  ];

  # Protonmail bridge uses fixed local addresses — not secrets
  home.sessionVariables = {
    POP_SMTP_HOST = "127.0.0.1";
    POP_SMTP_PORT = "1025";
  };

  # Agenix secrets
  age.secrets = lib.listToAttrs (map ({secret, ...}: {
      name = secret;
      value = {
        file = ../../secrets/grue/${secret}.age;
        mode = "0400";
      };
    })
    secretEnvs);

  # Set ENVs from secrets in shell init
  programs.zsh.initContent = lib.concatMapStrings mkSecretExport secretEnvs;
}
