# home/modules/zsh/default.nix
{config, ...}: {
  programs.zsh = {
    enable = true;

    sessionVariables = {
      EDITOR = "vim";
      VISUAL = "vim";
      DIRENV_LOG_FORMAT = ""; # silence direnv loading/export messages
    };

    initContent = ''
      # Inject 1Password secrets if op is available and signed in
      if command -v op &>/dev/null; then
        eval "$(op inject --in-file ${./secrets.env} 2>/dev/null)" || true
      fi

      # Set NIXOS_REBOOT_PENDING if the running kernel differs from the current config.
      # Used by the starship prompt and the login message below.
      if [[ "$(readlink /run/booted-system/kernel)" != "$(readlink /run/current-system/kernel)" ]]; then
        export NIXOS_REBOOT_PENDING=1
      fi

      # Notify on login if a reboot is pending
      if [[ -o login ]] && [[ -n "$NIXOS_REBOOT_PENDING" ]]; then
        echo "⚠ NixOS update staged — reboot to apply."
      fi
    '';

    defaultKeymap = "viins";
    enableCompletion = true;
    autocd = true;
    autosuggestion = {
      enable = true;
      strategy = ["match_prev_cmd"];
    };
    syntaxHighlighting.enable = true;
    dotDir = "${config.xdg.configHome}/zsh";

    antidote = {
      enable = true;

      plugins = [
        "mattmc3/zephyr path:plugins/completion"
        "mdumitru/git-aliases"
        "mattmc3/zman"
        "agkozak/zsh-z"
      ];

      useFriendlyNames = true;
    };

    shellAliases = {
      ll = "eza -l";
      la = "eza -la";
      lt = "eza -T";

      md = "mkdir -p";
    };
  };
}
