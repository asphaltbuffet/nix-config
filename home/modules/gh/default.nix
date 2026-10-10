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
      gh-dash # TUI dashboard for PRs and issues across repos
      gh-notify # TUI browser for GitHub notifications
    ];

    # Reads from GitHub go over HTTPS with the gh token; pushes stay on SSH via
    # the 1Password agent. This keeps the background jj-git-fetch timer from
    # popping the 1Password unlock window while the vault is locked.
    gitCredentialHelper.enable = true;
  };

  # pushInsteadOf maps SSH to itself, so it wins over insteadOf for pushes.
  programs.git.settings.url = {
    "https://github.com/".insteadOf = "git@github.com:";
    "git@github.com:".pushInsteadOf = "git@github.com:";
  };
}
