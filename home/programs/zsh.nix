{...}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    dotDir = ".config/zsh";
    shellAliases = {
      ll = "eza -l";
      la = "eza -la";
      lt = "eza -T";

      md = "mkdir -p";
    };

  };
}
