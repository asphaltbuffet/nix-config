# home/roles/base.nix
{ pkgs, lib, ... }:
{
  #### Core imports ####
  # Pull in your shared app modules so every user gets consistent configs
  imports = [
    ../modules/eza
    ../modules/fzf
    ../modules/git
    ../modules/tmux
    ../modules/vim
    ../modules/zoxide
    ../modules/zsh
  #   ../modules/firefox
  ];

  #### Home-Manager essentials ####
  programs.home-manager.enable = true;
  xdg.enable = true;
  fonts.fontconfig.enable = true;

  #### nix-index (for “command-not-found” functionality) ####
  programs.nix-index.enable = true;
  # programs.nix-index-database.comma.enable = true;

  #### Common CLI / UX tools ####
  home.packages = with pkgs; [
    # Everyday command-line utilities
    bat
    fd
    fzf
    ripgrep
    wget
    curl
    unzip
    zip
    just # handy task runner for all users
    xh
  ];

  #### Default environment setup ####
  home.sessionVariables = {
    EDITOR = lib.mkDefault "vim";
    PAGER = lib.mkDefault "less";
    LANG = "en_US.UTF-8";
  };

  #### fzf defaults ####
  programs.fzf.enable = true;
}
