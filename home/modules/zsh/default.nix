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
