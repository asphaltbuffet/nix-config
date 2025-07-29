{ pkgs, ... }: {
  programs.kitty = {
    enable = true;
    shellIntegration.enableZshIntegration = true;
    themeFile = "SpaceGray_Eighties";
    # font.package = pkgs.fira;
    font.name = "Fira Sans";
    font.size = 14;
  };
}
