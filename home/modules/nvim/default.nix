{pkgs, ...}: {
  imports = [./plugins.nix];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    initLua = builtins.concatStringsSep "\n" [
      (builtins.readFile ./options.lua)
      (builtins.readFile ./keymaps.lua)
    ];

    extraPackages = with pkgs; [
      # LSP servers
      gopls
      nixd
      pyright
      lua-language-server

      # Formatters / linters
      gofumpt
      gotools # goimports
      golangci-lint
      ruff
      stylua
      alejandra

      # Telescope deps
      ripgrep
      fd
    ];
  };
}
