{ pkgs, lib, ... }:
{
  programs.git = {
    enable = true;
    package = pkgs.gitAndTools.gitFull;


    settings = {
      alias = {
        co = "checkout";
        cb = "checkout -b";
        please = "push --force-with-lease";
        st = "status";
        cm = "checkout main";
      };
      branch.sort = "-committerdate";
      column.ui = "auto";
      commit.verbose = true;
      diff = {
        algorithm = "histogram";
        colorMoved = "plain";
        mnemonicPrefix = true;
        renames = true;
      };
      fetch = {
        prune = true;
        pruneTags = true;
        all = true;
      };
      help.autocorrect = "prompt";
      init.defaultBranch = "main";
      merge = {
        conflictstyle = "zdiff3";
        tool = "vimdiff";
      };
      mergetool.prompt = false;
      push = {
        default = "simple";
        autoSetupRemote = true;
        followTags = true;
      };
      rebase = {
        autosquash = true;
        autoStash = true;
        updateRefs = true;
      };
      rerere = {
        enabled = true;
        autoupdate = true;
      };
      tag.sort = "version:refname";
    };

    ignores = lib.splitString "\n" (builtins.readFile ./gitignore_common);

  };
}
