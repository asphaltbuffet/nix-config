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

      templates.log = ''
        label(
          separate(" ",
            if(current_working_copy, "working_copy"),
            if(immutable, "immutable", "mutable"),
            if(conflict, "conflicted"),
          ),
          concat(
            separate(" ",
              change_id.shortest(8),
              commit_id.shortest(8),
              committer.timestamp().ago(),
              bookmarks.join(" "),
              tags,
              working_copies,
              if(author.email() != "30903912+asphaltbuffet@users.noreply.github.com",
                label("author", "‹" ++ author.name() ++ "›")),
            ) ++ "\n",
            "  " ++ separate(" ",
              if(empty, label("empty", "(empty)")),
              if(description,
                description.first_line(),
                label(if(empty, "empty"), "(no description set)"),
              ),
            ) ++ "\n",
          )
        )
      '';

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
