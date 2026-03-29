# home/modules/agenix/default.nix
# User-level agenix secret declarations and load-secrets script.
# Secrets are decrypted to $XDG_RUNTIME_DIR/agenix/ at activation time.
# Each secret is encrypted only to that user's SSH key.
{
  pkgs,
  config,
  inputs,
  ...
}: let
  # Single source of truth: all user secrets.
  # Add new secrets here; update secrets.nix and encrypt the .age file.
  userSecrets = {
    goreleaser = {
      file = ../../../secrets/grue/goreleaser.age;
      envVar = "GORELEASER_KEY";
    };
    anthropic = {
      file = ../../../secrets/grue/anthropic.age;
      envVar = "ANTHROPIC_API_KEY";
    };
    context7 = {
      file = ../../../secrets/grue/context7.age;
      envVar = "CONTEXT7_API_KEY";
    };
    github = {
      file = ../../../secrets/grue/github.age;
      envVar = "GH_TOKEN";
    };
    githubMcp = {
      file = ../../../secrets/grue/githubMcp.age;
      envVar = "GITHUB_PERSONAL_ACCESS_TOKEN";
    };
    protonmailHost = {
      file = ../../../secrets/grue/protonmailHost.age;
      envVar = "POP_SMTP_HOST";
    };
    protonmailPort = {
      file = ../../../secrets/grue/protonmailPort.age;
      envVar = "POP_SMTP_PORT";
    };
    protonmailUsername = {
      file = ../../../secrets/grue/protonmailUsername.age;
      envVar = "POP_SMTP_USERNAME";
    };
    protonmailPassword = {
      file = ../../../secrets/grue/protonmailPassword.age;
      envVar = "POP_SMTP_PASSWORD";
    };
    resend = {
      file = ../../../secrets/grue/resend.age;
      envVar = "RESEND_API_KEY";
    };
  };

  # Generate load-secrets entries for each secret.
  # SC2155-safe: declare and export separately.
  loadLines = builtins.concatStringsSep "\n" (
    builtins.attrValues (
      builtins.mapAttrs (name: secret: let
        path = config.age.secrets.${name}.path;
      in ''
        if [[ -r "${path}" ]]; then
          ${secret.envVar}="$(< "${path}")"
          export ${secret.envVar}
        fi
      '')
      userSecrets
    )
  );

  loadSecrets = pkgs.writeShellApplication {
    name = "load-secrets";
    text = loadLines;
  };
in {
  imports = [inputs.agenix.homeManagerModules.default];

  # Declare agenix secret paths for each user secret.
  age.secrets = builtins.mapAttrs (_name: secret: {
    inherit (secret) file;
    mode = "0400";
  }) userSecrets;

  home.packages = [loadSecrets];
}
