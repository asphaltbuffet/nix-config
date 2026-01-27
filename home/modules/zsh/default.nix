# home/modules/zsh/default.nix
{config, ...}: {
  programs.zsh = {
    enable = true;

    sessionVariables = {
      EDITOR = "vim";
      VISUAL = "vim";
    };

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
        "ohmyzsh/ohmyzsh path:plugins/mise"
        "peterhurford/up.zsh"
        "rummik/zsh-tailf"
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

      gst = "git status";
      gd = "git diff";
      glods = ''git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset" --date=short'';
    };
  };
}
