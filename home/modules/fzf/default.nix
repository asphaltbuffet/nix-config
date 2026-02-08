{...}: {
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --strip-cwd-prefix";
    changeDirWidgetCommand = "fd --type d";
    fileWidgetCommand = "fd --type f";
  };
}
