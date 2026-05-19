# home/modules/jj/default.nix
{pkgs, ...}: let
  fetchScript = import ./fetch-script.nix {inherit pkgs;};
in {
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

  systemd.user.services.jj-git-fetch = {
    Unit = {
      Description = "Fetch all jj repos under ~/dev";
      After = ["network-online.target"];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${fetchScript}/bin/jj-git-fetch-all";
    };
  };

  systemd.user.timers.jj-git-fetch = {
    Unit.Description = "Periodic jj git fetch for all repos under ~/dev";
    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "15m";
      Persistent = true;
    };
    Install.WantedBy = ["timers.target"];
  };
}
