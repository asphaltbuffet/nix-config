{ pkgs, ... }: {
  programs.git = {
    enable = true;

    package = pkgs.gitAndTools.gitFull;
    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
      };
    };
    userEmail = "otherland@gmail.com";
    userName = "Ben Lechlitner";

    extraConfig = {
      branch = { sort = "-committerdate"; };
      column = { ui = "auto"; };
      commit = { verbose = true; };
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
      help = { autocorrect = "prompt"; };
      init = { defaultBranch = "main"; };
      merge = {
        conflictstyle = "zdiff3";
        tool = "vimdiff";
      };
      mergetool = { prompt = false; };
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
      tag = { sort = "version:refname"; };
    };

    ignores = [
      # vim
      "[._]*.s[a-v][a-z]"
      "!*svg"
      "[._]*.sw[a-p]"
      "[._]s[a-rt-v][a-z]"
      "[._]ss[a-gi-z]"
      "[._]sw[a-p]"
      "Session.vim"
      "Sessionx.vim"
      ".netrwhist"
      "[._]*.un~"

      # linux
      "*~"
      ".fuse_hidden*"
      ".directory"
      ".Trash-*"
      ".nfs*"
    ];
  };
}
