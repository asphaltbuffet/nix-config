# Vim plugins
{pkgs, ...}: {
  programs.vim.plugins = with pkgs.vimPlugins; [
    # Linting & formatting
    ale
    editorconfig-vim

    # Editing helpers
    delimitMate
    vim-commentary
    vim-easy-align
    vim-repeat
    vim-surround
    vim-unimpaired

    # Navigation
    fzf-vim
    nerdtree
    vim-nerdtree-tabs
    vim-lastplace

    # UI
    papercolor-theme
    vim-airline
    vim-airline-themes
    vim-indent-guides

    # Language support
    jq-vim
    vim-go
    vim-nix
  ];
}
