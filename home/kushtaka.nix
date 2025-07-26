{ config, username, pkgs, ...}: {
  nixpkgs = {
    overlays = [];
    config = {
      allowUnfree = true;
      allowUnfreePredicte = (_: true);
    };
  };

  targets.genericLinux.enable = true;

  home = {
    inherit username;
    homeDirectory = "/home/${username}";

    stateVersion = "25.05";

    packages = with pkgs; [
      _1password-cli
      asciinema
      bat        # better cat
      bottom     # better top
      broot
      choose     # cut/awk
      delta      # better git-diff
      doggo      # dig
      duf        # better df
      dust       # du + rust
      eza        # better ls
      fd         # better find
      fping      # ping for mult
      fzf
      git-absorb
      glow       # markdown viewer
      gum        # fancy cli snippets
      ijq        # interactive jq
      iperf
      jq
      just
      lnav
      mcfly      # history search
      moreutils
      ncdu
      pop        # email from cli
      presenterm # presentations
      ripgrep
      taplo      # toml
      tig        # git TUI
      tmux
      tmux-xpanes
      trippy     # tui network tool
      vhs        # terminal gifs
      viddy      # better watch
      wishlist   # ssh helper
      xh         # better curl
      zoxide     # cd

      _1password-gui
      discord
      signal-desktop
      obsidian
    ];
  };

  xdg.enable = true;

  fonts.fontconfig.enable = true;

  programs.home-manager.enable = true;
  programs.firefox.enable = true;

  systemd.user.startServices = "sd-switch";

}
