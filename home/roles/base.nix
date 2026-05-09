# home/roles/base.nix
{
  pkgs,
  lib,
  inputs,
  ...
}: {
  #### Core imports ####
  # Pull in your shared app modules so every user gets consistent configs
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
    ../modules/firefox
    ../modules/wishlist

    # GUI stuff
    ../modules/1password
    ../modules/kitty
    ../modules/mullvad
    ../modules/signal
  ];

  #### Home-Manager essentials ####
  xdg.enable = true;
  fonts.fontconfig.enable = true;

  programs = {
    home-manager.enable = true;
    # Provides fast command-not-found via pre-built indexes
    # comma lets you run any command temporarily: , cowsay hello
    nix-index-database.comma.enable = true;
    fzf.enable = true;
  };

  #### Common CLI / UX tools ####
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

      # GUI stuff
      discord
      vlc
    ];

    #### Default environment setup ####
    sessionVariables = {
      EDITOR = lib.mkDefault "nvim";
      LANG = "en_US.UTF-8";
      PAGER = lib.mkDefault "less";
    };
  };
}
