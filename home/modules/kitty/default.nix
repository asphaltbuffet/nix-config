{ pkgs, ... }:
{
  programs.kitty = {
    enable = true;
    shellIntegration.enableZshIntegration = true;
    themeFile = "Monokai";
    # font.package = pkgs.fira;
    font.name = "Fira Sans";
    font.size = 14;

    settings = {
      cursor_blink_interval = -1;
      enable_audio_bell = false;
      window_padding_width = 10;
      shell = ".";
      editor = ".";
    };
  };
}
