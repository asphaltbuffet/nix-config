{ ... }:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      add_newline = true;
      hostname.ssh_only = true;
      directory.truncation_symbol = "…/";
    };
  };
}
