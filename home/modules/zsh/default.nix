# home/modules/zsh/default.nix
{config, ...}: {
  programs.zsh = {
    enable = true;

    sessionVariables = {
      EDITOR = "vim";
      VISUAL = "vim";
    };

    initContent = ''
      autoload -Uz promptinit && promptinit && prompt powerlevel10k

      # source p10k config file managed by HomeManager
      [[ ! -f $ZDOTDIR/.p10k.zsh ]] || source $ZDOTDIR/.p10k.zsh
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
        "mafredri/zsh-async"
        "romkatv/powerlevel10k kind:fpath"
        "romkatv/zsh-bench kind:path"
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

  home.file."${config.xdg.configHome}/zsh/.p10k.zsh".source = ./.p10k.zsh;
}
