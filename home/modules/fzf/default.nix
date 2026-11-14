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

  # `**<Tab>` completion ignores the commands above and calls these hooks
  # (default: `find`). Route them through fd so .gitignore is respected.
  programs.zsh.initContent = ''
    _fzf_compgen_path() { fd --follow . "$1"; }
    _fzf_compgen_dir() { fd --type d --follow . "$1"; }
  '';
}
