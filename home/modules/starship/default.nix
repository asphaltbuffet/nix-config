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
      # Cap how long any single filesystem/VCS scan may block. On NFS-backed
      # paths (see nixos/common/nas.nix — /home/grue/nas) an unbounded scan can
      # stall the prompt for seconds while the automount remounts. If a scan
      # exceeds these budgets Starship renders without that segment.
      scan_timeout = 30; # ms — directory/VCS discovery
      command_timeout = 100; # ms — external commands (jj, `starship module ...`)

      # Left prompt: dir → jj (or git fallbacks) → newline → prompt char
      # ''${ is Nix's escape for a literal ${ inside ''...'' strings
      format = ''$env_var$all''${custom.jj}''${custom.git_branch}''${custom.git_commit}$line_break$character'';

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

      env_var.NIXOS_REBOOT_PENDING = {
        variable = "NIXOS_REBOOT_PENDING";
        symbol = "󰐥 ";
        style = "bold red";
        format = "[$symbol]($style)";
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
        # jj VCS — shown only inside jj repos.
        # `IN_JJ_REPO` is precomputed once per prompt by the zsh precmd hook
        # (see home/modules/zsh) so neither this module nor the git fallbacks
        # below re-run `jj root` — that walk hits the filesystem (NFS on the NAS)
        # and previously ran 5× per prompt.
        jj = {
          description = "The current jj status";
          when = ''[ "$IN_JJ_REPO" = "1" ]'';
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
          when = ''[ "$IN_JJ_REPO" != "1" ]'';
          command = "starship module git_branch";
          style = "";
          description = "Only show git_branch if not in a jj repo";
        };

        git_commit = {
          when = ''[ "$IN_JJ_REPO" != "1" ]'';
          command = "starship module git_commit";
          style = "";
          description = "Only show git_commit if not in a jj repo";
        };

        git_status = {
          when = ''[ "$IN_JJ_REPO" != "1" ]'';
          command = "starship module git_status";
          style = "";
          description = "Only show git_status if not in a jj repo";
        };

        git_metrics = {
          when = ''[ "$IN_JJ_REPO" != "1" ]'';
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
