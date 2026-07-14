_: {
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --strip-cwd-prefix";
    changeDirWidget.command = "fd --type d";
    fileWidget.command = "fd --type f";

    # Yield Ctrl-R to atuin (the history manager). An empty command is the
    # home-manager-supported way to disable fzf's Ctrl-R binding; keeps fzf's
    # Ctrl-T (files) and Alt-C (cd) widgets. Silences the "both configure
    # Ctrl-R" eval warning.
    historyWidget.command = "";
  };
}
