{pkgs, ...}: let
  plugins = pkgs.vimPlugins;
in {
  programs.neovim.plugins = [
    # -- Treesitter --
    {
      plugin = plugins.nvim-treesitter.withAllGrammars;
      type = "lua";
      config = builtins.readFile ./plugins/treesitter.lua;
    }

    # -- LSP --
    {
      plugin = plugins.nvim-lspconfig;
      type = "lua";
      config = builtins.readFile ./plugins/lsp.lua;
    }
    {plugin = plugins.fidget-nvim;}

    # -- Formatting --
    {
      plugin = plugins.conform-nvim;
      type = "lua";
      config = ''
        require("conform").setup({
          formatters_by_ft = {
            go = { "goimports", "gofumpt", "golangci_lint" },
            lua = { "stylua" },
            nix = { "alejandra" },
            python = { "ruff_organize_imports", "ruff_format" },
          },
        })
      '';
    }

    # -- Completion --
    {
      plugin = plugins.nvim-cmp;
      type = "lua";
      config = builtins.readFile ./plugins/cmp.lua;
    }
    {plugin = plugins.cmp-nvim-lsp;}
    {plugin = plugins.cmp-buffer;}
    {plugin = plugins.cmp-path;}
    {plugin = plugins.cmp_luasnip;}
    {plugin = plugins.luasnip;}
    {plugin = plugins.friendly-snippets;}

    # -- Fuzzy finder --
    {
      plugin = plugins.telescope-nvim;
      type = "lua";
      config = builtins.readFile ./plugins/telescope.lua;
    }
    {plugin = plugins.telescope-fzf-native-nvim;}
    {plugin = plugins.plenary-nvim;}

    # -- UI --
    {
      plugin = plugins.nightfox-nvim;
      type = "lua";
      config = builtins.readFile ./plugins/ui.lua;
    }
    {plugin = plugins.lualine-nvim;}
    {plugin = plugins.indent-blankline-nvim;}
    {plugin = plugins.nvim-web-devicons;}
    {plugin = plugins.todo-comments-nvim;}

    # -- Editor enhancements --
    {
      plugin = plugins.which-key-nvim;
      type = "lua";
      config = builtins.readFile ./plugins/editor.lua;
    }
    {plugin = plugins.comment-nvim;}
    {plugin = plugins.nvim-surround;}
    {plugin = plugins.nvim-autopairs;}
    {plugin = plugins.flash-nvim;}
    {plugin = plugins.vim-easy-align;}
    {plugin = plugins.vim-unimpaired;}
    {plugin = plugins.vim-repeat;}

    # -- Navigation & git --
    {
      plugin = plugins.nvim-tree-lua;
      type = "lua";
      config = builtins.readFile ./plugins/navigation.lua;
    }
    {plugin = plugins.gitsigns-nvim;}
    {plugin = plugins.nvim-lastplace;}
  ];
}
