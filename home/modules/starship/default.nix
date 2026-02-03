{config, ...}: {
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    configPath = "${config.xdg.configHome}/starship/starship.toml";

    settings = {
      add_newline = true;
      hostname.ssh_only = true;
      directory.truncation_symbol = "…/";
    };
  };
}
