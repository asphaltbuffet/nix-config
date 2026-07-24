# home/roles/cli.nix
# Shell / command-line foundation. Every login wants this; it contains no
# graphical or desktop applications. The `base` role imports it and adds the
# desktop app suite; kiosk users (e.g. the arcade cabinet) import `cli` directly.
{
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    inputs.nix-index-database.homeModules.nix-index

    ../modules/atuin
    ../modules/eza
    ../modules/fzf
    ../modules/git
    ../modules/starship
    ../modules/tmux
    ../modules/vim
    ../modules/zoxide
    ../modules/zsh
    ../modules/wishlist
  ];

  xdg.enable = true;
  fonts.fontconfig.enable = true;

  programs = {
    home-manager.enable = true;
    nix-index-database.comma.enable = true;
    fzf.enable = true;
  };

  home = {
    packages = with pkgs; [
      bat
      curl
      fd
      just
      ripgrep
      sd
      unzip
      wget
      xh
      zip
    ];

    sessionVariables = {
      EDITOR = lib.mkDefault "nvim";
      LANG = "en_US.UTF-8";
      PAGER = lib.mkDefault "less";
    };
  };
}
