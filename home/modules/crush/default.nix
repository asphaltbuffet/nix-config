# home/modules/crush/default.nix
{...}: {
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
