{...}: {
  programs.fzf = {
    enable = true;

    enableZshIntegration = true;
    tmux.enableShellIntegration = true;

    defaultCommand = "fd --type f";
    changeDirWidgetCommand = "fd --type d";
    fileWidgetCommand = "fd --type f";

  };
}
