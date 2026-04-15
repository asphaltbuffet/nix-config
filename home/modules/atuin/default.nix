{...}: {
  programs.atuin = {
    enable = true;
    settings = {
      ai.enabled = true;

      auto-sync = true;
      sync-frequency = "5m";

      enter-accept = true;
      keymap-mode = "vim-normal";

      common_subcommands = [
        "just"
        "mise"
        "elf"

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
