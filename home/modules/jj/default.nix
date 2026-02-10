# home/modules/jj/default.nix
{pkgs, ...}: {
  programs.jujutsu = {
    enable = true;

    settings = {
      ui = {
        editor = "${pkgs.neovim}/bin/nvim";
        default-command = ["status"];
        diff-editor = ":builtin";
      };

      aliases = {
        tug = ["bookmark" "move" "--from" "heads(::@- & bookmarks())" "--to" "@-"];
      };

      fix.tools = {
        alejandra = {
          command = ["${pkgs.alejandra}/bin/alejandra" "--quiet"];
          patterns = ["glob:'**/*.nix'"];
        };
      };
    };
  };

  programs.jjui = {
    enable = true;
  };
}
