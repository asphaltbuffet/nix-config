_: {
  programs.atuin = {
    enable = true;
    flags = ["--disable-up-arrow"];
    settings = {
      ai.enabled = true;

      auto_sync = true;
      sync_frequency = "5m";

      enter_accept = true;
      keymap_mode = "vim-normal";

      common_subcommands = [
        "just"
        "mise"
        "elf"
        "wherehouse"

        # defaults
        "apt"
        "cargo"
        "composer"
        "dnf"
        "docker"
        "git"
        "go"
        "ip"
        "jj"
        "kubectl"
        "nix"
        "nmcli"
        "npm"
        "pecl"
        "pnpm"
        "podman"
        "port"
        "systemctl"
        "tmux"
        "yarn"
      ];
    };
  };
}
