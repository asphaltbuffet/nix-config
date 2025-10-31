# home/roles/base.nix
{ pkgs, lib, config, ... }:
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
    ../modules/firefox
  ];

  #### Home-Manager essentials ####
  programs.home-manager.enable = true;
  xdg.enable = true;
  fonts.fontconfig.enable = true;

  #### nix-index (for “command-not-found” functionality) ####
  programs.nix-index.enable = true;

  #### Common CLI / UX tools ####
  home.packages = with pkgs; [
    bat
    curl
    fd
    just
    ripgrep
    unzip
    wget
    xh
    zip
  ];

  #### Default environment setup ####
  home.sessionVariables = {
    EDITOR = lib.mkDefault "vim";
    LANG = "en_US.UTF-8";
    PAGER = lib.mkDefault "less";
  };

  programs.fzf.enable = true;
}
