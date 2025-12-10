# home/modules/kitty/default.nix
{pkgs, ...}: {
  programs.kitty = {
    enable = true;

    shellIntegration.enableZshIntegration = true;
    themeFile = "gruvbox-dark";
    font.package = pkgs.fira-code;
    font.name = "Fira Code";
    font.size = 14;

    settings = {
      # fonts
      disable_ligatures = "cursor";
      scrollbar = "scrolled-and-hovered";
      cursor_blink_interval = -1;
      enable_audio_bell = false;
      tab_bar_style = "powerline";
      wayland_enable_ime = false;
      shell = ".";
      editor = ".";
    };
  };
}
