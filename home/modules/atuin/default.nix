_: {
  programs.atuin = {
    enable = true;
    flags = ["--disable-up-arrow"];
    settings = {
      ai.enabled = true;

      # Self-hosted sync server on bunyip (ADR-0025). AI is unaffected: it
      # resolves ai.endpoint (unset -> hub.atuin.sh), never sync_address.
      sync_address = "https://atuin.armadillo-toad.ts.net";
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
