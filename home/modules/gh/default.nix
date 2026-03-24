{pkgs, ...}: {
  programs.gh = {
    enable = true;

    settings = {
      git_protocol = "ssh";
      prompt = "enabled";

      aliases = {
        # CI / Actions
        runs = "run list";
        watch = "run watch";
        # PR shortcuts
        prc = "pr create";
        prv = "pr view --web";
      };
    };

    extensions = with pkgs; [
      gh-dash    # TUI dashboard for PRs and issues across repos
      gh-notify  # TUI browser for GitHub notifications
    ];

    # gitCredentialHelper is disabled: jj handles git credentials via the
    # 1Password SSH agent (configured in home/modules/ssh/default.nix).
    gitCredentialHelper.enable = false;
  };
}
