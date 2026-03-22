{
  config,
  lib,
  ...
}: {
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    configPath = "${config.xdg.configHome}/starship/starship.toml";

    settings = {
      # Left prompt: dir → jj (or git fallbacks) → newline → prompt char
      # ''${ is Nix's escape for a literal ${ inside ''...'' strings
      format = ''$all''${custom.jj}''${custom.git_branch}''${custom.git_commit}$line_break$character'';

      # Right prompt (line 1): exit code → duration → direnv
      right_format = lib.concatStrings [
        "$status"
        "$cmd_duration"
        "$direnv"
        "$battery"
      ];

      battery = {
        full_symbol = "󰁹";
        charging_symbol = "󰂅 ";
        discharging_symbol = "󰂃";
        unknown_symbol = "󰂑";
        empty_symbol = "󰂎";
      };

      directory = {
        truncation_symbol = " /";
        read_only = " 󰉐 ";
      };

      hostname = {
        ssh_only = false;
      };

      nix_shell = {
        symbol = "";
        pure_msg = "λ";
        impure_msg = "Λ";
        unknown_msg = " ";
      };

      custom = {
        # jj VCS — shown only inside jj repos
        jj = {
          description = "The current jj status";
          when = "jj --ignore-working-copy root";
          symbol = "🥋 ";
          command = ''
            jj log --revisions @ --no-graph --ignore-working-copy --color always --limit 1 --template '
              separate(" ",
                change_id.shortest(4),
                bookmarks,
                "|",
                concat(
                  if(conflict, "💥"),
                  if(divergent, "🚧"),
                  if(hidden, "👻"),
                  if(immutable, "🔒"),
                ),
                raw_escape_sequence("\x1b[1;32m") ++ if(empty, "(empty)"),
                raw_escape_sequence("\x1b[1;32m") ++ coalesce(
                  truncate_end(29, description.first_line(), "…"),
                  "(no description set)",
                ) ++ raw_escape_sequence("\x1b[0m"),
              )
            '
          '';
          format = "$symbol$output ";
        };

        # Git fallbacks — only shown in pure-git repos (not jj-colocated)
        git_branch = {
          when = "! jj --ignore-working-copy root";
          command = "starship module git_branch";
          style = "";
          description = "Only show git_branch if not in a jj repo";
        };

        git_commit = {
          when = "! jj --ignore-working-copy root";
          command = "starship module git_commit";
          style = "";
          description = "Only show git_commit if not in a jj repo";
        };

        git_status = {
          when = "! jj --ignore-working-copy root";
          command = "starship module git_status";
          style = "";
          description = "Only show git_status if not in a jj repo";
        };

        git_metrics = {
          when = "! jj --ignore-working-copy root";
          command = "starship module git_metrics";
          style = "";
          description = "Only show git_metrics if not in a jj repo";
        };
      };

      character = {
        success_symbol = "[󰅂 ](bold green)";
        error_symbol = "[󰅂 ](bold red)";
        vimcmd_symbol = "[󰅁 ](bold green)";
        vimcmd_replace_one_symbol = "[󰅁 ](bold purple)";
        vimcmd_replace_symbol = "[󰅁 ](bold purple)";
        vimcmd_visual_symbol = "[󰅁 ](bold yellow)";
      };

      status = {
        disabled = false;
        symbol = " ";
        map_symbol = true;
        not_executable_symbol = " ";
        not_found_symbol = " ";
        sigint_symbol = "󰗖 ";
        signal_symbol = "🗲 ";
      };

      cmd_duration = {format = "[$duration]($style) ";};

      direnv = {
        disabled = false;
        format = "[$symbol$loaded]($style) ";
        symbol = "󰐍 ";
        loaded_msg = "env";
        unloaded_msg = "";
        allowed_msg = "";
        not_allowed_msg = "!";
        denied_msg = "✗";
      };

      # Disable built-in git modules — replaced by conditional custom modules above
      git_branch.disabled = true;
      git_commit.disabled = true;
      git_state.disabled = true;
      git_metrics.disabled = true;
      git_status.disabled = true;
    };
  };
}
