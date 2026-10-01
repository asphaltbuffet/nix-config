# home/modules/crush/default.nix
_: {
  programs.crush = {
    enable = true;
    settings = {
      lsp = {
        go = {
          command = "gopls";
        };
        nix = {
          command = "nixd";
        };
      };
    };
  };
}
