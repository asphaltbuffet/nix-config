# home/modules/bat/default.nix
# bat (cat with syntax highlighting) plus batman, which renders man pages
# through bat. MANPAGER mirrors `batman --export-env`, so plain `man` is
# highlighted too; `batman` with no args opens an fzf picker.
{pkgs, ...}: let
  inherit (pkgs.bat-extras) batman;
in {
  programs.bat = {
    enable = true;
    extraPackages = [batman];
  };

  home.sessionVariables = {
    MANPAGER = "env BATMAN_IS_BEING_MANPAGER=yes ${batman}/bin/batman";
    MANROFFOPT = "-c";
  };
}
